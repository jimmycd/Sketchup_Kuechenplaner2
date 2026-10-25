# Test des Generators ohne SketchUp: Mock-API + kleiner DC-Formel-Auswerter.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
load File.expand_path('../src/unterschrank_schubladen/main.rb', __dir__)

U = UnterschrankSchubladen
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

def eingabe(anz, anteile, extra = {})
  e = { 'Breite' => 60.0, 'Hoehe' => 70.0, 'Tiefe' => 80.0, 'Anz_Schubladen' => anz }
  (1..6).each { |i| e["Anteil_#{i}"] = anteile[i - 1] || 1.0 }
  e.merge(extra)
end

# Geometrische Prüfungen auf Basis der ausgewerteten Formeln
def pruefe(wurzel, anz, h, b, t, label)
  mk = wurzel.wert('Materialstaerke_Korpus')
  sp = wurzel.wert('Spaltbreite')
  fronten = []
  (1..6).each do |i|
    s = wurzel.finde("Schublade#{i}")
    sichtbar = s.wert('hidden') < 0.5
    check(sichtbar == (i <= anz), "#{label}: Sichtbarkeit Schublade #{i}")
    unless sichtbar
      # ausgeblendete Schubladen dürfen nicht aus dem Korpus ragen (Auswahlrahmen)
      z0 = s.wert('z')
      s.kinder.each do |c|
        lo = z0 + c.wert('z'); hi = lo + c.wert('lenz')
        check(lo >= -EPS && hi <= h + EPS, "#{label}: versteckte S#{i}/#{c.name} außerhalb (#{lo.round(2)}..#{hi.round(2)})")
      end
      next
    end
    f = s.finde('Front')
    z0 = s.wert('z')
    fronten << [z0 + f.wert('z'), z0 + f.wert('z') + f.wert('lenz')]
    check((f.wert('lenx') - (b - sp)).abs < EPS, "#{label}: Frontbreite S#{i}")
    check((f.wert('x') - sp / 2).abs < EPS, "#{label}: Front x S#{i}")
    # Kasten innerhalb Korpus und innerhalb Fronthöhe
    kl = s.finde('KastenSeiteL'); kr = s.finde('KastenSeiteR')
    check(kl.wert('x') >= mk - EPS && kr.wert('x') + kr.wert('lenx') <= b - mk + EPS, "#{label}: Kasten Breite S#{i}")
    check(((kr.wert('x') + kr.wert('lenx')) - kl.wert('x') - (b - 2 * mk - 2 * wurzel.wert('Luft_Auszug'))).abs < EPS, "#{label}: Kasten Außenbreite S#{i}")
    check(kl.wert('y') + kl.wert('leny') <= mk + t + EPS, "#{label}: Kasten Tiefe S#{i}")
    kz0 = z0 + kl.wert('z'); kz1 = kz0 + kl.wert('lenz')
    check(kl.wert('lenz') > 0, "#{label}: Kastenhöhe > 0 S#{i}")
    check(kz0 >= mk - EPS && kz1 <= h - mk + EPS, "#{label}: Kasten kollidiert mit Boden/Strebe S#{i}")
    kh = s.finde('KastenHinten'); kb = s.finde('KastenBoden'); kv = s.finde('KastenVorne')
    check((kh.wert('y') + kh.wert('leny') - (kl.wert('y') + kl.wert('leny'))).abs < EPS, "#{label}: Rückstück bündig S#{i}")
    mb = wurzel.wert('Materialstaerke_Kastenboden')
    if wurzel.wert('Kastenboden_tragend') > 0.5
      # tragender Boden: volle Kastenbreite, Seiten stehen darauf
      check((kb.wert('x') - kl.wert('x')).abs < EPS && (kb.wert('x') + kb.wert('lenx') - (kr.wert('x') + kr.wert('lenx'))).abs < EPS,
            "#{label}: tragender Kastenboden volle Breite S#{i}")
      check((kl.wert('z') - (kb.wert('z') + mb)).abs < EPS && (kr.wert('z') - kl.wert('z')).abs < EPS, "#{label}: Seiten auf dem Boden S#{i}")
    else
      check((kb.wert('x') - (kl.wert('x') + kl.wert('lenx'))).abs < EPS, "#{label}: Kastenboden an Seite S#{i}")
      check((kb.wert('x') + kb.wert('lenx') - kr.wert('x')).abs < EPS, "#{label}: Kastenboden bis Seite R S#{i}")
      check((kl.wert('z') - kb.wert('z')).abs < EPS, "#{label}: Seiten und Boden unten bündig S#{i}")
    end
    check((kb.wert('lenz') - mb).abs < EPS, "#{label}: Stärke Kastenboden S#{i}")
    check((kv.wert('z') - (kb.wert('z') + mb)).abs < EPS, "#{label}: Vorderstück auf dem Boden S#{i}")
    check((kv.wert('z') + kv.wert('lenz') - (kl.wert('z') + kl.wert('lenz'))).abs < EPS, "#{label}: Vorderstück Höhe S#{i}")
    # Lochraster: Schienenbohrung (Unterkante Kasten + Höhenoffset) auf Start + n * Raster, ab Unterkante Seite
    unten = z0 + kb.wert('z')
    loch = (unten + wurzel.wert('Hoehenoffset_Schiene') - wurzel.wert('Lochraster_Start')) / wurzel.wert('Lochraster')
    check((loch - loch.round).abs < 1e-6 && loch.round >= 0, "#{label}: Schiene S#{i} nicht im Lochraster (#{unten.round(3)})")
    check(kb.wert('z') >= wurzel.wert('Kasten_Abstand_unten') - EPS &&
          kb.wert('z') < wurzel.wert('Kasten_Abstand_unten') + wurzel.wert('Lochraster') - EPS,
          "#{label}: Kasten S#{i} höchstens ein Raster über dem Mindestabstand")
    check((kz1 - (z0 + f.wert('lenz') - wurzel.wert('Kasten_Abstand_oben'))).abs < EPS || kl.wert('lenz') <= 2.0 + EPS,
          "#{label}: Kasten S#{i} Abstand oben")
    check((s.wert('Auszug') - (t - 2) * 0.8).abs < EPS, "#{label}: Auszug S#{i}")
  end
  fronten.sort!
  check((fronten.first[0]).abs < EPS, "#{label}: unterste Front bei 0 (#{fronten.first[0]})")
  check((fronten.last[1] - h).abs < EPS, "#{label}: oberste Front bis Höhe")
  fronten.each_cons(2) { |a, c| check((c[0] - a[1] - sp).abs < EPS, "#{label}: Spalt zwischen Fronten") }
  # Korpus
  check((wurzel.finde('SeiteR').wert('x') - (b - mk)).abs < EPS, "#{label}: SeiteR")
  check((wurzel.finde('Rückwand').wert('y') - (t + mk)).abs < EPS, "#{label}: Rückwand")
  fronten
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
        check((k.defn.box[i] * 2.54 - k.wert(ax)).abs < EPS, "#{label}: #{k.name}.#{ax} gezeichnet vs Formel")
      end
    end
  end
  k.kinder.each { |c| pruefe_geometrie(c, label) }
