# encoding: UTF-8
# Schrank-CNC – TCN für Arbeitsplatten (Komponenten/arbeitsplatte): Verbindungsfräsung.
#
# Je Stoßende einer Platte eine TCN "<Tag>_Stoss<nr>", Platten ohne Stoß mit
# Ausschnitt eine TCN "<Tag>". Die Platte liegt mit dem Dekor nach unten, das
# Stoßende am Anschlag links unten (x = 0). Arbeitsbereich 3200 × 1300 mm, in x
# ist die Auflage unbegrenzt; die Platte wird bauseits abgelängt, die TCN fräst nur:
#   Kontur   Stoßkante (Gehrungsansatz mit Bogen, Gehrung, stumpf, Längsstoß) mit
#            dem Konturfräser, um den Radius in den Abfall versetzt, ganz durch.
#            Die durchlaufende Platte bekommt dazu ihr Ende an der Wand.
#   Hundeknochen  je Verbinder Bohrung Ø 35 (65 mm vom Stoß) und Steg 12 breit zum Stoß,
#            20 tief. 2 Verbinder bis 650 mm Stoßlänge, 3 bis 900, sonst 4;
#            Gehrung immer 4. 80 mm von Wand und Vorderkante.
#   Ausschnitte Spüle/Kochfeld, wenn sie im Arbeitsbereich liegen.
# Maße und Stoßpfade liest der Export aus dem Wörterbuch JT_Arbeitsplatte, nicht
# aus der Geometrie (Weltkoordinaten in mm, wie beim Erzeugen gerechnet).

require 'json'

