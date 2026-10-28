# Test ohne SketchUp: TCN-Export des Korpus (Schritte 5 bis 7) an echten Schränken aus
# Komponenten/ (mit der Mock-API erzeugt), verglichen mit Jürgens Beispiel-TCN.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
require 'tmpdir'
komp = File.expand_path('../../Komponenten', __dir__)
load File.join(komp, 'hochschrank/src/hochschrank/main.rb')
load File.join(komp, 'oberschrank/src/oberschrank/main.rb')
load File.join(komp, 'apothekerschrank/src/apothekerschrank/main.rb')
load File.join(komp, 'hochschrank_geraete/src/hochschrank_geraete/main.rb')
load File.join(komp, 'unterschrank_schubladen/src/unterschrank_schubladen/main.rb')
load File.join(komp, 'unterschrank_spuele/src/unterschrank_spuele/main.rb')
load File.join(komp, 'unterschrank_kochfeld/src/unterschrank_kochfeld/main.rb')
load File.join(komp, 'unterschrank_geschirrspueler/src/unterschrank_geschirrspueler/main.rb')
load File.join(komp, 'unterschrank_handtuch/src/unterschrank_handtuch/main.rb')
load File.join(komp, 'eckschrank/src/eckschrank/main.rb')
load File.expand_path('../src/jt_schrank_cnc/main.rb', __dir__)

S = JTools::SchrankCnc
BEISPIELE = File.expand_path('../beispiele', __dir__)
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

# Bearbeitungszeilen einer Seite, ohne die laufende Nummer WS= und den Namen W$=
def bearbeitungen(text, side)
  block = text.split(/\r?\n/).drop_while { |z| z != "SIDE##{side}{" }.drop(2).take_while { |z| z != '}SIDE' }
  block.map { |z| z.sub(/WS=\d+ +(W\$=\S+ +)?/, 'WS ') }
end

def beispiel(name) = File.binread(File.join(BEISPIELE, name)).force_encoding('Windows-1252').encode('UTF-8')

def kopf(text) = text.split("\r\n").first(3)

model = Sketchup.active_model = Sketchup::Model.new
# Unterschrank 90 x 56 wie die Beispiele Boden/Deckel (DL 862, DH 558)
uss = UnterschrankSchubladen.erstellen({ 'Breite' => 90.0, 'Tiefe' => 56.0 })
dateien, meldungen = S::Export.erzeugen(model)
d = dateien.to_h { |x| [x.name, x] }

# --- Boden = Boden.tcn ---
boden = d['USS1_Boden']
check(boden, 'Boden exportiert')
check(kopf(boden.text) == kopf(beispiel('Boden.tcn')), "Kopf Boden: #{kopf(boden.text)}")
# Dübel wie Boden.tcn, aber "gerade Anzahl" aus, Schritt errechnet und 30 mm ab der fertigen Kante
# (Jürgen 2026-10-28): Tiefe 560, vorn 2 mm Anleimer -> im Fräsmaß 30 … x-28, L = 500, n = 5, ST = 125
[4, 6].each do |s|
  soll = bearbeitungen(beispiel('Boden.tcn'), s).map do |z|
    z.sub('#8508=1 #8509=1', '#8508=0 #8509=0').sub('#8511=x-30', '#8511=x-28').sub('#8512=150', '#8512=125')
  end
  check(bearbeitungen(boden.text, s) == soll, "Boden SIDE##{s}: #{bearbeitungen(boden.text, s)}")
end
# Schritt: höchstens 160, erster und letzter Dübel genau am Rand (abgerundet auf 4 Stellen)
{ 498 => 124.5, 480 => 160.0, 481 => 120.25, 100 => 100.0, 440 => 146.6666, 160 => 160.0 }.each do |l, st|
  check(S::Regeln.schritt(l, 160) == st, "Schritt #{l}: #{S::Regeln.schritt(l, 160)} statt #{st}")
  n = (l / st + 1e-6).floor
  check(st <= 160 && (l - n * st).between?(0, 0.001), "Schritt #{l}: letzter Dübel am Ende")
end

