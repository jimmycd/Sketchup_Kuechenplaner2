# Test ohne SketchUp: Raum – Grundriss, Wände mit Gehrung, Öffnungen, Prüfungen, Aufbau und Dialoge
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
load File.expand_path('../src/raum/main.rb', __dir__)

R = Raum::Rechnung
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end
def nah(a, b, eps = 1e-6)
  a = [a].flatten
  b = [b].flatten
  a.size == b.size && a.zip(b).all? { |x, y| (x - y).abs < eps }
end

# Fläche eines ebenen Polygons (Newell) mit Normale n
def poly_flaeche(pts, n)
  s = [0.0, 0.0, 0.0]
  pts.each_with_index do |p, i|
    q = pts[(i + 1) % pts.size]
    s[0] += p[1] * q[2] - p[2] * q[1]
    s[1] += p[2] * q[0] - p[0] * q[2]
    s[2] += p[0] * q[1] - p[1] * q[0]
  end
  (s[0] * n[0] + s[1] * n[1] + s[2] * n[2]).abs / 2.0
end

# Volumen aus den Flächen (Gauß): 1/3 Σ (p·n) A – nur richtig, wenn die Hülle geschlossen ist
# und alle Normalen nach außen zeigen
def volumen(flaechen)
  flaechen.sum do |f|
    n = f[:normal]
    a = poly_flaeche(f[:pts], n) - f[:loecher].sum { |l| poly_flaeche(l, n) }
    p = f[:pts].first
    (p[0] * n[0] + p[1] * n[1] + p[2] * n[2]) * a / 3.0
  end
end

# --- Grundriss -----------------------------------------------------------------
re = R.rechteck(4000, 3000)
check(R.flaeche(re) < 0, 'Rechteck im Uhrzeigersinn (Raum rechts der Laufrichtung)')
ws = R.waende(re, true, 240)
check(ws.map { |w| w[:laenge].round } == [4000, 3000, 4000, 3000], "Wandlängen = Innenmaße: #{ws.map { |w| w[:laenge] }}")
check(ws.all? { |w| nah(w[:a], -240) && nah(w[:b], 240) }, 'Gehrung an allen Außenecken um die Wanddicke')
w1 = ws.first
check(nah(w1[:start], [0, 3000]) && nah(w1[:winkel], 0), 'Wand 1 = hinten, von links nach rechts')
# y-Achse der Wand zeigt nach außen (in die Wand hinein)
check(nah([-Math.sin(w1[:winkel]), Math.cos(w1[:winkel])], [0, 1]), 'Wand 1: Dicke geht nach außen (+y)')

# Volumen einer Wand ohne und mit Öffnungen
h = 2500.0
d = 240.0
plan = (w1[:laenge] + (w1[:laenge] + w1[:b] - w1[:a])) / 2 * d
check(nah(volumen(R.flaechen(w1, h, d, [])), plan * h, 1e-3), "Wand geschlossen, Volumen = Grundriss × Höhe (#{volumen(R.flaechen(w1, h, d, []))})")
fenster = { 'typ' => 'Fenster', 'wand' => 1, 'abstand' => 500.0, 'breite' => 1000.0, 'hoehe' => 1200.0, 'bruestung' => 950.0,
            'fensterbank' => 'ja', 'ueberstand' => 30.0 }
tuer = { 'typ' => 'Tür', 'wand' => 1, 'abstand' => 2500.0, 'breite' => 885.0, 'hoehe' => 2010.0, 'anschlag' => 'links', 'richtung' => 'innen' }
durch = { 'typ' => 'Durchgang', 'wand' => 1, 'abstand' => 3500.0, 'breite' => 400.0, 'hoehe' => 2000.0 }
oe = [tuer, fenster, durch]
soll = plan * h - d * (1000 * 1200 + 885 * 2010 + 400 * 2000)
check(nah(volumen(R.flaechen(w1, h, d, oe)), soll, 1e-3), "Wand mit Fenster, Tür, Durchgang: Volumen stimmt (#{volumen(R.flaechen(w1, h, d, oe))} statt #{soll})")
check(R.flaechen(w1, h, d, oe).first[:loecher].size == 1, 'Fenster = Loch, Tür und Durchgang = Aussparung bis zum Boden')
check(R.flaechen(w1, h, d, oe).all? { |f| f[:pts].all? { |p| p[2] >= 0 && p[2] <= h && p[1] >= 0 && p[1] <= d } },
      'alle Punkte innerhalb der Wand')

