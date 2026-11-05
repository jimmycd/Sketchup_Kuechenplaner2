# Test ohne SketchUp: Mock-API + kleiner DC-Formel-Auswerter.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
load File.expand_path('../src/unterschrank_abfall/main.rb', __dir__)

H = UnterschrankAbfall
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
  'Rückwand' => [], 'Front' => ALLE4, 'KastenBoden' => [], 'KastenRueckwand' => %i[zmax]
}.freeze
GRUPPE_BEREICH = { 'Auszug' => 'A', 'SchubladeOben' => 'B' }.freeze

def pruefe(w, p, label)
  b, h, t = p['Breite'], p['Hoehe'], p['Tiefe']
  mk, sp, rw = 1.9, 0.2, 0.8
  oben = p['Frontvariante'].to_i == 1
  r = H.berechne(p)
  alle = teile(w)
  sichtbar = alle.reject { |t2| t2[:hidden] }
  q = ->(pfad) { (sichtbar.find { |t2| t2[:pfad] == pfad } || raise("#{label}: #{pfad} fehlt"))[:q] }
  da = ->(pfad) { sichtbar.any? { |t2| t2[:pfad] == pfad } }

  sichtbar.each do |t2|
    a = t2[:q]
    check(a[0] >= -EPS && a[1] <= b + EPS && a[4] >= -EPS && a[5] <= h + EPS && a[2] >= -sp - EPS && a[3] <= t + mk + rw + EPS,
          "#{label}: #{t2[:pfad]} außerhalb #{a.map { |v| v.round(2) }}")
  end
  # keine Kollisionen (Behälter stehen auf dem Kastenboden, berühren ihn nur)
  sichtbar.combination(2).each do |a, c|
    check(!ueberlapp?(a[:q], c[:q]), "#{label}: Kollision #{a[:pfad]} / #{c[:pfad]}")
  end

  # Korpus wie Unterschrank mit Schubladen
  n = H::NAME
  %w[SeiteL SeiteR].each { |s| check(nahe(q.("#{n}/#{s}")[5] - q.("#{n}/#{s}")[4], h) && nahe(q.("#{n}/#{s}")[3] - q.("#{n}/#{s}")[2], t), "#{label}: #{s}") }
  rq = q.("#{n}/Rückwand")
  check(nahe(rq[2], t + mk) && nahe(rq[1] - rq[0], b) && nahe(rq[5], h), "#{label}: Rückwand hinter dem Korpus #{rq}")
  check(nahe(q.("#{n}/StrebeHinten")[3], t + mk) && nahe(q.("#{n}/StrebeVorn")[5], h), "#{label}: Streben")

  nl = H.nennlaenge(t)
  check(nl + 0.3 <= t + EPS || nl == 35, "#{label}: NL #{nl} passt in die Tiefe #{t}")
  check(nahe(w.wert('nl'), nl), "#{label}: NL-Formel #{w.wert('nl')} statt #{nl}")

  # Auszug (A): Front ab Unterkante, über die volle Höhe oder bis unter die Schublade oben
  fa = q.('Auszug/Front')
  h_a = oben ? h - p['Hoehe_Front_Oben'] - sp : h
  check(nahe(fa[4], 0) && nahe(fa[5], h_a) && nahe(fa[0], sp / 2) && nahe(fa[1], b - sp / 2) && nahe(fa[2], -sp),
        "#{label}: Front Auszug #{fa}")
  kasten = lambda do |g, z_front, oberkante|
    kb, kr = q.("#{g}/KastenBoden"), q.("#{g}/KastenRueckwand")
    check(nahe(kb[3] - kb[2], nl - 1) && nahe(kb[2], mk) && nahe(kb[1] - kb[0], b - 2 * mk - 3.5), "#{label}: #{g} Kastenboden LW-35 x NL-10 #{kb}")
    check(nahe(kr[3], mk + nl - 1) && nahe(kr[1] - kr[0], b - 2 * mk - 3.8) && nahe(kr[4], kb[5]), "#{label}: #{g} Kastenrückwand #{kr}")
    rn = (kb[4] - p['Lochraster_Start']) / p['Lochraster']
    # mind. Kasten_Abstand_unten über der Front und Schiene mind. 38 mm über dem Korpusboden (LEGRABOX)
    min_ab = [z_front + p['Kasten_Abstand_unten'], mk + 3.8].max
    check(kb[4] >= min_ab - EPS && (rn - rn.round).abs < 1e-6 &&
          kb[4] < min_ab + p['Lochraster'], "#{label}: #{g} Kasten im Lochraster #{kb[4]}")
    # Zarge C (Rückwand 148), wenn der Kasten 177 mm hoch sein kann, sonst M (Rückwand 62)
    platz = oberkante - p['Kasten_Abstand_oben'] - kb[5]
    soll = (platz + kb[5] - kb[4] >= 17.7 - 1e-4 ? p['Hoehe_Kastenrueckwand'] : [platz, 6.2].min).clamp(2.0, 99)
    check(nahe(kr[5] - kr[4], soll), "#{label}: #{g} Kastenrückwand #{kr[5] - kr[4]} statt #{soll}")
    kb
  end
  kb = kasten.('Auszug', 0.0, h_a)

  # Behälter: n gleich breite nebeneinander auf dem Kastenboden, vor der Kastenrückwand
  beh = sichtbar.select { |t2| t2[:name].start_with?('Behaelter') }.sort_by { |t2| t2[:q][0] }
  anz = p['Anz_Behaelter'].to_i
  check(beh.size == anz, "#{label}: #{beh.size} Behälter statt #{anz}")
  check(nahe(beh.first[:q][0], kb[0]) && nahe(beh.last[:q][1], kb[1]), "#{label}: Behälter füllen die Kastenbreite")
  beh.each_cons(2) { |a, c| check(nahe(c[:q][0] - a[:q][1], p['Behaelter_Abstand']), "#{label}: Abstand zwischen den Behältern") }
  bw = beh.map { |x| x[:q][1] - x[:q][0] }
  check(bw.all? { |v| nahe(v, bw.first) }, "#{label}: Behälter gleich breit #{bw}")
  kr = q.('Auszug/KastenRueckwand')
  hb = [p['Behaelter_Hoehe'], h_a - p['Kasten_Abstand_oben'] - kb[5]].min.clamp(5.0, 999)
  beh.each do |x|
    check(nahe(x[:q][4], kb[5]) && nahe(x[:q][2], mk) && nahe(x[:q][3], kr[2] - p['Behaelter_Abstand']), "#{label}: Behälter Lage #{x[:q]}")
    check(nahe(x[:q][5] - x[:q][4], hb), "#{label}: Behälterhöhe #{x[:q][5] - x[:q][4]} statt #{hb}")
  end

  # Schublade oben (B)
  if oben
    fb = q.('SchubladeOben/Front')
    check(nahe(fb[5], h) && nahe(fb[4], h - p['Hoehe_Front_Oben']) && nahe(fb[4] - fa[5], sp), "#{label}: Front oben #{fb}")
    kbo = kasten.('SchubladeOben', fb[4], h)
    beh.each { |x| check(x[:q][5] <= kbo[4] + EPS, "#{label}: Behälter unter der Schublade oben") }
  else
    check(%w[Front KastenBoden KastenRueckwand].none? { |x| da.("SchubladeOben/#{x}") }, "#{label}: keine Schublade oben")
  end
