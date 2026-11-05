# Test ohne SketchUp: Andock-Werkzeug – Einrast-Rechnung und Einbindung in die Komponenten.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
komp = File.expand_path('../../Komponenten', __dir__)
%w[unterschrank_schubladen hochschrank oberschrank unterschrank_geschirrspueler unterschrank_kuehlschrank blenden eckschrank].each { |k| load File.join(komp, k, 'src', k, 'main.rb') }
load File.expand_path('../src/jt_schrank_cnc/main.rb', __dir__)

A = JTools::SchrankCnc::Andocken
R = A::Rechnung
V = Math::PI / 2
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

def nah(a, b, eps = 1e-9)
  a = [a].flatten
  b = [b].flatten
  a.size == b.size && a.zip(b).all? { |x, y| (x - y).abs < eps }
end

# Unterschrank 60 breit, 60 tief (Front bei y = -2), 72 hoch; Nachbar 80 tief
K = [0, 60, -2, 58, 0, 72].freeze
N = [0, 60, -2, 78, 0, 72].freeze
null = [0, 0, 0, 0]

# --- Seiten und Bündigkeit ----------------------------------------------------
check(nah(R.an_nachbar(K, K, null, :rechts, 0), [0, 60, 0]), 'rechts neben gleich tiefem Schrank')
check(nah(R.an_nachbar(K, K, null, :links, 0), [0, -60, 0]), 'links neben gleich tiefem Schrank')
check(nah(R.an_nachbar(K, N, null, :rechts, 0), [0, 60, 20]), 'Rückwände bündig bei tieferem Nachbarn')
check(nah(R.an_nachbar(K, N, null, :rechts, 0, :vorne), [0, 60, 0]), 'Fronten bündig auf Wunsch')

# Nachbar um 90° gedreht und verschoben: neuer Schrank übernimmt die Drehung
nl = [V, 200, 100, 0]
w, x, y = R.an_nachbar(K, K, nl, :rechts, 0)
check(nah([w, x, y], [V, 200, 160]), "rechts am gedrehten Nachbarn: #{[w, x, y]}")
w, x, y = R.an_nachbar(K, K, [Math::PI, 0, 0, 0], :rechts, 0)
check(nah([w, x, y], [Math::PI, -60, 0]), "rechts am 180° gedrehten Nachbarn: #{[w, x, y]}")

# --- Ecke: quer vor die Front (z. B. vor ein Blindeck) --------------------------
check(R.viertel(:vorne_rechts, 0) == 3 && R.viertel(:vorne_links, 0) == 1, 'vor der Front automatisch quer')
check(R.viertel(:vorne_rechts, 1) == 1 && R.viertel(:rechts, 2) == 2, 'eigene Drehung bleibt')
w, x, y = R.an_nachbar(K, K, null, :vorne_rechts, 3)
lage = [w, x, y, 0]
e = R.ecken(K, lage)
xs = e.map { |p| p[0] }
ys = e.map { |p| p[1] }
check(nah(xs.max, 60), "quer rechts: Rückseite in der Flucht der rechten Seite (#{xs.max})")
check(nah(ys.max, -2), "quer rechts: steht an der Front des Nachbarn (#{ys.max})")
check(nah(ys.min, -62), "quer rechts: reicht 60 nach vorn (#{ys.min})")
fx, = R.welt(lage, 30, -2)
check(fx < xs.max, 'quer rechts: Front zeigt zum Nachbarn hin (nach links)')
w, x, y = R.an_nachbar(K, K, null, :vorne_links, 1)
e = R.ecken(K, [w, x, y, 0])
check(nah(e.map { |p| p[0] }.min, 0) && nah(e.map { |p| p[1] }.max, -2), 'quer links: bündig mit linker Seite, an der Front')

# L-Küche andersherum: neuer Schrank um 90° gedreht rechts an der Seite, Rückwand an der Wand des Nachbarn
w, x, y = R.an_nachbar(K, K, null, :rechts, 3)
e = R.ecken(K, [w, x, y, 0])
check(nah(e.map { |p| p[0] }.min, 60) && nah(e.map { |p| p[1] }.max, 58), "gedreht rechts an der Seite: #{e.first}")

# --- Seite aus Mausposition ----------------------------------------------------
check(R.seite(10, K, false) == :links && R.seite(50, K, false) == :rechts, 'Seite links/rechts nach Mausposition')
check(R.seite(50, K, true) == :vorne_rechts && R.seite(5, K, true) == :vorne_links, 'auf der Front: quer davor')

