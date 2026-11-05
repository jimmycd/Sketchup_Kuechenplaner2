# Test ohne SketchUp: Schrankzeilen, Ecken (L/U) und Begrenzungen erkennen
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
komp = File.expand_path('../..', __dir__)
$VERBOSE = nil
%w[unterschrank_schubladen eckschrank].each { |k| load File.join(komp, k, 'src', k, 'main.rb') }
load File.expand_path('../src/arbeitsplatte/main.rb', __dir__)

E = Arbeitsplatte::Erkennung
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

# Grundriss: hintere Wand bei y = 820, linke Wand bei x = 0. Schränke 820 tief
# (Korpus 800 + Front), Front der hinteren Zeile bei y = 0.
def el(kz, rechteck, front = :ny, typ: 'Unterschrank', kat: 'Unterschrank', z1: 720.0)
  { kz: kz, typ: typ, kategorie: kat, rechteck: rechteck, front: front, z0: 0.0, z1: z1 }
end
def hinten(kz, x0, x1, **o) = el(kz, [x0, 0.0, x1, 820.0], :ny, **o)
def links(kz, y0, y1, **o) = el(kz, [0.0, y0, 820.0, y1], :px, **o)
def rechts(kz, y0, y1, xw = 3000.0, **o) = el(kz, [xw - 820.0, y0, xw, y1], :nx, **o)

# --- gerade Zeile ---
erg = E.erkenne([hinten('USS1', 0, 600), hinten('UST1', 600, 1200), hinten('USP1', 1200, 1800)])
z = erg[:zeilen]
check(z.size == 1 && z[0][:elemente].map { |e| e[:kz] } == %w[USS1 UST1 USP1], "eine Zeile mit 3 Schränken: #{z.map { |x| x[:elemente].map { |e| e[:kz] } }}")
check(z[0][:s0] == 0 && z[0][:s1] == 1800 && z[0][:front_linie] == 0 && z[0][:wand] == 820, "Maße der Zeile: #{z[0].slice(:s0, :s1, :front_linie, :wand)}")
check(z[0][:enden].values.all? { |e| e[:art] == :frei }, 'beide Enden frei')
check(erg[:formen] == [{ form: 'I', zeilen: [1] }], "Form I: #{erg[:formen]}")
check(erg[:warnungen].empty?, "keine Warnungen: #{erg[:warnungen]}")
check(E.zusammenfassung(erg).include?('Zeile 1: USS1 UST1 USP1 · Länge 1800 mm, Tiefe 820 mm'), E.zusammenfassung(erg))

# Reihenfolge der Eingabe egal, Oberschränke werden übergangen
erg = E.erkenne([hinten('USP1', 1200, 1800), el('OS1', [0, 450, 600, 820], kat: 'Oberschrank'), hinten('USS1', 0, 600)])
check(erg[:zeilen].size == 1 && erg[:zeilen][0][:elemente].map { |e| e[:kz] } == %w[USS1 USP1], 'sortiert, Oberschrank übergangen')
check(erg[:zeilen][0][:luecken] == [[600.0, 1200.0]], "Lücke 600 überbrückt: #{erg[:zeilen][0][:luecken]}")

# Lücke größer als 650 trennt
erg = E.erkenne([hinten('USS1', 0, 600), hinten('USS2', 1300, 1900)])
check(erg[:zeilen].size == 2 && erg[:formen].map { |f| f[:form] } == %w[I I], 'Lücke 700 trennt die Zeilen')
erg = E.erkenne([hinten('USS1', 0, 600), hinten('USS2', 1300, 1900)], max_luecke: 800.0)
check(erg[:zeilen].size == 1, 'max_luecke einstellbar')

# Hochschrank am Ende, anderer Unterschrank tiefer (andere Frontlinie) = eigene Zeile
erg = E.erkenne([hinten('USS1', 0, 600), hinten('USS2', 600, 1200),
                 el('HS1', [1202.0, -5.0, 1802.0, 820.0], kat: 'Hochschrank', typ: 'Hochschrank')])
