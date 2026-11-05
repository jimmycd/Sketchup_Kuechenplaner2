# Gemeinsamer Test-Baustein: Nachbildung der Dynamic Components beim Neuzeichnen.
#
# Die echte DC merkt sich die Größe eines Schranks an der Instanz (lenx/leny/lenz, Zoll)
# und skaliert die Instanz beim Neuzeichnen (redraw_with_undo) auf diese Größe. Schränke,
# die nach einer Änderung neu aufgebaut werden (neue Definition), müssen deshalb die neue
# Größe eintragen, sonst bleibt der Schrank so groß wie vorher und wird nur gestaucht
# (Fehler 2026-11-02: Abschlussregal Tiefe 400 mm, gezeichnet 238 mm).
module DcGroesseHelfer
  ACHSEN = { 'lenx' => :width, 'leny' => :height, 'lenz' => :depth }.freeze

  # Ersatz für $dc_observers.get_latest_class. Ohne Formula für lenx/leny/lenz bleibt die
  # Zielgröße die beim ersten Neuzeichnen gemerkte (so verhielt sich die echte DC 2026-11-05:
  # Tiefe 350 gebaut, lenx/leny/lenz neu eingetragen, trotzdem auf 314 mm gestaucht).
  class Dc
    def initialize(dict) = (@dict, @gemerkt = dict, {})
    def get_latest_class = self

    def redraw_with_undo(inst)
      bb = inst.definition.bounds
      ist = ACHSEN.values.map { |m| bb.send(m) }
      alt = (@gemerkt[inst] ||= ist)
      s = ACHSEN.keys.each_with_index.map do |k, i|
        f = inst.get_attribute(@dict, "_#{k}_formula") || inst.definition.get_attribute(@dict, "_#{k}_formula")
        ziel = f ? Float(f) / 2.54 : alt[i]
        ist[i] > 1e-9 ? ziel / ist[i] : 1.0
      end
      o = inst.transformation.to_a[12, 3]
      inst.transformation = Geom::Transformation.new([s[0], 0, 0, 0, 0, s[1], 0, 0, 0, 0, s[2], 0, *o, 1])
    end
  end

  # Mit nachgebildeter DC ausführen
  def self.mit_dc(dict)
    alt = $dc_observers
    $dc_observers = Dc.new(dict)
    yield
  ensure
    $dc_observers = alt
  end

  # Größe der Instanz im Modell (cm) = Hülle der Definition × Skalierung
  def self.groesse(inst)
    t = inst.transformation.to_a
    bb = inst.definition.bounds
    [[t[0, 3], bb.width], [t[4, 3], bb.height], [t[8, 3], bb.depth]].map do |a, l|
      Math.sqrt(a.sum { |v| v * v }) * l * 2.54
    end
  end
end
