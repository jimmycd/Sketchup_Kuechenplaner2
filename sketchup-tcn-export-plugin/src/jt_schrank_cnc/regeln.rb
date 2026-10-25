# encoding: UTF-8
# Schrank-CNC – Bearbeitungsregeln aus Jürgens Beispiel-TCN (beispiele/).
#
# Stöße werden geometrisch gefunden: liegt die Stirnseite eines Bodens, Deckels,
# Zwischenbodens oder einer Strebe (Teil A) an der Fläche einer Seite (Teil B),
# bekommt A eine Dübelreihe in die Stirnseite und B die passende Reihe in die
# Fläche. Dazu (Schritt 6): Nut für eine Rückwand, die in Seiten und Boden
# steckt (Oberschrank), Schrauben Deckel–Rückwand, Lochreihen für Einlegeböden
# und Bohrungen für Sockelfüße. Die Bearbeitungen entstehen zuerst in
# Weltkoordinaten (mm) und werden erst beim Schreiben in die
# Werkstückkoordinaten (Fräsmaß) umgerechnet.

module JTools
  module SchrankCnc
    module Regeln
      TOL = 0.1 # mm

      # Bearbeitung auf einer Weltseite: :reihe (p0 -> p1, Raster, verteilt), :bohrung (p0)
      # oder :nut (Mittellinie p0 -> p1 auf der Oberfläche, d = Nutbreite)
      Op = Struct.new(:art, :seite, :p0, :p1, :d, :tiefe, :raster, :verteilt, :titel)

      # Dübelreihen je Rolle von A (Abstand vom Rand, Raster; verteilt = #8508/#8509 1/1)
      VERBINDUNGEN = {
        'Boden'         => { rand: 30, raster: 150, verteilt: true },  # Boden.tcn, Seite.tcn
        'Deckel'        => { rand: 30, raster: 150, verteilt: true },  # Deckel.tcn
        'Zwischenboden' => { rand: 30, raster: 150, verteilt: true },
        # Strebe.tcn: 20 … x-20, Raster 60; verteilt, damit es auch bei 98 mm (Anleimer) zwei Dübel bleiben
        'Strebe'        => { rand: 20, raster: 60, verteilt: true, schraube: true }
      }.freeze
      DUEBEL = { d: 8, tiefe_kante: 22, tiefe_flaeche: 14 }.freeze # Seite 14 tief (Seiten_SK, Jürgen: das tiefere)
      SCHRAUBE = { d: 3, tiefe: 21 }.freeze # Seite.tcn: Ø3, 21 tief in der Mitte der Strebe
      # Deckel–Rückwand (Oberschrank): 3 Schrauben, 50 mm von den Seiten und in der Mitte;
      # Ø4 durch die Rückwand (1 mm tiefer als ihre Stärke), Ø3 × 15 in die Deckelkante (Annahme)
      RUECKWAND_SCHRAUBE = { rand: 50, d_rueckwand: 4, d_deckel: 3, tiefe_deckel: 15, durch: 1 }.freeze
      # Seite.tcn: Lochreihe Ø5, 12 tief, Raster 32, 35 mm von vorn und hinten,
      # 55 … x-50 im Fräsmaß der Seite = 38 über dem Boden und 33 unter dem Deckel.
      # Jede Seite bekommt sie in jedem Fach (Seiten sind immer gleich).
      LOCHREIHE = { d: 5, tiefe: 12, raster: 32, rand: 35, ueber: 38, unter: 33 }.freeze
      # Seiten_SK_L/R: Schiene (Blum LEGRABOX) Ø5, 14 tief, 37/69/261/293 mm ab Vorderkante Seite
      # (roh, im Fräsmaß 35/67/259/291), Höhe = Kastenunterkante + Höhenoffset Schiene
      SCHIENE = { d: 5, tiefe: 14, tiefen: [37, 69, 261, 293] }.freeze
      KASTEN = %w[KastenBoden KastenSeite KastenVorne KastenHinten].freeze
      # Boden.tcn: je Sockelfuß 2 × 2 Bohrungen Ø3, 3 tief, Raster 64; 20 mm vom Rand in x, 60 mm in y
      SOCKELFUSS = { d: 3, tiefe: 3, raster: 64, rand_x: 20, rand_y: 60 }.freeze
      SOCKEL_KATEGORIEN = %w[Unterschrank Hochschrank].freeze
      FESTE_BOEDEN = %w[Boden Deckel Zwischenboden Strebe].freeze

      def self.anwenden(werkstuecke)
        werkstuecke.each { |w| w.ops.clear }
        meldungen = []
        werkstuecke.group_by { |w| w.teil.pfad.first }.each_value do |teile|
          teile.each do |a|
            regel = VERBINDUNGEN[a.rolle] or next
            teile.each do |b|
              next unless b.rolle == 'Seite'
              stoss(a, b, regel, meldungen)
            end
          end
          teile.select { |w| w.rolle == 'Rueckwand' }.each do |rw|
            teile.each { |b| nut(rw, b) if %w[Seite Boden Deckel].include?(b.rolle) }
            teile.each { |b| rueckwand_schrauben(rw, b) if b.rolle == 'Deckel' && Schraenke.kategorie(b.teil) == 'Oberschrank' }
          end
          lochreihen(teile)
          schienen(teile, meldungen)
          teile.each { |w| sockelfuesse(w) if w.rolle == 'Boden' && SOCKEL_KATEGORIEN.include?(Schraenke.kategorie(w.teil)) }
        end
        meldungen
      end

      def self.ueberlapp(a, b, i) = [a.hi[i], b.hi[i]].min - [a.lo[i], b.lo[i]].max

      def self.punkt(werte)
        p = [0.0, 0.0, 0.0]
        werte.each { |i, v| p[i] = v }
        p
      end

      # Rückwand A steckt in B: Nut in die Fläche von B, auf der A herausragt
      def self.nut(a, b)
        k = b.dicke_achse
        ca = a.dicke_achse
        return if k == ca || (0..2).any? { |i| ueberlapp(a, b, i) < TOL }
        ax = Geometrie::ACHSEN[k]
        if a.lo[k] < b.lo[k] - TOL then seite, flaeche = :"#{ax}min", b.lo[k]
        elsif a.hi[k] > b.hi[k] + TOL then seite, flaeche = :"#{ax}max", b.hi[k]
        else return
        end
        la = ([0, 1, 2] - [k, ca]).first
        mitte = ([a.lo[ca], b.lo[ca]].max + [a.hi[ca], b.hi[ca]].min) / 2.0
        lo = [a.lo[la], b.lo[la]].max
        hi = [a.hi[la], b.hi[la]].min
        # bis zum Rand der Platte: ein Fräserradius darüber hinaus, damit die Nut offen ist
        lo -= NUT[:ueberlauf] if lo <= b.lo_f(la) + TOL
        hi += NUT[:ueberlauf] if hi >= b.hi_f(la) - TOL
        p0 = punkt(k => flaeche, ca => mitte, la => lo)
        p1 = punkt(k => flaeche, ca => mitte, la => hi)
        b.ops << Op.new(:nut, seite, p0, p1, ueberlapp(a, b, ca), ueberlapp(a, b, k), nil, nil, "Nut #{a.teil.jt('teil')}")
      end
      NUT = { werkzeug: 2200, d_werkzeug: 8.03, ueberlauf: 5 }.freeze # Treppenbau: 2200 = Ø 8,03 mm

      # Oberschrank: Deckel B endet vor der Rückwand A und wird durch sie verschraubt
      def self.rueckwand_schrauben(a, b)
        ca = a.dicke_achse
        kb = b.dicke_achse
        return if kb == ca
        if (b.hi[ca] - a.lo[ca]).abs < TOL then sa, sb, kp = :"#{Geometrie::ACHSEN[ca]}min", :"#{Geometrie::ACHSEN[ca]}max", a.lo[ca]
        elsif (b.lo[ca] - a.hi[ca]).abs < TOL then sa, sb, kp = :"#{Geometrie::ACHSEN[ca]}max", :"#{Geometrie::ACHSEN[ca]}min", a.hi[ca]
        else return
        end
        la = ([0, 1, 2] - [ca, kb]).first
        return unless ueberlapp(a, b, la) > 1.0 && ueberlapp(a, b, kb) > 1.0
        r = RUECKWAND_SCHRAUBE
        lo = b.lo[la] + r[:rand]
        hi = b.hi[la] - r[:rand]
        return if hi - lo < 1.0
        m = (b.lo[kb] + b.hi[kb]) / 2.0
        p0 = punkt(ca => kp, kb => m, la => lo)
        p1 = punkt(ca => kp, kb => m, la => hi)
        raster = (hi - lo) / 2.0
        a.ops << Op.new(:reihe, sa, p0, p1, r[:d_rueckwand], a.mass(ca) + r[:durch], raster, false, "Schraube #{b.teil.jt('teil')}")
        b.ops << Op.new(:reihe, sb, p0, p1, r[:d_deckel], r[:tiefe_deckel], raster, false, "Schraube #{a.teil.jt('teil')}")
      end

      def self.flaeche_innen(s, k, nach_max) = nach_max ? [:"#{Geometrie::ACHSEN[k]}max", s.hi[k]] : [:"#{Geometrie::ACHSEN[k]}min", s.lo[k]]

      # feste Böden (und Streben), die an der Seite stoßen, nach Höhe; Seite der Seite, an der sie liegen
      def self.boeden_an(s, teile)
        k = s.dicke_achse
        teile.select do |f|
          FESTE_BOEDEN.include?(f.rolle) && f.dicke_achse != k &&
            [(f.lo[k] - s.hi[k]).abs, (s.lo[k] - f.hi[k]).abs].min < TOL
        end
      end

      # Lochreihen in jeder Seite je Fach zwischen zwei festen Böden: vorn 35 mm,
      # hinten 35 mm vor Hinterkante bzw. Rückwandnut
      def self.lochreihen(teile)
        teile.select { |w| w.rolle == 'Seite' }.each do |s|
          k = s.dicke_achse
          boeden = boeden_an(s, teile)
          next if boeden.empty?
          v = boeden.first.dicke_achse
          t = ([0, 1, 2] - [k, v]).first
          nach_max = (boeden.first.lo[k] - s.hi[k]).abs < TOL
          seite, flaeche = flaeche_innen(s, k, nach_max)
          l = LOCHREIHE
          nuten = s.ops.select { |o| o.art == :nut && o.seite == seite && o.p0[t] > s.lo_f(t) + l[:rand] }
          hinten = ([s.hi_f(t)] + nuten.map { |o| o.p0[t] - o.d / 2.0 }).min
          lagen = boeden.map { |f| [f.lo[v], f.hi[v]] }.uniq.sort
          raster = lochraster(s)
          lagen.each_cons(2) do |(_, unten), (oben, _)|
            lo = unten + l[:ueber]
            # mit Schubladen-Lochraster (Lochraster_Start + n · Lochraster ab Unterkante Seite):
            # auf das Raster, damit die Schienen in die Lochreihe geschraubt werden können
            lo = s.lo[v] + raster[0] + raster[1] * ((lo - s.lo[v] - raster[0]) / raster[1] - 1e-6).ceil if raster
            hi = oben - l[:unter]
            next if hi - lo < l[:raster]
            [s.lo_f(t) + l[:rand], hinten - l[:rand]].each do |y|
              s.ops << Op.new(:reihe, seite, punkt(k => flaeche, t => y, v => lo), punkt(k => flaeche, t => y, v => hi),
                              l[:d], l[:tiefe], l[:raster], false, 'Lochreihe')
            end
          end
        end
      end

      # Lochraster des Schranks [Start, Raster] in mm, wenn er Schubladen im Raster hat
      def self.lochraster(w)
        d = Schraenke.definition(w.teil.schrank)
        st, ra = %w[lochraster_start lochraster].map { |k| d.get_attribute(DC_DICT, k) }
        st && ra.to_f > 0 ? [st.to_f * Geometrie::MM, ra.to_f * Geometrie::MM] : nil
      end

      # liegt eine Bohrung schon in einer Lochreihe der Seite?
      def self.in_lochreihe?(s, seite, p)
        s.ops.any? do |o|
          next false unless o.art == :reihe && o.titel == 'Lochreihe' && o.seite == seite
          a = (0..2).find { |i| (o.p1[i] - o.p0[i]).abs > 0.001 }
          (0..2).all? { |i| i == a || (o.p0[i] - p[i]).abs < 0.1 } &&
            p[a].between?(o.p0[a] - 0.1, o.p1[a] + 0.1) && (((p[a] - o.p0[a]) / o.raster) % 1 - 0.5).abs > 0.5 - 0.1 / o.raster
        end
      end

      # Schienenbohrungen je sichtbarer Schublade in beiden Seiten
      def self.schienen(teile, meldungen)
        kaesten = teile.select { |w| KASTEN.include?(w.rolle) }.group_by { |w| w.teil.jt('bereich') }
        kaesten.each_value do |kasten|
          unten = kasten.map { |w| w.lo[2] }.min
          schrank = Schraenke.definition(kasten.first.teil.schrank)
          z = unten + schrank.get_attribute(DC_DICT, 'hoehenoffset_schiene').to_f * Geometrie::MM
          lo = (0..1).map { |i| kasten.map { |w| w.lo[i] }.min }
          hi = (0..1).map { |i| kasten.map { |w| w.hi[i] }.max }
          teile.select { |w| w.rolle == 'Seite' && w.dicke_achse != 2 }.each do |s|
            k = s.dicke_achse
            t = 1 - k
            next unless z.between?(s.lo[2], s.hi[2]) && [s.hi[t], hi[t]].min - [s.lo[t], lo[t]].max > 1.0
            nach_max = if (lo[k] - s.hi[k]).between?(-TOL, 60) then true
                       elsif (s.lo[k] - hi[k]).between?(-TOL, 60) then false
                       end
            next if nach_max.nil?
            seite, flaeche = flaeche_innen(s, k, nach_max)
            SCHIENE[:tiefen].each do |d|
              y = s.lo[t] + d
              if y > s.hi_f(t) - 10
                meldungen << "#{s.name}: Schienenbohrung #{d} mm liegt hinter der Seite"
                next
              end
              p = punkt(k => flaeche, t => y, 2 => z)
              next if in_lochreihe?(s, seite, p)
              s.ops << Op.new(:bohrung, seite, p, nil, SCHIENE[:d], SCHIENE[:tiefe], nil, nil, "Schiene #{kasten.first.teil.jt('bereich')}")
            end
          end
        end
      end

      # Sockelfüße: Bohrbild aus Boden.tcn in der Unterseite des Bodens,
      # x entlang der längeren Plattenrichtung (wie DL)
      def self.sockelfuesse(w)
        k = w.dicke_achse
        ax = w.flaechen_achsen.max_by { |a| [w.hi_f(a) - w.lo_f(a), -a] }
        ay = (w.flaechen_achsen - [ax]).first
        f = SOCKELFUSS
        xs = [[w.lo_f(ax) + f[:rand_x], w.lo_f(ax) + f[:rand_x] + f[:raster]],
              [w.hi_f(ax) - f[:rand_x] - f[:raster], w.hi_f(ax) - f[:rand_x]]]
        ys = [w.lo_f(ay) + f[:rand_y], w.lo_f(ay) + f[:rand_y] + f[:raster],
              w.hi_f(ay) - f[:rand_y], w.hi_f(ay) - f[:rand_y] - f[:raster]]
        xs.each do |x0, x1|
          ys.each do |y|
            w.ops << Op.new(:reihe, :"#{Geometrie::ACHSEN[k]}min", punkt(k => w.lo[k], ax => x0, ay => y),
                            punkt(k => w.lo[k], ax => x1, ay => y), f[:d], f[:tiefe], f[:raster], false, 'Sockelfuss')
          end
        end
      end

      def self.stoss(a, b, regel, meldungen)
        k = b.dicke_achse
        return if k == a.dicke_achse
        if (a.lo[k] - b.hi[k]).abs < TOL
          sa, sb, kp = :"#{Geometrie::ACHSEN[k]}min", :"#{Geometrie::ACHSEN[k]}max", b.hi[k]
        elsif (a.hi[k] - b.lo[k]).abs < TOL
          sa, sb, kp = :"#{Geometrie::ACHSEN[k]}max", :"#{Geometrie::ACHSEN[k]}min", b.lo[k]
        else
          return
        end
        andere = (0..2).reject { |i| i == k }
        return unless andere.all? { |i| [a.hi[i], b.hi[i]].min - [a.lo[i], b.lo[i]].max > 1.0 }

        ca = a.dicke_achse
        la = (andere - [ca]).first
        lo = [a.lo_f(la), b.lo_f(la)].max
        hi = [a.hi_f(la), b.hi_f(la)].min
        if hi - lo < 2 * regel[:rand]
          meldungen << "#{a.name} an #{b.name}: Stoß nur #{(hi - lo).round(1)} mm lang, keine Dübel"
          return
        end
        pt = lambda do |l|
          p = [0.0, 0.0, 0.0]
          p[k] = kp
          p[ca] = (a.lo[ca] + a.hi[ca]) / 2.0
          p[la] = l
          p
        end
        p0 = pt.(lo + regel[:rand])
        p1 = pt.(hi - regel[:rand])
        titel = "Duebel #{b.teil.jt('teil')}"
        a.ops << Op.new(:reihe, sa, p0, p1, DUEBEL[:d], DUEBEL[:tiefe_kante], regel[:raster], regel[:verteilt], titel)
        b.ops << Op.new(:reihe, sb, p0, p1, DUEBEL[:d], DUEBEL[:tiefe_flaeche], regel[:raster], regel[:verteilt],
                        "Duebel #{a.teil.jt('teil')}")
        return unless regel[:schraube]
        b.ops << Op.new(:bohrung, sb, pt.((lo + hi) / 2.0), nil, SCHRAUBE[:d], SCHRAUBE[:tiefe], nil, nil,
                        "Schraube #{a.teil.jt('teil')}")
      end

      # Fläche 1 (oben auf der Maschine): die große Fläche mit den meisten Bohrungen,
      # bei Gleichstand die obere bzw. die Seite zur größeren Koordinate
      def self.flaeche1(w)
        a = w.dicke_achse
        mn, mx = :"#{Geometrie::ACHSEN[a]}min", :"#{Geometrie::ACHSEN[a]}max"
        w.ops.count { |o| o.seite == mn } > w.ops.count { |o| o.seite == mx } ? mn : mx
      end
    end
  end
end
