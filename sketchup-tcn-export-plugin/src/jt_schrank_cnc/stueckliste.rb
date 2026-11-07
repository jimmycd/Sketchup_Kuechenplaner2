# encoding: UTF-8
# Schrank-CNC – Stückliste.
#
# Eine Zeile je TCN-Datei des Exports (gleiche Teile zusammengefasst, Anzahl), damit
# Stückliste, TCN-Dateien und Fräsliste immer zusammenpassen. Drei Maße je Teil:
#   Fertigmaß = Maß im Modell (mit Anleimer)
#   Fräsmaß   = Fertigmaß minus Anleimer an jeder Kante mit Anleimer (= DL/DH der TCN)
#   Rohmaß    = Fräsmaß plus Übermaß aus den Einstellungen (Zuschnitt an der Formatsäge)
# Länge (L) ist die längere, Breite (B) die kürzere Seite; bei Platten mit Maserung ist L
# die Seite in Faserrichtung (Materialien.maser_achse, Fronten senkrecht). Kanten: L1/L2 sind die
# beiden Längskanten, B1/B2 die beiden Querkanten; im Feld steht das Anleimer-Material.
# Schräg- und Bogenkanten (Abschlussregal) stehen unter "Kante Kontur" mit ihrer Länge;
# Roh-, Fräs- und Fertigmaß sind dort das umschließende Rechteck (Kontur fräst die CNC).
# Ausgabe: Stueckliste.pdf (A4 quer, je Material und Stärke eine Tabelle mit Summen, mit
# dem eigenen PDF-Schreiber pdf.rb wie Etiketten und Zuschnittplan) und daneben
# Stueckliste.csv (Semikolon, Dezimalkomma, für Excel). Geschrieben über den Export-Dialog (ausgabe.rb).

