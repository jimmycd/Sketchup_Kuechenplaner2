# Test ohne SketchUp: Mock-API + kleiner DC-Formel-Auswerter.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
load File.expand_path('../src/unterschrank_doppeltuer/main.rb', __dir__)

H = UnterschrankDoppeltuer
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
  def MIN(*a) = a.min
  def MAX(*a) = a.max
  def INT(x) = x.floor.to_f

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

  # zweimal, damit Werte, die von später ausgewerteten Werten abhängen, stimmen
  def redraw
    2.times { schluessel.each { |k| @werte[k] = auswerten(formel(k)) } }
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
      out << { name: c.name, knoten: c, pfad: "#{k.name}/#{c.name}",
               q: [o[0], o[0] + l[0], o[1], o[1] + l[1], o[2], o[2] + l[2]], hidden: vs }
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

ALLE4 = %i[xmin xmax zmin zmax].freeze
KANTEN_SOLL = {
  'SeiteL' => %i[ymin], 'SeiteR' => %i[ymin], 'Boden' => %i[ymin], 'StrebeVorn' => %i[ymin], 'StrebeHinten' => [],
  'Rückwand' => [], 'TürL' => ALLE4, 'TürR' => ALLE4,
  'Einlegeboden1' => %i[ymin], 'Einlegeboden2' => %i[ymin], 'Einlegeboden3' => %i[ymin]
}.freeze

def pruefe(w, p, label)
  b, h, t = p['Breite'], p['Hoehe'], p['Tiefe']
  mk, sp, rw, bs = 1.9, 0.2, 0.8, 10.0
  n = p['Anz_Einlegeboeden'].to_i
  hinten = mk + t + rw # Rückseite wie beim Unterschrank mit Tür (Korpus + Rückwand dahinter)
  alle = teile(w)
  sichtbar = alle.reject { |t2| t2[:hidden] }
  q = ->(nm) { (sichtbar.find { |t2| t2[:name] == nm } || raise("#{label}: #{nm} fehlt"))[:q] }

  # Komponentengrenzen: alle Teile (auch ausgeblendete) innerhalb des Schranks
  alle.each do |t2|
    a = t2[:q]
    check(a[0] >= -EPS && a[1] <= b + EPS && a[4] >= -EPS && a[5] <= h + EPS && a[2] >= -sp - EPS && a[3] <= hinten + EPS,
          "#{label}: #{t2[:pfad]} außerhalb #{a.map { |v| v.round(2) }}")
  end
  sichtbar.combination(2).each do |a, c|
    check(!ueberlapp?(a[:q], c[:q]), "#{label}: Kollision #{a[:pfad]} / #{c[:pfad]}")
  end

  rq = q.('Rückwand')
  check(nahe(rq[0], 0) && nahe(rq[1], b) && nahe(rq[4], 0) && nahe(rq[5], h) && nahe(rq[2], mk + t) && nahe(rq[3], hinten),
        "#{label}: Rückwand hinter dem Korpus #{rq}")
  %w[SeiteL SeiteR Boden].each { |nm| check(nahe(q.(nm)[2], mk) && nahe(q.(nm)[3], mk + t), "#{label}: #{nm} volle Tiefe") }
  %w[SeiteL SeiteR].each { |s| check(nahe(q.(s)[4], 0) && nahe(q.(s)[5], h), "#{label}: #{s} volle Höhe") }
  check(nahe(q.('SeiteL')[0], 0) && nahe(q.('SeiteR')[1], b), "#{label}: Seiten außen")
  check(nahe(q.('Boden')[4], 0) && nahe(q.('Boden')[0], mk) && nahe(q.('Boden')[1], b - mk), "#{label}: Boden zwischen den Seiten")
  sv, sh = q.('StrebeVorn'), q.('StrebeHinten')
  check(nahe(sv[2], mk) && nahe(sv[3], mk + bs) && nahe(sv[5], h), "#{label}: Strebe vorn #{sv}")
  check(nahe(sh[3], mk + t) && nahe(sh[2], mk + t - bs) && nahe(sh[5], h), "#{label}: Strebe hinten an der Rückwand #{sh}")

  # Einlegeböden: gleich hohe Fächer zwischen Boden und Streben
  eb = sichtbar.select { |t2| t2[:name].start_with?('Einlegeboden') }.sort_by { |t2| t2[:q][4] }
  check(eb.size == n, "#{label}: #{eb.size} Einlegeböden statt #{n}")
  kanten = [mk] + eb.flat_map { |t2| [t2[:q][4], t2[:q][5]] } + [h - mk]
  faecher = kanten.each_slice(2).map { |u, o| o - u }
  check(faecher.all? { |f| nahe(f, faecher.first) && f > 0 }, "#{label}: Fächer gleich hoch #{faecher.map { |f| f.round(3) }}")
  eb.each { |t2| check(nahe(t2[:q][2], mk + 1.0) && nahe(t2[:q][3], mk + t) && nahe(t2[:q][0], mk) && nahe(t2[:q][1], b - mk),
                       "#{label}: Einlegeboden 10 mm zurückgesetzt, bis zur Rückwand #{t2[:q]}") }

  # Zwei Türen: volle Höhe, außen halbe Fuge, dazwischen eine Fuge
  tueren = sichtbar.select { |t2| t2[:name].start_with?('Tür') }.sort_by { |t2| t2[:q][0] }
  check(tueren.map { |t2| t2[:name] } == %w[TürL TürR], "#{label}: Türen #{tueren.map { |t2| t2[:name] }}")
  tueren.each { |t2| check(nahe(t2[:q][4], 0) && nahe(t2[:q][5], h) && nahe(t2[:q][2], -sp) && nahe(t2[:q][3], -sp + mk),
                           "#{label}: Tür Höhe/Lage #{t2[:q]}") }
  check(nahe(tueren.first[:q][0], sp / 2) && nahe(tueren.last[:q][1], b - sp / 2), "#{label}: Türen außen #{sp / 2} Fuge")
  check(nahe(tueren.last[:q][0] - tueren.first[:q][1], sp), "#{label}: Fuge zwischen den Türen")
  check(nahe(tueren.first[:q][1] - tueren.first[:q][0], b / 2 - sp), "#{label}: Türbreite Breite/2 - Fuge")
