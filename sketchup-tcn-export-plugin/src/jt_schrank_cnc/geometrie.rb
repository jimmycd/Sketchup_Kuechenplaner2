# encoding: UTF-8
# Schrank-CNC – Teile vermessen.
#
# Jedes Teil wird als achsparalleler Quader in Weltkoordinaten (mm) erfasst,
# dazu die Seiten mit Anleimer (Kantenflächen mit einer OCL-Kante, Typ 4).
# Die Lage auf der Maschine (Werkstückkoordinaten der TCN) beschreibt Lage:
# DL entlang der längeren, DH entlang der kürzeren Plattenrichtung, DS = Stärke.
# Alle Werkstückmaße und -lagen sind Fräsmaß: an jeder Seite mit Anleimer
# um dessen Stärke kleiner (wie OpenCutList).

module JTools
  module SchrankCnc
    module Geometrie
      MM = 25.4 # SketchUp rechnet intern in Zoll
      ACHSEN = %w[x y z].freeze
      OCL_DICT = 'ladb_opencutlist'.freeze

      # 4x4-Matrix (Spaltenform wie Geom::Transformation#to_a)
      def self.matrix(tr) = tr.to_a.map(&:to_f)

      def self.mal(a, b)
        (0..3).flat_map do |c|
          (0..3).map { |r| (0..3).sum { |k| a[k * 4 + r] * b[c * 4 + k] } }
        end
      end

      def self.punkt(m, p) = (0..2).map { |r| (0..2).sum { |k| m[k * 4 + r] * p[k] } + m[12 + r] }

      def self.richtung(m, v) = (0..2).map { |r| (0..2).sum { |k| m[k * 4 + r] * v[k] } }

      # Welt-Matrix eines Teils aus seinem Pfad (äußerste Instanz zuerst)
      def self.welt(pfad)
        pfad.reduce([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1].map(&:to_f)) { |m, i| mal(m, matrix(i.transformation)) }
      end

      # Seite (:xmin … :zmax) zu einer Richtung, nach der größten Komponente
      def self.seite(v)
        a = (0..2).max_by { |k| v[k].abs }
        :"#{ACHSEN[a]}#{v[a] > 0 ? 'max' : 'min'}"
      end

      def self.achse(seite) = ACHSEN.index(seite.to_s[0])
      def self.max?(seite) = seite.to_s.end_with?('max')

      # Anleimerstärke einer OCL-Kante in mm ("2mm", "2 mm", "0.08in" wird nicht gelesen -> 2)
      def self.kantenstaerke(mat)
        t = mat.get_attribute(OCL_DICT, 'thickness').to_s
        t =~ /\A\s*([\d.,]+)\s*mm\s*\z/ ? $1.tr(',', '.').to_f : 2.0
      end

      # Werkstück: Teil, Quader lo/hi (mm, Welt), Anleimer je Weltseite (mm)
      Werkstueck = Struct.new(:teil, :lo, :hi, :kanten, :ops) do
        def name = teil.name
        def rolle = teil.rolle
        def mass(a) = hi[a] - lo[a]
        def dicke_achse = (0..2).min_by { |a| mass(a) }
        def flaechen_achsen = (0..2).reject { |a| a == dicke_achse }
        def kante(seite) = kanten[seite] || 0.0
        # Fräsmaß-Grenzen je Achse (ohne Anleimer)
        def lo_f(a) = lo[a] + kante(:"#{ACHSEN[a]}min")
        def hi_f(a) = hi[a] - kante(:"#{ACHSEN[a]}max")
      end

      def self.werkstueck(teil)
        m = welt(teil.pfad)
        d = teil.inst.definition
        bb = d.bounds
        ecken = [bb.min.to_a, bb.max.to_a].map { |p| p.map(&:to_f) }
        pts = [0, 1].product([0, 1], [0, 1]).map { |i, j, k| punkt(m, [ecken[i][0], ecken[j][1], ecken[k][2]]) }
        lo = (0..2).map { |a| pts.map { |p| p[a] }.min * MM }
        hi = (0..2).map { |a| pts.map { |p| p[a] }.max * MM }
        kanten = {}
        d.entities.grep(Sketchup::Face).each do |f|
          mat = f.material
          next unless mat && mat.get_attribute(OCL_DICT, 'type').to_i == 4
          kanten[seite(richtung(m, f.normal.to_a))] = kantenstaerke(mat)
        end
        Werkstueck.new(teil, lo, hi, kanten, [])
      end

      # Lage auf der Maschine: Achse und Richtung (+1/-1) je Werkstückachse x, y, z.
      # z zeigt aus Fläche 1 heraus (oben auf der Maschine), x entlang DL, y = z × x.
      Lage = Struct.new(:ws, :ax, :sx, :ay, :sy, :az, :sz) do
        def dl = ws.hi_f(ax) - ws.lo_f(ax)
        def dh = ws.hi_f(ay) - ws.lo_f(ay)
        def ds = ws.mass(az)
        def u(p, a, s) = s > 0 ? p[a] - ws.lo_f(a) : ws.hi_f(a) - p[a]
        def x(p) = u(p, ax, sx)
        def y(p) = u(p, ay, sy)
        # Tiefe unter Fläche 1
        def tiefe(p) = sz > 0 ? ws.hi[az] - p[az] : p[az] - ws.lo[az]
        def flaeche1 = :"#{ACHSEN[az]}#{sz > 0 ? 'max' : 'min'}"

        # TCN-Seite einer Weltseite: 1 oben, 3 vorne (y = 0), 4 rechts (x = DL), 5 hinten, 6 links (x = 0)
        def side(seite)
          a = Geometrie.achse(seite)
          mx = Geometrie.max?(seite)
          return (mx == (sz > 0) ? 1 : 2) if a == az
          if a == ax then (mx == (sx > 0) ? 4 : 6)
          else (mx == (sy > 0) ? 5 : 3)
          end
        end
      end

      # z = Weltseite von Fläche 1; x entlang der längeren Plattenrichtung
      def self.lage(ws, flaeche1)
        az = achse(flaeche1)
        sz = max?(flaeche1) ? 1 : -1
        ax = ws.flaechen_achsen.max_by { |a| [ws.hi_f(a) - ws.lo_f(a), -a] }
        ay = ws.flaechen_achsen.find { |a| a != ax }
        # y = z × x: Vorzeichen aus dem Kreuzprodukt der Einheitsvektoren
        ez = [0, 0, 0]; ez[az] = sz
        ex = [0, 0, 0]; ex[ax] = 1
        ey = [ez[1] * ex[2] - ez[2] * ex[1], ez[2] * ex[0] - ez[0] * ex[2], ez[0] * ex[1] - ez[1] * ex[0]]
        # stehende Teile (Fronten, Rückwand): y = 0 an der Unterkante wie in SK_Vorderstueck_Frontbef.tcn,
        # dafür x von der anderen Seite her (bleibt ein Rechtssystem)
        sx = ay == 2 && ey[ay] < 0 ? -1 : 1
        Lage.new(ws, ax, sx, ay, ey[ay] * sx, az, sz)
      end
    end
  end
end