# Ecke nach innen (L-Raum): Gehrung kürzt die Außenseite, Volumen stimmt
l_raum = [[0, 3000], [2000, 3000], [2000, 1500], [4000, 1500], [4000, 0], [0, 0]]
check(R.flaeche(l_raum) < 0, 'L-Raum im Uhrzeigersinn')
lw = R.waende(l_raum, true, 200)
check(nah(lw[2][:a], 200) && nah(lw[1][:b], -200), "einspringende Ecke: Außenseite kürzer (a=#{lw[2][:a]}, b=#{lw[1][:b]})")
lw.each do |w|
  pl = (w[:laenge] + (w[:laenge] + w[:b] - w[:a])) / 2 * 200
  check(nah(volumen(R.flaechen(w, h, 200, [])), pl * h, 1e-3), "L-Raum Wand #{w[:nr]}: Hülle geschlossen")
end
# schräge Ecke 135°
schraeg = R.waende([[0, 0], [0, 2000], [1000, 3000], [3000, 3000]], false, 240)
check(nah(schraeg.first[:a], 0) && nah(schraeg.last[:b], 0), 'offener Zug: gerade Enden')
check(nah(schraeg[0][:b], 240 * Math.tan(Math::PI / 8)) && nah(schraeg[1][:a], -240 * Math.tan(Math::PI / 8)), 'Gehrung bei 45° Knick')
check(nah(volumen(R.flaechen(schraeg[1], h, 240, [])), (schraeg[1][:laenge] + (schraeg[1][:laenge] + schraeg[1][:b] - schraeg[1][:a])) / 2 * 240 * h, 1e-3),
      'schräge Wand: Hülle geschlossen')

# --- Prüfungen --------------------------------------------------------------------
check(R.pruefe_wand(w1, h, oe).nil?, "gültige Öffnungen: #{R.pruefe_wand(w1, h, oe)}")
check(R.pruefe_wand(w1, h, [fenster.merge('abstand' => 5.0)]).to_s.include?('passt nicht'), 'zu nah am Wandanfang')
check(R.pruefe_wand(w1, h, [fenster.merge('abstand' => 3500.0)]).to_s.include?('passt nicht'), 'über das Wandende hinaus')
check(R.pruefe_wand(w1, h, [fenster.merge('bruestung' => 1400.0)]).to_s.include?('Decke'), 'Fenster bis in die Decke')
check(R.pruefe_wand(w1, h, [fenster, tuer.merge('abstand' => 1400.0)]).to_s.include?('überschneiden'), 'Öffnungen überschneiden sich')
check(R.pruefe_wand(lw[2], h, [fenster.merge('abstand' => 100.0)]).to_s.include?('passt nicht'),
      'einspringende Ecke: Öffnung muss hinter der Gehrung beginnen')
check(R.pruefe_raum(2500, 50).to_s.include?('Wanddicke'), 'zu dünne Wand')
check(R.pruefe('punkte' => re, 'geschlossen' => true, 'hoehe' => 2500, 'dicke' => 240, 'oeffnungen' => [fenster.merge('wand' => 9)]).to_s.include?('gibt es nicht'),
      'Öffnung an fehlender Wand')
check(R.pruefe('punkte' => [[0, 0], [50, 0]], 'geschlossen' => false, 'hoehe' => 2500, 'dicke' => 240).to_s.include?('kürzer'), 'zu kurze Wand')

# --- Linien zu Grundriss -------------------------------------------------------------
kanten = [[[4000, 0], [4000, 1500]], [[0, 3000], [0, 0]], [[2000, 3000], [0, 3000]], [[4000, 1500], [2000, 1500]],
          [[0, 0], [4000, 0]], [[2000, 1500], [2000, 3000]]]
