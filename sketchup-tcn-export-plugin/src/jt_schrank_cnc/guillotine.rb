# encoding: UTF-8
# Schrank-CNC – Guillotine-Zuschnitt in Stufen für die Formatsäge.
#
# Begriffe wie im Schnittplan von OpenCutList (Rectangle Guillotine):
#   Stufe 1  durchgehende Schnitte über die ganze (besäumte) Platte → Streifen
#   Stufe 2  Schnitte quer durch einen Streifen → Abschnitte
#   Stufe 3  Schnitte quer durch einen Abschnitt → Teile (nur bei 3 Stufen,
#            bei 2 Stufen nur zum Abtrennen des Abfalls, siehe Schnitttyp)
#   Stufe 4  nur Schnitttyp „nicht exakt“ bei 3 Stufen: Abfall neben einem Teil abtrennen
# Erster Schnitt:
#   horizontal  Stufe 1 läuft längs der Platte (Streifen über die ganze Länge)
#   vertikal    Stufe 1 läuft quer (Streifen über die ganze Breite)
#   beliebig    je Platte das bessere von beiden
# Schnitttyp:
#   exakt        so viele Stufen wie eingestellt; jedes Teil füllt seinen Streifen
#                (2 Stufen) bzw. seinen Abschnitt (3 Stufen) quer voll aus
#   nicht exakt  eine Stufe mehr erlaubt, aber nur um Abfall von einem Teil zu trennen
#   homogen      wie exakt, die letzte Ebene enthält nur gleiche Teile
# Abstand = Schnittbreite, Randabfall = Besäumen je Plattenkante. Reste (Abfall), die
# in beiden Richtungen mindestens die Mindestgröße haben, sind als „behalten“ markiert.
# Lager: zuerst die Plattenreste (begrenzte Anzahl), dann die Standardplatte.
# Eigener Code (kein Code aus OpenCutList), Heuristik: je Platte mehrere Varianten
# (Richtung, Sortierung, Streifenwahl) rechnen und die mit der größten belegten
# Fläche nehmen.

