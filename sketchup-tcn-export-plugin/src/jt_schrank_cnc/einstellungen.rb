# encoding: UTF-8
# Schrank-CNC – allgemeine Einstellungen (gelten für alle Modelle auf diesem Rechner,
# gespeichert mit Sketchup.write_default). Das Fenster zeigt oben zusätzlich die
# Werte der Küche (Sockelhöhe, Abstände) aus gemeinsam/einstellungen.rb.
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

      # Ein Fenster für beide Arten: oben die Werte der Küche (Sockel, Abstände; im
      # Modell gespeichert, gemeinsam/einstellungen.rb), unten CNC und Zuschnitt
      # (für alle Modelle auf diesem Rechner).
      # true = gespeichert, false = abgebrochen oder ungültig
      def dialog(model = Sketchup.active_model)
        kueche = Kuechenplaner::Einstellungen
        keys = WERTE.keys
        prompts = kueche.prompts + keys.map { |k| "#{CNC_GRUPPE}: #{WERTE[k][0].sub(/\AZuschnitt: /, '')}" }
        alt = kueche.vorgaben(model) + keys.map { |k| Tcn.n(wert(k)) }
        n = kueche::WERTE.size
        erg = Kuechenplaner::Eingabe.abfragen(prompts, alt, 'Küchenplaner – Einstellungen',
                                              untertitel: 'Sockel, Abstände, CNC', ok: 'Speichern') do |neu|
          zahlen = neu[n..-1].map { |s| s.to_s.strip.tr(',', '.') }
          raise ArgumentError, 'Bitte nur Zahlen ≥ 0 eingeben (mm).' if zahlen.any? { |s| s !~ /\A\d+(\.\d+)?\z/ }
          model.start_operation('Einstellungen ändern', true) if model.respond_to?(:start_operation)
          begin
            kueche.uebernehmen(neu[0, n], model)
          ensure
            model.commit_operation if model.respond_to?(:commit_operation)
          end
          keys.zip(zahlen).each { |k, s| setzen(k, s.to_f) }
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
