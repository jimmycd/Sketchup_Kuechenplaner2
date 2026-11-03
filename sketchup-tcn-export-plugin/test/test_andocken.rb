# Test ohne SketchUp: Andock-Werkzeug – Einrast-Rechnung und Einbindung in die Komponenten.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
komp = File.expand_path('../../Komponenten', __dir__)
%w[unterschrank_schubladen hochschrank oberschrank unterschrank_geschirrspueler unterschrank_kuehlschrank blenden].each { |k| load File.join(komp, k, 'src', k, 'main.rb') }
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
check(R.hoehe(K, 'Unterschrank', K, 0, 'Unterschrank', 99) == 0, 'Unterschrank neben Unterschrank: Höhe vom Nachbarn')
check(R.hoehe(OS, 'Oberschrank', OS, 145, 'Oberschrank', 0) == 145, 'Oberschrank neben Oberschrank: Höhe vom Nachbarn')
check(R.hoehe(OS, 'Oberschrank', HS, 0, 'Hochschrank', 0) == 150, 'Oberschrank neben Hochschrank: Oberkanten bündig')
check(R.hoehe(OS, 'Oberschrank', K, 0, 'Unterschrank', 140) == 140, 'Oberschrank neben Unterschrank: eigene Höhe')
check(R.hoehe(K, 'Unterschrank', OS, 145, 'Oberschrank', 0) == 0, 'Unterschrank neben Oberschrank: eigene Höhe')
check(R.hoehe(HS, 'Hochschrank', K, 0, 'Unterschrank', 7) == 0, 'Hochschrank neben Unterschrank: gleiche Unterkante')

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
check(nah(R.raum_hoehe('Unterschrank', 10, 150, 99), 10 + 150 / 25.4), 'Raumwand: Unterschrank auf Fußboden + Sockelhöhe des Raums')
check(nah(R.raum_hoehe('Hochschrank', 0, nil, 99), 100 / 25.4), 'Raumwand: ohne Angabe 100 mm Sockel')
check(nah(R.raum_hoehe('Hochschrank', 0, 0, 99), 0), 'Raumwand: Sockelhöhe 0 möglich')
check(R.raum_hoehe('Oberschrank', 0, 150, 99) == 99, 'Raumwand: Oberschrank behält seine Höhe')
# Wand 2 (rechts, läuft in -y): Schrank um -90° gedreht, Rückseite an x = 400
w, x, y, = R.an_raumwand(K, [-V, 400, 300, 0], 30, [0], [300], 10)
e = R.ecken(K, [w, x, y, 0])
check(nah(e.map { |p| p[0] }.max, 400) && nah(e.map { |p| p[1] }.max, 300), "Raumwand rechts: in der Ecke hinten rechts (#{e.map { |p| p[0] }.max}, #{e.map { |p| p[1] }.max})")

check(nah(R.winkel(4 * V + 1e-12), 0) && nah(R.winkel(-V), 3 * V), 'Winkel auf 90° gerundet und 0..360°')

# --- Einbindung: neuer Schrank in SketchUp -----------------------------------------
model = Sketchup.active_model = Sketchup::Model.new
us1 = UnterschrankSchubladen.erstellen(UnterschrankSchubladen::DEFAULTS)
check(model.werkzeug.is_a?(A::Werkzeug), 'ohne Auswahl: neuer Schrank hängt am Andock-Werkzeug')
check(model.selection.to_a == [us1], 'neuer Schrank ist danach ausgewählt')
k1 = A.kasten(us1)
check(nah(k1[1] - k1[0], 60.cm, 1e-6), "Kasten = Breite des Schranks (#{k1})")

model.select_tool(nil)
us2 = UnterschrankSchubladen.erstellen(UnterschrankSchubladen::DEFAULTS)
check(model.werkzeug.nil?, 'mit ausgewähltem Schrank: kein Werkzeug, direkt angereiht')
k2 = A.kasten(us2)
check(nah(us2.transformation.origin.to_a[0] + k2[0], us1.transformation.origin.to_a[0] + k1[1], 1e-6),
      "angereiht: rechts bündig daneben (#{us2.transformation.origin.to_a})")
check(nah(us2.transformation.origin.to_a[1..2], us1.transformation.origin.to_a[1..2], 1e-6), 'angereiht: gleiche Flucht und Höhe')

# Oberschrank an Hochschrank: Oberkanten bündig
model.selection.clear
hs = Hochschrank.erstellen({})
model.select_tool(nil)
os = Oberschrank.erstellen({})
kh = A.kasten(hs)
ko = A.kasten(os)
check(nah(os.transformation.origin.to_a[2] + ko[5], hs.transformation.origin.to_a[2] + kh[5], 1e-6), 'Oberschrank an Hochschrank: Oberkanten bündig')

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
model.selection.add(us1)
wg = Blenden.erstellen(:wange, {})
kw = A.kasten(wg)
check(nah(kw[4], 0) && nah(wg.transformation.origin.to_a[2], us1.transformation.origin.to_a[2], 1e-6),
      "Wange angereiht: Unterkante Korpus gleich, Wange reicht bis zum Boden (#{wg.transformation.origin.to_a}, #{kw})")
check(nah(wg.transformation.origin.to_a[0] + kw[0], us1.transformation.origin.to_a[0] + k1[1], 1e-6), 'Wange rechts neben dem Schrank')

# Werkzeug: Tab dreht, Pfeil hoch schaltet die Bündigkeit
wz = A::Werkzeug.new(us1)
view = Object.new
def view.invalidate = nil
check(wz.onKeyDown(9, false, 0, view) && wz.instance_variable_get(:@drehung) == 1, 'Tab dreht um 90°')
check(wz.onKeyDown(37, false, 0, view) && wz.instance_variable_get(:@drehung) == 0, 'Pfeil links dreht zurück')
wz.onKeyDown(38, false, 0, view)
check(wz.instance_variable_get(:@buendig) == :vorne, 'Pfeil hoch: Fronten bündig')
check(!wz.onKeyDown(65, false, 0, view), 'andere Tasten gehen an SketchUp')

# alle Schrank-Komponenten rufen den Haken nach dem Erzeugen auf
Dir[File.join(komp, '*/src/*/main.rb')].each do |f|
  src = File.read(f, encoding: 'UTF-8')
  next unless src.include?('model.selection.clear')
  check(src.include?('Kuechenplaner.neuer_schrank(inst) if Kuechenplaner.respond_to?(:neuer_schrank)'),
        "#{File.basename(File.dirname(f))}: ruft Kuechenplaner.neuer_schrank auf")
end

puts $fehler.zero? ? 'test_andocken: alles OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
