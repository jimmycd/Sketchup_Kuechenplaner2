# Test des Generators ohne SketchUp: Mock-API + kleiner DC-Formel-Auswerter.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
load File.expand_path('../src/unterschrank_kochfeld/main.rb', __dir__)

U = UnterschrankKochfeld
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
  e = { 'Breite' => 80.0, 'Hoehe' => 70.0, 'Tiefe' => 80.0, 'Anz_Schubladen' => anz }
  (1..3).each { |i| e["Anteil_#{i}"] = anteile[i - 1] || 1.0 }
  e.merge(extra)
end

def nl_soll(lt) = [65.0, ((lt - 0.3) / 5 + 0.000001).floor * 5.0].min

# Geometrische Prüfungen auf Basis der ausgewerteten Formeln
def pruefe(wurzel, anz, h, b, t, label)
  mk = wurzel.wert('Materialstaerke_Korpus')
  sp = wurzel.wert('Spaltbreite')
  hb = wurzel.wert('Hoehe_Blende')
  it = wurzel.wert('Installationstiefe')
  # Blende oben, bündig mit der Korpusoberkante
  bl = wurzel.finde('Blende')
  check((bl.wert('z') + bl.wert('lenz') - h).abs < EPS && (bl.wert('lenz') - hb).abs < EPS, "#{label}: Blende oben, Höhe #{hb}")
  check((bl.wert('lenx') - (b - sp)).abs < EPS && (bl.wert('x') - sp / 2).abs < EPS && (bl.wert('y') + sp).abs < EPS,
        "#{label}: Blende Breite/Lage wie Fronten")
  fronten = [[bl.wert('z'), h]]
  nl = nl_soll(t - it)
  check((wurzel.wert('NL') - nl).abs < EPS, "#{label}: NL #{wurzel.wert('NL')} statt #{nl}")
  sv = wurzel.finde('StrebeVorn')
  (1..3).each do |i|
    s = wurzel.finde("Schublade#{i}")
    sichtbar = s.wert('hidden') < 0.5
    check(sichtbar == (i <= anz), "#{label}: Sichtbarkeit Schublade #{i}")
    unless sichtbar
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
    kb = s.finde('KastenBoden'); kr = s.finde('KastenRueckwand')
    lw = b - 2 * mk
    mb = wurzel.wert('Materialstaerke_Kastenboden')
    check((s.wert('NL') - nl).abs < EPS, "#{label}: NL S#{i}")
    check((kb.wert('lenx') - (lw - 3.5)).abs < EPS && (kb.wert('x') - (mk + 1.75)).abs < EPS, "#{label}: Boden LW-35 mittig S#{i}")
    check((kb.wert('leny') - (nl - 1.0)).abs < EPS && (kb.wert('y') - mk).abs < EPS, "#{label}: Boden NL-10 S#{i}")
    check((kr.wert('y') + kr.wert('leny') - (kb.wert('y') + kb.wert('leny'))).abs < EPS, "#{label}: Rückwand hinten bündig S#{i}")
    check((kr.wert('z') - (kb.wert('z') + mb)).abs < EPS, "#{label}: Rückwand auf dem Boden S#{i}")
    # Installationsraum hinten bleibt frei
    check(kb.wert('y') + kb.wert('leny') <= mk + t - it + EPS, "#{label}: Kasten ragt in den Installationsraum S#{i}")
    kz0 = z0 + kb.wert('z'); kz1 = z0 + kr.wert('z') + kr.wert('lenz')
    check(kz0 >= mk - EPS, "#{label}: Kasten kollidiert mit Boden S#{i}")
    # Einbauraum des Geräts und Strebe vorn bleiben frei
    check(kz1 <= h - hb + EPS, "#{label}: Kasten S#{i} ragt in den Einbauraum (#{kz1.round(2)} > #{h - hb})")
    check(kz1 <= sv.wert('z') + EPS, "#{label}: Kasten S#{i} kollidiert mit der Strebe vorn")
    unten = z0 + kb.wert('z')
    loch = (unten + wurzel.wert('Hoehenoffset_Schiene') - wurzel.wert('Lochraster_Start')) / wurzel.wert('Lochraster')
    check((loch - loch.round).abs < 1e-6 && loch.round >= 0, "#{label}: Schiene S#{i} nicht im Lochraster")
    check(kz1 <= z0 + f.wert('lenz') - wurzel.wert('Kasten_Abstand_oben') + EPS || kr.wert('lenz') <= 2.0 + EPS,
          "#{label}: Kasten S#{i} Abstand oben")
  end
  fronten.sort!
  check(fronten.first[0].abs < EPS, "#{label}: unterste Front bei 0 (#{fronten.first[0]})")
  check((fronten.last[1] - h).abs < EPS, "#{label}: Blende bis Höhe")
  fronten.each_cons(2) { |a, c| check((c[0] - a[1] - sp).abs < EPS, "#{label}: Spalt zwischen Fronten #{a} #{c}") }
  # Korpus: keine Strebe hinten, Rückwand hinter dem Korpus
  check(wurzel.finde('StrebeHinten').nil?, "#{label}: keine Strebe hinten")
  check((wurzel.finde('SeiteR').wert('x') - (b - mk)).abs < EPS, "#{label}: SeiteR")
  check((wurzel.finde('Rückwand').wert('y') - (t + mk)).abs < EPS, "#{label}: Rückwand")
  # Strebe vorn: hochkant (Standard) oder flach, immer oben an der Korpusvorderkante
  flach = wurzel.wert('Strebe_Vorn') > 0.5
  bs = wurzel.wert('BreiteStreben')
  check((sv.wert('leny') - (flach ? bs : mk)).abs < EPS && (sv.wert('lenz') - (flach ? mk : bs)).abs < EPS,
        "#{label}: Strebe vorn #{flach ? 'flach' : 'hochkant'}")
  check((sv.wert('z') + sv.wert('lenz') - h).abs < EPS && (sv.wert('y') - mk).abs < EPS, "#{label}: Strebe vorn oben vorn")
  # Kanalausschnitt im Boden
  lw = b - 2 * mk
  links = wurzel.wert('Ausschnitt_Links'); kbr = wurzel.wert('Ausschnitt_Breite')
  soll = case wurzel.wert('Kanal_Lage').round
         when 0 then wurzel.wert('Kanal_Rand')
         when 2 then lw - kbr - wurzel.wert('Kanal_Rand')
         else (lw - kbr) / 2
         end
  check((links - soll).abs < EPS && links >= 0 && links + kbr <= lw + EPS, "#{label}: Ausschnitt links #{links}")
  check((wurzel.wert('Ausschnitt_Tiefe') - (it - 2 * wurzel.wert('Kanal_Steg'))).abs < EPS, "#{label}: Ausschnitt Tiefe")
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
  [2, [1, 1]],
  [1, [1]],
  [3, [1, 1, 1]],
  [3, [1, 1, 2], { 'Hoehe_Blende' => 25.0 }],
  [2, [1, 2], { 'Breite' => 60.0, 'Kanal_Lage' => 0.0 }],
  [2, [1, 1], { 'Breite' => 90.0, 'Kanal_Lage' => 2.0, 'Installationstiefe' => 20.0 }],
  [2, [1, 1], { 'Strebe_Vorn' => 1.0 }],
  [2, [1, 1], { 'Tiefe' => 56.0 }],
  [2, [1, 1], { 'Hoehenoffset_Schiene' => 1.1, 'Lueftung' => 1.0 }]
].each do |anz, ant, extra|
  Sketchup.active_model = Sketchup::Model.new
  e = eingabe(anz, ant, extra || {})
  inst = U.erstellen(e)
  w = Knoten.new(inst, inst.definition, nil)
  w.redraw
  label = "anz=#{anz} #{ant.inspect} #{extra.inspect}"
  p = U::DEFAULTS.merge(e)
  fr = pruefe(w, anz, p['Hoehe'], p['Breite'], p['Tiefe'], label)
  pruefe_geometrie(w, label)
  puts "#{label}: Fronten (cm) " + fr.map { |a, c| "#{a.round(2)}–#{c.round(2)}" }.join(', ') + ", NL #{w.wert('NL')}"

  # Rekonfiguration über die Komponentenoptionen simulieren
  d = inst.definition
  d.set_attribute(U::DICT, 'anz_schubladen', 3.0)
  [1.0, 2.0, 1.0].each_with_index { |v, i| d.set_attribute(U::DICT, "anteil_#{i + 1}", v) }
  d.set_attribute(U::DICT, 'hoehe', 80.0 / 2.54)
  d.set_attribute(U::DICT, 'breite', 90.0 / 2.54)
  d.set_attribute(U::DICT, 'tiefe', 60.0 / 2.54)
  d.set_attribute(U::DICT, 'hoehe_blende', 18.0 / 2.54)
  d.set_attribute(U::DICT, 'installationstiefe', 12.0 / 2.54)
  d.set_attribute(U::DICT, 'kanal_lage', 2.0)
  d.set_attribute(U::DICT, 'strebe_vorn', 1.0 - (p['Strebe_Vorn'] || 0))
  w2 = Knoten.new(inst, d, nil)
  w2.redraw
  pruefe(w2, 3, 80.0, 90.0, 60.0, "#{label} -> umkonfiguriert")
