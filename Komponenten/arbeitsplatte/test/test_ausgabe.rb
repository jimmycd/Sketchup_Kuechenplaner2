# Test ohne SketchUp: Platten zeichnen (OCL, Tags, Anleimer), Dialog, neu berechnen
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
$VERBOSE = nil
haupt = File.expand_path('../../..', __dir__)
load File.expand_path('../src/arbeitsplatte/main.rb', __dir__)
load File.join(haupt, 'sketchup-tcn-export-plugin/src/jt_schrank_cnc/main.rb')

A = Arbeitsplatte
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end
def nah(a, b, eps = 0.01) = (a - b).abs < eps

$eingabe = nil
module UI
  def self.inputbox(beschriftung, vorgabe, listen, titel)
    $dialog = [beschriftung, vorgabe, listen, titel]
    $eingabe ? $eingabe.call(vorgabe.dup) : vorgabe
  end
end

class Tr
  def initialize(a) = @a = a
  def to_a = @a
end
def mm(v) = v / 25.4
def gerade(ox = 0, oy = 0) = Tr.new([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, mm(ox), mm(oy), 0, 1])
def gedreht90(ox, oy) = Tr.new([0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 1, 0, mm(ox), mm(oy), 0, 1])
def schrank(model, kz, breite, tr, typ: 'Unterschrank')
  d = model.definitions.add(kz)
  { 'schrank' => kz, 'typ' => typ, 'kategorie' => 'Unterschrank' }.each { |k, v| d.set_attribute('JT_Schrank', k, v) }
  b = Struct.new(:min, :max).new([0, mm(-20), 0], [mm(breite), mm(800), mm(720)])
  d.define_singleton_method(:bounds) { b }
  model.entities.add_instance(d, tr)
end

# L-Küche: hinten Blindeck 1000 + 600 (Front bei y = 0, Wand 820), links 2 × 600
model = Sketchup::Model.new
Sketchup.active_model = model
schrank(model, 'UES1', 1000, gerade(0, 20), typ: 'Eckschrank')
uss1 = schrank(model, 'USS1', 600, gerade(1000, 20))
schrank(model, 'USS2', 600, gedreht90(800, -650))
schrank(model, 'UST1', 600, gedreht90(800, -1250))

# --- Dialog: Vorgaben ergeben die Standardoptionen ---
erg = A::Modell.erkenne(model)
beschr, vorgabe, listen = A::Dialog.felder(erg)
check(beschr.size == 13 && beschr[10] == 'Ecke 1: Stoß' && beschr[11] == 'Ecke 1: durchlaufende Platte', "Felder: #{beschr}")
check(vorgabe[0] == 'Schichtstoff (Anleimer ab Werk)' && vorgabe[6] == A::Dialog::AUTO && vorgabe[10] == 'Gehrungsansatz', "Vorgaben: #{vorgabe}")
check(vorgabe[11].start_with?('Zeile 1 ') && listen[11].split('|').size == 2, "durchlaufend: #{vorgabe[11]} / #{listen[11]}")
o = A::Dialog.optionen(erg, vorgabe)
check(o[:art] == :schichtstoff && o[:staerke].nil? && o[:format].nil? && o[:ueberstand_vorn] == 20 && o[:radius] == 30 &&
      o[:ecken] == { 1 => { stoss: :gehrungsansatz, durchlaufend: 1 } }, "Optionen aus den Vorgaben: #{o}")
w = vorgabe.dup
w[6] = A::Dialog::EIGENES
w[7] = '3000 x 1000'
w[1] = '39,5'
check(A::Dialog.optionen(erg, w).values_at(:format, :staerke) == [[3000.0, 1000.0], 39.5], 'eigenes Format, Komma')
w[6] = '4100 × 650'
check(A::Dialog.optionen(erg, w)[:format] == [4100.0, 650.0], 'Standardformat aus der Liste')
w[6] = A::Dialog::EIGENES
w[7] = 'groß'
begin
  A::Dialog.optionen(erg, w)
  check(false, 'falsches Format')
rescue ArgumentError
end
# Vorgaben aus gespeicherten Optionen
_, v2, = A::Dialog.felder(erg, art: :massivholz, format: [4100.0, 900.0], ecken: { 1 => { stoss: :stumpf, durchlaufend: 2 } })
check(v2[0] == 'Massivholz' && v2[6] == '4100 × 900' && v2[10] == 'stumpf' && v2[11].start_with?('Zeile 2 '), "Vorgaben aus Optionen: #{v2}")