pk, gk = R.kette(kanten.shuffle(random: Random.new(3)))
check(gk && pk.size == 6, "geschlossener Linienzug: #{pk.inspect}")
check(nah(R.flaeche(R.orientieren(pk, gk)).abs, R.flaeche(l_raum).abs) && R.flaeche(R.orientieren(pk, gk)) < 0, 'geschlossen: im Uhrzeigersinn')
pk, gk = R.kette([[[0, 3000], [0, 1000]], [[0, 1000], [0, 0]], [[0, 0], [4000, 0]]])
check(!gk && pk.size == 3, "offener Zug, zwei Linien in einer Flucht = eine Wand: #{pk.inspect}")
o = R.orientieren(pk, gk)
w = R.waende(o, false, 240)
# Raum liegt in der Ecke (x > 0, y > 0): Außenseite (+y lokal) zeigt weg davon
mitte = [w[0][:start][0] + Math.cos(w[0][:winkel]) * 500, w[0][:start][1] + Math.sin(w[0][:winkel]) * 500]
aussen = [mitte[0] - Math.sin(w[0][:winkel]) * 100, mitte[1] + Math.cos(w[0][:winkel]) * 100]
check(aussen[0] < 0 || aussen[1] < 0, "L-Wandreihe: Dicke geht von der Ecke weg nach außen (#{aussen})")
begin
  R.kette([[[0, 0], [100, 0]], [[0, 0], [0, 100]], [[0, 0], [-100, 0]]])
  check(false, 'Verzweigung wird erkannt')
rescue Raum::Fehler => e
  check(e.message.include?('verzweigen'), e.message)
end
begin
  R.kette([[[0, 0], [1000, 0]], [[0, 500], [1000, 500]]])
  check(false, 'getrennte Züge werden erkannt')
rescue Raum::Fehler => e
  check(e.message.include?('getrennte'), e.message)
end
einzeln = R.orientieren([[0, 0], [3000, 0]], false, [1500, -2000])
check(nah(R.waende(einzeln, false, 240).first[:winkel], 0), 'einzelne Wand: Raum auf der Seite des Betrachters (unten)')
einzeln = R.orientieren([[0, 0], [3000, 0]], false, [1500, 2000])
check(nah(R.waende(einzeln, false, 240).first[:winkel].abs, Math::PI), 'einzelne Wand: Betrachter oben, Wand umgedreht')

# --- Teile und Einrasten ----------------------------------------------------------------
tf = R.teile(fenster, d)
check(tf.size == 6 && tf.all? { |t| t[4].all?(&:positive?) }, "Fenster: Rahmen, Glas, Fensterbank mit positiven Maßen (#{tf.map(&:first)})")
bank = tf.find { |t| t[0] == 'Fensterbank' }
check(nah(bank[3][2] + bank[4][2], 950) && nah(bank[3][1], -30), 'Fensterbank: Oberkante = Brüstung, 30 mm in den Raum')
check(R.teile(fenster.merge('fensterbank' => 'nein'), d).size == 5, 'ohne Fensterbank')
tt = R.teile(tuer, d)
check(tt.size == 4 && tt.all? { |t| t[2] == Raum::TAG_TUER }, 'Tür: Zarge und Blatt')
a = R.aufschlag(tuer, d)
check(a.all? { |p| p[1] <= 1e-9 } && nah(a[1][0], 2500 + 30 + 825) && nah(a.last[1], -825, 1e-6), 'Aufschlag nach innen, Bänder links, Radius = Blatt')
a = R.aufschlag(tuer.merge('anschlag' => 'rechts', 'richtung' => 'aussen'), d)
check(a.all? { |p| p[1] >= d - 1e-9 } && nah(a[0][0], 2500 + 885 - 30), 'Aufschlag nach außen, Bänder rechts')
check(R.teile(durch, d).empty? && R.aufschlag(fenster, d).nil?, 'Durchgang ohne Teile, Fenster ohne Bodenaufschlag')
kl, kr = R.kanten(w1, oe)
check(kl == [0.0, 3385.0, 3900.0] && kr == [4000.0, 2500.0, 3500.0], "Einrastkanten: Wandenden und Laibungen bis zum Boden (#{kl} / #{kr})")
check(R.abstand_aus_text('850', 4000, 1000) == 850 && R.abstand_aus_text('r850', 4000, 1000) == 2150 &&
      R.abstand_aus_text('1200,5mm', 4000, 1000) == 1200.5 && R.abstand_aus_text('abc', 4000, 1000).nil?, 'Maßfeld: von links, von rechts')
