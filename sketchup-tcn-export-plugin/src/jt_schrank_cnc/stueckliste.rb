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
# Ausgabe: Stueckliste.csv (Semikolon, Dezimalkomma, für Excel) und
# Stueckliste.html (Druckseite, je Material und Stärke eine Tabelle mit Summen).

module JTools
  module SchrankCnc
    module Stueckliste
      module_function

      KOPF = %w[Nr Tag TCN-Datei Anzahl Schrank Teil Rolle Material Stärke Roh\ L Roh\ B
                Fräs\ L Fräs\ B Fertig\ L Fertig\ B Kante\ L1 Kante\ L2 Kante\ B1 Kante\ B2 Maserung Kante\ Kontur].freeze

      Zeile = Struct.new(:nr, :tag, :datei, :anzahl, :schrank, :teil, :rolle, :material, :ds,
                         :fertig, :fraes, :roh, :kanten, :maserung, :hinweis, :kontur) do
        # Kantenlänge je Kante (Fertigmaß), L1/L2 entlang der Länge
        def kantenlaenge(k)
          k.to_s.start_with?('l') ? fertig[0] : fertig[1]
        end
      end

      def zeile(d)
        ws = d.ws
        t = ws.teil
        mat = t.inst.material
        z = Zeile.new(nil, t.name, "#{d.name}.tcn", d.anzahl, t.jt('schrank'), t.jt('teil'), t.rolle,
                      mat ? mat.name.to_s : '', d.lage.ds.round(1))
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
          # Arbeitsplatte: Maße aus dem Arbeitsplatten-Export, Zuschnitt von Hand
          l, b = [d.lage.dl, d.lage.dh].sort.reverse
          z.fertig = z.fraes = z.roh = [l, b]
          z.kanten = {}
          z.hinweis = 'Arbeitsplatte'
        end
        z
      end

      # Zeilen sortiert nach Material, Stärke (dick zuerst), Rohfläche (groß zuerst), Tag
      def zeilen(dateien)
        gesehen = {}
        zs = dateien.each_with_object([]) do |d, out|
          # eine Arbeitsplatte mit zwei Stoßenden hat zwei TCN, aber nur eine Zeile
          next if !d.ws.respond_to?(:kanten) && gesehen[d.ws.teil.inst]
          gesehen[d.ws.teil.inst] = true
          out << zeile(d)
        end
        zs = zs.sort_by { |z| [z.material, -z.ds, -(z.roh[0] * z.roh[1]).round(1), z.tag.to_s] }
        zs.each_with_index { |z, i| z.nr = i + 1 }
      end

      def erzeugen(model, auswahl: nil)
        dateien, = Export.erzeugen(model, auswahl: auswahl)
        zs = zeilen(dateien)
        meldungen = zs.select { |z| z.material.empty? }.map { |z| "#{z.tag}: kein Material" }
        [zs, meldungen]
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

      def html(zs, titel: 'Stückliste', meldungen: [])
        # Anleimer-Materialien als Kürzel A, B, C … mit Legende
        kantenmat = zs.flat_map { |z| z.kanten.values + z.kontur.keys }.compact.uniq.sort
        kz = kantenmat.each_with_index.to_h { |m, i| [m, ('A'.ord + i).chr] }
        o = +"<!DOCTYPE html>\n<html lang=\"de\"><head><meta charset=\"utf-8\"><title>#{h(titel)}</title>\n<style>\n"
        o << "@page{size:A4 landscape;margin:10mm}body{font:11px/1.35 Arial,sans-serif;color:#000;margin:0 4mm}\n"
        o << "h1{font-size:18px;margin:6px 0}h2{font-size:14px;margin:14px 0 4px}table{border-collapse:collapse;width:100%;page-break-inside:auto}\n"
        o << "th,td{border:1px solid #888;padding:2px 4px;text-align:left;vertical-align:top}th{background:#eee}td.z{text-align:right;white-space:nowrap}\n"
        o << "tr{page-break-inside:avoid}.roh{font-weight:bold}.sum{margin:3px 0 0;color:#333}.meld{color:#a00}.k{text-align:center}\n"
        o << "</style></head><body>\n<h1>#{h(titel)}</h1>\n"
        o << "<p>Rohmaß = Fräsmaß + Übermaß (L #{zahl(Einstellungen.uebermass_laenge)} / B #{zahl(Einstellungen.uebermass_breite)} mm); "
        o << "Fräsmaß = Fertigmaß − Anleimer. L = längere Seite. Kanten: L1/L2 Längskanten, B1/B2 Querkanten.</p>\n"
        unless kz.empty?
          o << '<p>Anleimer: ' + kz.map { |m, k| "<b>#{k}</b> = #{h(m)}" }.join(', ') + "</p>\n"
        end
        o << "<p class=\"meld\">#{meldungen.map { |m| h(m) }.join('<br>')}</p>\n" unless meldungen.empty?
        gruppen(zs).each do |g|
          o << "<h2>#{h(g[:material].empty? ? '(ohne Material)' : g[:material])} – #{zahl(g[:ds])} mm</h2>\n"
          o << '<table><tr><th>Nr</th><th>Tag</th><th>Schrank</th><th>Teil</th><th>Anz.</th>'
          o << '<th>Rohmaß L × B</th><th>Fräsmaß</th><th>Fertigmaß</th><th>L1</th><th>L2</th><th>B1</th><th>B2</th><th>TCN-Datei</th></tr>' + "\n"
          g[:zeilen].each do |z|
            o << "<tr><td class=\"z\">#{z.nr}</td><td>#{h(z.tag)}</td><td>#{h(z.schrank)}</td><td>#{h(z.teil)}#{z.hinweis ? " (#{h(z.hinweis)})" : ''}#{z.kontur.empty? ? '' : " (Kontur: #{h(kontur_text(z, kz))})"}</td>"
            o << "<td class=\"z\">#{z.anzahl}</td><td class=\"z roh\">#{mass(z.roh)}</td><td class=\"z\">#{mass(z.fraes)}</td><td class=\"z\">#{mass(z.fertig)}</td>"
            %i[l1 l2 b1 b2].each { |k| o << "<td class=\"k\">#{kz[z.kanten[k]]}</td>" }
            o << "<td>#{h(z.datei)}</td></tr>\n"
          end
          o << "</table>\n<p class=\"sum\">#{g[:stueck]} Teile, Rohfläche #{zahl(g[:flaeche].round(2))} m²"
          g[:kanten_lfm].sort.each { |m, l| o << ", Anleimer #{kz[m]} #{zahl(l.round(1))} m" }
          o << "</p>\n"
        end
        o << "</body></html>\n"
      end

      def schreiben(ordner, zs, meldungen = [])
        Tcn.write(File.join(ordner, 'Stueckliste.csv'), csv(zs))
        p = File.join(ordner, 'Stueckliste.html')
        File.binwrite(p, html(zs, titel: "Stückliste #{File.basename(ordner.to_s.tr('\\', '/'))}", meldungen: meldungen).encode('UTF-8').b)
        p
      end

      def dialog(model = Sketchup.active_model)
        auswahl = model.selection.to_a.empty? ? nil : model.selection.to_a
        zs, meldungen = erzeugen(model, auswahl: auswahl)
        if zs.empty?
          UI.messagebox('Keine Schrankteile gefunden (Teile mit Tag und JT_Schrank, sichtbar).')
          return
        end
        ordner = UI.select_directory(title: 'Ordner für die Stückliste')
        return unless ordner
        p = schreiben(ordner, zs, meldungen)
        UI.openURL("file:///#{p.tr('\\', '/').sub(%r{\A/+}, '')}")
        text = "Stückliste mit #{zs.sum(&:anzahl)} Teilen#{auswahl ? ' (nur Auswahl)' : ''}: Stueckliste.csv und Stueckliste.html in\n#{ordner}"
        text += "\n\nHinweise:\n" + meldungen.first(15).join("\n") unless meldungen.empty?
        UI.messagebox(text)
      end
    end
  end
end
