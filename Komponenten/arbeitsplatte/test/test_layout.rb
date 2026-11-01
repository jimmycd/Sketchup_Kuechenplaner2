# Test ohne SketchUp: Plattenlayout (Überstände, Ecken, Stoßarten, Teilung, Format)
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
$VERBOSE = nil
load File.expand_path('../src/arbeitsplatte/main.rb', __dir__)

E = Arbeitsplatte::Erkennung
L = Arbeitsplatte::Layout
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end
def nah(a, b, eps = 0.01) = (a - b).abs < eps
def pnah(p, q) = nah(p[0], q[0]) && nah(p[1], q[1])

# Grundriss wie in test_arbeitsplatte.rb: hintere Wand y = 820, linke Wand x = 0,
# Front der hinteren Zeile bei y = 0, Schränke 820 tief.
def el(kz, rechteck, front = :ny, typ: 'Unterschrank', kat: 'Unterschrank', z1: 720.0)
  { kz: kz, typ: typ, kategorie: kat, rechteck: rechteck, front: front, z0: 0.0, z1: z1 }
end
def hinten(kz, x0, x1, **o) = el(kz, [x0, 0.0, x1, 820.0], :ny, **o)
def links(kz, y0, y1, **o) = el(kz, [0.0, y0, 820.0, y1], :px, **o)
def rechts(kz, y0, y1, xw = 3000.0, **o) = el(kz, [xw - 820.0, y0, xw, y1], :nx, **o)
def layout(els, eo = {}, lo = {}) = L.berechne(E.erkenne(els, eo), lo)
# Kante zwischen zwei Punkten finden
def kante(p, a, b)
  i = p[:punkte].each_index.find { |k| pnah(p[:punkte][k], a) && pnah(p[:punkte][(k + 1) % p[:punkte].size], b) }
  i && p[:kanten][i]
end

# --- gerade Zeile 1800: Tiefe 820 + 20 vorn - 5 Wand = 835, Format 900 ---
lay = layout([hinten('USS1', 0, 600), hinten('UST1', 600, 1800)])
p = lay[:platten].first
check(lay[:platten].size == 1 && lay[:stoesse].empty?, 'eine Platte, kein Stoß')
check(p[:punkte] == [[1800.0, -20.0], [1800.0, 815.0], [0.0, 815.0], [0.0, -20.0]], "Umriss: #{p[:punkte]}")
check(p[:kanten] == %i[frei wand frei vorne], "Kanten: #{p[:kanten]}")
check(p[:laenge] == 1800 && p[:breite] == 835 && p[:format] == [4100.0, 900.0] && p[:staerke] == 38 && p[:z] == 720,
      "Maße: #{p.slice(:laenge, :breite, :format, :staerke, :z)}")
check(L.flaeche(p[:punkte]) > 0, 'gegen den Uhrzeigersinn')

# Überstände, Massivholz, Format wählbar
lay = layout([hinten('USS1', 0, 600)], {}, ueberstand_seite: 20.0, ueberstand_vorn: 30.0, wandabstand: 0.0, art: :massivholz)
p = lay[:platten].first
check(p[:punkte] == [[620.0, -30.0], [620.0, 820.0], [-20.0, 820.0], [-20.0, -30.0]] && p[:staerke] == 40, "Überstände/Massivholz: #{p[:punkte]} #{p[:staerke]}")
check(layout([hinten('USS1', 0, 600)], {}, format: [3000, 1000])[:platten][0][:format] == [3000.0, 1000.0], 'festes Format')
flach = layout([el('USS1', [0, 0, 600, 581])])[:platten][0]
check(flach[:breite] == 596 && flach[:format] == [4100.0, 600.0], "flache Schränke -> 600er Format: #{flach.slice(:breite, :format)}")
lay = layout([hinten('USS1', 0, 600)], {}, formate: [[4100, 600]])
check(lay[:warnungen].any? { |w| w.include?('breiter als jedes Format') }, "zu tief für die Formate: #{lay[:warnungen]}")

# Hochschrank am Ende: Fuge 2 statt der gemessenen 10
lay = layout([hinten('USS1', 0, 600), el('HS1', [610.0, -5.0, 1210.0, 820.0], kat: 'Hochschrank')])
p = lay[:platten].first
check(p[:punkte][0] == [608.0, -20.0] && p[:kanten][0] == :hochschrank, "Fuge zum Hochschrank: #{p[:punkte][0]} #{p[:kanten][0]}")