# --- Höhe ------------------------------------------------------------------------
OS = [0, 60, -2, 33, 0, 70].freeze
HS = [0, 60, -2, 58, 0, 220].freeze
KS = [0, 60, -2, 58, 0, 82].freeze # höherer Unterschrank
VZ = R.vorgaben_zoll(A::VORGABEN) # Sockel 100, Korpus 700, Platte 40, Abstand 550 mm
mm = 1 / 25.4
check(nah(VZ[:sockel], 100 * mm) && nah(VZ[:aufbau], 590 * mm) && nah(VZ[:ober], 1390 * mm), "Vorgaben in Zoll: #{VZ}")
# Unter-/Hochschränke: Sockelhöhe fest (Fußboden + Sockel), egal neben welchem Schrank
check(nah(R.hoehe(K, 'Unterschrank', K, 0, 'Unterschrank', 99, VZ), VZ[:sockel]), 'Unterschrank neben Unterschrank: auf dem Sockel')
check(nah(R.hoehe(KS, 'Unterschrank', K, 7, 'Unterschrank', 99, VZ), VZ[:sockel]), 'Unterschrank: Nachbar zu hoch/zu tief ändert den Sockel nicht')
check(nah(R.hoehe(K, 'Unterschrank', OS, 145, 'Oberschrank', 0, VZ), VZ[:sockel]), 'Unterschrank neben Oberschrank: auf dem Sockel')
check(nah(R.hoehe(HS, 'Hochschrank', K, 0, 'Unterschrank', 7, VZ), VZ[:sockel]), 'Hochschrank: auf dem Sockel')
check(nah(R.hoehe(K, 'Unterschrank', K, 0, 'Unterschrank', 0, VZ.merge(boden: 5.0)), 5 + VZ[:sockel]), 'Sockel über dem Fußboden des Raums')
check(R.hoehe(OS, 'Oberschrank', OS, 145, 'Oberschrank', 0, VZ) == 145, 'Oberschrank neben Oberschrank: gleiche Unterkante')
check(nah(R.hoehe(OS, 'Oberschrank', HS, 4, 'Hochschrank', 0, VZ), VZ[:ober]), 'Oberschrank neben Hochschrank: feste Höhe über dem Fußboden')
check(nah(R.hoehe(OS, 'Oberschrank', K, 4, 'Unterschrank', 140, VZ), 4 + 72 + VZ[:aufbau]),
      'Oberschrank bei Unterschrank: Seitenoberkante + Platte + Abstand, nie eigene Höhe')
check(nah(R.hoehe(OS, 'Oberschrank', OS, 145, 'Oberschrank', 0, VZ.merge(decke: 200.0)), 130), 'Oberschrank höchstens bis zur Decke')

# Sockel geändert: alles um d, Oberschrank nur bis zur Decke
check(nah(R.sockel_neu_z('Unterschrank', 4, K, 2, 230), 6) && nah(R.sockel_neu_z('Arbeitsplatte', 30, K, -2, 230), 28), 'Sockel neu: Unterschrank und Platte mit')
check(nah(R.sockel_neu_z('Oberschrank', 150, OS, 5, 230), 155), 'Sockel neu: Oberschrank mit, wenn Platz bis zur Decke')
check(nah(R.sockel_neu_z('Oberschrank', 158, OS, 5, 230), 160), 'Sockel neu: Oberschrank höchstens bis zur Decke')
check(nah(R.sockel_neu_z('Oberschrank', 170, OS, 5, 230), 170) && nah(R.sockel_neu_z('Oberschrank', 150, OS, -5, 230), 145),
      'Sockel neu: über der Decke bleibt er, nach unten immer mit')
check(nah(R.sockel_neu_z('Oberschrank', 150, OS, 5, nil), 155), 'Sockel neu: ohne Raum keine Grenze')

# Oberschrank über Unterschrank: Rückseiten bündig, links/rechts bündig, feste Höhe
lage = R.ueber_unterschrank(OS, K, [0, 10, 20, 4], false, VZ[:aufbau])
check(nah(lage, [0, 10, 20 + 58 - 33, 4 + 72 + VZ[:aufbau]]), "Oberschrank über Unterschrank links bündig: #{lage}")
OB = [0, 40, -2, 33, 0, 70].freeze
lage = R.ueber_unterschrank(OB, K, [0, 0, 0, 0], true, VZ[:aufbau])
check(nah(lage[1], 20), "Oberschrank über Unterschrank rechts bündig: #{lage}")

# --- Bezugskasten aus Seiten / virtuelle Seite ---------------------------------------
seiten = [[0, 1.9, 1.9, 59, 0, 72], [58.1, 60, 1.9, 59, 0, 72]]
check(nah(R.bezug(seiten, [], nil, [0, 60, -2, 59, -10, 90]), [0, 60, 1.9, 59, 0, 72]), 'Bezug aus den Seiten, Front/Gerät zählen nicht')
check(nah(R.bezug(seiten, [[60, 61.9, 1.9, 60, -10, 72]], nil, nil), [0, 61.9, 1.9, 60, 0, 72]), 'Wange verbreitert, aber nicht nach unten')
vs = R.virtuelle_seite(60, 70, 52, 0, 1.9, 0.8)
check(nah(vs, [0, 60, 1.9, 54.7, 0, 70]), "virtuelle Seite (Nische): #{vs}")
check(nah(R.bezug([], [[0, 1.9, 1.9, 54.7, -10, 70]], R.virtuelle_seite(60, 70, 52, 1.9, 1.9, 0.8), nil)[0..1], [0, 61.9]),
      'virtuelle Seite mit linker Wange')
