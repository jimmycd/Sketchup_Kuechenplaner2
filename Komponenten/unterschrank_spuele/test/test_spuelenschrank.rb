# Test ohne SketchUp: Mock-API + kleiner DC-Formel-Auswerter.
$LOAD_PATH.unshift(__dir__)
$SPUELENSCHRANK_TEST = true
require 'sketchup_mock'
load File.expand_path('../spuelenschrank.rb', __dir__)

H = Spuelenschrank
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
      next if k.name == 'Ausschnitt' && k.hidden? # ohne Ausschnitt flacher Umriss, ausgeblendet
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
  'Rückwand' => [], 'Tür' => ALLE4, 'TürL' => ALLE4, 'TürR' => ALLE4, 'Blende' => ALLE4, 'Front' => ALLE4,
  'KastenBoden' => [], 'KastenRueckwand' => %i[zmax]
}.freeze
BEREICH = { 'Blende' => 'B', 'Front' => 'A', 'KastenBoden' => 'A', 'KastenRueckwand' => 'A' }.freeze

def pruefe(w, p, label)
  b, h, t = p['Breite'], p['Hoehe'], p['Tiefe']
  mk, sp, rw, nut = 1.9, 0.2, 0.8, 0.9
  vs, hb, sf = p['Rueckwand_Versatz'], p['Hoehe_Blende'], p['Siphon_Freiraum']
  r = H.berechne(p)
  alle = teile(w)
  sichtbar = alle.reject { |t2| t2[:hidden] }
  q = ->(n) { (sichtbar.find { |t2| t2[:name] == n } || raise("#{label}: #{n} fehlt"))[:q] }
  da = ->(n) { sichtbar.any? { |t2| t2[:name] == n } }

  alle.each do |t2|
    a = t2[:q]
    check(a[0] >= -EPS && a[1] <= b + EPS && a[4] >= -EPS && a[5] <= h + EPS && a[2] >= -sp - EPS && a[3] <= t + mk + EPS,
          "#{label}: #{t2[:pfad]} außerhalb #{a.map { |v| v.round(2) }}")
  end
  # Kollisionen; erlaubt ist nur die Rückwand in der Nut der Seiten
  nut_ok = ->(a, c) { a[:name] == 'Rückwand' && %w[SeiteL SeiteR].include?(c[:name]) }
  sichtbar.combination(2).each do |a, c|
    next if nut_ok.(a, c) || nut_ok.(c, a)
    check(!ueberlapp?(a[:q], c[:q]), "#{label}: Kollision #{a[:pfad]} / #{c[:pfad]}")
  end

  # Installationsebene: Rückwand Versatz vor der Hinterkante, in der Seitennut, auf dem Boden, oben bündig
  rq = q.('Rückwand')
  check(nahe(rq[3], mk + t - vs) && nahe(rq[3] - rq[2], rw), "#{label}: Rückwand Lage y #{rq[2..3]}")
  check(nahe(rq[0], mk - nut) && nahe(rq[1], b - mk + nut), "#{label}: Rückwand in Seitennut #{rq[0..1]}")
  check(nahe(rq[4], mk) && nahe(rq[5], h), "#{label}: Rückwand auf dem Boden, oben bündig #{rq[4..5]}")
  check(nahe(q.('Boden')[3], mk + t) && nahe(q.('Boden')[4], 0), "#{label}: Boden volle Tiefe")
  sh = q.('StrebeHinten')
  check(nahe(sh[3], rq[2]) && nahe(sh[5], h), "#{label}: Strebe hinten endet an der Rückwand #{sh}")
  check(nahe(q.('StrebeVorn')[2], mk) && nahe(q.('StrebeVorn')[5], h), "#{label}: Strebe vorn")
  %w[SeiteL SeiteR].each { |s| check(nahe(q.(s)[5] - q.(s)[4], h) && nahe(q.(s)[3] - q.(s)[2], t), "#{label}: #{s}") }
  check(sichtbar.none? { |t2| t2[:name].start_with?('Einlegeboden') }, "#{label}: keine Einlegeböden")

  # Rückwand-Ausschnitt: Attribute an der Rückwand, Umriss davor
  rk = alle.find { |t2| t2[:name] == 'Rückwand' }[:knoten]
  ax, az, ab_, ah = %w[ausschnitt_x ausschnitt_z ausschnitt_b ausschnitt_h].map { |k| rk.wert(k) }
  rand = p['Ausschnitt_Rand']
  check(nahe(rq[0] + ax, mk + rand) && nahe(rq[0] + ax + ab_, b - mk - rand), "#{label}: Ausschnitt seitlich #{ax}/#{ab_}")
  check(nahe(rq[4] + az, r[:a_unten]) && nahe(ah, r[:a_hoehe]), "#{label}: Ausschnitt Höhe #{az}/#{ah}")
  check(ah <= 0 || (rq[4] + az + ah <= h - rand + EPS && az >= rand - EPS), "#{label}: Ausschnitt mit Steg oben/unten")
  if ah > 0
    aq = q.('Ausschnitt')
    check(nahe(aq[0], rq[0] + ax) && nahe(aq[1], rq[0] + ax + ab_) && nahe(aq[4], rq[4] + az) && nahe(aq[5], rq[4] + az + ah) &&
          aq[2] < rq[2] && aq[2] > rq[2] - 0.1, "#{label}: Umriss Ausschnitt #{aq}")
  else
    check(!da.('Ausschnitt'), "#{label}: kein Umriss ohne Ausschnitt")
  end

  if p['Frontvariante'].to_i == 0
    tueren = sichtbar.select { |t2| t2[:name].start_with?('Tür') }.sort_by { |t2| t2[:q][0] }
    check(tueren.size == p['Art_Tuer'], "#{label}: #{tueren.size} Türen statt #{p['Art_Tuer']}")
    tueren.each { |t2| check(nahe(t2[:q][4], 0) && nahe(t2[:q][5], h) && nahe(t2[:q][2], -sp), "#{label}: Tür Höhe/Lage #{t2[:q]}") }
    check(nahe(tueren.first[:q][0], sp / 2) && nahe(tueren.last[:q][1], b - sp / 2), "#{label}: Türen außen #{sp / 2} Fuge")
    tueren.each_cons(2) { |a, c| check(nahe(c[:q][0] - a[:q][1], sp), "#{label}: Fuge zwischen den Türen") }
    check(%w[Blende Front KastenBoden KastenRueckwand].none? { |n| da.(n) }, "#{label}: keine Blende/kein Auszug bei Türen")
  else
    check(sichtbar.none? { |t2| t2[:name].start_with?('Tür') }, "#{label}: keine Türen bei Blende + Auszug")
    bq, fq = q.('Blende'), q.('Front')
    check(nahe(bq[5], h) && nahe(bq[4], h - hb) && nahe(bq[0], sp / 2) && nahe(bq[1], b - sp / 2) && nahe(bq[2], -sp),
          "#{label}: Blende #{bq}")
    check(nahe(fq[4], 0) && nahe(bq[4] - fq[5], sp) && nahe(fq[0], sp / 2) && nahe(fq[1], b - sp / 2), "#{label}: Front Auszug #{fq}")
    kb, kr = q.('KastenBoden'), q.('KastenRueckwand')
    nl = H.nennlaenge(t - vs - rw)
    check(nl + 0.3 <= t - vs - rw + EPS && nl >= 35, "#{label}: NL #{nl} passt vor die Rückwand")
    check(nahe(kb[3] - kb[2], nl - 1) && nahe(kb[2], mk) && nahe(kb[1] - kb[0], b - 2 * mk - 3.5), "#{label}: Kastenboden LW-35 x NL-10 #{kb}")
    check(nahe(kr[3], mk + nl - 1) && nahe(kr[1] - kr[0], b - 2 * mk - 3.8) && nahe(kr[4], kb[5]), "#{label}: Kastenrückwand #{kr}")
    n = (kb[4] - p['Lochraster_Start']) / p['Lochraster']
    check(kb[4] >= p['Kasten_Abstand_unten'] - EPS && (n - n.round).abs < 1e-6, "#{label}: Kasten im Lochraster #{kb[4]}")
    check(kr[5] <= h - hb - sf + EPS || nahe(kr[5] - kr[4], 2.0), "#{label}: Siphon-Freiraum unter der Blende (Kasten oben #{kr[5]})")
    check(nahe(kr[5] - kr[4], [p['Hoehe_Kastenrueckwand'], h - hb - sf - kb[4] - 1.6].min.clamp(2.0, 99)),
          "#{label}: Kastenrückwand so hoch wie möglich #{kr[5] - kr[4]}")
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
    if b.name == 'Ausschnitt'
      check(b.defn.entities.faces.empty? && b.defn.entities.edges.size == 4, "#{label}: Umriss nur Kanten (kein OCL-Teil)")
      check(b.inst.layer&.name == "#{kz}_Rueckwand_Ausschnitt" && b.inst.get_attribute(H::JT_DICT, 'teil').nil?,
            "#{label}: Umriss ohne JT_Schrank, eigener Tag")
      next
    end
    soll = KANTEN_SOLL.fetch(b.name) { raise "kein Soll für #{b.name}" }
    check(b.inst.material.equal?(platte), "#{label}: #{b.name} ohne Plattenmaterial")
    ist = b.defn.entities.faces.select { |f| f.material.equal?(kante) }.map do |f|
      H::SEITEN.find { |_, (ax, vz)| f.normal.to_a[ax] * vz > 0.5 }.first
    end
    check(ist.sort == soll.sort, "#{label}: #{b.name} Anleimer #{ist.inspect} statt #{soll.inspect}")
    jt = %w[schrank typ kategorie bereich teil rolle].to_h { |k| [k, b.inst.get_attribute(H::JT_DICT, k)] }
    check(jt['schrank'] == kz && jt['typ'] == 'Spuelenschrank' && jt['kategorie'] == 'Unterschrank' &&
          jt['bereich'] == BEREICH.fetch(b.name, ''), "#{label}: #{b.name} JT_Schrank #{jt.inspect}")
    check(b.inst.layer&.name == [kz, BEREICH[b.name], jt['teil']].compact.join('_'), "#{label}: #{b.name} Tag #{b.inst.layer&.name}")
    check(H::ROLLEN.value?(jt['rolle']), "#{label}: #{b.name} Rolle #{jt['rolle'].inspect}")
    tags << b.inst.layer.name
  end
  check(tags.uniq.size == tags.size, "#{label}: Tags eindeutig")
  check(%w[SeiteL SeiteR Boden StrebeVorn StrebeHinten Rueckwand Tuer TuerL TuerR B_Front A_Front A_KastenBoden
           A_KastenRueckwand].sort == tags.map { |n| n.delete_prefix("#{kz}_") }.sort, "#{label}: Tag-Liste #{tags.inspect}")
