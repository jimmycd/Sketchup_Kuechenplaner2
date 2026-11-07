# encoding: UTF-8
# Schrank-CNC – TCN-Ausgabe für TpaCAD (TPA\ALBATROS\EDICAD 02.00).
# Kopf wie im Treppenbau (tcn.rb build_prog) und in Jürgens Beispielen,
# Bearbeitungen mit seinen Makros: squad (Formatieren), fittingx/fittingy
# (Bohrreihen), W#81 (Einzelbohrung), W#89/W#2201 (Nut, Ausschnitt), inge100 (Topfband). Lagen und DL/DH im Fräsmaß.

module JTools
  module SchrankCnc
    module Tcn
      module_function

      # Feld am Ende der Kopfzeile wie in den Vorlagen (Pendeln kommt später)
      FELD = { 'Boden' => 13, 'Deckel' => 11, 'Strebe' => 10, 'Seite' => 54 }.freeze

      SQUAD = '#8098=..\custom\mcr\squad.tmcr #8500=50 #8501=50 #8502=1000 #8503=-s-2 #8504=0 #8505=0 ' \
              '#8506=2 #8507=0 #8508=0 #8509=0.5 #8510=0 #8511=-s+1 #8513=0 #8514=10'

      def n(v)
        v = v.to_f
        v = 0.0 if v.abs < 0.00005
        s = format('%.4f', v).sub(/\.?0+\z/, '')
        s == '-0' ? '0' : s
      end

      # Lage als Ausdruck wie in den Vorlagen: ab der Mitte vom Ende her ("x-30")
      def ausdruck(v, gesamt, var)
        rest = gesamt - v
        return n(v) if v <= gesamt / 2.0 + 0.00005
        rest.abs < 0.00005 ? var : "#{var}-#{n(rest)}"
      end

      def fitting(ws, makro, p0, p1, quer, op, var, gesamt)
        nr = makro == 'fittingx' ? 1001 : 1003
        p0, p1 = [p0, p1].minmax
        v = op.verteilt ? 1 : 0
        "W##{nr}{ ::WT2 WS=#{ws}  #8098=..\\custom\\mcr\\#{makro}.tmcr #6=1 #8508=#{v} #8509=#{v} " \
          "#8510=#{ausdruck(p0, gesamt, var)} #8511=#{ausdruck(p1, gesamt, var)} #8512=#{n(op.raster)} " \
          "#8513=#{n(-op.tiefe)} #8517=0 #8518=#{quer} #8520=1 #8521=1 #8522=#{n(op.d)} #8525=0 }W"
      end

      # Nut: Bahn mit dem Nutfräser (W#89 Start, W#2201 relativ wie im Treppenbau),
      # breiter als der Fräser in mehreren Bahnen nebeneinander
      def nut(ws, lage, op)
        nt = Regeln::NUT
        x0, y0, x1, y1 = lage.x(op.p0), lage.y(op.p0), lage.x(op.p1), lage.y(op.p1)
        len = Math.hypot(x1 - x0, y1 - y0)
        qx, qy = -(y1 - y0) / len, (x1 - x0) / len
        rest = [op.d - nt[:d_werkzeug], 0.0].max
        bahnen = rest < 0.05 ? 1 : (rest / nt[:d_werkzeug]).ceil + 1
        (0...bahnen).flat_map do |i|
          o = bahnen == 1 ? 0.0 : -rest / 2.0 + rest * i / (bahnen - 1)
          a, b = (i.odd? ? [[x1, y1], [x0, y0]] : [[x0, y0], [x1, y1]])
          ["W#89{ ::WTs WS=#{ws}  #8015=0 #1=#{n(a[0] + qx * o)} #2=#{n(a[1] + qy * o)} #3=#{n(-op.tiefe)} " \
           "#201=1 #203=1 #205=#{nt[:werkzeug]} #1001=100 #8101=0 #8096=0 #40=0 #46=1 " \
           '#8135=0 #8136=0 #8180=0 #8181=0 #8185=0 #8186=0 #9511=0 #9512=0 #9513=0 }W',
           "W#2201{ ::WTl  #8015=1 #1=#{n(b[0] - a[0])} #2=#{n(b[1] - a[1])} }W"]
        end
      end

      # Ausschnitt: geschlossene Kontur mit dem Nutfräser, um den Fräserradius nach innen versetzt
      def ausschnitt(ws, lage, op)
        nt = Regeln::NUT
        r = nt[:d_werkzeug] / 2.0
        xs = [lage.x(op.p0), lage.x(op.p1)].minmax
        ys = [lage.y(op.p0), lage.y(op.p1)].minmax
        bx = xs[1] - xs[0] - 2 * r
        by = ys[1] - ys[0] - 2 * r
        ["W#89{ ::WTs WS=#{ws}  #8015=0 #1=#{n(xs[0] + r)} #2=#{n(ys[0] + r)} #3=#{n(-op.tiefe)} " \
         "#201=1 #203=1 #205=#{nt[:werkzeug]} #1001=100 #8101=0 #8096=0 #40=0 #46=1 " \
         '#8135=0 #8136=0 #8180=0 #8181=0 #8185=0 #8186=0 #9511=0 #9512=0 #9513=0 }W'] +
          [[bx, 0], [0, by], [-bx, 0], [0, -by]].map { |dx, dy| "W#2201{ ::WTl  #8015=1 #1=#{n(dx)} #2=#{n(dy)} }W" }
      end

      # Schräg- oder Bogenkante (Abschlussregal) mit dem Konturfräser ganz durch: Bahn um den
      # Fräserradius in den Abfall versetzt, abzüglich Anleimer (die Kante ist im Endmaß gezeichnet).
      # Ein- und Auslauf tangential, so weit, dass der Fräser außerhalb der Platte startet und
      # endet (Jürgen: Fräsbahnen außerhalb beginnen und ins Material fahren). Bögen als kurze
      # Geraden (W#2201), nicht als W#2125: TPA meldete beim runden Deckel "Radius ungültig"
      # (Jürgen 2026-11-05, wie bei der Arbeitsplatte). Teilung: höchstens BOGEN_GRAD je Stück
      # und höchstens BOGEN_SEHNE mm Bogenlänge.
      BOGEN_GRAD = 5.0
      BOGEN_SEHNE = 10.0

      def bogen_punkte(a, c, r, w)
        teile = [(w.abs * 180 / Math::PI / BOGEN_GRAD).ceil, (w.abs * r / BOGEN_SEHNE).ceil, 1].max
        a0 = Math.atan2(a[1] - c[1], a[0] - c[0])
        (1..teile).map { |i| [c[0] + r * Math.cos(a0 + w * i / teile), c[1] + r * Math.sin(a0 + w * i / teile)] }
      end

      def kontur(ws, lage, op)
        k = Regeln::KONTUR
        r = k[:d] / 2.0
        d = r - op.daten[:anleimer].to_f
        p2 = ->(p) { [lage.x(p), lage.y(p)] }
        poly = op.daten[:umriss].map(&p2)
        ab = ->(a, b) { [a[0] - b[0], a[1] - b[1]] }
        auf = ->(a, v, f) { [a[0] + v[0] * f, a[1] + v[1] * f] }
        ein = ->(v) { l = Math.hypot(*v); [v[0] / l, v[1] / l] }
        bahn = op.daten[:segmente].map do |seg|
          a, b = p2.(seg[1]), p2.(seg[2])
          if seg[0] == :linie
            e = ein.(ab.(b, a))
            nrm = [-e[1], e[0]]
            m = auf.(a, ab.(b, a), 0.5)
            nrm = [-nrm[0], -nrm[1]] if Regeln.innen?(auf.(m, nrm, 0.5), poly)
            [:linie, auf.(a, nrm, d), auf.(b, nrm, d)]
          else
            c = p2.(seg[3])
            rr = Math.hypot(*ab.(a, c))
            w = Math.atan2(b[1] - c[1], b[0] - c[0]) - Math.atan2(a[1] - c[1], a[0] - c[0])
            w -= 2 * Math::PI while w > Math::PI
            w += 2 * Math::PI while w <= -Math::PI
            wm = Math.atan2(a[1] - c[1], a[0] - c[0]) + w / 2.0
            aussen = [c[0] + (rr + 0.5) * Math.cos(wm), c[1] + (rr + 0.5) * Math.sin(wm)]
            r2 = Regeln.innen?(aussen, poly) ? rr - d : rr + d
            f = ->(q) { auf.(c, ein.(ab.(q, c)), r2) }
            [:bogen, f.(a), f.(b), c, r2, w]
          end
        end
        # Zwei Geraden mit gemeinsamer Ecke (Ausklinkung): die versetzten Bahnen im Schnittpunkt
        # verbinden, sonst schneidet die Verbindung in der Innenecke ins Werkstück
        op.daten[:segmente].each_cons(2).with_index do |(s0, s1), i|
          next unless s0[0] == :linie && s1[0] == :linie && Math.hypot(*ab.(p2.(s0[2]), p2.(s1[1]))) < 0.001
          a0, a1 = bahn[i][1], bahn[i][2]
          b0, b1 = bahn[i + 1][1], bahn[i + 1][2]
          d0, d1 = ab.(a1, a0), ab.(b1, b0)
          kreuz = d0[0] * d1[1] - d0[1] * d1[0]
          next if kreuz.abs < 1e-9
          t = ((b0[0] - a0[0]) * d1[1] - (b0[1] - a0[1]) * d1[0]) / kreuz
          x = auf.(a0, d0, t)
          bahn[i][2] = x
          bahn[i + 1][1] = x
        end
        tangente = lambda do |seg, q|
          return ein.(ab.(seg[2], seg[1])) if seg[0] == :linie
          v = ab.(q, seg[3])
          seg[5] > 0 ? ein.([-v[1], v[0]]) : ein.([v[1], -v[0]])
        end
        aus = r + k[:ueberlauf]
        start = auf.(bahn.first[1], tangente.(bahn.first, bahn.first[1]), -aus)
        ende = auf.(bahn.last[2], tangente.(bahn.last, bahn.last[2]), aus)
        gerade = ->(a, b) { "W#2201{ ::WTl  #8015=1 #1=#{n(b[0] - a[0])} #2=#{n(b[1] - a[1])} }W" }
        out = ["W#89{ ::WTs WS=#{ws}  #8015=0 #1=#{n(start[0])} #2=#{n(start[1])} #3=#{n(-op.tiefe)} " \
               "#201=1 #203=1 #205=#{k[:werkzeug]} #1001=100 #8101=0 #8096=0 #40=0 #46=1 " \
               '#8135=0 #8136=0 #8180=0 #8181=0 #8185=0 #8186=0 #9511=0 #9512=0 #9513=0 }W']
        pos = start
        bahn.each do |seg|
          out << gerade.(pos, seg[1]) if Math.hypot(*ab.(seg[1], pos)) > 0.001
          if seg[0] == :linie
            out << gerade.(seg[1], seg[2])
          else
            q = seg[1]
            pts = bogen_punkte(seg[1], seg[3], seg[4], seg[5])
            pts[-1] = seg[2]
            pts.each { |x| out << gerade.(q, x); q = x }
          end
          pos = seg[2]
        end
        out << gerade.(pos, ende)
      end

      # Griffkante: Fase 45° mit dem Folding-Fräser (1400) entlang der Kante, Spitze auf der Kante in der
      # Tiefe der Fase; Bahn beginnt und endet außerhalb der Front (Grifflos.op)
      def fase(ws, lage, op)
        x0, y0, x1, y1 = lage.x(op.p0), lage.y(op.p0), lage.x(op.p1), lage.y(op.p1)
        ["W#89{ ::WTs WS=#{ws}  #8015=0 #1=#{n(x0)} #2=#{n(y0)} #3=#{n(-op.tiefe)} " \
         "#201=1 #203=1 #205=#{op.daten[:werkzeug]} #1001=100 #8101=0 #8096=0 #40=0 #46=1 " \
         '#8135=0 #8136=0 #8180=0 #8181=0 #8185=0 #8186=0 #9511=0 #9512=0 #9513=0 }W',
         "W#2201{ ::WTl  #8015=1 #1=#{n(x1 - x0)} #2=#{n(y1 - y0)} }W"]
      end

      # Länge einer Tasche, über das ganze Werkstück als "h+20" wie in Schubkastenboden.tcn
      def laenge(v, gesamt, var)
        d = v - gesamt
        return n(v) if d < -0.00005
        d.abs < 0.00005 ? var : "#{var}+#{n(d)}"
      end

      # Rechtecktasche (rect.tmcr) wie in Schubkastenboden.tcn: Mitte, Breite in x, Länge in y
      def tasche(ws, lage, op)
        xs = [lage.x(op.p0), lage.x(op.p1)].minmax
        ys = [lage.y(op.p0), lage.y(op.p1)].minmax
        "W#1022{ ::WT2 WS=#{ws}  #8098=rect.tmcr #6=1 #8015=0 #8020=#{ausdruck(xs.sum / 2.0, lage.dl, 'x')} " \
          "#8021=#{ausdruck(ys.sum / 2.0, lage.dh, 'y')} #8101=0 #8103=0 #8104=0 #8100=0 #8505=2 " \
          "#8509=#{laenge(xs[1] - xs[0], lage.dl, 'l')} #8510=#{laenge(ys[1] - ys[0], lage.dh, 'h')} #8511=0 #8512=0 " \
          "#8514=#{n(-op.tiefe)} #8515=100 #8516=0 #8520=1 #8521=1 #8522=1000 #8524=0 #8525=0 }W"
      end

      # Blum-Topfband wie T_re_L_Topfband.tcn: Makro inge100, x entlang der Anschlagkante,
      # Anschlagkante bei y = DH (Geometrie.lage dreht die Tür so)
      def topfband(ws, lage, op)
        x = ausdruck(lage.x(op.p0), lage.dl, 'x')
        y = ausdruck(lage.y(op.p0), lage.dh, 'y')
        sc = (op.daten && op.daten[:schraub]) || { d: 8, abstand: 45, versatz: 9.5 }
        "W#1506{ ::WT2 WS=#{ws}  #8098=..\\custom\\mcr\\inge100.tmcr #8500=#{n(op.d)} #8501=#{n(sc[:d])} #8502=#{n(sc[:abstand])} " \
          "#8503=#{n(sc[:versatz]).tr('.', ',')} " \
          "#8504=#{n(op.tiefe)} #8505=14 #8506=1 #8507=#{x} #8508=#{y} }W"
      end

      def bohrung(ws, x, y, op)
        "W#81{ ::WTp WS=#{ws}  #8015=0 #1=#{x} #2=#{y} #3=#{n(-op.tiefe)} #1002=#{n(op.d)} #201=1 #203=1 #1001=0 }W"
      end

      # Bearbeitungen je TCN-Seite; Bearbeitungen auf Fläche 2 gehen nicht (Meldung)
      def seiten(lage, meldungen = [])
        s = Hash.new { |h, k| h[k] = [] }
        lage.ws.ops.each do |op|
          if op.art == :kontur # ganz durch, immer von Fläche 1 aus
            s[1] << op
            next
          end
          side = lage.side(op.seite)
          if side == 2
            meldungen << "#{lage.ws.name}: #{op.titel} liegt auf der Unterseite und fehlt in der TCN"
            next
          end
          if %i[nut tasche ausschnitt topfband fase].include?(op.art) && side != 1
            meldungen << "#{lage.ws.name}: #{op.titel} liegt nicht auf Fläche 1 und fehlt in der TCN"
            next
          end
          s[side] << op
        end
        s
      end

      # Zeilen einer Bearbeitung, WS als Platzhalter "@" (Nummern vergibt zeilen)
      def op_zeilen(lage, side, op)
        return nut('@', lage, op) if op.art == :nut
        return ausschnitt('@', lage, op) if op.art == :ausschnitt
        return [tasche('@', lage, op)] if op.art == :tasche
        return kontur('@', lage, op) if op.art == :kontur
        return fase('@', lage, op) if op.art == :fase
        return [topfband('@', lage, op)] if op.art == :topfband
        if side == 1
          if op.art == :bohrung
            x, y = lage.x(op.p0), lage.y(op.p0)
            [bohrung('@', ausdruck(x, lage.dl, 'x'), ausdruck(y, lage.dh, 'y'), op)]
          elsif (lage.y(op.p0) - lage.y(op.p1)).abs < 0.001
            [fitting('@', 'fittingx', lage.x(op.p0), lage.x(op.p1), ausdruck(lage.y(op.p0), lage.dh, 'y'), op, 'x', lage.dl)]
          else
            [fitting('@', 'fittingy', lage.y(op.p0), lage.y(op.p1), ausdruck(lage.x(op.p0), lage.dl, 'x'), op, 'y', lage.dh)]
          end
        else
          # Stirnseite: im Makro ist x die Länge der Seite, #8518 die Tiefe unter Fläche 1
          lang = [4, 6].include?(side)
          u0 = lang ? lage.y(op.p0) : lage.x(op.p0)
          u1 = lang ? lage.y(op.p1) : lage.x(op.p1)
          [fitting('@', 'fittingx', u0, u1, n(lage.tiefe(op.p0)), op, 'x', lang ? lage.dh : lage.dl)]
        end
      end

      # Fräsungen nie in voller Tiefe auf einmal (Materialschonung, Jürgen 2026-11-02,
      # gilt für alle TCN): tiefer als ZUSTELLUNG wird die Bahn in gleich großen
      # Schritten von höchstens ZUSTELLUNG wiederholt, jede Stufe als eigene Bearbeitung
      ZUSTELLUNG = 20.0

      def stufen(tiefe)
        tiefe = tiefe.to_f
        k = (tiefe / ZUSTELLUNG - 1e-6).ceil
        k <= 1 ? [tiefe] : (1..k).map { |i| tiefe * i / k }
      end

      # Zeilen -> Zeilen mit Zustellschritten: Fräsbahn = W#89 + folgende Bahnzeilen
      # (W#2201 Gerade, W#2125 Bogen …), Tasche = W#1022 (rect.tmcr, Tiefe #8514)
      def zustellen(zeilen)
        bloecke = []
        zeilen.each do |l|
          if bloecke.last && bloecke.last[0].start_with?('W#89{') && l =~ /\AW#2\d{3}\{ ::WT[la]/
            bloecke.last << l
          else
            bloecke << [l]
          end
        end
        bloecke.flat_map do |b|
          feld = b[0].start_with?('W#89{') ? '#3' : (b[0].start_with?('W#1022{') ? '#8514' : nil)
          t = feld && b[0][/ #{feld}=(-[\d.]+) /, 1].to_f.abs
          next b unless t && t > ZUSTELLUNG + 1e-6
          stufen(t).flat_map { |s| [b[0].sub(/ #{feld}=-[\d.]+ /, " #{feld}=#{n(-s)} ")] + b[1..] }
        end
      end

      # Zeilen einer Seite, nach Inhalt sortiert (gespiegelte Teile ergeben dieselbe TCN),
      # dann fortlaufend nummeriert ab ws + 1
      def zeilen(lage, side, ops, ws)
        z = ops.map { |op| op_zeilen(lage, side, op) }.sort_by { |x| x.join("\n") }.flatten
        zustellen(z).map do |l|
          l.include?('WS=@') ? l.sub('WS=@', "WS=#{ws += 1}") : l
        end
      end

      # Kopf bis einschließlich SIDE#0, gleich für alle Teile
      def kopf(dl, dh, ds, feld, aktiv)
        out = []
        out << "TPA\\ALBATROS\\EDICAD\\02.00:1224:r0w0h0s#{feld}"
        out << "::SIDE=#{aktiv.map { |x| "#{x};" }.join}"
        out << "::UNm DL=#{n(dl)} DH=#{n(dh)} DS=#{n(ds)}"
        out << "'tcn version=2.6.14"
        out << "'code=ansi"
        out << 'EXE{' << '#0=0' << '#1=0' << '#2=0' << '#3=0' << '#4=0' << '}EXE'
        out << 'OFFS{' << '#0=0|0' << '#1=0|0' << '#2=0|0' << '}OFFS'
        out << 'VARV{'
        ['1|1', '2|2', '3|3', '4|4', '0|0', '0|0', '0|0', '0|0'].each_with_index { |v, i| out << "##{i}=#{v}" }
        out << '}VARV'
        out << 'VAR{' << '}VAR' << 'SPEC{' << '}SPEC' << 'INFO{' << '}INFO'
        out << 'OPTI{'
        out << ':: OPTDEF=1 OPTIMIZE=%;0 OPTMIN=0 OPT3=0 OPT0=0 OPTTOOL=0 OPT2=0 OPTX=0 OPTY=0 OPTR=0 ' \
               'OPT4=0 OPT6=0 OPT7=0 LSTCOD=0%1%2%3 LTOOLFR=0 LTOOLPN=0 OPTF1=0 OOO=0.5'
        out << '}OPTI' << 'LINK{' << '}LINK'
        out << 'SIDE#0{' << '$=F #0' << '}SIDE'
      end

      # formatieren: false beim zweiten Programm fürs gewendete Werkstück (schon formatiert)
      def build(lage, meldungen = [], formatieren: true)
        w = lage.ws
        s = seiten(lage, meldungen)
        aktiv = ([1] + s.keys).uniq.sort
        out = kopf(lage.dl, lage.dh, lage.ds, FELD.fetch(w.rolle, 1), aktiv)
        ws = formatieren ? 1 : 0
        out << 'SIDE#1{' << '$=F #1'
        out << "W#1510{ ::WT2 WS=#{ws}  #{SQUAD} }W" if formatieren
        z = zeilen(lage, 1, s[1], ws)
        ws += z.count { |l| l.include?(' WS=') }
        out.concat(z) << '}SIDE'
        [3, 4, 5, 6].each do |side|
          out << "SIDE##{side}{" << "$=F ##{side}"
          z = zeilen(lage, side, s[side], ws)
          ws += z.count { |l| l.include?(' WS=') }
          out.concat(z) << '}SIDE'
        end
        out
      end

      def text(lage, meldungen = [], formatieren: true)
        build(lage, meldungen, formatieren: formatieren).join("\r\n") + "\r\n"
      end

      def write(path, text)
        File.open(path, 'wb') do |io|
          io.write(text.encode('Windows-1252', invalid: :replace, undef: :replace, replace: '_'))
        end
        path
      end
    end
  end
end
