# encoding: UTF-8
# Test ohne SketchUp: Sockelfüße aus dem Beschlag-Katalog (Jürgen, 2026-11-07: „Sockelversteller …
# Katalog, dass man diese auswählen kann für die Küche“). Bohrbild im Boden je Modell, Mittelfüße bei
# breiten Schränken, Höhe nach der Sockelhöhe, Beschlagliste, Wahl je Schrank, Hinweis in den Einstellungen.
$LOAD_PATH.unshift(__dir__)
require 'beschlag_helfer'

komp = File.expand_path('../../Komponenten', __dir__)
%w[unterschrank_schubladen oberschrank].each { |k| load File.join(komp, "#{k}/src/#{k}/main.rb") }
load File.expand_path('../src/jt_schrank_cnc/main.rb', __dir__)

S = JTools::SchrankCnc
B = S::Beschlagmodell
K = S::Beschlagkatalog
KE = Kuechenplaner::Einstellungen
MM = 25.4
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

# --- Katalog ---
modelle = K.zur_art('sockelfuss').map { |e| e['kennung'] }
check(modelle.sort == %w[haefele-axilo-78-einpressen haefele-axilo-78-schrauben haefele-sockelfuss-kunststoff haefele-sockelfuss-stahl],
      "Sockelfüße im Katalog: #{modelle}")
K.zur_art('sockelfuss').each { |e| check(K.fehler(e).empty?, "#{e['kennung']}: #{K.fehler(e)}") }
check(K::ARTEN['sockelfuss'][:standard] == 'haefele-axilo-78-schrauben', 'Standard: AXILO 78 zum Schrauben (wie Boden.tcn)')

ax = K.eintrag('haefele-axilo-78-schrauben')
st = K.eintrag('haefele-sockelfuss-stahl')
h = ->(e, s) { x = K.sockelfuss_hoehe(e, s); [x['bauhoehe'], x['artikel'], x['passt']] }
check(h.(ax, 100) == [100, '637.76.353', true], "AXILO bei Sockel 100: H 100 (90–120), nicht 80 (70–100): #{h.(ax, 100)}")
check(h.(ax, 75) == [80, '637.76.352', true] && h.(ax, 60) == [60, '637.76.351', true], 'AXILO bei 75 und 60')
check(h.(ax, 230) == [200, '637.76.357', false], "AXILO bei 230 passt nicht, nächste Höhe 200: #{h.(ax, 230)}")
check(h.(st, 145) [2] == false && h.(st, 130) == [120, '637.19.228', true], 'Stahl: Lücke 140–150, 130 → H 120')
check(K.sockelfuss_bereich(ax) == [53, 220], 'AXILO Bereich 53–220')

# --- Schrank bauen und auswerten ---
def bauen(kennung, breite: 60.0, sockel: 100.0)
  Sketchup.defaults.clear
  model = Sketchup.active_model = Sketchup::Model.new
  KE.setzen('sockelhoehe', sockel, model)
  K.waehlen('sockelfuss', kennung, model)
  s = UnterschrankSchubladen.erstellen({ 'Breite' => breite, 'Tiefe' => 52.0, 'Anz_Schubladen' => 3, 'Anteil_1' => 1.0, 'Anteil_2' => 1.0, 'Anteil_3' => 2.0 })
  ws = []
  S::Export.erzeugen(model, alle_ws: ws)
  [model, s, ws]
end

def fuesse(ws)
  boden = ws.find { |w| w.rolle == 'Boden' }
  [boden, boden.ops.select { |o| o.titel == 'Sockelfuss' }]
end

def liste(ws)
  S::Beschlaege.liste(ws).select { |p| p.gruppe.start_with?('Sockelfüße') }.to_h { |p| [p.beschlag, p.anzahl] }
end

# AXILO zum Schrauben, 600 breit: 4 Füße je 2 × 2 Ø3 × 3 im Raster 64, 20 vom Seitenrand, 60 von vorn/hinten
_, _, ws = bauen('haefele-axilo-78-schrauben')
boden, fu = fuesse(ws)
check(fu.size == 8 && fu.all? { |o| o.art == :reihe && o.d == 3 && o.tiefe == 3 && o.raster == 64 && o.seite == :zmin },
      "AXILO: 8 Reihen Ø3 × 3, Raster 64 auf der Unterseite (#{fu.map { |o| [o.art, o.d, o.tiefe, o.raster] }.uniq})")
check(fu.map { |o| o.daten[:fuss] }.uniq.size == 4, 'AXILO: 4 Füße bei 600 Breite')
xs = fu.flat_map { |o| [o.p0[0], o.p1[0]] }.map { |x| (x - boden.lo[0]).round(3) }.uniq.sort
bb = (boden.hi[0] - boden.lo[0]).round(3)
check(xs == [20.0, 84.0, bb - 84, bb - 20], "AXILO: x 20/84 von beiden Rändern (#{xs}, Boden #{bb})")
l = liste(ws)
check(l['Häfele AXILO 78 Rohr mit Einschraubgleiter H 100, 637.76.353'] == 4, "Beschlagliste: 4 Rohre H 100 (#{l})")
check(l['Häfele AXILO 78 Befestigungsplatte rechteckig zum Schrauben, 637.76.333'] == 4 && l['Spanplattenschraube Ø4 × 16'] == 16,
      'Beschlagliste: 4 Befestigungsplatten, 16 Schrauben')
check(l['Häfele AXILO 78 Sockelblendenclip zum Schrauben, 637.38.054'] == 2, 'Beschlagliste: 2 Sockelblendenclips (vordere Füße)')

