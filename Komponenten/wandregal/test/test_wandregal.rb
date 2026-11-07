# Test ohne SketchUp (Mock-API): Wandregal mit Spalten, Reihen je Spalte, eigenen Fachhöhen und
# Breiten, Mittelwänden, Rückwand ja/nein; Anleimer, Tags, JT_Schrank, Neuaufbau nach Änderungen.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
load File.expand_path('../src/wandregal/main.rb', __dir__)

W = Wandregal
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

def neu_model
  Sketchup.active_model = Sketchup::Model.new
end

# Teile eines Regals: Name => { pos (cm), box (cm), inst }
def teile(inst)
  inst.definition.entities.instances.to_h do |c|
    [c.name, { pos: c.transformation.origin.map { |v| v * 2.54 }, box: c.definition.box.map { |v| v * 2.54 }, inst: c }]
  end
end

def kanten(c)
  c.definition.entities.faces.select { |f| f.material && f.material.name == W::KANTE }.map { |f| f.normal.to_a.map(&:round) }.sort
end

def nah(a, b) = (a - b).abs < 1e-4

mk = 1.9

# --- Standard: eine Spalte, zwei Reihen, Rückwand ---
neu_model
inst = W.erstellen
t = teile(inst)
check(t.keys.sort == %w[Boden Deckel Mittelboden1 Rueckwand SeiteL SeiteR], "Standard: Teile #{t.keys}")
check(nah(t['SeiteR'][:pos][0], 60 - mk) && nah(t['SeiteL'][:box][2], 35) && nah(t['SeiteL'][:box][1], 25), 'Standard: Seiten 350 hoch, 250 tief')
check(nah(t['Boden'][:pos][0], mk) && nah(t['Boden'][:box][0], 60 - 2 * mk) && nah(t['Boden'][:box][1], 25), 'Boden zwischen den Seiten, volle Tiefe')
check(nah(t['Deckel'][:pos][2], 35 - mk), 'Deckel oben')
ti = 25 - 2.5 - 0.8
check(nah(t['Mittelboden1'][:box][1], ti) && nah(t['Mittelboden1'][:pos][2], mk + (35 - 3 * mk) / 2), "Fachboden vor der Rückwand, gleich hohe Fächer (#{t['Mittelboden1']})")
rw = t['Rueckwand']
check(nah(rw[:pos][1], mk + ti) && nah(rw[:box][0], 60 - 2 * mk + 1.8) && nah(rw[:box][2], 35 - 2 * mk + 1.8) && nah(rw[:pos][2], mk - 0.9),
      "Rückwand in der Nut von Seiten, Boden und Deckel, 25 mm vor der Hinterkante (#{rw})")
check(kanten(t['SeiteL'][:inst]) == [[0, -1, 0], [0, 0, -1], [0, 0, 1]], "Seite: Anleimer vorn, oben, unten #{kanten(t['SeiteL'][:inst])}")
%w[Boden Deckel Mittelboden1].each { |n| check(kanten(t[n][:inst]) == [[0, -1, 0]], "#{n}: Anleimer vorn") }
check(kanten(rw[:inst]).empty?, 'Rückwand ohne Anleimer')
t.each do |n, x|
  c = x[:inst]
  check(c.layer.name == "WR1_#{n}", "Tag #{c.layer.name}")
  check(c.get_attribute('JT_Schrank', 'kategorie') == 'Wandregal' && c.get_attribute('JT_Schrank', 'typ') == 'Wandregal' &&
        c.get_attribute('JT_Schrank', 'schrank') == 'WR1', "JT_Schrank #{n}")
  check(c.get_attribute('JT_Schrank', 'rolle') == W::ROLLEN.fetch(n.sub(/\d+\z/, '')), "Rolle #{n}")
  check(c.material && c.material.name == 'Melamin weiss', "Material #{n}")
end
check(inst.definition.get_attribute('JT_Schrank', 'kategorie') == 'Wandregal', 'Kategorie Wandregal am Regal')
d = inst.definition
check(d.get_attribute('dynamic_attributes', 'summary') == W::HILFE_KURZ, 'Kurzhilfe')
check(!d.get_attribute('dynamic_attributes', 'reihen_1').nil? && d.get_attribute('dynamic_attributes', 'reihen_2').nil?,
      'Felder nur für vorhandene Spalten')
# Listen Spalten/Reihen: Anzeige = Wert (sonst zeigt das Fenster eine Zahl zu viel, Jürgen 2026-11-07)
check(d.get_attribute('dynamic_attributes', '_spalten_options') == '&1=1&2=2&3=3&4=4&', "Spalten-Liste #{d.get_attribute('dynamic_attributes', '_spalten_options')}")
check(d.get_attribute('dynamic_attributes', '_reihen_1_options') == '&1=1&2=2&3=3&4=4&5=5&' && d.get_attribute('dynamic_attributes', 'reihen_1') == 2.0,
      'Reihen-Liste: Wert 2 steht als 2 da')