check(R.bezug([], [], nil, [1, 2, 3, 4, 5, 6]) == [1, 2, 3, 4, 5, 6], 'ohne Seiten und Maße: alle sichtbaren Teile')
check(nah(R.bezug(seiten, [], nil, nil, [[1.9, 58.1, 59, 59.8, 0, 72]]), [0, 60, 1.9, 59.8, 0, 72]), 'Rückwand hinter den Seiten verlängert nur nach hinten')
m = R.matmul([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 10, 0, 0, 1], [0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 1, 0, 0, 5, 0, 1])
check(nah(R.box_trafo(m, [0, 0, 0], [2, 1, 3]), [9, 10, 5, 7, 0, 3]), 'Teil gedreht und verschoben: Grenzen im Schranksystem')

# --- Zeile: freies Ende ----------------------------------------------------------------
reihe = [[K, [0, 0, 0, 0]], [K, [0, 120, 0, 0]], [K, [0, 60, 0, 0]], [K, [0, 300, 0, 0]]]
check(R.rechts_an?(K, [0, 0, 0, 0], K, [0, 60, 0, 0]) && !R.rechts_an?(K, [0, 60, 0, 0], K, [0, 0, 0, 0]), 'rechts_an? nur in eine Richtung')
check(!R.rechts_an?(K, [0, 0, 0, 0], OS, [0, 60, 0, 145]), 'Oberschrank darüber ist kein Nachbar in der Zeile')
check(!R.rechts_an?(K, [0, 0, 0, 0], K, [V, 60, 0, 0]), 'quer stehender Schrank ist kein Nachbar in der Zeile')
check(R.zeilenende(reihe, 0) == 1 && R.zeilenende(reihe, 2) == 1 && R.zeilenende(reihe, 1, :links) == 0, 'Zeilenende rechts und links')
check(R.zeilenende(reihe, 3) == 3, 'einzelner Schrank ist sein eigenes Ende')
# gedrehte Zeile (Wand rechts, -90°)
dz = [[K, [-V, 400, 300, 0]], [K, [-V, 400, 240, 0]]]
check(R.zeilenende(dz, 0) == 1, 'Zeilenende in gedrehter Zeile')

# --- Wand und frei ---------------------------------------------------------------
check(nah(R.an_wand(K, [100, 0], [0, -1]), [0, 70, -58]), 'Wand hinten (Raum bei -y): Rückseite an der Wand, Mitte an der Maus')
w, x, y = R.an_wand(K, [0, 50], [3, 0]) # Wand links, Raum bei +x
e = R.ecken(K, [w, x, y, 0])
check(nah(w, V) && nah(e.map { |p| p[0] }.min, 0), "Wand links: Rückseite an der Wand (#{w}, #{e.map { |p| p[0] }.min})")
check(nah(e.map { |p| p[1] }.sum / 8.0, 50), 'Wand links: Mitte an der Maus')
fx, = R.welt([w, x, y, 0], 30, -2)
check(fx > 50, 'Wand links: Front zeigt in den Raum')
check(nah(R.frei(K, [0, 0], 0), [0, -30, -28]), 'frei: Mitte unter der Maus')

# --- Wand des Raums: Wand-Koordinaten wie beim Schrank (x entlang, y in die Wand) -----------
# Wand 1 eines Raums: beginnt bei (0, 300), läuft in +x; Raum liegt bei y < 300
wl = [0, 0, 300, 0]
w, x, y, xs = R.an_raumwand(K, wl, 100, [0], [400], 10)
check(nah([w, x, y, xs], [0, 70, 242, 70]), "Raumwand: Mitte an der Maus, Rückseite an der Wand (#{[w, x, y, xs]})")
e = R.ecken(K, [w, x, y, 0])
check(nah(e.map { |p| p[1] }.max, 300) && nah(e.map { |p| p[1] }.min, 240), 'Raumwand: Front zeigt in den Raum')
check(nah(R.an_raumwand(K, wl, 37, [0], [400], 10)[3], 0), 'Raumwand: rastet in der linken Ecke ein')
check(nah(R.an_raumwand(K, wl, 365, [0], [400], 10)[3], 340), 'Raumwand: rastet in der rechten Ecke ein')
check(nah(R.an_raumwand(K, wl, 250, [0, 210], [400, 150], 10)[3], 210), 'Raumwand: rastet an der Türlaibung ein')
check(nah(R.an_raumwand(K, wl, 200, [0], [400], 10)[3], 170), 'Raumwand: weit weg von Kanten frei')
check(nah(R.raum_hoehe('Unterschrank', 10, K, VZ), 10 + VZ[:sockel]), 'Raumwand: Unterschrank auf Fußboden + Sockel')
check(nah(R.raum_hoehe('Hochschrank', 0, [0, 1, 0, 1, 2, 3], VZ), VZ[:sockel] - 2), 'Raumwand: Seitenunterkante auf dem Sockel')
check(nah(R.raum_hoehe('Oberschrank', 5, OS, VZ), 5 + VZ[:ober]), 'Raumwand: Oberschrank auf fester Höhe')
check(nah(R.raum_hoehe('Oberschrank', 0, OS, VZ.merge(decke: 80.0)), 10), 'Raumwand: Oberschrank höchstens bis zur Decke')
w, x, y, = R.an_raumwand(K, wl, 100, [0], [400], 10, 2)
check(nah(y, 240), "Raumwand: Wandabstand hinter dem Schrank (#{y})")
check(nah(R.an_raumwand(K, wl, 37, [0], [400], 10, 2, 400)[3], 2), 'Raumwand: in der linken Ecke auch seitlich Wandabstand')
check(nah(R.an_raumwand(K, wl, 365, [0], [400], 10, 2, 400)[3], 338), 'Raumwand: in der rechten Ecke auch seitlich Wandabstand')
check(nah(R.an_raumwand(K, wl, 250, [0, 210], [400, 150], 10, 2, 400)[3], 210), 'Raumwand: Türlaibung ohne Wandabstand')
check(nah(R.an_raumwand(K, wl, 200, [0], [400], 10, 2, 400, :links)[3], 2), 'Eckschrank: immer in die linke Ecke, an beiden Wänden')
check(nah(R.an_raumwand(K, wl, 50, [0], [400], 10, 2, 400, :rechts)[3], 338), 'Eckschrank Blindseite rechts: in die rechte Ecke')

