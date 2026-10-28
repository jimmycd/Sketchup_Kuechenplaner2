# Test ohne SketchUp: Kurzhilfe, Tags und JT_Schrank werden in die ausgewählte Komponente geschrieben.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
load File.expand_path('../src/unterschrank_tuer/main.rb', __dir__)

T = UnterschrankTuer
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

# Quader-Flächen einer Teildefinition; "anleimer" = Seiten mit Anleimer wie in der .skp
SEITEN = { xmin: [-1, 0, 0], xmax: [1, 0, 0], ymin: [0, -1, 0], ymax: [0, 1, 0], zmin: [0, 0, -1], zmax: [0, 0, 1] }.freeze
def platte(model, name, anleimer = [])
  d = model.definitions.add(name)
  SEITEN.each do |s, n|
    f = Sketchup::Face.new(d.entities, [], n)
    f.material = model.materials[T::ANLEIMER] || model.materials.add(T::ANLEIMER) if anleimer.include?(s)
    d.entities.faces << f
  end
  d
end

def anleimer_seiten(inst)
  inst.definition.entities.faces.select { |f| f.material&.name == T::ANLEIMER }.map do |f|
    n = f.normal.transform(inst.transformation)
    SEITEN.key(SEITEN.values.min_by { |v| v.zip([n.x, n.y, n.z]).sum { |a, b| (a - b)**2 } })
  end.sort
end

# Nachbau der Teile aus Unterschrank.skp: Instanzname bzw. nur Definitionsname.
# Anleimer wie in der von Hand gebauten .skp (falsch): Boden ohne, vordere Strebe
# vorne und hinten, hintere Strebe vorne. Mit strebe_geteilt nutzen beide Streben
# dieselbe Definition, die hintere um 180° gedreht.
def unterschrank(model, strebe_geteilt: false)
  d = model.definitions.add('Unterschrank')
  d.set_attribute(T::DICT, '_name', 'Unterschrank')
  d.set_attribute(T::DICT, 'anz_einlegeboeden', '1') # wie in der .skp als Text gespeichert
  seite = platte(model, 'Seite', %i[ymin])
  strebe_v = platte(model, 'StrebeV', %i[ymin ymax])
  strebe_h = strebe_geteilt ? strebe_v : platte(model, 'StrebeH', %i[ymin])
  { 'SeiteL' => seite, 'SeiteR' => seite, 'Boden' => platte(model, 'Boden'),
    'StrebeVorn' => strebe_v, 'StrebeHinten' => strebe_h,
    'Rückwand' => platte(model, 'Rückwand'), 'Front' => platte(model, 'Front', %i[xmin xmax zmin zmax]) }.each do |n, defn|
    tr = n == 'StrebeHinten' && strebe_geteilt ? Geom::Transformation.rotation([0, 0, 0], [0, 0, 1], Math::PI) : Geom::Transformation.translation([0, 0, 0])
    i = d.entities.add_instance(defn, tr)
    i.name = n
  end
  (1..3).each do |k|
    eb = platte(model, "Boden##{k}")
    eb.set_attribute(T::DICT, '_hidden_formula', " IF (Unterschrank!Anz_Einlegeboeden>#{k - 1},0,1)")
    d.entities.add_instance(eb, Geom::Transformation.translation([0, 0, 0]))
  end
  d.entities.add_instance(model.definitions.add('Griff'), Geom::Transformation.translation([0, 0, 0]))
  model.entities.add_instance(d, Geom::Transformation.translation([0, 0, 0]))
end

model = Sketchup.active_model = Sketchup::Model.new
check(T.einrichten(model).empty?, 'ohne Auswahl passiert nichts')

inst = unterschrank(model)
d = inst.definition
model.selection.add(inst)
check(T.einrichten(model) == [inst], 'Auswahl wird bearbeitet')
check(d.description == T::HILFE_KURZ, 'Beschreibung der Definition')
check(d.get_attribute(T::DICT, 'summary') == T::HILFE_KURZ, 'summary')
check(d.get_attribute(T::DICT, 'description') == T::HILFE, 'description')
check(%w[summary description].all? { |k| d.get_attribute(T::DICT, "_#{k}_access") == 'VIEW' }, 'nur anzeigen')
check(T::HILFE.include?(T::DOKU_URL), 'Link zur Doku')
check(File.exist?(File.expand_path('../README.md', __dir__)), 'README.md vorhanden')

