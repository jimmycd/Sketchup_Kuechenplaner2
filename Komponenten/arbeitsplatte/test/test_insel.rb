# Test ohne SketchUp: Arbeitsplatte auf einer Kücheninsel (Inselschränke, Komponenten/unterschrank_insel):
# kein Wandabstand, Sitzüberstand hinten mit Anleimer, erhöhte Theke, Warnungen
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
$VERBOSE = nil
load File.expand_path('../src/arbeitsplatte/main.rb', __dir__)

A = Arbeitsplatte
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end
def nah(a, b, eps = 0.01) = (a - b).abs < eps

class Tr
  def initialize(a) = @a = a
  def to_a = @a
end
def mm(v) = v / 25.4
def gerade(ox = 0, oy = 0) = Tr.new([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, mm(ox), mm(oy), 0, 1])

# Inselschrank wie der Generator (Werte in mm): Front bis y = -2, Korpus 520 tief ab y = 19, Rückwand 8,
# Verkleidung 19 -> Y_Hinten 547, Y_Aussen 566; Verkleidung/Wangen bis 100 unter den Korpus;
# mit Theke reicht die Definition bis 816 nach hinten und 1000 nach oben
def insel(model, kz, breite, x, theke: false, sitz: 300.0, dc_an_instanz: {})
  d = model.definitions.add(kz)
  { 'schrank' => kz, 'typ' => 'Unterschrank_Insel', 'kategorie' => 'Unterschrank', 'insel' => true }
    .each { |k, v| d.set_attribute('JT_Schrank', k, v) }
  { 'hoehe' => 700.0, 'y_hinten' => 547.0, 'y_aussen' => 566.0, 'sitzueberstand' => sitz }
    .each { |k, v| d.set_attribute('dynamic_attributes', k, mm(v)) }
  d.set_attribute('dynamic_attributes', 'theke', theke ? 1.0 : 0.0)
  b = Struct.new(:min, :max).new([0, mm(-2), mm(-100)], [mm(breite), mm(theke ? 816 : 566), mm(theke ? 1000 : 700)])
  d.define_singleton_method(:bounds) { b }
  i = model.entities.add_instance(d, gerade(x, 0))
  dc_an_instanz.each { |k, v| i.set_attribute('dynamic_attributes', k, v) }
  i
end

def normal(model, kz, x)
  d = model.definitions.add(kz)
  { 'schrank' => kz, 'typ' => 'Unterschrank_Schubladen', 'kategorie' => 'Unterschrank' }.each { |k, v| d.set_attribute('JT_Schrank', k, v) }
  b = Struct.new(:min, :max).new([0, mm(-2), 0], [mm(600), mm(547), mm(700)])
  d.define_singleton_method(:bounds) { b }
  model.entities.add_instance(d, gerade(x, 0))
end

def lauf(model, opt = {})
  erg = A::Modell.erkenne(model)
  [erg, A::Layout.berechne(erg, opt)]
end

def ys(p) = p[:punkte].map(&:last).minmax

# --- Insel aus zwei Schränken, Sitzüberstand 300 ---
m = Sketchup.active_model = Sketchup::Model.new
insel(m, 'USI1', 600, 1000)
insel(m, 'USI2', 600, 1600)
erg, lay = lauf(m)
z = erg[:zeilen].first
check(erg[:zeilen].size == 1 && z[:insel] && !z[:theke] && nah(z[:sitzueberstand], 300), "Insel erkannt: #{z.slice(:insel, :theke, :sitzueberstand)}")
check(erg[:warnungen].empty? && lay[:warnungen].empty?, "keine Warnungen: #{erg[:warnungen] + lay[:warnungen]}")
check(nah(z[:z], 700), "Platte auf dem Korpus, nicht auf der Theke/Wange: #{z[:z]}")
p = lay[:platten]
check(p.size == 1, "eine Platte: #{p.size}")
y0, y1 = ys(p[0])
check(nah(y0, -2 - 20) && nah(y1, 566 + 300), "Tiefe von 20 vor der Front bis 300 hinter die Verkleidung: #{[y0, y1]}")
check(p[0][:kanten].count(:frei) == 3 && p[0][:kanten].count(:vorne) == 1 && !p[0][:kanten].include?(:wand),
      "Kanten: vorne ab Werk, hinten und Enden frei: #{p[0][:kanten]}")
check(p[0][:format] == [4100.0, 900.0], "Format nach der Tiefe 888: #{p[0][:format]}")
# gezeichnet: Hinterkante bekommt den Anleimer
A::Ausgabe.bauen(m, erg, lay)
kante = m.materials['Anleimer Arbeitsplatte']
pd = m.definitions["APL1_Platte1"]
mit = pd.entities.grep(Sketchup::Face).select { |f| f.material.equal?(kante) }
check(mit.size == 3, "drei Kanten mit Anleimer (Enden und hinten): #{mit.size}")