end

# --- OpenCutList: Material, Anleimer, Tags ---------------------------------
model = Sketchup.active_model = Sketchup::Model.new
inst1 = U.erstellen(eingabe(2, [1, 1]))
inst2 = U.erstellen(eingabe(3, [1, 1, 1]))
mel = model.materials['Melamin weiss']; anl = model.materials['Anleimer weiss']
check(mel.get_attribute('ladb_opencutlist', 'type') == 2, 'OCL: Melamin = Plattenmaterial')
check(anl.get_attribute('ladb_opencutlist', 'type') == 4, 'OCL: Anleimer = Kante')
check(anl.get_attribute('ladb_opencutlist', 'edge_decremented') == true, 'OCL: Anleimer wird abgezogen')

def teile(inst, pfad = [])
  inst.definition.entities.instances.flat_map do |c|
    c.definition.entities.faces.empty? ? teile(c, pfad + [c]) : [[c, pfad + [c]]]
  end
end

[[inst1, 'USK1'], [inst2, 'USK2']].each do |inst, kz|
  t = teile(inst)
  # SeiteL/R, Boden, StrebeVorn, Rückwand, Blende + je Schublade Front, KastenBoden, KastenRueckwand
  check(t.size == 6 + 3 * 3, "#{kz}: Anzahl Teile #{t.size}")
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
check(%w[USK1_SeiteL USK1_Rueckwand USK1_Blende USK1_StrebeVorn USK1_S2_Front USK2_S3_KastenRueckwand USK1_S1_Schublade].all? { |n| model.layers[n] }, 'Tag-Namen')
bl = teile(inst1).map(&:first).find { |c| c.name == 'Blende' }
check(bl.get_attribute(U::JT_DICT, 'rolle') == 'Front' && bl.get_attribute(U::JT_DICT, 'bereich') == '', 'Blende: Rolle Front, kein Bereich')
check(inst1.definition.get_attribute(U::JT_DICT, 'typ') == U::TYP, 'JT_Schrank am Schrank')