check(erg[:zeilen][0][:enden][:ende] == { art: :hochschrank, kz: 'HS1', fuge: 2.0 }, "Hochschrank am Ende: #{erg[:zeilen][0][:enden]}")
check(erg[:zeilen][0][:enden][:start][:art] == :frei, 'Anfang frei')
erg = E.erkenne([el('HS1', [-600.0, -5.0, 0.0, 820.0], kat: 'Hochschrank'), hinten('USS1', 0, 600)])
check(erg[:zeilen][0][:enden][:start][:art] == :hochschrank, 'Hochschrank am Anfang')

# Überlappung und Schrank nicht an der Wand
erg = E.erkenne([hinten('USS1', 0, 600), hinten('USS2', 550, 1150), el('UST1', [1150, 0, 1750, 800])])
check(erg[:warnungen].any? { |w| w.include?('USS2 überlappt USS1 um 50.0 mm') }, "Überlappung gemeldet: #{erg[:warnungen]}")
check(erg[:warnungen].any? { |w| w.include?('UST1 steht nicht an der Wand (20.0 mm') }, "Abstand zur Wand gemeldet: #{erg[:warnungen]}")

# Unterschiedliche Oberkante: zwei Zeilen
erg = E.erkenne([hinten('USS1', 0, 600), hinten('USS2', 600, 1200, z1: 760.0)])
check(erg[:zeilen].size == 2, 'andere Oberkante = andere Zeile')

# Abschlussregal ohne Front an derselben Wand (Front 21 mm zurück): gleiche Zeile, Platte gleich tief
erg = E.erkenne([hinten('USP1', 0, 600), el('RA1', [600, 21.0, 900, 820.0])])
z = erg[:zeilen]
check(z.size == 1 && z[0][:elemente].map { |e| e[:kz] } == %w[USP1 RA1] && z[0][:front_linie] == 0 && z[0][:wand] == 820,
      "Regal ohne Front in der Zeile: #{z.map { |x| [x[:elemente].map { |e| e[:kz] }, x[:front_linie]] }}")
lay = Arbeitsplatte::Layout.berechne(erg, {})
check(lay[:platten].size == 1 && lay[:platten][0][:punkte].size == 4 && lay[:platten][0][:breite] == 835.0,
      "eine Platte, durchgehend gleich tief: #{lay[:platten].map { |p| [p[:laenge], p[:breite]] }}")
# zurückstehend, aber nicht an derselben Wand (flacher Schrank vorn bündig ist schon eine Zeile): weit zurück = eigene Zeile
erg = E.erkenne([hinten('USS1', 0, 600), el('X1', [600, 200.0, 1200, 820.0])])
check(erg[:zeilen].size == 2, 'Front 200 mm zurück bleibt eine eigene Zeile')

# Insel Rücken an Rücken (markierte Schränke): eine Zeile, eine Platte über beide, vorn und hinten Überstand
insel = [hinten('IA', 0, 600), el('IB', [0.0, 840.0, 600.0, 1660.0], :py)]
check(E.erkenne(insel, toleranz_ruecken: 10.0)[:zeilen].size == 2, 'ohne Markierung, Rückseiten 20 mm auseinander: zwei Zeilen')
direkt = [hinten('IA', 0, 600), el('IB', [0.0, 820.0, 600.0, 1640.0], :py)]
dz = E.erkenne(direkt)[:zeilen]
check(dz.size == 1 && dz[0][:wand] == 1640.0 && Arbeitsplatte::Layout.berechne(E.erkenne(direkt), {})[:platten].map { |p| p[:breite] } == [1680.0],
      "direkt Rücken an Rücken auch ohne Markierung eine Platte: #{dz.map { |x| x.slice(:front_linie, :wand) }}")
erg = E.erkenne(insel, rueckenverbund: true)
z = erg[:zeilen]
check(z.size == 1 && z[0][:elemente].map { |e| e[:kz] }.sort == %w[IA IB] && z[0][:wand] == 1660.0, "Rücken an Rücken: #{z.map { |x| x.slice(:front_linie, :wand) }}")
lay = Arbeitsplatte::Layout.berechne(erg, {})
pl = lay[:platten]
check(pl.size == 1 && pl[0][:breite] == 1700.0 && pl[0][:kanten].include?(:frei),
      "eine Platte 1700 tief (20 vorn + 1660 + 20 hinten): #{pl.map { |p| [p[:laenge], p[:breite], p[:kanten]] }}")
