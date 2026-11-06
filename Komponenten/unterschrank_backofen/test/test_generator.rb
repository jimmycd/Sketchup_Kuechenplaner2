# Test des Generators ohne SketchUp: Mock-API + kleiner DC-Formel-Auswerter.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
load File.expand_path('../src/unterschrank_backofen/main.rb', __dir__)

U = UnterschrankBackofen
EPS = 1e-6
$fehler = 0
def check(bed, msg)
  unless bed
    $fehler += 1
    puts "FEHLER: #{msg}"
  end
end

# --- DC-Auswerter -----------------------------------------------------------
class Knoten
  attr_reader :inst, :defn, :parent, :kinder, :werte
  def initialize(inst, defn, parent)
    @inst, @defn, @parent = inst, defn, parent
    @werte = {}
    @kinder = defn.entities.instances.map { |ci| Knoten.new(ci, ci.definition, self) }
  end

  def name
    inst ? (inst.get_attribute(U::DICT, '_name') || defn.get_attribute(U::DICT, '_name')) : defn.get_attribute(U::DICT, '_name')
  end

  def roh(attr)
    k = attr.downcase
    return @werte[k] if @werte.key?(k)
    v = inst&.get_attribute(U::DICT, k)
    v = defn.get_attribute(U::DICT, k) if v.nil?
    v = inst.transformation.origin[%w[x y z].index(k)] if v.nil? && inst && %w[x y z].include?(k)
    raise "Attribut #{attr} fehlt an #{name}" if v.nil?
    fu = defn.get_attribute(U::DICT, "_#{k}_formulaunits")
    laenge = %w[x y z lenx leny lenz].include?(k) || fu == 'CENTIMETERS'
    laenge ? v * 2.54 : v
  end

  def formel(k)
    inst&.get_attribute(U::DICT, "_#{k}_formula") || defn.get_attribute(U::DICT, "_#{k}_formula")
  end

  def ref(n, attr)
    ziel = if parent && parent.name == n then parent
           else (parent ? parent.kinder : []).find { |s| s.name == n }
           end
    raise "Referenz #{n}!#{attr} von #{name} nicht auflösbar (nur Eltern/Geschwister)" unless ziel
    ziel.roh(attr)
  end

  def IF(c, a, b) = c ? a : b
  def INT(x) = x.floor.to_f
  def MIN(*a) = a.min
  def MAX(*a) = a.max

  def auswerten(f)
    ruby = f.gsub(/(\w+)!(\w+)|\b([A-Za-z_]\w*)\b(?!\s*\()/) do
      $1 ? "ref(#{$1.inspect},#{$2.inspect})" : "roh(#{$3.inspect})"
    end
    v = instance_eval(ruby)
    v == true ? 1.0 : (v == false ? 0.0 : v.to_f)
  end

  def alle_schluessel
    keys = (defn.attribute_dictionary(U::DICT)&.keys || []) + (inst&.attribute_dictionary(U::DICT)&.keys || [])
    keys.grep(/\A_(.+)_formula\z/) { $1 }.reject { |k| k.start_with?('inst_') }.uniq.sort
  end

  # wie DC: erst eigene Formeln, dann Kinder
  def redraw
    alle_schluessel.each { |k| @werte[k] = auswerten(formel(k)) }
    kinder.each(&:redraw)
  end

  def wert(k) = roh(k)
  def finde(n) = kinder.find { |c| c.name == n }
end

def eingabe(extra = {})
  { 'Breite' => 60.0, 'Hoehe' => 70.0, 'Tiefe' => 80.0 }.merge(extra)
end

def nl_soll(lt) = ([35.0, 40.0, 45.0, 50.0, 55.0, 60.0, 65.0].select { |n| n + 0.3 <= lt + 1e-6 }.max || 35.0)

# Geometrische Prüfungen auf Basis der ausgewerteten Formeln; schublade: erwartet ja/nein
def pruefe(w, h, b, t, nh, schublade, label)
  mk = w.wert('Materialstaerke_Korpus')
  sp = w.wert('Spaltbreite')
  z_eb = h - nh
  check((w.wert('Schublade') > 0.5) == schublade, "#{label}: Schublade #{schublade} (Wert #{w.wert('Schublade')})")
  # Korpus: keine Streben, Rückwand nur unten
  check(%w[StrebeVorn StrebeHinten Deckel].none? { |n| w.finde(n) }, "#{label}: keine Streben/kein Deckel")
  check((w.finde('SeiteR').wert('x') - (b - mk)).abs < EPS, "#{label}: SeiteR")
  rw = w.finde('Rückwand')
  check((rw.wert('y') - (t + mk)).abs < EPS && (rw.wert('lenz') - z_eb).abs < EPS, "#{label}: Rückwand bis Oberkante Einbauboden")
  # Einbauboden
  eb = w.finde('ZwischenbodenUnten')
  check((eb.wert('z') + eb.wert('lenz') - z_eb).abs < EPS && (eb.wert('lenz') - mk).abs < EPS, "#{label}: Einbauboden Oberkante #{z_eb}")
  check((eb.wert('leny') - (t - w.wert('Lueftungsspalt'))).abs < EPS && (eb.wert('y') - mk).abs < EPS, "#{label}: Einbauboden mit Lüftungsspalt hinten")
  check((eb.wert('lenx') - (b - 2 * mk)).abs < EPS && (eb.wert('x') - mk).abs < EPS, "#{label}: Einbauboden zwischen den Seiten")
  # Nische: lichte Höhe bis zur Korpusoberkante frei
  check((h - (eb.wert('z') + eb.wert('lenz')) - nh).abs < EPS, "#{label}: Nischenhöhe #{nh}")
  # unten: Blende oder Schublade, Front bis 2 mm unter den Einbauboden-Oberkante (= Ofenfront)
  bl = w.finde('Blende')
  s = w.finde('Schublade1')
  check((bl.wert('hidden') > 0.5) == schublade && (s.wert('hidden') > 0.5) == !schublade, "#{label}: genau eins sichtbar")
  check((bl.wert('lenz') - (z_eb - sp)).abs < EPS && bl.wert('z').abs < EPS, "#{label}: Blende 0 bis #{z_eb - sp}")
  check((bl.wert('lenx') - (b - sp)).abs < EPS && (bl.wert('x') - sp / 2).abs < EPS && (bl.wert('y') + sp).abs < EPS,
        "#{label}: Blende Breite/Lage wie Fronten")
  f = s.finde('Front')
  check((f.wert('lenz') - (z_eb - sp)).abs < EPS && (s.wert('z') + f.wert('z')).abs < EPS && (f.wert('lenx') - (b - sp)).abs < EPS,
        "#{label}: Schubladenfront wie Blende")
  nl = nl_soll(t)
  check((w.wert('NL') - nl).abs < EPS && (s.wert('NL') - nl).abs < EPS, "#{label}: NL #{w.wert('NL')} statt #{nl}")
  kb = s.finde('KastenBoden'); kr = s.finde('KastenRueckwand')
  lw = b - 2 * mk
  mb = w.wert('Materialstaerke_Kastenboden')
  check((kb.wert('lenx') - (lw - 3.5)).abs < EPS && (kb.wert('x') - (mk + 1.75)).abs < EPS, "#{label}: Boden LW-35 mittig")
  check((kb.wert('leny') - (nl - 1.0)).abs < EPS && (kb.wert('y') - mk).abs < EPS, "#{label}: Boden NL-10")
  check((kr.wert('y') + kr.wert('leny') - (kb.wert('y') + kb.wert('leny'))).abs < EPS, "#{label}: Kastenrückwand hinten bündig")
  check((kr.wert('z') - (kb.wert('z') + mb)).abs < EPS, "#{label}: Kastenrückwand auf dem Boden")
  check(kr.wert('lenz') > 0 && kb.wert('z') >= mk - EPS, "#{label}: Kasten über dem Boden, positive Höhe")
  kz1 = kr.wert('z') + kr.wert('lenz')
  if schublade
    check(kz1 <= z_eb - mk - w.wert('Kasten_Abstand_oben') + EPS, "#{label}: Kasten stößt an den Einbauboden (#{kz1.round(2)})")
    min_ab = [w.wert('Kasten_Abstand_unten'), mk + 3.8 - w.wert('Hoehenoffset_Schiene')].max
    check((kb.wert('z') - min_ab).abs < EPS, "#{label}: Kasten genau am Mindestabstand, kein Lochraster (#{kb.wert('z').round(3)})")
  else
    check(kz1 <= h + EPS, "#{label}: versteckter Kasten außerhalb")
  end
end

# Vergleicht die vom Generator gezeichnete Geometrie mit den Formelwerten
def pruefe_geometrie(k, label)
  if k.inst && k.parent
    o = k.inst.transformation.origin.map { |v| v * 2.54 }
    %w[x y z].each_with_index do |ax, i|
      next unless k.formel(ax)
      check((o[i] - k.wert(ax)).abs < EPS, "#{label}: #{k.name}.#{ax} gezeichnet #{o[i]} vs Formel #{k.wert(ax)}")
    end
    if k.defn.box
      %w[lenx leny lenz].each_with_index do |ax, i|
        next unless k.formel(ax)
        check((k.defn.box[i] * 2.54 - k.wert(ax)).abs < EPS, "#{label}: #{k.name}.#{ax} gezeichnet #{k.defn.box[i] * 2.54} vs Formel #{k.wert(ax)}")
      end
    end
    if k.formel('hidden')
      check(k.inst.hidden == (k.wert('hidden') > 0.5), "#{label}: #{k.name} ausgeblendet passt nicht zur Formel")
    end
  end
  k.kinder.each { |c| pruefe_geometrie(c, label) }
end

[
  [{}, false],                                     # 700 mm Korpus: 62 mm frei -> Blende
  [{ 'Hoehe' => 76.0 }, true],                     # 760 mm: 122 mm frei -> Schublade
  [{ 'Hoehe' => 72.0, 'Nischenhoehe' => 59.0 }, true], # 72 - 59 - 3,8 = 9,2 cm
  [{ 'Hoehe' => 76.0, 'Unten' => 1.0 }, false],    # Blende erzwungen
  [{ 'Hoehe' => 76.0, 'Min_Lichte_Schublade' => 12.3 }, false],
  [{ 'Breite' => 90.0, 'Tiefe' => 56.0, 'Hoehe' => 80.0, 'Lueftungsspalt' => 3.0 }, true],
  [{ 'Hoehe' => 76.0, 'Hoehenoffset_Schiene' => 1.1 }, true]
].each do |extra, schublade|
  Sketchup.active_model = Sketchup::Model.new
  e = eingabe(extra)
  inst = U.erstellen(e)
  w = Knoten.new(inst, inst.definition, nil)
  w.redraw
  p = U::DEFAULTS.merge(e)
  label = extra.inspect
  check(U.berechne(p)[:schublade] == schublade, "#{label}: berechne Schublade")
  pruefe(w, p['Hoehe'], p['Breite'], p['Tiefe'], p['Nischenhoehe'], schublade, label)
  pruefe_geometrie(w, label)
  puts "#{label}: #{schublade ? 'Schublade' : 'Blende'}, lichte Höhe unten #{(U.berechne(p)[:lichte_unten] * 10).round} mm, NL #{w.wert('NL')}"

  # Umkonfiguration über die Komponentenoptionen (Werte an der Instanz)
  inst.set_attribute(U::DICT, 'hoehe', (schublade ? 70.0 : 78.0) / 2.54)
  inst.set_attribute(U::DICT, 'breite', 80.0 / 2.54)
  inst.set_attribute(U::DICT, 'tiefe', 60.0 / 2.54)
  inst.set_attribute(U::DICT, 'unten', 0.0)
  inst.set_attribute(U::DICT, 'min_lichte_schublade', 8.5 / 2.54)
  w2 = Knoten.new(inst, inst.definition, nil)
  w2.redraw
  pruefe(w2, schublade ? 70.0 : 78.0, 80.0, 60.0, p['Nischenhoehe'], !schublade, "#{label} -> umkonfiguriert")
end

# --- Material, Anleimer, Tags ---------------------------------------------
model = Sketchup.active_model = Sketchup::Model.new
inst1 = U.erstellen(eingabe)
inst2 = U.erstellen(eingabe('Hoehe' => 76.0))
mel = model.materials['Melamin weiss']; anl = model.materials['Anleimer weiss']
check(mel.get_attribute('ladb_opencutlist', 'type') == 2, 'Melamin = Plattenmaterial')
check(anl.get_attribute('ladb_opencutlist', 'type') == 4 && anl.get_attribute('ladb_opencutlist', 'edge_decremented') == true,
      'Anleimer = Kante, wird abgezogen')

def teile(inst, pfad = [])
  inst.definition.entities.instances.flat_map do |c|
    c.definition.entities.faces.empty? ? teile(c, pfad + [c]) : [[c, pfad + [c]]]
  end
end

[[inst1, 'USB1'], [inst2, 'USB2']].each do |inst, kz|
  t = teile(inst)
  # SeiteL/R, Boden, Einbauboden, Rückwand, Blende + Schublade Front, KastenBoden, KastenRueckwand
  check(t.size == 6 + 3, "#{kz}: Anzahl Teile #{t.size}")
  tags = t.map { |c, _| c.layer&.name }
  check(tags.none?(&:nil?) && tags.uniq.size == tags.size && tags.all? { |n| n.start_with?("#{kz}_") }, "#{kz}: Tags #{tags}")
  t.each do |c, _|
    check(c.material == mel, "#{kz}: Material #{c.name}")
    jt = %w[schrank typ kategorie bereich teil rolle].to_h { |k| [k, c.get_attribute(U::JT_DICT, k)] }
    check(jt['schrank'] == kz && jt['typ'] == U::TYP && jt['kategorie'] == 'Unterschrank', "#{kz}: JT_Schrank #{c.name} #{jt.inspect}")
    check(c.layer.name == [kz, (jt['bereich'] unless jt['bereich'].empty?), jt['teil']].compact.join('_'),
          "#{kz}: Tag #{c.layer.name} passt nicht zu JT_Schrank #{jt.inspect}")
    check(U::ROLLEN.value?(jt['rolle']), "#{kz}: Rolle #{c.name} #{jt['rolle'].inspect}")
    typ = c.definition.get_attribute(U::DICT, '_name')
    soll = U::KANTEN.fetch(typ).sort
    ist = c.definition.entities.faces.select { |f| f.material == anl }.map { |f| U.seite_von(f) }.sort
    check(ist == soll, "#{kz}: Anleimer #{c.name} #{ist} statt #{soll}")
  end
end
check(%w[USB1_SeiteL USB1_Rueckwand USB1_Blende USB1_ZwischenbodenUnten USB1_S1_Front USB2_S1_KastenRueckwand USB1_S1_Schublade].all? { |n| model.layers[n] }, 'Tag-Namen')
tl = teile(inst1).map(&:first)
eb = tl.find { |c| c.name == 'ZwischenbodenUnten' }
check(eb.get_attribute(U::JT_DICT, 'rolle') == 'Zwischenboden' && eb.get_attribute(U::JT_DICT, 'nische') == 'N1', 'Einbauboden: Zwischenboden mit Nische N1')
bl = tl.find { |c| c.name == 'Blende' }
check(bl.get_attribute(U::JT_DICT, 'rolle') == 'Front' && !bl.hidden && bl.get_attribute(U::JT_DICT, 'bereich') == '', 'Blende: Rolle Front, sichtbar bei 700 mm')
check(inst1.definition.entities.instances.find { |c| c.name == 'Schublade1' }.hidden, 'Schublade bei 700 mm ausgeblendet')
check(teile(inst2).map(&:first).find { |c| c.name == 'Blende' }.hidden, 'Blende bei 760 mm ausgeblendet')
check(inst1.definition.get_attribute(U::JT_DICT, 'typ') == U::TYP, 'JT_Schrank am Schrank')

# --- Nischen für die Geräte ------------------------------------------------
n1 = ->(k) { inst1.definition.get_attribute('JT_Nische_N1', k) }
kf = ->(k) { inst1.definition.get_attribute('JT_Nische_KF', k) }
check(n1.('nische') == 'N1' && n1.('geraet') == 'Backofen60', "Nische N1: #{n1.('geraet')}")
check(n1.('breite') == 562.0 && n1.('hoehe') == 600.0 && n1.('tiefe') == 800.0, 'Nische N1: lichte Maße')
check(n1.('x') == 19.0 && n1.('y') == 19.0 && n1.('z') == 100.0, 'Nische N1: Einfügepunkt auf dem Einbauboden')
check(kf.('nische') == 'KF' && kf.('geraet') == 'Kochfeld60' && kf.('z') == 700.0 && kf.('arbeitsplatte') == 40.0, 'Nische KF: Kochfeld auf der Korpusoberkante')

# --- Warnungen im Dialog ------------------------------------------------------
check(U.warnungen(U::DEFAULTS).any? { |w| w.include?('62 mm') && w.include?('Blende') }, 'Warnung: zu wenig Platz für die Schublade')
check(U.warnungen(U::DEFAULTS.merge('Hoehe' => 76.0)).empty?, 'keine Warnung bei 760 mm')
check(U.warnungen(U::DEFAULTS.merge('Breite' => 55.0, 'Hoehe' => 76.0)).any? { |w| w.include?('512 mm') }, 'Warnung: lichte Breite zu klein')

# --- Kurzhilfe in der Komponente ------------------------------------------
Sketchup.active_model = Sketchup::Model.new
hd = U.erstellen(eingabe).definition
check(hd.description == U::HILFE_KURZ && hd.get_attribute(U::DICT, 'summary') == U::HILFE_KURZ, 'Hilfe: Beschreibung/summary')
check(hd.get_attribute(U::DICT, 'description').nil?, 'Hilfe: description')
check(%w[summary description].none? { |k| hd.get_attribute(U::DICT, "_#{k}_access") }, 'Hilfe: keine eigenen Zeilen in den Optionen')
check(File.exist?(File.expand_path('../README.md', __dir__)), 'README.md vorhanden')

# .rbz muss zum Quelltext passen (sonst ./build_rbz.sh im Hauptordner ausführen)
rbz = File.expand_path('../unterschrank_backofen.rbz', __dir__)
%w[unterschrank_backofen.rb unterschrank_backofen/main.rb].each do |f|
  im_rbz = IO.popen(['unzip', '-p', rbz, f], err: File::NULL, &:read)
  check(im_rbz == File.read(File.expand_path("../src/#{f}", __dir__)), "rbz veraltet: #{f} (./build_rbz.sh im Hauptordner ausführen)")
end

# --- Tiefe nachträglich ändern (Komponentenoptionen) = gleich mit dieser Tiefe erzeugt ---
require_relative '../../../test/tiefe_helfer'
[{}, { 'Hoehe' => 76.0 }].each do |ein|
  TiefeHelfer.pruefen(Knoten, U::DICT, ->(e) { U.erstellen(e) },
                      [[80.0, 52.0], [52.0, 40.0], [52.0, 65.0], [56.0, 47.3]], eingabe(ein)).each do |was, abw|
    check(abw.empty?, "Tiefe #{was} #{ein.inspect}: " + abw.first(8).join('; '))
  end
end

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