# --- Erzeugen über den Dialog (Ecke 1 auf stumpf umgestellt) ---
$eingabe = ->(v) { v[10] = 'stumpf'; v }
inst = A.erzeugen(model)
check(inst && inst.name == 'APL1', "Instanz APL1: #{inst && inst.name}")
d = inst.definition
check(d.get_attribute('JT_Schrank', 'typ') == 'Arbeitsplatte' && d.get_attribute('JT_Schrank', 'kategorie') == 'Arbeitsplatte' &&
      d.get_attribute('JT_Schrank', 'schrank') == 'APL1', 'JT_Schrank an der Definition')
platten = d.entities.instances
check(platten.size == 2 && platten.map { |i| i.layer.name } == %w[APL1_Platte1 APL1_Platte2], "Tags: #{platten.map { |i| i.layer.name }}")
check(platten.all? { |i| i.get_attribute('JT_Schrank', 'rolle') == 'Arbeitsplatte' && i.get_attribute('JT_Schrank', 'teil') =~ /\APlatte\d\z/ },
      'JT_Schrank am Teil, Rolle Arbeitsplatte')
mat = platten[0].material
check(mat.name == 'Arbeitsplatte Schichtstoff' && mat.get_attribute('ladb_opencutlist', 'type') == 2 &&
      mat.get_attribute('ladb_opencutlist', 'std_thicknesses') == '38mm', 'OCL Plattenwerkstoff 38 mm')
st = JSON.parse(d.get_attribute('JT_Arbeitsplatte', 'stoesse'))
check(st.size == 1 && st[0]['art'] == 'stumpf', "Stoß gespeichert: #{st}")
check(A::Ausgabe.optionen_lesen(d.get_attribute('JT_Arbeitsplatte', 'optionen'))[:ecken] == { 1 => { stoss: :stumpf, durchlaufend: 1 } },
      'Optionen gespeichert und gelesen')
check(JSON.parse(d.get_attribute('JT_Arbeitsplatte', 'schraenke')).sort == %w[UES1 USS1 USS2 UST1], 'Schränke gespeichert')

# Platte A (hinten, durchlaufend): Umriss, Lage, Flächen
pa = platten[0]
pkt = JSON.parse(pa.get_attribute('JT_Arbeitsplatte', 'punkte'))
check(pa.transformation.origin.map { |v| (v * 25.4).round(3) } == [5.0, -20.0, 720.0], "Lage Platte A: #{pa.transformation.origin.map { |v| (v * 25.4).round(3) }}")
faces = pa.definition.entities.faces
check(faces.size == pkt.size + 2, "Ober-, Unterseite und #{pkt.size} Seiten: #{faces.size}")
check(faces[0].normal.z < 0 && faces[1].normal.z > 0, 'Unterseite nach unten, Oberseite nach oben')
check(nah(faces[1].pts.map { |p| p[2] }.max * 25.4, 38), 'Oberseite in 38 mm')
kanten = JSON.parse(pa.get_attribute('JT_Arbeitsplatte', 'kanten'))
seiten = faces[2..]
mats = seiten.map { |f| f.material && f.material.name }
check(kanten.each_index.all? do |i|
  soll = { 'vorne' => 'Anleimer Arbeitsplatte ab Werk', 'frei' => 'Anleimer Arbeitsplatte' }[kanten[i]]
  mats[i] == soll
end, "Anleimer nach Kantenart: #{kanten.zip(mats)}")
werk = model.materials['Anleimer Arbeitsplatte ab Werk']
frei = model.materials['Anleimer Arbeitsplatte']
check(werk.get_attribute('ladb_opencutlist', 'type') == 4 && werk.attribute_dictionary('ladb_opencutlist')['edge_decremented'] == false,
      'Vorderkante ab Werk: Kante, wird nicht abgezogen')
check(frei.get_attribute('ladb_opencutlist', 'type') == 4 && frei.get_attribute('ladb_opencutlist', 'edge_decremented') == true &&
      frei.get_attribute('ladb_opencutlist', 'thickness') == '2mm', 'freie Enden: 2 mm, wird abgezogen')
check(mats.count('Anleimer Arbeitsplatte ab Werk') == 1 && mats.count('Anleimer Arbeitsplatte') == 1, "A: eine Vorderkante, ein freies Ende: #{mats}")

# Arbeitsplatte zählt nicht als Schrank, der TCN-Export übergeht sie (eigener Export folgt)
check(A::Modell.instanzen(model).none? { |i| i.equal?(inst) }, 'Arbeitsplatte ist kein Schrank für die Erkennung')
teile = JTools::SchrankCnc::Schraenke.teile(model)
check(teile.count { |t| t.rolle == 'Arbeitsplatte' } == 2 && JTools::SchrankCnc::Export.werkstuecke(model).empty?,
      'TCN-Export: Arbeitsplatten erkannt, aber übergangen')

