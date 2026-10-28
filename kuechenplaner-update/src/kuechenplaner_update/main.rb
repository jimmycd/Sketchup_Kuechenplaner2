# encoding: UTF-8
# Küchenplaner – Plugins aktualisieren
#
# Holt den aktuellen Stand aller Küchenplaner-Erweiterungen (alles, was in
# Kuechenplaner_alle.rbz steckt) von GitHub oder aus einem lokalen Repo-Ordner,
# schreibt nur die geänderten Dateien in den Plugins-Ordner und lädt die
# betroffenen Erweiterungen sofort neu. Kein Extension Manager, kein Neustart.
#
# Jede Datei wird gegen ihre Git-Prüfsumme (Blob-SHA aus dem Repo) geprüft; erst
# wenn alle Downloads stimmen, wird geschrieben.
require 'sketchup.rb'
require 'json'
require 'digest/sha1'
require 'fileutils'
require 'uri'

# Gemeinsames Untermenü "Erweiterungen > Küchenplaner" für alle Komponenten und
# den TCN-Export. Steht wortgleich in jeder Erweiterung (der Test prüft das), damit
# das Untermenü nur einmal angelegt wird, egal welche Erweiterungen geladen sind.
# Schränke kommen in Kuechenplaner.untermenu('Unterschränke' | 'Oberschränke' |
# 'Hochschränke'), Geräte in 'Geräte', Werkzeuge direkt in Kuechenplaner.menu darunter.
module Kuechenplaner
  GRUPPEN = ['Unterschränke', 'Oberschränke', 'Hochschränke', 'Geräte'].freeze

  def self.menu
    @menu ||= UI.menu('Extensions').add_submenu('Küchenplaner')
  end

  # Alle Gruppen beim ersten Aufruf anlegen, damit die Reihenfolge nicht von der
  # Ladereihenfolge der Erweiterungen abhängt.
  def self.untermenu(gruppe)
    @untermenues ||= GRUPPEN.each_with_object({}) { |g, h| h[g] = menu.add_submenu(g) }
    @untermenues.fetch(gruppe)
  end
end unless defined?(Kuechenplaner.untermenu)

