# Test ohne SketchUp: Frontfarbe und Griffe an echten Schränken aus Komponenten/
# (mit der Mock-API erzeugt).
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
komp = File.expand_path('../../Komponenten', __dir__)
load File.join(komp, 'hochschrank/src/hochschrank/main.rb')
load File.join(komp, 'oberschrank/src/oberschrank/main.rb')
load File.join(komp, 'unterschrank_schubladen/src/unterschrank_schubladen/main.rb')
load File.expand_path('../src/jt_schrank_cnc/main.rb', __dir__)

S = JTools::SchrankCnc
F = S::Frontfarbe
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

def ocl(model, name, typ)
  m = model.materials[name] || model.materials.add(name)
  m.set_attribute('ladb_opencutlist', 'type', typ)
  m
end

model = Sketchup.active_model = Sketchup::Model.new
hs  = Hochschrank.erstellen({})
os1 = Oberschrank.erstellen({})
os1b = model.entities.add_instance(os1.definition, Geom::Transformation.translation([100, 0, 0])) # Kopie, gleiche Definition
os2 = Oberschrank.erstellen({ 'Art_Tuer' => 1.0 })
uss = UnterschrankSchubladen.erstellen({ 'Anz_Schubladen' => 3, 'Anteil_1' => 1.0, 'Anteil_2' => 1.0, 'Anteil_3' => 1.0 })
eiche = ocl(model, 'Front Eiche 19mm', 2)
grau  = ocl(model, 'Front Grau', 2)
ocl(model, 'Anleimer Eiche', 4)
ocl(model, 'Frontblende ohne OCL', 0)
melamin = model.materials['Melamin weiss']

# --- Materialien ---
check(F.frontmaterialien(model).map(&:name) == ['Front Eiche 19mm', 'Front Grau'], 'nur Frontmaterialien (OCL Typ 2, Name Front…)')
check(F.dekor('Front Eiche hell 19mm') == 'Eiche hell' && F.dekor('Front Grau') == 'Grau' && F.dekor('Front Weiss 19 mm') == 'Weiss', 'Dekor aus Name')
check(F.anleimer(model, eiche).name == 'Anleimer Eiche', 'vorhandener Anleimer zum Dekor')

# --- Teile und Bereiche ---
teile = S::Schraenke.teile(model)
check(teile.all? { |t| t.schrank }, 'jedes Teil hat seinen Schrank')
check(teile.map(&:schrank).uniq.size == 5, "5 Schränke gefunden (#{teile.map(&:schrank).uniq.size})")
alle = F.fronten(model)
check(alle.all?(&:front?) && alle.map(&:rolle).uniq.sort == %w[Front Tuer], 'Fronten = Rolle Front oder Tuer')
ober = F.fronten(model, kategorie: 'Oberschrank')
check(F.vorschau(ober) == '5 Fronten in 3 Schränken', "Vorschau Oberschränke: #{F.vorschau(ober)}")
check(F.vorschau(F.fronten(model, kategorie: 'Unterschrank')) == '3 Fronten in 1 Schrank', 'Vorschau Unterschrank')
hoch = F.fronten(model, kategorie: 'Hochschrank')
check(F.vorschau(hoch) == '4 Fronten in 1 Schrank', "Vorschau Hochschrank: #{F.vorschau(hoch)}")

def mat_von(model, kategorie, schrank = nil)
  F.fronten(model, kategorie: kategorie).select { |t| schrank.nil? || t.pfad.first.equal?(schrank) }.map { |t| t.inst.material&.name }.uniq
end

def kanten_von(t)
  t.inst.definition.entities.faces.map(&:material).compact.map(&:name).uniq
end

# --- Oberschränke auf Eiche ---
n = F.anwenden(model, ober, eiche)
check(n == ober.size, "alle Oberschrank-Fronten geändert (#{n})")
check(mat_von(model, 'Oberschrank') == ['Front Eiche 19mm'], 'Oberschränke Eiche')
check(mat_von(model, 'Hochschrank') == ['Melamin weiss'] && mat_von(model, 'Unterschrank') == ['Melamin weiss'], 'andere Schränke unverändert')
F.fronten(model, kategorie: 'Oberschrank').each do |t|
  check(kanten_von(t) == ['Anleimer Eiche'], "#{t.name}: Anleimer Eiche statt #{kanten_von(t)}")
  check(t.inst.get_attribute('dynamic_attributes', 'material') == 'Front Eiche 19mm', "#{t.name}: DC-Attribut material")
end
korpus = S::Schraenke.teile(model).reject(&:front?)
check(korpus.all? { |t| t.inst.material.equal?(melamin) }, 'Korpus und Schubkästen bleiben Melamin weiss')
check(korpus.select { |t| t.schrank.equal?(hs) }.all? { |t| kanten_von(t) - ['Anleimer Melamin weiss'] == [] }, 'Korpus-Anleimer unverändert')