# freier Platz: Wände und andere Schränke
wand = [[0, 0, 300, 0], [0, 400, 0, 24]]
check(R.platz?(K, [0, 0, 242, 0], [wand]) && !R.platz?(K, [0, 0, 250, 0], [wand]), 'Platz: an der Wand ja, in der Wand nein')
nachbar = [[0, 60, 0, 0], [K[0], K[1], K[2], K[3]]]
check(R.platz?(K, [0, 0, 0, 0], [nachbar]) && !R.platz?(K, [0, 30, 0, 0], [nachbar]), 'Platz: daneben ja, überlappend nein')
check(!R.platz?(K, [0, 0, 0, 0], [[[-V, 50, 300, 0], [0, 300, 0, 24]]]), 'Platz: gedrehte Wand im Weg')
# Wand 2 (rechts, läuft in -y): Schrank um -90° gedreht, Rückseite an x = 400
w, x, y, = R.an_raumwand(K, [-V, 400, 300, 0], 30, [0], [300], 10)
e = R.ecken(K, [w, x, y, 0])
check(nah(e.map { |p| p[0] }.max, 400) && nah(e.map { |p| p[1] }.max, 300), "Raumwand rechts: in der Ecke hinten rechts (#{e.map { |p| p[0] }.max}, #{e.map { |p| p[1] }.max})")

check(nah(R.winkel(4 * V + 1e-12), 0) && nah(R.winkel(-V), 3 * V), 'Winkel auf 90° gerundet und 0..360°')

# --- Einbindung: neuer Schrank in SketchUp -----------------------------------------
def o(i) = i.transformation.origin.to_a.map(&:to_f)
model = Sketchup.active_model = Sketchup::Model.new
us1 = UnterschrankSchubladen.erstellen(UnterschrankSchubladen::DEFAULTS)
check(model.werkzeug.is_a?(A::Werkzeug), 'erster Schrank (noch keine Zeile): hängt am Andock-Werkzeug')
check(model.selection.to_a == [us1], 'neuer Schrank ist danach ausgewählt')
k1 = A.kasten(us1)
check(nah(k1[1] - k1[0], 60.cm, 1e-6), "Kasten = Breite des Schranks (#{k1})")
b1 = A.bezug(us1)
check(nah([b1[0], b1[1], b1[4], b1[5]], [0, 60.cm, 0, 70.cm], 1e-6), "Bezug = Außenseiten und Oberkante der Seiten (#{b1})")

# Andock-Werkzeug beenden, erster Schrank steht; nächste ohne Auswahl ans freie Ende
# erster Schrank: mit dem Werkzeug abgesetzt, auf dem Sockel
sockel = A.vorgaben(model)[:sockel]
A.setzen(us1, [0, 0, 0, sockel], 'test')
model.select_tool(nil)
model.selection.clear
us2 = UnterschrankSchubladen.erstellen(UnterschrankSchubladen::DEFAULTS)
check(model.werkzeug.nil?, 'zweiter Schrank: kein Werkzeug, direkt ans freie Ende')
b2 = A.bezug(us2)
check(nah(o(us2)[0] + b2[0], o(us1)[0] + b1[1], 1e-6), "angereiht: Seiten berühren sich (#{o(us2)})")
check(nah(o(us2)[1..2], o(us1)[1..2], 1e-6), 'angereiht: gleiche Flucht und Höhe')

# dritter Schrank, Auswahl auf dem ersten: rechts ist us2, also links daneben
model.selection.clear
model.selection.add(us1)
us3 = UnterschrankSchubladen.erstellen(UnterschrankSchubladen::DEFAULTS)
check(nah(o(us3), [-60.cm, 0, sockel], 1e-6), "markierter Schrank hat nur links Platz: links daneben (#{o(us3)})")