# Dübelreihe Ø8 an der Stirnseite: 30 … x-30, gerade Anzahl aus, Schritt <= 160 und passend zur Länge
# (Fräsmaß: 30 an Kanten ohne, 28 an Kanten mit 2-mm-Anleimer)
def duebel_stirn_ok?(x)
  z = [3, 4, 5, 6].flat_map { |s| bearbeitungen(x.text, s) }.select { |r| r.include?('#8522=8 ') }
  !z.empty? && z.all? do |r|
    a, var, b = r.match(/#8510=(\d+(?:\.\d+)?) #8511=([xy])-(\d+(?:\.\d+)?) /)&.captures
    next false unless a
    l = (var == 'x' ? x.lage.dl : x.lage.dh) - a.to_f - b.to_f
    st = r[/#8512=(\S+)/, 1].to_f
    r.include?('#8508=0 #8509=0 ') && [a, b].all? { |v| %w[28 30].include?(v) } && st <= 160 && st > 0 &&
      ((l / st) - (l / st).round).abs < 1e-4 && (l / st).round == (l / 160.0 - 1e-9).ceil
  end
end
# Sockelfüße wie Boden.tcn; die Vorlage schreibt manche Lagen als Ausdruck und von hinten nach vorn
fuss = bearbeitungen(beispiel('Boden.tcn'), 1).map do |z|
  z.sub('(1*(-64))+(y-60)', 'y-124').sub('#8511=20+64', '#8511=84').sub('#8510=x-20 #8511=x-20-64', '#8510=x-84 #8511=x-20')
end
check(bearbeitungen(boden.text, 1).sort == fuss.sort, "Boden SIDE#1: squad und Sockelfüße wie Boden.tcn: #{bearbeitungen(boden.text, 1)}")
check(boden.lage.flaeche1 == :zmin, 'Boden: Fläche 1 ist die Unterseite (Sockelfüße)')

# --- Strebe = Strebe.tcn, aber 1/1 verteilt (bleibt bei 98 mm Fräsmaß zwei Dübel) ---
s60 = UnterschrankSchubladen.erstellen({ 'Breite' => 60.0, 'Tiefe' => 56.0 })
dateien2, = S::Export.erzeugen(model, auswahl: [s60])
strebe = dateien2.find { |x| x.name == 'USS2_StrebeHinten' }
check(strebe && kopf(strebe.text) == kopf(beispiel('Strebe.tcn')), "Kopf Strebe: #{strebe && kopf(strebe.text)}")
[4, 6].each do |s|
  soll = bearbeitungen(beispiel('Strebe.tcn'), s).map { |z| z.sub('#8508=0 #8509=0', '#8508=1 #8509=1') }
  check(bearbeitungen(strebe.text, s) == soll, "Strebe SIDE##{s}: #{bearbeitungen(strebe.text, s)}")
end
vorn = dateien2.find { |x| x.name == 'USS2_StrebeVorn' }
check((vorn.lage.dh - 98).abs < 1e-6 && bearbeitungen(vorn.text, 4).first.include?('#8510=20 #8511=x-20'), 'Strebe vorn: Fräsmaß 98, 20 … x-20')
check(dateien2.all? { |x| x.ws.teil.schrank.equal?(s60) }, 'Auswahl: nur Teile des gewählten Schranks')

# --- Seite = Seite.tcn (Dübel zu Boden und Streben, Schrauben in die Streben) ---
seite = d['USS1_SeiteR']
z = bearbeitungen(seite.text, 1)
check(seite.lage.dl == 700 && seite.lage.dh == 558 && seite.lage.ds == 19, "Seite Fräsmaß: #{seite.lage.to_a.drop(1)}")
check(z.first.include?('squad.tmcr'), 'Seite: squad zuerst')
boden_reihe = z.find { |x| x.include?('#8518=9.5 ') }
check(boden_reihe&.include?('fittingy.tmcr') && boden_reihe.include?('#8508=0 #8509=0 #8510=28 #8511=y-30 #8512=125 #8513=-14') &&
      boden_reihe.include?('#8522=8 '), "Seite: Dübel Boden bei 9.5 (ohne Anleimer unten), 14 tief (Seiten_SK): #{boden_reihe}")
vorlage = bearbeitungen(beispiel('Seite.tcn'), 1)
hinten = vorlage.select { |x| x.include?('y-80') || x.include?('#2=y-50') }.map { |x| x.gsub('x-7.5', 'x-9.5').sub('#8508=0 #8509=0', '#8508=1 #8509=1').sub('#8513=-12', '#8513=-14') }
hinten = hinten.map { |x| x.sub('#8510=y-20 #8511=y-80', '#8510=y-80 #8511=y-20') }
check(hinten.size == 2 && (hinten - z).empty?, "Seite: Strebe hinten wie Seite.tcn (x-9.5 statt x-7.5, kein Anleimer oben): #{z}")
check(z.any? { |x| x.include?('#8510=20 #8511=78 #8512=60') } && z.any? { |x| x.include?('#1=x-9.5 #2=49 #3=-21 #1002=3') },
      'Seite: Strebe vorn 20 … 78 (Strebe mit Anleimer), Schraube in der Mitte')
check(d['USS1_SeiteL'].text != seite.text && bearbeitungen(d['USS1_SeiteL'].text, 1).size == z.size, 'Seite links gespiegelt')
check(kopf(seite.text)[0].end_with?('s54') && kopf(boden.text)[0].end_with?('s13'), 'Feld s je Rolle wie in den Vorlagen')

# --- alle Dateien ---
dateien.each do |x|
  t = x.text
  check(t.include?("\r\n") && !t.gsub("\r\n", '').include?("\n"), "#{x.name}: CRLF")
  check(t.start_with?('TPA\\ALBATROS\\EDICAD\\02.00:1224:r0w0h0s') && t.include?("\r\n'code=ansi\r\n"), "#{x.name}: Kopf")
  check(bearbeitungen(t, 1).first&.include?('squad.tmcr'), "#{x.name}: squad")
  aktiv = t[/::SIDE=([\d;]+)/, 1].split(';').map(&:to_i)
  check(aktiv == ([1] + [3, 4, 5, 6].reject { |s| bearbeitungen(t, s).empty? }), "#{x.name}: SIDE-Liste #{aktiv}")
  check(x.lage.ds == x.ws.mass(x.ws.dicke_achse), "#{x.name}: DS = Stärke")
end
check(dateien.none? { |x| x.ws.teil.pfad.any?(&:hidden?) }, 'ausgeblendete Teile fehlen')
check(S::Schraenke.teile(model).count { |t| t.pfad.first.equal?(uss) && !t.sichtbar? } > 0, 'Testschrank hat ausgeblendete Teile')
check(meldungen.none? { |m| m.include?('Unterseite') }, "keine Bearbeitung auf der Unterseite: #{meldungen}")
# (im Mock sind alle Schubladen des Unterschranks ausgeblendet, ihre Lage kommt aus DC-Formeln)
lr = z.select { |x| x.include?('#8522=5 ') }
check(lr.size == 2 && lr.all? { |x| x.include?('#8510=57 #8511=x-52 #8512=32') },
      "Unterschrank ohne sichtbare Schubladen: Lochreihen 38 über dem Boden bis unter die Streben: #{lr}")
check(dateien.none? { |x| x.text.include?('W#89') }, 'Unterschrank: Rückwand ohne Nut')

# --- Oberschrank: Anleimer unten an der Seite -> 7.5 wie Seite.tcn; Kopien werden gezählt ---
model = Sketchup.active_model = Sketchup::Model.new
os1 = Oberschrank.erstellen({})
model.entities.add_instance(os1.definition, Geom::Transformation.translation([100, 0, 0]))
Oberschrank.erstellen({ 'Breite' => 40.0 })
dateien, = S::Export.erzeugen(model)
d = dateien.to_h { |x| [x.name, x] }
check(d['OS1_Boden']&.anzahl == 2 && d['OS1_SeiteL'].anzahl == 2, 'gleicher Schrank zweimal: eine Datei, Anzahl 2')
check(d['OS2_Boden'] && (d['OS2_Boden'].lage.dh - 362).abs < 1e-6, "zweiter Oberschrank eigene Dateien (Boden DH #{d['OS2_Boden']&.lage&.dh})")
z = bearbeitungen(d['OS1_SeiteR'].text, 1)
check(z.any? { |x| x.include?('#8518=7.5 ') } && z.any? { |x| x.include?('#8518=x-7.5 ') }, "Oberschrank Seite: Boden 7.5, Deckel x-7.5: #{z}")
check(d['OS1_Deckel'].lage.dh < d['OS1_Boden'].lage.dh, 'Deckel endet vor der Rückwand')

# Schritt 6, Oberschrank: Lochreihen wie Seite.tcn (55 … x-50, vorn 35), hinten 35 vor der Rückwandnut
lr = z.select { |x| x.include?('#8522=5 ') }
check(lr.size == 2 && lr.all? { |x| x.include?('fittingx.tmcr #6=1 #8508=0 #8509=0 #8510=55 #8511=x-50 #8512=32 #8513=-12') },
      "Oberschrank Seite: Lochreihen 55 … x-50, Raster 32: #{lr}")
check(lr.map { |x| x[/#8518=(\S+)/, 1] }.sort == %w[35 y-68], "Lochreihen 35 vorn, 68 hinten (25 Versatz + 8 Nut + 35): #{lr}")
nut = d['OS1_SeiteR'].text.split("\r\n").select { |x| x.start_with?('W#89', 'W#2201') }
check(nut.size == 2 && nut[0].include?('#3=-9 ') && nut[0].include?('#205=2200') && nut[0].include?('#2=369 ') && nut[0].include?('#1=8 '),
      "Seite: Nut 9 tief, Fräser 2200, 25 + 4 mm vor der Hinterkante, ab Unterkante Rückwand: #{nut}")
check(nut[1] == 'W#2201{ ::WTl  #8015=1 #1=695 #2=0 }W', "Seite: Nut bis 5 mm über die Oberkante: #{nut[1]}")
bnut = d['OS1_Boden'].text.split("\r\n").select { |x| x.start_with?('W#89', 'W#2201') }
check(bnut.size == 2 && bnut[0].include?('#1=-5 ') && bnut[1].include?('#1=572 '), "Boden: Nut durchgehend: #{bnut}")
check(d['OS1_Boden'].lage.flaeche1 == :zmax && !d['OS1_Boden'].text.include?('#8522=3 '), 'Oberschrank-Boden: Nut oben, keine Sockelfüße')
sd = bearbeitungen(d['OS1_Deckel'].text, 5) + bearbeitungen(d['OS1_Deckel'].text, 3)
check(sd == ['W#1001{ ::WT2 WS #8098=..\\custom\\mcr\\fittingx.tmcr #6=1 #8508=0 #8509=0 #8510=50 #8511=x-50 #8512=231 #8513=-15 #8517=0 #8518=9.5 #8520=1 #8521=1 #8522=3 #8525=0 }W'],
      "Deckel: 3 Schrauben Ø3 × 15 in die Hinterkante (50, Mitte, x-50): #{sd}")
rs = bearbeitungen(d['OS1_Rueckwand'].text, 1).drop(1)
check(rs.size == 1 && rs[0].include?('#8510=59 #8511=y-59 #8512=231 #8513=-9 ') && rs[0].include?('#8518=x-9.5 ') && rs[0].include?('#8522=4 '),
      "Rückwand: 3 Bohrungen Ø4 durch, auf Höhe Deckelmitte: #{rs}")

check(S::Export.dateiname('HS1 U1/Front') == 'HS1_U1_Front', 'Dateiname ohne Sonderzeichen')

# --- Hochschrank: Zwischenböden ---
model = Sketchup.active_model = Sketchup::Model.new
Hochschrank.erstellen({})
dateien, = S::Export.erzeugen(model)
z = bearbeitungen(dateien.find { |x| x.name == 'HS1_SeiteL' }.text, 1)
check(z.count { |x| x.include?('fittingy.tmcr') && x.include?('#8522=8 ') } == 4, "Hochschrank Seite: 4 Dübelreihen (Boden, 2 Zwischenböden, Deckel): #{z.size - 1}")
lr = z.select { |x| x.include?('#8522=5 ') }
check(lr.size == 4 && lr.map { |x| x[/#8510=(\S+) #8511=(\S+)/, 0] }.uniq.sort == ['#8510=738 #8511=x-831', '#8510=x-741 #8511=x-50'],
      "Hochschrank: Lochreihen nur in den Fächern ohne Schubladen: #{lr}")
# Schienen (LEGRABOX): 37/69/261/293 ab Vorderkante roh = 35/67/259/291 im Fräsmaß, Höhe = Kastenunterkante
sch = z.select { |x| x.include?('#1002=5 ') && x.include?('#3=-14 ') }
hoehen = sch.map { |x| x[/#1=(\S+)/, 1] }.tally
check(hoehen == { '35' => 4, '291' => 4, '515' => 4 }, "Hochschrank: Schienenbohrungen je Schublade (#{hoehen})")
# Tiefe 800: NL 650 -> 37, 69, 37+320, 37+416 (roh) = 35, 67, 355, 451 im Fräsmaß (DH 798: 451 = y-347)
check(sch.map { |x| x[/#2=(\S+)/, 1] }.uniq.sort == %w[347 y-35 y-355 y-67], "Schienenbohrungen in der Tiefe (NL 650): #{sch}")
nl = lambda do |tiefe|
  Sketchup.active_model = m = Sketchup::Model.new
  Hochschrank.erstellen({ 'Tiefe' => tiefe })
  w = S::Export.werkstuecke(m)
  S::Regeln.nennlaenge(w.find { |x| x.rolle == 'Seite' }, w)
end
check([nl.(80.0), nl.(56.0), nl.(55.2), nl.(35.5), nl.(30.0)] == [650, 550, 500, 350, nil],
      "Nennlänge aus der lichten Tiefe (NL + 3 <= LT): #{[nl.(80.0), nl.(56.0), nl.(55.2), nl.(35.5), nl.(30.0)]}")
Sketchup.active_model = model
check(z.any? { |x| x.include?('#1=291 #2=y-35 ') }, 'Schiene: alle vier Bohrungen, keine Lochreihe im Schubladenfach')
check(dateien.none? { |x| x.text.include?('W#89') } && !dateien.find { |x| x.name == 'HS1_Rueckwand' }.text.include?('#8522=4 '),
      'Hochschrank: Rückwand ohne Nut und ohne Deckelschrauben')
check(bearbeitungen(dateien.find { |x| x.name == 'HS1_Boden' }.text, 1).count { |x| x.include?('#8522=3 ') } == 8, 'Hochschrank: Sockelfüße')
# Frontbefestigung LEGRABOX: Ø3 × 5 hinten in der Front, 14 mm von der Innenseite der Seite (x = 30 im Fräsmaß),
# unterstes Loch 36 über Unterkante Kasten = 69 über Unterkante Front wie in SK_Vorderstueck_Frontbef.tcn
fb = ->(name) { bearbeitungen(dateien.find { |x| x.name == name }.text, 1).select { |x| x.include?('#1002=3 ') && x.include?('#3=-5 ') } }
u3 = fb.('HS1_U3_Front')
check(u3.size == 8 && u3.map { |x| x[/#1=(\S+)/, 1] }.tally == { '30' => 4, 'x-30' => 4 } &&
      u3.map { |x| x[/#2=(\S+)/, 1] }.uniq.sort == %w[101 69 y-30.3333 y-62.3333],
      "Frontbefestigung 0/32/96/128 ab 69 mm: #{u3}")
u1 = fb.('HS1_U1_Front')
check(u1.size == 6 && u1.map { |x| x[/#2=(\S+)/, 1] }.uniq.sort == %w[82.3333 y-113 y-49],
      "Frontbefestigung: nur Löcher bis Oberkante Kasten: #{u1}")
check(fb.('HS1_O_Tuer').empty?, 'Tür ohne Frontbefestigung')
# Kastenboden: Falz für die Zargen an beiden Enden der Breite, 38 und 20 breit, 8 tief (Schubkastenboden.tcn)
kb = bearbeitungen(dateien.find { |x| x.name == 'HS1_U1_KastenBoden' }.text, 1).select { |x| x.include?('rect.tmcr') }
check(kb.size == 4 && kb.all? { |x| x.include?('#8514=-8 ') } &&
      kb.map { |x| x[/#8021=(\S+)/, 1] }.tally == { '19' => 2, 'y-19' => 2 } &&
      kb.map { |x| x[/#8509=(\S+) #8510=(\S+)/, 0] }.uniq.sort == ['#8509=l #8510=20', '#8509=l+20 #8510=38'],
      "Kastenboden: Falz an beiden Zargen: #{kb}")
check(bearbeitungen(dateien.find { |x| x.name == 'HS1_U1_KastenRueckwand' }.text, 1).size == 1, 'Kastenrückwand ohne Bearbeitung')
%w[HS1_ZwischenbodenUnten HS1_ZwischenbodenOben HS1_Deckel].each do |n|
  x = dateien.find { |y| y.name == n }
  check(x && bearbeitungen(x.text, 3).size + bearbeitungen(x.text, 4).size + bearbeitungen(x.text, 5).size +
        bearbeitungen(x.text, 6).size == 2, "#{n}: zwei Dübelreihen an den Stirnseiten")
  check(duebel_stirn_ok?(x), "#{n}: Dübel 30 mm vom Rand, max. 160 mm Abstand: #{[4, 6].map { |s| bearbeitungen(x.text, s) }}")
end
# Seite: dieselben Reihen gegenüber Boden, Zwischenböden und Deckel
z = bearbeitungen(dateien.find { |x| x.name == 'HS1_SeiteL' }.text, 1).select { |r| r.include?('fittingy.tmcr') && r.include?('#8522=8 ') }
st = %w[HS1_Boden HS1_ZwischenbodenUnten HS1_ZwischenbodenOben HS1_Deckel].map do |n|
  [3, 4, 5, 6].flat_map { |s| bearbeitungen(dateien.find { |y| y.name == n }.text, s) }.first[/#8512=(\S+)/, 1]
end
check(z.size == 4 && z.all? { |r| r.include?('#8508=0 #8509=0 #8510=30 #8511=y-28 ') } &&
      z.map { |r| r[/#8512=(\S+)/, 1] }.sort == st.sort, "Hochschrank Seite: Dübel wie Boden/Deckel (#{st}): #{z}")

# --- Apothekerschrank: mehrere Kästen an einer Hochfront ---
model_ap = Sketchup.active_model = Sketchup::Model.new
Apothekerschrank.erstellen({})
dap, = S::Export.erzeugen(model_ap)
namen = dap.map(&:name)
check((1..5).all? { |j| namen.include?("AP1_A#{j}_KastenBoden") } && !namen.include?('AP1_A6_KastenBoden') &&
      namen.none? { |n| n.start_with?('AP1_B_') || n =~ /AP1_B\d/ }, "Apothekerschrank: 5 Kästen, versteckte Teile nicht exportiert: #{namen}")
z = bearbeitungen(dap.find { |x| x.name == 'AP1_SeiteL' }.text, 1)
check(z.count { |x| x.include?('fittingy.tmcr') && x.include?('#8522=8 ') } == 3, 'Apothekerschrank Seite: Dübel Boden, Mittelboden, Deckel')
check(z.none? { |x| x.include?('#8522=5 ') }, 'Apothekerschrank: keine Lochreihen (nur Auszüge)')
sch = z.select { |x| x.include?('#1002=5 ') && x.include?('#3=-14 ') }
hoehen = sch.map { |x| x[/#1=(\S+)/, 1] }.tally
# Kastenunterkanten 99/483/867/1251/1635 mm; die oberen zwei misst die TCN von oben (DL 2098: x-847 = 1251)
check(hoehen == { '99' => 4, '483' => 4, '867' => 4, 'x-847' => 4, 'x-463' => 4 }, "Apothekerschrank: Schienen je Kasten (#{hoehen})")
fb = bearbeitungen(dap.find { |x| x.name == 'AP1_A_Front' }.text, 1).select { |x| x.include?('#1002=3 ') && x.include?('#3=-5 ') }
# die Hochfront liegt mit der Höhe in x: 14 mm von der Seiteninnenseite = 30 im Fräsmaß in y,
# unterstes Loch je Kasten 36 über Kastenunterkante (99 + 36 - 2 Anleimer = 133)
check(fb.size == 40 && fb.map { |x| x[/#2=(\S+)/, 1] }.tally == { '30' => 20, 'y-30' => 20 } && fb.any? { |x| x.include?('#1=133 ') },
      "Apothekerschrank: Hochfront mit Frontbefestigung je Kasten (5 × 8): #{fb.size}")
Apothekerschrank.erstellen({ 'Anz_Fronten' => 2.0, 'Anz_Kaesten_A' => 2.0, 'Anz_Kaesten_B' => 3.0 })
dap, = S::Export.erzeugen(model_ap)
fb = ->(n) { bearbeitungen(dap.find { |x| x.name == n }.text, 1).count { |x| x.include?('#1002=3 ') && x.include?('#3=-5 ') } }
check(fb.('AP2_A_Front') == 16 && fb.('AP2_B_Front') == 24, "Apothekerschrank zwei Fronten: Befestigung je Front nur für ihre Kästen (#{fb.('AP2_A_Front')}/#{fb.('AP2_B_Front')})")
Sketchup.active_model = model

# --- Schreiben: TCN + Teileliste ---
Dir.mktmpdir do |dir|
  S::Export.schreiben(dir, dateien)
  check(dateien.all? { |x| File.exist?(File.join(dir, "#{x.name}.tcn")) }, 'alle TCN geschrieben')
  csv = File.binread(File.join(dir, 'Teileliste.csv'))
  zeilen = csv.split("\r\n")
  check(zeilen.first == 'Datei;Anzahl;Schrank;Teil;Rolle;Material;DL;DH;DS' && zeilen.size == dateien.size + 1, 'Teileliste: Kopf und eine Zeile je Datei')
  check(zeilen.include?('HS1_Boden.tcn;1;HS1;Boden;Boden;Melamin weiss;798;562;19'), "Teileliste Boden: #{zeilen.grep(/HS1_Boden/)}")
end

# --- gleicher Tag: gleiche TCN wird gezählt, andere TCN bekommt _2 ---
a, b = %w[HS1_ZwischenbodenUnten HS1_ZwischenbodenOben].map { |n| dateien.find { |x| x.name == n } }
alt = b.ws.teil.inst.layer
b.ws.teil.inst.layer = a.ws.teil.inst.layer
check(S::Export.erzeugen(model)[0].find { |x| x.name == 'HS1_ZwischenbodenUnten' }.anzahl == 2, 'gleicher Tag, gleiche TCN: Anzahl 2')
b.ws.teil.inst.layer = alt
a, b = %w[HS1_SeiteL HS1_Boden].map { |n| dateien.find { |x| x.name == n } }
alt = b.ws.teil.inst.layer
b.ws.teil.inst.layer = a.ws.teil.inst.layer
dateien3, = S::Export.erzeugen(model)
check(dateien3.any? { |x| x.name == "#{S::Export.dateiname(a.name)}_2" }, 'gleicher Tag, andere TCN: Endung _2')
b.ws.teil.inst.layer = alt

# --- Hochschrank Geräte: drei Zwischenböden, keine Lochreihen in den Nischen, Platzhalter nicht exportiert ---
hm = Sketchup.active_model = Sketchup::Model.new
HochschrankGeraete.erstellen({})
dh, = S::Export.erzeugen(hm)
check(dh.all? { |x| x.name.start_with?('HG1_') }, "Hochschrank Geräte: nur Schrankteile, kein Platzhalter: #{dh.map(&:name)}")
zh = bearbeitungen(dh.find { |x| x.name == 'HG1_SeiteL' }.text, 1)
check(zh.count { |x| x.include?('fittingy.tmcr') && x.include?('#8522=8 ') } == 5,
      'Hochschrank Geräte Seite: 5 Dübelreihen (Boden, 3 Zwischenböden, Deckel)')
lrh = zh.select { |x| x.include?('#8522=5 ') }
check(lrh.size == 2 && lrh.all? { |x| x.include?('#8510=x-282 #8511=x-50') }, "Hochschrank Geräte: Lochreihen nur im oberen Fach: #{lrh}")
%w[HG1_ZwischenbodenUnten HG1_ZwischenbodenMitte HG1_ZwischenbodenOben].each do |n|
  x = dh.find { |y| y.name == n }
  check(x && (3..6).sum { |s| bearbeitungen(x.text, s).size } == 2, "#{n}: zwei Dübelreihen an den Stirnseiten")
end
check(bearbeitungen(dh.find { |x| x.name == 'HG1_Boden' }.text, 1).count { |x| x.include?('#8522=3 ') } == 8,
      'Hochschrank Geräte: Sockelfüße')
check(S::Frontfarbe.fronten(hm, kategorie: 'Hochschrank').count(&:sichtbar?) == 4, 'Hochschrank Geräte: Frontfarbe findet 3 Schubladen + Tür')
hm = Sketchup.active_model = Sketchup::Model.new
HochschrankGeraete.erstellen({ 'Geraet_N2' => 5.0 })
dh, = S::Export.erzeugen(hm)
check(dh.none? { |x| x.name == 'HG1_ZwischenbodenMitte' }, 'nur ein Gerät: kein Zwischenboden Mitte')
zh = bearbeitungen(dh.find { |x| x.name == 'HG1_SeiteL' }.text, 1)
check(zh.count { |x| x.include?('fittingy.tmcr') && x.include?('#8522=8 ') } == 4, 'nur ein Gerät: 4 Dübelreihen')
# --- Spülenschrank: Rückwand-Ausschnitt, Installationsebene (Rückwand in der Seitennut, auf dem Boden) ---
sm = Sketchup.active_model = Sketchup::Model.new
Spuelenschrank.erstellen({})
ds, ms = S::Export.erzeugen(sm)
check(ms.empty?, "Spülenschrank: keine Meldungen #{ms}")
dsp = ds.to_h { |x| [x.name, x] }
check(dsp.keys.sort == %w[USP1_A_Front USP1_A_KastenBoden USP1_A_KastenRueckwand USP1_B_Front USP1_Boden USP1_Rueckwand
                          USP1_SeiteL USP1_SeiteR USP1_StrebeHinten USP1_StrebeVorn], "Spülenschrank: Dateien #{dsp.keys}")
rw = dsp['USP1_Rueckwand']
check([rw.lage.dl, rw.lage.dh].zip([780, 681]).all? { |a, b| (a - b).abs < 1e-6 }, "Rückwand Spüle: 780 x 681 (#{rw.lage.dl} x #{rw.lage.dh})")
kontur = bearbeitungen(rw.text, 1).drop(1)
# Ausschnitt 662 x 400 ab 250 über Korpus-Unterkante = 231 über Unterkante Rückwand, 59 vom Rand; Fräser Ø8,03 innen
check(kontur.size == 5 && kontur[0].include?('#1=63.015 #2=235.015 #3=-9 ') && kontur[0].include?('#205=2200') &&
      kontur.drop(1) == ['W#2201{ ::WTl  #8015=1 #1=653.97 #2=0 }W', 'W#2201{ ::WTl  #8015=1 #1=0 #2=391.97 }W',
                         'W#2201{ ::WTl  #8015=1 #1=-653.97 #2=0 }W', 'W#2201{ ::WTl  #8015=1 #1=0 #2=-391.97 }W'],
      "Rückwand Spüle: Ausschnitt als geschlossene Kontur, 9 tief: #{kontur}")
z = bearbeitungen(dsp['USP1_SeiteR'].text, 1)
nut = z.select { |x| x.start_with?('W#89', 'W#2201') }
check(nut.size == 2 && nut[0].include?('#1=54 #2=19 #3=-9 ') && nut[1].include?('#1=0 #2=686 '),
      "Seite Spüle: Nut 50 + 4 mm vor der Hinterkante, ab Oberkante Boden bis über die Oberkante: #{nut}")
check(z.none? { |x| x.include?('#8522=5 ') && x.include?('fittingy') }, 'Seite Spüle mit Auszug: keine Lochreihe')
check(z.count { |x| x.include?('#1002=5 ') && x.include?('#3=-14 ') } == 4, 'Seite Spüle: Schienenbohrungen für den Auszug')
bd = dsp['USP1_Boden'].text
check(!bd.include?('W#89') && bd.include?('#8522=3 '), 'Boden Spüle: keine Nut, Sockelfüße')
check(bearbeitungen(dsp['USP1_B_Front'].text, 1).size == 1, 'Blende: nur Formatieren, keine Frontbefestigung')
check(bearbeitungen(dsp['USP1_A_Front'].text, 1).count { |x| x.include?('#1002=3 ') } == 8, 'Auszugfront: Frontbefestigung')
ff = S::Frontfarbe.fronten(sm, kategorie: 'Unterschrank')
check(ff.size == 5 && ff.count(&:sichtbar?) == 2, 'Spüle: Frontfarbe findet alle Fronten, sichtbar Blende und Auszugfront')
# Türen: Lochreihen im Fach, hinten 35 vor der Nut; ohne Ausschnitt keine Kontur
sm = Sketchup.active_model = Sketchup::Model.new
Spuelenschrank.erstellen({ 'Frontvariante' => 0.0, 'Ausschnitt_Hoehe' => 0.0 })
ds, = S::Export.erzeugen(sm)
dsp = ds.to_h { |x| [x.name, x] }
check(dsp.key?('USP1_TuerL') && dsp.key?('USP1_TuerR') && !dsp.key?('USP1_A_Front'), "Spüle mit Türen: #{dsp.keys}")
check(bearbeitungen(dsp['USP1_Rueckwand'].text, 1).size == 1, 'Rückwand ohne Ausschnitt: nur Formatieren')
lr = bearbeitungen(dsp['USP1_SeiteR'].text, 1).select { |x| x.include?('#8522=5 ') }
check(lr.size == 2 && lr.map { |x| x[/#8518=(\S+)/, 1] }.sort == %w[93 x-35], "Spüle mit Türen: Lochreihen 35 vorn, 93 hinten (50 + 8 Nut + 35): #{lr}")
# --- Geschirrspüler: Front und Wangen nur formatieren, Gerät wird nicht exportiert ---
gm = Sketchup.active_model = Sketchup::Model.new
usg = UnterschrankGeschirrspueler.erstellen({ 'Art_Wange' => 3.0 })
dg, = S::Export.erzeugen(gm)
check(dg.map(&:name).sort == %w[USG1_Front USG1_WangeL USG1_WangeR], "Geschirrspüler: Dateien #{dg.map(&:name)}")
dg.each do |x|
  z = bearbeitungen(x.text, 1)
  check(z.size == 1 && z.first.include?('squad.tmcr'), "Geschirrspüler #{x.name}: nur Formatieren #{z}")
  check([3, 4, 5, 6].all? { |s| bearbeitungen(x.text, s).empty? }, "Geschirrspüler #{x.name}: keine Stirnbohrungen")
end
fr = dg.find { |x| x.name == 'USG1_Front' }
check(fr && [fr.lage.dl, fr.lage.dh].sort.zip([594, 696]).all? { |a, b| (a - b).abs < 1e-6 }, "Geschirrspüler Front Fräsmaß: #{fr && [fr.lage.dl, fr.lage.dh, fr.lage.ds]}")
check(S::Frontfarbe.fronten(gm, kategorie: 'Unterschrank').size == 1, 'Geschirrspüler: Frontfarbe findet die Front')
Sketchup.active_model = model

# --- Dialog ---
module UI
  class << self
    attr_accessor :ordner, :meldung
    def select_directory(**) = ordner
    def messagebox(m, *) = (self.meldung = m)
  end
end
Dir.mktmpdir do |dir|
  UI.ordner = dir
  S::Export.dialog(model)
  check(UI.meldung.to_s.start_with?("#{dateien.size} TCN-Dateien"), "Dialog-Meldung: #{UI.meldung}")
  check(File.exist?(File.join(dir, 'HS1_SeiteL.tcn')), 'Dialog schreibt in den Ordner')
end
UI.ordner = nil
UI.meldung = nil
S::Export.dialog(model)
check(UI.meldung.nil?, 'Abbrechen bei der Ordnerwahl schreibt nichts')
S::Export.dialog(Sketchup::Model.new)
check(UI.meldung.to_s.start_with?('Keine Schrankteile'), 'leeres Modell: Hinweis')

# --- Unterschrank Kochfeld mit Abzug: Kanalausschnitt, Schienen-NL aus dem Attribut, Strebe hochkant, Blende ---
km = Sketchup.active_model = Sketchup::Model.new
UnterschrankKochfeld.erstellen({})
dk, mk_ = S::Export.erzeugen(km)
k = dk.to_h { |x| [x.name, x] }
check(k.keys.none? { |n| n.include?('StrebeHinten') } && k['USK1_Blende'] && k['USK1_StrebeVorn'], "Kochfeld: Dateien #{k.keys}")
check(mk_.none? { |m| m.include?('Unterseite') || m.include?('Fläche 1') }, "Kochfeld: Meldungen #{mk_}")
kb = k['USK1_Boden']
ta = bearbeitungen(kb.text, 1).select { |x| x.include?('rect.tmcr') }
check(kb.lage.flaeche1 == :zmin && ta.size == 1 && ta[0].include?('#8514=-20 ') &&
      [ta[0][/#8509=(\S+)/, 1], ta[0][/#8510=(\S+)/, 1]].sort == %w[110 300],
      "Kochfeld-Boden: Kanalausschnitt 300 × 110 durch (19 + 1 mm) von unten: #{ta}")
check(ta[0].include?('#8021=381 ') || ta[0].include?('#8020=381 '), "Kochfeld-Boden: Ausschnitt mittig (381 von 762): #{ta}")
mitte_t = ta[0][/#8020=(\S+)/, 1]
check(kb.lage.dl == 798 && mitte_t == 'x-75', "Kochfeld-Boden: Ausschnitt 20 mm vor der Hinterkante (Mitte 75 roh): #{ta}")
check(bearbeitungen(kb.text, 1).count { |x| x.include?('#8522=3 ') } == 8, 'Kochfeld-Boden: Sockelfüße bleiben')
# Schienen: NL 600 aus dem Attribut (Tiefe 800 − Installationstiefe 150), nicht 650 aus dem Abstand zur Rückwand;
# DL der Seite = Tiefe 798, also #1 = Lage in der Tiefe, #2 = Höhe
sr = bearbeitungen(k['USK1_SeiteR'].text, 1).select { |x| x.include?('#1002=5 ') && x.include?('#3=-14 ') }
xs = sr.map { |x| v = x[/#1=(\S+)/, 1]; v.start_with?('x-') ? v[2..].to_f : 798 - v.to_f }.uniq.sort
check(k['USK1_SeiteR'].lage.dl == 798 && xs == [35.0, 67.0, 291.0, 355.0], "Kochfeld: Schienen NL 600 (37/69/293/357 roh): #{xs}")
check(sr.map { |x| x[/#2=(\S+)/, 1] }.uniq.size == 2, "Kochfeld: Schienen für 2 Schubladen: #{sr}")
check(S::Regeln.nennlaenge_schrank(km.definitions['Unterschrank Kochfeld mit Abzug']) == 600, 'NL-Attribut 60 cm = 600')
# Strebe vorn hochkant: Dübel in die Stirnseiten, Schraube in die Seite
sv = k['USK1_StrebeVorn']
check(sv.lage.dh == 100 && [4, 6].all? { |s2| bearbeitungen(sv.text, s2).size == 1 }, "Strebe vorn hochkant: Dübel beidseitig (#{sv.lage.to_a.drop(1)})")
check(bearbeitungen(k['USK1_SeiteR'].text, 1).count { |x| x.include?('#1002=3 ') && x.include?('#3=-21 ') } == 1, 'Seite: Schraube in die hochkante Strebe')
# Blende: nur formatieren; Fronten der Schubladen mit LEGRABOX-Frontbefestigung
check(bearbeitungen(k['USK1_Blende'].text, 1).size == 1, "Blende ohne Bearbeitung: #{bearbeitungen(k['USK1_Blende'].text, 1)}")
check(bearbeitungen(k['USK1_S1_Front'].text, 1).count { |x| x.include?('#1002=3 ') && x.include?('#3=-5 ') } >= 4, 'Schubladenfront: Frontbefestigung')
# Kanal links: Ausschnitt 100 mm von der linken Seite (Mitte 250)
Sketchup.active_model = km2 = Sketchup::Model.new
UnterschrankKochfeld.erstellen({ 'Kanal_Lage' => 0.0 })
tl = bearbeitungen(S::Export.erzeugen(km2)[0].find { |x| x.name == 'USK1_Boden' }.text, 1).find { |x| x.include?('rect.tmcr') }
check(tl && (tl.include?('=250 ') || tl.include?('=512 ') || tl.include?('-250 ')), "Kochfeld-Boden: Ausschnitt links (Mitte 250 von links): #{tl}")
# Frontfarbe mit Griff: Blende bekommt Material, aber keinen Griff
Sketchup.active_model = km
fr = S::Frontfarbe.fronten(km)
check(fr.any? { |t| t.jt('teil') == 'Blende' }, 'Frontfarbe: Blende zählt als Front')
S::Frontfarbe.anwenden(km, fr, nil, griff: { lochmass: 160, lage: 'Mitte', hoehe: 35 })
bl = S::Schraenke.teile(km).select(&:front?)
check(bl.find { |t| t.jt('teil') == 'Blende' }.jt('griff_lochmass').nil? &&
      bl.select { |t| t.jt('teil') == 'Front' }.all? { |t| t.jt('griff_lochmass') == 160.0 }, 'Frontfarbe: Griff an den Schubladen, nicht an der Blende')

# --- Schmaler Unterschrank mit Häfele HU Slim Base: Schienen an einer Seite, Front, keine Lochreihen ---
# Wert einer Lage im Fräsmaß ab der Nullkante: "x-45" -> max - 45
def lage_mm(v, max) = v.start_with?('x-', 'y-') ? max - v[2..].to_f : v.to_f
hm = Sketchup.active_model = Sketchup::Model.new
UnterschrankHandtuch.erstellen({})
dh, mh = S::Export.erzeugen(hm)
h = dh.to_h { |x| [x.name, x] }
check(mh.empty?, "Handtuch: keine Meldungen bei Standardmaßen: #{mh}")
check(h.keys.sort == %w[USH1_Boden USH1_Front USH1_Rueckwand USH1_SeiteL USH1_SeiteR USH1_StrebeHinten USH1_StrebeVorn],
      "Handtuch: Dateien ohne Beschlag-Platzhalter: #{h.keys}")
schiene = ->(t) { bearbeitungen(t, 1).select { |x| x.include?('#1002=3 ') && x.include?('#3=-10 ') } }
sl = h['USH1_SeiteL']
pos = schiene.(sl.text).map { |x| [lage_mm(x[/#1=(\S+)/, 1], sl.lage.dl), lage_mm(x[/#2=(\S+)/, 1], sl.lage.dh)] }.sort
# Seite 700 hoch, 800 tief (Fräsmaß DL 798 ab Vorderkante, Anleimer vorn 2 mm): 56/280/330 roh, 19 + 52 / 19 + 436 hoch
check(pos == [54, 278, 328].product([71.0, 455.0]).sort, "Handtuch: Schienenbohrungen links (LH): #{pos}")
check(schiene.(h['USH1_SeiteR'].text).empty?, 'Handtuch: rechte Seite ohne Schiene')
check(dh.none? { |x| x.text.include?('#8522=5 ') }, 'Handtuch: keine Lochreihen')
fr = h['USH1_Front']
fpos = bearbeitungen(fr.text, 1).select { |x| x.include?('#3=-5 ') }.map do |x|
  [lage_mm(x[/#1=(\S+)/, 1], fr.lage.dl), lage_mm(x[/#2=(\S+)/, 1], fr.lage.dh)]
end.sort
# Front 148 × 700, rundum Anleimer (Fräsmaß 144 × 696): X = 84 (M150) mittig, 103 / 487 über Oberkante Boden
check(fr.lage.dh == 144 && fpos == [120.0, 504.0].product([30.0, 114.0]).sort, "Handtuch: Frontbohrungen M150: #{fpos}")
fu = bearbeitungen(h['USH1_Boden'].text, 1).select { |x| x.include?('#8522=3 ') }
check(fu.size == 4 && fu.map { |x| x[/#8518=(\S+)/, 1] }.uniq.sort == %w[24 y-24], "Handtuch: schmaler Boden, ein Sockelfuß je Ende mittig: #{fu}")
check(S::Frontfarbe.fronten(hm).map { |t| t.jt('teil') } == ['Front'], 'Handtuch: Frontfarbe findet die Front')

hm2 = Sketchup.active_model = Sketchup::Model.new
UnterschrankHandtuch.erstellen({ 'Modell' => 200.0, 'Seite_Beschlag' => 1.0, 'Hoehe' => 55.0, 'Tiefe' => 45.0 })
dh2, mh2 = S::Export.erzeugen(hm2)
h2 = dh2.to_h { |x| [x.name, x] }
check(schiene.(h2['USH1_SeiteL'].text).empty? && schiene.(h2['USH1_SeiteR'].text).size == 6, 'Handtuch: Schienen rechts (RH)')
fr2 = h2['USH1_Front']
w2 = bearbeitungen(fr2.text, 1).select { |x| x.include?('#3=-5 ') }.map { |x| lage_mm(x[/#2=(\S+)/, 1], fr2.lage.dh) }.uniq.sort
check(w2 == [30.0, 164.0], "Handtuch: Frontbohrungen M200 X = 134: #{w2}")
check(mh2.any? { |m| m.include?('lichte Höhe 512') } && mh2.any? { |m| m.include?('Tiefe 450') }, "Handtuch: zu kleiner Einbauraum gemeldet: #{mh2}")

# --- Eckschrank Blindeck: Blende ohne Bearbeitung, Lochreihen; Le Mans: Profil und Säulenlager ---
lage_xy = ->(d, z) { [lage_mm(z[/#1=(\S+)/, 1], d.lage.dl), lage_mm(z[/#2=(\S+)/, 1], d.lage.dh)] }
em = Sketchup.active_model = Sketchup::Model.new
Eckschrank.erstellen({})
de, me = S::Export.erzeugen(em)
e = de.to_h { |x| [x.name, x] }
check(me.empty?, "Eckschrank: keine Meldungen: #{me}")
check(e.keys.sort == %w[UES1_Blende UES1_Boden UES1_Einlegeboden1 UES1_Rueckwand UES1_SeiteL UES1_SeiteR UES1_StrebeHinten UES1_StrebeVorn UES1_Tuer],
      "Eckschrank: Dateien ohne Le-Mans-Platzhalter und ausgeblendete Teile: #{e.keys}")
check(bearbeitungen(e['UES1_Blende'].text, 1).size == 1, 'Eckschrank: Blende nur formatieren')
check(%w[UES1_SeiteL UES1_SeiteR].all? { |n| e[n].text.include?('#8522=5 ') && !e[n].text.include?('#3=-13 ') },
      'Eckschrank: Lochreihen in beiden Seiten, keine Le-Mans-Bohrungen')
fr_e = S::Frontfarbe.fronten(em).select(&:sichtbar?)
check(fr_e.map { |t| t.jt('teil') }.sort == %w[Blende Tuer], "Eckschrank: Frontfarbe findet Blende und Tür: #{fr_e.map { |t| t.jt('teil') }}")
S::Frontfarbe.anwenden(em, fr_e, nil, griff: { lochmass: 160, lage: 'Mitte', hoehe: 35 })
fe = S::Schraenke.teile(em).select { |t| t.front? && t.sichtbar? }.to_h { |t| [t.jt('teil'), t.jt('griff_lochmass')] }
check(fe == { 'Blende' => nil, 'Tuer' => 160.0 }, "Eckschrank: Griff an der Tür, nicht an der Blende: #{fe}")

[[0.0, 'SeiteR', 'SeiteL'], [1.0, 'SeiteL', 'SeiteR']].each do |blind, tuerseite, blindseite|
  lm = Sketchup.active_model = Sketchup::Model.new
  Eckschrank.erstellen({ 'Variante' => 2.0, 'Blindseite' => blind })
  dl, ml = S::Export.erzeugen(lm)
  l = dl.to_h { |x| [x.name, x] }
  tx = "Le Mans Blindseite #{blind.to_i}"
  check(ml.empty?, "#{tx}: keine Meldungen bei 1000 mm und LeMans 50: #{ml}")
  check(!l.key?('UES1_Einlegeboden1') && dl.none? { |x| x.text.include?('#8522=5 ') && x.text.include?('fitting') && x.text.include?('#8512=32 ') },
        "#{tx}: keine Einlegeböden, keine Lochreihen")
  s = l["UES1_#{tuerseite}"]
  pr = bearbeitungen(s.text, 1).select { |x| x.include?('#1002=5 ') && x.include?('#3=-13 ') }.map { |x| lage_xy.(s, x) }
  # Seite 700 hoch (DL), Profil 52 mm ab Vorderkante (Fräsmaß 50), unterstes Loch 19 + 28 mm über Unterkante, Raster 64
  hoehen = pr.map(&:first).sort
  check(pr.size == 8 && hoehen == (0..7).map { |i| 47.0 + 64 * i } && pr.map(&:last).uniq.size == 1 &&
        [50.0, s.lage.dh - 50].include?(pr.first.last), "#{tx}: Profil 500 an der Türseite: #{pr}")
  check(!l["UES1_#{blindseite}"].text.include?('#3=-13 '), "#{tx}: Blindseite ohne Profil")
  # Säulenlager: X = 526 ab Innenseite der Türseite (Boden 962 lang: 981 - 526 - 19 = 436 ab links), 69/37 ab Vorderkante
  x_soll = blind.zero? ? 436.0 : 962.0 - 436.0
  bo = l['UES1_Boden']
  lb = bearbeitungen(bo.text, 1).select { |x| x.include?('#3=-20 ') }.map { |x| [lage_xy.(bo, x), x[/#1002=(\S+)/, 1]] }
  check(lb.size == 3 && lb.map { |(p, _)| p[0] }.sort == [x_soll - 16, x_soll, x_soll + 16] &&
        lb.find { |_, d| d == '5' }[0][1].then { |y| [67.0, bo.lage.dh - 67].include?(y) },
        "#{tx}: Säulenlager im Boden (durchgebohrt von unten): #{lb}")
  sv = l['UES1_StrebeVorn']
  ls = bearbeitungen(sv.text, 1).select { |x| x.include?('W#81') }.map { |x| [lage_xy.(sv, x), x[/#3=(\S+)/, 1]] }
  check(ls.size == 3 && ls.map { |(p, _)| p[0] }.sort == [x_soll - 16, x_soll, x_soll + 16] && ls.map(&:last).sort == %w[-10 -10 -13],
        "#{tx}: Säulenlager unter der Strebe vorn: #{ls}")
end
lm2 = Sketchup.active_model = Sketchup::Model.new
Eckschrank.erstellen({ 'Variante' => 2.0, 'LeMans' => 60.0, 'Breite' => 90.0, 'Tiefe' => 48.0 })
_, ml2 = S::Export.erzeugen(lm2)
check(ml2.any? { |m| m.include?('Korpusbreite für LeMans 60 900') } && ml2.any? { |m| m.include?('Tiefe 480') },
      "Le Mans: zu kleiner Korpus gemeldet: #{ml2}")

# --- Eckschrank L-Form: Innenecke ausfräsen, Sockelfüße je Schenkel, Streben in der Ecke ---
lf = Sketchup.active_model = Sketchup::Model.new
Eckschrank.erstellen({}, l_form: true)
dlf, mlf = S::Export.erzeugen(lf)
f = dlf.to_h { |x| [x.name, x] }
check(mlf.empty?, "L-Form: keine Meldungen: #{mlf}")
bo = f['UES1_Boden']
check(bo.lage.dl == 873 && bo.lage.dh == 873 && bo.lage.flaeche1 == :zmin, "L-Boden: Rechteck 873 x 873, Fläche 1 unten: #{bo.lage.to_a.drop(1)}")
kont = bearbeitungen(bo.text, 1).drop_while { |x| !x.include?('W#89') }
# Ecke vom Rand bis 2 mm hinter die Korpusvorderkante (Anleimer), 8 mm über die Platte hinaus: 323 x 323,
# Kontur um den Fräserradius nach innen versetzt
check(kont.size == 5 && kont[0].include?('#1=562.015 #2=562.015 #3=-20 ') && kont[1].include?('#1=315 #2=0 ') &&
      kont[2].include?('#1=0 #2=315 '), "L-Boden: Innenecke ausgefräst: #{kont}")
fuss = bearbeitungen(bo.text, 1).select { |x| x.include?('#8522=3 ') }.map { |x| [x[/#8510=(\S+)/, 1], x[/#8518=(\S+)/, 1]] }
# Füße nur außerhalb der Ecke (lage_mm: x 0…873, die Ecke liegt bei x > 558 und y > 558)
lage = ->(v) { lage_mm(v, 873) }
check(fuss.size == 16 && fuss.none? { |x, y| lage.(x) > 558 && lage.(y) > 558 }, "L-Boden: 16 Sockelfuß-Reihen außerhalb der Ecke: #{fuss}")
check(fuss.any? { |x, y| lage.(x).between?(470, 558) && lage.(y).between?(558, 700) }, "L-Boden: Fuß an der Innenecke: #{fuss}")
eb = f['UES1_Einlegeboden1']
check(bearbeitungen(eb.text, 1).any? { |x| x.include?('W#89') && x.include?('#1=552.015 ') }, 'L-Einlegeboden: Ecke 10 mm weiter zurück')
check(%w[SeiteL SeiteR].all? { |n| f["UES1_#{n}"].text.include?('#8522=5 ') }, 'L-Form: Lochreihen in beiden Seiten')
# Strebe B stößt mit dem Ende an die Kante von Strebe A: Dübel in beiden (A in der Kante, 22 tief)
%w[StrebeVorn StrebeHinten].each do |sn|
  a = f["UES1_#{sn}1"]
  b = f["UES1_#{sn}2"]
  kante = [3, 5].flat_map { |sd| bearbeitungen(a.text, sd) }.select { |x| x.include?('#8522=8 ') && x.include?('#8513=-22 ') }
  ende = [4, 6].map { |sd| bearbeitungen(b.text, sd).count { |x| x.include?('#8522=8 ') } }
  check(kante.size == 1 && ende == [1, 1], "L-Form: #{sn} in der Ecke verdübelt (#{kante.size}, #{ende})")
end
check(S::Frontfarbe.fronten(lf).select(&:sichtbar?).map { |t| t.jt('teil') }.sort == %w[TuerL TuerR], 'L-Form: Frontfarbe findet beide Türen')

if $fehler.zero?
  puts 'test_export: alles OK'
else
  puts "test_export: #{$fehler} Fehler"
  exit 1
end