check(d.get_attribute('dynamic_attributes', '_rueckwand_options') == '&ja=0&nein=1&', 'Rückwand-Liste ja=0, nein=1')
check(d.get_attribute('dynamic_attributes', 'breiten') == 'gleich' && d.get_attribute('dynamic_attributes', '_breiten_units') == 'STRING',
      'Breiten als Text "gleich"')

# --- Spalten mit Mittelwand, je Spalte eigene Reihen und Höhen, Breiten ---
neu_model
inst = W.erstellen('Breite' => 80.0, 'Hoehe' => 60.0, 'Spalten' => 3.0, 'Breiten' => '300;200',
                   'Reihen_1' => 1.0, 'Reihen_2' => 3.0, 'Hoehen_2' => '150;250', 'Reihen_3' => 2.0, 'Hoehen_3' => '100')
t = teile(inst)
check(t.keys.grep(/Mittelwand/).sort == %w[Mittelwand1 Mittelwand2], "3 Spalten: zwei Mittelwände #{t.keys}")
check(t.keys.grep(/Mittelboden/).size == 0 + 2 + 1, "Fachböden: 0 + 2 + 1 (#{t.keys.grep(/Mittelboden/)})")
m1, m2 = t['Mittelwand1'], t['Mittelwand2']
check(nah(m1[:pos][0], mk + 30) && nah(m2[:pos][0], mk + 30 + mk + 20), "Mittelwände nach 300 und 200 mm lichter Breite (#{m1[:pos][0]}, #{m2[:pos][0]})")
check(nah(m1[:pos][2], mk) && nah(m1[:box][2], 60 - 2 * mk) && nah(m1[:box][1], ti), 'Mittelwand zwischen Boden und Deckel, bis vor die Rückwand')
b3 = 80 - 2 * mk - 50 - 2 * mk
fb = t.values.select { |x| x[:inst].name.start_with?('Mittelboden') }
sp = fb.group_by { |x| x[:inst].get_attribute('JT_Schrank', 'spalte') }
check(sp.keys.sort == [2, 3], "Fachböden in Spalte 2 und 3 (#{sp.keys})")
z2 = sp[2].map { |x| x[:pos][2] }.sort
check(nah(z2[0], mk + 15) && nah(z2[1], mk + 15 + mk + 25), "Spalte 2: Fächer 150 und 250 mm von unten (#{z2})")
check(sp[2].all? { |x| nah(x[:box][0], 20) && nah(x[:pos][0], m1[:pos][0] + mk) }, 'Spalte 2: Fachböden zwischen den Mittelwänden')
check(nah(sp[3][0][:pos][2], mk + 10) && nah(sp[3][0][:box][0], b3) && nah(sp[3][0][:pos][0], m2[:pos][0] + mk), "Spalte 3: Rest der Breite (#{b3}), Fach 100 mm")
check(%w[reihen_3 hoehen_3].all? { |k| !inst.definition.get_attribute('dynamic_attributes', k).nil? } &&
      inst.definition.get_attribute('dynamic_attributes', 'reihen_4').nil?, 'Felder für drei Spalten')

# --- ohne Rückwand: alles über die volle Tiefe, hinten mit Anleimer ---
neu_model
inst = W.erstellen('Rueckwand' => 1.0, 'Spalten' => 2.0)
t = teile(inst)
check(!t.key?('Rueckwand'), 'ohne Rückwand: keine Rückwand')
check(nah(t['Mittelwand1'][:box][1], 25) && nah(t['Mittelboden1'][:box][1], 25), 'ohne Rückwand: Mittelwand und Fachböden volle Tiefe')
check(kanten(t['SeiteL'][:inst]) == [[0, -1, 0], [0, 0, -1], [0, 0, 1], [0, 1, 0]], 'ohne Rückwand: Seite auch hinten Anleimer')
%w[Boden Mittelwand1 Mittelboden1].each { |n| check(kanten(t[n][:inst]) == [[0, -1, 0], [0, 1, 0]], "ohne Rückwand: #{n} vorn und hinten Anleimer") }

# --- ungültige Eingaben ---
[[{ 'Breiten' => 'abc', 'Spalten' => 2.0 }, 'Breiten'], [{ 'Breiten' => '550', 'Spalten' => 2.0 }, 'zu klein'],
 [{ 'Hoehen_1' => '300;20', 'Reihen_1' => 3.0 }, 'zu klein'], [{ 'Tiefe' => 5.0 }, 'Tiefe'], [{ 'Materialstaerke_Korpus' => 4.0 }, 'Materialstärke']].each do |e, wort|
  begin
    W.berechne(W::DEFAULTS.merge(e))
    check(false, "ungültig #{e}: keine Meldung")
  rescue ArgumentError => ex
    check(ex.message.include?(wort), "ungültig #{e}: #{ex.message}")
  end