end

def pruefe_ocl(w, label, kz)
  m = Sketchup.active_model.materials
  platte = m[H::MATERIAL]; kante = m[H::KANTE]; beh = m[H::BEHAELTER]
  check(platte.get_attribute(H::OCL_DICT, 'type') == 2, "#{label}: Plattenmaterial OCL-Typ")
  check(kante.get_attribute(H::OCL_DICT, 'type') == 4 && kante.get_attribute(H::OCL_DICT, 'edge_decremented') == true,
        "#{label}: Anleimer OCL")
  check(beh.get_attribute(H::OCL_DICT, 'type') == 5, "#{label}: Behälter sind in OCL Beschlag (Typ 5)")
  tags = []
  sammle = lambda do |k, bereich|
    k.kinder.each do |c|
      next sammle.(c, GRUPPE_BEREICH.fetch(c.name)) unless c.kinder.empty?
      if c.name.start_with?('Behaelter')
        check(c.inst.material.equal?(beh), "#{label}: #{c.name} Material")
        check(c.inst.attribute_dictionary(H::JT_DICT).nil?, "#{label}: #{c.name} ohne JT_Schrank (kein Werkstück)")
        tags << c.inst.layer.name
        next
      end
      soll = KANTEN_SOLL.fetch(c.name) { raise "kein Soll für #{c.name}" }
      check(c.inst.material.equal?(platte), "#{label}: #{c.name} ohne Plattenmaterial")
      ist = c.defn.entities.faces.select { |f| f.material.equal?(kante) }.map do |f|
        H::SEITEN.find { |_, (ax, vz)| f.normal.to_a[ax] * vz > 0.5 }.first
      end
      check(ist.sort == soll.sort, "#{label}: #{c.name} Anleimer #{ist.inspect} statt #{soll.inspect}")
      jt = %w[schrank typ kategorie bereich teil rolle].to_h { |x| [x, c.inst.get_attribute(H::JT_DICT, x)] }
      check(jt['schrank'] == kz && jt['typ'] == 'Unterschrank_Abfall' && jt['kategorie'] == 'Unterschrank' &&
            jt['bereich'] == bereich.to_s, "#{label}: #{c.name} JT_Schrank #{jt.inspect}")
      check(c.inst.layer&.name == [kz, bereich, jt['teil']].compact.join('_'), "#{label}: #{c.name} Tag #{c.inst.layer&.name}")
      check(H::ROLLEN.value?(jt['rolle']), "#{label}: #{c.name} Rolle #{jt['rolle'].inspect}")
      tags << c.inst.layer.name
    end
  end
  sammle.(w, nil)
  check(tags.uniq.size == tags.size, "#{label}: Tags eindeutig")
  check((%w[SeiteL SeiteR Boden StrebeVorn StrebeHinten Rueckwand A_Front A_KastenBoden A_KastenRueckwand
            B_Front B_KastenBoden B_KastenRueckwand] + (1..4).map { |i| "A_Behaelter#{i}" }).sort ==
        tags.map { |x| x.delete_prefix("#{kz}_") }.sort, "#{label}: Tag-Liste #{tags.inspect}")
