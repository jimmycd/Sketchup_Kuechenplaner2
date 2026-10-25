# encoding: UTF-8
# Schrank-CNC – TCN-Ausgabe für TpaCAD (TPA\ALBATROS\EDICAD 02.00).
# Kopf wie im Treppenbau (tcn.rb build_prog) und in Jürgens Beispielen,
# Bearbeitungen mit seinen Makros: squad (Formatieren), fittingx/fittingy
# (Bohrreihen), W#81 (Einzelbohrung). Lagen und DL/DH im Fräsmaß.

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

      def bohrung(ws, x, y, op)
        "W#81{ ::WTp WS=#{ws}  #8015=0 #1=#{x} #2=#{y} #3=#{n(-op.tiefe)} #1002=#{n(op.d)} #201=1 #203=1 #1001=0 }W"
      end

      # Bearbeitungen je TCN-Seite; Bearbeitungen auf Fläche 2 gehen nicht (Meldung)
      def seiten(lage, meldungen = [])
        s = Hash.new { |h, k| h[k] = [] }
        lage.ws.ops.each do |op|
          side = lage.side(op.seite)
          if side == 2
            meldungen << "#{lage.ws.name}: #{op.titel} liegt auf der Unterseite und fehlt in der TCN"
            next
          end
          s[side] << op
        end
        s
      end

      def zeilen(lage, side, ops, ws)
        ops.map do |op|
          ws += 1
          if side == 1
            if op.art == :bohrung
              x, y = lage.x(op.p0), lage.y(op.p0)
              bohrung(ws, ausdruck(x, lage.dl, 'x'), ausdruck(y, lage.dh, 'y'), op)
            elsif (lage.y(op.p0) - lage.y(op.p1)).abs < 0.001
              fitting(ws, 'fittingx', lage.x(op.p0), lage.x(op.p1), ausdruck(lage.y(op.p0), lage.dh, 'y'), op, 'x', lage.dl)
            else
              fitting(ws, 'fittingy', lage.y(op.p0), lage.y(op.p1), ausdruck(lage.x(op.p0), lage.dl, 'x'), op, 'y', lage.dh)
            end
          else
            # Stirnseite: im Makro ist x die Länge der Seite, #8518 die Tiefe unter Fläche 1
            lang = [4, 6].include?(side)
            u0 = lang ? lage.y(op.p0) : lage.x(op.p0)
            u1 = lang ? lage.y(op.p1) : lage.x(op.p1)
            fitting(ws, 'fittingx', u0, u1, n(lage.tiefe(op.p0)), op, 'x', lang ? lage.dh : lage.dl)
          end
        end
      end

      def build(lage, meldungen = [])
        w = lage.ws
        s = seiten(lage, meldungen)
        aktiv = ([1] + s.keys).uniq.sort
        out = []
        out << "TPA\\ALBATROS\\EDICAD\\02.00:1224:r0w0h0s#{FELD.fetch(w.rolle, 1)}"
        out << "::SIDE=#{aktiv.map { |x| "#{x};" }.join}"
        out << "::UNm DL=#{n(lage.dl)} DH=#{n(lage.dh)} DS=#{n(lage.ds)}"
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
        ws = 1
        out << 'SIDE#1{' << '$=F #1' << "W#1510{ ::WT2 WS=#{ws}  #{SQUAD} }W"
        z = zeilen(lage, 1, s[1], ws)
        ws += z.size
        out.concat(z) << '}SIDE'
        [3, 4, 5, 6].each do |side|
          out << "SIDE##{side}{" << "$=F ##{side}"
          z = zeilen(lage, side, s[side], ws)
          ws += z.size
          out.concat(z) << '}SIDE'
        end
        out
      end

      def text(lage, meldungen = []) = build(lage, meldungen).join("\r\n") + "\r\n"

      def write(path, text)
        File.open(path, 'wb') do |io|
          io.write(text.encode('Windows-1252', invalid: :replace, undef: :replace, replace: '_'))
        end
        path
      end
    end
  end
end