module JTools
  module SchrankCnc
    module Guillotine
      module_function

      EPS = 1e-6
      ERSTER = %w[beliebig horizontal vertikal].freeze
      TYPEN = ['exakt', 'nicht exakt', 'homogen'].freeze

      # kerf = Schnittbreite, rand = Besäumen je Kante, erster/typ als Text (s. oben),
      # stufen 2 oder 3, rest_l/rest_b = Mindestgröße für Reste zum Behalten
      Optionen = Struct.new(:kerf, :rand, :erster, :typ, :stufen, :rest_l, :rest_b) do
        def self.standard
          new(3.0, 10.0, 'beliebig', 'nicht exakt', 3, 300.0, 100.0)
        end
      end
      # l längs der Plattenlänge, wenn nicht gedreht; schluessel = gleiche Teile (homogen)
      Stueck = Struct.new(:l, :b, :drehbar, :schluessel, :daten)
      # anzahl nil = unbegrenzt; rest = Plattenrest aus dem Lager
      Lager = Struct.new(:l, :b, :anzahl, :rest)
      Teil = Struct.new(:stueck, :x, :y, :l, :b, :gedreht)
      # stufe 0 = Besäumen; horizontal = Schnittlinie längs der Platte (x-Richtung)
      Schnitt = Struct.new(:nr, :stufe, :horizontal, :x, :y, :laenge)
      Rest = Struct.new(:x, :y, :l, :b, :behalten)
      Platte = Struct.new(:l, :b, :rest, :teile, :schnitte, :reste, :erster) do
        def flaeche
          l * b
        end

        def belegt
          teile.sum { |t| t.l * t.b }
        end

        def ausnutzung
          flaeche > 0 ? belegt * 100.0 / flaeche : 0.0
        end

        # Gleiche Platten erkennen (Maße und Lage der Teile)
        def signatur
          [l, b, teile.map { |t| [t.stueck.schluessel, t.x.round(2), t.y.round(2), t.gedreht] }.sort_by(&:to_s)]
        end
      end

      # Alle Stücke auf Platten verteilen. Gibt [Platten, nicht platzierte Stücke] zurück.
      def packen(stuecke, lager, opt)
        offen = stuecke.dup
        vorrat = lager.map(&:dup)
        platten = []
        until offen.empty?
          beste = nil
          vorrat.each do |lg|
            next if lg.anzahl && lg.anzahl <= 0
            p = platte_packen(offen, lg, opt)
            next if p.nil? || p.teile.empty?
            # Plattenreste zuerst (in Lagerreihenfolge), sonst die besser gefüllte Platte
            beste = p
            break
          end
          break unless beste
          lg = vorrat.find { |v| v.l == beste.l && v.b == beste.b && v.rest == beste.rest && (v.anzahl.nil? || v.anzahl > 0) }
          lg.anzahl -= 1 if lg.anzahl
          platten << beste
          weg = beste.teile.map(&:stueck)
          offen = offen.reject { |s| weg.any? { |w| w.equal?(s) } }
        end
        [platten, offen]
      end

      # Eine Platte füllen: beste Variante (größte belegte Fläche, dann kleinste Ausdehnung)
      def platte_packen(offen, lg, opt)
        richtungen = case opt.erster
                     when 'horizontal' then [:h]
                     when 'vertikal' then [:v]
                     else %i[h v]
                     end
        sortierungen = [
          ->(s) { -(s.l * s.b) },
          ->(s) { -[s.l, s.b].max },
          ->(s) { -[s.l, s.b].min }
        ]
        beste = nil
        bester_wert = nil
        richtungen.each do |r|
          sortierungen.each do |sort|
            liste = offen.sort_by.with_index { |s, i| [sort.(s), i] }
            %i[erstes fuellung].each do |wahl|
              p = variante(liste, lg, opt, r, wahl)
              next unless p
              wert = [-p.belegt.round(1), ausdehnung(p, r).round(1)]
              if bester_wert.nil? || (wert <=> bester_wert) < 0
                beste = p
                bester_wert = wert
              end
            end
          end
        end
        beste
      end

      # Abstand vom Plattenanfang bis zum Ende des letzten Streifens
      def ausdehnung(p, r)
        p.teile.map { |t| r == :h ? t.y + t.b : t.x + t.l }.max || 0.0
      end

      # Maße eines Stücks in Streifenkoordinaten (u längs des Streifens, v quer)
      # für r (:h/:v) und gedreht ja/nein
      def uv(s, r, gedreht)
        l, b = gedreht ? [s.b, s.l] : [s.l, s.b]
        r == :h ? [l, b] : [b, l]
      end

      def lagen(s)
        s.drehbar && (s.l - s.b).abs > EPS ? [false, true] : [false]
      end

      # Eine Variante: Streifen für Streifen füllen
      def variante(liste, lg, opt, r, wahl)
        k = opt.kerf
        lu = r == :h ? lg.l : lg.b # Länge in Streifenrichtung
        lv = r == :h ? lg.b : lg.l
        u_max = lu - 2 * opt.rand
        v_max = lv - 2 * opt.rand
        return nil if u_max <= 0 || v_max <= 0
        offen = liste.dup
        streifen = []
        v = 0.0
        loop do
          rest_v = v_max - v
          break if rest_v <= EPS
          s = streifen_bauen(offen, u_max, rest_v, opt, r, wahl)
          break unless s
          s[:v] = v
          streifen << s
          s[:abschnitte].each { |a| a[:teile].each { |t| offen.delete_if { |o| o.equal?(t[:s]) } } }
          v += s[:h] + k
        end
        return nil if streifen.empty?
        aufbauen(lg, opt, r, streifen, u_max, v_max)
      end

      # Kandidaten für die Streifenhöhe: erste passende Lage des ersten Stücks oder
      # (Füllung) jede vorkommende Höhe; gewählt wird die beste Füllung
      def streifen_bauen(offen, u_max, rest_v, opt, r, wahl)
        hoehen = []
        offen.each do |s|
          lagen(s).each do |g|
            u, v = uv(s, r, g)
            hoehen << [v, s, g] if u <= u_max + EPS && v <= rest_v + EPS
          end
          break if wahl == :erstes && !hoehen.empty?
        end
        return nil if hoehen.empty?
        hoehen = hoehen.uniq { |v, s, _| [v.round(3), s.schluessel] }.first(12) if wahl == :fuellung
        best = nil
        hoehen.each do |h, s, g|
          st = streifen_fuellen(offen, u_max, h, opt, r, s, g)
          next unless st
          wert = st[:flaeche] / (u_max * h)
          wert += st[:flaeche] * 1e-9 # bei gleicher Füllung den größeren Streifen
          best = [wert, st] if best.nil? || wert > best[0] + EPS
        end
        best && best[1]
      end

      def exakt?(opt)
        opt.typ != 'nicht exakt'
      end

      def homogen?(opt)
        opt.typ == 'homogen'
      end

      # Streifen der Höhe h füllen, beginnend mit Stück erstes in Lage g
      def streifen_fuellen(offen, u_max, h, opt, r, erstes, g)
        k = opt.kerf
        frei = offen.dup
        abschnitte = []
        u = 0.0
        flaeche = 0.0
        start = [erstes, g]
        loop do
          rest_u = u_max - u
          break if rest_u <= EPS
          if start
            s, lage = start
            start = nil
          else
            s, lage = abschnitt_start(frei, rest_u, h, opt, r, abschnitte)
            break unless s
          end
          su, sv = uv(s, r, lage)
          a = { u: u, w: su, teile: [{ s: s, g: lage, u: su, v: sv }] }
          frei.delete_if { |o| o.equal?(s) }
          if opt.stufen == 3
            belegt = sv
            loop do
              n = stapel_naechstes(frei, su, h - belegt - k, opt, r, s)
              break unless n
              ns, ng = n
              nu, nv = uv(ns, r, ng)
              a[:teile] << { s: ns, g: ng, u: nu, v: nv }
              frei.delete_if { |o| o.equal?(ns) }
              belegt += k + nv
            end
          end
          a[:teile].each { |t| flaeche += t[:u] * t[:v] }
          abschnitte << a
          u += su + k
        end
        return nil if abschnitte.empty?
        { h: h, abschnitte: abschnitte, flaeche: flaeche }
      end

      # Nächster Abschnitt im Streifen: das größte passende Stück
      def abschnitt_start(frei, rest_u, h, opt, r, abschnitte)
        erstes = abschnitte.first[:teile].first[:s]
        best = nil
        frei.each do |s|
          next if homogen?(opt) && opt.stufen == 2 && s.schluessel != erstes.schluessel
          lagen(s).each do |g|
            u, v = uv(s, r, g)
            next if u > rest_u + EPS || v > h + EPS
            # 2 Stufen exakt/homogen: Teil muss den Streifen quer ganz ausfüllen
            next if opt.stufen == 2 && exakt?(opt) && (v - h).abs > EPS
            wert = [v / h, u * v]
            best = [wert, s, g] if best.nil? || (wert <=> best[0]) > 0
          end
        end
        best && best[1..2]
      end

      # Nächstes Teil im Abschnitt (3 Stufen) über dem vorigen; Platz rest_v
      def stapel_naechstes(frei, w, rest_v, opt, r, erstes)
        return nil if rest_v <= EPS
        best = nil
        frei.each do |s|
          next if homogen?(opt) && s.schluessel != erstes.schluessel
          lagen(s).each do |g|
            u, v = uv(s, r, g)
            next if v > rest_v + EPS || u > w + EPS
            next if exakt?(opt) && (u - w).abs > EPS
            wert = [u / w, v]
            best = [wert, s, g] if best.nil? || (wert <=> best[0]) > 0
          end
        end
        best && best[1..2]
      end

      # Aus den Streifen Teile, Schnitte (in Sägereihenfolge) und Reste der Platte machen
      def aufbauen(lg, opt, r, streifen, u_max, v_max)
        k = opt.kerf
        rd = opt.rand
        # Streifenkoordinaten (u, v, du, dv) → Platte (x, y, l, b)
        xy = lambda do |u, v, du, dv|
          r == :h ? [rd + u, rd + v, du, dv] : [rd + v, rd + u, dv, du]
        end
        teile = []
        schnitte = []
        reste = []
        schnitt = lambda do |stufe, u, v, laenge, laengs_u|
          x, y, = xy.(u, v, 0, 0)
          horizontal = r == :h ? laengs_u : !laengs_u
          schnitte << Schnitt.new(schnitte.size + 1, stufe, horizontal, x, y, laenge)
        end
        rest = lambda do |u, v, du, dv|
          return if du <= EPS || dv <= EPS
          x, y, l, b = xy.(u, v, du, dv)
          gross, klein = [l, b].sort.reverse
          reste << Rest.new(x, y, l, b, gross >= opt.rest_l - EPS && klein >= opt.rest_b - EPS)
        end
        if rd > EPS
          schnitte << Schnitt.new(schnitte.size + 1, 0, true, 0.0, rd, lg.l)
          schnitte << Schnitt.new(schnitte.size + 1, 0, true, 0.0, lg.b - rd, lg.l)
          schnitte << Schnitt.new(schnitte.size + 1, 0, false, rd, rd, lg.b - 2 * rd)
          schnitte << Schnitt.new(schnitte.size + 1, 0, false, lg.l - rd, rd, lg.b - 2 * rd)
        end
        streifen.each do |s|
          v0 = s[:v]
          h = s[:h]
          # Stufe 1: Streifen von der Platte trennen (entfällt am Plattenende)
          schnitt.(1, 0.0, v0 + h, u_max, true) if v0 + h < v_max - EPS
          ende_u = 0.0
          s[:abschnitte].each do |a|
            u0 = a[:u]
            w = a[:w]
            ende_u = u0 + w
            # Stufe 2: Abschnitt vom Streifen trennen
            schnitt.(2, u0 + w, v0, h, false) if u0 + w < u_max - EPS
            v = v0
            a[:teile].each do |t|
              x, y, l, b = xy.(u0, v, t[:u], t[:v])
              teile << Teil.new(t[:s], x, y, l, b, t[:g])
              # Stufe 3: Teil im Abschnitt abtrennen (oben Abfall oder nächstes Teil)
              schnitt.(3, u0, v + t[:v], w, true) if v + t[:v] < v0 + h - EPS
              # Stufe 4: Abfall neben dem Teil (nur nicht exakt)
              if t[:u] < w - EPS
                schnitt.(4, u0 + t[:u], v, t[:v], false)
                rest.(u0 + t[:u] + k, v, w - t[:u] - k, t[:v])
              end
              v += t[:v] + k
            end
            rest.(u0, v, w, v0 + h - v) if v < v0 + h - EPS
          end
          rest.(ende_u + k, v0, u_max - ende_u - k, h) if ende_u + k < u_max - EPS
        end
        letzter = streifen.last
        v_ende = letzter[:v] + letzter[:h] + k
        rest.(0.0, v_ende, u_max, v_max - v_ende) if v_ende < v_max - EPS
        Platte.new(lg.l, lg.b, lg.rest, teile, schnitte, reste, r)
      end
    end
  end
end