end
# mehr Werte als Fächer: der letzte ergibt sich aus dem Rest
h = W.aufteilung('100;100;100', 2, 50.0, mk, 'x')
check(nah(h[0], 10) && nah(h[1], 50 - mk - 10), "zu viele Werte: letzter aus dem Rest (#{h})")
check(W.aufteilung(' gleich ', 2, 50.0, mk, 'x').all? { |x| nah(x, (50 - mk) / 2) } && W.aufteilung('', 1, 50.0, mk, 'x') == [50.0], 'gleich / leer')
check(nah(W.aufteilung('125,5', 2, 50.0, mk, 'x')[0], 12.55), 'Komma als Dezimalzeichen')

# --- Neuaufbau nach Änderung in den Komponentenoptionen ---
neu_model
model = Sketchup.active_model
inst = W.erstellen
inst.transformation = Geom::Transformation.translation([10, 20, 30])
inst.set_attribute('dynamic_attributes', 'spalten', 2.0)
W.pruefen(model)
t = teile(inst)
check(t.key?('Mittelwand1') && t.keys.grep(/Mittelboden/).size == 2, "Spalten 1 -> 2: Mittelwand, Fachböden in beiden Spalten (#{t.keys})")
check(!inst.definition.get_attribute('dynamic_attributes', 'reihen_2').nil?, 'neue Spalte bekommt ihre Felder')
check(t['SeiteL'][:inst].layer.name == 'WR1_SeiteL', 'Kürzel bleibt')
inst.set_attribute('dynamic_attributes', 'reihen_2', 4.0)
inst.set_attribute('dynamic_attributes', 'hoehen_2', '50')
W.pruefen(model)
t = teile(inst)
z = t.values.select { |x| x[:inst].get_attribute('JT_Schrank', 'spalte') == 2 }.map { |x| x[:pos][2] }.min
check(t.keys.grep(/Mittelboden/).size == 1 + 3 && nah(z, mk + 5), "Spalte 2: 4 Reihen, unterstes Fach 50 mm (#{t.keys})")
# Unterkante über Arbeitsplatte geändert: Regal wandert mit
z0 = inst.transformation.origin[2]
inst.set_attribute('dynamic_attributes', 'abstand_ap', 60.0 / 2.54)
W.pruefen(model)
check(nah((inst.transformation.origin[2] - z0) * 2.54, 10), "Abstand 500 -> 600 mm: Regal 100 mm höher (#{(inst.transformation.origin[2] - z0) * 2.54})")
check(nah(inst.transformation.origin[0], 10) && nah(inst.transformation.origin[1], 20), 'Lage bleibt')
# zurück auf eine Spalte: Felder der 2. Spalte verschwinden
inst.set_attribute('dynamic_attributes', 'spalten', 1.0)
W.pruefen(model)
check(inst.get_attribute('dynamic_attributes', 'reihen_2').nil? && inst.definition.get_attribute('dynamic_attributes', 'reihen_2').nil?,
      'eine Spalte: Felder der zweiten Spalte weg')
check(teile(inst).keys.grep(/Mittelwand/).empty?, 'eine Spalte: keine Mittelwand')
# ungültig: alte Werte bleiben
alt = inst.definition
inst.set_attribute('dynamic_attributes', 'hoehen_1', 'xx')
W.pruefen(model)
check(inst.definition.equal?(alt) && inst.get_attribute('dynamic_attributes', 'hoehen_1') == 'gleich', 'ungültig: alte Werte zurück')
# Höhe beim Platzieren (Andock-Werkzeug) gemerkt: kein Neuaufbau, kein Verschieben
z1 = inst.transformation.origin[2]
W.abstand_setzen(inst, 45.0 / 2.54)
W.pruefen(model)
check(inst.definition.equal?(alt) && nah(inst.transformation.origin[2], z1), 'abstand_setzen: kein Neuaufbau')
check(nah(W.eingabe_aus(inst)['Abstand_AP'], 45), 'abstand_setzen: Wert am Regal')
# Frontfarbe
neu_model
inst = W.erstellen('Farbe' => 1.0)
check(teile(inst).values.all? { |x| x[:inst].get_attribute('JT_Schrank', 'frontfarbe') }, 'Frontfarbe: alle Teile markiert')

puts $fehler.zero? ? 'test_wandregal: alles OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