# Spüle im Schrank auf der Rückseite: Ausschnitt von der hinteren Kante gemessen
sp = [hinten('IA', 0, 600), el('USP1', [0.0, 840.0, 600.0, 1660.0], :py, typ: 'Spuelenschrank')]
ae = E.erkenne(sp, rueckenverbund: true)
au = Arbeitsplatte::Ausschnitte.fuer_zeile(ae[:zeilen][0], Arbeitsplatte::Layout::OPTIONEN.merge(ausschnitte: {}))
check(au.size == 1 && au[0][:rechteck][3] < 1680.0 && au[0][:rechteck][1] > 840.0, "Spülenausschnitt auf der Rückseite: #{au.map { |x| x[:rechteck] }}")
# Wangen (19 mm, bündig mit der Front, an beiden Enden): Platte geht durchgehend gleich tief darüber
wg = [hinten('US1', 0, 600), el('WG1', [-19.0, -2.0, 0.0, 820.0], typ: 'Wange'), el('WG2', [600.0, 5.0, 619.0, 800.0], typ: 'Wange')]
we = E.erkenne(wg)
check(we[:zeilen].size == 1 && we[:zeilen][0][:s0] == -19.0 && we[:zeilen][0][:s1] == 619.0 && we[:zeilen][0][:elemente].map { |e| e[:kz] } == %w[US1],
      "Wangen an den Enden: #{we[:zeilen].map { |x| x.slice(:s0, :s1, :front_linie) }}")
wl = Arbeitsplatte::Layout.berechne(we, {})[:platten]
check(wl.size == 1 && wl[0][:punkte].size == 4 && wl[0][:breite] == 835.0, "eine Platte über Wangen: #{wl.map { |p| [p[:laenge], p[:breite]] }}")
# Insel Rücken an Rücken mit Wange über die ganze Tiefe
wi = E.erkenne([hinten('IA', 0, 600), el('IB', [0.0, 820.0, 600.0, 1640.0], :py), el('WG3', [-19.0, 0.0, 0.0, 1640.0], typ: 'Wange')])
check(wi[:zeilen].size == 1 && wi[:zeilen][0][:s0] == -19.0, "Insel mit Wange: #{wi[:zeilen].map { |x| x.slice(:s0, :s1) }}")
# Rückseiten zu weit auseinander: getrennt
check(E.erkenne([hinten('IA', 0, 600), el('IB', [0.0, 1600.0, 600.0, 2420.0], :py)], rueckenverbund: true)[:zeilen].size == 2,
      'Rückseiten 780 mm auseinander: zwei Zeilen')
# markierte Schränke mit großer Lücke längs: eine Zeile
check(E.erkenne([hinten('IA', 0, 600), hinten('IC', 1600, 2200)], max_luecke: 10_000.0)[:zeilen].size == 1, 'Lücke 1000 überbrückt')

# --- L mit Blindeck: Blindeck UES1 an der linken Wand, Zeile B mit Passleiste 50 davor ---
blind = hinten('UES1', 0, 1000, typ: 'Eckschrank')
erg = E.erkenne([blind, hinten('USS1', 1000, 1600), links('USS2', -650, -50), links('UST1', -1250, -650)])
check(erg[:zeilen].size == 2 && erg[:ecken].size == 1, "2 Zeilen, 1 Ecke: #{erg[:zeilen].size}/#{erg[:ecken].size}")
a = erg[:zeilen].find { |x| x[:front] == :ny }
b = erg[:zeilen].find { |x| x[:front] == :px }
e = erg[:ecken].first
check(e && e[:schraenke_in_ecke] == a[:nr] && e[:eckschrank] == 'UES1', "Ecke über dem Blindeck: #{e}")
check(e && e[:passleiste] == 50.0, "Passleiste 50: #{e && e[:passleiste]}")
check(e && e[:innen] == [820.0, 0.0] && e[:aussen] == [0.0, 820.0], "Innen- und Außenecke: #{e && e.slice(:innen, :aussen)}")
check(a[:enden][:start] == { art: :ecke, ecke: 1 } && a[:enden][:ende][:art] == :frei, "Zeile A: Ecke am Anfang #{a[:enden]}")
check(b[:enden][:ende] == { art: :ecke, ecke: 1 } && b[:enden][:start][:art] == :frei, "Zeile B: Ecke am Ende #{b[:enden]}")
check(erg[:formen] == [{ form: 'L', zeilen: [1, 2] }], "Form L: #{erg[:formen]}")
check(E.zusammenfassung(erg).include?('Ecke 1: Zeile 1 + 2, Eckschrank UES1, Passleiste 50 mm'), E.zusammenfassung(erg))

