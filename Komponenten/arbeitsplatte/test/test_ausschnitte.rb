# Test ohne SketchUp: Ausschnitte für Spüle und Kochfeld, Prüfungen, Zeichnen
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
$VERBOSE = nil
load File.expand_path('../src/arbeitsplatte/main.rb', __dir__)

E = Arbeitsplatte::Erkennung
L = Arbeitsplatte::Layout
AU = Arbeitsplatte::Ausschnitte
D = Arbeitsplatte::Dialog
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end
def nah(a, b, eps = 0.01) = (a - b).abs < eps

def el(kz, rechteck, front = :ny, typ: 'Unterschrank', kat: 'Unterschrank')
  { kz: kz, typ: typ, kategorie: kat, rechteck: rechteck, front: front, z0: 0.0, z1: 720.0 }
end
def hinten(kz, x0, x1, typ: 'Unterschrank') = el(kz, [x0, 0.0, x1, 820.0], :ny, typ: typ)
def links(kz, y0, y1, typ: 'Unterschrank') = el(kz, [0.0, y0, 820.0, y1], :px, typ: typ)
def layout(els, lo = {}) = L.berechne(E.erkenne(els), lo)

# --- Zeile mit Spüle (900) und Herd (800) ---
zeile = [hinten('USS1', 0, 600), hinten('USP1', 600, 1500, typ: 'Spuelenschrank'), hinten('UST1', 1500, 2100),
         hinten('USK1', 2100, 2900, typ: 'Unterschrank_Kochfeld'), hinten('USS2', 2900, 3500)]
lay = layout(zeile)
p = lay[:platten].first
sp, kf = p[:ausschnitte]
check(p[:ausschnitte].size == 2 && sp[:art] == :spuele && kf[:art] == :kochfeld, "zwei Ausschnitte: #{p[:ausschnitte].map { |a| a[:art] }}")
# Spüle: 900 - 100 = 800 breit, mittig bei 1050, 60 hinter der Vorderkante (y = -20) -> y 40 … 530
check(sp[:rechteck] == [650.0, 40.0, 1450.0, 530.0] && sp[:radius] == 10 && sp[:schrank] == 'USP1', "Spüle: #{sp.slice(:rechteck, :radius)}")
check(sp[:punkte].size == 4 * 9 && sp[:punkte].all? { |x, y| x.between?(650, 1450) && y.between?(40, 530) }, 'Spüle mit Radius 10 gerundet')
check(nah(L.flaeche(sp[:punkte]), 800 * 490 - (4 - Math::PI) * 100, 5.0), "Spülen-Fläche mit Radius: #{L.flaeche(sp[:punkte])}")
# Kochfeld 800 -> 750 × 490, 50 hinter der Vorderkante, ohne Radius
check(kf[:rechteck] == [2125.0, 30.0, 2875.0, 520.0] && kf[:punkte].size == 4, "Kochfeld: #{kf[:rechteck]}")
check(lay[:warnungen].empty?, "keine Warnungen: #{lay[:warnungen]}")
check(L.zusammenfassung(lay).include?('Ausschnitt Spüle 800 × 490, Kochfeld 750 × 490'), L.zusammenfassung(lay))
# Schrank mit Front +x (linke Wand): Ausschnitt quer gedreht
lay = layout([links('USP2', -1500, -600, typ: 'Spuelenschrank')])
a = lay[:platten][0][:ausschnitte][0]
check(a[:rechteck] == [290.0, -1450.0, 780.0, -650.0], "Spüle an der linken Wand: #{a[:rechteck]}")

# --- Einstellungen je Schrank ---
lay = layout(zeile, ausschnitte: { 'USP1' => false, 'USK1' => { breite: 560.0, abstand_vorn: 70.0 },
                                   'USS2' => { art: :kochfeld } })
arten = lay[:platten][0][:ausschnitte].map { |x| [x[:schrank], x[:art], x[:breite]] }
check(arten == [['USK1', :kochfeld, 560.0], ['USS2', :kochfeld, 560.0]], "aus/geändert/zusätzlich: #{arten}")
check(lay[:platten][0][:ausschnitte][0][:rechteck][1] == 50.0, 'Abstand vorn 70 von der Vorderkante')

# --- Prüfungen ---
w = layout(zeile, ausschnitte: { 'USP1' => { breite: 950.0, abstand_vorn: 30.0 } })[:warnungen]
check(w.any? { |x| x.include?('Spüle über USP1: 950 mm breit, ragt über die Schrankseiten') }, "zu breit: #{w}")
check(w.any? { |x| x.include?('Spüle über USP1: nur 30 mm von der Vorderkante') }, "zu nah an der Vorderkante: #{w}")
w = layout(zeile, ausschnitte: { 'USP1' => { tiefe: 900.0 } })[:warnungen]
check(w.any? { |x| x.include?('ragt aus Platte 1') }, "ragt hinten aus der Platte: #{w}")
# Kochfeld neben Hochschrank
hs = [hinten('USK1', 0, 600, typ: 'Unterschrank_Kochfeld'), el('HS1', [602.0, -5.0, 1202.0, 820.0], kat: 'Hochschrank')]
w = layout(hs)[:warnungen]
check(w.any? { |x| x.include?('Kochfeld über USK1: nur 22 mm neben Hochschrank HS1') }, "Hochschrank-Abstand: #{w}")
# Spüle nah am Eckstoß (Spülenschrank direkt an der Ecke der anstoßenden Zeile)
l = [hinten('UES1', 0, 1000, typ: 'Eckschrank'), hinten('USS1', 1000, 2200),
     links('USP1', -950, -50, typ: 'Spuelenschrank'), links('UST1', -1550, -950)]
