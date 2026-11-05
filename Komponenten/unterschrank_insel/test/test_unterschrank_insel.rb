# Test ohne SketchUp: Mock-API + kleiner DC-Formel-Auswerter.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
load File.expand_path('../src/unterschrank_insel/main.rb', __dir__)

H = UnterschrankInsel
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
  def OR(*a) = a.any?
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
  'Rückwand' => [], 'Einlegeboden' => %i[ymin], 'Front' => ALLE4, 'Tür' => ALLE4, 'TürL' => ALLE4, 'TürR' => ALLE4,
  'KastenBoden' => [], 'KastenRueckwand' => %i[zmax],
  'Verkleidung' => %i[xmin xmax zmax], 'WangeL' => %i[ymin ymax zmax], 'WangeR' => %i[ymin ymax zmax],
  'Theke' => %i[xmin xmax ymin ymax]
}.freeze

def pruefe(w, p, label)
  b, h, t = p['Breite'], p['Hoehe'], p['Tiefe']
  mk, sp, rw, mv, sh = 1.9, 0.2, 0.8, 1.9, p['Sockelhoehe']
  r = H.berechne(p)
  alle = teile(w)
  sichtbar = alle.reject { |x| x[:hidden] }
  q = ->(pfad) { (sichtbar.find { |x| x[:pfad] == pfad } || raise("#{label}: #{pfad} fehlt")) [:q] }
  da = ->(pfad) { sichtbar.any? { |x| x[:pfad] == pfad } }
  n = H::NAME
  schub = p['Frontart'].to_i == 1
  theke = p['Theke'].to_i == 1
  verkl = theke || p['Verkleidung'].to_i == 1
  wl, wr = [1, 3].include?(p['Art_Wange'].to_i), [2, 3].include?(p['Art_Wange'].to_i)
  y_h = t + mk + rw
  y_a = y_h + (verkl ? mv : 0)

  # alles innerhalb des Schranks samt Wangen, Verkleidung und Theke; keine Kollisionen
  x0, x1 = wl ? -mv : 0, wr ? b + mv : b
  y1 = theke ? y_a + p['Ueberstand_Theke'] : y_a
  z1 = theke ? p['Hoehe_Theke'] - sh : h
  sichtbar.each do |x|
    a = x[:q]
    check(a[0] >= x0 - EPS && a[1] <= x1 + EPS && a[2] >= -sp - EPS && a[3] <= y1 + EPS && a[4] >= -sh - EPS && a[5] <= z1 + EPS,
          "#{label}: #{x[:pfad]} außerhalb #{a.map { |v| v.round(2) }}")
  end
  sichtbar.combination(2).each { |a, c| check(!ueberlapp?(a[:q], c[:q]), "#{label}: Kollision #{a[:pfad]} / #{c[:pfad]}") }

  # Korpus
  %w[SeiteL SeiteR].each { |s| check(nahe(q.("#{n}/#{s}")[5], h) && nahe(q.("#{n}/#{s}")[3] - q.("#{n}/#{s}")[2], t), "#{label}: #{s}") }
  rq = q.("#{n}/Rückwand")
  check(nahe(rq[2], t + mk) && nahe(rq[3], y_h) && nahe(rq[1] - rq[0], b), "#{label}: Rückwand hinter dem Korpus #{rq}")
  nl = H.nennlaenge(t)
  check(nahe(w.wert('nl'), nl), "#{label}: NL-Formel #{w.wert('nl')} statt #{nl}")

  # Fronten
  fronten = sichtbar.select { |x| %w[Front Tür TürL TürR].include?(x[:name]) }
  if schub
    anz = p['Anz_Schubladen'].to_i
    check(fronten.size == anz && fronten.all? { |x| x[:name] == 'Front' }, "#{label}: #{anz} Schubladenfronten (#{fronten.size})")
    fs = fronten.map { |x| x[:q] }.sort_by { |a| a[4] }
    check(nahe(fs.first[4], 0) && nahe(fs.last[5], h), "#{label}: Fronten von 0 bis Oberkante")
    fs.each_cons(2) { |a, c| check(nahe(c[4] - a[5], sp), "#{label}: Fuge zwischen den Schubladen") }
    hs = fs.map { |a| a[5] - a[4] }
    check(hs.all? { |v| nahe(v, hs.first) }, "#{label}: gleich hohe Fronten #{hs}")
    (1..anz).each do |i|
      g = "Schublade#{i}"
      f, kb, kr = q.("#{g}/Front"), q.("#{g}/KastenBoden"), q.("#{g}/KastenRueckwand")
      check(nahe(kb[3] - kb[2], nl - 1) && nahe(kb[1] - kb[0], b - 2 * mk - 3.5), "#{label}: #{g} Kastenboden #{kb}")
      rn = (kb[4] - p['Lochraster_Start']) / p['Lochraster']
      # mindestens 30 mm über der Front-Unterkante und Schiene mind. 38 mm über dem Korpusboden (LEGRABOX)
      min_ab = [f[4] + 3, mk + 3.8].max
      check(kb[4] >= min_ab - EPS && (rn - rn.round).abs < 1e-6 && kb[4] < min_ab + 3.2, "#{label}: #{g} Kasten im Lochraster #{kb[4]}")
      # Zarge C (Rückwand 148) oder M (62): oberste Schublade 30 mm unter der Frontoberkante, sonst bis an die Front
      ao = i == 1 ? 3.0 : 0.0
      zarge = kr[5] - kr[4] > 14.0 ? 17.7 : 9.05
      check((kb[4] + zarge <= f[5] - ao + EPS || f[5] - ao - kb[4] < 9.05) && nahe(kr[4], kb[5]),
            "#{label}: #{g} Kasten unter der Frontoberkante")
    end
    check(sichtbar.none? { |x| x[:name].start_with?('Einlegeboden') }, "#{label}: keine Einlegeböden bei Schubladen")
  else
    art = p['Art_Tuer'].to_i
    namen = fronten.map { |x| x[:name] }.sort
    check(namen == (art == 1 ? ['Tür'] : %w[TürL TürR]), "#{label}: Türen #{namen}")
    check(fronten.all? { |x| nahe(x[:q][4], 0) && nahe(x[:q][5], h) && nahe(x[:q][2], -sp) }, "#{label}: Türen über die volle Höhe")
    check(nahe(fronten.map { |x| x[:q][1] - x[:q][0] }.sum + (art == 1 ? sp : 2 * sp), b), "#{label}: Türbreite")
    eb = sichtbar.select { |x| x[:name].start_with?('Einlegeboden') }
    check(eb.size == p['Anz_Einlegeboeden'].to_i, "#{label}: #{eb.size} Einlegeböden")
    check(sichtbar.none? { |x| x[:pfad].start_with?('Schublade') }, "#{label}: keine Schubladen bei Türen")
  end

  # Verkleidung hinter der Rückwand bis zum Fußboden bzw. bis unter die Theke
  if verkl
    v = q.("#{n}/Verkleidung")
    check(nahe(v[2], y_h) && nahe(v[3], y_a) && nahe(v[0], 0) && nahe(v[1], b) && nahe(v[4], -sh) &&
          nahe(v[5], theke ? p['Hoehe_Theke'] - p['Staerke_Theke'] - sh : h), "#{label}: Verkleidung #{v}")
  else
    check(!da.("#{n}/Verkleidung"), "#{label}: keine Verkleidung")
  end
  # Wangen: von der Frontfläche bis hinter die Verkleidung, Fußboden bis Oberkante Korpus
  [['WangeL', wl, -mv], ['WangeR', wr, b]].each do |wn, soll, x|
    if soll
      a = q.("#{n}/#{wn}")
      check(nahe(a[0], x) && nahe(a[2], -sp) && nahe(a[3], y_a) && nahe(a[4], -sh) && nahe(a[5], h), "#{label}: #{wn} #{a}")
    else
      check(!da.("#{n}/#{wn}"), "#{label}: keine #{wn}")
    end
  end
  # Theke
  if theke
    a = q.("#{n}/Theke")
    check(nahe(a[5], p['Hoehe_Theke'] - sh) && nahe(a[3], y_a + p['Ueberstand_Theke']) && nahe(a[3] - a[2], p['Tiefe_Theke']) &&
          nahe(a[1] - a[0], b), "#{label}: Thekenplatte #{a}")
  else
    check(!da.("#{n}/Theke"), "#{label}: keine Theke")
  end
  check(nahe(w.wert('y_aussen'), y_a), "#{label}: Y_Aussen #{w.wert('y_aussen')} statt #{y_a}")
