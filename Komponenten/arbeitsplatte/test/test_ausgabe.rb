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
check(beschr.size == 12 && beschr[10] == 'Ecke 1: Stoß' && beschr[11] == 'Ecke 1: durchlaufende Platte', "Felder: #{beschr}")
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

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