# Unterbau-Kühlschrank (keine eigene Seite): virtuelle Seite, Gerät steht auf dem Boden
model.selection.clear
uk = UnterschrankKuehlschrank.erstellen({})
bk = A.bezug(uk)
check(nah([bk[0], bk[1], bk[4], bk[5]], [0, 60.cm, 0, 70.cm], 1e-6), "Kühlschrank: virtuelle Seite = Nische (#{bk})")
check(nah(o(uk)[0], o(us2)[0] + 60.cm, 1e-6) && nah(o(uk)[2], o(us3)[2], 1e-6),
      "Kühlschrank: am freien rechten Ende, auf dem Sockel (#{o(uk)})")
geraet = uk.definition.entities.instances.find { |i| i.definition.name.include?('Platzhalter') }
check(geraet && nah(o(uk)[2] + geraet.transformation.origin[2], o(us1)[2] - 10.cm, 1e-6),
      'Kühlschrank: Geräteunterkante auf dem Fußboden (Sockel nicht vergessen)')

# Oberschrank: der erste kommt über den Anfang der Unterschrank-Zeile, Höhe fest
model.selection.clear
os1 = Oberschrank.erstellen({})
bo = A.bezug(os1)
v = A.vorgaben
check(model.werkzeug.nil?, 'erster Oberschrank: kein Werkzeug, direkt über die Zeile')
check(nah(o(os1)[0] + bo[0], o(us3)[0] + b1[0], 1e-6), "erster Oberschrank: links bündig mit der Zeile (#{o(os1)})")
check(nah(o(os1)[2] + bo[4], o(us1)[2] + b1[5] + v[:aufbau], 1e-6), 'erster Oberschrank: Unterkante = Unterschrank + Platte + Abstand')
check(nah(o(os1)[1] + bo[3], o(us1)[1] + b1[3], 1e-6), 'erster Oberschrank: Rückseite in der Flucht der Unterschränke')
os2 = Oberschrank.erstellen({})
check(nah(o(os2)[0] + bo[0], o(os1)[0] + bo[1], 1e-6) && nah(o(os2)[2], o(os1)[2], 1e-6), 'zweiter Oberschrank: rechts daneben, gleiche Höhe')

# Hochschrank am Ende der Unterschränke: gleiche Unterkante
model.selection.clear
hs = Hochschrank.erstellen({})
bh = A.bezug(hs)
check(nah(o(hs)[0] + bh[0], o(uk)[0] + bk[1], 1e-6) && nah(o(hs)[2] + bh[4], o(us1)[2] + b1[4], 1e-6),
      "Hochschrank: am freien Ende der Unterschränke, gleiche Unterkante (#{o(hs)})")

# Oberschrank an Hochschrank (Auswahl): feste Höhe, nicht die Oberkante des Hochschranks
model.selection.clear
model.selection.add(hs)
os3 = Oberschrank.erstellen({})
check(nah(o(os3)[0] + bo[0], o(hs)[0] + bh[1], 1e-6), 'Oberschrank rechts am Hochschrank')
check(nah(o(os3)[2] + bo[4], o(hs)[2] + bh[4] - v[:sockel] + v[:ober], 1e-6), 'Oberschrank am Hochschrank: feste Höhe')

# Einstellungen werden gelesen
Sketchup.write_default('Kuechenplaner_Einstellungen', 'sockelhoehe', 150.0)
check(nah(A.vorgaben[:sockel], 150 / 25.4) && nah(A.vorgaben[:aufbau], 590 / 25.4), 'Kuechenplaner::Einstellungen wird benutzt')
Sketchup.defaults.delete(['Kuechenplaner_Einstellungen', 'sockelhoehe'])

# Sockelhöhe 100 → 150 mm: Unterschränke, Kühlschrank (Parameter Sockelhöhe) und Oberschränke mit
zs = [us1, uk, hs, os1].map { |i| o(i)[2] }
A.sockel_geaendert(model, 100, 150)
check(nah([us1, uk, hs, os1].map { |i| o(i)[2] }, zs.map { |z| z + 50 / 25.4 }, 1e-6), 'Sockel geändert: alle Schränke 50 mm höher')
check(nah(JTools::SchrankCnc::Schraenke.dc(uk, 'sockelhoehe'), 150 / 25.4, 1e-6), 'Sockel geändert: Kühlschrank-Nische bekommt die neue Sockelhöhe')
A.sockel_geaendert(model, 150, 100)
check(nah(o(us1)[2], sockel, 1e-6), 'Sockel zurück: wieder auf 100 mm')