# --- Nische für die Geräte-Komponenten -----------------------------------
n = ->(k) { inst1.definition.get_attribute(U::NISCHE_DICT, k) }
check(n.('nische') == 'KF' && n.('geraet') == 'KochfeldAbzug80', "Nische: #{n.('nische')} #{n.('geraet')}")
check(n.('breite') == 762.0 && n.('hoehe') == 200.0 && n.('tiefe') == 800.0, "Nische: lichte Maße #{n.('breite')} #{n.('hoehe')} #{n.('tiefe')}")
check(n.('x') == 19.0 && n.('y') == 19.0 && n.('z') == 700.0, 'Nische: Einfügepunkt vorne links auf der Korpusoberkante')
check(n.('lueftung') == 'Umluft' && n.('kanal_lage') == 'mittig' && n.('installationstiefe') == 150.0, 'Nische: Lüftung/Kanal')
check(n.('kanal_breite') == 300.0 && n.('kanal_x') == 19.0 + 231.0 && n.('arbeitsplatte') == 40.0, "Nische: Kanal x #{n.('kanal_x')}, AP")
Sketchup.active_model = Sketchup::Model.new
ab = U.erstellen(eingabe(2, [1, 1], { 'Lueftung' => 1.0, 'Breite' => 90.0, 'Kanal_Lage' => 0.0 })).definition
check(ab.get_attribute(U::NISCHE_DICT, 'lueftung') == 'Abluft' && ab.get_attribute(U::NISCHE_DICT, 'geraet') == 'KochfeldAbzug90' &&
      ab.get_attribute(U::NISCHE_DICT, 'kanal_lage') == 'links', 'Nische: Abluft, 90 cm, links')

# Standardwerte: 2 gleich hohe Schubladen
std = U.berechne(U::DEFAULTS)
check((std[:fronten][0][:h] - std[:fronten][1][:h]).abs < EPS, 'Standard: 2 Schubladen 1:1')
check(U.parse_aufteilung('1;2', 2) == [1.0, 2.0], 'parse 1;2')

# --- Kurzhilfe in der Komponente ------------------------------------------
Sketchup.active_model = Sketchup::Model.new
hd = U.erstellen(eingabe(2, [1, 1])).definition
check(hd.description == U::HILFE_KURZ, 'Hilfe: Beschreibung der Definition')
check(hd.get_attribute(U::DICT, 'summary') == U::HILFE_KURZ, 'Hilfe: summary')
check(hd.get_attribute(U::DICT, 'description') == U::HILFE, 'Hilfe: description')
check(%w[summary description].all? { |k| hd.get_attribute(U::DICT, "_#{k}_access") == 'VIEW' }, 'Hilfe: nur anzeigen')
check(U::HILFE.include?(U::DOKU_URL), 'Hilfe: Link zur Doku')
check(File.exist?(File.expand_path('../README.md', __dir__)), 'README.md vorhanden')

# .rbz muss zum Quelltext passen (sonst ./build_rbz.sh im Hauptordner ausführen)
rbz = File.expand_path('../unterschrank_kochfeld.rbz', __dir__)
%w[unterschrank_kochfeld.rb unterschrank_kochfeld/main.rb].each do |f|
  im_rbz = IO.popen(['unzip', '-p', rbz, f], &:read)
  check(im_rbz == File.read(File.expand_path("../src/#{f}", __dir__)), "rbz veraltet: #{f} (./build_rbz.sh im Hauptordner ausführen)")
end

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