end

def pruefe_material(w, label, kz)
  m = Sketchup.active_model.materials
  platte, kante = m[H::MATERIAL], m[H::KANTE]
  tm, tk = m[H::THEKE_MATERIAL], m[H::THEKE_KANTE]
  check(platte.get_attribute(H::OCL_DICT, 'type') == 2 && tm.get_attribute(H::OCL_DICT, 'type') == 2, "#{label}: Plattenwerkstoffe")
  check([kante, tk].all? { |k| k.get_attribute(H::OCL_DICT, 'type') == 4 && k.get_attribute(H::OCL_DICT, 'edge_decremented') == true },
        "#{label}: Anleimer")
  tags = []
  sammle = lambda do |k, bereich|
    k.kinder.each do |c|
      unless c.kinder.empty?
        b2 = c.name.start_with?('Schublade') ? ('A'.ord + c.name[/\d+/].to_i - 1).chr : bereich
        next sammle.(c, b2)
      end
      soll = KANTEN_SOLL.fetch(c.name.sub(/\d+\z/, '')) { raise "kein Soll für #{c.name}" }
      theke = c.name == 'Theke'
      check(c.inst.material.equal?(theke ? tm : platte), "#{label}: #{c.name} Material")
      ist = c.defn.entities.faces.select { |f| f.material.equal?(theke ? tk : kante) }.map do |f|
        H::SEITEN.find { |_, (ax, vz)| f.normal.to_a[ax] * vz > 0.5 }.first
      end
      check(ist.sort == soll.sort, "#{label}: #{c.name} Anleimer #{ist.inspect} statt #{soll.inspect}")
      jt = %w[schrank typ kategorie bereich teil rolle].to_h { |x| [x, c.inst.get_attribute(H::JT_DICT, x)] }
      check(jt['schrank'] == kz && jt['typ'] == 'Unterschrank_Insel' && jt['kategorie'] == 'Unterschrank' &&
            jt['bereich'] == bereich.to_s, "#{label}: #{c.name} JT_Schrank #{jt.inspect}")
      check(c.inst.layer&.name == [kz, bereich, jt['teil']].compact.join('_'), "#{label}: #{c.name} Tag #{c.inst.layer&.name}")
      check(H::ROLLEN.value?(jt['rolle']), "#{label}: #{c.name} Rolle #{jt['rolle'].inspect}")
      tags << c.inst.layer.name
    end
  end
  sammle.(w, nil)
  check(tags.uniq.size == tags.size, "#{label}: Tags eindeutig #{tags.tally.select { |_, v| v > 1 }}")
  %w[Verkleidung WangeL WangeR Theke A_Front D_KastenRueckwand TuerL Einlegeboden2].each do |x|
    check(tags.include?("#{kz}_#{x}"), "#{label}: Tag #{kz}_#{x} fehlt")
  end
