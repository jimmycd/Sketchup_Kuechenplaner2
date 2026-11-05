# encoding: UTF-8
#
# Küchenplaner – Neu laden zur Laufzeit (ohne SketchUp-Neustart)
#
# Diese Datei liegt wortgleich in jeder Erweiterung unter
# src/kuechenplaner_gemeinsam/neuladen.rb; die Vorlage ist gemeinsam/neuladen.rb im
# Hauptordner, ./build_rbz.sh verteilt sie, der Test prüft das.
#
# Warum überhaupt neu laden? SketchUp lädt eine Ruby-Datei je Sitzung nur einmal
# (require). Installiert man eine neue .rbz über den Extension Manager, liegen die
# neuen Dateien zwar im Plugins-Ordner, es läuft aber bis zum Neustart der alte Code.
#
# Was diese Datei macht:
# * Wächter: ein Timer prüft alle 2 s, ob sich Dateien der Küchenplaner-Erweiterungen
#   im Plugins-Ordner geändert haben (Änderungszeit, Größe). Sind die Änderungen fertig
#   (zwei Prüfungen hintereinander gleich, also die .rbz ganz entpackt), werden die
#   gemeinsamen Dateien und die main.rb jeder betroffenen, eingeschalteten Erweiterung
#   mit load neu geladen. Neue Erweiterungen registriert SketchUp selbst.
# * Kuechenplaner::Neuladen.neu_laden – alles (Menü „Küchenplaner neu laden“) oder
#   nur bestimmte Dateien („Plugins aktualisieren“ ruft danach stand_merken auf).
#
# Damit das geht, gilt für alle Erweiterungen:
# * main.rb darf mehrfach laufen: Menüeinträge, Symbolleiste und Beobachter nur einmal
#   anlegen (file_loaded?), deren Blöcke rufen Modul-Methoden auf, die beim Neuladen
#   ersetzt werden; weitere Dateien der Erweiterung lädt main.rb mit load.
# * Beobachter als gemerkte Instanz (@beobachter ||= ...), dann hängt SketchUp sie nicht
#   doppelt an; die Klasse wird beim Neuladen nur ergänzt, die Instanz nutzt den neuen Code.
# Was ohne Neustart nicht geht: Menüeinträge und Icons kann SketchUp nicht entfernen.
# Neue Einträge erscheinen sofort (am Ende ihres Menüs), weggefallene bleiben bis zum
# nächsten Start stehen.
#
# Keine Konstanten: die Datei wird selbst neu geladen, ohne Warnungen.