w = layout(l)[:warnungen]
check(w.any? { |x| x =~ /Spüle über USP1: nur \d+ mm vom Stoß 1/ }, "nah am Stoß: #{w}")
st = layout(l)[:stoesse][0]
d = AU.abstand_zum_stoss(layout(l)[:platten][1][:ausschnitte][0], st, L::OPTIONEN)
check(d.between?(95, 110), "Abstand Spüle–Stoß schräg zum inneren Eckpunkt (840, -20): #{d}")

# --- Längsstoß weicht dem Ausschnitt aus ---
lang = (0...5).map { |i| hinten("USS#{i + 1}", i * 600, (i + 1) * 600) } +
       [hinten('USP1', 3000, 3900, typ: 'Spuelenschrank'), hinten('USS9', 3900, 4500)]
lay = layout(lang)
# Schrankseiten 3000 und 3900 liegen 50 mm neben der Spüle: Stoß weiter vorn bei 2400
check(lay[:stoesse][0][:pfad][0][1][0] == 2400.0 && lay[:platten][1][:ausschnitte].size == 1, "Längsstoß bei 2400, nicht neben der Spüle: #{lay[:stoesse][0][:pfad]}")
lang2 = (0...6).map { |i| hinten("USS#{i + 1}", i * 600, (i + 1) * 600) } + [hinten('USP1', 3600, 4500, typ: 'Spuelenschrank')]
lay = layout(lang2)
check(lay[:stoesse][0][:pfad][0][1][0] == 3000.0 && lay[:platten][1][:ausschnitte].size == 1, "Spüle auf dem zweiten Stück: #{lay[:stoesse][0][:pfad]}")

# --- Dialog: Felder und Antworten ---
erg = E.erkenne(zeile)
beschr, vorgabe, = D.felder(erg)
check(beschr[10..] == ['Spüle über USP1: B x T (mm, 0 = kein Ausschnitt)', 'Spüle über USP1: Abstand von der Vorderkante (mm)',
                       'Kochfeld über USK1: B x T (mm, 0 = kein Ausschnitt)', 'Kochfeld über USK1: Abstand von der Vorderkante (mm)',
                       'Kochfeld zusätzlich über Schrank (Kürzel, mehrere mit Komma)'], "Ausschnitt-Felder: #{beschr[10..]}")
check(vorgabe[10..] == ['800 x 490', '60', '750 x 490', '50', ''], "Vorgaben: #{vorgabe[10..]}")
w = vorgabe.dup
w[10] = '0'
w[12] = '780 x 500'
w[14] = 'USS1, USS2'
o = D.optionen(erg, w)
check(o[:ausschnitte] == { 'USP1' => false, 'USK1' => { breite: 780.0, tiefe: 500.0, abstand_vorn: 50.0 },
                           'USS1' => { art: :kochfeld }, 'USS2' => { art: :kochfeld } }, "Antworten: #{o[:ausschnitte]}")
beschr2, vorgabe2, = D.felder(erg, o)
check(beschr2.size == 10 + 4 * 2 + 1 && vorgabe2[10..] == ['560 x 490', '50', '0', '60', '780 x 500', '50', '560 x 490', '50', ''],
      "Felder aus gespeicherten Optionen (in Zeilenfolge): #{vorgabe2[10..]}")
o2 = D.optionen(erg, vorgabe2, o)
check(o2[:ausschnitte] == o[:ausschnitte].merge('USS1' => { breite: 560.0, tiefe: 490.0, abstand_vorn: 50.0, art: :kochfeld },
                                                'USS2' => { breite: 560.0, tiefe: 490.0, abstand_vorn: 50.0, art: :kochfeld }),
      "zweiter Durchlauf: #{o2[:ausschnitte]}")
w[12] = 'groß'
begin
  D.optionen(erg, w)
  check(false, 'falsche Ausschnittmaße')
rescue ArgumentError
end

# --- Zeichnen: Löcher in Ober- und Unterseite, Daten am Teil, Optionen lesen ---
model = Sketchup::Model.new
Sketchup.active_model = model
lay = layout(zeile)
inst = Arbeitsplatte::Ausgabe.bauen(model, E.erkenne(zeile), lay)
pl = inst.definition.entities.instances[0]
faces = pl.definition.entities.faces
n_umriss = lay[:platten][0][:punkte].size
n_loch = lay[:platten][0][:ausschnitte].sum { |x| x[:punkte].size }
check(faces.size == 2 + n_umriss + n_loch, "Flächen: 2 + #{n_umriss} Seiten + #{n_loch} Schnittkanten = #{faces.size}")
check(faces[2 + n_umriss..].none?(&:material), 'Schnittkanten ohne Anleimer')
gesp = JSON.parse(pl.get_attribute('JT_Arbeitsplatte', 'ausschnitte'))
check(gesp.map { |x| x['art'] } == %w[spuele kochfeld] && gesp[0]['rechteck'] == [650.0, 40.0, 1450.0, 530.0], "gespeichert: #{gesp.map { |x| x['rechteck'] }}")
txt = Arbeitsplatte::Ausgabe.json(Arbeitsplatte::Ausgabe.optionen_speichern(L::OPTIONEN.merge(ausschnitte: o[:ausschnitte])))
check(Arbeitsplatte::Ausgabe.optionen_lesen(txt)[:ausschnitte] == o[:ausschnitte], 'Ausschnitt-Optionen gespeichert und gelesen')

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