# Geschirrspüler- und Kühlschrank-Nische: Kasten = virtueller Korpus wie bei einem Unterschrank
# (Nischenbreite, Front bis Rückwand, Unterkante bis Oberkante Korpus). Geräte-Platzhalter (bis zum
# Fußboden, tiefer als der Korpus) und ausgeblendete Wangen zählen nicht.
[[UnterschrankGeschirrspueler, 'Geschirrspüler'], [UnterschrankKuehlschrank, 'Kühlschrank-Nische']].each do |mod, name|
  model.selection.clear
  model.select_tool(nil)
  us = UnterschrankSchubladen.erstellen(UnterschrankSchubladen::DEFAULTS.merge('Tiefe' => 52.0))
  ku = A.kasten(us)
  model.selection.clear
  model.selection.add(us)
  ni = mod.erstellen('Tiefe' => 52.0)
  kn = A.kasten(ni)
  check(nah(kn, [0, 60, -0.2, 1.9 + 52 + 0.8, 0, 70].map(&:cm), 1e-6), "#{name}: Kasten = virtueller Korpus (#{kn.map { |v| (v * 2.54).round(2) }})")
  check(nah(kn[3..5], ku[3..5], 1e-6), "#{name}: Kasten hinten und Höhe wie Unterschrank daneben") # Fronten des Unterschranks sind im Mock ausgeblendet
  check(nah(ni.transformation.origin.to_a[1..2], us.transformation.origin.to_a[1..2], 1e-6),
        "#{name}: angereiht in gleicher Flucht und Höhe (#{ni.transformation.origin.to_a})")
  check(nah(ni.transformation.origin.to_a[0], us.transformation.origin.to_a[0] + ku[1], 1e-6), "#{name}: direkt rechts daneben")
  # mit beiden Wangen: Kasten wird um die Wangen breiter
  model.selection.clear
  model.select_tool(nil)
  kw = A.kasten(mod.erstellen('Tiefe' => 52.0, 'Art_Wange' => 3.0))
  check(nah(kw[0..1], [0, 63.8].map(&:cm), 1e-6), "#{name}: Kasten mit Wangen #{kw[0..1].map { |v| (v * 2.54).round(2) }}")
end

# Wange (Komponente Blenden) reicht bis zum Boden: angereiht zählt die Korpusunterkante
model.select_tool(nil)
model.selection.clear
model.selection.add(us3) # links vom Zeilenanfang ist frei
wg = Blenden.erstellen(:wange, {})
kw = A.kasten(wg)
check(nah(kw[4], 0) && nah(wg.transformation.origin.to_a[2], us1.transformation.origin.to_a[2], 1e-6),
      "Wange angereiht: Unterkante Korpus gleich, Wange reicht bis zum Boden (#{wg.transformation.origin.to_a}, #{kw})")

# --- Raum: Wände als Hindernis, Decke, Eckschrank ------------------------------------
require 'json'
model = Sketchup.active_model = Sketchup::Model.new
rd = Sketchup::ComponentDefinition.new('Raum')
raum = model.entities.add_instance(rd, Geom::Transformation.translation([0, 0, 0]))
raum.set_attribute('JT_Raum', 'typ', 'Raum')
raum.set_attribute('JT_Raum', 'daten', JSON.generate('hoehe' => 2300.0, 'dicke' => 240.0))
# Wand 1 hinten: von (0, 300 cm) nach +x, 240 cm lang; Wand 2 rechts: von (240, 300) nach -y
w1 = rd.entities.add_instance(Sketchup::ComponentDefinition.new('W1'),
                              Geom::Transformation.axes(Geom::Point3d.new(0, 300.cm, 0), Geom::Vector3d.new(1, 0, 0), Geom::Vector3d.new(0, 1, 0), Geom::Vector3d.new(0, 0, 1)))
w2 = rd.entities.add_instance(Sketchup::ComponentDefinition.new('W2'),
                              Geom::Transformation.axes(Geom::Point3d.new(240.cm, 300.cm, 0), Geom::Vector3d.new(0, -1, 0), Geom::Vector3d.new(1, 0, 0), Geom::Vector3d.new(0, 0, 1)))
# Wand 3 vorne: von (240, 0) nach -x; Wand 4 links: von (0, 0) nach +y
w3 = rd.entities.add_instance(Sketchup::ComponentDefinition.new('W3'),
                              Geom::Transformation.axes(Geom::Point3d.new(240.cm, 0, 0), Geom::Vector3d.new(-1, 0, 0), Geom::Vector3d.new(0, -1, 0), Geom::Vector3d.new(0, 0, 1)))
w4 = rd.entities.add_instance(Sketchup::ComponentDefinition.new('W4'),
                              Geom::Transformation.axes(Geom::Point3d.new(0, 0, 0), Geom::Vector3d.new(0, 1, 0), Geom::Vector3d.new(-1, 0, 0), Geom::Vector3d.new(0, 0, 1)))
[[w1, 1, 2400.0], [w2, 2, 3000.0], [w3, 3, 2400.0], [w4, 4, 3000.0]].each do |w, nr, l|
  { 'typ' => 'Wand', 'wand' => nr, 'laenge' => l }.each { |k2, v2| w.set_attribute('JT_Raum', k2, v2) }