module JTools
  module SchrankCnc
    module Stueckliste
      module_function

      KOPF = %w[Nr Tag TCN-Datei Anzahl Schrank Teil Rolle Material Stärke Roh\ L Roh\ B
                Fräs\ L Fräs\ B Fertig\ L Fertig\ B Kante\ L1 Kante\ L2 Kante\ B1 Kante\ B2 Maserung Kante\ Kontur].freeze

      Zeile = Struct.new(:nr, :tag, :datei, :anzahl, :schrank, :teil, :rolle, :material, :ds,
                         :fertig, :fraes, :roh, :kanten, :maserung, :hinweis, :kontur, :quelle) do
        # Kantenlänge je Kante (Fertigmaß), L1/L2 entlang der Länge
        def kantenlaenge(k)
          k.to_s.start_with?('l') ? fertig[0] : fertig[1]
        end
      end

      def zeile(d)
        ws = d.ws
        t = ws.teil
        mat = t.inst.material
        z = Zeile.new(nil, t.name, d.datei, d.anzahl, t.jt('schrank'), t.jt('teil'), t.rolle,
                      mat ? mat.name.to_s : '', d.lage.ds.round(1))
        z.quelle = d
        z.maserung = Materialien.maserung?(mat)
        z.kontur = ws.respond_to?(:kontur_kanten) && ws.kontur_kanten ? ws.kontur_kanten.to_h : {}
        if ws.respond_to?(:kanten)
          ax = Geometrie::ACHSEN
          la, ba = ws.flaechen_achsen.sort_by { |a| [-(ws.hi_f(a) - ws.lo_f(a)).round(3), a] }
          if z.maserung
            # mit Maserung ist L die Seite in Faserrichtung (Fronten senkrecht, siehe Materialien)
            laengen = (0..2).map { |a| ws.hi_f(a) - ws.lo_f(a) }
            la = Materialien.maser_achse(t, ws.flaechen_achsen, laengen)
            ba = (ws.flaechen_achsen - [la]).first
          end
          z.fertig = [ws.mass(la), ws.mass(ba)]
          z.fraes = [ws.hi_f(la) - ws.lo_f(la), ws.hi_f(ba) - ws.lo_f(ba)]
          km = ws.kanten_mat || {}
          z.kanten = { l1: km[:"#{ax[ba]}min"], l2: km[:"#{ax[ba]}max"],
                       b1: km[:"#{ax[la]}min"], b2: km[:"#{ax[la]}max"] }
          ue = Einstellungen.uebermass(*z.fraes)
          z.roh = [z.fraes[0] + ue[0], z.fraes[1] + ue[1]]
        else
          # Arbeitsplatte: Maße aus dem Arbeitsplatten-Export, Zuschnitt von Hand; Länge immer
          # längs der Küchenzeile (auch bei kurzen Teilplatten nach einem Längsstoß)
          l, b = d.lage.dl, d.lage.dh
          z.fertig = z.fraes = z.roh = [l, b]
          z.kanten = {}
          z.hinweis = 'Arbeitsplatte'
        end
        z
      end

      # Zeilen sortiert nach Material, Stärke (dick zuerst), Rohfläche (groß zuerst), Tag
      def zeilen(dateien)
        gesehen = {}.compare_by_identity
        zs = dateien.each_with_object([]) do |d, out|
          # eine Arbeitsplatte mit zwei Stoßenden hat zwei TCN, aber nur eine Zeile (beide Dateien darin)
          if !d.ws.respond_to?(:kanten) && (z = gesehen[d.ws.teil.inst])
            z.datei = "#{z.datei}, #{d.datei}"
            next
          end
          out << (gesehen[d.ws.teil.inst] = zeile(d))
        end
        zs = zs.sort_by { |z| [z.material, -z.ds, -(z.roh[0] * z.roh[1]).round(1), z.tag.to_s] }
        zs.each_with_index { |z, i| z.nr = i + 1 }
      end

      # Ergebnis: [Zeilen, Meldungen, Beschläge (Beschlaege::Posten)]
      def erzeugen(model, auswahl: nil)
        ws = []
        dateien, export_meldungen = Export.erzeugen(model, auswahl: auswahl, alle_ws: ws)
        aus_export(dateien, export_meldungen, ws)
      end

      # Stückliste aus einem fertigen Export (Export.erzeugen mit alle_ws: ws), damit Stückliste,
      # Etiketten, Zuschnitt und TCN-Dateien aus demselben Lauf dieselben Nummern haben
      def aus_export(dateien, export_meldungen, ws)
        zs = zeilen(dateien)
        meldungen = zs.select { |z| z.material.empty? }.map { |z| "#{z.tag}: kein Material" }
        # Höhen-/Tiefenprobleme der Schubladen gehören auch auf die Stückliste
        meldungen += export_meldungen.select { |m| m.include?('LEGRABOX') }
        [zs, meldungen, Beschlaege.liste(ws)]
      end

      # Gruppen je [Material, Stärke] mit Summen
      def gruppen(zs)
        zs.group_by { |z| [z.material, z.ds] }.map do |(mat, ds), g|
          lfm = Hash.new(0.0)
          g.each { |z| z.kanten.each { |k, m| lfm[m] += z.kantenlaenge(k) * z.anzahl / 1000.0 if m } }
          g.each { |z| z.kontur.each { |m, l| lfm[m] += l * z.anzahl / 1000.0 } }
          { material: mat, ds: ds, zeilen: g, stueck: g.sum(&:anzahl),
            flaeche: g.sum { |z| z.roh[0] * z.roh[1] * z.anzahl } / 1e6, kanten_lfm: lfm }
        end
      end

      def zahl(v)
        Tcn.n(v.to_f.round(1)).tr('.', ',')
      end

      def csv(zs)
        out = [KOPF.join(';')]
        zs.each do |z|
          out << [z.nr, z.tag, z.datei, z.anzahl, z.schrank, z.teil, z.rolle, z.material, zahl(z.ds),
                  *z.roh.map { |v| zahl(v) }, *z.fraes.map { |v| zahl(v) }, *z.fertig.map { |v| zahl(v) },
                  *%i[l1 l2 b1 b2].map { |k| z.kanten[k].to_s }, z.maserung ? 'ja' : 'nein', kontur_text(z)]
                 .map { |v| v.to_s.tr(';', ',') }.join(';')
        end
        out.join("\r\n") + "\r\n"
      end

      # "Anleimer Melamin weiss 412 mm" je Material der Schräg-/Bogenkante
      def kontur_text(z, kz = nil)
        z.kontur.sort.map { |m, l| "#{kz ? kz[m] : m} #{zahl(l.round(1))} mm" }.join(', ')
      end

      def h(s)
        s.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub('"', '&quot;')
      end

      def mass(a)
        "#{zahl(a[0])} × #{zahl(a[1])}"
      end

      SEITE = [297.0, 210.0].freeze # A4 quer
      RAND = 10.0
      # Spalten der Tabelle (Summe 277 mm = A4 quer minus 2 × 10 mm Rand); Rohmaß fett
      SPALTEN = [['Nr', 8, :rechts], ['Tag', 48, :links], ['Schrank', 14, :links], ['Teil', 56, :links],
                 ['Anz.', 8, :rechts], ['Rohmaß L × B', 26, :rechts], ['Fräsmaß', 24, :rechts],
                 ['Fertigmaß', 24, :rechts], ['L1', 6, :mitte], ['L2', 6, :mitte], ['B1', 6, :mitte],
                 ['B2', 6, :mitte], ['TCN-Datei', 45, :links]].freeze
      GR = 2.5       # Schriftgröße der Tabelle mm (≈ 7 pt)
      ZH = 4.4       # Zeilenhöhe mm
      Y_MAX = 198.0  # unterste Tabellenzeile, darunter der Seitenfuß

      # Anleimer-Materialien als Kürzel A, B, C …
      def kuerzel(zs)
        zs.flat_map { |z| z.kanten.values + z.kontur.keys }.compact.uniq.sort
          .each_with_index.to_h { |m, i| [m, ('A'.ord + i).chr] }
      end

      def tabellenzeile(z, kz)
        teil = z.teil.to_s
        teil += " (#{z.hinweis})" if z.hinweis
        teil += " (Kontur: #{kontur_text(z, kz)})" unless z.kontur.empty?
        [z.nr, z.tag, z.schrank, teil, z.anzahl, mass(z.roh), mass(z.fraes), mass(z.fertig),
         *%i[l1 l2 b1 b2].map { |k| kz[z.kanten[k]] }, z.datei]
      end

      def summe_text(g, kz)
        t = +"#{g[:stueck]} Teile, Rohfläche #{zahl(g[:flaeche].round(2))} m²"
        g[:kanten_lfm].sort.each { |m, l| t << ", Anleimer #{kz[m]} #{zahl(l.round(1))} m" }
        t
      end

      # Stückliste als PDF (Pdf-Objekt): Kopf mit Erklärung, Legende und Hinweisen, dann je
      # Material und Stärke eine Tabelle mit Summenzeile; Tabellen laufen über mehrere Seiten
      # (Spaltenköpfe auf jeder Seite wiederholt), Fuß mit Titel und „Seite x von n“.
      def pdf(zs, titel: 'Stückliste', meldungen: [], beschlaege: [])
        kz = kuerzel(zs)
        doc = Pdf.new(titel: titel)
        doc.seite(*SEITE)
        doc.text(RAND, 16, titel, groesse: 6, fett: true, max: 277)
        y = 23.0
        erkl = ["Rohmaß = Fräsmaß + Übermaß (L #{zahl(Einstellungen.uebermass_laenge)} / B #{zahl(Einstellungen.uebermass_breite)} mm); " \
                'Fräsmaß = Fertigmaß − Anleimer. L = längere Seite (mit Maserung: in Faserrichtung).',
                'Kanten: L1/L2 Längskanten, B1/B2 Querkanten; Buchstabe = Anleimer (Legende). Nummern und Tags wie auf Etiketten und Zuschnittplan.']
        erkl.each { |t| doc.text(RAND, y, t, groesse: 2.8, max: 277); y += 4.2 }
        unless kz.empty?
          doc.text(RAND, y, 'Anleimer: ' + kz.map { |m, k| "#{k} = #{m}" }.join(', '), groesse: 2.8, max: 277)
          y += 4.2
        end
        meldungen.first(10).each do |m|
          doc.text(RAND, y, m, groesse: 2.8, farbe: [0.7, 0, 0], max: 277)
          y += 4.2
        end
        y += 2
        gruppen(zs).each do |g|
          ueber = "#{g[:material].empty? ? '(ohne Material)' : g[:material]} – #{zahl(g[:ds])} mm"
          zeilen = g[:zeilen].map { |z| tabellenzeile(z, kz) }
          erste = true
          # Überschrift nur mit Platz für Kopf und mindestens eine Zeile, sonst neue Seite
          until zeilen.empty? && !erste
            if y + 6 + 2 * ZH > Y_MAX
              doc.seite(*SEITE)
              y = 14.0
            end
            doc.text(RAND, y + 4, erste ? ueber : "#{ueber} (Fortsetzung)", groesse: 3.8, fett: true, max: 277)
            y, n = doc.tabelle(RAND, y + 6, SPALTEN, zeilen, Y_MAX, groesse: GR, zeilenhoehe: ZH, fett: [5])
            zeilen = zeilen.drop(n)
            erste = false
          end
          if y + 5 > Y_MAX
            doc.seite(*SEITE)
            y = 14.0
          end
          doc.text(RAND, y + 3.6, summe_text(g, kz), groesse: 2.8, farbe: [0.2, 0.2, 0.2], max: 277)
          y += 9
        end
        beschlagseite(doc, beschlaege) unless beschlaege.empty?
        n = doc.seiten.size
        n.times do |i|
          doc.auf_seite(i) do
            doc.text(RAND, 205, titel, groesse: 2.4, farbe: [0.4, 0.4, 0.4], max: 200)
            doc.text(SEITE[0] - RAND, 205, "Seite #{i + 1} von #{n}", groesse: 2.4, farbe: [0.4, 0.4, 0.4], ausrichtung: :rechts)
          end
        end
        doc
      end

      BESCHLAG_SPALTEN = [['Pos', 10, :rechts], ['Anzahl', 16, :rechts], ['Einheit', 14, :links], ['Beschlag', 92, :links],
                          ['Größe / Hinweis', 70, :links], ['Schränke', 75, :links]].freeze

      # Eigene Seite(n) mit der Beschlagliste: je Gruppe (Schubladen, Schrauben, Türen, Klappen) eine Tabelle
      def beschlagseite(doc, posten)
        doc.seite(*SEITE)
        doc.text(RAND, 16, 'Beschläge', groesse: 6, fett: true, max: 277)
        ausz = Beschlagkatalog.gewaehlt('schubladen')
        zs = ausz['zargen'].map { |k, z| "#{k} #{z['hoehe'].to_f.round(1).to_s.sub(/\.0\z/, '').tr('.', ',')}" }.join(', ')
        ["Schubladen: #{ausz['name']} – höchste Zarge, die passt (#{zs} mm); " \
         'Nennlänge NL wie die Bohrungen in den Seiten.',
         'Türen: Blum-Topfbänder Ø35 mit Montageplatte. Alle Anzahlen aus den Bohrbildern der TCN-Dateien; Artikelnummern nach Blum-Katalog.']
          .each_with_index { |t, i| doc.text(RAND, 23 + 4.2 * i, t, groesse: 2.8, max: 277) }
        y = 31.0
        pos = 0
        posten.group_by(&:gruppe).each do |gruppe, ps|
          zeilen = ps.map { |p| [pos += 1, p.anzahl, p.einheit, p.beschlag, p.hinweis, p.schraenke.join(', ')] }
          erste = true
          until zeilen.empty? && !erste
            if y + 6 + 2 * ZH > Y_MAX
              doc.seite(*SEITE)
              y = 14.0
            end
            doc.text(RAND, y + 4, erste ? gruppe : "#{gruppe} (Fortsetzung)", groesse: 3.8, fett: true, max: 277)
            y, n = doc.tabelle(RAND, y + 6, BESCHLAG_SPALTEN, zeilen, Y_MAX, groesse: GR, zeilenhoehe: ZH, fett: [1])
            zeilen = zeilen.drop(n)
            erste = false
          end
          y += 5
        end
      end

      # pfad = PDF-Datei; die CSV kommt mit gleichem Namen daneben, die Beschläge als <Name>_Beschlaege.csv.
      # Gibt [pdf, csv] zurück.
      def schreiben(pfad, zs, meldungen = [], titel: nil, beschlaege: [])
        pfad = pfad.to_s
        pfad += '.pdf' unless pfad.downcase.end_with?('.pdf')
        csv_pfad = pfad.sub(/\.pdf\z/i, '.csv')
        titel ||= "Stückliste #{File.basename(pfad.tr('\\', '/'), '.*').sub(/\AStueckliste_?/i, '')}".strip
        pdf(zs, titel: titel, meldungen: meldungen, beschlaege: beschlaege).schreiben(pfad)
        Tcn.write(csv_pfad, csv(zs))
        Tcn.write(pfad.sub(/\.pdf\z/i, '_Beschlaege.csv'), Beschlaege.csv(beschlaege)) unless beschlaege.empty?
        [pfad, csv_pfad]
      end

      # Vorschlag für den Dateinamen: Stueckliste_<Modell>.pdf, ohne Modellnamen Stueckliste.pdf
      def dateiname(model)
        t = model.respond_to?(:title) ? model.title.to_s.strip : ''
        t = t.gsub(/[\\\/:*?"<>|]/, '_')
        t.empty? ? 'Stueckliste.pdf' : "Stueckliste_#{t}.pdf"
      end

      def startordner(model)
        p = model.respond_to?(:path) ? model.path.to_s : ''
        p.empty? ? nil : File.dirname(p)
      end
    end
  end
end