# --- nur die ausgewählte Kopie auf Grau, mit Griff ---
model.selection.clear
model.selection.add(os1b)
f = F.fronten(model, kategorie: 'Oberschrank', auswahl: model.selection.to_a)
check(f.map { |t| t.pfad.first }.uniq == [os1b], 'nur der ausgewählte Schrank')
F.anwenden(model, f, grau, griff: { lochmass: 160, lage: 'rechts', hoehe: 35 })
check(!os1b.definition.equal?(os1.definition), 'Kopie wurde eindeutig gemacht')
check(mat_von(model, 'Oberschrank', os1b) == ['Front Grau'], 'Kopie Grau')
check(mat_von(model, 'Oberschrank', os1) == ['Front Eiche 19mm'], 'Original bleibt Eiche')
check(F.fronten(model, kategorie: 'Oberschrank').select { |t| t.pfad.first.equal?(os1) }.all? { |t| kanten_von(t) == ['Anleimer Eiche'] },
      'Original behält Anleimer Eiche')
ag = model.materials['Anleimer Grau']
check(ag && ag.get_attribute('ladb_opencutlist', 'type') == 4 && ag.get_attribute('ladb_opencutlist', 'edge_decremented') == true,
      'neuer Anleimer Grau als OCL-Kante')
gk = F.fronten(model, kategorie: 'Oberschrank').group_by { |t| t.pfad.first }
check(gk[os1b].all? { |t| t.jt('griff_lochmass') == 160.0 && t.jt('griff_lage') == 'rechts' && t.jt('griff_hoehe') == 35.0 }, 'Griff an der Kopie')
check(gk[os1].none? { |t| t.jt('griff_lochmass') }, 'kein Griff am Original')
check(os1b.definition.entities.instances.find { |i| i.name == 'SeiteL' }.definition.equal?(
        os1.definition.entities.instances.find { |i| i.name == 'SeiteL' }.definition), 'Korpusteile bleiben geteilt')

# --- Griffe entfernen ohne Materialwechsel ---
F.anwenden(model, F.fronten(model, auswahl: [os1b]), nil, griff: false)
check(F.fronten(model, auswahl: [os1b]).none? { |t| t.jt('griff_lochmass') }, 'Griff entfernt')
check(mat_von(model, 'Oberschrank', os1b) == ['Front Grau'], 'Material bleibt beim Griff entfernen')

# --- Unterschrank inkl. ausgeblendeter Schubladen ---
F.anwenden(model, F.fronten(model, kategorie: 'Unterschrank'), grau)
check(F.fronten(model, kategorie: 'Unterschrank').size == 6 && mat_von(model, 'Unterschrank') == ['Front Grau'],
      'alle 6 Unterschrank-Fronten (auch ausgeblendete) Grau')

# --- Dialog ---
module UI
  class << self
    attr_accessor :antwort, :meldungen
    def inputbox(*)
      antwort
    end
    def messagebox(m, *_)
      ((self.meldungen ||= []) << m) && IDOK
    end
  end
end
UI.antwort = ['Front Eiche 19mm', 'Nur Hochschränke', 'Nein', 'setzen', '128', 'Mitte', '40,5']
F.dialog(model)
check(UI.meldungen.last.start_with?('4 Fronten in 1 Schrank bekommen „Front Eiche 19mm“ und Griffbohrungen'), "Dialog-Frage: #{UI.meldungen.last}")
check(mat_von(model, 'Hochschrank') == ['Front Eiche 19mm'], 'Dialog: Hochschrank Eiche')
check(F.fronten(model, kategorie: 'Hochschrank').all? { |t| t.jt('griff_hoehe') == 40.5 && t.jt('griff_lochmass') == 128.0 }, 'Dialog: Griff')
UI.antwort = ['Front Eiche 19mm', 'Alle Schränke', 'Nein', 'setzen', 'abc', 'Mitte', '35']
F.dialog(model)
check(UI.meldungen.last.include?('keine Zahl'), 'Dialog: ungültiges Lochmaß')
m2 = Sketchup.active_model = Sketchup::Model.new
F.dialog(m2)
check(UI.meldungen.last.include?('kein Frontmaterial'), 'Dialog ohne Frontmaterial')

# .rbz muss zum Quelltext passen (sonst ./build_rbz.sh im Hauptordner ausführen)
rbz = File.expand_path('../schrank_cnc.rbz', __dir__)
Dir.chdir(File.expand_path('../src', __dir__)) { Dir['jt_schrank_cnc.rb'] + Dir['jt_schrank_cnc/*.rb'] }.each do |f|
  im_rbz = IO.popen(['unzip', '-p', rbz, f], err: File::NULL, &:read)
  check(im_rbz == File.read(File.expand_path("../src/#{f}", __dir__)), "rbz veraltet: #{f} (./build_rbz.sh im Hauptordner ausführen)")
end

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