end
vr = A.vorgaben(model)
check(nah(vr[:decke], 2300 / 25.4) && nah(vr[:boden], 0), "Raum: Decke 2300 mm (#{vr[:decke]})")
check(A.waende(model).size == 4 && nah(A.waende(model)[1][0][0], 3 * V), 'Raum: vier Wände, Wand 2 gedreht')
# Schrank in der rechten Ecke an Wand 1 (rechts ist Wand 2) → der nächste kommt links daneben
r1 = UnterschrankSchubladen.erstellen(UnterschrankSchubladen::DEFAULTS)
b = A.bezug(r1)
A.setzen(r1, [0, 180.cm - b[0], 300.cm - b[3], vr[:sockel]], 'test')
model.select_tool(nil)
model.selection.clear
model.selection.add(r1)
r2 = UnterschrankSchubladen.erstellen(UnterschrankSchubladen::DEFAULTS)
check(nah(o(r2)[0] + b[1], o(r1)[0] + b[0], 1e-6), "rechts ist die Wand: links neben den markierten Schrank (#{o(r2)})")
model.selection.clear
r3 = UnterschrankSchubladen.erstellen(UnterschrankSchubladen::DEFAULTS)
check(nah(o(r3)[0] + b[1], o(r2)[0] + b[0], 1e-6), "ohne Auswahl, rechtes Ende an der Wand: ans linke Ende (#{o(r3)})")
# Oberschrank-Höhe an der Decke begrenzt (Decke 2300, Oberschrank 700 hoch: Unterkante höchstens 1600)
ob = Oberschrank.erstellen({})
bo = A.bezug(ob)
check(o(ob)[2] + bo[5] <= vr[:decke] + 1e-6, "Oberschrank unter der Decke (#{((o(ob)[2] + bo[5]) * 25.4).round} mm)")
# markierter Schrank mit beiden Seiten belegt: Werkzeug
model.select_tool(nil)
model.selection.clear
model.selection.add(r2)
r4 = UnterschrankSchubladen.erstellen(UnterschrankSchubladen::DEFAULTS)
check(model.werkzeug.is_a?(A::Werkzeug), 'markiert, keine freie Seite: Schrank hängt an der Maus')
model.select_tool(nil)
model.entities.instances.delete(r4)

# --- Werkzeug in einem leeren Raum (Wandabstand 20 mm) --------------------------------
Sketchup.write_default('Kuechenplaner_Einstellungen', 'wandabstand', 20.0)
[r1, r2, r3, ob].each { |i| model.entities.instances.delete(i) }
model.selection.clear
neu = UnterschrankSchubladen.erstellen(UnterschrankSchubladen::DEFAULTS)
wz = model.werkzeug
check(wz.is_a?(A::Werkzeug), 'leerer Raum: erster Schrank hängt an der Maus')
bn = A.bezug(neu)
lz = ->(w) { [w.ziel[1], w.ziel[2], w.ziel[3]] }
wz.setze_punkt(100.cm, 280.cm)
x, y, z = lz.(wz)
check(wz.wand.zero? && nah(y + bn[3], 298.cm, 1e-6) && nah(z, vr[:sockel], 1e-6), "an Wand 1: Rückseite 20 mm vor der Wand, auf dem Sockel (#{[x, y, z]})")
check(nah(x + (bn[0] + bn[1]) / 2, 100.cm, 1e-6), 'an Wand 1: Mitte unter der Maus')
wz.setze_punkt(150.cm, 50.cm) # Maus weit weg: bleibt an Wand 1
check(wz.wand.zero? && nah(lz.(wz)[1] + bn[3], 298.cm, 1e-6), 'Wand bleibt, nur entlang verschieben')
wz.setze_punkt(5.cm, 280.cm)
check(nah(lz.(wz)[0] + bn[0], 2.cm, 1e-6), "Ecke links: seitlich 20 mm zu Wand 4 (#{lz.(wz)[0]})")
wz.setze_punkt(-80.cm, 280.cm)
check(nah(lz.(wz)[0] + bn[0], 2.cm, 1e-6), 'nie in die Nachbarwand: bleibt in der Ecke stehen')
wz.setze_punkt(238.cm, 280.cm)
check(nah(lz.(wz)[0] + bn[1], 238.cm, 1e-6), 'Ecke rechts: seitlich 20 mm zu Wand 2')
# Tab: Wand 2 (rechts), Schrank gedreht, Rückseite 20 mm vor x = 240
wz.taste_tab
wz.setze_punkt(200.cm, 150.cm)
e = R.ecken(bn, wz.ziel)
check(wz.wand == 1 && nah(e.map { |q2| q2[0] }.max, 238.cm, 1e-6), "Tab: an Wand 2 (#{e.map { |q2| q2[0] }.max * 2.54})")
wz.shift = true
wz.taste_tab
wz.shift = false
check(wz.wand.zero?, 'Shift+Tab: zurück an Wand 1')
3.times { wz.taste_tab }
check(wz.wand == 3, 'Tab läuft durch alle Wände')
wz.taste_tab
check(wz.wand.zero?, 'nach der letzten Wand wieder Wand 1')
# absetzen
fake_view = Struct.new(:model).new(model)
wz.setze_punkt(5.cm, 280.cm)
wz.onLButtonDown(0, 0, 0, fake_view)
check(nah(o(neu)[0] + bn[0], 2.cm, 1e-6), 'Klick setzt ab')

