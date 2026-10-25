# Test ohne SketchUp: Kurzhilfe wird in die ausgewählte Komponente geschrieben.
$LOAD_PATH.unshift(__dir__)
$HILFE_TEST = true
require 'sketchup_mock'
load File.expand_path('../hilfe_einbetten.rb', __dir__)

T = UnterschrankTuerHilfe
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

model = Sketchup.active_model = Sketchup::Model.new
check(T.einbetten(model).empty?, 'ohne Auswahl passiert nichts')

d = model.definitions.add('Unterschrank')
d.set_attribute(T::DICT, '_name', 'Unterschrank')
inst = model.entities.add_instance(d, Geom::Transformation.translation([0, 0, 0]))
model.selection.add(inst)
check(T.einbetten(model) == [inst], 'Auswahl wird bearbeitet')
check(d.description == T::HILFE_KURZ, 'Beschreibung der Definition')
check(d.get_attribute(T::DICT, 'summary') == T::HILFE_KURZ, 'summary')
check(d.get_attribute(T::DICT, 'description') == T::HILFE, 'description')
check(%w[summary description].all? { |k| d.get_attribute(T::DICT, "_#{k}_access") == 'VIEW' }, 'nur anzeigen')
check(T::HILFE.include?(T::DOKU_URL), 'Link zur Doku')
check(File.exist?(File.expand_path('../README.md', __dir__)), 'README.md vorhanden')

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
