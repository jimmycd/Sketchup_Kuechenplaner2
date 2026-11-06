# Test ohne SketchUp: kopierte Schränke öffnen unabhängig (Jürgen 2026-11-06) –
# eine Schublade im kopierten Schrank darf nicht mit der im Original herausfahren.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
komp = File.expand_path('../../Komponenten', __dir__)
%w[unterschrank_schubladen oberschrank].each do |k|
  load File.join(komp, k, 'src', k, 'main.rb')
end
load File.expand_path('../src/jt_schrank_cnc/main.rb', __dir__)

K = JTools::SchrankCnc::Kopien
S = JTools::SchrankCnc::Schraenke
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

def schubladen(inst)
  S.instanzen(inst.definition.entities).select { |c| c.name =~ /\ASchublade\d\z/ }
end

# --- Unterschrank mit Schubladen kopiert (wie Rücken an Rücken) ---
model = Sketchup.active_model = Sketchup::Model.new
d = UnterschrankSchubladen.erzeuge(model, UnterschrankSchubladen::DEFAULTS.dup)
a = model.entities.add_instance(d, Geom::Transformation.new)
b = model.entities.add_instance(d, Geom::Transformation.new) # Kopie: gleiche Definition
check(K.kopien(model).size == 2, 'Kopie erkannt (zwei Schränke, eine Definition)')
check(schubladen(a).first.equal?(schubladen(b).first), 'vorher: Schublade 1 ist in beiden Schränken dieselbe Instanz (Fehlerursache)')

K.nachziehen(model)
check(!a.definition.equal?(b.definition), 'nachher: jede Kopie hat eine eigene Definition')
check(K.kopien(model).empty?, 'nachher: keine geteilten Schränke mehr')
check(schubladen(a).size == schubladen(b).size && schubladen(a).size >= 1, 'Schubladen in beiden Schränken vorhanden')
check(schubladen(a).zip(schubladen(b)).none? { |x, y| x.equal?(y) }, 'jede Schublade ist eine eigene Instanz je Schrank')
check(schubladen(b).all? { |s| K.beweglich?(s) }, 'Schubladen der Kopie behalten onClick')
# starre Teile dürfen geteilt bleiben (kein unnötiges Kopieren der Platten)
sa = S.instanzen(a.definition.entities).find { |c| c.name == 'SeiteL' }
sb = S.instanzen(b.definition.entities).find { |c| c.name == 'SeiteL' }
check(sa.definition.equal?(sb.definition), 'Seiten teilen weiter ihre Definition')
n = model.definitions.size
K.nachziehen(model)
check(model.definitions.size == n, 'zweiter Lauf ändert nichts')

# --- dreifach kopiert ---
model = Sketchup.active_model = Sketchup::Model.new
d = UnterschrankSchubladen.erzeuge(model, UnterschrankSchubladen::DEFAULTS.dup)
drei = 3.times.map { model.entities.add_instance(d, Geom::Transformation.new) }
check(K.eindeutig_machen(model) >= 2, 'drei Kopien: mindestens zwei neue Definitionen')
check(drei.map(&:definition).uniq.size == 3, 'drei Kopien: drei Definitionen')

# --- Oberschrank: Tür hängt in einem Türhalter (Zwischenebene) ---
model = Sketchup.active_model = Sketchup::Model.new
Oberschrank.erstellen({})
a = model.entities.grep(Sketchup::ComponentInstance).first
b = model.entities.add_instance(a.definition, Geom::Transformation.new)
K.nachziehen(model)
pfade = lambda do |inst, pfad = [], out = []|
  S.instanzen(S.definition(inst).entities).each do |c|
    K.beweglich?(c) ? out << (pfad + [c]) : pfade.call(c, pfad + [c], out)
  end
  out
end
pa = pfade.call(a)
pb = pfade.call(b)
check(!pa.empty? && pa.size == pb.size, "Oberschrank: bewegliche Teile gefunden (#{pa.size})")
check(pa.zip(pb).all? { |x, y| !x.last.equal?(y.last) }, 'Oberschrank: Türen je Schrank eigene Instanzen')
check((pa + pb).all? { |pf| pf[0..-2].all? { |i| i.definition.instances.size == 1 } },
      'Oberschrank: Zwischenebenen über der Tür (Türhalter) je Schrank eigene Definition')

puts $fehler.zero? ? 'OK: kopierte Schränke öffnen unabhängig' : "#{$fehler} Fehler"
exit($fehler.zero? ? 0 : 1)
