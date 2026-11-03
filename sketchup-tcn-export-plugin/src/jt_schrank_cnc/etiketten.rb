# encoding: UTF-8
# Schrank-CNC – Etiketten (ersetzt die Etiketten aus OpenCutList).
#
# Ein Etikett je Stück (Anzahl 3 = drei Etiketten "1/3", "2/3", "3/3"), in der
# Reihenfolge der Stückliste (gleiche Nummern). Ausgabe als PDF (Etiketten.pdf), im
# PDF-Leser mit „Tatsächliche Größe“ drucken:
#   Bogen  – A4 hoch, Etiketten in Spalten × Zeilen mit Rändern und Abständen,
#            Startposition für angebrochene Bögen
#   Endlos – Etikettendrucker mit Rolle: je Etikett eine Seite in Etikettengröße
# Das Format ist frei einstellbar und wird für alle Modelle gespeichert.
# Inhalt: Tag, Nummer, Schrank/Teil, Material und Stärke, Rohmaß, Fräsmaß, Fertigmaß
# (in dieser Reihenfolge), Kantenbild (Anleimer als dicke Linie), TCN-Dateiname,
# optional QR-Code mit dem TCN-Dateinamen (im PDF gezeichnet, ohne Internet).

module JTools
  module SchrankCnc
    module Etiketten
      module_function

      SEITE = [210.0, 297.0].freeze # A4 hoch, mm
      ARTEN = %w[Bogen Endlos].freeze

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
      # L1 unten, L2 oben, B1 links, B2 rechts; Anleimer als dicke Linie.
      # Zeichnet in das Feld x/y/w/h (mm), rechtsbündig oben
      def kantenbild(doc, z, x, y, w, h)
        l, b = z.fertig
        r = [[b / l.to_f, 0.25].max, 1.0].min
        bw = [w, h / r].min
        bh = bw * r
        x0 = x + w - bw
        sw = [bw * 0.035, 0.5].max
        doc.rechteck(x0, y, bw, bh, rand: [0, 0, 0], staerke: 0.15)
        linien = { l1: [x0, y + bh, x0 + bw, y + bh], l2: [x0, y, x0 + bw, y],
                   b1: [x0, y, x0, y + bh], b2: [x0 + bw, y, x0 + bw, y + bh] }
        linien.each do |k, (x1, y1, x2, y2)|
          doc.linie(x1, y1, x2, y2, staerke: sw) if z.kanten[k]
        end
        bh
      end

      def mass(a)
        "#{zahl(a[0])} × #{zahl(a[1])}"
      end

      # Textzeilen eines Etiketts: [Text, fett]
      def zeilen(z)
        [["#{z.schrank} · #{z.teil}", false],
         ["#{z.material.empty? ? '(ohne Material)' : z.material} #{zahl(z.ds)} mm", false],
         ["Roh #{mass(z.roh)}", true],
         ["Fräs #{mass(z.fraes)}", false],
         ["Fertig #{mass(z.fertig)}", false],
         [z.datei.to_s, false]]
      end

      # Ein Etikett mit linker oberer Ecke x/y
      def etikett(doc, z, i, n, f, x, y, qr)
        w = f['etikett_breite']
        hoch = f['etikett_hoehe']
        fs = [[hoch / 14.0, w / 27.0].min, 1.6].max
        pad_x = [w * 0.03, 2.0].min
        pad_y = [hoch * 0.04, 1.5].min
        innen = w - 2 * pad_x
        doc.ausschnitt(x, y, w, hoch) do
          # Kopf: Tag groß links, Nummer rechts, Linie darunter
          nr = "Nr #{z.nr}#{n > 1 ? " · #{i}/#{n}" : ''}"
          nr_b = doc.textbreite(nr, fs * 0.95)
          ft = fs * 1.45
          yk = y + pad_y + ft * 0.8
          doc.text(x + w - pad_x, yk, nr, groesse: fs * 0.95, ausrichtung: :rechts)
          doc.text(x + pad_x, yk, z.tag, groesse: ft, fett: true, max: innen - nr_b - 1)
          yl = yk + ft * 0.3
          doc.linie(x + pad_x, yl, x + w - pad_x, yl, staerke: 0.2)
          # rechts: Kantenbild und QR-Code
          rechts = [w * 0.28, 22.0].min
          rest_h = hoch - (yl - y) - pad_y - 0.6
          bild_h = kantenbild(doc, z, x + w - pad_x - rechts, yl + 0.8, rechts, [hoch * 0.3, rest_h].min)
          if qr
            q = [rest_h - bild_h - 1.7, rechts].min
            doc.qr(x + w - pad_x - q, yl + 0.8 + bild_h + 1.5, q, z.datei) if q >= 6
          end
          # Text links
          text_b = innen - rechts - 1.0
          zh = fs * 1.2
          ty = yl + 0.6 + zh * 0.85
          zeilen(z).each do |t, fett|
            g = t == z.datei.to_s ? fs * 0.85 : fs
            break if ty > y + hoch - pad_y * 0.5
            doc.text(x + pad_x, ty, t, groesse: g, fett: fett, max: text_b)
            ty += zh
          end
        end
      end

      def pdf(zs, f, start: 1, titel: 'Etiketten')
        w = f['etikett_breite']
        hoch = f['etikett_hoehe']
        qr = f['etikett_qr'].to_s.strip.downcase.start_with?('j')
        doc = Pdf.new(titel: titel)
        liste = stuecke(zs)
        if bogen?(f)
          vorne = [[start.to_i, 1].max, je_bogen(f)].min - 1
          plaetze = Array.new(vorne) + liste
          pos = lagen(f)
          plaetze.each_slice(je_bogen(f)) do |seite_e|
            doc.seite(*SEITE)
            seite_e.each_with_index do |e, k|
              etikett(doc, *e, f, *pos[k], qr) if e
            end
          end
        else
          liste.each do |e|
            doc.seite(w, hoch)
            etikett(doc, *e, f, 0, 0, qr)
          end
        end
        doc
      end

      # Lage der Etiketten auf dem Bogen: [[x, y], …] für Platz 0 … je_bogen-1
      def lagen(f)
        (0...je_bogen(f)).map do |k|
          [f['etikett_rand_links'] + (k % f['etikett_spalten']) * (f['etikett_breite'] + f['etikett_abstand_h']),
           f['etikett_rand_oben'] + (k / f['etikett_spalten']) * (f['etikett_hoehe'] + f['etikett_abstand_v'])]
        end
      end

      def schreiben(ordner, zs, f, start: 1)
        p = File.join(ordner, 'Etiketten.pdf')
        pdf(zs, f, start: start, titel: "Etiketten #{File.basename(ordner.to_s.tr('\\', '/'))}").schreiben(p)
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
          text = "#{stuecke(zs).size} Etiketten#{auswahl ? ' (nur Auswahl)' : ''} in\n#{p}\n\nDrucken mit „Tatsächliche Größe“ (100 %, nicht „an Seite anpassen“)."
          text += "\n\nHinweise:\n" + meldungen.first(15).join("\n") unless meldungen.empty?
          UI.messagebox(text)
        end
      rescue ArgumentError => e
        UI.messagebox(e.message)
      end
    end
  end
end