end

LAENGEN = %w[Breite Hoehe Tiefe Hoehe_Front_Oben Behaelter_Hoehe].freeze

def lauf(p, label, umkonf = nil, kz = 'USM1')
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
  umkonf.each { |k, v| d.set_attribute(H::DICT, k.downcase, LAENGEN.include?(k) ? v / 2.54 : v.to_f) }
  w2 = Knoten.new(inst, d, nil)
  w2.redraw
  pruefe(w2, p.merge(umkonf), "#{label} -> umkonfiguriert")
end

lauf({}, 'Standard (ein Auszug, 3 Behälter)', { 'Frontvariante' => 1, 'Anz_Behaelter' => 2, 'Breite' => 45.0 })
lauf({ 'Frontvariante' => 1.0 }, 'Schublade oben + Auszug', { 'Frontvariante' => 0, 'Anz_Behaelter' => 4, 'Breite' => 90.0 })
lauf({ 'Frontvariante' => 1.0, 'Hoehe_Front_Oben' => 15.0, 'Anz_Behaelter' => 1.0 }, 'flache Schublade oben, 1 Behälter',
     { 'Hoehe_Front_Oben' => 25.0, 'Behaelter_Hoehe' => 30.0 })
lauf({ 'Breite' => 45.0, 'Tiefe' => 52.0, 'Anz_Behaelter' => 2.0 }, '450 x 520', { 'Hoehe' => 55.0, 'Tiefe' => 60.0 })
lauf({ 'Hoehe' => 55.0, 'Frontvariante' => 1.0 }, 'niedrig: Behälter begrenzt', { 'Behaelter_Hoehe' => 60.0 })
lauf({ 'Kuerzel' => 'USM7' }, 'eigenes Kürzel', nil, 'USM7')