# L andersherum: Zeile B steht in der Ecke (bis an die hintere Wand), A stößt an ihre Front
erg = E.erkenne([links('UES1', -200, 820, typ: 'Eckschrank'), links('USS1', -800, -200), hinten('USS2', 820, 1420)])
e = erg[:ecken].first
b = erg[:zeilen].find { |x| x[:front] == :px }
check(e && e[:schraenke_in_ecke] == b[:nr] && e[:passleiste] == 0.0 && e[:eckschrank] == 'UES1', "B in der Ecke: #{e}")

# Kurze Zeile (nur ein Schrank) an der Ecke
erg = E.erkenne([hinten('USS1', 0, 900), links('USS2', -600, 0)])
check(erg[:ecken].size == 1 && erg[:ecken][0][:enden] == { 1 => :start, 2 => :ende }, "kurze Zeile: #{erg[:ecken]}")

# --- U-Küche: A hinten 3000, B links, C rechts, A läuft mit Schränken in beide Ecken ---
u = (0...5).map { |i| hinten("USS#{i + 1}", i * 600, (i + 1) * 600) } +
    [links('UST1', -1800, -1200), links('UST2', -1200, -600), links('UST3', -600, 0),
     rechts('USP1', -1200, -600), rechts('USK1', -600, 0)]
erg = E.erkenne(u)
check(erg[:zeilen].size == 3 && erg[:ecken].size == 2, "U: 3 Zeilen, 2 Ecken: #{erg[:zeilen].size}/#{erg[:ecken].size}")
check(erg[:formen].map { |f| f[:form] } == ['U'], "Form U: #{erg[:formen]}")
mitte = erg[:zeilen].find { |x| x[:front] == :ny }
check(mitte[:enden].values.map { |x| x[:art] } == %i[ecke ecke], "Mittelzeile hat zwei Ecken: #{mitte[:enden]}")
check(erg[:ecken].all? { |x| x[:schraenke_in_ecke] == mitte[:nr] }, 'Mittelzeile steht in beiden Ecken')
c = erg[:zeilen].find { |x| x[:front] == :nx }
check(c[:front_linie] == 2180 && c[:wand] == 3000 && c[:enden][:ende][:art] == :ecke, "rechte Zeile: #{c.slice(:front_linie, :wand, :enden)}")
check(erg[:warnungen].empty?, "U ohne Warnungen: #{erg[:warnungen]}")

# Ecke mit unterschiedlicher Oberkante wird gemeldet (Zeilen bleiben getrennt erkannt)
erg = E.erkenne([hinten('USS1', 0, 900), links('USS2', -600, 0, z1: 750.0)])
check(erg[:ecken].size == 1 && erg[:warnungen].any? { |w| w.include?('Oberkanten unterschiedlich') }, "Höhe in der Ecke: #{erg[:warnungen]}")

# Zeilen ohne Berührung: keine Ecke
erg = E.erkenne([hinten('USS1', 1500, 2100), links('USS2', -1800, -1200)])
check(erg[:ecken].empty? && erg[:formen].size == 2, 'weit entfernte Zeilen: keine Ecke')

# --- Aus dem Modell lesen ---
class Tr
  def initialize(a) = @a = a
  def to_a = @a
end
def mm(v) = v / 25.4
def gerade(ox = 0, oy = 0) = Tr.new([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, mm(ox), mm(oy), 0, 1])
def gedreht90(ox, oy) = Tr.new([0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 1, 0, mm(ox), mm(oy), 0, 1])
def schrankdef(model, kz, kat, min, max, typ: 'Unterschrank')
  d = model.definitions.add(kz)
  { 'schrank' => kz, 'typ' => typ, 'kategorie' => kat }.each { |k, v| d.set_attribute('JT_Schrank', k, v) }
  b = Struct.new(:min, :max).new(min.map { |v| mm(v) }, max.map { |v| mm(v) })
  d.define_singleton_method(:bounds) { b }
  d
end