end

LAENGEN = %w[Breite Hoehe Tiefe Hoehe_Blende Siphon_Freiraum Rueckwand_Versatz Ausschnitt_Unten Ausschnitt_Hoehe Ausschnitt_Rand].freeze

def lauf(p, label, umkonf = nil, kz = 'USP1')
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

lauf({}, 'Standard (Blende + Auszug)', { 'Frontvariante' => 0, 'Art_Tuer' => 2, 'Breite' => 120.0 })
lauf({ 'Frontvariante' => 0.0 }, 'zwei Türen', { 'Frontvariante' => 1, 'Breite' => 60.0, 'Hoehe_Blende' => 15.0 })
lauf({ 'Frontvariante' => 0.0, 'Art_Tuer' => 1.0, 'Breite' => 60.0 }, 'eine Tür', { 'Art_Tuer' => 2, 'Ausschnitt_Hoehe' => 0.0 })
lauf({ 'Breite' => 60.0, 'Tiefe' => 56.0, 'Rueckwand_Versatz' => 8.0 }, 'Auszug 60 x 56', { 'Hoehe' => 55.0, 'Tiefe' => 60.0 })
lauf({ 'Hoehe' => 55.0 }, 'niedrig: Kasten unter dem Siphon-Freiraum', { 'Siphon_Freiraum' => 10.0 })
lauf({ 'Ausschnitt_Hoehe' => 0.0 }, 'ohne Ausschnitt', { 'Ausschnitt_Hoehe' => 30.0, 'Ausschnitt_Unten' => 1.0 })
lauf({ 'Ausschnitt_Hoehe' => 80.0 }, 'Ausschnitt zu hoch wird begrenzt')
lauf({ 'Kuerzel' => 'USP7' }, 'eigenes Kürzel', nil, 'USP7')