check(R.platzieren(4000, 1234, 1000) == 730, 'Öffnung mittig unter der Maus, 10-mm-Raster')

# --- Aufbau in SketchUp (Attrappe) -----------------------------------------------------------
model = $model = Sketchup.active_model = Sketchup::Model.new
raum = Raum.anlegen(model, re, true, 2500, 240)
wi = raum.entities.grep(Sketchup::ComponentInstance)
check(Raum.raum?(raum) && wi.size == 4 && wi.all? { |i| Raum.wand?(i) }, 'Raum-Gruppe mit 4 Wänden')
check(wi.all? { |i| i.layer.name == 'Raum-Wand' && i.material.name == 'Raum Wand' }, 'Wände auf Tag Raum-Wand mit Material Raum Wand')
check(raum.entities.grep(Sketchup::Group).map(&:name) == ['Boden'], 'Boden des Raums')
w2 = wi[1]
check(nah(w2.transformation.origin.to_a.map { |v| v * 25.4 }, [4000, 3000, 0]) && w2.get_attribute('JT_Raum', 'laenge') == 3000.0,
      'Wand 2 beginnt an der Innenecke hinten rechts')
# alle Wandflächen zeigen nach außen (Normale wie gewünscht)
flaechen = wi.first.definition.entities.grep(Sketchup::Face)
check(flaechen.size == 6 && flaechen.none?(&:geloescht), "Wand ohne Öffnung: 6 Flächen (#{flaechen.size})")
check(model.materials.to_a.none? { |m| m.respond_to?(:get_attribute) }, 'keine OpenCutList-Materialien')

f = Raum.aendern(raum, 'Test') { |dd| dd['oeffnungen'] = [fenster, tuer] }
check(f.nil?, "Öffnungen einsetzen: #{f}")
wi = raum.entities.grep(Sketchup::ComponentInstance)
check(wi.size == 4 && model.definitions.h.keys.grep(/Raum Wand/).size == 4, "neu gebaut, alte Wand-Definitionen entfernt (#{model.definitions.h.keys})")
ents = wi.first.definition.entities
check(ents.grep(Sketchup::Group).map(&:name).sort == ['Aufschlag', 'Fensterbank', 'Glas', 'Rahmen links', 'Rahmen oben', 'Rahmen rechts', 'Rahmen unten',
                                                      'Tuerblatt', 'Zarge links', 'Zarge oben', 'Zarge rechts'].sort, 'Fenster- und Türteile in der Wand')
check(wi.first.get_attribute('JT_Raum', 'kanten_links') == [0.0, 3385.0], 'Einrastkanten an der Wand-Instanz')
f = Raum.aendern(raum, 'Test') { |dd| dd['hoehe'] = 1500 }
check(f.to_s.include?('Decke') && Raum.daten(raum)['hoehe'] == 2500.0, "zu niedrig für das Fenster: abgelehnt, nichts geändert (#{f})")

# --- Dialoge und Werkzeug ------------------------------------------------------------------
model = $model = Sketchup.active_model = Sketchup::Model.new
$antworten = [%w[3600 2800 2600 175 120]]
raum = Raum.raum_anlegen_dialog(model)
check(raum && Raum.daten(raum)['dicke'] == 175.0 && model.selection.to_a == [raum], 'Raum anlegen über den Dialog, danach ausgewählt')
check(Raum.daten(raum)['sockel'] == 120.0 && raum.entities.grep(Sketchup::ComponentInstance).all? { |i| i.get_attribute('JT_Raum', 'sockel') == 120.0 },
      'Sockelhöhe aus dem Dialog an Raum und Wänden')