# breiter Schrank (1200): Paar in der Mitte, 6 Füße, 3 Clips
_, _, ws = bauen('haefele-axilo-78-schrauben', breite: 120.0)
boden, fu = fuesse(ws)
check(fu.map { |o| o.daten[:fuss] }.uniq.size == 6, "1200 breit: 6 Füße (#{fu.map { |o| o.daten[:fuss] }.uniq.size})")
mitte = (boden.lo[0] + boden.hi[0]) / 2.0
check(fu.any? { |o| ((o.p0[0] + o.p1[0]) / 2.0 - mitte).abs < 0.01 }, 'Mittelfuß mittig')
check(liste(ws)['Häfele AXILO 78 Sockelblendenclip zum Schrauben, 637.38.054'] == 3, '1200 breit: 3 Clips')
# 900 bleibt bei 4 Füßen (erst über 900 mm Bodenlänge)
_, _, ws = bauen('haefele-axilo-78-schrauben', breite: 90.0)
check(fuesse(ws)[1].map { |o| o.daten[:fuss] }.uniq.size == 4, '900 breit: 4 Füße')

# Sockelhöhe 150 → Rohr H 150
_, _, ws = bauen('haefele-axilo-78-schrauben', sockel: 150.0)
check(liste(ws).key?('Häfele AXILO 78 Rohr mit Einschraubgleiter H 150, 637.76.355'), "Sockel 150: Rohr H 150 (#{liste(ws).keys})")

# Einpressen: Ø10 × 12 für die Zapfen, keine Schrauben
_, _, ws = bauen('haefele-axilo-78-einpressen')
_, fu = fuesse(ws)
check(fu.size == 8 && fu.all? { |o| o.d == 10 && o.tiefe == 12 }, 'Einpressen: Ø10 × 12')
check(!liste(ws).key?('Spanplattenschraube Ø4 × 16') && liste(ws)['Häfele AXILO 78 Befestigungsplatte rechteckig zum Einpressen, 637.76.335'] == 4,
      'Einpressen: Platte zum Einpressen, keine Schrauben')

# Kunststoff: eine Markierung Ø3 je Fuß (Mitte 50 vom Seitenrand, 100 von vorn/hinten)
_, _, ws = bauen('haefele-sockelfuss-kunststoff')
boden, fu = fuesse(ws)
check(fu.size == 4 && fu.all? { |o| o.art == :bohrung && o.d == 3 && o.tiefe == 3 }, 'Kunststoff: 4 Einzelbohrungen Ø3')
# (gemessen ab dem Fräsmaß, wie alle Bohrbilder im Boden)
ys = fu.map { |o| (o.p0[1] - boden.lo_f(1)).round(3) }.uniq.sort
check(ys == [100.0, (boden.hi_f(1) - boden.lo_f(1) - 100).round(3)], "Kunststoff: 100 von vorn/hinten (#{ys})")
check(liste(ws)['Häfele Sockelverstellfuß Kunststoff H 100, 637.38.451'] == 4, "Kunststoff H 100 (#{liste(ws)})")

# Stahl: Durchbohrung Ø10 (Stärke + 1) für die Befestigungsschraube M10
_, _, ws = bauen('haefele-sockelfuss-stahl')
boden, fu = fuesse(ws)
check(fu.size == 4 && fu.all? { |o| o.art == :bohrung && o.d == 10 && (o.tiefe - boden.mass(2) - 1).abs < 0.01 }, 'Stahl: Ø10 durch')
l = liste(ws)
check(l['Häfele Sockelverstellfuß Stahl H 100, 637.19.219'] == 4 && l['Befestigungsschraube M10 × 32, 637.45.999'] == 4, "Stahl: Fuß und Schraube (#{l})")
model, s, _ = bauen('haefele-sockelfuss-stahl', sockel: 145.0)
p = S::Beschlaege.liste(begin; w = []; S::Export.erzeugen(model, alle_ws: w); w; end).find { |x| x.beschlag.start_with?('Häfele Sockelverstellfuß Stahl') }
check(p && p.hinweis.include?('passt nicht'), "Stahl bei 145: Hinweis passt nicht (#{p && p.hinweis})")
check(S::Einstellungen.sockelfuss_hinweis(model).to_s.include?('150–170'), 'Einstellungen: Hinweis mit Einstellbereichen')
KE.setzen('sockelhoehe', 100.0, model)
check(S::Einstellungen.sockelfuss_hinweis(model).nil?, 'Einstellungen: passt bei 100')

# --- Wahl je Schrank und Schrank-Dialog ---
model, s, _ = bauen('haefele-axilo-78-schrauben')
o = Oberschrank.erstellen({})
check(S::Schrankbeschlag.arten(s).include?('sockelfuss') && !S::Schrankbeschlag.arten(o).include?('sockelfuss'),
      'Schrank-Dialog: Sockelfuß beim Unterschrank, nicht beim Oberschrank')
K.schrank_waehlen(s, 'sockelfuss', 'haefele-sockelfuss-stahl', model)
ws = []
S::Export.erzeugen(model, alle_ws: ws)
_, fu = fuesse(ws.select { |w| w.teil.pfad.first == s })
check(fu.all? { |o| o.d == 10 }, 'eigene Wahl des Schranks gilt im TCN')
check(liste(ws).keys.any? { |k| k.include?('Stahl') }, 'eigene Wahl des Schranks gilt in der Beschlagliste')

KE.setzen('sockelhoehe', 100.0)
puts $fehler.zero? ? 'Sockelfüße: alle Tests OK' : "Sockelfüße: #{$fehler} Fehler"
exit($fehler.zero? ? 0 : 1)