module Kuechenplaner
  module Neuladen
    class << self
      attr_writer :plugins_ordner
      attr_reader :timer

      # Plugins-Ordner (diese Datei liegt in <Plugins>/kuechenplaner_gemeinsam/)
      def plugins_ordner
        @plugins_ordner || File.expand_path('..', File.dirname(File.expand_path(__FILE__)))
      end

      # Ordnernamen aller Küchenplaner-Erweiterungen im Plugins-Ordner: <name>/main.rb,
      # das die gemeinsamen Dateien lädt
      def erweiterungen
        @art ||= {}
        Dir.glob(File.join(plugins_ordner, '*', 'main.rb')).select do |m|
          zeit = (File.mtime(m) rescue nil)
          @art[m] = [zeit, kuechenplaner?(m)] unless @art[m] && @art[m][0] == zeit
          @art[m][1]
        end.map { |m| File.basename(File.dirname(m)) }.sort
      end

      def kuechenplaner?(main)
        File.read(main, encoding: 'UTF-8').include?("'kuechenplaner_gemeinsam'")
      rescue StandardError
        false
      end

      # Stand der Dateien: { pfad => [änderungszeit, größe] }
      def stand
        dateien = Dir.glob(File.join(plugins_ordner, 'kuechenplaner_gemeinsam', '*.rb'))
        erweiterungen.each { |e| dateien.concat(Dir.glob(File.join(plugins_ordner, e, '**', '*.rb'))) }
        dateien.each_with_object({}) do |f, h|
          s = (File.stat(f) rescue nil)
          h[File.expand_path(f)] = [s.mtime.to_f, s.size] if s
        end
      end

      # aktuellen Stand als geladen merken (nach eigenem Neuladen oder „Plugins aktualisieren“)
      def stand_merken
        @letzter = stand
        @kandidat = nil
      end

      # ---------- Wächter ----------

      def beobachten(sekunden = 2)
        return unless defined?(UI) && UI.respond_to?(:start_timer)
        UI.stop_timer(@timer) if @timer && UI.respond_to?(:stop_timer)
        stand_merken
        @timer = nil
        @timer = UI.start_timer(sekunden, true) { pruefen }
      end

      # Ein Takt des Wächters; gibt die neu geladenen Erweiterungen zurück (oder nil)
      def pruefen
        return if @laeuft
        jetzt = stand
        @letzter ||= jetzt
        return @kandidat = nil if jetzt == @letzter
        # Installation noch im Gange? Erst laden, wenn sich zwei Takte lang nichts mehr tut
        if jetzt != @kandidat
          @kandidat = jetzt
          return
        end
        geaendert = jetzt.keys.reject { |f| @letzter[f] == jetzt[f] }
        stand_merken
        return if geaendert.empty?
        neu_laden(geaendert, still: true)
      rescue StandardError => e
        @kandidat = nil
        status("Neuladen fehlgeschlagen: #{e.message}")
        nil
      end

      # ---------- Neu laden ----------

      # dateien: geänderte Dateien (Pfade im Plugins-Ordner); nil = alles neu laden.
      # Lädt zuerst die gemeinsamen Dateien, dann main.rb jeder betroffenen, eingeschalteten
      # Erweiterung (main.rb lädt ihre weiteren Dateien selbst). Gibt die Namen der neu
      # geladenen Erweiterungen zurück. still: nur Statuszeile, Meldung nur bei Fehlern.
      def neu_laden(dateien = nil, still: false)
        return [] if @laeuft
        @laeuft = true
        verbose = $VERBOSE
        begin
          $VERBOSE = nil # „already initialized constant“ beim erneuten Laden unterdrücken
          fehler = []
          geladen = laden(dateien, fehler)
          stand_merken
          melden(geladen, fehler, still)
          geladen
        ensure
          $VERBOSE = verbose
          @laeuft = false
        end
      end

      def laden(dateien, fehler)
        basis = File.expand_path(plugins_ordner)
        rel = (dateien || stand.keys).map { |f| File.expand_path(f, basis).sub("#{basis}/", '') }
        gemeinsam = rel.select { |r| r.start_with?('kuechenplaner_gemeinsam/') && r.end_with?('.rb') }.uniq.sort
        ordner = rel.select { |r| r.include?('/') }.map { |r| r.split('/').first }.uniq & erweiterungen
        # Plugins aktualisieren zuletzt: es kann gerade selbst laufen
        ordner = ordner.sort.partition { |o| o != 'kuechenplaner_update' }.flatten
        gemeinsam.each { |r| sicher(fehler, r) { load File.join(basis, r) } }
        ordner.each_with_object([]) do |o, geladen|
          next unless eingeschaltet?(o)
          sicher(fehler, o) do
            load File.join(basis, o, 'main.rb')
            geladen << o
          end
        end
      end

      # Ist die Erweiterung zu <ordner>/main in SketchUp registriert und eingeschaltet?
      # Nicht registriert -> nein (eine neue Erweiterung lädt SketchUp beim Installieren selbst).
      def eingeschaltet?(ordner)
        return true unless defined?(Sketchup) && Sketchup.respond_to?(:extensions)
        muster = %r{(?:\A|/)#{Regexp.escape(ordner.downcase)}/main(?:\.rb[es]?)?\z}
        bekannt = false
        Sketchup.extensions.each do |e|
          next unless e.respond_to?(:extension_path)
          bekannt = true
          return e.loaded? if e.extension_path.to_s.tr('\\', '/').downcase =~ muster
        end
        !bekannt # SketchUp ohne extension_path: laden
      end

      def sicher(fehler, name)
        yield
      rescue ScriptError, StandardError => e
        fehler << "#{name}: #{e.class}: #{e.message}"
      end

      def melden(geladen, fehler, still)
        text = geladen.empty? ? 'nichts neu geladen' : "neu geladen: #{geladen.join(', ')}"
        status(fehler.empty? ? text : "#{text} – #{fehler.size} Fehler")
        return if still && fehler.empty?
        return unless defined?(UI) && UI.respond_to?(:messagebox)
        msg = "Küchenplaner – #{text.sub(/\A./, &:upcase)}."
        msg += "\n\nFehler (alter Stand bleibt aktiv):\n#{fehler.join("\n")}" unless fehler.empty?
        msg += "\n\nDie Änderungen gelten ab sofort, ohne Neustart von SketchUp." if fehler.empty? && !geladen.empty?
        UI.messagebox(msg)
      end

      def status(text)
        return unless defined?(Sketchup) && Sketchup.respond_to?(:status_text=)
        Sketchup.status_text = "Küchenplaner: #{text}"
      end
    end
  end
end

# Wächter starten (beim Neuladen dieser Datei: alten Timer ersetzen)
Kuechenplaner::Neuladen.beobachten
