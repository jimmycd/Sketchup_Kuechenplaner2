# encoding: UTF-8
# Schrank-CNC – Export: ein Dialog für alle Ausgaben (Symbolleisten-Icon „Export“ und
# Menü Küchenplaner › Export…). Abgefragt werden Stückliste, Etiketten, Zuschnittplan und
# TCN (je ja/nein) und der Zielordner; danach, nur wenn gewählt, das Etikettenformat und
# die Zuschnitt-Optionen. Alles kommt aus EINEM Export-Lauf (Export.erzeugen), daher haben
# Stückliste, Etiketten, Zuschnittplan und TCN-Dateien immer dieselben Nummern.
#
# Zielordner:
#   Stueckliste_<Modell>.pdf / .csv (+ _Beschlaege.csv)   Stückliste mit Beschlagliste
#   Etiketten.pdf, Zuschnitt.pdf
#   tcn/<Nr>_<Tag>.tcn und tcn/Liste_<Zielordner>.xmlst    CNC-Programme und Fräsliste
# Alte .tcn/.xmlst im Unterordner tcn werden vorher gelöscht, damit dort nur die Teile des
# aktuellen Exports liegen (sonst landen Teile eines alten Stands in der Fräsliste/Maschine).

require 'fileutils'

module JTools
  module SchrankCnc
    module Ausgabe
      module_function

      DICT = 'JT_Ausgabe'
      # [Schlüssel, Beschriftung im Dialog]
      TEILE = [['stueckliste', 'Ausgabe: Stückliste (PDF und CSV, mit Beschlagliste)'],
               ['etiketten', 'Ausgabe: Etiketten (PDF)'],
               ['zuschnitt', 'Ausgabe: Zuschnittplan (PDF)'],
               ['tcn', 'Ausgabe: TCN-Dateien und Fräsliste (Unterordner tcn)']].freeze
      TCN_ORDNER = 'tcn'

      def gewaehlt_lesen
        TEILE.to_h { |k, _| [k, Sketchup.read_default(DICT, k, 'ja').to_s == 'ja'] }
      end

      # Zuletzt benutzter Zielordner dieses Modells, sonst <Modellordner>/Export_<Modell>
      def ordner_vorschlag(model)
        o = model.respond_to?(:get_attribute) ? model.get_attribute(DICT, 'ordner').to_s : ''
        return o unless o.empty?
        basis = Stueckliste.startordner(model)
        return '' unless basis
        t = model.respond_to?(:title) ? model.title.to_s.strip.gsub(/[\\\/:*?"<>|]/, '_') : ''
        File.join(basis, t.empty? ? 'Export' : "Export_#{t}")
      end

      def tcn_ordner(ordner)
        File.join(ordner, TCN_ORDNER)
      end

      # Alte TCN und Fräslisten im Unterordner tcn löschen (nur dort, nur diese Endungen)
      def tcn_aufraeumen(dir)
        Dir.glob(File.join(dir.tr('\\', '/'), '*')).each do |f|
          File.delete(f) if File.file?(f) && f =~ /\.(tcn|xmlst)\z/i
        end
      end

      # Die gewählten Ausgaben in den Ordner schreiben. daten: { dateien:, zs:, meldungen:,
      # stueckliste_meldungen:, beschlaege: }; wahl: { 'stueckliste' => true, … };
      # etiketten: [format, start], zuschnitt: [optionen, formate]. Gibt die Zeilen der Meldung zurück.
      def schreiben(model, ordner, daten, wahl, etiketten: nil, zuschnitt: nil)
        FileUtils.mkdir_p(ordner)
        zs = daten[:zs]
        text = []
        if wahl['stueckliste']
          t = model.respond_to?(:title) && !model.title.to_s.strip.empty? ? "Stückliste #{model.title.to_s.strip}" : nil
          p, c = Stueckliste.schreiben(File.join(ordner, Stueckliste.dateiname(model)), zs, daten[:stueckliste_meldungen],
                                       titel: t, beschlaege: daten[:beschlaege])
          text << "Stückliste (#{zs.sum(&:anzahl)} Teile#{daten[:beschlaege].empty? ? '' : ', Beschlagliste auf der letzten Seite'}): " \
                  "#{File.basename(p)}, #{File.basename(c)}"
        end
        if wahl['etiketten']
          f, start = etiketten
          p = Etiketten.schreiben(ordner, zs, f, start: start)
          text << "#{Etiketten.stuecke(zs).size} Etiketten: #{File.basename(p)}"
        end
        if wahl['zuschnitt']
          o, formate = zuschnitt
          gruppen = Zuschnitt.berechnen(model, zs, o, formate)
          zm = daten[:stueckliste_meldungen] + Zuschnitt.meldungen_zu(gruppen, zs)
          p = Zuschnitt.schreiben(ordner, gruppen, o, zm)
          text << "Zuschnittplan (#{gruppen.sum { |g| g.platten.size }} Platten): #{File.basename(p)}"
        end
        if wahl['tcn']
          dir = tcn_ordner(ordner)
          FileUtils.mkdir_p(dir)
          tcn_aufraeumen(dir)
          liste = Fraesliste.name(ordner)
          Export.schreiben(dir, daten[:dateien], liste: liste)
          text << "#{daten[:dateien].size} TCN-Dateien (#{daten[:dateien].sum(&:anzahl)} Teile) und #{liste}: Unterordner #{TCN_ORDNER}"
        end
        text
      end

      def dialog(model = Sketchup.active_model)
        Roentgen.zuruecksetzen(model) if defined?(Roentgen) # Teile in Modell-Lage rechnen
        auswahl = model.selection.to_a.empty? ? nil : model.selection.to_a
        ws = []
        dateien, meldungen = Export.erzeugen(model, auswahl: auswahl, alle_ws: ws)
        if dateien.empty?
          UI.messagebox('Keine Schrankteile gefunden (Teile mit Tag und JT_Schrank, sichtbar).')
          return
        end
        zs, st_meldungen, beschlaege = Stueckliste.aus_export(dateien, meldungen, ws)
        daten = { dateien: dateien, zs: zs, meldungen: meldungen, stueckliste_meldungen: st_meldungen, beschlaege: beschlaege }
        alt = gewaehlt_lesen
        labels = TEILE.map { |_, l| l } + ['Ziel: Zielordner (wird angelegt, TCN in den Unterordner tcn)']
        werte = TEILE.map { |k, _| alt[k] ? 'ja' : 'nein' } + [ordner_vorschlag(model)]
        listen = TEILE.map { 'ja|nein' } + [':ordner']
        untertitel = auswahl ? 'nur die gewählten Schränke' : 'alle Schränke im Modell'
        Kuechenplaner::Eingabe.abfragen(labels, werte, listen, 'Export', untertitel: untertitel, ok: 'Weiter') do |antwort|
          wahl = TEILE.each_with_index.to_h { |(k, _), i| [k, antwort[i].to_s == 'ja'] }
          ordner = antwort[TEILE.size].to_s.strip
          raise ArgumentError, 'bitte mindestens eine Ausgabe wählen' if wahl.values.none?
          raise ArgumentError, 'bitte einen Zielordner angeben' if ordner.empty?
          if wahl['zuschnitt'] && zs.none? { |z| z.hinweis != 'Arbeitsplatte' && !z.material.empty? }
            raise ArgumentError, 'Zuschnittplan: keine Teile mit Material'
          end
          wahl.each { |k, v| Sketchup.write_default(DICT, k, v ? 'ja' : 'nein') }
          model.set_attribute(DICT, 'ordner', ordner) if model.respond_to?(:set_attribute)
          etiketten_schritt(wahl) do |etik|
            zuschnitt_schritt(model, zs, wahl) do |zus|
              fertig(model, ordner, daten, wahl, auswahl, etik, zus)
            end
          end
        end
      rescue ArgumentError => e
        UI.messagebox(e.message)
      end

      # Etikettenformat nur abfragen, wenn Etiketten gewählt sind
      def etiketten_schritt(wahl, &weiter)
        return weiter.call(nil) unless wahl['etiketten']
        Etiketten.abfragen { |f, start| weiter.call([f, start]) }
      end

      def zuschnitt_schritt(model, zs, wahl, &weiter)
        return weiter.call(nil) unless wahl['zuschnitt']
        Zuschnitt.abfragen(model, zs) { |o, formate| weiter.call([o, formate]) }
      end

      def fertig(model, ordner, daten, wahl, auswahl, etik, zus)
        text = schreiben(model, ordner, daten, wahl, etiketten: etik, zuschnitt: zus)
        UI.openURL("file:///#{ordner.tr('\\', '/').sub(%r{\A/+}, '')}")
        m = "Export#{auswahl ? ' (nur Auswahl)' : ''} in\n#{ordner}\n\n" + text.map { |t| "• #{t}" }.join("\n")
        m += "\n\nPDFs drucken mit „Tatsächliche Größe“ (Etiketten 100 %)." if wahl['stueckliste'] || wahl['etiketten'] || wahl['zuschnitt']
        hinweise = (daten[:meldungen] + daten[:stueckliste_meldungen]).uniq
        m += "\n\nHinweise:\n" + hinweise.first(15).join("\n") unless hinweise.empty?
        m += "\n…" if hinweise.size > 15
        UI.messagebox(m)
      rescue SystemCallError => e
        UI.messagebox("Export konnte nicht geschrieben werden (ist eine PDF noch geöffnet?):\n#{e.message}")
      end
    end
  end
end
