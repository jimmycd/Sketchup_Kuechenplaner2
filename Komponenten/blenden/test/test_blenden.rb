# Test ohne SketchUp: Mock-API + kleiner DC-Formel-Auswerter.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
load File.expand_path('../src/blenden/main.rb', __dir__)

B = Blenden
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

  def name = inst&.get_attribute(B::DICT, '_name') || defn.get_attribute(B::DICT, '_name')

  def roh(attr)
    k = attr.downcase
    return @werte[k] if @werte.key?(k)
    v = inst&.get_attribute(B::DICT, k)
    v = defn.get_attribute(B::DICT, k) if v.nil?
    v = inst.transformation.origin[%w[x y z].index(k)] if v.nil? && inst && %w[x y z].include?(k)
    raise "Attribut #{attr} fehlt an #{name}" if v.nil?
    fu = defn.get_attribute(B::DICT, "_#{k}_formulaunits")
    %w[x y z lenx leny lenz].include?(k) || fu == 'CENTIMETERS' ? v * 2.54 : v
  end

  def formel(k) = inst&.get_attribute(B::DICT, "_#{k}_formula") || defn.get_attribute(B::DICT, "_#{k}_formula")

  def ref(n, attr)
    ziel = parent && parent.name == n ? parent : (parent ? parent.kinder : []).find { |s| s.name == n }
    raise "Referenz #{n}!#{attr} von #{name} nicht auflösbar" unless ziel
    ziel.roh(attr)
  end

  def IF(c, a, b) = c ? a : b
  def AND(*a) = a.all?
  def OR(*a) = a.any?
  def CEILING(x, s) = (x / s - 1e-9).ceil * s

  def auswerten(f)
    ruby = f.gsub(/(?<![<>=!])=(?!=)/, '==').gsub(/(\w+)!(\w+)|\b([A-Za-z_]\w*)\b(?!\s*\()/) do
      $1 ? "ref(#{$1.inspect},#{$2.inspect})" : "roh(#{$3.inspect})"
    end
    v = instance_eval(ruby)
    v == true ? 1.0 : (v == false ? 0.0 : v.to_f)
  end

  def schluessel
    keys = (defn.attribute_dictionary(B::DICT)&.keys || []) + (inst&.attribute_dictionary(B::DICT)&.keys || [])
    keys.grep(/\A_(.+)_formula\z/) { $1 }.uniq.sort
  end

  def redraw
    schluessel.each { |k| @werte[k] = auswerten(formel(k)) }
    kinder.each(&:redraw)
  end

  def wert(k) = roh(k)
  def hidden? = (defn.get_attribute(B::DICT, '_hidden_formula') ? wert('hidden') > 0.5 : false)
  def pos(ax) = (formel(ax) ? wert(ax) : inst.transformation.origin[%w[x y z].index(ax)] * 2.54)
end

def nahe(a, b) = (a - b).abs < EPS
def q_nahe(a, b) = a.size == b.size && a.zip(b).all? { |x, y| nahe(x, y) }

# Sichtbare Teile nach DC-Neuberechnung: { Name => Quader [x0,x1,y0,y1,z0,z1] }
def sichtbar(k)
  k.kinder.reject(&:hidden?).to_h do |c|
    o = %w[x y z].map { |ax| c.pos(ax) }
    l = %w[lenx leny lenz].each_with_index.map { |a, i| c.formel(a) ? c.wert(a) : c.defn.box[i] * 2.54 }
    [c.name, [o[0], o[0] + l[0], o[1], o[1] + l[1], o[2], o[2] + l[2]]]
  end
end

# Gezeichnet (Lage + Box) passt zur Formel, ausgeblendet passt zur Formel
def pruefe_gezeichnet(k, label)
  k.kinder.each do |c|
    o = c.inst.transformation.origin.map { |v| v * 2.54 }
    %w[x y z].each_with_index { |ax, i| check(nahe(o[i], c.wert(ax)), "#{label}: #{c.name}.#{ax} gezeichnet #{o[i]} vs #{c.wert(ax)}") if c.formel(ax) }
    %w[lenx leny lenz].each_with_index { |ax, i| check(nahe(c.defn.box[i] * 2.54, c.wert(ax)), "#{label}: #{c.name}.#{ax} gezeichnet") if c.formel(ax) }
    check(!!c.inst.hidden == c.hidden?, "#{label}: #{c.name} hidden gezeichnet vs Formel")
  end
end

def ueberlapp?(a, b) = (0..2).all? { |i| a[2 * i] < b[2 * i + 1] - EPS && b[2 * i] < a[2 * i + 1] - EPS }

def knoten(inst)
  k = Knoten.new(inst, inst.definition, nil)
  k.redraw
  k
end

def umkonfigurieren(inst, werte)
  laengen = %w[Breite Hoehe Tiefe Laenge Sockelhoehe Ueberstand Staerke Ruecksprung]
  werte.each { |n, v| inst.set_attribute(B::DICT, n.downcase, laengen.include?(n) ? v / 2.54 : v.to_f) }
  knoten(inst)
end

KANTEN_SOLL = {
  'Blende' => %i[xmin xmax zmin zmax], 'Winkelleiste' => %i[ymin],
  'WangeL' => %i[ymin zmax], 'WangeR' => %i[ymin zmax],
  'SockelSeiteL' => %i[ymin zmax], 'SockelSeiteR' => %i[ymin zmax]
}.freeze
ROLLE_SOLL = { 'Blende' => 'Front', 'Winkelleiste' => 'Leiste', 'WangeL' => 'Wange', 'WangeR' => 'Wange',
               'SockelSeiteL' => 'Sockel', 'SockelSeiteR' => 'Sockel' }.freeze

# Material, Kanten, Tag, JT_Schrank an jedem Teil (auch ausgeblendeten)
def pruefe_kennzeichen(inst, kz, typ, kat, label, oberschrank: false, frontmat: nil)
  m = Sketchup.active_model.materials
  platte, kante = m[B::MATERIAL], m[B::KANTE]
  check(platte.get_attribute(B::OCL_DICT, 'type') == 2 && kante.get_attribute(B::OCL_DICT, 'type') == 4, "#{label}: Materialtypen")
  d = inst.definition
  check(d.get_attribute(B::JT_DICT, 'schrank') == kz && d.get_attribute(B::JT_DICT, 'typ') == typ &&
        d.get_attribute(B::JT_DICT, 'kategorie') == kat, "#{label}: JT_Schrank am Hauptteil")
  tags = []
  d.entities.instances.each do |c|
    teil = c.get_attribute(B::JT_DICT, 'teil')
    soll = teil.start_with?('Sockelblende') ? %i[zmax] : KANTEN_SOLL.fetch(teil)
    soll = %i[ymin zmin zmax] if oberschrank && teil.start_with?('Wange')
    front = %w[Blende WangeL WangeR].include?(teil)
    mat_soll = front && frontmat ? frontmat[0] : platte
    kante_soll = front && frontmat ? frontmat[1] : kante
    check(c.material.equal?(mat_soll), "#{label}: #{teil} Material #{c.material&.name}")
    ist = c.definition.entities.faces.select { |f| f.material.equal?(kante_soll) }.map do |f|
      B::SEITEN.find { |_, (ax, vz)| f.normal.to_a[ax] * vz > 0.5 }.first
    end
    check(ist.sort == soll.sort, "#{label}: #{teil} Kanten #{ist.inspect} statt #{soll.inspect}")
    rolle = teil.start_with?('Sockelblende') ? 'Sockel' : ROLLE_SOLL.fetch(teil)
    jt = %w[schrank typ kategorie bereich teil rolle].to_h { |k| [k, c.get_attribute(B::JT_DICT, k)] }
    check(jt == { 'schrank' => kz, 'typ' => typ, 'kategorie' => kat, 'bereich' => '', 'teil' => teil, 'rolle' => rolle },
          "#{label}: #{teil} JT_Schrank #{jt.inspect}")
    check(!!c.get_attribute(B::JT_DICT, 'frontfarbe') == front, "#{label}: #{teil} Frontfarbe-Kennzeichen")
    check(c.layer.name == "#{kz}_#{teil}", "#{label}: #{teil} Tag #{c.layer.name}")
    tags << c.layer.name
  end
  check(tags.uniq.size == tags.size, "#{label}: Tags eindeutig #{tags.inspect}")
end

def neu = (Sketchup.active_model = Sketchup::Model.new)

# ---------------------------------------------------------------------------
# Passblende
# ---------------------------------------------------------------------------
[[{}, 'Standard'], [{ 'Seite' => 'links', 'Winkelleiste' => 1.0, 'Breite' => 8.0 }, 'links mit Leiste'],
 [{ 'Winkelleiste' => 1.0, 'Hoehe' => 72.0, 'Kategorie' => 'Hochschrank' }, 'rechts mit Leiste, Hochschrank']].each do |e, label|
  neu
  inst = B.erstellen(:passblende, e)
  p = B::ARTEN[:passblende][:defaults].merge(e)
  k = knoten(inst)
  soll = B.passblende_masse(p).compact
  check(sichtbar(k).keys.sort == soll.keys.sort, "PB #{label}: Teile #{sichtbar(k).keys}")
  soll.each { |n, q| check(q_nahe(sichtbar(k)[n], q), "PB #{label}: #{n} #{sichtbar(k)[n]} statt #{q}") }
  pruefe_gezeichnet(k, "PB #{label}")
  pruefe_kennzeichen(inst, 'PB1', 'Passblende', e['Kategorie'] || 'Unterschrank', "PB #{label}")
  check(sichtbar(k).values.combination(2).none? { |a, b| ueberlapp?(a, b) }, "PB #{label}: Kollision")
  # Blende bündig mit den Fronten (2 mm vor der Korpusvorderkante wie die Fronten), Leiste an der Schrankseite
  bl = sichtbar(k)['Blende']
  check(nahe(bl[2], -0.2) && nahe(bl[3], 1.7), "PB #{label}: Blende in der Frontebene #{bl}")
  check(p['Seite'] == 'links' ? nahe(bl[1], 0) : nahe(bl[0], 0), "PB #{label}: Blende an der Schrankkante")
end
neu
inst = B.erstellen(:passblende, {})
k = umkonfigurieren(inst, 'Breite' => 12.0, 'Winkelleiste' => 1, 'Hoehe' => 80.0)
soll = B.passblende_masse(B::ARTEN[:passblende][:defaults].merge('Breite' => 12.0, 'Winkelleiste' => 1.0, 'Hoehe' => 80.0))
check(sichtbar(k).keys.sort == %w[Blende Winkelleiste] && soll.all? { |n, q| q_nahe(sichtbar(k)[n], q) },
      "PB umkonfiguriert: #{sichtbar(k).inspect}")

# ---------------------------------------------------------------------------
# Wange
# ---------------------------------------------------------------------------
[[{}, 'Unterschrank rechts'], [{ 'Seite' => 'links', 'Staerke' => 3.8, 'Ueberstand' => 2.0, 'Tiefe' => 52.0 }, 'links 38 mm'],
 [{ 'Kategorie' => 'Hochschrank', 'Hoehe' => 210.0, 'Sockelhoehe' => 12.0 }, 'Hochschrank'],
 [{ 'Kategorie' => 'Oberschrank', 'Hoehe' => 70.0, 'Tiefe' => 40.0, 'Seite' => 'links' }, 'Oberschrank']].each do |e, label|
  neu
  inst = B.erstellen(:wange, e)
  p = B::ARTEN[:wange][:defaults].merge(e)
  ober = e['Kategorie'] == 'Oberschrank'
  p['Sockelhoehe'] = 0.0 if ober
  k = knoten(inst)
  name, q = B.wange_masse(p).first
  check(sichtbar(k).keys == [name] && q_nahe(sichtbar(k)[name], q), "WG #{label}: #{sichtbar(k).inspect} statt #{q}")
  # bündig mit der Front, hinten mit der Rückwand, unten am Boden
  check(nahe(q[2], -0.2 - p['Ueberstand']) && nahe(q[3], 1.9 + p['Tiefe'] + 0.8) && nahe(q[4], -p['Sockelhoehe']) &&
        nahe(q[5], p['Hoehe']) && nahe(q[1] - q[0], p['Staerke']), "WG #{label}: Maße #{q}")
  check(e['Seite'] == 'links' ? nahe(q[1], 0) : nahe(q[0], 0), "WG #{label}: an der Schrankkante")
  pruefe_gezeichnet(k, "WG #{label}")
  pruefe_kennzeichen(inst, 'WG1', 'Wange', e['Kategorie'] || 'Unterschrank', "WG #{label}", oberschrank: ober)
  check(!!inst.definition.get_attribute(B::JT_DICT, 'sockel_unter_korpus') == !ober, "WG #{label}: Andock-Kennzeichen")
  check(ober == (inst.definition.get_attribute(B::DICT, '_sockelhoehe_access') == 'NONE'), "WG #{label}: Sockelhöhe nur bei Unter/Hoch")
end
neu
inst = B.erstellen(:wange, 'Seite' => 'links')
k = umkonfigurieren(inst, 'Staerke' => 2.5, 'Sockelhoehe' => 15.0, 'Hoehe' => 72.0)
q = sichtbar(k)['WangeL']
check(q && nahe(q[0], -2.5) && nahe(q[1], 0) && nahe(q[4], -15.0) && nahe(q[5], 72.0), "WG umkonfiguriert: #{q}")

# ---------------------------------------------------------------------------
# Sockelblende
# ---------------------------------------------------------------------------
[[{}, 'kurz'], [{ 'Laenge' => 300.0 }, '3000 = 2 Stücke'], [{ 'Laenge' => 900.0, 'Art_Seite' => 3.0 }, '9000 mit Seiten'],
 [{ 'Laenge' => 281.6, 'Art_Seite' => 1.0, 'Staerke' => 1.6 }, 'Seite links, gerade 1 Stück'],
 [{ 'Laenge' => 120.0, 'Art_Seite' => 2.0, 'Sockelhoehe' => 15.0, 'Tiefe' => 56.0 }, 'Seite rechts']].each do |e, label|
  neu
  inst = B.erstellen_sockelblende(e)
  p = B::ARTEN[:sockelblende][:defaults].merge(e)
  k = knoten(inst)
  soll = B.sockelblende_masse(p)
  check(sichtbar(k).keys.sort == soll.keys.sort, "SB #{label}: Teile #{sichtbar(k).keys.sort} statt #{soll.keys.sort}")
  soll.each { |n, q| check(q_nahe(sichtbar(k)[n] || [], q), "SB #{label}: #{n} #{sichtbar(k)[n]} statt #{q}") }
  stuecke = soll.select { |n, _| n.start_with?('Sockelblende') }.values
  check(stuecke.all? { |q| q[1] - q[0] <= 280.0 + EPS }, "SB #{label}: Stücke höchstens 2800 mm")
  check(nahe(soll.values.map(&:first).min, 0) && nahe(soll.values.map { |q| q[1] }.max, p['Laenge']), "SB #{label}: Gesamtlänge")
  check(stuecke.all? { |q| nahe(q[2], 1.9 + 5.0) && nahe(q[4], -p['Sockelhoehe'] + 0.3) && nahe(q[5], 0) },
        "SB #{label}: 50 mm hinter Korpusvorderkante, 3 mm Luft")
  pruefe_gezeichnet(k, "SB #{label}")
  pruefe_kennzeichen(inst, 'SB1', 'Sockelblende', 'Sockel', "SB #{label}")
  check(sichtbar(k).values.combination(2).none? { |a, b| ueberlapp?(a, b) }, "SB #{label}: Kollision")
end
neu
inst = B.erstellen_sockelblende('Laenge' => 120.0)
k = umkonfigurieren(inst, 'Laenge' => 600.0, 'Art_Seite' => 3)
soll = B.sockelblende_masse(B::ARTEN[:sockelblende][:defaults].merge('Laenge' => 600.0, 'Art_Seite' => 3.0))
check(sichtbar(k).keys.sort == soll.keys.sort && soll.all? { |n, q| q_nahe(sichtbar(k)[n], q) },
      "SB umkonfiguriert auf 6000 mit Seiten: #{sichtbar(k).keys.sort}")
check(B::MAX_STUECKE * 280.0 >= 1400.0, 'SB: bis 14 m Länge')

# ---------------------------------------------------------------------------
# Mit gewähltem Schrank: Maße, Lage und Frontmaterial übernehmen
# ---------------------------------------------------------------------------
def schrank(m, kat, breite_cm, tr, hoehe: 70.0, tiefe: 52.0, sockel: nil, frontmat: nil)
  d = m.definitions.add("Schrank #{kat}")
  { 'schrank' => "X#{m.entities.length + 1}", 'typ' => kat, 'kategorie' => kat }.each { |k, v| d.set_attribute(B::JT_DICT, k, v) }
  d.set_attribute(B::DICT, 'hoehe', hoehe / 2.54)
  d.set_attribute(B::DICT, 'tiefe', tiefe / 2.54)
  d.set_attribute(B::DICT, 'sockelhoehe', sockel / 2.54) if sockel
  seite = m.definitions.add('Seite')
  seite.box = [breite_cm / 2.54, tiefe / 2.54, hoehe / 2.54]
  d.entities.add_instance(seite, Geom::Transformation.translation([0, 1.9 / 2.54, 0]))
  fd = m.definitions.add('Front')
  fd.box = [(breite_cm - 0.2) / 2.54, 1.9 / 2.54, hoehe / 2.54]
  if frontmat
    f = Sketchup::Face.new(fd.entities, [], [0, -1, 0])
    f.material = frontmat[1]
    fd.entities.faces << f
  end
  fi = d.entities.add_instance(fd, Geom::Transformation.translation([0.1 / 2.54, -0.2 / 2.54, 0]))
  fi.set_attribute(B::JT_DICT, 'rolle', 'Front')
  fi.material = frontmat && frontmat[0]
  m.entities.add_instance(d, tr)
end

m = neu
eiche = m.materials.add('Front Eiche')
eiche_kante = m.materials.add('Anleimer Eiche')
eiche_kante.set_attribute(B::OCL_DICT, 'type', 4)
tr = Geom::Transformation.drehung(90, [100 / 2.54, 50 / 2.54, 10 / 2.54])
us = schrank(m, 'Unterschrank', 60.0, tr, hoehe: 72.0, tiefe: 56.0, sockel: 15.0, frontmat: [eiche, eiche_kante])
m.selection.add(us)
v = B.vorschlag(B.einzelner_nachbar(m))
check(v['Kategorie'] == 'Unterschrank' && nahe(v['Hoehe'], 72.0) && nahe(v['Tiefe'], 56.0) && nahe(v['Sockelhoehe'], 15.0),
      "Vorschlag aus dem Schrank: #{v.inspect}")
wr = B.erstellen(:wange, v.merge('Seite' => 'rechts'), us)
wl = B.erstellen(:wange, v.merge('Seite' => 'links'), us)
soll_r = (tr * Geom::Transformation.translation([60 / 2.54, 0, 0])).origin
check(q_nahe(wr.transformation.origin, soll_r) && nahe(wr.transformation.w, tr.w), "Wange rechts am Schrank: #{wr.transformation.origin}")
check(q_nahe(wl.transformation.origin, tr.origin), "Wange links am Schrank: #{wl.transformation.origin}")
pruefe_kennzeichen(wr, 'WG1', 'Wange', 'Unterschrank', 'Wange mit Frontmaterial', frontmat: [eiche, eiche_kante])
check(wr.definition.entities.instances.first.get_attribute(B::DICT, 'material') == 'Front Eiche', 'Frontmaterial übersteht DC-Neuzeichnen')
check(m.selection.to_a == [wl], 'neue Wange ausgewählt')
m.selection.clear
m.selection.add(us)
pb = B.erstellen(:passblende, v.merge('Seite' => 'rechts', 'Winkelleiste' => 1.0), us)
check(q_nahe(pb.transformation.origin, soll_r), 'Passblende rechts am Schrank')
pruefe_kennzeichen(pb, 'PB1', 'Passblende', 'Unterschrank', 'Passblende mit Frontmaterial', frontmat: [eiche, eiche_kante])

# Sockelblende unter einer Zeile: zwei Schränke, rechts die Wange; ein quer stehender wird übergangen
m = neu
tr1 = Geom::Transformation.drehung(90, [100 / 2.54, 50 / 2.54, 10 / 2.54])
s1 = schrank(m, 'Unterschrank', 60.0, tr1, sockel: 12.0, tiefe: 52.0)
s2 = schrank(m, 'Hochschrank', 45.0, tr1 * Geom::Transformation.translation([60 / 2.54, 0, 0]), tiefe: 56.0, hoehe: 210.0)
quer = schrank(m, 'Unterschrank', 60.0, Geom::Transformation.drehung(0, [0, 0, 0]))
os = schrank(m, 'Oberschrank', 60.0, tr1)
m.selection.add(s2)
w = B.erstellen(:wange, { 'Seite' => 'rechts', 'Staerke' => 1.9 }, s2)
m.selection.clear
[s2, s1, w, quer, os].each { |e| m.selection.add(e) }
z = B.zeile(m)
check(z[:ref].equal?(s2) && nahe(z[:x0] * 2.54, -60.0) && nahe(z[:laenge], 60.0 + 45.0) && nahe(z[:tiefe], 56.0) &&
      nahe(z[:sockel], 12.0), "Zeile aus der Auswahl (ohne Wange): #{z.reject { |k2, _| k2 == :ref }.inspect}")
check(B.zeilen(B.sockel_teile(m.selection.to_a)).size == 2, 'quer stehender Schrank ist eine eigene Zeile')
sb = B.erstellen_sockelblende({ 'Laenge' => z[:laenge], 'Tiefe' => z[:tiefe], 'Sockelhoehe' => z[:sockel] }, z)
check(q_nahe(sb.transformation.origin, tr1.origin) && nahe(sb.transformation.w, tr1.w), "Sockelblende beginnt am linken Schrank: #{sb.transformation.origin}")

# Sockelblende für die ganze Küche: L-Küche, Innenecke links hinten, Lücke, Wange, Oberschrank, alte Blende
m = neu
a = (0..2).map { |i| schrank(m, 'Unterschrank', 60.0, Geom::Transformation.translation([i * 60 / 2.54, 0, 0])) }
schrank(m, 'Oberschrank', 60.0, Geom::Transformation.translation([0, 0, 150 / 2.54]))
m.selection.add(a[2])
B.erstellen(:wange, { 'Seite' => 'rechts', 'Staerke' => 1.9 }, a[2])
abseits = schrank(m, 'Hochschrank', 60.0, Geom::Transformation.translation([250 / 2.54, 0, 0]), hoehe: 210.0)
# Zeile B an der linken Wand, Front nach +x, beginnt vor der Front von A
b = [-60.2, -120.2].map { |y| schrank(m, 'Unterschrank', 60.0, Geom::Transformation.drehung(90, [55 / 2.54, y / 2.54, 0])) }
m.selection.clear
alt = B.erstellen_sockelblende('Laenge' => 60.0)
m.selection.clear
k = B.kueche(m)
check(k[:teile].size == 6 && !k[:auswahl] && k[:alte] == [alt], "Küche: 6 Schränke, keine Auswahl, alte Blende (#{k[:teile].size})")
p = B::ARTEN[:sockelblende][:defaults]
zl = B.ecken(B.zeilen(k[:teile]), p)
check(zl.size == 3, "drei Zeilen (A, Hochschrank nach Lücke, B): #{zl.size}")
neu_sb = B.erstellen_sockelblenden({ 'Sockelhoehe' => 10.0, 'Staerke' => 1.6 }, zl, k[:alte])
check(neu_sb.size == 3 && !m.entities.to_a.include?(alt) && m.selection.to_a == neu_sb, 'je Zeile eine Sockelblende, alte ersetzt, neue ausgewählt')
welt = lambda do |inst|
  q = sichtbar(knoten(inst))
  pts = q.select { |n, _| n.start_with?('Sockelblende') }.values.flat_map do |c|
    [[c[0], c[2]], [c[1], c[3]]].map { |x, y| inst.transformation * Geom::Point3d.new(x / 2.54, y / 2.54, 0) }
  end
  xs, ys = pts.map { |pt| pt.x * 2.54 }, pts.map { |pt| pt.y * 2.54 }
  [xs.min, xs.max, ys.min, ys.max].map { |v| v.round(3) }
end
boxen = neu_sb.map { |i| welt.(i) }
# A: endet links an der Rückseite der Blende von B (x = 55 - 6.9 - 1.6), rechts an der Wange (180)
check(boxen.include?([46.5, 180.0, 6.9, 8.5]), "Zeile A um die Ecke: #{boxen.inspect}")
# B: läuft bis an die Vorderseite der Blende von A (y = 6.9)
check(boxen.include?([46.5, 48.1, -120.2, 6.9]), "Zeile B bis an die Blende von A: #{boxen.inspect}")
check(boxen.include?([250.0, 310.0, 6.9, 8.5]), "Hochschrank nach der Lücke eigene Blende: #{boxen.inspect}")
# mit Auswahl nur die gewählten Schränke
m.selection.clear
m.selection.add(b[0])
k = B.kueche(m)
check(k[:auswahl] && k[:teile] == [b[0]], 'mit Auswahl nur die gewählten Schränke')
# Über 14 m: mehrere Sockelblenden
m = neu
lang = (0..25).map { |i| schrank(m, 'Unterschrank', 60.0, Geom::Transformation.translation([i * 60 / 2.54, 0, 0])) }
zl = B.ecken(B.zeilen(B.sockel_teile(lang)), p)
neu_sb = B.erstellen_sockelblenden({ 'Sockelhoehe' => 10.0, 'Staerke' => 1.6 }, zl)
check(neu_sb.size == 2 && neu_sb.all? { |i| nahe(B.dc_cm(i, 'laenge'), 780.0) }, "15,6 m lange Zeile in zwei Blenden: #{neu_sb.map { |i| B.dc_cm(i, 'laenge') }.inspect}")

# ---------------------------------------------------------------------------
# Dialoge und Menü
# ---------------------------------------------------------------------------
module UI
  class << self
    attr_accessor :antworten, :fragen
  end
  def self.inputbox(prompts, defaults, *_r)
    (@fragen ||= []) << [prompts, defaults]
    a = (@antworten || []).shift
    a || defaults
  end
end
m = neu
B.dialog_sockelblende
m.selection.clear
B.dialog_passblende
m.selection.clear
B.dialog_wange
check(m.entities.length == 3, "Dialoge ohne Auswahl erzeugen je ein Teil (#{m.entities.length})")
check(UI.fragen.map { |f| f[1] } == [['600', '100', '520', 'keine'],
                                     ['Unterschrank', 'rechts', '50', '', 'nein'],
                                     ['Unterschrank', 'rechts', '19', '', '', '100', '0']], "Dialog-Vorschläge: #{UI.fragen.map { |f| f[1] }.inspect}")
hs = m.entities.instances[1].definition.entities.instances.first
check(nahe(hs.definition.box[2] * 2.54, 70.0), 'Passblende ohne Auswahl: Standardhöhe Unterschrank')
UI.antworten = [['Hochschrank', 'links', '25', '', '', '120', '10']]
m.selection.clear
B.dialog_wange
wg = m.entities.instances.last
q = sichtbar(knoten(wg))['WangeL']
check(q && nahe(q[1] - q[0], 2.5) && nahe(q[5], 210.0) && nahe(q[4], -12.0) && nahe(q[2], -1.2) && nahe(q[3], 1.9 + 52.0 + 0.8),
      "Wange aus dem Dialog: #{q.inspect}")
m = neu
UI.antworten = [%w[3000 100 520 beide]]
B.dialog_sockelblende
check(sichtbar(knoten(m.entities.instances.last)).keys.count { |n| n.start_with?('Sockelblende') } == 2, 'Sockelblende 3000 mm aus dem Dialog: 2 Stücke')
n = m.entities.length
UI.antworten = [%w[20000 100 520 keine], %w[0 100 520 keine]]
B.dialog_sockelblende
B.dialog_passblende
check(m.entities.length == n, 'zu lange Sockelblende / Breite 0 abgewiesen')

# Dialog mit Schränken im Modell: Sockelblende für die ganze Küche, alte ersetzen
m = neu
2.times { |i| schrank(m, 'Unterschrank', 60.0, Geom::Transformation.translation([i * 60 / 2.54, 0, 0])) }
m.selection.clear
alt = B.erstellen_sockelblende('Laenge' => 60.0)
m.selection.clear
UI.fragen = []
UI.antworten = [%w[120 19 ja]]
B.dialog_sockelblende
check(UI.fragen.last == [['Sockelhöhe (mm)', 'Stärke (mm)', 'Vorhandene Sockelblenden (1) ersetzen'], %w[100 16 ja]],
      "Dialog Küche: #{UI.fragen.last.inspect}")
sbs = m.entities.to_a.select { |e| B.sockelblende?(e) }
q = sbs.size == 1 && sichtbar(knoten(sbs[0]))['Sockelblende1']
check(!sbs.include?(alt) && q && nahe(q[1] - q[0], 120.0) && nahe(q[3] - q[2], 1.9) && nahe(q[4], -12.0 + 0.3),
      "Sockelblende aus dem Küchen-Dialog: #{q.inspect}")

# Sockelhöhe aus den Küchen-Einstellungen (hier 150 mm statt Standard 100 mm)
Kuechenplaner::Einstellungen.define_singleton_method(:sockelhoehe) { |_m = nil| 150.0 }
m = neu
UI.fragen = []
B.dialog_wange
m.selection.clear
B.dialog_sockelblende
check(UI.fragen.map { |f| f[1][-2] } == %w[150 520] && UI.fragen[0][1][5] == '150', "Sockelhöhe aus Einstellungen im Dialog: #{UI.fragen.map { |f| f[1] }.inspect}")
q = sichtbar(knoten(m.entities.instances.last))['Sockelblende1']
check(q && nahe(q[4], -15.0 + 0.3), "Sockelblende mit Sockelhöhe aus Einstellungen: #{q.inspect}")
Kuechenplaner::Einstellungen.define_singleton_method(:sockelhoehe) { |_m = nil| 100.0 }

eintraege = Kuechenplaner.schraenke.select { |g, _, _| g == 'Blenden & Wangen' }.map { |_, t, _| t }
check(eintraege == ['Passblende…', 'Wange…', 'Sockelblende…'], "Menü Blenden & Wangen: #{eintraege.inspect}")
check(Kuechenplaner::GRUPPEN.include?('Blenden & Wangen'), 'Gruppe Blenden & Wangen')

# Kurzhilfe und Doku
d = Sketchup.active_model.definitions['Wange']
check(d.description == B::HILFE_KURZ[:wange] && d.get_attribute(B::DICT, 'summary') == B::HILFE_KURZ[:wange], 'Hilfe: Summary')
check(d.get_attribute(B::DICT, 'description').nil?, 'Hilfe: keine lange Beschreibung im Fenster')
check(File.exist?(File.expand_path('../README.md', __dir__)), 'README.md vorhanden')

# --- Tiefe nachträglich ändern (Komponentenoptionen) = gleich mit dieser Tiefe erzeugt ---
require_relative '../../../test/tiefe_helfer'
{ 'Wange' => ->(e) { B.erstellen(:wange, e) },
  'Wange links Hochschrank' => ->(e) { B.erstellen(:wange, e.merge('Seite' => 'links', 'Kategorie' => 'Hochschrank', 'Hoehe' => 210.0)) },
  'Sockelblende' => ->(e) { B.erstellen_sockelblende(e.merge('Laenge' => 400.0, 'Art_Seite' => 3.0)) } }.each do |was, erz|
  TiefeHelfer.pruefen(Knoten, B::DICT, erz, [[80.0, 52.0], [52.0, 65.0]]).each do |paar, abw|
    check(abw.empty?, "#{was} Tiefe #{paar}: " + abw.first(8).join('; '))
  end
end

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