# --- Überlänge: 7 × 600 = 4200 > 4100 - 2 × 10 -> Stoß über der Schrankseite bei 3600 ---
lay = layout((0...7).map { |i| hinten("USS#{i + 1}", i * 600, (i + 1) * 600) })
check(lay[:platten].size == 2 && lay[:platten].map { |x| x[:laenge] } == [3600, 600], "geteilt: #{lay[:platten].map { |x| x[:laenge] }}")
s = lay[:stoesse].first
check(s && s[:art] == :laengs && s[:platten] == [1, 2] && s[:pfad] == [[:linie, [3600.0, -20.0], [3600.0, 815.0]]], "Längsstoß: #{s}")
check(lay[:platten][0][:kanten][0] == :stoss && lay[:platten][1][:kanten][2] == :stoss, 'Längsstoß-Kanten')
# ohne Schrankseite in Reichweite: Warnung
lay = layout([hinten('USS1', 0, 4500)])
check(lay[:platten].size == 2 && lay[:warnungen].any? { |w| w.include?('nicht über einer Schrankseite') }, "Teilung ohne Schrankseite: #{lay[:warnungen]}")

# --- L mit Blindeck, Standard Gehrungsansatz ---
l_els = [hinten('UES1', 0, 1000, typ: 'Eckschrank'), hinten('USS1', 1000, 1600), links('USS2', -650, -50), links('UST1', -1250, -650)]
lay = layout(l_els)
a, b = lay[:platten]
check(lay[:platten].size == 2 && a[:front] == :ny && b[:front] == :px, "zwei Platten: #{lay[:platten].map { |x| x[:front] }}")
st = lay[:stoesse].first
check(st[:art] == :gehrungsansatz && st[:platten] == [a[:nr], b[:nr]] && st[:ecke] == 1, "A läuft durch (länger): #{st.slice(:art, :platten)}")
# innerer Eckpunkt (840, -20); 45° bis (810, 10); gerade bis zur Wand x = 5
seg = st[:pfad]
check(seg.map(&:first) == %i[linie bogen linie], "Pfad Linie-Bogen-Linie: #{seg.map(&:first)}")
check(pnah(seg[0][1], [840, -20]) && pnah(seg[2][2], [5, 10]), "Pfad von innen bis an die Wand: #{seg[0][1]} … #{seg[2][2]}")
tl = 30 * Math.tan(Math::PI / 8)
t1 = [810 + tl / Math.sqrt(2), 10 - tl / Math.sqrt(2)]
t2 = [810 - tl, 10]
check(pnah(seg[0][2], t1) && pnah(seg[1][1], t1) && pnah(seg[1][2], t2), "Bogen tangential: #{seg[1]} / soll #{t1} #{t2}")
mitte = seg[1][3]
check(nah(Math.hypot(t1[0] - mitte[0], t1[1] - mitte[1]), 30) && nah(Math.hypot(t2[0] - mitte[0], t2[1] - mitte[1]), 30) && nah(mitte[0], t2[0]),
      "Bogenmitte im Abstand R: #{mitte}")
# A (weiblich): Vorderkante bis (840,-20), dann der Pfad, an der Wand bis in die Ecke (5, 815)
check(a[:punkte].include?([840.0, -20.0]) && a[:punkte].include?([5.0, 815.0]) && a[:punkte].include?([5.0, 10.0]), "Umriss A: #{a[:punkte]}")
check(kante(a, [5.0, 815.0], [5.0, 10.0]) == :wand && kante(a, [1600.0, -20.0], [1600.0, 815.0]) == :frei, "Kanten A: #{a[:kanten]}")
check(a[:kanten].count(:stoss) == 10, "A: 10 Stoßkanten (Linie, 8 Bogenteile, Linie): #{a[:kanten].count(:stoss)}")
# B (männlich): ragt um 30 in A hinein, bis y = 10
check(b[:punkte].include?([5.0, 10.0]) && b[:punkte].include?([840.0, -20.0]), "Umriss B: #{b[:punkte]}")
check(b[:laenge] == 1260 && b[:breite] == 835, "B: Länge von -1250 bis 10: #{b[:laenge]} × #{b[:breite]}")
check(kante(b, [5.0, -1250.0], [840.0, -1250.0]) == :frei, "B: freies Ende #{b[:kanten]}")
check([a, b].all? { |x| L.flaeche(x[:punkte]) > 0 }, 'beide gegen den Uhrzeigersinn')
# Flächen passen ohne Überlappung zusammen: Summe = L-Fläche
gesamt = 1600 * 835 - 5 * 835 + 835 * 1230 # A von x 5..1600, B von y -1250..-20
check(nah(L.flaeche(a[:punkte]) + L.flaeche(b[:punkte]), gesamt, 1.0), "Flächen A + B = L: #{L.flaeche(a[:punkte]) + L.flaeche(b[:punkte])} / #{gesamt}")

