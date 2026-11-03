# encoding: UTF-8
# Schrank-CNC – Zuschnittplan für die Formatsäge.
#
# Je Material und Stärke werden die Rohmaße der Stückliste mit dem Guillotine-Optimierer
# BinPacking2D (aus OpenCutList übernommen, GPL-3.0, siehe bin_packing_2d/ und
# THIRD_PARTY.md) auf Platten verteilt: nur durchgehende Schnitte, wie an der Formatsäge.
<<<<<<< HEAD
# Plattenformat aus dem Material (Küchenplaner › Materialien…), sonst
=======
# Plattenformat aus dem Material (std_sizes im Material-Wörterbuch, erstes Format), sonst
>>>>>>> origin/main
# 2800 × 2070. Schnittbreite und Besäumen aus den Einstellungen. Maserung am Material:
# dann wird nicht gedreht, die Teillänge (L, in Faserrichtung) liegt längs der Platte.
# Arbeitsplatten bleiben draußen (Zuschnitt von Hand).
# Ausgabe: Zuschnitt.html, Druckseite A4 quer: Übersicht, dann je Platte eine Seite
# mit maßstäblicher Skizze (Teilnummern wie in Stückliste und Etiketten) und
# Schnittliste in Reihenfolge.

module JTools
  module SchrankCnc
    module BinPacking2D; end
    require File.join(File.dirname(__FILE__), 'bin_packing_2d', 'packengine.rb')

    module Zuschnitt
      module_function

      BP = BinPacking2D
      STANDARD_PLATTE = [2800.0, 2070.0].freeze

      Platte = Struct.new(:nr, :laenge, :breite, :teile, :schnitte, :reste, :ausnutzung)
      # x, y: Lage auf der Platte (mm, von der Ecke links oben), l, b: Maße wie gelegt
      Teil = Struct.new(:zeile, :i, :n, :x, :y, :l, :b, :gedreht)
      Schnitt = Struct.new(:nr, :art, :laengs, :x, :y, :laenge)
      Rest = Struct.new(:x, :y, :l, :b)
      Gruppe = Struct.new(:material, :ds, :format, :maserung, :platten, :nicht_platziert, :fehler)

      # Plattenformat aus "2800mm x 2070mm;4100mm x 1300mm" (erstes Format), in mm
      def plattenformat(mat)
        Materialien.plattenformat(mat) || STANDARD_PLATTE.dup
      end

      def material(model, name)
        model.materials.to_a.find { |m| m.name.to_s == name }
      end

      # Schnittart aus BinPacking2D
      def art(cut)
        case cut.cut_type
        when BP::TRIMMING_CUT then 'Besäumen'
        when BP::BOUNDING_CUT then 'Reststreifen'
        when BP::INTERNAL_THROUGH_CUT then 'Durchgehend'
        else 'Schnitt'
        end
      end

      def gruppe(zs, material, ds, mat)
        format = plattenformat(mat)
        maserung = zs.first.maserung
        o = BP::Options.new
        o.set_base_length(format[0])
        o.set_base_width(format[1])
        o.set_rotatable(!maserung)
        o.set_saw_kerf(Einstellungen.schnittbreite)
        o.set_trimsize(Einstellungen.besaeumen)
        o.set_optimization(BP::OPT_MEDIUM)
        o.set_stacking_pref(BP::STACKING_ALL)
        e = BP::PackEngine.new(o)
        zs.each do |z|
          (1..z.anzahl).each { |i| e.add_box(z.roh[0], z.roh[1], !maserung, z.nr, [z, i, z.anzahl]) }
        end
        g = Gruppe.new(material, ds, format, maserung, [], [], nil)
        erg, fehler = e.runall
        if erg.nil? || fehler.to_i > BP::ERROR_NONE
          g.fehler = fehler == BP::ERROR_NO_PLACEMENT_POSSIBLE ? 'kein Teil passt auf die Platte' : "Optimierer-Fehler #{fehler}"
          g.nicht_platziert = zs.flat_map { |z| (1..z.anzahl).map { |i| [z, i, z.anzahl] } }
          return g
        end
        g.nicht_platziert = erg.unplaced_boxes.map(&:data)
        erg.packed_bins.each_with_index do |bin, k|
          teile = bin.boxes.map { |b| Teil.new(*b.data, b.x_pos, b.y_pos, b.length, b.width, b.rotated) }
          teile.sort_by! { |t| [t.zeile.nr, t.i] }
          schnitte = bin.cuts.sort_by { |c| [c.cut_type == BP::TRIMMING_CUT ? 0 : 1, c.index, c.level, c.y_pos, c.x_pos] }
                        .each_with_index.map { |c, n| Schnitt.new(n + 1, art(c), c.is_horizontal, c.x_pos, c.y_pos, c.length) }
          reste = bin.leftovers.map { |r| Rest.new(r.x_pos, r.y_pos, r.length, r.width) }
          g.platten << Platte.new(k + 1, bin.length, bin.width, teile, schnitte, reste, bin.efficiency)
        end
        g
      end

      # Gruppen je [Material, Stärke], ohne Arbeitsplatten und Teile ohne Material
      def berechnen(model, zs)
        zs.reject { |z| z.hinweis == 'Arbeitsplatte' || z.material.empty? }
          .group_by { |z| [z.material, z.ds] }
          .map { |(m, ds), g| gruppe(g, m, ds, material(model, m)) }
      end

      def erzeugen(model, auswahl: nil)
        zs, meldungen = Stueckliste.erzeugen(model, auswahl: auswahl)
        gruppen = berechnen(model, zs)
        meldungen += gruppen.reject { |g| g.nicht_platziert.empty? }.map do |g|
          "#{g.material} #{Stueckliste.zahl(g.ds)} mm: #{g.nicht_platziert.size} Teile passen nicht auf die Platte#{g.fehler ? " (#{g.fehler})" : ''}"
        end
        meldungen << "#{zs.count { |z| z.hinweis == 'Arbeitsplatte' }} Arbeitsplatte(n) nicht im Zuschnittplan (von Hand)" if zs.any? { |z| z.hinweis == 'Arbeitsplatte' }
        [gruppen, meldungen]
      end

      def h(s)
        Stueckliste.h(s)
      end

      def zahl(v)
        Stueckliste.zahl(v)
      end

      def stueck_text(z, i, n)
        "Nr #{z.nr}#{n > 1 ? " (#{i}/#{n})" : ''}"
      end

      # Skizze einer Platte als SVG (Platte links oben = 0/0, Länge waagrecht)
      def skizze(p)
        l = p.laenge
        b = p.breite
        sb = Einstellungen.schnittbreite
        o = +"<svg class=\"skizze\" viewBox=\"-40 -40 #{Tcn.n(l + 80)} #{Tcn.n(b + 80)}\" xmlns=\"http://www.w3.org/2000/svg\">"
        o << '<defs><pattern id="rest" width="40" height="40" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><line x1="0" y1="0" x2="0" y2="40" stroke="#999" stroke-width="6"/></pattern></defs>'
        o << "<rect x=\"0\" y=\"0\" width=\"#{Tcn.n(l)}\" height=\"#{Tcn.n(b)}\" fill=\"#eee\" stroke=\"#000\" stroke-width=\"4\"/>"
        p.reste.each do |r|
          o << "<rect x=\"#{Tcn.n(r.x)}\" y=\"#{Tcn.n(r.y)}\" width=\"#{Tcn.n(r.l)}\" height=\"#{Tcn.n(r.b)}\" fill=\"url(#rest)\"/>"
        end
        p.teile.each do |t|
          o << "<rect x=\"#{Tcn.n(t.x)}\" y=\"#{Tcn.n(t.y)}\" width=\"#{Tcn.n(t.l)}\" height=\"#{Tcn.n(t.b)}\" fill=\"#fff\" stroke=\"#000\" stroke-width=\"3\"/>"
          fs = [[t.b * 0.22, t.l * 0.09, 70].min, 18].max
          cx = t.x + t.l / 2.0
          cy = t.y + t.b / 2.0
          o << "<text x=\"#{Tcn.n(cx)}\" y=\"#{Tcn.n(cy - fs * 0.15)}\" font-size=\"#{Tcn.n(fs.round(1))}\" text-anchor=\"middle\" font-weight=\"bold\">#{t.zeile.nr}#{t.n > 1 ? "<tspan font-weight=\"normal\" font-size=\"#{Tcn.n((fs * 0.6).round(1))}\"> #{t.i}/#{t.n}</tspan>" : ''}</text>"
          o << "<text x=\"#{Tcn.n(cx)}\" y=\"#{Tcn.n(cy + fs * 0.85)}\" font-size=\"#{Tcn.n((fs * 0.7).round(1))}\" text-anchor=\"middle\">#{zahl(t.l)} × #{zahl(t.b)}</text>"
        end
        p.schnitte.each do |s|
          x2 = s.laengs ? s.x + s.laenge : s.x
          y2 = s.laengs ? s.y : s.y + s.laenge
          dx = s.laengs ? 0 : sb / 2.0
          dy = s.laengs ? sb / 2.0 : 0
          o << "<line x1=\"#{Tcn.n(s.x + dx)}\" y1=\"#{Tcn.n(s.y + dy)}\" x2=\"#{Tcn.n(x2 + dx)}\" y2=\"#{Tcn.n(y2 + dy)}\" stroke=\"#c00\" stroke-width=\"#{Tcn.n([sb, 4].max)}\"/>"
          mx = s.laengs ? s.x + 30 : s.x + dx
          my = s.laengs ? s.y + dy : s.y + 30
          o << "<circle cx=\"#{Tcn.n(mx)}\" cy=\"#{Tcn.n(my)}\" r=\"22\" fill=\"#c00\"/><text x=\"#{Tcn.n(mx)}\" y=\"#{Tcn.n(my + 9)}\" font-size=\"26\" fill=\"#fff\" text-anchor=\"middle\">#{s.nr}</text>"
        end
        o << '</svg>'
      end

      def schnittliste(p)
        o = +'<table class="schnitte"><tr><th>Schnitt</th><th>Art</th><th>Richtung</th><th>bei</th><th>ab</th><th>Länge</th></tr>'
        p.schnitte.each do |s|
          bei = s.laengs ? "y = #{zahl(s.y)}" : "x = #{zahl(s.x)}"
          ab = s.laengs ? "x = #{zahl(s.x)}" : "y = #{zahl(s.y)}"
          o << "<tr><td class=\"z\">#{s.nr}</td><td>#{s.art}</td><td>#{s.laengs ? 'längs' : 'quer'}</td><td class=\"z\">#{bei}</td><td class=\"z\">#{ab}</td><td class=\"z\">#{zahl(s.laenge)}</td></tr>"
        end
        o << '</table>'
      end

      def teileliste(p)
        o = +'<table class="teile"><tr><th>Nr</th><th>Tag</th><th>Rohmaß L × B</th><th>gedreht</th></tr>'
        p.teile.each do |t|
          o << "<tr><td class=\"z\">#{h(stueck_text(t.zeile, t.i, t.n).sub('Nr ', ''))}</td><td>#{h(t.zeile.tag)}</td>"
          o << "<td class=\"z\">#{zahl(t.zeile.roh[0])} × #{zahl(t.zeile.roh[1])}</td><td>#{t.gedreht ? 'ja' : ''}</td></tr>"
        end
        o << '</table>'
      end

      def html(gruppen, titel: 'Zuschnittplan', meldungen: [])
        o = +"<!DOCTYPE html>\n<html lang=\"de\"><head><meta charset=\"utf-8\"><title>#{h(titel)}</title>\n<style>\n"
        o << "@page{size:A4 landscape;margin:8mm}body{font:11px/1.35 Arial,sans-serif;color:#000;margin:0 3mm}\n"
        o << "h1{font-size:18px;margin:4px 0}h2{font-size:14px;margin:0 0 4px}table{border-collapse:collapse}\n"
        o << "th,td{border:1px solid #888;padding:1px 4px;text-align:left;vertical-align:top}th{background:#eee}td.z{text-align:right;white-space:nowrap}\n"
        o << ".platte{page-break-before:always;break-before:page}.inhalt{display:flex;gap:4mm;align-items:flex-start}\n"
        o << ".skizze{width:185mm;height:auto;max-height:150mm;font-family:Arial,sans-serif}.listen{flex:1;display:flex;flex-direction:column;gap:3mm;font-size:10px}\n"
        o << ".meld{color:#a00}\n</style></head><body>\n<h1>#{h(titel)}</h1>\n"
        o << "<p>Schnittbreite #{zahl(Einstellungen.schnittbreite)} mm, besäumen #{zahl(Einstellungen.besaeumen)} mm je Kante. "
        o << 'Maße = Rohmaß (Fräsmaß + Übermaß). Platte links oben = 0/0, Länge waagrecht. Nummern wie Stückliste und Etiketten.</p>' + "\n"
        o << "<p class=\"meld\">#{meldungen.map { |m| h(m) }.join('<br>')}</p>\n" unless meldungen.empty?
        o << '<table><tr><th>Material</th><th>Stärke</th><th>Platte</th><th>Maserung</th><th>Platten</th><th>Teile</th><th>Ausnutzung</th><th>passt nicht</th></tr>' + "\n"
        gruppen.each do |g|
          stueck = g.platten.sum { |p| p.teile.size }
          aus = g.platten.empty? ? '' : "#{zahl((g.platten.sum { |p| p.ausnutzung } / g.platten.size).round(1))} %"
          o << "<tr><td>#{h(g.material)}</td><td class=\"z\">#{zahl(g.ds)}</td><td class=\"z\">#{zahl(g.format[0])} × #{zahl(g.format[1])}</td>"
          o << "<td>#{g.maserung ? 'ja, nicht drehen' : 'nein'}</td><td class=\"z\">#{g.platten.size}</td><td class=\"z\">#{stueck}</td><td class=\"z\">#{aus}</td>"
          o << "<td>#{g.nicht_platziert.map { |z, i, n| h(stueck_text(z, i, n)) }.join(', ')}</td></tr>\n"
        end
        o << "</table>\n"
        gruppen.each do |g|
          g.platten.each do |p|
            o << "<div class=\"platte\"><h2>#{h(g.material)} #{zahl(g.ds)} mm – Platte #{p.nr} von #{g.platten.size} (#{zahl(p.laenge)} × #{zahl(p.breite)}, Ausnutzung #{zahl(p.ausnutzung.round(1))} %)</h2>\n"
            o << "<div class=\"inhalt\">#{skizze(p)}<div class=\"listen\">#{schnittliste(p)}#{teileliste(p)}</div></div></div>\n"
          end
        end
        o << "</body></html>\n"
      end

      def schreiben(ordner, gruppen, meldungen = [])
        p = File.join(ordner, 'Zuschnitt.html')
        File.binwrite(p, html(gruppen, titel: "Zuschnittplan #{File.basename(ordner.to_s.tr('\\', '/'))}", meldungen: meldungen).encode('UTF-8').b)
        p
      end

      def dialog(model = Sketchup.active_model)
        auswahl = model.selection.to_a.empty? ? nil : model.selection.to_a
        gruppen, meldungen = erzeugen(model, auswahl: auswahl)
        if gruppen.empty?
          UI.messagebox('Keine Schrankteile gefunden (Teile mit Tag, JT_Schrank und Material, sichtbar).')
          return
        end
        ordner = UI.select_directory(title: 'Ordner für den Zuschnittplan')
        return unless ordner
        p = schreiben(ordner, gruppen, meldungen)
        UI.openURL("file:///#{p.tr('\\', '/').sub(%r{\A/+}, '')}")
        platten = gruppen.sum { |g| g.platten.size }
        text = "Zuschnittplan: #{platten} Platte(n)#{auswahl ? ' (nur Auswahl)' : ''} in\n#{p}"
        text += "\n\nHinweise:\n" + meldungen.first(15).join("\n") unless meldungen.empty?
        UI.messagebox(text)
      end
    end
  end
end
