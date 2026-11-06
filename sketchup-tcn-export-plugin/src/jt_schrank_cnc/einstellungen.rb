# encoding: UTF-8
# Schrank-CNC – allgemeine Einstellungen (gelten für alle Modelle auf diesem Rechner,
# gespeichert mit Sketchup.write_default). Das Fenster zeigt oben zusätzlich die
# Werte der Küche (Sockelhöhe, Abstände) aus gemeinsam/einstellungen.rb und die
# Beschläge der Küche (Beschlagkatalog).
#
# Übermaß: Rohmaß (Zuschnitt an der Formatsäge) = Fräsmaß + Übermaß, damit die CNC
# das Teil rundum formatieren kann (squad). Angabe gesamt je Richtung in mm, also
# 10 mm = 5 mm je Kante. Länge = längere, Breite = kürzere Seite des Teils.
# Das Übermaß stand früher am Material (length_increase/width_increase); nach Jürgen (2026-11-01) ist es eine allgemeine Einstellung.
# Zuschnitt: Schnittbreite des Sägeblatts (Jürgen: 3 mm) und Besäumen ringsum.

module JTools
  module SchrankCnc
    module Einstellungen
      module_function

      SEKTION = 'JT_SchrankCnc'.freeze

      # Schlüssel => [Bezeichnung, Standardwert]
      WERTE = {
        'uebermass_laenge' => ['Übermaß Länge gesamt (mm)', 10.0],
        'uebermass_breite' => ['Übermaß Breite gesamt (mm)', 10.0],
        'schnittbreite' => ['Zuschnitt: Schnittbreite Sägeblatt (mm)', 3.0],
        'besaeumen' => ['Zuschnitt: Besäumen je Plattenkante (mm)', 10.0]
      }.freeze

      def wert(k)
        v = Sketchup.read_default(SEKTION, k, nil)
        v.nil? ? WERTE.fetch(k)[1] : v.to_s.tr(',', '.').to_f
      end

      def setzen(k, v)
        WERTE.fetch(k)
        Sketchup.write_default(SEKTION, k, v.to_f)
      end

      def uebermass_laenge
        wert('uebermass_laenge')
      end

      def uebermass_breite
        wert('uebermass_breite')
      end

      def schnittbreite
        wert('schnittbreite')
      end

      def besaeumen
        wert('besaeumen')
      end

      # Übermaß [in Richtung a, in Richtung b] für ein Teil a × b (mm, gesamt):
      # das Längen-Übermaß gilt für die längere Seite
      def uebermass(a, b)
        a >= b ? [uebermass_laenge, uebermass_breite] : [uebermass_breite, uebermass_laenge]
      end

      CNC_GRUPPE = 'CNC und Zuschnitt – alle Modelle'.freeze
      BESCHLAG_GRUPPE = 'Beschläge – ganze Küche'.freeze

      # Ein Fenster für alles: oben die Werte der Küche (Sockel, Abstände; im Modell gespeichert,
      # gemeinsam/einstellungen.rb), dann die Beschläge der Küche (je Beschlagart ein Modell aus dem
      # Beschlag-Katalog, im Modell gespeichert), unten CNC und Zuschnitt (für alle Modelle auf
      # diesem Rechner). true = gespeichert, false = abgebrochen oder ungültig
      def dialog(model = Sketchup.active_model)
        kueche = Kuechenplaner::Einstellungen
        keys = WERTE.keys
        arten = Beschlagkatalog::ARTEN
        modelle = arten.keys.to_h { |a| [a, Beschlagkatalog.zur_art(a)] }
        prompts = kueche.prompts + arten.map { |_, v| "#{BESCHLAG_GRUPPE}: #{v[:name]}" } +
                  keys.map { |k| "#{CNC_GRUPPE}: #{WERTE[k][0].sub(/\AZuschnitt: /, '')}" }
        alt = kueche.vorgaben(model) + arten.keys.map { |a| Beschlagkatalog.vorschlag(a, model)['name'] } +
              keys.map { |k| Tcn.n(wert(k)) }
        listen = kueche.prompts.map { '' } + arten.keys.map { |a| modelle[a].map { |e| e['name'] }.join('|') } + keys.map { '' }
        n = kueche::WERTE.size
        nb = arten.size
        erg = Kuechenplaner::Eingabe.abfragen(prompts, alt, listen, 'Küchenplaner – Einstellungen',
                                              untertitel: 'Sockel, Abstände, Beschläge, CNC', ok: 'Speichern') do |neu|
          zahlen = neu[(n + nb)..-1].map { |s| s.to_s.strip.tr(',', '.') }
          raise ArgumentError, 'Bitte nur Zahlen ≥ 0 eingeben (mm).' if zahlen.any? { |s| s !~ /\A\d+(\.\d+)?\z/ }
          wahl = arten.keys.each_with_index.to_h do |a, i|
            e = modelle[a].find { |x| x['name'] == neu[n + i].to_s }
            raise ArgumentError, "#{arten[a][:name]}: bitte ein Modell aus der Liste wählen." unless e
            [a, e['kennung']]
          end
          model.start_operation('Einstellungen ändern', true) if model.respond_to?(:start_operation)
          begin
            sockel_alt = kueche.sockelhoehe(model)
            kueche.uebernehmen(neu[0, n], model)
            wahl.each { |a, k| Beschlagkatalog.waehlen(a, k, model) }
            # Sockelhöhe geändert: vorhandene Schränke in der Höhe mitnehmen (Andock-Werkzeug)
            Andocken.sockel_geaendert(model, sockel_alt, kueche.sockelhoehe(model)) if defined?(Andocken)
          ensure
            model.commit_operation if model.respond_to?(:commit_operation)
          end
          keys.zip(zahlen).each { |k, s| setzen(k, s.to_f) }
          # gezeigte Beschläge folgen der neuen Wahl
          Beschlagmodell.nachziehen(model) if defined?(Beschlagmodell)
          true
        end
        erg ? true : false
      rescue ArgumentError => e
        UI.messagebox(e.message)
        false
      end
    end
  end
end