module KuechenplanerUpdate
  REPO  = 'jimmycd/sketchup_kuechenplaner2'.freeze
  ZWEIG = 'main'.freeze
  API   = "https://api.github.com/repos/#{REPO}".freeze
  RAW   = "https://raw.githubusercontent.com/#{REPO}".freeze
  # Quelltext einer Erweiterung im Repo: <ordner>/src/<pfad> oder Komponenten/<name>/src/<pfad>;
  # <pfad> ist der Pfad im Plugins-Ordner (wie in der .rbz)
  SRC = %r{\A(?:Komponenten/[^/]+|[^/]+)/src/(.+)\z}.freeze
  TITEL = 'Küchenplaner – Plugins aktualisieren'.freeze

  class << self
    attr_writer :plugins_ordner

    # Plugins-Ordner, in dem diese Erweiterung (und damit alle anderen) installiert ist
    def plugins_ordner
      @plugins_ordner || File.expand_path('..', File.dirname(__FILE__))
    end

    # ---------- Menü-Aktionen ----------

    # Neuesten Stand von GitHub (Zweig main) holen
    def von_github
      status('prüfe GitHub …')
      holen("#{API}/commits/#{ZWEIG}") do |text, fehler|
        next melden("GitHub nicht erreichbar (#{fehler}).") if fehler
        commit = JSON.parse(text.force_encoding('UTF-8'))
        sha = commit['sha']
        info = commit['commit'] || {}
        stand = "#{info.dig('committer', 'date').to_s[0, 10]} – #{info['message'].to_s.lines.first.to_s.strip}"
        holen("#{API}/git/trees/#{sha}?recursive=1") do |baum, fehler2|
          next melden("Dateiliste nicht lesbar (#{fehler2}).") if fehler2
          baum = JSON.parse(baum.force_encoding('UTF-8'))
          next melden('Dateiliste von GitHub unvollständig.') if baum['truncated']
          eintraege = baum['tree'].select { |e| e['type'] == 'blob' }.map { |e| [e['path'], e['sha']] }
          plan = geaendert(zuordnen(eintraege))
          next melden("Alles aktuell (GitHub #{ZWEIG}, Stand #{stand}).") if plan.empty?
          next status('') unless bestaetigen(plan, "GitHub #{ZWEIG}, Stand #{stand}")
          herunterladen(sha, plan.to_a, {}) do |dateien, fehler3|
            next melden("Download fehlgeschlagen, nichts geändert: #{fehler3}") if fehler3
            fertig(installieren(dateien), "GitHub #{ZWEIG}, Stand #{stand}")
          end
        end
      end
    end

    # Stand aus einem lokalen Repo-Ordner laden (z. B. ein Klon von GitHub)
    def von_ordner(ordner = nil)
      unless ordner
        opt = { title: 'Repo-Ordner des Küchenplaners wählen' }
        letzter = Sketchup.read_default('KuechenplanerUpdate', 'ordner')
        opt[:directory] = letzter if letzter && File.directory?(letzter)
        ordner = UI.select_directory(opt)
      end
      return unless ordner
      eintraege = repo_dateien(ordner)
      return melden("In #{ordner} keine Küchenplaner-Erweiterungen gefunden (erwartet: Komponenten/*/src).") if eintraege.empty?
      Sketchup.write_default('KuechenplanerUpdate', 'ordner', ordner)
      plan = geaendert(zuordnen(eintraege.map { |p, d| [p, blob_sha(d)] }))
      return melden("Alles aktuell (Ordner #{ordner}).") if plan.empty?
      return unless bestaetigen(plan, "Ordner #{ordner}")
      inhalt = Hash[eintraege]
      fertig(installieren(plan.map { |ziel, (pfad, _)| [ziel, inhalt[pfad]] }.to_h), "Ordner #{ordner}")
    end

    # ---------- Ablauf ----------

    # Git-Prüfsumme einer Datei (wie "git hash-object")
    def blob_sha(daten)
      Digest::SHA1.hexdigest("blob #{daten.bytesize}\0".b + daten.b)
    end

    # [[repo_pfad, sha], ...] -> { pfad_im_plugins_ordner => [repo_pfad, sha] }
    def zuordnen(eintraege)
      eintraege.each_with_object({}) do |(pfad, sha), h|
        ziel = pfad[SRC, 1]
        h[ziel] = [pfad, sha] if ziel
      end
    end

    # nur Dateien, die im Plugins-Ordner fehlen oder anders sind
    def geaendert(zuordnung)
      zuordnung.reject do |ziel, (_, sha)|
        datei = File.join(plugins_ordner, ziel)
        File.file?(datei) && blob_sha(File.binread(datei)) == sha
      end
    end

    # alle Erweiterungs-Dateien eines lokalen Repo-Ordners: [[repo_pfad, inhalt], ...]
    def repo_dateien(ordner)
      Dir.glob('{Komponenten/*,*}/src/**/*', base: ordner).sort.uniq
         .select { |p| p =~ SRC && File.file?(File.join(ordner, p)) }
         .map { |p| [p, File.binread(File.join(ordner, p))] }
    end

    # Dateien nacheinander laden und prüfen; ruft den Block mit { ziel => inhalt } oder Fehler auf
    def herunterladen(commit, offen, fertig, &blk)
      return blk.call(fertig, nil) if offen.empty?
      ziel, (pfad, sha) = offen.first
      status("lade #{ziel} (#{fertig.size + 1}/#{fertig.size + offen.size}) …")
      url = "#{RAW}/#{commit}/#{pfad.split('/').map { |s| URI.encode_www_form_component(s).gsub('+', '%20') }.join('/')}"
      holen(url) do |daten, fehler|
        next blk.call(nil, "#{pfad}: #{fehler}") if fehler
        next blk.call(nil, "#{pfad}: Prüfsumme falsch") unless blob_sha(daten) == sha
        herunterladen(commit, offen.drop(1), fertig.merge(ziel => daten), &blk)
      end
    end

    # Dateien schreiben und die betroffenen Erweiterungen neu laden.
    # Gibt die Namen der neu geladenen Erweiterungsordner zurück.
    def installieren(dateien)
      lader_neu = dateien.keys.reject { |z| z.include?('/') || File.exist?(File.join(plugins_ordner, z)) }
      dateien.each do |ziel, daten|
        datei = File.join(plugins_ordner, ziel)
        FileUtils.mkdir_p(File.dirname(datei))
        File.binwrite(datei, daten)
      end
      neu_laden(dateien.keys, lader_neu)
    end

    def neu_laden(ziele, lader_neu)
      ordner = ziele.select { |z| z.include?('/') }.map { |z| z.split('/').first }.uniq.sort
      ordner -= lader_neu.map { |l| File.basename(l, '.rb') }
      # diese Erweiterung selbst zuletzt, sie wird dabei ersetzt
      ordner = ordner.partition { |o| o != 'kuechenplaner_update' }.flatten
      geladen = []
      # neue Erweiterungen registrieren (lädt sie auch)
      lader_neu.sort.each do |l|
        load File.join(plugins_ordner, l)
        geladen << File.basename(l, '.rb')
      end
      # vorhandene, eingeschaltete Erweiterungen neu laden
      ordner.each do |o|
        main = File.join(plugins_ordner, o, 'main.rb')
        next unless File.file?(main) && eingeschaltet?(o)
        load main
        geladen << o
      end
      geladen
    end

    # Ist die Erweiterung zu <ordner>/main in SketchUp eingeschaltet? Unbekannt -> ja
    def eingeschaltet?(ordner)
      muster = %r{(?:\A|/)#{Regexp.escape(ordner.downcase)}/main(?:\.rb[es]?)?\z}
      Sketchup.extensions.each do |e|
        next unless e.respond_to?(:extension_path)
        return e.loaded? if e.extension_path.to_s.tr('\\', '/').downcase =~ muster
      end
      true
    end

    # ---------- SketchUp-Oberfläche ----------

    def holen(url, &blk)
      anfrage = Sketchup::Http::Request.new(url, Sketchup::Http::GET)
      anfrage.headers = { 'User-Agent' => 'Kuechenplaner-Update', 'Accept' => '*/*' }
      (@anfragen ||= []) << anfrage # Referenz halten, sonst räumt Ruby die Anfrage weg
      anfrage.start do |_req, antwort|
        @anfragen.delete(anfrage)
        if antwort.status_code == 200
          blk.call(antwort.body.to_s.b, nil)
        else
          blk.call(nil, "HTTP #{antwort.status_code}")
        end
      end
    rescue StandardError => e
      blk.call(nil, e.message)
    end

    def bestaetigen(plan, quelle)
      erw = plan.keys.map { |z| z.include?('/') ? z.split('/').first : File.basename(z, '.rb') }.uniq.sort
      UI.messagebox("Neue Version gefunden (#{quelle}).\n\n#{plan.size} Datei(en) in #{erw.size} Erweiterung(en):\n" \
                    "#{erw.join(', ')}\n\nJetzt installieren und neu laden?", MB_YESNO) == IDYES
    end

    def fertig(geladen, quelle)
      melden("Aktualisiert (#{quelle}).\n\nNeu geladen: #{geladen.empty? ? '–' : geladen.join(', ')}\n\n" \
             'Die Änderungen gelten ab sofort. Neue Menüeinträge stehen bis zum nächsten Start von SketchUp ' \
             'am Ende des Küchenplaner-Menüs.')
    end

    def melden(text)
      status('')
      UI.messagebox(text)
    end

    def status(text)
      Sketchup.status_text = text.empty? ? '' : "Küchenplaner: #{text}"
    end
  end

  unless file_loaded?(__FILE__)
    # Ganz unten im Küchenplaner-Menü: der Timer läuft erst, wenn SketchUp alle
    # Erweiterungen geladen hat (nach TCN-Export und Frontfarbe)
    UI.start_timer(0, false) do
      menu = Kuechenplaner.menu
      menu.add_separator
      menu.add_item('Plugins aktualisieren (GitHub)…') { KuechenplanerUpdate.von_github }
      menu.add_item('Plugins aus Ordner laden…') { KuechenplanerUpdate.von_ordner }
    end
    file_loaded(__FILE__)
  end
end