end

# Türen öffnen sich mit "Interagieren": links um die linke Kante, rechts um die rechte
def pruefe_drehen(w, label)
  tl = w.finde('TürL')
  hr = w.finde('TuerRHalter')
  check(tl.defn.get_attribute(H::DICT, 'onclick') == 'ANIMATE("ROTZ",0,-100)', "#{label}: linke Tür öffnet nach links")
  check(hr.defn.get_attribute(H::DICT, 'onclick') == 'ANIMATE("ROTZ",0,100)', "#{label}: rechte Tür öffnet nach rechts")
  check(nahe(hr.pos('x'), w.wert('breite') - 0.1) && nahe(hr.finde('TürR').pos('x'), -hr.wert('b_tuer')),
        "#{label}: Drehpunkt rechte Tür an der rechten Außenkante")
end

def pruefe_ocl(w, label, kz)
  m = Sketchup.active_model.materials
  platte = m[H::MATERIAL]; kante = m[H::KANTE]
  check(platte.get_attribute(H::OCL_DICT, 'type') == 2, "#{label}: Plattenmaterial OCL-Typ")
  check(kante.get_attribute(H::OCL_DICT, 'type') == 4 && kante.get_attribute(H::OCL_DICT, 'edge_decremented') == true,
        "#{label}: Anleimer OCL")
  tags = []
  blaetter(w).each do |b|
    soll = KANTEN_SOLL.fetch(b.name) { raise "kein Soll für #{b.name}" }
    check(b.inst.material.equal?(platte), "#{label}: #{b.name} ohne Plattenmaterial")
    ist = b.defn.entities.faces.select { |f| f.material.equal?(kante) }.map do |f|
      H::SEITEN.find { |_, (ax, vz)| f.normal.to_a[ax] * vz > 0.5 }.first
    end
    check(ist.sort == soll.sort, "#{label}: #{b.name} Anleimer #{ist.inspect} statt #{soll.inspect}")
    jt = %w[schrank typ kategorie bereich teil rolle].to_h { |k| [k, b.inst.get_attribute(H::JT_DICT, k)] }
    check(jt['schrank'] == kz && jt['typ'] == 'Unterschrank_Doppeltuer' && jt['kategorie'] == 'Unterschrank' &&
          jt['bereich'] == '', "#{label}: #{b.name} JT_Schrank #{jt.inspect}")
    check(b.inst.layer&.name == "#{kz}_#{jt['teil']}", "#{label}: #{b.name} Tag #{b.inst.layer&.name}")
    check(H::ROLLEN.value?(jt['rolle']), "#{label}: #{b.name} Rolle #{jt['rolle'].inspect}")
    tags << b.inst.layer.name
  end
  check(tags.uniq.size == tags.size, "#{label}: Tags eindeutig")
  check(%w[SeiteL SeiteR Boden StrebeVorn StrebeHinten Rueckwand TuerL TuerR Einlegeboden1 Einlegeboden2 Einlegeboden3].sort ==
        tags.map { |nm| nm.delete_prefix("#{kz}_") }.sort, "#{label}: Tag-Liste #{tags.inspect}")
