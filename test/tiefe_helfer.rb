# Gemeinsamer Test-Baustein (von den Komponenten-Tests geladen): Tiefe nachträglich ändern.
#
# Ein Schrank, der mit Tiefe A erzeugt und dann im Fenster "Komponentenoptionen" auf
# Tiefe B gestellt wird (die DC schreibt an die Instanz und rechnet neu), muss genau so
# aussehen wie ein Schrank, der gleich mit Tiefe B erzeugt wurde: alle Teile an derselben
# Stelle, gleich groß, gleich sichtbar, und alle berechneten Werte am Schrank (z. B. NL der
# LEGRABOX-Schiene) gleich. Damit fällt jedes Maß auf, das nur beim Erzeugen fest
# eingetragen wurde und keiner Formel folgt.
#
# Die Knoten-Klasse (DC-Auswerter) kommt aus dem jeweiligen Test; gebraucht werden
# kinder, name, formel(k), wert(k), inst und defn.
module TiefeHelfer
  EPS = 1e-6
  ACHSEN = %w[x y z].freeze
  LAENGEN = %w[lenx leny lenz].freeze

  # Pfad => [Ursprung, Größe, versteckt] aller Blatt-Teile (absolut, cm)
  def self.blaetter(k, off = [0.0, 0.0, 0.0], versteckt = false, pfad = '', out = {})
    k.kinder.each do |c|
      o = ACHSEN.each_with_index.map do |ax, i|
        off[i] + (c.formel(ax) ? c.wert(ax) : c.inst.transformation.origin[i] * 2.54)
      end
      vs = versteckt || (c.formel('hidden') ? c.wert('hidden') > 0.5 : false)
      p = "#{pfad}/#{c.name}"
      p += "##{out.keys.count { |q| q.start_with?(p) }}" if out.key?(p)
      if c.kinder.empty?
        box = c.defn.respond_to?(:box) ? c.defn.box : nil
        l = LAENGEN.each_with_index.map { |a, i| c.formel(a) ? c.wert(a) : (box ? box[i] * 2.54 : nil) }
        out[p] = [o, l, vs]
      else
        blaetter(c, o, vs, p, out)
      end
    end
    out
  end

  # Werte aller Formeln am Schrank selbst (NL, Fronthöhen, …)
  def self.werte(k, schluessel)
    schluessel.to_h { |s| [s, k.wert(s)] }
  end

  def self.gleich?(a, b)
    return a == b unless a.is_a?(Numeric) && b.is_a?(Numeric)
    (a - b).abs < EPS
  end

  # geaendert: Knoten nach "Tiefe ändern + neu berechnen", neu: Knoten frisch mit der neuen Tiefe.
  # Gibt die Liste der Abweichungen zurück (leer = gleich).
  def self.abweichungen(geaendert, neu, schluessel = [])
    fehler = []
    a = blaetter(geaendert)
    b = blaetter(neu)
    (a.keys | b.keys).each do |p|
      x, y = a[p], b[p]
      next fehler << "#{p} fehlt (#{x ? 'neu' : 'geändert'})" unless x && y
      next if x[2] && y[2] # ausgeblendet: Lage egal
      fehler << "#{p} sichtbar #{!x[2]} statt #{!y[2]}" if x[2] != y[2]
      3.times do |i|
        fehler << "#{p} #{ACHSEN[i]} #{x[0][i].round(3)} statt #{y[0][i].round(3)}" unless gleich?(x[0][i], y[0][i])
        next if x[1][i].nil? || y[1][i].nil?
        fehler << "#{p} #{LAENGEN[i]} #{x[1][i].round(3)} statt #{y[1][i].round(3)}" unless gleich?(x[1][i], y[1][i])
      end
    end
    schluessel.each do |s|
      v1, v2 = geaendert.wert(s), neu.wert(s)
      fehler << "#{s} #{v1.inspect} statt #{v2.inspect}" unless gleich?(v1, v2)
    end
    fehler
  end

  # Für jedes Paar [Tiefe vorher, Tiefe nachher] (cm): erzeugen, Tiefe an der Instanz ändern
  # (so macht es das Fenster Komponentenoptionen), neu berechnen und mit einem frisch mit der
  # neuen Tiefe erzeugten Schrank vergleichen. erzeugen: ->(eingabe) { Instanz }.
  # Liefert { "a -> b" => [Abweichungen] }.
  def self.pruefen(knoten, dict, erzeugen, paare, eingabe = {})
    Sketchup.active_model = Sketchup::Model.new
    i0 = erzeugen.call(eingabe)
    bezuege = bezuege_auf_eigene_formeln(knoten.new(i0, i0.definition, nil)).uniq
    paare.to_h do |t0, t1|
      Sketchup.active_model = Sketchup::Model.new
      inst = erzeugen.call(eingabe.merge('Tiefe' => t0))
      inst.set_attribute(dict, 'tiefe', t1 / 2.54)
      g = knoten.new(inst, inst.definition, nil)
      g.redraw
      Sketchup.active_model = Sketchup::Model.new
      inst2 = erzeugen.call(eingabe.merge('Tiefe' => t1))
      n = knoten.new(inst2, inst2.definition, nil)
      n.redraw
      schluessel = (inst2.definition.attribute_dictionary(dict) || {}).keys.grep(/\A_(.+)_formula\z/) { $1 }
      ["#{(t0 * 10).round} -> #{(t1 * 10).round} mm",
       abweichungen(g, n, schluessel.uniq.sort) + ausserhalb(g).map { |f| "Komponentengrenze: #{f}" }]
    end.merge('(Formeln, die auf Formeln desselben Bauteils verweisen)' => bezuege)
  end