end

LAENGEN = %w[Breite Hoehe Tiefe Sitzueberstand Hoehe_Theke Tiefe_Theke Ueberstand_Theke].freeze

def lauf(p, label, umkonf = nil, kz = 'USI1')
  Sketchup.active_model = Sketchup::Model.new
  inst = H.erstellen(p)
  p = H::DEFAULTS.merge(p)
  w = Knoten.new(inst, inst.definition, nil)
  w.redraw
  pruefe(w, p, label)
  pruefe_geometrie(w, label)
  pruefe_material(w, label, kz)
  return unless umkonf
  d = inst.definition
  umkonf.each { |k, v| d.set_attribute(H::DICT, k.downcase, LAENGEN.include?(k) ? v / 2.54 : v.to_f) }
  w2 = Knoten.new(inst, d, nil)
  w2.redraw
  pruefe(w2, p.merge(umkonf), "#{label} -> umkonfiguriert")
end

lauf({}, 'Standard (3 Schubladen, Verkleidung)', { 'Anz_Schubladen' => 4, 'Art_Wange' => 3, 'Breite' => 90.0 })
lauf({ 'Frontart' => 0.0 }, 'zwei Türen', { 'Art_Tuer' => 1, 'Anz_Einlegeboeden' => 2, 'Theke' => 1 })
lauf({ 'Frontart' => 0.0, 'Art_Tuer' => 1.0, 'Anz_Einlegeboeden' => 0.0, 'Verkleidung' => 0.0 }, 'eine Tür ohne Verkleidung',
     { 'Frontart' => 1, 'Anz_Schubladen' => 1, 'Verkleidung' => 1, 'Art_Wange' => 1 })