M = Arbeitsplatte::Modell
model = Sketchup::Model.new
Sketchup.active_model = model
# Unterschrank wie die Generatoren: Korpus y 0..800, Front davor bis -21, Höhe 720
us = schrankdef(model, 'USS1', 'Unterschrank', [0, -21, 0], [600, 800, 720])
i1 = model.entities.add_instance(us, gerade(1000, 21))
els = M.elemente(i1)
check(els.size == 1 && els[0][:rechteck] == [1000.0, 0.0, 1600.0, 821.0] && els[0][:front] == :ny && els[0][:z1] == 720.0,
      "gerader Schrank: #{els}")
# um 90° gedreht an der linken Wand: Front zeigt nach +x
i2 = model.entities.add_instance(us, gedreht90(800, -600))
els = M.elemente(i2)
check(els.size == 1 && els[0][:front] == :px && els[0][:rechteck] == [0.0, -600.0, 821.0, 0.0], "gedrehter Schrank: #{els}")
# schräg: übergangen mit Warnung
w = []
s = Math.sqrt(0.5)
i3 = model.entities.add_instance(us, Tr.new([s, s, 0, 0, -s, s, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]))
check(M.elemente(i3, w).empty? && w == ['USS1 steht schräg, wird übergangen'], "schräger Schrank: #{w}")
model.entities.instances.delete(i3)

# L-Eckschrank: Schenkel A 1500 an der hinteren Wand, Schenkel B 1500 an der linken
ld = schrankdef(model, 'UES1', 'Unterschrank', [0, -673, 0], [1500, 827, 720], typ: 'Eckschrank')
ld.set_attribute('JT_Eckschrank', 'l_gebaut', [150.0, 150.0, 80.0])
ld.set_attribute('dynamic_attributes', 'spaltbreite', mm(2))
els = M.elemente(model.entities.add_instance(ld, gerade(5000, -827)))
check(els.size == 2 && els.map { |x| x[:schenkel] } == %w[A B], "L-Eckschrank: zwei Schenkel #{els}")
check(els[0][:front] == :ny && els[0][:rechteck] == [5000.0, -829.0, 6500.0, 0.0], "Schenkel A: #{els[0]}")
check(els[1][:front] == :px && els[1][:rechteck] == [5000.0, -1500.0, 5829.0, -829.0], "Schenkel B: #{els[1]}")
erg = E.erkenne(els + [el('USS9', [5000.0, -2100.0, 5829.0, -1500.0], :px)])
check(erg[:ecken].size == 1 && erg[:ecken][0][:eckschrank] == 'UES1' && erg[:ecken][0][:passleiste] == 0.0,
      "L-Eckschrank bildet die Ecke: #{erg[:ecken]}")
check(erg[:zeilen].find { |x| x[:front] == :px }[:elemente].map { |x| x[:kz] } == %w[USS9 UES1], 'Schenkel B gehört zur linken Zeile')

# Auswahl statt ganzes Modell; Schränke ohne JT_Schrank werden übergangen
fremd = model.definitions.add('Stuhl')
model.entities.add_instance(fremd, gerade)
check(M.instanzen(model).size == 3, "ohne Auswahl alle Schränke: #{M.instanzen(model).size}")
model.selection << i1
check(M.instanzen(model) == [i1], 'mit Auswahl nur die ausgewählten')
model.selection.clear

# Gesamtlauf aus dem Menü
inst = Arbeitsplatte.erzeugen(model, optionen: {})
check(inst && inst.name == 'APL1' && inst.definition.entities.instances.size >= 3, "erzeugen: #{inst && inst.definition.entities.instances.size} Platten")

# Schnittstelle zu den echten Generatoren: Kategorie und Typ an der Definition,
# L-Form mit l_gebaut
uss = UnterschrankSchubladen.erzeuge(model, {})
check(M.schrank?(model.entities.add_instance(uss, gerade)) && uss.get_attribute('JT_Schrank', 'typ').to_s != '',
      'Unterschrank mit Schubladen hat JT_Schrank kategorie/typ an der Definition')
l = Eckschrank.erzeuge_l(model, {})
check(l.get_attribute('JT_Schrank', 'typ') == 'Eckschrank' && l.get_attribute('JT_Eckschrank', 'l_gebaut'),
      'L-Eckschrank: typ Eckschrank und l_gebaut')
check(l.get_attribute('dynamic_attributes', 'spaltbreite'), 'L-Eckschrank: Spaltbreite als DC-Attribut')

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