end

[
  [3, [1, 1, 1]],
  [3, [1, 1, 2]],
  [4, [14, 14, 20, 21.4]],
  [1, [1]],
  [6, [1, 1, 1, 1, 1, 1]],
  [2, [1, 3]],
  [3, [1, 1, 1], { 'Luft_Auszug' => 0.0 }],
  [3, [1, 1, 2], { 'Luft_Auszug' => 2.15 }],
  [3, [1, 1, 1], { 'Kastenboden_tragend' => 0.0, 'Materialstaerke_Kastenboden' => 0.8 }],
  [4, [1, 1, 2, 2], { 'Hoehenoffset_Schiene' => 1.1 }],
  [2, [1, 1], { 'Lochraster_Start' => 3.7, 'Hoehenoffset_Schiene' => 0.5 }]
].each do |anz, ant, extra|
  model = Sketchup.active_model = Sketchup::Model.new
  e = eingabe(anz, ant, extra || {})
  inst = U.erstellen(e)
  w = Knoten.new(inst, inst.definition, nil)
  w.redraw
  label = "anz=#{anz} #{ant.inspect}"
  fr = pruefe(w, anz, 70.0, 60.0, 80.0, label)
  pruefe_geometrie(w, label)
  puts "#{label}: Fronten (cm) " + fr.map { |a, c| "#{a.round(2)}–#{c.round(2)} (h=#{(c - a).round(2)})" }.join(', ')

  # Rekonfiguration über die Komponentenoptionen simulieren
  d = inst.definition
  d.set_attribute(U::DICT, 'anz_schubladen', 4.0)
  [1.0, 2.0, 1.0, 3.0].each_with_index { |v, i| d.set_attribute(U::DICT, "anteil_#{i + 1}", v) }
  d.set_attribute(U::DICT, 'hoehe', 80.0 / 2.54)
  d.set_attribute(U::DICT, 'breite', 45.0 / 2.54)
  d.set_attribute(U::DICT, 'luft_auszug', 1.25 / 2.54)
  d.set_attribute(U::DICT, 'kastenboden_tragend', 1.0 - d.get_attribute(U::DICT, 'kastenboden_tragend'))
  w2 = Knoten.new(inst, d, nil)
  w2.redraw
  pruefe(w2, 4, 80.0, 45.0, 80.0, "#{label} -> umkonfiguriert")