# stumpf und Gehrung als Option, durchlaufende Platte umschaltbar
lay = layout(l_els, {}, stoss: :stumpf)
st = lay[:stoesse].first
check(st[:art] == :stumpf && st[:pfad] == [[:linie, [840.0, -20.0], [5.0, -20.0]]], "stumpf: #{st[:pfad]}")
check(lay[:platten][1][:laenge] == 1230, "B stumpf bis zur Vorderkante von A: #{lay[:platten][1][:laenge]}")
lay = layout(l_els, {}, ecken: { 1 => { stoss: :gehrung } })
st = lay[:stoesse].first
check(st[:art] == :gehrung && st[:pfad] == [[:linie, [840.0, -20.0], [5.0, 815.0]]], "Gehrung: #{st[:pfad]}")
check(nah(L.flaeche(lay[:platten][0][:punkte]) + L.flaeche(lay[:platten][1][:punkte]), gesamt, 1.0), 'Gehrung: Flächen passen')
lay = layout(l_els, {}, ecken: { 1 => { durchlaufend: 2 } })
a, b = lay[:platten]
check(lay[:stoesse].first[:platten] == [b[:nr], a[:nr]] && b[:punkte].include?([5.0, 815.0]), "B läuft durch: #{b[:punkte]}")
check(nah(L.flaeche(a[:punkte]) + L.flaeche(b[:punkte]), gesamt, 1.0), 'B durch: Flächen passen')
lay = layout(l_els, {}, radius: 120.0)
check(lay[:warnungen].any? { |w| w.include?('Radius 120') } && lay[:stoesse][0][:pfad].size == 2, "zu großer Radius: #{lay[:warnungen]}")
begin
  layout(l_els, {}, stoss: :schwalbe)
  check(false, 'unbekannte Stoßart')
rescue ArgumentError
end

# --- U: Mittelplatte läuft durch, zwei Gehrungsansätze ---
u = (0...5).map { |i| hinten("USS#{i + 1}", i * 600, (i + 1) * 600) } +
    [links('UST1', -1800, -1200), links('UST2', -1200, -600), links('UST3', -600, 0),
     rechts('USP1', -1800, -1200), rechts('USK1', -1200, -600), rechts('USS9', -600, 0)]
lay = layout(u)
mitte = lay[:platten].find { |x| x[:front] == :ny }
check(lay[:platten].size == 3 && lay[:stoesse].size == 2, "U: 3 Platten, 2 Stöße: #{lay[:platten].size}/#{lay[:stoesse].size}")
check(lay[:stoesse].all? { |x| x[:platten][0] == mitte[:nr] && x[:art] == :gehrungsansatz }, 'Mittelplatte durchlaufend in beiden Ecken')
check(mitte[:punkte].include?([5.0, 815.0]) && mitte[:punkte].include?([2995.0, 815.0]) && mitte[:laenge] == 2990, "Mittelplatte von Wand zu Wand: #{mitte[:laenge]}")
rp = lay[:platten].find { |x| x[:front] == :nx }
check(rp[:punkte].include?([2160.0, -20.0]) && rp[:punkte].include?([2995.0, 10.0]), "rechte Platte am Stoß: #{rp[:punkte]}")
summe = lay[:platten].sum { |x| L.flaeche(x[:punkte]) }
check(nah(summe, 2990 * 835 + 2 * 835 * 1780, 1.0), "U-Flächen passen: #{summe}")
check(lay[:warnungen].empty?, "U ohne Warnungen: #{lay[:warnungen]}")
check(L.zusammenfassung(lay).include?('Stoß 1: Gehrungsansatz, Platte'), L.zusammenfassung(lay))

# lange U-Mittelzeile: geteilt, Ecken an den richtigen Stücken
lang = (0...8).map { |i| hinten("USS#{i + 1}", i * 600, (i + 1) * 600) } +
       [links('UST1', -600, 0), rechts('USP1', -600, 0, 4800.0)]
lay = layout(lang)
st = lay[:stoesse]
check(st.map { |x| x[:art] } == %i[laengs gehrungsansatz gehrungsansatz], "Stöße: #{st.map { |x| x[:art] }}")
mitte = lay[:platten].select { |x| x[:front] == :ny }
check(mitte.size == 2 && st[1][:platten][0] == mitte[0][:nr] && st[2][:platten][0] == mitte[1][:nr], "Ecken an erstem und letztem Stück: #{st.map { |x| x[:platten] }}")

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