lauf({ 'Theke' => 1.0, 'Art_Wange' => 3.0, 'Anz_Schubladen' => 2.0 }, 'erhöhte Theke mit Wangen',
     { 'Hoehe_Theke' => 105.0, 'Tiefe_Theke' => 40.0, 'Ueberstand_Theke' => 30.0, 'Art_Wange' => 2 })
lauf({ 'Theke' => 1.0, 'Verkleidung' => 0.0 }, 'Theke erzwingt Verkleidung', { 'Theke' => 0 })
lauf({ 'Breite' => 120.0, 'Tiefe' => 52.0, 'Anz_Schubladen' => 4.0 }, '1200 x 520', { 'Hoehe' => 78.0, 'Tiefe' => 60.0 })
lauf({ 'Kuerzel' => 'USI7' }, 'eigenes Kürzel', nil, 'USI7')

# Insel-Kennzeichen und Sitzüberstand für die Arbeitsplatte
Sketchup.active_model = Sketchup::Model.new
H.erstellen({})
H.erstellen({})
md = Sketchup.active_model
d = md.definitions[H::NAME]
check(md.layers['USI2_Verkleidung'], 'zweiter Schrank USI2')
check(d.get_attribute(H::JT_DICT, 'insel') == true && d.get_attribute(H::JT_DICT, 'kategorie') == 'Unterschrank', 'JT_Schrank insel/kategorie')
check(nahe(d.get_attribute(H::DICT, 'sitzueberstand') * 2.54, 30.0), 'Sitzüberstand 300 mm')

# --- Kurzhilfe in der Komponente ------------------------------------------
check(d.description == H::HILFE_KURZ, 'Hilfe: Beschreibung der Definition')
check(d.get_attribute(H::DICT, 'summary') == H::HILFE_KURZ && d.get_attribute(H::DICT, 'description').nil?, 'Hilfe: summary/description')
check(File.exist?(File.expand_path('../README.md', __dir__)), 'README.md vorhanden')

# --- Dialog: Front und Rückseite wählbar ---
module UI
  class << self
    attr_accessor :antwort
  end
  def self.inputbox(_p, d, *_r) = (antwort || d)
end
Sketchup.active_model = Sketchup::Model.new
UI.antwort = ['800', '720', '560', 'Türen', 'Verkleidung, erhöhte Theke']
H.dialog
i = Sketchup.active_model.entities.grep(Sketchup::ComponentInstance).last
w = ->(k) { i.definition.get_attribute(H::DICT, k) }
check(nahe(w.('breite') * 2.54, 80) && nahe(w.('tiefe') * 2.54, 56) && w.('frontart') == 0.0 && w.('theke') == 1.0 && w.('verkleidung') == 1.0,
      'Dialog: Maße, Türen, erhöhte Theke')
UI.antwort = nil

# --- Tiefe nachträglich ändern (Komponentenoptionen) = gleich mit dieser Tiefe erzeugt ---
require_relative '../../../test/tiefe_helfer'
[{}, { 'Frontart' => 0.0 }, { 'Theke' => 1.0, 'Art_Wange' => 3.0 }, { 'Verkleidung' => 0.0, 'Anz_Schubladen' => 2.0 }].each do |e|
  TiefeHelfer.pruefen(Knoten, H::DICT, ->(x) { H.erstellen(x) },
                      [[80.0, 52.0], [52.0, 40.0], [52.0, 65.0], [56.0, 47.3]], e).each do |was, abw|
    check(abw.empty?, "Tiefe #{was} #{e}: " + abw.first(8).join('; '))
  end
end

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
