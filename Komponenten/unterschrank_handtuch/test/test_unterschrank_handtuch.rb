# Test ohne SketchUp: Mock-API + kleiner DC-Formel-Auswerter.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
load File.expand_path('../src/unterschrank_handtuch/main.rb', __dir__)

H = UnterschrankHandtuch
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
  'SeiteL' => %i[ymin], 'SeiteR' => %i[ymin], 'Boden' => %i[ymin], 'StrebeVorn' => %i[ymin],
  'StrebeHinten' => [], 'Rückwand' => [], 'Front' => %i[xmin xmax zmin zmax], 'Beschlag' => []
}.freeze

def pruefe(w, p, label)
  b = { 150 => 15.0, 200 => 20.0 }.fetch(p['Modell'].to_i)
  h, t = p['Hoehe'], p['Tiefe']
  mk, sp, rw, bs = 1.9, 0.2, 0.8, 10.0
  check(nahe(w.wert('breite'), b), "#{label}: Breite #{w.wert('breite')} aus Modell M#{p['Modell'].to_i}")
  alle = teile(w)
  q = ->(n) { (alle.find { |t2| t2[:name] == n } || raise("#{label}: #{n} fehlt"))[:q] }
  check(alle.none? { |t2| t2[:hidden] }, "#{label}: nichts ausgeblendet")

  alle.each do |t2|
    a = t2[:q]
    check(a[0] >= -EPS && a[1] <= b + EPS && a[4] >= -EPS && a[5] <= h + EPS && a[2] >= -sp - EPS && a[3] <= t + mk + rw + EPS,
          "#{label}: #{t2[:pfad]} außerhalb #{a.map { |v| v.round(2) }}")
  end
  alle.combination(2).each do |a, c|
    check(!ueberlapp?(a[:q], c[:q]), "#{label}: Kollision #{a[:pfad]} / #{c[:pfad]}")
  end

  # Korpus wie Unterschrank mit Schubladen
  check(nahe(q.('SeiteL')[0], 0) && nahe(q.('SeiteR')[1], b) && nahe(q.('SeiteL')[2], mk) && nahe(q.('SeiteL')[3], mk + t), "#{label}: Seiten")
  check(nahe(q.('Boden')[4], 0) && nahe(q.('Boden')[5], mk) && nahe(q.('Boden')[1] - q.('Boden')[0], b - 2 * mk), "#{label}: Boden zwischen den Seiten")
  check(nahe(q.('StrebeVorn')[2], mk) && nahe(q.('StrebeVorn')[3], mk + bs) && nahe(q.('StrebeVorn')[5], h), "#{label}: Strebe vorn oben")
  check(nahe(q.('StrebeHinten')[3], mk + t) && nahe(q.('StrebeHinten')[5], h), "#{label}: Strebe hinten oben")
  check(nahe(q.('Rückwand')[2], mk + t) && nahe(q.('Rückwand')[1], b) && nahe(q.('Rückwand')[5], h), "#{label}: Rückwand hinter dem Korpus")

  # Front über die volle Höhe, 1 mm Fuge seitlich, 2 mm vor dem Korpus
  f = q.('Front')
  check(nahe(f[0], sp / 2) && nahe(f[1], b - sp / 2) && nahe(f[2], -sp) && nahe(f[3], -sp + mk) && nahe(f[4], 0) && nahe(f[5], h),
        "#{label}: Front #{f}")

  # Einbauraum Häfele: lichte Weite 112/162, 485 tief, 565 hoch, auf dem Boden ab Korpusvorderkante
  g = q.('Beschlag')
  check(nahe(g[1] - g[0], b - 2 * mk) && nahe(g[0], mk) && nahe(g[2], mk) && nahe(g[3] - g[2], 48.5) &&
        nahe(g[4], mk) && nahe(g[5] - g[4], 56.5), "#{label}: Einbauraum Beschlag #{g}")
  check(nahe(b - 2 * mk, p['Modell'].to_i == 200 ? 16.2 : 11.2), "#{label}: lichte Weite wie Häfele verlangt")
end

