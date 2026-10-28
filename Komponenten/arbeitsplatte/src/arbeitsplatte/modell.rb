# encoding: UTF-8
#
# Arbeitsplatte – Schränke aus dem SketchUp-Modell lesen
#
# Liest die Instanzen mit dem Wörterbuch JT_Schrank (an der Definition) in der
# Auswahl, sonst im ganzen Modell (oberste Ebene), und macht daraus die Elemente
# für Erkennung.erkenne: Grundriss-Rechteck in Weltkoordinaten (mm), Blickrichtung
# der Front, Unter- und Oberkante. Die Front liegt bei allen Schränken lokal auf
# ymin (die Fronten stehen vor dem Korpus), die Rückseite auf ymax.
#
# Der L-Eckschrank (Wörterbuch JT_Eckschrank/l_gebaut) wird zu zwei Elementen:
# Schenkel A an der hinteren Wand (Front -y) über die ganze Breite, Schenkel B an
# der linken Wand (Front +x) bis vor die Front von A. Beide sind gleich tief: von
# der Wand bis vor die Türen, die lokal bei y = -Spaltbreite liegen.

module Arbeitsplatte
  module Modell
    MM       = 25.4 # SketchUp rechnet intern in Zoll
    JT_DICT  = 'JT_Schrank'.freeze
    DC_DICT  = 'dynamic_attributes'.freeze
    L_DICT   = 'JT_Eckschrank'.freeze
    L_GEBAUT = 'l_gebaut'.freeze
    SPALT_L  = 2.0 # mm, Fuge vor dem L-Eckschrank (Spaltbreite), falls nicht am Schrank

    # Spaltenform wie Geom::Transformation#to_a
    def self.punkt(m, p)
      (0..2).map { |r| (0..2).sum { |k| m[k * 4 + r] * p[k] } + m[12 + r] }
    end

    def self.richtung(m, v)
      (0..2).map { |r| (0..2).sum { |k| m[k * 4 + r] * v[k] } }
    end

    # Blickrichtung als :nx/:px/:ny/:py, nil wenn der Schrank schräg steht
    def self.front(m, lokal)
      v = richtung(m, lokal)
      l = Math.sqrt(v[0]**2 + v[1]**2)
      return nil if l < 1e-9
      x, y = v[0] / l, v[1] / l
      return (x < 0 ? :nx : :px) if x.abs > 0.999
      return (y < 0 ? :ny : :py) if y.abs > 0.999
      nil
    end

    # Lokales Rechteck (Zoll) -> Weltrechteck (mm), z aus den Bounds
    def self.welt_rechteck(m, x0, y0, x1, y1, z0, z1)
      pts = [x0, x1].product([y0, y1], [z0, z1]).map { |p| punkt(m, p).map { |v| v * MM } }
      xs, ys, zs = pts.transpose
      [[xs.min, ys.min, xs.max, ys.max].map { |v| v.round(1) }, zs.min.round(1), zs.max.round(1)]
    end

    def self.schrank?(inst)
      d = inst.definition
      %w[Unterschrank Hochschrank].include?(d.get_attribute(JT_DICT, 'kategorie'))
    end

    # alle: true übergeht die Auswahl (Neuberechnen einer markierten Arbeitsplatte)
    def self.instanzen(model, alle: false)
      quelle = alle || model.selection.to_a.empty? ? model.entities.to_a : model.selection.to_a
      quelle.grep(Sketchup::ComponentInstance).select { |i| schrank?(i) }
    end

    # Elemente eines Schranks (meist eins, beim L-Eckschrank zwei)
    def self.elemente(inst, warnungen = [])
      d = inst.definition
      m = inst.transformation.to_a.map(&:to_f)
      bb = d.bounds
      (x0, y0, z0), (x1, y1, z1) = bb.min.to_a.map(&:to_f), bb.max.to_a.map(&:to_f)
      basis = { kz: d.get_attribute(JT_DICT, 'schrank').to_s, typ: d.get_attribute(JT_DICT, 'typ').to_s,
                kategorie: d.get_attribute(JT_DICT, 'kategorie').to_s }
      teile = if d.get_attribute(L_DICT, L_GEBAUT)
                sp = (v = d.get_attribute(DC_DICT, 'spaltbreite')) ? v.to_f : SPALT_L / MM
                t = y1 + sp # Wand bis vor die Türen
                [[[x0, y1 - t, x1, y1], [0, -1, 0], 'A'], [[x0, y0, x0 + t, y1 - t], [1, 0, 0], 'B']]
              else
                [[[x0, y0, x1, y1], [0, -1, 0], nil]]
              end
      teile.map do |(rx0, ry0, rx1, ry1), lokal, schenkel|
        f = front(m, lokal)
        unless f
          warnungen << "#{basis[:kz]} steht schräg, wird übergangen"
          next
        end
        rechteck, zu, zo = welt_rechteck(m, rx0, ry0, rx1, ry1, z0, z1)
        basis.merge(rechteck: rechteck, front: f, z0: zu, z1: zo, schenkel: schenkel)
      end.compact
    end

    def self.erkenne(model, optionen = {})
      warnungen = []
      els = instanzen(model).flat_map { |i| elemente(i, warnungen) }
      erg = Erkennung.erkenne(els, optionen)
      erg[:warnungen] = warnungen + erg[:warnungen]
      erg
    end
  end
end