module JTools
  module SchrankCnc
    module Arbeitsplatten
      AP_DICT = 'JT_Arbeitsplatte'.freeze
      # Werkzeuge aus Jürgens Werkzeugliste (Fläche 1): Kontur mit 1004 (Ø 20,
      # Jürgens Wahl 2026-11-01), Steg 12 mm breit mit dem
      # VHM Ø 8 (2200) in zwei Bahnen, ein 12er Fräser ist nicht vorhanden.
      # Die Bohrung Ø 35 wählt die Maschine über den Durchmesser.
      KONTUR = { werkzeug: 1004, d: 20.0, ueberlauf: 10.0, durch: 1.0 }.freeze
      STEG = { werkzeug: 2200, d: 8.0, breite: 12.0, ueberlauf: 5.0 }.freeze # ueberlauf: Fräserrand vor der Kante
      HUNDEKNOCHEN = { d: 35.0, tiefe: 20.0, abstand: 65.0, rand: 80.0 }.freeze
      FELD = { x: 3200.0, y: 1300.0 }.freeze
      NORMALE = { 'ny' => [0.0, -1.0], 'py' => [0.0, 1.0], 'nx' => [-1.0, 0.0], 'px' => [1.0, 0.0] }.freeze

      Ws = Struct.new(:teil)
      Lage = Struct.new(:dl, :dh, :ds)
      Op = Struct.new(:d, :tiefe)

      # -------------------------------------------------------------------------
      # Geometrie (2D, mm)
      # -------------------------------------------------------------------------
      def self.minus(a, b)
        [a[0] - b[0], a[1] - b[1]]
      end

      def self.plus(a, b, f = 1.0)
        [a[0] + b[0] * f, a[1] + b[1] * f]
      end

      def self.skalar(a, b)
        a[0] * b[0] + a[1] * b[1]
      end

      def self.einheit(v)
        l = Math.hypot(*v)
        [v[0] / l, v[1] / l]
      end

      def self.innen?(p, poly)
        x, y = p
        drin = false
        poly.each_with_index do |a, i|
          b = poly[i - 1]
          drin = !drin if (a[1] > y) != (b[1] > y) && x < (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]) + a[0]
        end
        drin
      end

      def self.abstand(p, a, b)
        d = minus(b, a)
        l2 = skalar(d, d)
        t = l2.zero? ? 0.0 : (skalar(minus(p, a), d) / l2).clamp(0.0, 1.0)
        Math.hypot(*minus(p, plus(a, d, t)))
      end

      # Punkte eines Stoßpfads [[linie, p0, p1] | [bogen, p0, p1, mitte, r]] mit Startpunkt
      def self.pfad_punkte(pfad, teile)
        [pfad[0][1]] + pfad.flat_map do |seg|
          next [seg[2]] if seg[0] == 'linie'
          _, p0, p1, c, r = seg
          a0 = Math.atan2(p0[1] - c[1], p0[0] - c[0])
          da = Math.atan2(p1[1] - c[1], p1[0] - c[0]) - a0
          da -= 2 * Math::PI while da > Math::PI
          da += 2 * Math::PI while da < -Math::PI
          (1..teile).map { |i| [c[0] + r * Math.cos(a0 + da * i / teile), c[1] + r * Math.sin(a0 + da * i / teile)] }
        end
      end

      # Linienzug um d nach links versetzt (d < 0: rechts), Ecken als Schnitt der Geraden
      def self.versatz(pts, d, geschlossen = false)
        n = pts.size
        segs = (0...(geschlossen ? n : n - 1)).map do |i|
          a, b = pts[i], pts[(i + 1) % n]
          e = einheit(minus(b, a))
          nrm = [-e[1], e[0]]
          [plus(a, nrm, d), plus(b, nrm, d), e]
        end
        schnitt = lambda do |s1, s2|
          k = s1[2][0] * s2[2][1] - s1[2][1] * s2[2][0]
          return s1[1] if k.abs < 1e-9
          t = ((s2[0][0] - s1[0][0]) * s2[2][1] - (s2[0][1] - s1[0][1]) * s2[2][0]) / k
          plus(s1[0], s1[2], t)
        end
        if geschlossen
          segs.each_index.map { |i| schnitt.(segs[i - 1], segs[i]) }
        else
          [segs[0][0]] + segs.each_cons(2).map { |s1, s2| schnitt.(s1, s2) } + [segs[-1][1]]
        end
      end

      # -------------------------------------------------------------------------
      # Platten im Modell
      # -------------------------------------------------------------------------
      def self.teile(model, auswahl: nil)
        Schraenke.teile(model).select do |t|
          t.rolle == 'Arbeitsplatte' && t.sichtbar? && (auswahl.nil? || t.pfad.any? { |i| auswahl.include?(i) })
        end
      end

      def self.ap(inst, k)
        inst.get_attribute(AP_DICT, k)
      end

      # Platte als Hash aus den gespeicherten Werten; nil, wenn etwas fehlt
      def self.platte(t)
        haupt = Schraenke.definition(t.schrank)
        werte = %w[nr punkte kanten front staerke].map { |k| ap(t.inst, k) }
        return nil if werte.any?(&:nil?) || haupt.get_attribute(AP_DICT, 'stoesse').nil?
        o = JSON.parse(haupt.get_attribute(AP_DICT, 'optionen') || '{}')
        nr = werte[0].to_i
        { nr: nr, punkte: JSON.parse(werte[1]), kanten: JSON.parse(werte[2]), front: werte[3].to_s,
          staerke: werte[4].to_f, ausschnitte: JSON.parse(ap(t.inst, 'ausschnitte') || '[]'),
          stoesse: JSON.parse(haupt.get_attribute(AP_DICT, 'stoesse')).select { |s| s['platten'].include?(nr) },
          bogen_teile: (o['bogen_teile'] || 8).to_i }
      end

      # Maschinenlage: u längs (nach rechts, vor der Platte stehend), v ab der Vorderkante.
      # Stoß rechts: x = Umax - u, y = v; Stoß links: x = u - Umin, y = Vmax - v
      def self.rahmen(p, ende)
        n = NORMALE.fetch(p[:front])
        r = [-n[1], n[0]]
        uv = ->(q) { [skalar(q, r), -skalar(q, n)] }
        us, vs = p[:punkte].map(&uv).transpose
        umin, umax, vmin, vmax = us.min, us.max, vs.min, vs.max
        abb = lambda do |q|
          u, v = uv.(q)
          ende == :rechts ? [umax - u, v - vmin] : [u - umin, vmax - v]
        end
        { abb: abb, uv: uv, mitte: (umin + umax) / 2.0, lage: Lage.new(umax - umin, vmax - vmin, p[:staerke]) }
      end

      # Kanten der Platte am Stoß als Linienzug (Weltkoordinaten), nil = keine Kontur
      def self.kontur(p, s, pfad)
        durch = s['platten'][0] == p[:nr] && s['art'] != 'laengs'
        return nil if durch && s['art'] == 'stumpf'
        pts, kanten = p[:punkte], p[:kanten]
        m = pts.size
        auf_pfad = ->(q) { pfad.each_cons(2).any? { |a, b| abstand(q, a, b) < 0.05 } }
        wahl = (0...m).select { |i| kanten[i] == 'stoss' && auf_pfad.(pts[i]) && auf_pfad.(pts[(i + 1) % m]) }
        return nil if wahl.empty?
        if durch
          w = pfad.last
          wand = [wahl.min - 1, wahl.max + 1].map { |i| i % m }.find do |i|
            kanten[i] == 'wand' && [pts[i], pts[(i + 1) % m]].any? { |q| Math.hypot(*minus(q, w)) < 0.05 }
          end
          wahl << wand if wand
        end
        start = wahl.find { |i| !wahl.include?((i - 1) % m) } || wahl.min
        folge = [start]
        folge << (folge.last + 1) % m while wahl.include?((folge.last + 1) % m) && folge.size < wahl.size
        folge.map { |i| pts[i] } + [pts[(folge.last + 1) % m]]
      end

      # Verbinder entlang des letzten geraden Stücks (zur Wand hin)
      def self.verbinder(p, s)
        lin = s['pfad'].reverse.find { |seg| seg[0] == 'linie' }
        w = lin[2]
        f = einheit(minus(lin[1], w))
        laenge = skalar(minus(s['pfad'][0][1], w), f)
        anzahl = s['art'] == 'gehrung' ? 4 : (laenge <= 650 ? 2 : (laenge <= 900 ? 3 : 4))
        hk = HUNDEKNOCHEN
        nrm = [-f[1], f[0]]
        (0...anzahl).map do |i|
          a = hk[:rand] + (laenge - 2 * hk[:rand]) * i / (anzahl - 1)
          q = plus(w, f, a)
          c = [1, -1].map { |sg| plus(q, nrm, sg * hk[:abstand]) }.find { |x| innen?(x, p[:punkte]) }
          c && [q, c]
        end.compact
      end

      # Konturzug -> Stücke [:linie, a, b] / [:bogen, a, b, mitte, r]: aufeinanderfolgende
      # Sehnen auf einem Bogen des Stoßpfads werden wieder zu einem Bogen
      def self.stuecke(pts, pfad)
        boegen = pfad.select { |seg| seg[0] == 'bogen' }.map { |seg| [seg[3], seg[4].to_f] }
        auf = lambda do |a, b|
          boegen.find do |c, r|
            m = [(a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0]
            (Math.hypot(*minus(a, c)) - r).abs < 0.05 && (Math.hypot(*minus(b, c)) - r).abs < 0.05 &&
              Math.hypot(*minus(m, c)) < r - 1e-6
          end
        end
        out = []
        pts.each_cons(2) do |a, b|
          bg = auf.(a, b)
          if bg && out.last && out.last[0] == :bogen && out.last[3] == bg[0]
            out.last[2] = b
          elsif bg
            out << [:bogen, a, b, bg[0], bg[1]]
          else
            out << [:linie, a, b]
          end
        end
        out
      end

      def self.drehsinn(a, b, c)
        (a[0] - c[0]) * (b[1] - c[1]) - (a[1] - c[1]) * (b[0] - c[0]) > 0 ? 1 : -1
      end

      # Stücke um d nach rechts versetzt (Bögen bleiben Bögen, tangentiale Übergänge
      # bleiben tangential, Ecken als Schnitt der Geraden), Anfang und Ende um
      # aus verlängert
      def self.versatz_rechts(st, d, aus)
        v = st.map do |seg|
          if seg[0] == :linie
            e = einheit(minus(seg[2], seg[1]))
            nr = [e[1], -e[0]]
            [:linie, plus(seg[1], nr, d), plus(seg[2], nr, d)]
          else
            _, a, b, c, r = seg
            r2 = r + drehsinn(a, b, c) * d # gegen den Uhrzeigersinn: Mitte links, rechts = außen
            f = ->(q) { plus(c, einheit(minus(q, c)), r2) }
            [:bogen, f.(a), f.(b), c, r2]
          end
        end
        v.each_cons(2) do |s1, s2|
          next if Math.hypot(*minus(s1[2], s2[1])) < 0.01 || s1[0] != :linie || s2[0] != :linie
          d1, d2 = minus(s1[2], s1[1]), minus(s2[2], s2[1])
          k = d1[0] * d2[1] - d1[1] * d2[0]
          next if k.abs < 1e-9
          t = ((s2[1][0] - s1[1][0]) * d2[1] - (s2[1][1] - s1[1][1]) * d2[0]) / k
          x = plus(s1[1], d1, t) # Schnitt der beiden Geraden
          s1[2] = x
          s2[1] = x
        end
        if v.first[0] == :linie
          v.first[1] = plus(v.first[1], einheit(minus(v.first[1], v.first[2])), aus)
        end
        v.last[2] = plus(v.last[2], einheit(minus(v.last[2], v.last[1])), aus) if v.last[0] == :linie
        v
      end

      # Ausschnitt als geschlossene Fräserbahn (Weltkoordinaten), um den Radius nach innen
      def self.ausschnitt_bahn(a)
        r = KONTUR[:d] / 2.0
        if a['radius'].to_f <= r + 0.01
          x0, y0, x1, y1 = a['rechteck']
          [[x0 + r, y0 + r], [x1 - r, y0 + r], [x1 - r, y1 - r], [x0 + r, y1 - r]]
        else
          versatz(a['punkte'], r, true)
        end
      end

      # -------------------------------------------------------------------------
      # TCN-Zeilen (Fläche 1 = Unterseite der Platte, Dekor liegt unten)
      # -------------------------------------------------------------------------
      def self.bahn(ws, pts, tiefe, werkzeug, geschlossen = false)
        n = ->(v) { Tcn.n(v) }
        pts = pts + [pts[0]] if geschlossen
        ["W#89{ ::WTs WS=#{ws}  #8015=0 #1=#{n.(pts[0][0])} #2=#{n.(pts[0][1])} #3=#{n.(-tiefe)} " \
         "#201=1 #203=1 #205=#{werkzeug} #1001=100 #8101=0 #8096=0 #40=0 #46=1 " \
         '#8135=0 #8136=0 #8180=0 #8181=0 #8185=0 #8186=0 #9511=0 #9512=0 #9513=0 }W'] +
          pts.each_cons(2).map { |a, b| "W#2201{ ::WTl  #8015=1 #1=#{n.(b[0] - a[0])} #2=#{n.(b[1] - a[1])} }W" }
      end

      # Steg: startet ganz außerhalb der Stoßkante (Fräser samt Radius im Abfall, der
      # Konturfräser hat ihn vorher entfernt) und fährt ins Material bis zur Bohrung,
      # das gibt einen sauberen Übergang; breiter als der Fräser in Bahnen nebeneinander
      # Bahn aus Stücken in Maschinenkoordinaten: Geraden relativ (W#2201), Bögen wie in
      # Jürgens bogen.tcn als tangentialer Bogen mit Radius und Winkel (W#2125,
      # #8046 Winkel in Grad). Die übrigen Werte genau wie im Beispiel lassen: dort
      # steht EW2 (Drehrichtung) auf Automatisch, nur dann gilt das Vorzeichen des
      # Winkels als Drehrichtung (Jürgen 2026-11-01).
      # Vorzeichen: TPA zeigt Fläche 1 mit y nach unten, "negativ = im Uhrzeigersinn"
      # gilt für diese Ansicht. In den Maschinenkoordinaten (x rechts, y hoch gerechnet)
      # ist das genau umgekehrt, deshalb wird der gerechnete Winkel negiert
      # (sonst läuft der Bogen falsch herum, Jürgen 2026-11-02)
      def self.bahn_stuecke(ws, st, tiefe, werkzeug)
        n = ->(v) { Tcn.n(v) }
        out = bahn(ws, [st[0][1]], tiefe, werkzeug)
        st.each do |seg|
          a, b = seg[1], seg[2]
          if seg[0] == :linie
            out << "W#2201{ ::WTl  #8015=1 #1=#{n.(b[0] - a[0])} #2=#{n.(b[1] - a[1])} }W"
          else
            c, r = seg[3], seg[4]
            w = Math.atan2(b[1] - c[1], b[0] - c[0]) - Math.atan2(a[1] - c[1], a[0] - c[0])
            w -= 2 * Math::PI while w > Math::PI
            w += 2 * Math::PI while w <= -Math::PI
            out << "W#2125{ ::WTa  #8015=0 #8019=0 #8017=#{n.(r)} #8048=1 #8046=#{n.(-w * 180 / Math::PI)} #42=0 #49=0 }W"
          end
        end
        out
      end

      def self.steg(q, c, tiefe)
        rest = STEG[:breite] - STEG[:d]
        e = einheit(minus(c, q))
        nrm = [-e[1], e[0]]
        q = plus(q, e, -(STEG[:d] / 2.0 + STEG[:ueberlauf]))
        bahnen = rest < 0.05 ? 1 : (rest / STEG[:d]).ceil + 1
        (0...bahnen).map do |i|
          o = bahnen == 1 ? 0.0 : -rest / 2.0 + rest * i / (bahnen - 1)
          bahn('@', [plus(q, nrm, o), plus(c, nrm, o)], tiefe, STEG[:werkzeug])
        end
      end

      def self.text(lage, bearbeitungen)
        out = Tcn.kopf(lage.dl, lage.dh, lage.ds, 1, [1])
        ws = 0
        out << 'SIDE#1{' << '$=F #1'
        bearbeitungen.each do |zeilen|
          ws += 1
          out.concat(zeilen.map { |l| l.sub('WS=@', "WS=#{ws}") })
        end
        out << '}SIDE'
        [3, 4, 5, 6].each { |side| out << "SIDE##{side}{" << "$=F ##{side}" << '}SIDE' }
        out.join("\r\n") + "\r\n"
      end

      def self.im_feld?(pts)
        pts.all? { |x, y| x <= FELD[:x] + 1e-6 && y <= FELD[:y] + 1e-6 }
      end

      # Bearbeitungen eines Stoßendes (Liste von Zeilen-Blöcken, WS als "@")
      def self.stoss_bearbeitungen(p, stoesse, rah, name, meldungen)
        abb = rah[:abb]
        hk = HUNDEKNOCHEN
        r = KONTUR[:d] / 2.0
        b = []
        stoesse.each do |s|
          pfad = pfad_punkte(s['pfad'], p[:bogen_teile])
          k = kontur(p, s, pfad)
          if k
            # Abfall liegt rechts (Umriss gegen den Uhrzeigersinn), Bahn über die Kanten hinaus
            v = versatz_rechts(stuecke(k, s['pfad']), r, r + KONTUR[:ueberlauf])
            m = v.map { |seg| seg[0] == :linie ? [seg[0], abb.(seg[1]), abb.(seg[2])] : [seg[0], abb.(seg[1]), abb.(seg[2]), abb.(seg[3]), seg[4]] }
            if im_feld?(m.flat_map { |seg| [seg[1], seg[2]] })
              b << bahn_stuecke('@', m, p[:staerke] + KONTUR[:durch], KONTUR[:werkzeug])
            else
              meldungen << "#{name}: Stoßkontur #{s['nr']} liegt außerhalb des Arbeitsbereichs #{FELD[:x].round} × #{FELD[:y].round}"
            end
          end
          verbinder(p, s).each do |q, c|
            mq, mc = abb.(q), abb.(c)
            unless im_feld?([mq, mc])
              meldungen << "#{name}: Verbinder an Stoß #{s['nr']} außerhalb des Arbeitsbereichs"
              next
            end
            b << [Tcn.bohrung('@', Tcn.n(mc[0]), Tcn.n(mc[1]), Op.new(hk[:d], hk[:tiefe]))]
            b.concat(steg(mq, mc, hk[:tiefe]))
          end
        end
        b
      end

      # Ergebnis: [[[name, text, teil, lage], …], meldungen]
      def self.dateien(model, auswahl: nil)
        meldungen = []
        out = []
        teile(model, auswahl: auswahl).each do |t|
          name = Export.dateiname(t.name)
          p = platte(t)
          unless p
            meldungen << "#{name}: Daten der Arbeitsplatte fehlen, bitte „Arbeitsplatte neu berechnen“"
            next
          end
          rah0 = rahmen(p, :links)
          enden = p[:stoesse].group_by do |s|
            us = pfad_punkte(s['pfad'], p[:bogen_teile]).map { |q| rah0[:uv].(q)[0] }
            us.sum / us.size > rah0[:mitte] ? :rechts : :links
          end
          enden = { links: [] } if enden.empty? && p[:ausschnitte].any?
          dats = enden.map do |ende, st|
            rah = rahmen(p, ende)
            n = st.empty? ? name : "#{name}_Stoss#{st.map { |s| s['nr'] }.min}"
            meldungen << "#{n}: Platte #{rah[:lage].dh.round} mm breit, Arbeitsbereich #{FELD[:y].round}" if rah[:lage].dh > FELD[:y]
            { name: n, rah: rah, b: stoss_bearbeitungen(p, st, rah, n, meldungen) }
          end
          # Ausschnitte in die TCN, in der sie am nächsten am Anschlag liegen
          p[:ausschnitte].each do |a|
            bahnen = dats.map { |d| ausschnitt_bahn(a).map(&d[:rah][:abb]) }
            i = bahnen.each_index.min_by { |j| bahnen[j].map(&:first).max }
            if i && im_feld?(bahnen[i])
              dats[i][:b] << bahn('@', bahnen[i], p[:staerke] + KONTUR[:durch], KONTUR[:werkzeug], true)
            else
              meldungen << "#{name}: Ausschnitt über #{a['schrank']} liegt außerhalb des Arbeitsbereichs, bitte von Hand"
            end
          end
          dats.each { |d| out << [d[:name], text(d[:rah][:lage], d[:b]), t, d[:rah][:lage]] }
        end
        [out, meldungen]
      end
    end
  end
end