def pruefe_ocl(w, label, kz)
  m = Sketchup.active_model.materials
  platte = m[H::MATERIAL]; kante = m[H::KANTE]; beschlag = m[H::BESCHLAG]
  check(platte.get_attribute(H::OCL_DICT, 'type') == 2, "#{label}: Plattenmaterial OCL-Typ")
  check(kante.get_attribute(H::OCL_DICT, 'type') == 4 && kante.get_attribute(H::OCL_DICT, 'edge_decremented') == true,
        "#{label}: Anleimer OCL")
  check(beschlag.get_attribute(H::OCL_DICT, 'type') == 5, "#{label}: Beschlag ist in OCL ein Beschlag (Typ 5)")
  tags = []
  blaetter(w).each do |b|
    soll = KANTEN_SOLL.fetch(b.name) { raise "kein Soll für #{b.name}" }
    ist = b.defn.entities.faces.select { |f| f.material.equal?(kante) }.map do |f|
      H::SEITEN.find { |_, (ax, vz)| f.normal.to_a[ax] * vz > 0.5 }.first
    end
    check(ist.sort == soll.sort, "#{label}: #{b.name} Anleimer #{ist.inspect} statt #{soll.inspect}")
    tags << b.inst.layer.name
    if b.name == 'Beschlag'
      check(b.inst.material.equal?(beschlag), "#{label}: Beschlag-Material")
      check(b.inst.attribute_dictionary(H::JT_DICT).nil?, "#{label}: Beschlag ohne JT_Schrank (kein Werkstück)")
      next
    end
    check(b.inst.material.equal?(platte), "#{label}: #{b.name} ohne Plattenmaterial")
    jt = %w[schrank typ kategorie bereich teil rolle].to_h { |k| [k, b.inst.get_attribute(H::JT_DICT, k)] }
    check(jt['schrank'] == kz && jt['typ'] == 'Unterschrank_Handtuch' && jt['kategorie'] == 'Unterschrank' && jt['bereich'] == '',
          "#{label}: #{b.name} JT_Schrank #{jt.inspect}")
    check(b.inst.layer&.name == "#{kz}_#{jt['teil']}", "#{label}: #{b.name} Tag #{b.inst.layer&.name}")
    check(H::ROLLEN.value?(jt['rolle']), "#{label}: #{b.name} Rolle #{jt['rolle'].inspect}")
  end
  check(tags.uniq.size == tags.size, "#{label}: Tags eindeutig")
  check(%w[SeiteL SeiteR Boden StrebeVorn StrebeHinten Rueckwand Front Beschlag].sort ==
        tags.map { |n| n.delete_prefix("#{kz}_") }.sort, "#{label}: Tag-Liste #{tags.inspect}")
  check(w.finde('Auszug').inst.layer.name == "#{kz}_Auszug", "#{label}: Auszug-Gruppe eigener Tag")
end

def lauf(p, label, umkonf = nil, kz = 'USH1')
  Sketchup.active_model = Sketchup::Model.new
  inst = H.erstellen(p)
  p = H::DEFAULTS.merge(p)
  w = Knoten.new(inst, inst.definition, nil)
  w.redraw
  pruefe(w, p, label)
  pruefe_geometrie(w, label)
  pruefe_ocl(w, label, kz)
  d = inst.definition
  check(d.get_attribute(H::JT_DICT, 'beschlag') == 'Haefele HU Slim Base' && d.get_attribute(H::JT_DICT, 'schrank') == kz,
        "#{label}: JT_Schrank am Schrank")
  check(w.finde('Auszug').defn.get_attribute(H::DICT, 'onclick') == 'ANIMATE("Y",0,-Weg)', "#{label}: Auszug fährt heraus")
  return unless umkonf
  umkonf.each { |k, v| d.set_attribute(H::DICT, k.downcase, %w[Hoehe Tiefe].include?(k) ? v / 2.54 : v.to_f) }
  w2 = Knoten.new(inst, d, nil)
  w2.redraw
  pruefe(w2, p.merge(umkonf), "#{label} -> umkonfiguriert")
end

lauf({}, 'Standard M150', { 'Modell' => 200, 'Hoehe' => 72.0, 'Tiefe' => 56.0 })
lauf({ 'Modell' => 200.0, 'Seite_Beschlag' => 1.0, 'Tiefe' => 56.0 }, 'M200 rechts', { 'Modell' => 150, 'Hoehe' => 65.0 })
lauf({ 'Kuerzel' => 'USH7' }, 'eigenes Kürzel', nil, 'USH7')
begin
  Sketchup.active_model = Sketchup::Model.new
  H.erstellen({ 'Modell' => 300.0 })
  check(false, 'M300 abgelehnt')
rescue ArgumentError
end

# Zweiter Schrank im selben Modell bekommt USH2
Sketchup.active_model = Sketchup::Model.new
H.erstellen({})
H.erstellen({})
check(Sketchup.active_model.layers['USH2_Front'] && Sketchup.active_model.layers['USH2_Beschlag'], 'zweiter Schrank USH2')

# --- Kurzhilfe in der Komponente ------------------------------------------
hd = Sketchup.active_model.definitions['Unterschrank Handtuch']
check(hd.description == H::HILFE_KURZ, 'Hilfe: Beschreibung der Definition')
check(hd.get_attribute(H::DICT, 'summary') == H::HILFE_KURZ, 'Hilfe: summary')
check(hd.get_attribute(H::DICT, 'description') == H::HILFE, 'Hilfe: description')
check(%w[summary description].all? { |k| hd.get_attribute(H::DICT, "_#{k}_access") == 'VIEW' }, 'Hilfe: nur anzeigen')
check(H::HILFE.include?(H::DOKU_URL), 'Hilfe: Link zur Doku')
check(File.exist?(File.expand_path('../README.md', __dir__)), 'README.md vorhanden')

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