end

# --- OpenCutList: Material, Anleimer, Tags ---------------------------------
model = Sketchup.active_model = Sketchup::Model.new
inst1 = U.erstellen(eingabe(3, [1, 1, 1]))
inst2 = U.erstellen(eingabe(2, [1, 1]))
mel = model.materials['Melamin weiss']; anl = model.materials['Anleimer weiss']
check(mel.get_attribute('ladb_opencutlist', 'type') == 2, 'OCL: Melamin = Plattenmaterial')
check(anl.get_attribute('ladb_opencutlist', 'type') == 4, 'OCL: Anleimer = Kante')
check(anl.get_attribute('ladb_opencutlist', 'thickness') == '2 mm', 'OCL: Anleimer 2 mm')
check(anl.get_attribute('ladb_opencutlist', 'edge_decremented') == true, 'OCL: Anleimer wird abgezogen')

def teile(inst, pfad = [])
  inst.definition.entities.instances.flat_map do |c|
    c.definition.entities.faces.empty? ? teile(c, pfad + [c]) : [[c, pfad + [c]]]
  end
end

[[inst1, 'USS1'], [inst2, 'USS2']].each do |inst, kz|
  t = teile(inst)
  check(t.size == 6 + 6 * 6, "#{kz}: Anzahl Teile #{t.size}")
  tags = t.map { |c, _| c.layer&.name }
  check(tags.none?(&:nil?), "#{kz}: jedes Teil hat ein Tag")
  check(tags.uniq.size == tags.size, "#{kz}: Tags eindeutig")
  check(tags.all? { |n| n.start_with?("#{kz}_") }, "#{kz}: Tags mit Kürzel #{kz}")
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
    rest = c.definition.entities.faces.reject { |f| f.material == anl }
    check(rest.all? { |f| f.material.nil? }, "#{kz}: übrige Flächen erben Melamin #{c.name}")
  end
end
check(%w[USS1_SeiteL USS1_Rueckwand USS1_S3_Front USS2_S1_KastenSeiteR USS1_S1_Schublade].all? { |n| model.layers[n] }, 'Tag-Namen')
check(inst1.definition.get_attribute(U::JT_DICT, 'kategorie') == 'Unterschrank', 'JT_Schrank am Schrank')

# Aufteilungs-Parser
check(U.parse_aufteilung('1;1;2', 3) == [1.0, 1.0, 2.0], 'parse 1;1;2')
check(U.parse_aufteilung('140/140 416', 3) == [140.0, 140.0, 416.0], 'parse mm')
check(U.parse_aufteilung('1,5;1', 3) == [1.5, 1.0, 1.0], 'parse Komma + auffüllen')

# --- Kurzhilfe in der Komponente ------------------------------------------
Sketchup.active_model = Sketchup::Model.new
hd = U.erstellen(eingabe(3, [1, 1, 1])).definition
check(hd.description == U::HILFE_KURZ, 'Hilfe: Beschreibung der Definition')
check(hd.get_attribute(U::DICT, 'summary') == U::HILFE_KURZ, 'Hilfe: summary')
check(hd.get_attribute(U::DICT, 'description') == U::HILFE, 'Hilfe: description')
check(%w[summary description].all? { |k| hd.get_attribute(U::DICT, "_#{k}_access") == 'VIEW' }, 'Hilfe: nur anzeigen')
check(U::HILFE.include?(U::DOKU_URL), 'Hilfe: Link zur Doku')
check(File.exist?(File.expand_path('../README.md', __dir__)), 'README.md vorhanden')

# .rbz muss zum Quelltext passen (sonst build_rbz.sh ausführen)
rbz = File.expand_path('../unterschrank_schubladen.rbz', __dir__)
%w[unterschrank_schubladen.rb unterschrank_schubladen/main.rb].each do |f|
  im_rbz = IO.popen(['unzip', '-p', rbz, f], &:read)
  check(im_rbz == File.read(File.expand_path("../src/#{f}", __dir__)), "rbz veraltet: #{f} (build_rbz.sh ausführen)")
end

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
