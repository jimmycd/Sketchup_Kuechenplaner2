# Test ohne SketchUp: Mock-API + kleiner DC-Formel-Auswerter.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
load File.expand_path('../src/oberschrank_klappe/main.rb', __dir__)

H = OberschrankKlappe
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
  'Rückwand' => [], 'Klappe' => %i[xmin xmax zmin zmax], 'KlappeO' => %i[xmin xmax zmin zmax], 'KlappeU' => %i[xmin xmax zmin zmax]
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

  # Klappe(n): HK-top eine, HF zwei gleich hohe Teile; außen 1 mm, dazwischen 2 mm Fuge, 2 mm vor dem Korpus
  kl = sichtbar.select { |t2| t2[:name].start_with?('Klappe') }.sort_by { |t2| -t2[:q][4] }
  soll_n = p['Art_Klappe'].to_i == 2 ? 2 : 1
  check(kl.size == soll_n, "#{label}: #{kl.size} Klappenteile statt #{soll_n} (#{kl.map { |k| k[:name] }})")
  check(kl.map { |k| k[:name] } == (soll_n == 1 ? ['Klappe'] : %w[KlappeO KlappeU]), "#{label}: Klappennamen #{kl.map { |k| k[:name] }}")
  kl.each do |k|
    check(nahe(k[:q][0], sp / 2) && nahe(k[:q][1], b - sp / 2) && nahe(k[:q][2], -sp) && nahe(k[:q][3], -sp + mk),
          "#{label}: #{k[:name]} Breite/Lage #{k[:q]}")
  end
  unless kl.empty?
    check(nahe(kl.first[:q][5], h - sp / 2) && nahe(kl.last[:q][4], sp / 2), "#{label}: Klappe oben/unten 1 mm Fuge")
    kl.each_cons(2) { |a, c| check(nahe(a[:q][4] - c[:q][5], sp), "#{label}: Fuge zwischen den Klappenteilen") }
    kl.each_cons(2) { |a, c| check(nahe(a[:q][5] - a[:q][4], c[:q][5] - c[:q][4]), "#{label}: HF-Teile gleich hoch") }
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
    check(jt['schrank'] == kz && jt['typ'] == 'Oberschrank_Klappe' && jt['kategorie'] == 'Oberschrank' && jt['bereich'] == '',
          "#{label}: #{b.name} JT_Schrank #{jt.inspect}")
    check(b.inst.layer&.name == "#{kz}_#{jt['teil']}", "#{label}: #{b.name} Tag #{b.inst.layer&.name}")
    check(H::ROLLEN.value?(jt['rolle']), "#{label}: #{b.name} Rolle #{jt['rolle'].inspect}")
    tags << b.inst.layer.name
  end
  check(tags.uniq.size == tags.size, "#{label}: Tags eindeutig")
  check((%w[SeiteL SeiteR Boden Deckel Rueckwand Klappe KlappeO KlappeU] + (1..2).map { |k| "Einlegeboden#{k}" }).sort ==
        tags.map { |n| n.delete_prefix("#{kz}_") }.sort, "#{label}: Tag-Liste #{tags.inspect}")
end

def lauf(p, label, umkonf = nil, kz = 'OK1')
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

lauf({}, 'Standard (HK-top)', { 'Art_Klappe' => 2, 'Anz_Einlegeboeden' => 2, 'Breite' => 60.0, 'Hoehe' => 72.0 })
lauf({ 'Hoehe' => 72.0, 'Art_Klappe' => 2.0, 'Anz_Einlegeboeden' => 1.0 }, 'HF', { 'Art_Klappe' => 1, 'Anz_Einlegeboeden' => 0, 'Hoehe' => 35.0 })
lauf({ 'Breite' => 120.0, 'Hoehe' => 90.0, 'Art_Klappe' => 2.0, 'Tiefe' => 32.0 }, 'HF breit', { 'Tiefe' => 35.0, 'Breite' => 80.0 })
lauf({ 'Art_Klappe' => 3.0, 'Hoehe' => 50.0 }, 'Free Slim', { 'Art_Klappe' => 2, 'Hoehe' => 72.0 })
lauf({ 'Art_Klappe' => 2.0, 'Hoehe' => 72.0 }, 'HF -> Free Slim', { 'Art_Klappe' => 3, 'Hoehe' => 45.0 })
lauf({ 'Kuerzel' => 'OK7' }, 'eigenes Kürzel', nil, 'OK7')

# Zweiter Schrank im selben Modell bekommt OK2
Sketchup.active_model = Sketchup::Model.new
H.erstellen({})
H.erstellen({})
check(Sketchup.active_model.layers['OK2_Klappe'], 'zweiter Schrank OK2')
jd = Sketchup.active_model.definitions[H::NAME]
check(jd.get_attribute(H::JT_DICT, 'kategorie') == 'Oberschrank', 'JT_Schrank am Schrank: kategorie Oberschrank (Andocken)')
check(jd.get_attribute(H::JT_DICT, 'beschlag') == 'AVENTOS HK-top', 'JT_Schrank am Schrank: Beschlag')
check(jd.get_attribute(H::DICT, '_art_klappe_access') == 'NONE', 'Klappenart nicht in den Komponentenoptionen (Beschlag gilt für die ganze Küche)')
check(H.klappe_hinweis(90.0, 40.0).nil?, 'ohne Plugin kein Hinweis zum Klappenbeschlag')