# --- Neu berechnen nach dem Verschieben eines Schranks ---
uss1.instance_variable_set(:@transformation, gerade(1100, 20))
neu = A.neu_berechnen(model)
check(neu.size == 1 && neu[0].name == 'APL1' && !model.entities.instances.include?(inst), 'alte APL1 ersetzt')
pn = neu[0].definition.entities.instances
check(pn.size == 2 && JSON.parse(neu[0].definition.get_attribute('JT_Arbeitsplatte', 'stoesse'))[0]['art'] == 'stumpf',
      'gleiche Einstellungen (stumpf)')
check(pn[0].get_attribute('JT_Arbeitsplatte', 'laenge') == 1695.0, "Platte A 100 mm länger: #{pn[0].get_attribute('JT_Arbeitsplatte', 'laenge')}")
# markierte Arbeitsplatte: die Schränke werden trotzdem alle gefunden
model.selection << neu[0]
neu2 = A.neu_berechnen(model)
check(neu2.size == 1 && neu2[0].definition.entities.instances.size == 2, 'markierte Arbeitsplatte neu berechnet')
model.selection.clear

# --- Neu berechnen bezieht neue Schränke ein (alte Platte löschen, komplett neu) ---
ops = []
model.define_singleton_method(:start_operation) { |*a| ops << a }
uss3 = schrank(model, 'USS3', 600, gerade(1700, 20))
neu3 = A.neu_berechnen(model)
d3 = neu3[0].definition
check(neu3.size == 1 && neu3[0].name == 'APL1' && JSON.parse(d3.get_attribute('JT_Arbeitsplatte', 'schraenke')).include?('USS3'),
      "neuer Schrank USS3 einbezogen: #{d3.get_attribute('JT_Arbeitsplatte', 'schraenke')}")
check(d3.entities.instances[0].get_attribute('JT_Arbeitsplatte', 'laenge') == 2295.0,
      "Platte A über USS3 verlängert: #{d3.entities.instances[0].get_attribute('JT_Arbeitsplatte', 'laenge')}")
check(ops.size == 1, "ein Vorgang = ein Rückgängig: #{ops}")
check(model.entities.instances.count { |i| i.definition.get_attribute('JT_Schrank', 'typ') == 'Arbeitsplatte' } == 1, 'nur eine Arbeitsplatte im Modell')
check(model.definitions['Arbeitsplatte APL1'].equal?(d3) && model.definitions['Arbeitsplatte APL1#1'].nil?,
      'alte Definition entfernt, neue heißt wieder „Arbeitsplatte APL1“')
check(model.layers.to_a.map(&:name).grep(/^APL1_/).sort == %w[APL1_Platte1 APL1_Platte2], "Tags: #{model.layers.to_a.map(&:name)}")
# Hochschrank am Zeilenende (neu dazugestellt): Platte endet davor ohne Anleimer
hs = schrank(model, 'HS1', 600, gerade(2300, 20))
hs.definition.set_attribute('JT_Schrank', 'kategorie', 'Hochschrank')
hs.definition.set_attribute('JT_Schrank', 'typ', 'Hochschrank')
neu4 = A.neu_berechnen(model)
p4 = neu4[0].definition.entities.instances[0]
check(JSON.parse(p4.get_attribute('JT_Arbeitsplatte', 'kanten')).include?('hochschrank'),
      "Hochschrank am Ende erkannt: #{p4.get_attribute('JT_Arbeitsplatte', 'kanten')}")
# Schrank wieder weg: Platte wird wieder kürzer
model.entities.erase_entities(uss3, hs)
neu5 = A.neu_berechnen(model)
check(neu5[0].definition.entities.instances[0].get_attribute('JT_Arbeitsplatte', 'laenge') == 1695.0 &&
      !JSON.parse(neu5[0].definition.get_attribute('JT_Arbeitsplatte', 'schraenke')).include?('USS3'), 'USS3 entfernt: Platte wieder 1695')
model.singleton_class.send(:remove_method, :start_operation)

# --- Massivholz, zweite Arbeitsplatte bekommt APL2 ---
$eingabe = nil
inst2 = A.erzeugen(model, optionen: { art: :massivholz })
pl = inst2.definition.entities.instances
check(inst2.name == 'APL2' && pl.map { |i| i.layer.name } == %w[APL2_Platte1 APL2_Platte2], "APL2: #{pl.map { |i| i.layer.name }}")
check(pl[0].material.name == 'Arbeitsplatte Massivholz' && pl[0].material.get_attribute('ladb_opencutlist', 'type') == 1, 'Massivholz: OCL Typ 1')
check(pl.all? { |i| i.definition.entities.faces.none?(&:material) }, 'Massivholz ohne Anleimer')
check(nah(pl[0].definition.entities.faces[1].pts.map { |p| p[2] }.max * 25.4, 40), 'Massivholz 40 mm')

