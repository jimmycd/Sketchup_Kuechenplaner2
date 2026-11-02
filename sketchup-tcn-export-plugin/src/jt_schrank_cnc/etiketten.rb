# encoding: UTF-8
# Schrank-CNC – Etiketten (ersetzt die Etiketten aus OpenCutList).
#
# Ein Etikett je Stück (Anzahl 3 = drei Etiketten "1/3", "2/3", "3/3"), in der
# Reihenfolge der Stückliste (gleiche Nummern). Ausgabe als HTML-Seite, die im
# Browser gedruckt wird (auch als PDF):
#   Bogen  – A4 hoch, Etiketten in Spalten × Zeilen mit Rändern und Abständen,
#            Startposition für angebrochene Bögen
#   Endlos – Etikettendrucker mit Rolle: je Etikett eine Seite in Etikettengröße
# Das Format ist frei einstellbar und wird für alle Modelle gespeichert.
# Inhalt: Tag, Nummer, Schrank/Teil, Material und Stärke, Rohmaß, Fertigmaß,
# Kantenbild (Anleimer als dicke Linie), TCN-Dateiname, optional QR-Code
# mit dem TCN-Dateinamen (braucht beim Drucken Internet für die QR-Bibliothek).

module JTools
  module SchrankCnc
    module Etiketten
      module_function

      SEITE = [210.0, 297.0].freeze # A4 hoch, mm
      ARTEN = %w[Bogen Endlos].freeze
      QR_JS = 'https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js'.freeze

      # Schlüssel => [Bezeichnung, Standard]; Standard = A4-Bogen 3 × 8 à 70 × 37 mm
      FORMAT = {
        'etikett_art' => ['Art (Bogen oder Endlos)', 'Bogen'],
        'etikett_breite' => ['Etikett Breite (mm)', 70.0],
        'etikett_hoehe' => ['Etikett Höhe (mm)', 37.0],
        'etikett_spalten' => ['Bogen: Spalten', 3],
        'etikett_zeilen' => ['Bogen: Zeilen', 8],
        'etikett_rand_oben' => ['Bogen: Rand oben (mm)', 0.5],
        'etikett_rand_links' => ['Bogen: Rand links (mm)', 0.0],
        'etikett_abstand_h' => ['Bogen: Abstand waagrecht (mm)', 0.0],
        'etikett_abstand_v' => ['Bogen: Abstand senkrecht (mm)', 0.0],
        'etikett_qr' => ['QR-Code (ja oder nein)', 'nein']
      }.freeze

      def format_lesen
        FORMAT.each_with_object({}) do |(k, (_, std)), h|
          v = Sketchup.read_default(Einstellungen::SEKTION, k, nil)
          h[k] = if v.nil? then std
                 elsif std.is_a?(String) then v.to_s
                 elsif std.is_a?(Integer) then v.to_i
                 else v.to_s.tr(',', '.').to_f
                 end
        end
      end

      def format_speichern(f)
        f.each { |k, v| Sketchup.write_default(Einstellungen::SEKTION, k, v) if FORMAT.key?(k) }
      end

      def bogen?(f)
        f['etikett_art'] != 'Endlos'
      end

      def je_bogen(f)
        f['etikett_spalten'] * f['etikett_zeilen']
      end

      # Prüft das Format; gibt Fehlertexte zurück
      def pruefen(f)
        fehler = []
        fehler << 'Etikettgröße muss größer als 0 sein' unless f['etikett_breite'] > 0 && f['etikett_hoehe'] > 0
        if bogen?(f)
          fehler << 'Spalten und Zeilen mindestens 1' unless f['etikett_spalten'] >= 1 && f['etikett_zeilen'] >= 1
          b = f['etikett_rand_links'] + f['etikett_spalten'] * f['etikett_breite'] + (f['etikett_spalten'] - 1) * f['etikett_abstand_h']
          h = f['etikett_rand_oben'] + f['etikett_zeilen'] * f['etikett_hoehe'] + (f['etikett_zeilen'] - 1) * f['etikett_abstand_v']
          fehler << "Etiketten passen nicht auf A4 (#{Tcn.n(b.round(1))} × #{Tcn.n(h.round(1))} mm)" if b > SEITE[0] + 0.01 || h > SEITE[1] + 0.01
        end
        fehler
      end

      # Ein Eintrag je Stück: [Zeile, i, n]
      def stuecke(zs)
        zs.flat_map { |z| (1..z.anzahl).map { |i| [z, i, z.anzahl] } }
      end

      def h(s)
        Stueckliste.h(s)
      end

      def zahl(v)
        Stueckliste.zahl(v)
      end

      # Kantenbild: Rechteck im Seitenverhältnis des Teils (begrenzt), Länge waagrecht;
      # L1 unten, L2 oben, B1 links, B2 rechts; Anleimer als dicke Linie
      def kantenbild(z, breite_mm, hoehe_mm)
        l, b = z.fertig
        r = [[b / l.to_f, 0.25].max, 1.0].min
        w = 100.0
        hh = w * r
        sw = 7
        o = +"<svg class=\"kb\" viewBox=\"-6 -6 #{w + 12} #{(hh + 12).round(2)}\" style=\"width:#{breite_mm}mm;max-height:#{hoehe_mm}mm\">"
        o << "<rect x=\"0\" y=\"0\" width=\"#{w}\" height=\"#{hh.round(2)}\" fill=\"none\" stroke=\"#000\" stroke-width=\"1\"/>"
        linien = { l1: [0, hh, w, hh], l2: [0, 0, w, 0], b1: [0, 0, 0, hh], b2: [w, 0, w, hh] }
        linien.each do |k, (x1, y1, x2, y2)|
          next unless z.kanten[k]
          o << "<line x1=\"#{x1}\" y1=\"#{y1.round(2)}\" x2=\"#{x2}\" y2=\"#{y2.round(2)}\" stroke=\"#000\" stroke-width=\"#{sw}\" stroke-linecap=\"square\"/>"
        end
        o << '</svg>'
      end

      def etikett(z, i, n, f, qr_id = nil)
        w = f['etikett_breite']
        hoch = f['etikett_hoehe']
        bild_b = [w * 0.28, 22].min
        o = +"<div class=\"inhalt\">"
        o << "<div class=\"kopf\"><span class=\"tag\">#{h(z.tag)}</span><span class=\"nr\">Nr #{z.nr}#{n > 1 ? " · #{i}/#{n}" : ''}</span></div>"
        o << "<div class=\"rumpf\"><div class=\"text\">"
        o << "<div>#{h(z.schrank)} · #{h(z.teil)}</div>"
        o << "<div>#{h(z.material.empty? ? '(ohne Material)' : z.material)} #{zahl(z.ds)} mm</div>"
        o << "<div class=\"roh\">Roh #{zahl(z.roh[0])} × #{zahl(z.roh[1])}</div>"
        o << "<div>Fertig #{zahl(z.fertig[0])} × #{zahl(z.fertig[1])}</div>"
        # Schräg- oder Bogenkante (Abschlussregal): fräst die CNC, Anleimer danach von Hand
        o << "<div>Kontur mit Anleimer (CNC)</div>" if z.respond_to?(:kontur) && z.kontur && !z.kontur.empty?
        o << "<div class=\"datei\">#{h(z.datei)}</div>"
        o << '</div><div class="bild">'
        o << kantenbild(z, bild_b, hoch * 0.35)
        o << "<div id=\"#{qr_id}\" class=\"qr\" data-text=\"#{h(z.datei)}\"></div>" if qr_id
        o << '</div></div></div>'
      end

      def html(zs, f, start: 1, titel: 'Etiketten')
        w = f['etikett_breite']
        hoch = f['etikett_hoehe']
        qr = f['etikett_qr'].to_s.strip.downcase.start_with?('j')
        bogen = bogen?(f)
        seite = bogen ? SEITE : [w, hoch]
        # Schrift nach Etikettgröße: 70 × 37 → etwa 2,6 mm Grundschrift
        fs = [[hoch / 14.0, w / 27.0].min, 1.6].max.round(2)
        o = +"<!DOCTYPE html>\n<html lang=\"de\"><head><meta charset=\"utf-8\"><title>#{h(titel)}</title>\n<style>\n"
        o << "@page{size:#{Tcn.n(seite[0])}mm #{Tcn.n(seite[1])}mm;margin:0}\n"
        o << "html,body{margin:0;padding:0;background:#fff}body{font-family:Arial,sans-serif;color:#000}\n"
        o << ".seite{position:relative;width:#{Tcn.n(seite[0])}mm;height:#{Tcn.n(seite[1])}mm;overflow:hidden;page-break-after:always;break-after:page}\n"
        o << ".seite:last-child{page-break-after:auto;break-after:auto}\n"
        o << ".etikett{position:absolute;width:#{Tcn.n(w)}mm;height:#{Tcn.n(hoch)}mm;box-sizing:border-box;padding:1.5mm 2mm;overflow:hidden}\n"
        o << ".inhalt{font-size:#{fs}mm;line-height:1.2}.kopf{display:flex;justify-content:space-between;align-items:baseline;border-bottom:0.2mm solid #000;margin-bottom:0.6mm}\n"
        o << ".tag{font-weight:bold;font-size:1.45em}.nr{font-size:0.95em;white-space:nowrap;margin-left:1mm}.rumpf{display:flex;justify-content:space-between;gap:1mm}\n"
        o << ".text{min-width:0}.text div{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.roh{font-weight:bold}.datei{font-size:0.85em}\n"
        o << ".bild{display:flex;flex-direction:column;align-items:flex-end;gap:0.8mm}.kb{display:block}.qr img,.qr canvas{width:#{Tcn.n((hoch * 0.4).round(1))}mm!important;height:#{Tcn.n((hoch * 0.4).round(1))}mm!important}\n"
        o << "@media screen{body{background:#ccc}.seite{background:#fff;margin:4mm auto;box-shadow:0 0 2mm #888}.etikett{outline:0.1mm dashed #bbb}}\n"
        o << "</style>\n"
        o << "<script src=\"#{QR_JS}\"></script>\n" if qr
        o << "</head><body>\n"
        liste = stuecke(zs)
        if bogen
          vorne = [[start.to_i, 1].max, je_bogen(f)].min - 1
          plaetze = Array.new(vorne) + liste
          nr = 0
          plaetze.each_slice(je_bogen(f)) do |seite_e|
            o << "<div class=\"seite\">\n"
            seite_e.each_with_index do |e, k|
              next unless e
              x = f['etikett_rand_links'] + (k % f['etikett_spalten']) * (w + f['etikett_abstand_h'])
              y = f['etikett_rand_oben'] + (k / f['etikett_spalten']) * (hoch + f['etikett_abstand_v'])
              o << "<div class=\"etikett\" style=\"left:#{Tcn.n(x.round(2))}mm;top:#{Tcn.n(y.round(2))}mm\">"
              o << etikett(*e, f, qr ? "qr#{nr += 1}" : nil) << "</div>\n"
            end
            o << "</div>\n"
          end
        else
          liste.each_with_index do |e, k|
            o << "<div class=\"seite\"><div class=\"etikett\" style=\"left:0;top:0\">"
            o << etikett(*e, f, qr ? "qr#{k}" : nil) << "</div></div>\n"
          end
        end
        if qr
          o << "<script>if(window.QRCode){document.querySelectorAll('.qr').forEach(function(e){new QRCode(e,{text:e.dataset.text,width:128,height:128,correctLevel:QRCode.CorrectLevel.M})})}</script>\n"
        end
        o << "</body></html>\n"
      end

      def schreiben(ordner, zs, f, start: 1)
        p = File.join(ordner, 'Etiketten.html')
        File.binwrite(p, html(zs, f, start: start, titel: "Etiketten #{File.basename(ordner.to_s.tr('\\', '/'))}").encode('UTF-8').b)
        p
      end

      # Format abfragen (vorbelegt mit dem gespeicherten), dazu die Startposition.
      # Ruft den Block mit Format und Start auf (nicht bei Abbruch); ungültige Werte -> ArgumentError.
      def abfragen
        f = format_lesen
        keys = FORMAT.keys
        labels = keys.map { |k| FORMAT[k][0] } + ['Bogen: erstes freies Etikett (1 = oben links)']
        werte = keys.map { |k| f[k].is_a?(String) ? f[k] : Tcn.n(f[k]) } + ['1']
        listen = keys.map { |k| { 'etikett_art' => ARTEN.join('|'), 'etikett_qr' => 'nein|ja' }[k] || '' } + ['']
        Kuechenplaner::Eingabe.abfragen(labels, werte, listen, 'Etiketten – Format', gruppe: 'Etikett', ok: 'Weiter') do |antwort|
          neu = {}
          zahlen_ok = true
          keys.each_with_index do |k, i|
            std = FORMAT[k][1]
            s = antwort[i].to_s.strip
            if std.is_a?(String)
              neu[k] = s
            else
              zahlen_ok &&= s.tr(',', '.') =~ /\A\d+(\.\d+)?\z/
              neu[k] = std.is_a?(Integer) ? s.to_i : s.tr(',', '.').to_f
            end
          end
          start = antwort[keys.size].to_s.strip
          zahlen_ok &&= start =~ /\A\d+\z/
          fehler = zahlen_ok ? pruefen(neu) : ['Bitte bei Maßen und Anzahlen nur Zahlen ≥ 0 eingeben']
          raise ArgumentError, fehler.join("\n") unless fehler.empty?
          format_speichern(neu)
          yield neu, start.to_i
        end
      end

      def dialog(model = Sketchup.active_model)
        auswahl = model.selection.to_a.empty? ? nil : model.selection.to_a
        zs, meldungen = Stueckliste.erzeugen(model, auswahl: auswahl)
        if zs.empty?
          UI.messagebox('Keine Schrankteile gefunden (Teile mit Tag und JT_Schrank, sichtbar).')
          return
        end
        abfragen do |f, start|
          ordner = UI.select_directory(title: 'Ordner für die Etiketten')
          next unless ordner
          p = schreiben(ordner, zs, f, start: start)
          UI.openURL("file:///#{p.tr('\\', '/').sub(%r{\A/+}, '')}")
          text = "#{stuecke(zs).size} Etiketten#{auswahl ? ' (nur Auswahl)' : ''} in\n#{p}\n\nIm Browser drucken: Größe 100 % (nicht „an Seite anpassen“), Ränder keine."
          text += "\n\nHinweise:\n" + meldungen.first(15).join("\n") unless meldungen.empty?
          UI.messagebox(text)
        end
      rescue ArgumentError => e
        UI.messagebox(e.message)
      end
    end
  end
end
