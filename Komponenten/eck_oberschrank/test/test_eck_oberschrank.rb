# Test ohne SketchUp: Mock-API + kleiner DC-Formel-Auswerter.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
load File.expand_path('../src/eck_oberschrank/main.rb', __dir__)

E = EckOberschrank
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

  def name = inst&.get_attribute(E::DICT, '_name') || defn.get_attribute(E::DICT, '_name')

  def roh(attr)
    k = attr.downcase
    return @werte[k] if @werte.key?(k)
    v = inst&.get_attribute(E::DICT, k)
    v = defn.get_attribute(E::DICT, k) if v.nil?
    v = inst.transformation.origin[%w[x y z].index(k)] if v.nil? && inst && %w[x y z].include?(k)
    raise "Attribut #{attr} fehlt an #{name}" if v.nil?
    fu = defn.get_attribute(E::DICT, "_#{k}_formulaunits")
    %w[x y z lenx leny lenz].include?(k) || fu == 'CENTIMETERS' ? v * 2.54 : v
  end

  def formel(k) = inst&.get_attribute(E::DICT, "_#{k}_formula") || defn.get_attribute(E::DICT, "_#{k}_formula")

  def ref(n, attr)
    ziel = parent && parent.name == n ? parent : (parent ? parent.kinder : []).find { |s| s.name == n }
    raise "Referenz #{n}!#{attr} von #{name} nicht auflösbar" unless ziel
    ziel.roh(attr)
  end

  def IF(c, a, b) = c ? a : b
  def AND(*a) = a.all?
  def OR(*a) = a.any?
  def MAX(*a) = a.max
  def MIN(*a) = a.min

  def auswerten(f)
    ruby = f.gsub(/(?<![<>=!])=(?!=)/, '==').gsub(/(\w+)!(\w+)|\b([A-Za-z_]\w*)\b(?!\s*\()/) do
      $1 ? "ref(#{$1.inspect},#{$2.inspect})" : "roh(#{$3.inspect})"
    end
    v = instance_eval(ruby)
    v == true ? 1.0 : (v == false ? 0.0 : v.to_f)
  end

  def schluessel
    keys = (defn.attribute_dictionary(E::DICT)&.keys || []) + (inst&.attribute_dictionary(E::DICT)&.keys || [])
    keys.grep(/\A_(.+)_formula\z/) { $1 }.uniq.sort
  end

  # Attribute in Abhängigkeitsreihenfolge (einfach: mehrfach auswerten)
  def redraw
    3.times { schluessel.each { |k| @werte[k] = auswerten(formel(k)) } }
    kinder.each(&:redraw)
  end

  def wert(k) = roh(k)
  def finde(n) = kinder.find { |c| c.name == n } || raise("#{n} fehlt")
  def hidden? = (defn.get_attribute(E::DICT, '_hidden_formula') ? wert('hidden') > 0.5 : false)
  def pos(ax) = (formel(ax) ? wert(ax) : inst.transformation.origin[%w[x y z].index(ax)] * 2.54)
end

# Absolute Quader [x0,x1,y0,y1,z0,z1] aller Blatt-Teile, mit Sichtbarkeit
def teile(k, off = [0, 0, 0], versteckt = false, out = [])
  k.kinder.each do |c|
    o = off.each_with_index.map { |v, i| v + c.pos(%w[x y z][i]) }
    vs = versteckt || c.hidden?
    if c.kinder.empty?
      l = %w[lenx leny lenz].map { |a| c.formel(a) ? c.wert(a) : c.defn.box[%w[lenx leny lenz].index(a)] * 2.54 }
      out << { name: c.name, knoten: c, pfad: "#{k.name}/#{c.name}", q: [o[0], o[0] + l[0], o[1], o[1] + l[1], o[2], o[2] + l[2]], hidden: vs }
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

MK, SP, RW, V, NUT, RV = 1.9, 0.2, 0.8, 2.5, 0.9, 1.0
HI = V + RW # Wand -> Vorderseite Rückwand

TAGS = %w[SeiteL SeiteR Boden Deckel Rueckwand1 Rueckwand2 Einlegeboden1 Einlegeboden2
          Auflageleiste1 Auflageleiste2 TuerL TuerR].freeze
KANTEN_SOLL = {
  'SeiteR' => %i[ymin zmin zmax], 'SeiteL' => %i[xmax zmin zmax], 'Boden' => [], 'Deckel' => [],
  'Rückwand1' => [], 'Rückwand2' => [], 'Einlegeboden1' => [], 'Einlegeboden2' => [],
  'Auflageleiste1' => %i[ymin xmax], 'Auflageleiste2' => %i[ymin xmax],
  'TürR' => %i[xmin xmax zmin zmax], 'TürL' => %i[ymin ymax zmin zmax]
}.freeze

# Ausgefräste Innenecke einer L-Platte als Rechteck [x0, x1, y0, y1] (absolut)
def ecke(t2)
  d = t2[:knoten].defn
  ex = d.get_attribute(E::DICT, 'ecke_x') or return
  [t2[:q][0] + ex * 2.54, t2[:q][1], t2[:q][2], t2[:q][2] + d.get_attribute(E::DICT, 'ecke_y') * 2.54]
end

# Rückwand steckt in der Nut von Seite und Boden: Überlappung höchstens Nuttiefe × Rückwandstärke
def in_nut?(s1, s2)
  rw, o = [[s1, s2], [s2, s1]].find { |r, _| r[:name].start_with?('Rückwand') } || (return false)
  return false unless o[:name].start_with?('Seite', 'Boden')
  ue = (0..2).map { |i| [rw[:q][2 * i + 1], o[:q][2 * i + 1]].min - [rw[:q][2 * i], o[:q][2 * i]].max }
  ue.sort.first(2).zip([RW, NUT].sort).all? { |x, m| x <= m + EPS }
end

def pruefe(w, p, label)
  a, bb, h, t = p['Schenkel_A'], p['Schenkel_B'], p['Hoehe'], p['Tiefe']
  yw = MK + t
  ye = yw - bb + MK
  alle = teile(w)
  sichtbar = alle.reject { |t2| t2[:hidden] }
  q = ->(n) { (sichtbar.find { |t2| t2[:name] == n } || raise("#{label}: #{n} fehlt/ausgeblendet"))[:q] }

  # Außenmaße: Schenkel A an der Wand hinten (y = yw), Schenkel B an der Wand links (x = 0), Tür davor
  sichtbar.each do |t2|
    q2 = t2[:q]
    check(q2[0] >= -EPS && q2[1] <= a + EPS && q2[2] >= yw - bb - EPS && q2[3] <= yw + EPS && q2[4] >= -EPS && q2[5] <= h + EPS,
          "#{label}: #{t2[:pfad]} außerhalb #{q2.map { |x| x.round(2) }}")
  end
  # Kollisionen: L-Platten nur außerhalb ihrer Innenecke, Rückwände nur in der Nut
  sichtbar.combination(2).each do |s1, s2|
    next unless ueberlapp?(s1[:q], s2[:q])
    frei = in_nut?(s1, s2) || [[s1, s2], [s2, s1]].any? do |l, o|
      (n = ecke(l)) && [l[:q][0], o[:q][0]].max >= n[0] - EPS && [l[:q][1], o[:q][1]].min <= n[1] + EPS &&
        [l[:q][2], o[:q][2]].max >= n[2] - EPS && [l[:q][3], o[:q][3]].min <= n[3] + EPS
    end
    check(frei, "#{label}: Kollision #{s1[:pfad]} / #{s2[:pfad]}")
  end

  # Seiten an den Schenkelenden, volle Höhe und Tiefe
  sr, sl = q.('SeiteR'), q.('SeiteL')
  check(nahe(sr[1], a) && nahe(sr[2], MK) && nahe(sr[3], yw) && nahe(sr[5], h), "#{label}: Seite Ende A #{sr}")
  check(nahe(sl[0], 0) && nahe(sl[1], t) && nahe(sl[2], yw - bb) && nahe(sl[5], h), "#{label}: Seite Ende B #{sl}")
  # Boden über die volle Tiefe, Innenecke an der Korpusvorderkante
  bd = alle.find { |t2| t2[:name] == 'Boden' }
  n = ecke(bd)
  check(nahe(bd[:q][0], 0) && nahe(bd[:q][1], a - MK) && nahe(bd[:q][2], ye) && nahe(bd[:q][3], yw) && nahe(bd[:q][5], MK),
        "#{label}: L-Boden zwischen den Seiten #{bd[:q]}")
  check(nahe(n[0], t) && nahe(n[3], MK), "#{label}: Innenecke Boden #{n}")
  # Rückwände 25 mm vor der Wand, A durch die Ecke, B stößt an; unten in der Nut des Bodens, oben bündig
  ra, rb = q.('Rückwand1'), q.('Rückwand2')
  check(nahe(ra[3], yw - V) && nahe(ra[2], yw - HI) && nahe(ra[0], V) && nahe(ra[1], a - MK + NUT), "#{label}: Rückwand A #{ra}")
  check(nahe(rb[0], V) && nahe(rb[1], HI) && nahe(rb[3], ra[2]) && nahe(rb[2], ye - NUT), "#{label}: Rückwand B stößt an A #{rb}")
  check([ra, rb].all? { |r| nahe(r[4], MK - NUT) && nahe(r[5], h) }, "#{label}: Rückwände in der Bodennut, oben bündig")
  # Deckel vor den Rückwänden, oben
  dk = alle.find { |t2| t2[:name] == 'Deckel' }
  nd = ecke(dk)
  check(nahe(dk[:q][0], HI) && nahe(dk[:q][3], yw - HI) && nahe(dk[:q][1], a - MK) && nahe(dk[:q][2], ye) && nahe(dk[:q][5], h),
        "#{label}: Deckel vor den Rückwänden #{dk[:q]}")
  check(nahe(nd[0], t) && nahe(nd[3], MK), "#{label}: Innenecke Deckel #{nd}")
  # Falttür: A vor Schenkel A durch die Ecke, B vor Schenkel B bis 1 mm vor Tür A; 1 mm Fuge oben/unten
  ta, tbq = q.('TürR'), q.('TürL')
  check(nahe(ta[2], -SP) && nahe(ta[3], MK - SP) && nahe(ta[0], t + SP) && nahe(ta[1], a - SP / 2), "#{label}: Tür A #{ta}")
  check(nahe(tbq[0], t + SP) && nahe(tbq[1], t + SP + MK) && nahe(tbq[2], yw - bb + SP / 2) && nahe(tbq[3], -1.5 * SP),
        "#{label}: Tür B #{tbq}")
  check([ta, tbq].all? { |x| nahe(x[4], SP / 2) && nahe(x[5], h - SP / 2) }, "#{label}: Türen 1 mm Fuge oben und unten")
  # Einlegeböden gleichmäßig verteilt, vorn 10 mm zurück, hinten an den Rückwänden; Leiste darunter an Rückwand A
  k = p['Anz_Einlegeboeden'].to_i
  eb = sichtbar.select { |t2| t2[:name].start_with?('Einlegeboden') }
  ls = sichtbar.select { |t2| t2[:name].start_with?('Auflageleiste') }
  check(eb.size == k && ls.size == k, "#{label}: #{eb.size} Einlegeböden / #{ls.size} Leisten statt #{k}")
  eb.each_with_index do |t2, i|
    z = MK + (h - 2 * MK) * (i + 1) / (k + 1) - MK / 2
    ne = ecke(t2)
    check(nahe(t2[:q][4], z) && nahe(t2[:q][0], HI) && nahe(t2[:q][3], yw - HI) && nahe(ne[0], t - RV) && nahe(ne[3], MK + RV),
          "#{label}: #{t2[:name]} #{t2[:q]} Ecke #{ne}")
    l = ls[i][:q]
    check(nahe(l[5], z) && nahe(l[3], yw - HI) && nahe(l[0], HI), "#{label}: Auflageleiste #{i + 1} unter dem Boden an der Rückwand #{l}")
  end
end

def lauf(p, label, umkonf = nil, kz = 'OES1')
  Sketchup.active_model = Sketchup::Model.new
  inst = E.erstellen(p)
  p = E::DEFAULTS.merge(p)
  w = Knoten.new(inst, inst.definition, nil)
  w.redraw
  pruefe(w, p, label)
  pruefe_geometrie(w, label)
  pruefe_material(w, label, kz)
  d = inst.definition
  check(%w[schenkel_a schenkel_b tiefe hoehe].all? { |x| d.get_attribute(E::DICT, "_#{x}_access") == 'TEXTBOX' }, "#{label}: Maße änderbar")
  check(d.get_attribute(E::JT_DICT, 'schrank') == kz && d.get_attribute(E::JT_DICT, 'kategorie') == 'Oberschrank', "#{label}: JT_Schrank am Schrank")
  return unless umkonf
  umkonf.each { |k, v| d.set_attribute(E::DICT, k.downcase, k == 'Hoehe' ? v / 2.54 : v.to_f) }
  w2 = Knoten.new(inst, d, nil)
  w2.redraw
  pruefe(w2, p.merge(umkonf), "#{label} -> umkonfiguriert")
end

def pruefe_material(w, label, kz)
  m = Sketchup.active_model.materials
  platte = m[E::MATERIAL]; kante = m[E::KANTE]
  check(platte.get_attribute(E::MAT_DICT, 'type') == 2, "#{label}: Plattenmaterial")
  check(kante.get_attribute(E::MAT_DICT, 'type') == 4 && kante.get_attribute(E::MAT_DICT, 'edge_decremented') == true, "#{label}: Anleimer")
  tags = []
  blaetter(w).each do |b|
    soll = KANTEN_SOLL.fetch(b.name) { raise "kein Soll für #{b.name}" }
    ist = b.defn.entities.faces.select { |f| f.material.equal?(kante) }.map do |f|
      E::SEITEN.find { |_, (ax, vz)| f.normal.to_a[ax] * vz > 0.5 }.first
    end
    check(ist.sort == soll.sort, "#{label}: #{b.name} Anleimer #{ist.inspect} statt #{soll.inspect}")
    tags << b.inst.layer.name
    check(b.inst.material.equal?(platte), "#{label}: #{b.name} ohne Plattenmaterial")
    jt = %w[schrank typ kategorie bereich teil rolle].to_h { |k| [k, b.inst.get_attribute(E::JT_DICT, k)] }
    check(jt['schrank'] == kz && jt['typ'] == 'Eckschrank' && jt['kategorie'] == 'Oberschrank' && jt['bereich'] == '',
          "#{label}: #{b.name} JT_Schrank #{jt.inspect}")
    check(b.inst.layer&.name == "#{kz}_#{jt['teil']}", "#{label}: #{b.name} Tag #{b.inst.layer&.name}")
    check(E::ROLLEN.value?(jt['rolle']), "#{label}: #{b.name} Rolle #{jt['rolle'].inspect}")
  end
  check(tags.uniq.size == tags.size, "#{label}: Tags eindeutig #{tags}")
  check(TAGS.sort == tags.map { |n| n.delete_prefix("#{kz}_") }.sort, "#{label}: Tag-Liste #{tags.inspect}")
end

lauf({}, 'Standard 650 x 650, Tiefe 350', { 'Hoehe' => 90.0, 'Anz_Einlegeboeden' => 2 })
lauf({ 'Schenkel_A' => 90.0, 'Schenkel_B' => 60.0, 'Tiefe' => 32.0, 'Hoehe' => 72.0, 'Anz_Einlegeboeden' => 0.0 }, '900 x 600, Tiefe 320',
     { 'Anz_Einlegeboeden' => 1 })
lauf({ 'Anz_Einlegeboeden' => 2.0, 'Kuerzel' => 'OES7' }, 'eigenes Kürzel, zwei Einlegeböden', nil, 'OES7')
[{ 'Schenkel_B' => 50.0 }, { 'Schenkel_A' => 50.0 }, { 'Tiefe' => 15.0 }].each do |falsch|
  Sketchup.active_model = Sketchup::Model.new
  E.erstellen(falsch)
  check(false, "abgelehnt: #{falsch}")
rescue ArgumentError
end

# Schenkel und Tiefe im Fenster Komponentenoptionen ändern (die DC schreibt an die Instanz):
# l_pruefen baut den Schrank neu auf; Kürzel, Höhe, Einlegeböden, Frontmaterial und Griffe bleiben
m = Sketchup.active_model = Sketchup::Model.new
inst = E.erstellen({ 'Hoehe' => 78.0, 'Anz_Einlegeboeden' => 2.0 })
alt = inst.definition
front = m.materials.add('Front Eiche 19mm')
tuer = alt.entities.instances.find { |c| c.name == 'TürR' }
tuer.material = front
tuer.set_attribute(E::JT_DICT, 'griff_lochmass', 160.0)
E.l_pruefen(m)
check(inst.definition.equal?(alt), 'ändern: ohne Änderung kein Neuaufbau')
neu_p = { 'Schenkel_A' => 100.0, 'Schenkel_B' => 80.0, 'Tiefe' => 40.0 }
neu_p.each { |k, v| inst.set_attribute(E::DICT, k.downcase, v / 2.54) }
E.l_pruefen(m)
check(!inst.definition.equal?(alt) && m.definitions.to_a.none? { |d| d.equal?(alt) }, 'ändern: neu aufgebaut, alte Definition entfernt')
check(inst.definition.get_attribute(E::L_DICT, E::L_GEBAUT) == [100.0, 80.0, 40.0], 'ändern: neue Maße gemerkt')
w = Knoten.new(inst, inst.definition, nil)
w.redraw
pl = E::DEFAULTS.merge(neu_p).merge('Hoehe' => 78.0, 'Anz_Einlegeboeden' => 2)
pruefe(w, pl, 'geändert 1000 x 800, Tiefe 400')
pruefe_geometrie(w, 'geändert')
tags = inst.definition.entities.instances.map { |c| c.layer.name }.sort
check(tags == TAGS.map { |t| "OES1_#{t}" }.sort, "ändern: gleiches Kürzel, alle Tags: #{tags}")
tuer = inst.definition.entities.instances.find { |c| c.name == 'TürR' }
check(tuer.material.equal?(front) && tuer.get_attribute(E::JT_DICT, 'griff_lochmass') == 160.0, 'ändern: Frontmaterial und Griff bleiben')
E.l_pruefen(m)
check(inst.definition.get_attribute(E::L_DICT, E::L_GEBAUT) == [100.0, 80.0, 40.0], 'ändern: zweites Prüfen ändert nichts')
vorher = inst.definition
inst.set_attribute(E::DICT, 'schenkel_b', 50.0 / 2.54)
E.l_pruefen(m)
check(inst.definition.equal?(vorher) && nahe(inst.get_attribute(E::DICT, 'schenkel_b') * 2.54, 80.0), 'ändern: zu kurzer Schenkel abgelehnt, alter Wert zurück')

# Zweiter Schrank im selben Modell bekommt OES2
Sketchup.active_model = Sketchup::Model.new
E.erstellen({})
E.erstellen({})
check(Sketchup.active_model.layers['OES1_Boden'] && Sketchup.active_model.layers['OES2_TuerL'], 'zweiter Schrank OES2')

# --- Kurzhilfe in der Komponente ------------------------------------------
hd = Sketchup.active_model.definitions['Eck-Oberschrank L-Form']
check(hd.description == E::HILFE_KURZ, 'Hilfe: Beschreibung der Definition')
check(hd.get_attribute(E::DICT, 'summary') == E::HILFE_KURZ && hd.get_attribute(E::DICT, 'description').nil?, 'Hilfe: summary/description')
check(%w[summary description].none? { |k| hd.get_attribute(E::DICT, "_#{k}_access") }, 'Hilfe: keine eigenen Zeilen in den Optionen')
check(!E::HILFE_KURZ.include?('OpenCutList'), 'Hilfe: kein OpenCutList mehr')
check(File.exist?(File.expand_path('../README.md', __dir__)), 'README.md vorhanden')

# --- Tiefe nachträglich ändern = gleich mit dieser Tiefe erzeugt ---
# (L-Form: über den Neuaufbau statt per Formel; Vergleich wie test/tiefe_helfer.rb)
require_relative '../../../test/tiefe_helfer'
[[35.0, 30.0], [35.0, 45.0], [40.0, 32.0]].each do |t0, t1|
  m = Sketchup.active_model = Sketchup::Model.new
  i1 = E.erstellen({ 'Tiefe' => t0, 'Anz_Einlegeboeden' => 2.0 })
  i1.set_attribute(E::DICT, 'tiefe', t1 / 2.54)
  E.l_pruefen(m)
  g = Knoten.new(i1, i1.definition, nil)
  g.redraw
  Sketchup.active_model = Sketchup::Model.new
  i2 = E.erstellen({ 'Tiefe' => t1, 'Anz_Einlegeboeden' => 2.0 })
  n2 = Knoten.new(i2, i2.definition, nil)
  n2.redraw
  abw = TiefeHelfer.abweichungen(g, n2, %w[z_einlegeboden_1 z_einlegeboden_2])
  check(abw.empty?, "Tiefe #{t0} -> #{t1}: " + abw.first(8).join('; '))
end
Sketchup.active_model = Sketchup::Model.new
i0 = E.erstellen({})
bez = TiefeHelfer.bezuege_auf_eigene_formeln(Knoten.new(i0, i0.definition, nil))
check(bez.empty?, "Formeln auf Formeln desselben Bauteils: #{bez}")

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
