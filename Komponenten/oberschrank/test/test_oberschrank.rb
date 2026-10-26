# Test ohne SketchUp: Mock-API + kleiner DC-Formel-Auswerter.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
load File.expand_path('../src/oberschrank/main.rb', __dir__)

H = Oberschrank
EPS = 1e-6
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

class Knoten
  attr_reader :inst, :defn, :parent, :kinder
  def initialize(inst, defn, parent)
    @inst, @defn, @parent = inst, defn, parent
    @werte = {}
    @kinder = defn.entities.instances.map { |ci| Knoten.new(ci, ci.definition, self) }
  end

  def name = inst&.get_attribute(H::DICT, '_name') || defn.get_attribute(H::DICT, '_name')

  def roh(attr)
    k = attr.downcase
    return @werte[k] if @werte.key?(k)
    v = inst&.get_attribute(H::DICT, k)
    v = defn.get_attribute(H::DICT, k) if v.nil?
    v = inst.transformation.origin[%w[x y z].index(k)] if v.nil? && inst && %w[x y z].include?(k)
    raise "Attribut #{attr} fehlt an #{name}" if v.nil?
    fu = defn.get_attribute(H::DICT, "_#{k}_formulaunits")
    %w[x y z lenx leny lenz].include?(k) || fu == 'CENTIMETERS' ? v * 2.54 : v
  end

  def formel(k) = inst&.get_attribute(H::DICT, "_#{k}_formula") || defn.get_attribute(H::DICT, "_#{k}_formula")

  def ref(n, attr)
    ziel = parent && parent.name == n ? parent : (parent ? parent.kinder : []).find { |s| s.name == n }
    raise "Referenz #{n}!#{attr} von #{name} nicht auflösbar" unless ziel
    ziel.roh(attr)
  end

  def IF(c, a, b) = c ? a : b
  def AND(*a) = a.all?

  def auswerten(f)
    ruby = f.gsub(/(?<![<>=!])=(?!=)/, '==').gsub(/(\w+)!(\w+)|\b([A-Za-z_]\w*)\b(?!\s*\()/) do
      $1 ? "ref(#{$1.inspect},#{$2.inspect})" : "roh(#{$3.inspect})"
    end
    v = instance_eval(ruby)
    v == true ? 1.0 : (v == false ? 0.0 : v.to_f)
  end

  def schluessel
    keys = (defn.attribute_dictionary(H::DICT)&.keys || []) + (inst&.attribute_dictionary(H::DICT)&.keys || [])
    keys.grep(/\A_(.+)_formula\z/) { $1 }.uniq.sort
  end

  def redraw
    schluessel.each { |k| @werte[k] = auswerten(formel(k)) }
    kinder.each(&:redraw)
  end

  def wert(k) = roh(k)
  def finde(n) = kinder.find { |c| c.name == n } || raise("#{n} fehlt")
  def hidden? = (defn.get_attribute(H::DICT, '_hidden_formula') ? wert('hidden') > 0.5 : false)
  def pos(ax) = (formel(ax) ? wert(ax) : inst.transformation.origin[%w[x y z].index(ax)] * 2.54)
end

# Absolute Quader [x0,x1,y0,y1,z0,z1] aller Blatt-Teile, mit Sichtbarkeit
def teile(k, off = [0, 0, 0], versteckt = false, out = [])
  k.kinder.each do |c|
    o = off.each_with_index.map { |v, i| v + c.pos(%w[x y z][i]) }
    vs = versteckt || c.hidden?
    if c.kinder.empty?
      l = %w[lenx leny lenz].map { |a| c.formel(a) ? c.wert(a) : c.defn.box[%w[lenx leny lenz].index(a)] * 2.54 }
      out << { name: c.name, pfad: "#{k.name}/#{c.name}", q: [o[0], o[0] + l[0], o[1], o[1] + l[1], o[2], o[2] + l[2]], hidden: vs }
    else
      teile(c, o, vs, out)
    end
  end
  out
end

def pruefe_geometrie(k, label)
  if k.inst && k.parent
    o = k.inst.transformation.origin.map { |v| v * 2.54 }
    %w[x y z].each_with_index do |ax, i|
      next unless k.formel(ax)
      check((o[i] - k.wert(ax)).abs < EPS, "#{label}: #{k.name}.#{ax} gezeichnet #{o[i]} vs Formel #{k.wert(ax)}")
    end
    %w[lenx leny lenz].each_with_index do |ax, i|
      next unless k.defn.box && k.formel(ax)
      check((k.defn.box[i] * 2.54 - k.wert(ax)).abs < EPS, "#{label}: #{k.name}.#{ax} gezeichnet vs Formel")
    end
    check(!!k.inst.hidden == k.hidden?, "#{label}: #{k.name} hidden gezeichnet vs Formel")
  end
  k.kinder.each { |c| pruefe_geometrie(c, label) }
end

def ueberlapp?(a, b) = (0..2).all? { |i| a[2 * i] < b[2 * i + 1] - EPS && b[2 * i] < a[2 * i + 1] - EPS }
def blaetter(k, out = [])
  k.kinder.each { |c| c.kinder.empty? ? out << c : blaetter(c, out) }
  out
end
def nahe(a, b) = (a - b).abs < EPS

KANTEN_SOLL = {
  'SeiteL' => %i[ymin zmin zmax], 'SeiteR' => %i[ymin zmin zmax], 'Boden' => %i[ymin], 'Deckel' => %i[ymin],
  'Rückwand' => [], 'Tür' => %i[xmin xmax zmin zmax], 'TürL' => %i[xmin xmax zmin zmax], 'TürR' => %i[xmin xmax zmin zmax]
}.freeze

def pruefe(w, p, label)
  b, h, t = p['Breite'], p['Hoehe'], p['Tiefe']
  mk, sp, rw, vs, nut = 1.9, 0.2, 0.8, 2.5, 0.9
  alle = teile(w)
  sichtbar = alle.reject { |t2| t2[:hidden] }
  q = ->(n) { (sichtbar.find { |t2| t2[:name] == n } || raise("#{label}: #{n} fehlt"))[:q] }

  alle.each do |t2|
    a = t2[:q]
    check(a[0] >= -EPS && a[1] <= b + EPS && a[4] >= -EPS && a[5] <= h + EPS && a[2] >= -sp - EPS && a[3] <= t + mk + EPS,
          "#{label}: #{t2[:pfad]} außerhalb #{a.map { |v| v.round(2) }}")
  end
  # Kollisionen; erlaubt ist nur die Rückwand in der Nut von Seiten und Boden
  nut_ok = ->(a, c) { a[:name] == 'Rückwand' && %w[SeiteL SeiteR Boden].include?(c[:name]) }
  sichtbar.combination(2).each do |a, c|
    next if nut_ok.(a, c) || nut_ok.(c, a)
    check(!ueberlapp?(a[:q], c[:q]), "#{label}: Kollision #{a[:pfad]} / #{c[:pfad]}")
  end

  # Rückwand: 25 mm vor der Hinterkante, 9 mm in Seiten und Boden, oben bündig
  rq = q.('Rückwand')
  check(nahe(rq[3], mk + t - vs) && nahe(rq[3] - rq[2], rw), "#{label}: Rückwand Lage y #{rq[2..3]}")
  check(nahe(rq[0], mk - nut) && nahe(rq[1], b - mk + nut), "#{label}: Rückwand in Seitennut #{rq[0..1]}")
  check(nahe(rq[4], mk - nut) && nahe(rq[5], h), "#{label}: Rückwand in Bodennut, oben bündig #{rq[4..5]}")
  # Deckel endet vor der Rückwand, Boden geht durch
  dq = q.('Deckel')
  check(nahe(dq[3], rq[2]) && nahe(dq[5], h), "#{label}: Deckel endet vor Rückwand #{dq}")
  check(nahe(q.('Boden')[3], mk + t) && nahe(q.('Boden')[4], 0), "#{label}: Boden volle Tiefe")
  %w[SeiteL SeiteR].each { |s| check(nahe(q.(s)[5] - q.(s)[4], h) && nahe(q.(s)[3] - q.(s)[2], t), "#{label}: #{s}") }

  # Türen
  tueren = sichtbar.select { |t2| t2[:name].start_with?('Tür') }.sort_by { |t2| t2[:q][0] }
  check(tueren.size == p['Art_Tuer'], "#{label}: #{tueren.size} Türen statt #{p['Art_Tuer']}")
  tueren.each { |t2| check(nahe(t2[:q][4], sp / 2) && nahe(t2[:q][5], h - sp / 2) && nahe(t2[:q][2], -sp), "#{label}: Tür Höhe/Lage #{t2[:q]}") }
  unless tueren.empty?
    check(nahe(tueren.first[:q][0], sp / 2) && nahe(tueren.last[:q][1], b - sp / 2), "#{label}: Türen außen #{sp / 2} Fuge")
    tueren.each_cons(2) { |a, c| check(nahe(c[:q][0] - a[:q][1], sp), "#{label}: Fuge zwischen den Türen") }
  end

  # Einlegeböden gleichmäßig, vor der Rückwand
  eb = sichtbar.select { |t2| t2[:name].start_with?('Einlegeboden') }.sort_by { |t2| t2[:q][4] }
  check(eb.size == p['Anz_Einlegeboeden'], "#{label}: Einlegeböden #{eb.size}")
  fach = (h - 2 * mk) / (eb.size + 1)
  eb.each_with_index do |t2, i|
    check(nahe(t2[:q][4] + mk / 2, mk + fach * (i + 1)), "#{label}: Einlegeboden #{i + 1} Höhe")
    check(t2[:q][3] <= rq[2] + EPS && nahe(t2[:q][2], mk + 1.0), "#{label}: Einlegeboden #{i + 1} Tiefe")
  end
end

def pruefe_ocl(w, label, kz)
  m = Sketchup.active_model.materials
  platte = m[H::MATERIAL]; kante = m[H::KANTE]
  check(platte.get_attribute(H::OCL_DICT, 'type') == 2, "#{label}: Plattenmaterial OCL-Typ")
  check(kante.get_attribute(H::OCL_DICT, 'type') == 4 && kante.get_attribute(H::OCL_DICT, 'edge_decremented') == true,
        "#{label}: Anleimer OCL")
  tags = []
  blaetter(w).each do |b|
    soll = b.name.start_with?('Einlegeboden') ? %i[ymin] : KANTEN_SOLL.fetch(b.name) { raise "kein Soll für #{b.name}" }
    check(b.inst.material.equal?(platte), "#{label}: #{b.name} ohne Plattenmaterial")
    ist = b.defn.entities.faces.select { |f| f.material.equal?(kante) }.map do |f|
      H::SEITEN.find { |_, (ax, vz)| f.normal.to_a[ax] * vz > 0.5 }.first
    end
    check(ist.sort == soll.sort, "#{label}: #{b.name} Anleimer #{ist.inspect} statt #{soll.inspect}")
    jt = %w[schrank typ kategorie bereich teil rolle].to_h { |k| [k, b.inst.get_attribute(H::JT_DICT, k)] }
    check(jt['schrank'] == kz && jt['typ'] == 'Oberschrank' && jt['kategorie'] == 'Oberschrank' && jt['bereich'] == '',
          "#{label}: #{b.name} JT_Schrank #{jt.inspect}")
    check(b.inst.layer&.name == "#{kz}_#{jt['teil']}", "#{label}: #{b.name} Tag #{b.inst.layer&.name}")
    check(H::ROLLEN.value?(jt['rolle']), "#{label}: #{b.name} Rolle #{jt['rolle'].inspect}")
    tags << b.inst.layer.name
  end
  check(tags.uniq.size == tags.size, "#{label}: Tags eindeutig")
  check((%w[SeiteL SeiteR Boden Deckel Rueckwand Tuer TuerL TuerR] + (1..3).map { |k| "Einlegeboden#{k}" }).sort ==
        tags.map { |n| n.delete_prefix("#{kz}_") }.sort, "#{label}: Tag-Liste #{tags.inspect}")
end

def lauf(p, label, umkonf = nil, kz = 'OS1')
  Sketchup.active_model = Sketchup::Model.new
  inst = H.erstellen(p)
  p = H::DEFAULTS.merge(p)
  w = Knoten.new(inst, inst.definition, nil)
  w.redraw
  pruefe(w, p, label)
  pruefe_geometrie(w, label)
  pruefe_ocl(w, label, kz)
  return unless umkonf
  d = inst.definition
  umkonf.each { |k, v| d.set_attribute(H::DICT, k.downcase, %w[Breite Hoehe Tiefe].include?(k) ? v / 2.54 : v.to_f) }
  w2 = Knoten.new(inst, d, nil)
  w2.redraw
  pruefe(w2, p.merge(umkonf), "#{label} -> umkonfiguriert")
end

lauf({}, 'Standard (2 Türen)', { 'Art_Tuer' => 1, 'Anz_Einlegeboeden' => 3, 'Breite' => 45.0, 'Hoehe' => 90.0 })
lauf({ 'Breite' => 40.0, 'Art_Tuer' => 1.0, 'Anz_Einlegeboeden' => 2.0 }, 'eine Tür', { 'Art_Tuer' => 0, 'Anz_Einlegeboeden' => 0 })
lauf({ 'Art_Tuer' => 0.0, 'Anz_Einlegeboeden' => 0.0, 'Tiefe' => 32.0 }, 'offen', { 'Art_Tuer' => 2, 'Tiefe' => 35.0 })
lauf({ 'Kuerzel' => 'OS7' }, 'eigenes Kürzel', nil, 'OS7')

# Zweiter Schrank im selben Modell bekommt OS2
Sketchup.active_model = Sketchup::Model.new
H.erstellen({})
H.erstellen({})
check(Sketchup.active_model.layers['OS2_TuerR'], 'zweiter Schrank OS2')
check(Sketchup.active_model.definitions[H::NAME].get_attribute(H::JT_DICT, 'kategorie') == 'Oberschrank', 'JT_Schrank am Schrank')

# --- Kurzhilfe in der Komponente ------------------------------------------
hd = Sketchup.active_model.definitions[H::NAME]
check(hd.description == H::HILFE_KURZ, 'Hilfe: Beschreibung der Definition')
check(hd.get_attribute(H::DICT, 'summary') == H::HILFE_KURZ, 'Hilfe: summary')
check(hd.get_attribute(H::DICT, 'description') == H::HILFE, 'Hilfe: description')
check(H::HILFE.include?(H::DOKU_URL), 'Hilfe: Link zur Doku')
check(File.exist?(File.expand_path('../README.md', __dir__)), 'README.md vorhanden')

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