# Werte der Standard-Komponente in mm
r = H.berechne(H::DEFAULTS)
check(nahe(r[:nl], 65) && nahe(r[:t_innen], 74.2), "Standard: NL 650 bei 742 mm bis zur Rückwand (#{r[:nl]}, #{r[:t_innen]})")
check(nahe(r[:ab], 3.5) && nahe(r[:hrw], 14.8) && nahe(r[:h_auszug], 49.8), "Standard: Kasten ab 35 mm, Rückwand 148, Front 498 (#{r})")
check(nahe(r[:a_unten], 25) && nahe(r[:a_hoehe], 40) && nahe(r[:a_breite], 66.2), "Standard: Ausschnitt 662 x 400 ab 250 mm (#{r})")
r = H.berechne(H::DEFAULTS.merge('Hoehe' => 55.0))
check(nahe(r[:hrw], 15 - 3.5 - 1.6), "niedrig: Kastenrückwand #{r[:hrw]} (Oberkante 150 mm)")

# Zweiter Schrank im selben Modell bekommt USP2
Sketchup.active_model = Sketchup::Model.new
H.erstellen({})
H.erstellen({})
check(Sketchup.active_model.layers['USP2_A_Front'] && Sketchup.active_model.layers['USP2_TuerR'], 'zweiter Schrank USP2')
check(Sketchup.active_model.definitions[H::NAME].get_attribute(H::JT_DICT, 'kategorie') == 'Unterschrank', 'JT_Schrank am Schrank')

# --- Kurzhilfe in der Komponente ------------------------------------------
hd = Sketchup.active_model.definitions[H::NAME]
check(hd.description == H::HILFE_KURZ, 'Hilfe: Beschreibung der Definition')
check(hd.get_attribute(H::DICT, 'summary') == H::HILFE_KURZ, 'Hilfe: summary')
check(hd.get_attribute(H::DICT, 'description') == H::HILFE, 'Hilfe: description')
check(H::HILFE.include?(H::DOKU_URL), 'Hilfe: Link zur Doku')
check(File.exist?(File.expand_path('../README.md', __dir__)), 'README.md vorhanden')

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