# Abbruch im Dialog
$eingabe = ->(_) { false }
check(A.erzeugen(model).nil?, 'Abbruch im Dialog erzeugt nichts')
# ohne Schränke
leer = Sketchup::Model.new
check(A.erzeugen(leer, optionen: {}).nil? && A.neu_berechnen(leer) == [], 'leeres Modell')

# --- Zwei getrennte Arbeitsplatten: neuer Schrank kommt zu seiner Gruppe, die andere bleibt ---
zwei = Sketchup::Model.new
Sketchup.active_model = zwei
a1 = schrank(zwei, 'US1', 600, gerade(0, 20))
b1 = schrank(zwei, 'US2', 600, gerade(5000, 20))
zwei.selection << a1
apl1 = A.erzeugen(zwei, optionen: {})
zwei.selection.clear
zwei.selection << b1
apl2 = A.erzeugen(zwei, optionen: { art: :massivholz })
namen = [apl1.name, apl2.name]
zwei.selection.clear
schrank(zwei, 'US3', 600, gerade(5600, 20))
r = A.neu_berechnen(zwei)
sk = ->(i) { JSON.parse(i.definition.get_attribute('JT_Arbeitsplatte', 'schraenke')) }
check(namen == %w[APL1 APL2] && r.map(&:name) == %w[APL1 APL2], "beide neu: #{r.map(&:name)}")
check(sk.(r[0]) == %w[US1] && sk.(r[1]).sort == %w[US2 US3], "Zuteilung: #{r.map { |i| sk.(i) }}")
check(r[1].definition.entities.instances[0].material.name == 'Arbeitsplatte Massivholz', 'APL2 behält Massivholz')
# markiert nur APL1: ein neuer, freier Schrank kommt zu APL1, APL2 bleibt unberührt
schrank(zwei, 'US4', 600, gerade(10_000, 20))
zwei.selection << r[0]
r2 = A.neu_berechnen(zwei)
zwei.selection.clear
check(r2.size == 1 && sk.(r2[0]).sort == %w[US1 US4] && zwei.entities.instances.include?(r[1]), "nur APL1: #{r2.map { |i| sk.(i) }}")
# alle Schränke einer Platte weg: die Platte wird gelöscht
zwei.entities.erase_entities(zwei.entities.instances.select { |i| %w[US2 US3].include?(i.definition.name) })
r3 = A.neu_berechnen(zwei)
check(r3.map(&:name) == %w[APL1] && zwei.entities.instances.none? { |i| i.name == 'APL2' }, "APL2 ohne Schränke gelöscht: #{r3.map(&:name)}")

# --- Eingesetzte Spüle (Gerät ragt über den Korpus): Schrank bleibt in seiner Zeile ---
gm = Sketchup::Model.new
Sketchup.active_model = gm
box = ->(mn, mx) { Struct.new(:min, :max).new(mn, mx) }
s1 = schrank(gm, 'US1', 600, gerade(0, 20))
s2 = schrank(gm, 'USP1', 600, gerade(600, 20))
kd = gm.definitions.add('Korpus')
k = s2.definition.entities.add_instance(kd, gerade)
k.define_singleton_method(:bounds) { box.([0, mm(-20), 0], [mm(600), mm(800), mm(720)]) }
gd = gm.definitions.add('Spuele')
gd.set_attribute('JT_Geraet', 'geraet', 'Spuele')
g = s2.definition.entities.add_instance(gd, gerade)
g.define_singleton_method(:bounds) { box.([mm(-50), mm(-80), mm(600)], [mm(650), mm(500), mm(1100)]) }
b = s2.definition.bounds
s2.definition.define_singleton_method(:bounds) { box.(b.min, [b.max[0], b.max[1], mm(1100)]) } # wie SketchUp: Gerät zählt mit
el = A::Modell.elemente(s2)
check(el.size == 1 && el[0][:z1] == 720.0 && el[0][:rechteck] == [600.0, 0.0, 1200.0, 820.0], "Korpus ohne Spüle: #{el}")
eg = A::Modell.erkenne(gm)
check(eg[:zeilen].size == 1 && eg[:zeilen][0][:elemente].map { |e| e[:kz] } == %w[US1 USP1], "eine Zeile mit Spüle: #{eg[:zeilen].map { |z| z[:elemente].map { |e| e[:kz] } }}")

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