# --- Sitzüberstand an der Instanz geändert (Komponentenoptionen), verschieden je Schrank ---
m = Sketchup.active_model = Sketchup::Model.new
insel(m, 'USI1', 600, 1000, dc_an_instanz: { 'sitzueberstand' => mm(250) })
insel(m, 'USI2', 600, 1600, sitz: 300)
erg, lay = lauf(m)
check(nah(erg[:zeilen].first[:sitzueberstand], 250) && nah(ys(lay[:platten][0])[1], 566 + 250), 'kleinster Sitzüberstand, Wert von der Instanz')
check(erg[:warnungen].any? { |w| w.include?('Sitzüberstand verschieden') }, "Warnung verschieden: #{erg[:warnungen]}")

# --- großer Sitzüberstand: Warnung Stützen ---
m = Sketchup.active_model = Sketchup::Model.new
insel(m, 'USI1', 1200, 0, sitz: 400)
erg, = lauf(m)
check(erg[:warnungen].any? { |w| w.include?('Stützen') }, "Warnung Stützen: #{erg[:warnungen]}")

# --- erhöhte Theke: Platte endet an der Thekenwand, ohne Anleimer hinten ---
m = Sketchup.active_model = Sketchup::Model.new
insel(m, 'USI1', 600, 1000, theke: true)
insel(m, 'USI2', 600, 1600, theke: true)
erg, lay = lauf(m)
z = erg[:zeilen].first
check(z[:theke] && nah(z[:z], 700), "Theke: Zeile auf Korpushöhe #{z.slice(:theke, :z)}")
y0, y1 = ys(lay[:platten][0])
check(nah(y1, 547) && nah(y0, -22), "Theke: Platte bis an die Verkleidung #{[y0, y1]}")
check(lay[:platten][0][:kanten].count(:theke) == 1 && lay[:platten][0][:kanten].count(:frei) == 2, "Theke: Kanten #{lay[:platten][0][:kanten]}")
A::Ausgabe.bauen(m, erg, lay)
pd = m.definitions["APL1_Platte1"]
check(pd.entities.grep(Sketchup::Face).count { |f| f.material.equal?(m.materials['Anleimer Arbeitsplatte']) } == 2,
      'Theke: Anleimer nur an den Enden')

# --- Theke nur an einem Schrank: Sitzüberstand, Warnung ---
m = Sketchup.active_model = Sketchup::Model.new
insel(m, 'USI1', 600, 1000, theke: true)
insel(m, 'USI2', 600, 1600)
erg, = lauf(m)
check(!erg[:zeilen].first[:theke] && erg[:warnungen].any? { |w| w.include?('erhöhter Theke') }, "Theke gemischt: #{erg[:warnungen]}")

# --- Insel und normaler Schrank in einer Zeile: wie an der Wand, Warnung ---
m = Sketchup.active_model = Sketchup::Model.new
insel(m, 'USI1', 600, 1000)
normal(m, 'USS1', 1600)
erg, = lauf(m)
check(!erg[:zeilen].first[:insel] && erg[:warnungen].any? { |w| w.include?('gemischt') }, "gemischt: #{erg[:warnungen]}")

# --- Wandzeile unverändert ---
m = Sketchup.active_model = Sketchup::Model.new
normal(m, 'USS1', 0)
erg, lay = lauf(m)
check(!erg[:zeilen].first[:insel] && nah(ys(lay[:platten][0])[1], 547 - 5) && lay[:platten][0][:kanten].include?(:wand), 'Wandzeile wie bisher')

# --- Generator liefert die Attribute, die die Arbeitsplatte liest ---
load File.expand_path('../../unterschrank_insel/src/unterschrank_insel/main.rb', __dir__)
m = Sketchup.active_model = Sketchup::Model.new
d = UnterschrankInsel.erstellen({ 'Tiefe' => 52.0 }).definition
check(d.get_attribute('JT_Schrank', 'insel') == true, 'Generator: JT_Schrank/insel')
{ 'hoehe' => 700, 'y_hinten' => 547, 'y_aussen' => 566, 'sitzueberstand' => 300 }.each do |k, v|
  w = d.get_attribute('dynamic_attributes', k)
  check(w && nah(w * 25.4, v), "Generator: #{k} = #{w && (w * 25.4).round(2)} statt #{v}")
end
check(d.get_attribute('dynamic_attributes', 'theke') == 0.0, 'Generator: theke')

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
