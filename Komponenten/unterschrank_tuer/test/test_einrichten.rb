# Test ohne SketchUp: Kurzhilfe, Tags und JT_Schrank werden in die ausgewählte Komponente geschrieben.
$LOAD_PATH.unshift(__dir__)
$EINRICHTEN_TEST = true
require 'sketchup_mock'
load File.expand_path('../einrichten.rb', __dir__)

T = UnterschrankTuer
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

# Nachbau der Teile aus Unterschrank.skp: Instanzname bzw. nur Definitionsname
def unterschrank(model)
  d = model.definitions.add('Unterschrank')
  d.set_attribute(T::DICT, '_name', 'Unterschrank')
  seite = model.definitions.add('Seite')
  { 'SeiteL' => seite, 'SeiteR' => seite, 'Boden' => model.definitions.add('Boden'),
    'StrebeVorn' => model.definitions.add('StrebeV'), 'StrebeHinten' => model.definitions.add('StrebeH'),
    'Rückwand' => model.definitions.add('Rückwand'), 'Front' => model.definitions.add('Front') }.each do |n, defn|
    i = d.entities.add_instance(defn, Geom::Transformation.translation([0, 0, 0]))
    i.name = n
  end
  (1..3).each do |k|
    eb = model.definitions.add("Boden##{k}")
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

# Zweiter Lauf behält das Kürzel, ein zweiter Schrank bekommt UST2
T.einrichten(model)
check(teile.first.layer.name == 'UST1_SeiteL', 'zweiter Lauf behält UST1')
inst2 = unterschrank(model)
model.selection.clear
model.selection.add(inst2)
T.einrichten(model)
tags2 = inst2.definition.entities.instances.map { |i| i.layer&.name }
check(tags2 == soll.map { |t| "UST2_#{t}" } + [nil], "zweiter Schrank UST2 (Definitionen mit #1): #{tags2.inspect}")

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