end

module TiefeHelfer
  # SketchUp wertet die Formeln eines Bauteils nur einmal und der Reihe nach aus. Verweist eine
  # Formel auf ein anderes Attribut desselben Bauteils, das selbst eine Formel hat, kann sie dessen
  # alten Wert lesen (z. B. NL aus T_Innen beim Spülenschrank: nach einer Tiefenänderung blieb der
  # Auszug zu lang/kurz). Liefert alle solchen Bezüge "Bauteil.Attribut -> Attribut".
  def self.bezuege_auf_eigene_formeln(k, out = [])
    eigene = schluessel_von(k)
    eigene.each do |key|
      f = k.formel(key) or next
      f.gsub(/"[^"]*"/, '').scan(/(?<![!\w])([A-Za-z_]\w*)\b(?!\s*[(!])/).flatten.uniq.each do |r|
        r = r.downcase
        out << "#{k.name}.#{key} -> #{r}" if r != key && eigene.include?(r)
      end
    end
    k.kinder.each { |c| bezuege_auf_eigene_formeln(c, out) }
    out
  end

  def self.schluessel_von(k)
    dicts = [k.defn, k.inst].compact.map { |e| e.attribute_dictionary('dynamic_attributes') }.compact
    dicts.flat_map(&:keys).grep(/\A_(.+)_formula\z/) { $1 }.uniq
  end
end

module TiefeHelfer
  # Komponentengrenze (Thread "Komponentengrenzen korrigieren"): SketchUp zählt auch ausgeblendete
  # Teile zum Kasten der Komponente (blauer Auswahlrahmen, Einfügen/Andocken). Ein ausgeblendetes
  # Teil darf deshalb nie über die sichtbaren Teile hinausragen, sonst ist der Schrank scheinbar
  # breiter/tiefer/höher. Liefert die Teile, die herausragen.
  def self.ausserhalb(k)
    alle = blaetter(k)
    sichtbar = alle.values.reject { |_, l, vs| vs || l.any?(&:nil?) }
    return [] if sichtbar.empty?
    min = (0..2).map { |i| sichtbar.map { |o, l, _| [o[i], o[i] + l[i]].min }.min }
    max = (0..2).map { |i| sichtbar.map { |o, l, _| [o[i], o[i] + l[i]].max }.max }
    alle.filter_map do |p, (o, l, vs)|
      next unless vs && l.none?(&:nil?)
      raus = (0..2).select { |i| [o[i], o[i] + l[i]].min < min[i] - EPS || [o[i], o[i] + l[i]].max > max[i] + EPS }
      next if raus.empty?
      "#{p} (ausgeblendet) ragt in #{raus.map { |i| ACHSEN[i] }.join('/')} heraus"
    end
  end
end