# Werte der Standard-Komponente
r = H.berechne(H::DEFAULTS)
check(nahe(r[:nl], 65) && nahe(r[:ab_a], 6.7) && nahe(r[:hrw_a], 14.8) && nahe(r[:h_beh], 40), "Standard: NL 650, Kasten ab 67 mm (Schiene 38 über Boden), Behälter 400 (#{r})")
check(nahe(r[:b_beh], (60 - 3.8 - 3.5 - 2) / 3.0), "Standard: drei Behälter je #{r[:b_beh]}")
r = H.berechne(H::DEFAULTS.merge('Frontvariante' => 1.0))
check(nahe(r[:h_a], 49.8) && nahe(r[:ab_b], 54.7) && nahe(r[:hrw_b], 6.2), "Schublade oben (Zarge M): Fronten 498/200, Kasten oben ab 547 (#{r})")
check(nahe(r[:h_beh], 49.8 - 3 - 6.7 - 1.6), "Schublade oben: Behälter bis unter die Auszugsfront (#{r[:h_beh]})")
r = H.berechne(H::DEFAULTS.merge('Hoehe' => 55.0, 'Frontvariante' => 1.0))
check(nahe(r[:h_beh], 34.8 - 3 - 6.7 - 1.6), "niedrig: Behälter #{r[:h_beh]}")

# Zweiter Schrank im selben Modell bekommt USM2
Sketchup.active_model = Sketchup::Model.new
H.erstellen({})
H.erstellen({})
check(Sketchup.active_model.layers['USM2_A_Front'] && Sketchup.active_model.layers['USM2_B_Front'], 'zweiter Schrank USM2')
check(Sketchup.active_model.definitions[H::NAME].get_attribute(H::JT_DICT, 'kategorie') == 'Unterschrank', 'JT_Schrank am Schrank')
check(Sketchup.active_model.definitions[H::NAME].get_attribute(H::JT_DICT, 'typ') == 'Unterschrank_Abfall', 'Typ am Schrank')

# --- Kurzhilfe in der Komponente ------------------------------------------
hd = Sketchup.active_model.definitions[H::NAME]
check(hd.description == H::HILFE_KURZ, 'Hilfe: Beschreibung der Definition')
check(hd.get_attribute(H::DICT, 'summary') == H::HILFE_KURZ, 'Hilfe: summary')
check(hd.get_attribute(H::DICT, 'description').nil?, 'Hilfe: description')
opt = hd.get_attribute(H::DICT, '_frontvariante_options')
check(opt.include?('Ein%20Auszug%20%FCber%20die%20volle%20H%F6he=0') && opt.ascii_only?, "Optionen mit Umlauten für das DC-Fenster: #{opt}")
check(File.exist?(File.expand_path('../README.md', __dir__)), 'README.md vorhanden')

# --- Tiefe nachträglich ändern (Komponentenoptionen) = gleich mit dieser Tiefe erzeugt ---
require_relative '../../../test/tiefe_helfer'
[{}, { 'Frontvariante' => 1.0 }].each do |e|
  TiefeHelfer.pruefen(Knoten, H::DICT, ->(x) { H.erstellen(x) },
                      [[80.0, 52.0], [52.0, 40.0], [52.0, 65.0], [56.0, 47.3]], e).each do |was, abw|
    check(abw.empty?, "Tiefe #{was} #{e}: " + abw.first(8).join('; '))
  end
end

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