end

LAENGEN = %w[Breite Hoehe Tiefe].freeze

def lauf(p, label, umkonf = nil, kz = 'USD1')
  Sketchup.active_model = Sketchup::Model.new
  inst = H.erstellen(p)
  p = H::DEFAULTS.merge(p)
  w = Knoten.new(inst, inst.definition, nil)
  w.redraw
  pruefe(w, p, label)
  pruefe_geometrie(w, label)
  pruefe_drehen(w, label)
  pruefe_ocl(w, label, kz)
  return unless umkonf
  d = inst.definition
  umkonf.each { |k, v| d.set_attribute(H::DICT, k.downcase, LAENGEN.include?(k) ? v / 2.54 : v.to_f) }
  w2 = Knoten.new(inst, d, nil)
  w2.redraw
  pruefe(w2, p.merge(umkonf), "#{label} -> umkonfiguriert")
  pruefe_drehen(w2, "#{label} -> umkonfiguriert")
end

lauf({}, 'Standard 800 breit, 1 Einlegeboden', { 'Breite' => 120.0, 'Anz_Einlegeboeden' => 3 })
lauf({ 'Anz_Einlegeboeden' => 0.0 }, 'ohne Einlegeboden', { 'Anz_Einlegeboeden' => 2, 'Hoehe' => 55.0 })
lauf({ 'Anz_Einlegeboeden' => 2.0, 'Breite' => 60.0, 'Tiefe' => 56.0 }, '600 x 560, 2 Einlegeböden', { 'Tiefe' => 40.0, 'Anz_Einlegeboeden' => 0 })
lauf({ 'Anz_Einlegeboeden' => 3.0, 'Breite' => 100.0, 'Hoehe' => 78.0 }, '3 Einlegeböden', { 'Anz_Einlegeboeden' => 1, 'Breite' => 40.0 })
lauf({ 'Kuerzel' => 'USD7' }, 'eigenes Kürzel', nil, 'USD7')

r = H.berechne(H::DEFAULTS)
check(nahe(r[:b_tuer], 39.8), "Standard: zwei Türen je 398 mm (#{r[:b_tuer]})")

# Zweiter Schrank im selben Modell bekommt USD2
Sketchup.active_model = Sketchup::Model.new
H.erstellen({})
H.erstellen({})
check(Sketchup.active_model.layers['USD2_TuerL'] && Sketchup.active_model.layers['USD2_TuerR'], 'zweiter Schrank USD2')
check(Sketchup.active_model.definitions[H::NAME].get_attribute(H::JT_DICT, 'kategorie') == 'Unterschrank', 'JT_Schrank am Schrank')

# --- Kurzhilfe in der Komponente ------------------------------------------
hd = Sketchup.active_model.definitions[H::NAME]
check(hd.description == H::HILFE_KURZ, 'Hilfe: Beschreibung der Definition')
check(hd.get_attribute(H::DICT, 'summary') == H::HILFE_KURZ, 'Hilfe: summary')
check(hd.get_attribute(H::DICT, 'description').nil?, 'Hilfe: description')
check(File.exist?(File.expand_path('../README.md', __dir__)), 'README.md vorhanden')

# --- Tiefe nachträglich ändern (Komponentenoptionen) = gleich mit dieser Tiefe erzeugt ---
require_relative '../../../test/tiefe_helfer'
TiefeHelfer.pruefen(Knoten, H::DICT, ->(e) { H.erstellen(e) },
                    [[52.0, 40.0], [52.0, 65.0], [56.0, 47.3]]).each do |was, abw|
  check(abw.empty?, "Tiefe #{was}: " + abw.first(8).join('; '))
end

# --- Griffkante (Schrank-CNC setzt Griff_Front): Luft über jeder Front, Korpus bleibt ---
require_relative '../../../test/griff_helfer'
[{}].each do |e|
  f = GriffHelfer.pruefen(Knoten, H::DICT, ->(x) { H.erstellen(x) }, e)
  check(f.empty?, "Griffkante #{e.inspect}: " + f.first(8).join('; '))
end

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