$antworten = [['Tür'], %w[900 2000 rechts innen]]
Raum.einsetzen_dialog(model)
wz = model.werkzeug
check(wz.is_a?(Raum::Einsetzen), 'Einsetzen-Werkzeug aktiv')
wand3 = raum.entities.grep(Sketchup::ComponentInstance)[2]
view = Object.new
def view.invalidate = nil
wz.instance_variable_set(:@ziel, { raum: raum, nr: 3, laenge: 3600.0, tr: wand3.transformation, x: 0 })
wz.onUserText('r300', view)
t = Raum.daten(raum)['oeffnungen'].first
check(t && t['wand'] == 3 && t['abstand'] == 2400.0 && t['anschlag'] == 'rechts', "Tür über Maßfeld 300 mm von rechts gesetzt: #{t}")
$meldungen = []
wz.instance_variable_set(:@ziel, { raum: raum, nr: 3, laenge: 3600.0, tr: wand3.transformation, x: 0, abstand: 2000.0 })
wz.onLButtonDown(0, 0, 0, view)
check(Raum.daten(raum)['oeffnungen'].size == 1 && $meldungen.first.to_s.include?('überschneiden'), 'überschneidende Tür abgelehnt mit Meldung')

# Öffnung bearbeiten: Wand ausgewählt, Abstand ändern, dann löschen
model.selection.clear
model.selection.add(raum.entities.grep(Sketchup::ComponentInstance)[2])
$antworten = [%w[900 2000 rechts innen 1000 ändern]]
check(Raum.oeffnung_bearbeiten_dialog(model) && Raum.daten(raum)['oeffnungen'].first['abstand'] == 1000.0, 'Öffnung verschoben')
model.selection.clear
model.selection.add(raum.entities.grep(Sketchup::ComponentInstance)[2])
$antworten = [%w[900 2000 rechts innen 1000 löschen]]
Raum.oeffnung_bearbeiten_dialog(model)
check(Raum.daten(raum)['oeffnungen'].empty?, 'Öffnung gelöscht')

# Raum bearbeiten
model.selection.clear
model.selection.add(raum)
$antworten = [%w[2400 300 80]]
Raum.raum_bearbeiten_dialog(model)
check(Raum.daten(raum)['hoehe'] == 2400.0 && Raum.daten(raum)['dicke'] == 300.0 && Raum.daten(raum)['sockel'] == 80.0,
      'Raumhöhe, Wanddicke und Sockelhöhe geändert')
check(raum.entities.grep(Sketchup::ComponentInstance).all? { |i| i.get_attribute('JT_Raum', 'sockel') == 80.0 }, 'neue Sockelhöhe an den Wänden')
check(R.pruefe('punkte' => re, 'geschlossen' => true, 'hoehe' => 2500, 'dicke' => 240, 'sockel' => 400).to_s.include?('Sockel'), 'Sockelhöhe über 300 mm abgelehnt')
check(R.sockel({}) == 100.0, 'alter Raum ohne Sockelangabe: 100 mm')

# Wände aus Linien (offene L-Form, Betrachter im Raum)
model = $model = Sketchup.active_model = Sketchup::Model.new
cam = Struct.new(:eye).new(Geom::Point3d.new(50, 50, 60))
model.active_view = Struct.new(:camera).new(cam)
p = ->(x, y) { Geom::Point3d.new(x / 25.4, y / 25.4, 0) }
model.selection.add(Sketchup::Edge.new(p.(0, 3000), p.(0, 0)))
model.selection.add(Sketchup::Edge.new(p.(4000, 0), p.(0, 0)))
$antworten = [%w[2500 240 100]]
raum = Raum.waende_aus_linien(model)
check(raum && raum.entities.grep(Sketchup::ComponentInstance).size == 2 && raum.entities.grep(Sketchup::Group).empty?,
      'zwei Wände aus Linien, offener Zug ohne Boden')
model.selection.clear
model.selection.add(Sketchup::Edge.new(p.(0, 0), p.(1000, 0)))
model.selection.add(Sketchup::Edge.new(p.(0, 0), p.(0, 1000)))
model.selection.add(Sketchup::Edge.new(p.(0, 0), p.(-1000, 0)))
$meldungen = []
Raum.waende_aus_linien(model)
check($meldungen.last.to_s.include?('verzweigen'), 'verzweigte Linien: Meldung statt Absturz')

# Menü
check(Kuechenplaner::GRUPPEN.include?('Raum'), 'Menügruppe Raum')

puts $fehler.zero? ? 'test_raum: alles OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
