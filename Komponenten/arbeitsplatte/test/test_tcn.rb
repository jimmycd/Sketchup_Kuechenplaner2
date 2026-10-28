# Test ohne SketchUp: TCN der Arbeitsplatte (Verbindungsfräsung, Ausschnitte) über den Schrank-CNC-Export
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
$VERBOSE = nil
haupt = File.expand_path('../../..', __dir__)
load File.expand_path('../src/arbeitsplatte/main.rb', __dir__)
load File.join(haupt, 'sketchup-tcn-export-plugin/src/jt_schrank_cnc/main.rb')

A = Arbeitsplatte
S = JTools::SchrankCnc
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

class Tr
  def initialize(a)
    @a = a
  end

  def to_a
    @a
  end
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

def bohrungen(text) = text.scan(/W#81\{.* #1=(\S+) #2=(\S+) #3=(\S+) #1002=(\S+)/).map { |x| x.map(&:to_f) }
def bahnen(text, werkzeug)
  text.split("\r\n").each_with_index.select { |z, _| z.include?("#205=#{werkzeug} ") }.map do |z, i|
    x, y, t = z.match(/#1=(\S+) #2=(\S+) #3=(\S+)/).captures.map(&:to_f)
    pts = [[x, y]]
    text.split("\r\n")[(i + 1)..].take_while { |l| l.start_with?('W#2201') }.each do |l|
      dx, dy = l.match(/#1=(\S+) #2=(\S+)/).captures.map(&:to_f)
      pts << [pts.last[0] + dx, pts.last[1] + dy]
    end
    [pts, t]
  end
end
def nahe(a, b, eps = 0.01) = (a - b).abs < eps

# L-Küche wie in test_ausgabe.rb: hinten Blindeck 1000 + 600, links 2 × 600, Gehrungsansatz
model = Sketchup::Model.new
Sketchup.active_model = model
schrank(model, 'UES1', 1000, gerade(0, 20), typ: 'Eckschrank')
schrank(model, 'USS1', 600, gerade(1000, 20))
schrank(model, 'USS2', 600, gedreht90(800, -650))
schrank(model, 'UST1', 600, gedreht90(800, -1250))
A.erzeugen(model, optionen: {})

dateien, meldungen = S::Export.erzeugen(model)
namen = dateien.map(&:name)
check(namen.sort == %w[APL1_Platte1_Stoss1 APL1_Platte2_Stoss1], "je Platte eine TCN am Stoß: #{namen}")
check(meldungen.empty?, "keine Meldungen: #{meldungen}")
a = dateien.find { |d| d.name == 'APL1_Platte1_Stoss1' }
b = dateien.find { |d| d.name == 'APL1_Platte2_Stoss1' }
check(a.text.include?('::UNm DL=1595 DH=835 DS=38') && b.text.include?('::UNm DL=1260 DH=835 DS=38'),
      "Kopf: #{a.text[/::UNm.*/]} / #{b.text[/::UNm.*/]}")

# Verbinder: Stoßlänge 835 -> 3 Stück, 80 von Wand und Vorderkante, 65 vom Stoß
ba = bohrungen(a.text).sort
bb = bohrungen(b.text).sort
check(ba.map { |x, y, _, _| [x, y] } == [[80, 740], [417.5, 740], [755, 740]], "Bohrungen A (weiblich): #{ba}")
check(bb.map { |x, y, _, _| [x, y] }.sort_by(&:last) == [[65, 80], [65, 417.5], [65, 755]], "Bohrungen B (männlich): #{bb}")
check((ba + bb).all? { |_, _, t, d| t == -20 && d == 35 }, 'Ø 35, 20 tief')
# Stege von der Stoßkante zur Bohrung, 12er Fräser
sa = bahnen(a.text, S::Arbeitsplatten::STEG[:werkzeug])
check(sa.size == 3 && sa.all? { |pts, t| t == -20 && pts.size == 2 && nahe(pts[0][1], 805) && nahe(pts[1][1], 740) }, "Stege A: #{sa}")
sb = bahnen(b.text, S::Arbeitsplatten::STEG[:werkzeug])
check(sb.size == 3 && sb.all? { |pts, _| nahe(pts[0][0], 0) && nahe(pts[1][0], 65) }, "Stege B: #{sb}")

# Kontur: durch, um 10 in den Abfall versetzt
ka = bahnen(a.text, S::Arbeitsplatten::KONTUR[:werkzeug])
kb = bahnen(b.text, S::Arbeitsplatten::KONTUR[:werkzeug])
check(ka.size == 1 && kb.size == 1 && ka[0][1] == -39 && kb[0][1] == -39, "je eine Kontur, 39 tief: #{ka.size} #{kb.size}")
pa = ka[0][0]
# A: weiblich, Ende an der Wand (x = 0), dann die Stoßkante 30 hinter der Vorderkante
# (y = 805, Abfall davor), Bogen, Gehrung bis über die Vorderkante (y = 835)
check(pa[0] == [-10, -20] && pa[1] == [-10, 815] && nahe(pa[2][1], 815) && pa[2][0] > 780, "Kontur A Wandende und Stoßkante: #{pa.first(3)}")
check(pa.last[1] > 835 && pa.last[0] > 800, "Kontur A läuft über die Vorderkante hinaus: #{pa.last}")
pb = kb[0][0]
# B: männlich, Spitze bei x = 0, Fräser 10 davor
check(pb.any? { |x, y| nahe(x, -10) && y > 30 && y < 835 }, "Kontur B: #{pb}")
check(pb.all? { |x, _| x <= 30 + 10 + 0.01 }, "Kontur B nur am Gehrungsansatz: #{pb.map(&:first).max}")

# Teileliste mit den Arbeitsplatten
tl = S::Export.teileliste(dateien)
check(tl.include?('APL1_Platte1_Stoss1.tcn;1;APL1;Platte1;Arbeitsplatte;Arbeitsplatte Schichtstoff;1595;835;38'), "Teileliste: #{tl}")

# --- gerade Zeile mit Spüle, ohne Stoß: eine TCN mit dem Ausschnitt ---
m2 = Sketchup::Model.new
Sketchup.active_model = m2
schrank(m2, 'USS1', 600, gerade(0, 20))
schrank(m2, 'USP1', 900, gerade(600, 20), typ: 'Spuelenschrank')
A.erzeugen(m2, optionen: {})
d2, me2 = S::Export.erzeugen(m2)
check(d2.map(&:name) == ['APL1_Platte1'] && me2.empty?, "Platte ohne Stoß: #{d2.map(&:name)} #{me2}")
k = bahnen(d2[0].text, S::Arbeitsplatten::KONTUR[:werkzeug])
# Spüle 800 × 490 mittig über 600..1500, 60 von der Vorderkante, Fräser 10 nach innen
xs = k[0][0].map(&:first)
ys = k[0][0].map(&:last)
check(k.size == 1 && k[0][0].first == k[0][0].last && nahe(xs.min, 660) && nahe(xs.max, 1440) &&
      nahe(ys.min, 835 - 60 - 490 + 10) && nahe(ys.max, 835 - 60 - 10), "Ausschnitt: #{k}")
check(bohrungen(d2[0].text).empty?, 'ohne Stoß keine Verbinder')

# --- Platte ohne gespeicherte Daten: Meldung ---
inst = d2[0].ws.teil.inst
inst.attribute_dictionary('JT_Arbeitsplatte').delete('front') if inst.attribute_dictionary('JT_Arbeitsplatte').respond_to?(:delete)
inst.set_attribute('JT_Arbeitsplatte', 'front', nil)
d3, me3 = S::Export.erzeugen(m2)
check(d3.empty? && me3.any? { |x| x.include?('neu berechnen') }, "fehlende Daten: #{me3}")

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
