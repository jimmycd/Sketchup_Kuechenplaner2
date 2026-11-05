# encoding: UTF-8
# Schrank-CNC – kleiner PDF-Schreiber ohne fremde Bibliothek (für Stückliste, Etiketten
# und Zuschnittplan). Alle Maße in mm, Ursprung links oben (wie auf dem Papier), y nach
# unten. Schrift Helvetica / Helvetica-Bold (in jedem PDF-Leser vorhanden), Text in
# Windows-1252 (Umlaute, ß, ×, –, …). Kann Linien, Rechtecke, Kreise, Text (auch
# um 90° gedreht), Ausschneiden (clip) und QR-Codes (rqrcode_core) zeichnen.

module JTools
  module SchrankCnc
    # QR-Code-Erzeuger rqrcode_core (MIT, siehe THIRD_PARTY.md)
    %w[qr_code qr_math qr_polynomial qr_rs_block qr_bit_buffer qr_util qr_8bit_byte
       qr_alphanumeric qr_numeric qr_segment qr_multi].each do |f|
      load File.join(File.dirname(__FILE__), 'rqrcode_core', "#{f}.rb")
    end

    class Pdf
      PT = 72.0 / 25.4 # Punkt je mm

      # Zeichenbreiten der Standardschriften (1/1000 der Schriftgröße), Windows-1252
      HELVETICA = [
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        278, 278, 355, 556, 556, 889, 667, 191, 333, 333, 389, 584, 278, 333, 278, 278,
        556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 278, 278, 584, 584, 584, 556,
        1015, 667, 667, 722, 722, 667, 611, 778, 722, 278, 500, 667, 556, 833, 722, 778,
        667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 278, 278, 278, 469, 556,
        333, 556, 556, 500, 556, 556, 278, 556, 556, 222, 222, 500, 222, 833, 556, 556,
        556, 556, 333, 500, 278, 556, 500, 722, 500, 500, 500, 334, 260, 334, 584, 761,
        556, 0, 222, 556, 333, 1000, 556, 556, 333, 1000, 667, 333, 1000, 0, 611, 0,
        0, 222, 222, 333, 333, 350, 556, 1000, 333, 1000, 500, 333, 944, 0, 500, 667,
        278, 333, 556, 556, 556, 556, 260, 556, 333, 737, 370, 556, 584, 333, 737, 333,
        400, 584, 333, 333, 333, 556, 537, 278, 333, 333, 365, 556, 834, 834, 834, 611,
        667, 667, 667, 667, 667, 667, 1000, 722, 667, 667, 667, 667, 278, 278, 278, 278,
        722, 722, 778, 778, 778, 778, 778, 584, 778, 722, 722, 722, 722, 667, 667, 611,
        556, 556, 556, 556, 556, 556, 889, 500, 556, 556, 556, 556, 278, 278, 278, 278,
        556, 556, 556, 556, 556, 556, 556, 584, 611, 556, 556, 556, 556, 500, 556, 500
      ].freeze
      HELVETICA_BOLD = [
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        278, 333, 474, 556, 556, 889, 722, 238, 333, 333, 389, 584, 278, 333, 278, 278,
        556, 556, 556, 556, 556, 556, 556, 556, 556, 556, 333, 333, 584, 584, 584, 611,
        975, 722, 722, 722, 722, 667, 611, 778, 722, 278, 556, 722, 611, 833, 722, 778,
        667, 778, 722, 667, 611, 722, 667, 944, 667, 667, 611, 333, 278, 333, 584, 556,
        333, 556, 611, 556, 611, 556, 333, 611, 611, 278, 278, 556, 278, 889, 611, 611,
        611, 611, 389, 556, 333, 611, 556, 778, 556, 556, 500, 389, 280, 389, 584, 761,
        556, 0, 278, 556, 500, 1000, 556, 556, 333, 1000, 667, 333, 1000, 0, 611, 0,
        0, 278, 278, 500, 500, 350, 556, 1000, 333, 1000, 556, 333, 944, 0, 500, 667,
        278, 333, 556, 556, 556, 556, 280, 556, 333, 737, 370, 556, 584, 333, 737, 333,
        400, 584, 333, 333, 333, 611, 556, 278, 333, 333, 365, 556, 834, 834, 834, 611,
        722, 722, 722, 722, 722, 722, 1000, 722, 667, 667, 667, 667, 278, 278, 278, 278,
        722, 722, 778, 778, 778, 778, 778, 584, 778, 722, 722, 722, 722, 667, 667, 611,
        556, 556, 556, 556, 556, 556, 889, 556, 556, 556, 556, 556, 278, 278, 278, 278,
        611, 611, 611, 611, 611, 611, 611, 584, 611, 611, 611, 611, 611, 556, 611, 556
      ].freeze

      attr_reader :seiten

      def initialize(titel: nil)
        @titel = titel
        @seiten = []
      end

      # Neue Seite (Breite × Höhe in mm); danach zeichnen alle Befehle auf diese Seite
      def seite(breite, hoehe)
        @seiten << { b: breite.to_f, h: hoehe.to_f, ops: String.new(encoding: Encoding::BINARY) }
        self
      end

      # Im Block auf eine schon angelegte Seite zeichnen (Index ab 0), z. B. nachträglich
      # „Seite 2 von 5“ in den Fuß, wenn die Seitenzahl erst am Ende feststeht
      def auf_seite(i)
        raise ArgumentError, "Pdf: keine Seite #{i}" unless i.is_a?(Integer) && i >= 0 && i < @seiten.size
        alt = @aktuell
        @aktuell = i
        yield
        self
      ensure
        @aktuell = alt
      end

      def breite_seite
        aktuelle_seite[:b]
      end

      def hoehe_seite
        aktuelle_seite[:h]
      end

      # Einfache Tabelle: spalten = [[Titel, Breite mm, :links/:rechts/:mitte], …], zeilen =
      # Arrays mit Text je Spalte. fett = Spaltenindizes, die fett gedruckt werden. Zeichnet
      # bis y_max und gibt [y unter der letzten Zeile, Anzahl gezeichneter Zeilen] zurück.
      def tabelle(x, y, spalten, zeilen, y_max, groesse: 2.8, zeilenhoehe: 4.6, fett: [], kopf: true)
        breite = spalten.sum { |s| s[1] }
        zelle = lambda do |sx, w, a, t, b|
          tx = { links: sx + 1, rechts: sx + w - 1, mitte: sx + w / 2.0 }.fetch(a || :links)
          text(tx, y + zeilenhoehe * 0.72, t.to_s, groesse: groesse, fett: b, ausrichtung: a || :links, max: w - 2)
        end
        if kopf
          rechteck(x, y, breite, zeilenhoehe, fuellung: [0.92, 0.92, 0.92], rand: nil)
          sx = x
          spalten.each { |t, w, a| zelle.(sx, w, a, t, true); sx += w }
          y += zeilenhoehe
        end
        n = 0
        zeilen.each do |z|
          break if y + zeilenhoehe > y_max
          sx = x
          spalten.each_with_index { |(_, w, a), i| zelle.(sx, w, a, z[i], fett.include?(i)); sx += w }
          linie(x, y + zeilenhoehe, x + breite, y + zeilenhoehe, staerke: 0.1, farbe: [0.7, 0.7, 0.7])
          y += zeilenhoehe
          n += 1
        end
        [y, n]
      end

      # --- Text ---

      # Text nach Windows-1252 (Minuszeichen − als -, sonst nicht darstellbare Zeichen als ?)
      def self.cp1252(s)
        s.to_s.tr('−', '-').encode('Windows-1252', invalid: :replace, undef: :replace, replace: '?')
      end

      # Textbreite in mm bei Schriftgröße groesse (mm)
      def self.textbreite(s, groesse, fett = false)
        tab = fett ? HELVETICA_BOLD : HELVETICA
        cp1252(s).bytes.sum { |c| tab[c] } * groesse / 1000.0
      end

      def textbreite(s, groesse, fett = false)
        self.class.textbreite(s, groesse, fett)
      end

      # Text auf max mm kürzen (mit …)
      def self.kuerzen(s, max, groesse, fett = false)
        s = s.to_s
        return s if textbreite(s, groesse, fett) <= max
        s = s[0..-2] while !s.empty? && textbreite("#{s}…", groesse, fett) > max
        s.empty? ? '' : "#{s}…"
      end

      def kuerzen(s, max, groesse, fett = false)
        self.class.kuerzen(s, max, groesse, fett)
      end

      # Text mit Grundlinie bei y. ausrichtung :links, :mitte, :rechts. drehung 90 =
      # von unten nach oben lesbar (x/y ist dann der Anfang der Grundlinie, gedreht)
      def text(x, y, s, groesse:, fett: false, ausrichtung: :links, farbe: nil, drehung: 0, max: nil)
        s = kuerzen(s, max, groesse, fett) if max
        return self if s.to_s.empty?
        w = textbreite(s, groesse, fett)
        versatz = { links: 0.0, mitte: w / 2.0, rechts: w }.fetch(ausrichtung)
        o = op
        o << "q #{farbe_op(farbe || [0, 0, 0], 'rg')}BT /#{fett ? 'F2' : 'F1'} #{f(groesse * PT)} Tf "
        if drehung == 90
          o << "0 1 -1 0 #{f(x * PT)} #{f((hoehe_seite - y - versatz) * PT)} Tm "
        else
          o << "1 0 0 1 #{f((x - versatz) * PT)} #{f((hoehe_seite - y) * PT)} Tm "
        end
        o << "(".b << escape(self.class.cp1252(s)) << ") Tj ET Q\n".b
        self
      end

      # --- Grafik ---

      def linie(x1, y1, x2, y2, staerke: 0.2, farbe: nil, strich: nil)
        o = op
        o << "q #{farbe_op(farbe || [0, 0, 0], 'RG')}#{f(staerke * PT)} w 2 J "
        o << "[#{strich.map { |v| f(v * PT) }.join(' ')}] 0 d " if strich
        o << "#{f(x1 * PT)} #{f((hoehe_seite - y1) * PT)} m #{f(x2 * PT)} #{f((hoehe_seite - y2) * PT)} l S Q\n"
        self
      end

      # Rechteck links oben x/y, Breite w, Höhe h; fuellung und rand als [r, g, b] (0..1) oder nil
      def rechteck(x, y, w, h, fuellung: nil, rand: [0, 0, 0], staerke: 0.2, strich: nil)
        return self unless fuellung || rand
        o = op
        o << "q #{fuellung ? farbe_op(fuellung, 'rg') : ''}#{rand ? farbe_op(rand, 'RG') : ''}#{f(staerke * PT)} w 0 J "
        o << "[#{strich.map { |v| f(v * PT) }.join(' ')}] 0 d " if strich
        o << "#{f(x * PT)} #{f((hoehe_seite - y - h) * PT)} #{f(w * PT)} #{f(h * PT)} re "
        o << (fuellung && rand ? 'B' : fuellung ? 'f' : 'S') << " Q\n"
        self
      end

      def kreis(cx, cy, r, fuellung: [0, 0, 0], rand: nil, staerke: 0.2)
        k = 0.5523 * r
        y = hoehe_seite - cy
        pt = ->(a, b) { "#{f(a * PT)} #{f(b * PT)}" }
        o = op
        o << "q #{fuellung ? farbe_op(fuellung, 'rg') : ''}#{rand ? farbe_op(rand, 'RG') : ''}#{f(staerke * PT)} w "
        o << "#{pt.(cx + r, y)} m #{pt.(cx + r, y + k)} #{pt.(cx + k, y + r)} #{pt.(cx, y + r)} c "
        o << "#{pt.(cx - k, y + r)} #{pt.(cx - r, y + k)} #{pt.(cx - r, y)} c "
        o << "#{pt.(cx - r, y - k)} #{pt.(cx - k, y - r)} #{pt.(cx, y - r)} c "
        o << "#{pt.(cx + k, y - r)} #{pt.(cx + r, y - k)} #{pt.(cx + r, y)} c "
        o << (fuellung && rand ? 'B' : fuellung ? 'f' : 'S') << " Q\n"
        self
      end

      # Schraffur (Linien unter 45°) in einem Rechteck
      def schraffur(x, y, w, h, abstand: 3.0, farbe: [0.6, 0.6, 0.6], staerke: 0.15)
        ausschnitt(x, y, w, h) do
          d = -h
          while d < w
            linie(x + d, y + h, x + d + h, y, staerke: staerke, farbe: farbe)
            d += abstand
          end
        end
      end

      # Zeichnen nur innerhalb des Rechtecks
      def ausschnitt(x, y, w, h)
        op << "q #{f(x * PT)} #{f((hoehe_seite - y - h) * PT)} #{f(w * PT)} #{f(h * PT)} re W n\n"
        yield
        op << "Q\n"
        self
      end

      # QR-Code (Fehlerkorrektur M) als Quadrat mit Kantenlänge groesse, links oben x/y
      def qr(x, y, groesse, daten)
        q = RQRCodeCore::QRCode.new(daten.to_s, level: :m)
        n = q.module_count
        m = groesse / n.to_f
        o = op
        o << "q 0 0 0 rg\n"
        n.times do |r|
          c = 0
          while c < n
            if q.checked?(r, c)
              c2 = c
              c2 += 1 while c2 + 1 < n && q.checked?(r, c2 + 1)
              o << "#{f((x + c * m) * PT)} #{f((hoehe_seite - y - (r + 1) * m) * PT)} #{f((c2 - c + 1) * m * PT + 0.01)} #{f(m * PT + 0.01)} re\n"
              c = c2
            end
            c += 1
          end
        end
        o << "f Q\n"
        self
      end

      # --- Ausgabe ---

      def to_s
        objs = []
        objs << '<< /Type /Catalog /Pages 2 0 R >>'
        kinder = @seiten.each_index.map { |i| "#{5 + 2 * i} 0 R" }
        objs << "<< /Type /Pages /Count #{@seiten.size} /Kids [#{kinder.join(' ')}] >>"
        objs << '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>'
        objs << '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>'
        @seiten.each_with_index do |s, i|
          objs << "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 #{f(s[:b] * PT)} #{f(s[:h] * PT)}] " \
                  "/Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> /Contents #{6 + 2 * i} 0 R >>"
          inhalt = s[:ops].b
          objs << "<< /Length #{inhalt.bytesize} >>\nstream\n".b + inhalt + "\nendstream".b
        end
        objs << "<< /Title (#{escape(self.class.cp1252(@titel))}) /Producer (Kuechenplaner Schrank-CNC) >>" if @titel
        out = "%PDF-1.4\n%\xE2\xE3\xCF\xD3\n".b
        offsets = []
        objs.each_with_index do |o, i|
          offsets << out.bytesize
          out << "#{i + 1} 0 obj\n".b << o.b << "\nendobj\n".b
        end
        xref = out.bytesize
        out << "xref\n0 #{objs.size + 1}\n0000000000 65535 f \n".b
        offsets.each { |v| out << format("%010d 00000 n \n", v).b }
        out << "trailer\n<< /Size #{objs.size + 1} /Root 1 0 R#{@titel ? " /Info #{objs.size} 0 R" : ''} >>\nstartxref\n#{xref}\n%%EOF\n".b
        out
      end

      def schreiben(pfad)
        File.binwrite(pfad, to_s)
        pfad
      end

      private

      def aktuelle_seite
        raise 'Pdf: zuerst seite(...) aufrufen' if @seiten.empty?
        @aktuell ? @seiten[@aktuell] : @seiten.last
      end

      def op
        aktuelle_seite[:ops]
      end

      def f(v)
        r = v.to_f.round(3)
        r == r.to_i ? r.to_i.to_s : r.to_s
      end

      def farbe_op(c, art)
        "#{c.map { |v| f(v) }.join(' ')} #{art} "
      end

      def escape(s)
        s.to_s.b.gsub(/[\\()]/) { |m| "\\#{m}" }.gsub("\r", '\\r').gsub("\n", '\\n')
      end
    end
  end
end