# Klappe öffnet mit Interagieren nach vorne oben (Drehung um x an der Oberkante)
['Klappe Halter', 'Klappe oben Halter'].each do |n|
  d = Sketchup.active_model.definitions[n]
  check(d && d.get_attribute(H::DICT, 'onclick').to_s.start_with?('ANIMATE("ROTX",0,-'), "#{n}: öffnet nach oben")
end
check(Sketchup.active_model.definitions['Klappe unten Halter'].get_attribute(H::DICT, 'onclick').include?('ROTX'), 'HF unten faltet')

# Hinweis zur Korpushöhe
check(H.hinweis(1, 40.0).nil? && H.hinweis(2, 72.0).nil?, 'Hinweis: passende Höhen ohne Meldung')
check(H.hinweis(1, 72.0).to_s.include?('HK-top') && H.hinweis(2, 30.0).to_s.include?('HF'), 'Hinweis: unpassende Höhen gemeldet')
check(H.hinweis(3, 50.0).nil? && H.hinweis(3, 72.0).to_s.include?('Free Slim'), 'Hinweis: Free Slim bis 650 mm')

# Rollen: Klappenteile zählen als Front (Frontfarbe, Griffe, Stückliste)
%w[Klappe KlappeO KlappeU].each { |t| check(H::ROLLEN[t] == 'Front', "Rolle #{t}") }

# --- Kurzhilfe in der Komponente ------------------------------------------
hd = Sketchup.active_model.definitions[H::NAME]
check(hd.description == H::HILFE_KURZ, 'Hilfe: Beschreibung der Definition')
check(hd.get_attribute(H::DICT, 'summary') == H::HILFE_KURZ, 'Hilfe: summary')
check(hd.get_attribute(H::DICT, 'description').nil?, 'Hilfe: description')
check(File.exist?(File.expand_path('../README.md', __dir__)), 'README.md vorhanden')


# --- Tiefe nachträglich ändern (Komponentenoptionen) = gleich mit dieser Tiefe erzeugt ---
require_relative '../../../test/tiefe_helfer'
[{}, { 'Art_Klappe' => 2.0, 'Hoehe' => 72.0, 'Anz_Einlegeboeden' => 2.0 }].flat_map do |ein|
  TiefeHelfer.pruefen(Knoten, H::DICT, ->(e) { H.erstellen(e) },
                      [[80.0, 52.0], [52.0, 40.0], [52.0, 65.0], [56.0, 47.3]], ein).to_a
end.each do |was, abw|
  check(abw.empty?, "Tiefe #{was}: " + abw.first(8).join('; '))
end


# --- Grifflose Front (Schrank-CNC setzt Griff_Boden / Griff_Front und zeichnet neu) ---
[[1.0, 40.0], [2.0, 72.0]].each do |art, hoehe|
  [false, true].each do |nachher|
    [{ 'Griff_Boden' => 3.0 }, { 'Griff_Front' => 2.5 }].each do |werte|
      label = "Griff #{werte.keys.first} Art #{art.to_i}#{' nachträglich' if nachher}"
      Sketchup.active_model = Sketchup::Model.new
      basis = { 'Art_Klappe' => art, 'Hoehe' => hoehe, 'Anz_Einlegeboeden' => 1.0 }
      inst = H.erstellen(nachher ? basis : basis.merge(werte))
      d = inst.definition
      werte.each { |k, v| d.set_attribute(H::DICT, k.downcase, v / 2.54) } if nachher
      w = Knoten.new(inst, d, nil)
      w.redraw
      pruefe_geometrie(w, label) unless nachher
      sichtbar = teile(w).reject { |t2| t2[:hidden] }
      q = ->(n) { sichtbar.find { |t2| t2[:name] == n }[:q] }
      gb, gf = werte.fetch('Griff_Boden', 0.0), werte.fetch('Griff_Front', 0.0)
      check(nahe(q.('Boden')[4], gb), "#{label}: Boden z #{q.('Boden')[4]}")
      check(nahe(q.('Rückwand')[4], gb + 1.0) && nahe(q.('Rückwand')[5], hoehe), "#{label}: Rückwand #{q.('Rückwand')[4..5]}")
      unten = art == 2 ? 'KlappeU' : 'Klappe'
      check(nahe(q.(unten)[4], 0.1 + gf), "#{label}: #{unten} unten #{q.(unten)[4]}")
      oben = art == 2 ? q.('KlappeO') : q.('Klappe')
      check(nahe(oben[5], hoehe - 0.1), "#{label}: Klappe oben bleibt #{oben[5]}")
      check(nahe(q.('KlappeO')[4] - q.('KlappeU')[5], 0.2), "#{label}: Fuge Faltklappe") if art == 2
      eb = sichtbar.find { |t2| t2[:name].start_with?('Einlegeboden') }
      check(nahe(eb[:q][4] + 0.95, gb + 1.9 + (hoehe - 3.8 - gb) / 2), "#{label}: Einlegeboden mittig")
    end
  end
end

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