# Tags und JT_Schrank
teile = d.entities.instances.reject { |i| i.definition.name == 'Griff' }
tags = teile.map { |i| i.layer&.name }
soll = %w[SeiteL SeiteR Boden StrebeVorn StrebeHinten Rueckwand Tuer Einlegeboden1 Einlegeboden2 Einlegeboden3]
check(tags == soll.map { |t| "UST1_#{t}" }, "Tags #{tags.inspect}")
teile.each do |i|
  jt = %w[schrank typ kategorie bereich teil rolle].to_h { |k| [k, i.get_attribute(T::JT_DICT, k)] }
  check(jt['schrank'] == 'UST1' && jt['typ'] == T::TYP && jt['kategorie'] == 'Unterschrank' && jt['bereich'] == '',
        "JT_Schrank #{jt.inspect}")
  check(i.layer.name == "UST1_#{jt['teil']}", "Tag passt zu JT_Schrank #{jt.inspect}")
  check(T::ROLLEN.value?(jt['rolle']), "Rolle #{jt['rolle'].inspect}")
end
griff = d.entities.instances.find { |i| i.definition.name == 'Griff' }
check(griff.layer.nil? && griff.get_attribute(T::JT_DICT, 'teil').nil?, 'unbekanntes Teil bleibt ohne Tag')
check(d.get_attribute(T::JT_DICT, 'kategorie') == 'Unterschrank', 'JT_Schrank am Schrank')

# Anleimer (OpenCutList): Boden, Einlegeböden und vordere Strebe nur vorne, hintere Strebe keine,
# Seiten und Tür bleiben wie in der .skp
KANTEN_SOLL = {
  'SeiteL' => %i[ymin], 'SeiteR' => %i[ymin], 'Boden' => %i[ymin], 'StrebeVorn' => %i[ymin], 'StrebeHinten' => [],
  'Rueckwand' => [], 'Tuer' => %i[xmax xmin zmax zmin],
  'Einlegeboden1' => %i[ymin], 'Einlegeboden2' => %i[ymin], 'Einlegeboden3' => %i[ymin]
}.freeze
pruefe_kanten = lambda do |schrank, was|
  schrank.definition.entities.instances.reject { |i| i.definition.name.start_with?('Griff') }.each do |i|
    teil = i.get_attribute(T::JT_DICT, 'teil')
    check(anleimer_seiten(i) == KANTEN_SOLL.fetch(teil), "#{was}: Anleimer #{teil} #{anleimer_seiten(i).inspect}")
  end
end
pruefe_kanten.(inst, 'Schrank')
anl = model.materials[T::ANLEIMER]
check(anl.get_attribute(T::OCL_DICT, 'type') == 4 && anl.get_attribute(T::OCL_DICT, 'edge_decremented') == true,
      'Anleimer ist in OCL eine Kante, 2 mm werden nur dort abgezogen')

# beide Streben mit derselben Definition, hintere gedreht: hintere bekommt eine eigene Definition
m2 = Sketchup.active_model = Sketchup::Model.new
geteilt = unterschrank(m2, strebe_geteilt: true)
m2.selection.add(geteilt)
T.einrichten(m2)
pruefe_kanten.(geteilt, 'geteilte Strebe')
sv, sh = %w[StrebeVorn StrebeHinten].map { |n| geteilt.definition.entities.instances.find { |i| i.name == n } }
check(sv.definition != sh.definition, 'Streben haben getrennte Definitionen')
Sketchup.active_model = model

# Einlegeböden: Formeln für Sichtbarkeit und Höhe (Fehler: Anzahl Einlegeböden wirkte nicht)
# Kleiner Formel-Auswerter für die DC-Formeln: Unterschrank!X, IF(), + - * / >=
def dc_wert(formel, attr)
  ruby = formel.gsub(/Unterschrank!(\w+)/) { attr.fetch($1).to_s }.gsub('IF(', 'wenn(')
  Object.new.tap { |o| o.define_singleton_method(:wenn) { |b, a, c| b ? a : c } }.instance_eval(ruby).to_f
end