# zweiter Schrank ohne Markierung: ans freie Zeilenende
model.selection.clear
t60 = UnterschrankSchubladen.erstellen(UnterschrankSchubladen::DEFAULTS.merge('Tiefe' => 90.0))
bt = A.bezug(t60)
check(nah(o(t60)[0] + bt[0], o(neu)[0] + bn[1], 1e-6), 'ohne Markierung: ans freie Zeilenende')
model.entities.instances.delete(t60)
# tieferer Schrank im Werkzeug: stößt an den ersten und bleibt anliegend stehen
wz2 = A::Werkzeug.new(t60)
wz2.setze_punkt(20.cm, 280.cm)
check(nah(wz2.ziel[1] + bt[0], o(neu)[0] + bn[1], 1e-6), "gleitet nicht in den Nachbarn, liegt an (#{(wz2.ziel[1] + bt[0]) * 2.54})")
check(nah(wz2.ziel[2] + bt[3], 298.cm, 1e-6), 'tieferer Schrank: Rückseite im Wandabstand')
# flacherer Schrank (Tiefe 40) neben dem ersten: vordere Korpusecke gleich
t40 = UnterschrankSchubladen.erstellen(UnterschrankSchubladen::DEFAULTS.merge('Tiefe' => 40.0))
model.entities.instances.delete(t40)
model.select_tool(nil)
wz3 = A::Werkzeug.new(t40)
b4 = A.bezug(t40)
wz3.setze_punkt(90.cm, 280.cm)
check(nah(wz3.ziel[2] + b4[2], o(neu)[1] + bn[2], 1e-6) && nah(wz3.ziel[1] + b4[0], o(neu)[0] + bn[1], 1e-6),
      "flacherer Nachbar: Vorderkanten bündig, liegt an (#{wz3.ziel.map { |q2| q2 * 2.54 }})")
wz3.setze_punkt(160.cm, 280.cm)
check(nah(wz3.ziel[2] + b4[3], 298.cm, 1e-6), 'frei an der Wand: wieder im Wandabstand')

# Strg = Freihand: folgt der Maus, Höhe mit Pfeil, nur Kollision zählt
wz3.frei = true
wz3.setze_punkt(120.cm, 150.cm)
mx = wz3.ziel[1] + (b4[0] + b4[1]) / 2
check(nah(mx, 120.cm, 1e-6) && nah(wz3.ziel[3], vr[:sockel], 1e-6), 'Freihand: Mitte unter der Maus')
fview = Object.new
def fview.invalidate = nil
wz3.onKeyDown(38, false, 0, fview)
check(nah(wz3.ziel[3], vr[:sockel] + 10 / 25.4, 1e-6), 'Freihand: Pfeil hoch hebt um 10 mm')
alt = wz3.ziel.dup
wz3.setze_punkt(30.cm, 280.cm) # in den ersten Schrank hinein
check(wz3.ziel == alt, 'Freihand: Kollision mit Schrank wird verhindert')
wz3.setze_punkt(120.cm, 310.cm) # in die Wand
check(wz3.ziel == alt, 'Freihand: Kollision mit Wand wird verhindert')
wz3.onKeyUp(17, false, 0, fview)
check(!wz3.frei, 'Strg los: zurück an die Wand')

# Eckschrank L-Form: Bezug mit beiden Rückwänden, Tab erst drehen, dann Wand
model.selection.clear
model.entities.instances.delete(neu)
el = Eckschrank.erstellen({}, l_form: true)
model.entities.instances.delete(el)
model.select_tool(nil)
be = A.bezug(el)
check(nah(be[0], 0, 1e-6), "L-Form: Rückwand von Schenkel B zählt mit (#{be[0]})")
wl = A::Werkzeug.new(el)
wl.setze_punkt(30.cm, 290.cm)
e = R.ecken(be, wl.ziel)
check(nah(e.map { |q2| q2[0] }.min, 2.cm, 1e-6) && nah(e.map { |q2| q2[1] }.max, 298.cm, 1e-6), 'L-Form in der Ecke: beide Rückseiten im Wandabstand')
wl.taste_tab
check(wl.wand.zero? && wl.q == 3, 'Eckschrank: erster Tab dreht nur')
wl.setze_punkt(230.cm, 280.cm)
e = R.ecken(be, wl.ziel)
check(nah(e.map { |q2| q2[1] }.max, 298.cm, 1e-6) && nah(e.map { |q2| q2[0] }.max, 238.cm, 1e-6), 'gedreht: in der rechten Ecke, beide Rückseiten im Wandabstand')
wl.taste_tab
check(wl.wand == 1 && wl.q.zero?, 'Eckschrank: zweiter Tab wechselt die Wand')
check(A.eckschrank?(el) && !A.eckschrank?(t40), 'Eckschrank erkannt')
Sketchup.defaults.delete(['Kuechenplaner_Einstellungen', 'wandabstand'])

# Werkzeug: Tasten
check(!wl.onKeyDown(65, false, 0, fview), 'andere Tasten gehen an SketchUp')
check(!wl.onKeyDown(38, false, 0, fview), 'Pfeil hoch ohne Strg geht an SketchUp')

# alle Schrank-Komponenten rufen den Haken nach dem Erzeugen auf
Dir[File.join(komp, '*/src/*/main.rb')].each do |f|
  src = File.read(f, encoding: 'UTF-8')
  next unless src.include?('model.selection.clear')
  check(src.include?('Kuechenplaner.neuer_schrank(inst) if Kuechenplaner.respond_to?(:neuer_schrank)'),
        "#{File.basename(File.dirname(f))}: ruft Kuechenplaner.neuer_schrank auf")
end

puts $fehler.zero? ? 'test_andocken: alles OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
