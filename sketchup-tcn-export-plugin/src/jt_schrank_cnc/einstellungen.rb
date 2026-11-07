# encoding: UTF-8
# Schrank-CNC – allgemeine Einstellungen (gelten für alle Modelle auf diesem Rechner,
# gespeichert mit Sketchup.write_default). Das Fenster zeigt oben zusätzlich die
# Werte der Küche (Sockelhöhe, Abstände) aus gemeinsam/einstellungen.rb, die
# Beschläge der Küche (Beschlagkatalog) und die Griffserie mit Oberfläche (Griffkatalog).
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

      # Passt der Sockelfuß der Küche zur Sockelhöhe? nil oder Hinweis
      def sockelfuss_hinweis(model)
        e = Beschlagkatalog.kueche('sockelfuss', model)
        s = Kuechenplaner::Einstellungen.sockelhoehe(model).to_f
        return nil if Beschlagkatalog.sockelfuss_hoehe(e, s)['passt']
        bereiche = e['hoehen'].map { |x| "#{x['von']}–#{x['bis']}" }.join(', ')
        "#{e['name']} passt nicht zur Sockelhöhe #{Tcn.n(s)} mm (einstellbar #{bereiche} mm). " \
          'Die Beschlagliste nennt die nächste Höhe; bitte anderes Modell oder andere Sockelhöhe wählen.'
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
        gk = Griffkatalog
        serien = [gk::KEINE] + gk.serien.map { |x| gk.name(x) }
        oberfl = gk.serien.flat_map { |x| gk.oberflaechen(x) }.uniq.sort
        gs = gk.kueche(model)
        gm = Griffmulde
        mf = gm::FELDER.keys
        mw = gm.masse(model)
        prompts = kueche.prompts + arten.map { |_, v| "#{BESCHLAG_GRUPPE}: #{v[:name]}" } +
                  ["#{BESCHLAG_GRUPPE}: Griffserie (Bilder: Griffkatalog…)", "#{BESCHLAG_GRUPPE}: Griff-Oberfläche"] +
                  mf.map { |k| "#{BESCHLAG_GRUPPE}: #{gm::FELDER[k]}" } +
                  keys.map { |k| "#{CNC_GRUPPE}: #{WERTE[k][0].sub(/\AZuschnitt: /, '')}" }
        alt = kueche.vorgaben(model) + arten.keys.map { |a| Beschlagkatalog.vorschlag(a, model)['name'] } +
              [gs ? gk.name(gs) : gk::KEINE, gk.oberflaeche(model) || oberfl.first] + mf.map { |k| Tcn.n(mw[k]) } +
              keys.map { |k| Tcn.n(wert(k)) }
        listen = kueche.prompts.map { '' } + arten.keys.map { |a| modelle[a].map { |e| e['name'] }.join('|') } +
                 [serien.join('|'), oberfl.join('|')] + mf.map { '' } + keys.map { '' }
        n = kueche::WERTE.size
        nb = arten.size
        erg = Kuechenplaner::Eingabe.abfragen(prompts, alt, listen, 'Küchenplaner – Einstellungen',
                                              untertitel: 'Sockel, Abstände, Beschläge, CNC', ok: 'Speichern') do |neu|
          zahlen = neu[(n + nb + 2 + mf.size)..-1].map { |s| s.to_s.strip.tr(',', '.') }
          mneu = mf.each_with_index.to_h { |k, i| [k, neu[n + nb + 2 + i].to_s.strip.tr(',', '.')] }
          raise ArgumentError, 'Griffmulde: bitte nur Zahlen eingeben (mm).' if mneu.values.any? { |s| s !~ /\A\d+(\.\d+)?\z/ }
          mneu = mneu.transform_values(&:to_f)
          f = gm.fehler(mneu) and raise ArgumentError, f
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
            nicht = wahl.flat_map { |a, k| Beschlagkatalog.waehlen(a, k, model) && Beschlagkatalog.nicht_angepasst }
            griff_alt = gk.fingerabdruck(model) + gm.fingerabdruck(model)
            gwahl = gk.serien.find { |x| gk.name(x) == neu[n + nb].to_s }
            gk.waehlen(gwahl && gwahl['kennung'], neu[n + nb + 1].to_s, model)
            gm.setzen(mneu, model)
            griff_neu = gk.fingerabdruck(model) + gm.fingerabdruck(model) != griff_alt
            # Sockelhöhe geändert: vorhandene Schränke in der Höhe mitnehmen (Andock-Werkzeug)
            Andocken.sockel_geaendert(model, sockel_alt, kueche.sockelhoehe(model)) if defined?(Andocken)
          ensure
            model.commit_operation if model.respond_to?(:commit_operation)
          end
          keys.zip(zahlen).each { |k, s| setzen(k, s.to_f) }
          if (h = sockelfuss_hinweis(model))
            UI.messagebox(h)
          end
          unless nicht.empty?
            UI.messagebox("Diese Schränke sind mit einer älteren Version angelegt und passen sich nicht an den " \
                          "Schubladenauszug an: #{nicht.uniq.join(', ')}. Bitte neu anlegen.")
          end
          # gezeigte Beschläge folgen der neuen Wahl
          Beschlagmodell.nachziehen(model) if defined?(Beschlagmodell)
          if griff_neu && defined?(Griffmodell) && model.respond_to?(:start_operation)
            model.start_operation('Griffe', true, false, true)
            Griffmodell.aktualisieren(model)
            model.commit_operation
          end
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