boeden = (1..3).map { |k| teile.find { |i| i.layer.name == "UST1_Einlegeboden#{k}" } }
boeden.each_with_index do |b, idx|
  k = idx + 1
  check(b.get_attribute(T::DICT, '_name') == "Einlegeboden#{k}", "Name Einlegeboden#{k}")
  [b, b.definition].each do |e|
    f = e.get_attribute(T::DICT, '_hidden_formula')
    check(f == "IF(Unterschrank!Anz_Einlegeboeden>=#{k},0,1)", "Sichtbarkeitsformel #{k}: #{f.inspect}")
  end
  check(b.get_attribute(T::DICT, '_z_formula').to_s.include?('Anz_Einlegeboeden'), "Höhenformel #{k}")
  check(b.hidden == (k > 1), "Einlegeboden#{k} sofort richtig sichtbar bei Anzahl 1")
end
h, mk = 70.0, 1.9
(0..3).each do |n|
  attr = { 'Hoehe' => h, 'Materialstaerke_Korpus' => mk, 'Anz_Einlegeboeden' => n }
  sichtbar = boeden.select { |b| dc_wert(b.get_attribute(T::DICT, '_hidden_formula'), attr).zero? }
  check(sichtbar == boeden.first(n), "Anzahl #{n}: #{sichtbar.size} Böden sichtbar")
  zs = sichtbar.map { |b| dc_wert(b.get_attribute(T::DICT, '_z_formula'), attr) }
  # lichte Fächer zwischen Boden (Oberkante mk), den Einlegeböden und den Streben (Unterkante h-mk)
  kanten = [mk] + zs.flat_map { |z| [z, z + mk] } + [h - mk]
  faecher = kanten.each_slice(2).map { |a, b| (b - a).round(6) }
  check(faecher.uniq.size == 1 && faecher.first > 0, "Anzahl #{n}: gleich hohe Fächer #{faecher.inspect}")
  (boeden - sichtbar).each do |b|
    check(dc_wert(b.get_attribute(T::DICT, '_z_formula'), attr) == mk, "Anzahl #{n}: ausgeblendeter Boden liegt unten")
  end
end

# Zweiter Lauf behält das Kürzel, ein zweiter Schrank bekommt UST2
T.einrichten(model)
check(teile.first.layer.name == 'UST1_SeiteL', 'zweiter Lauf behält UST1')
inst2 = unterschrank(model)
model.selection.clear
model.selection.add(inst2)
T.einrichten(model)
tags2 = inst2.definition.entities.instances.map { |i| i.layer&.name }
check(tags2 == soll.map { |t| "UST2_#{t}" } + [nil], "zweiter Schrank UST2 (Definitionen mit #1): #{tags2.inspect}")

# Menü: Unterschrank.skp einfügen, jedes Exemplar mit eigenem Kürzel und eigener Definition
class Sketchup::Definitions
  attr_accessor :geladen
  def load(pfad) = (@geladen ||= {})[pfad] ||= yield_load(pfad)
  def yield_load(pfad)
    raise "falscher Pfad #{pfad}" unless File.exist?(pfad)
    m = Sketchup.active_model
    tmp = unterschrank(m) # baut die Definition im Modell, Instanz wieder entfernen
    m.entities.instances.delete(tmp)
    tmp.definition
  end
end
class Sketchup::ComponentDefinition
  def instances = Sketchup.active_model.entities.instances.select { |i| i.definition == self }
  def delete_attribute(d, k) = dicts[d]&.delete(k)
end
check(File.exist?(T::SKP), 'Unterschrank.skp liegt in der Erweiterung')
model = Sketchup.active_model = Sketchup::Model.new
e1 = T.einfuegen(model)
e2 = T.einfuegen(model)
tags_e = [e1, e2].map { |e| e.definition.entities.instances.map { |i| i.layer&.name }.compact.map { |t| t[/\A[A-Z]+\d+/] }.uniq }
check(tags_e == [['UST1'], ['UST2']], "eingefügte Schränke UST1/UST2: #{tags_e.inspect}")
check(e1.definition != e2.definition, 'zweiter Schrank hat eigene Definition')
check(e2.definition.description == T::HILFE_KURZ, 'Kurzhilfe am eingefügten Schrank')
check(e2.definition.get_attribute(T::JT_DICT, 'schrank') == 'UST2', 'JT_Schrank am zweiten Schrank')
check(model.selection.to_a == [e2], 'eingefügter Schrank ist ausgewählt')

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
