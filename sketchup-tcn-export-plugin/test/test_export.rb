# Test ohne SketchUp: TCN-Export des Korpus (Schritte 5 bis 7) an echten Schränken aus
# Komponenten/ (mit der Mock-API erzeugt), verglichen mit Jürgens Beispiel-TCN.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
require 'pdf_helfer'
require 'tmpdir'
komp = File.expand_path('../../Komponenten', __dir__)
load File.join(komp, 'hochschrank/src/hochschrank/main.rb')
load File.join(komp, 'oberschrank/src/oberschrank/main.rb')
load File.join(komp, 'oberschrank_klappe/src/oberschrank_klappe/main.rb')
load File.join(komp, 'oberschrank_dunstabzug/src/oberschrank_dunstabzug/main.rb')
load File.join(komp, 'apothekerschrank/src/apothekerschrank/main.rb')
load File.join(komp, 'hochschrank_geraete/src/hochschrank_geraete/main.rb')
load File.join(komp, 'unterschrank_schubladen/src/unterschrank_schubladen/main.rb')
load File.join(komp, 'unterschrank_spuele/src/unterschrank_spuele/main.rb')
load File.join(komp, 'unterschrank_doppeltuer/src/unterschrank_doppeltuer/main.rb')
load File.join(komp, 'unterschrank_kochfeld/src/unterschrank_kochfeld/main.rb')
load File.join(komp, 'unterschrank_backofen/src/unterschrank_backofen/main.rb')
load File.join(komp, 'unterschrank_geschirrspueler/src/unterschrank_geschirrspueler/main.rb')
load File.join(komp, 'unterschrank_kuehlschrank/src/unterschrank_kuehlschrank/main.rb')
load File.join(komp, 'unterschrank_handtuch/src/unterschrank_handtuch/main.rb')
load File.join(komp, 'unterschrank_abfall/src/unterschrank_abfall/main.rb')
load File.join(komp, 'unterschrank_insel/src/unterschrank_insel/main.rb')
load File.join(komp, 'eckschrank/src/eckschrank/main.rb')
load File.join(komp, 'eck_oberschrank/src/eck_oberschrank/main.rb')
load File.join(komp, 'hochschrank_vorrat/src/hochschrank_vorrat/main.rb')
load File.join(komp, 'hochschrank_kuehlschrank/src/hochschrank_kuehlschrank/main.rb')
load File.join(komp, 'regal_abschluss/src/regal_abschluss/main.rb')
load File.expand_path('../src/jt_schrank_cnc/main.rb', __dir__)
# Blenden & Wangen bringt eine eigene (gleiche) Kopie der Küchen-Einstellungen mit
v, $VERBOSE = $VERBOSE, nil
load File.join(komp, 'blenden/src/blenden/main.rb')
$VERBOSE = v

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

# --- Strebe = Strebe.tcn: genau 2 Dübel 20 … x-20, ST 60, 0/0 (Jürgen 2026-10-28) ---
s60 = UnterschrankSchubladen.erstellen({ 'Breite' => 60.0, 'Tiefe' => 56.0 })
dateien2, = S::Export.erzeugen(model, auswahl: [s60])
strebe = dateien2.find { |x| x.name == 'USS2_StrebeHinten' }
check(strebe && kopf(strebe.text) == kopf(beispiel('Strebe.tcn')), "Kopf Strebe: #{strebe && kopf(strebe.text)}")
[4, 6].each do |s|
  soll = bearbeitungen(beispiel('Strebe.tcn'), s)
  check(bearbeitungen(strebe.text, s) == soll, "Strebe SIDE##{s}: #{bearbeitungen(strebe.text, s)}")
end
vorn = dateien2.find { |x| x.name == 'USS2_StrebeVorn' }
check((vorn.lage.dh - 98).abs < 1e-6 && bearbeitungen(vorn.text, 4).first.include?('#8508=0 #8509=0 #8510=18 #8511=x-20 #8512=60 '),
      "Strebe vorn: Fräsmaß 98, 2 Dübel 20 ab fertiger Kante (18 … x-20, ST 60): #{bearbeitungen(vorn.text, 4)}")
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
hinten = vorlage.select { |x| x.include?('y-80') || x.include?('#2=y-50') }.map { |x| x.gsub('x-7.5', 'x-9.5').sub('#8513=-12', '#8513=-14') }
hinten = hinten.map { |x| x.sub('#8510=y-20 #8511=y-80', '#8510=y-80 #8511=y-20') }
check(hinten.size == 2 && (hinten - z).empty?, "Seite: Strebe hinten wie Seite.tcn (x-9.5 statt x-7.5, kein Anleimer oben): #{z}")
check(z.any? { |x| x.include?('#8508=0 #8509=0 #8510=18 #8511=78 #8512=60') } && z.any? { |x| x.include?('#1=x-9.5 #2=48 #3=-21 #1002=3') },
      'Seite: Strebe vorn 2 Dübel 18 … 78 (20 ab fertiger Kante), Schraube in der Mitte der fertigen Strebe')
check(d['USS1_SeiteL'].text != seite.text && bearbeitungen(d['USS1_SeiteL'].text, 1).size == z.size, 'Seite links gespiegelt')
check(kopf(seite.text)[0].end_with?('s54') && kopf(boden.text)[0].end_with?('s13'), 'Feld s je Rolle wie in den Vorlagen')
# Schraubenreihe Ø3 × 12 an der Dübellinie des Bodens wie Seite.tcn (ST 130, verteilt 1/1, gleiche Enden wie die Dübel)
sr = vorlage.find { |x| x.include?('#8522=3 ') }.sub('#8518=7.5', '#8518=9.5').sub('#8510=30', '#8510=28')
check(z.include?(sr), "Seite: Schraubenreihe Ø3 am Boden wie Seite.tcn: #{z}")
# Seite tiefer als hoch (Tiefe 80 cm): trotzdem wie Seite.tcn x = Höhe, y = Tiefe (Jürgen 2026-11-01)
tief = UnterschrankSchubladen.erstellen({ 'Breite' => 60.0, 'Tiefe' => 80.0 })
dt, = S::Export.erzeugen(model, auswahl: [tief])
st = dt.find { |x| x.name =~ /SeiteR\z/ }
zt = bearbeitungen(st.text, 1)
check(st.lage.dl == 700 && st.lage.dh == 798, "tiefe Seite: DL = Höhe 700, DH = Tiefe 798: #{st.lage.dl} #{st.lage.dh}")
check(zt.count { |x| x.include?('#8522=5 ') } == 2 && zt.select { |x| x.include?('#8522=5 ') }.all? { |x| x.include?('fittingx') && x.include?('#8510=57 #8511=x-52') } &&
      zt.count { |x| x.include?('fittingy') && x.include?('#8518=9.5 ') } == 2 &&
      zt.count { |x| x.include?('#8518=x-9.5 ') && x.include?('#8522=8 ') } == 2,
      "tiefe Seite: Lochreihen in x, Boden- und Strebendübel in y wie Seite.tcn: #{zt}")

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
check(sd.empty?, "Deckel: Hinterkante nicht vorgebohrt (waagrecht gibt es nur Ø8): #{sd}")
rs = bearbeitungen(d['OS1_Rueckwand'].text, 1).drop(1)
check(rs.size == 1 && rs[0].include?('#8510=59 #8511=y-59 #8512=231 #8513=-9 ') && rs[0].include?('#8518=x-9.5 ') && rs[0].include?('#8522=5 '),
      "Rückwand: 3 Bohrungen Ø5 durch (Durchgangsbohrer), auf Höhe Deckelmitte: #{rs}")

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
# Schienen (LEGRABOX): 37/69/261/293/357/453 ab Vorderkante roh (NL 650, 70 kg) = 35/67/259/291/355/451 im Fräsmaß,
# Höhe = Kastenunterkante; unterste Schublade 38 über dem Boden (19 + 38 = 57), kein Lochraster
sch = z.select { |x| x.include?('#1002=5 ') && x.include?('#3=-14 ') }
hoehen = sch.map { |x| x[/#1=(\S+)/, 1] }.tally
check(hoehen == { '57' => 6, '263.3333' => 6, '496.6667' => 6 }, "Hochschrank: Schienenbohrungen je Schublade (#{hoehen})")
# Tiefe 800: NL 650 -> 37, 69, 37+224, 37+256, 37+320, 37+416 (roh) = 35, 67, 259, 291, 355, 451 im Fräsmaß (DH 798: 451 = y-347)
check(sch.map { |x| x[/#2=(\S+)/, 1] }.uniq.sort == %w[347 y-259 y-291 y-35 y-355 y-67], "Schienenbohrungen in der Tiefe (NL 650): #{sch}")
nl = lambda do |tiefe|
  Sketchup.active_model = m = Sketchup::Model.new
  Hochschrank.erstellen({ 'Tiefe' => tiefe })
  w = S::Export.werkstuecke(m)
  S::Regeln.nennlaenge(w.find { |x| x.rolle == 'Seite' }, w)
end
check([nl.(80.0), nl.(56.0), nl.(55.2), nl.(35.5), nl.(30.0)] == [650, 550, 500, 350, nil],
      "Nennlänge aus der lichten Tiefe (NL + 3 <= LT): #{[nl.(80.0), nl.(56.0), nl.(55.2), nl.(35.5), nl.(30.0)]}")
Sketchup.active_model = model
check(z.any? { |x| x.include?('#1=263.3333 #2=y-35 ') }, 'Schiene: alle vier Bohrungen, keine Lochreihe im Schubladenfach')
check(dateien.none? { |x| x.text.include?('W#89') } && !dateien.find { |x| x.name == 'HS1_Rueckwand' }.text.include?('fitting'),
      'Hochschrank: Rückwand ohne Nut und ohne Deckelschrauben')
check(bearbeitungen(dateien.find { |x| x.name == 'HS1_Boden' }.text, 1).count { |x| x.include?('#8522=3 ') } == 8, 'Hochschrank: Sockelfüße')
# Frontbefestigung LEGRABOX: Ø3 × 5 hinten in der Front, 14 mm von der Innenseite der Seite (x = 30 im Fräsmaß),
# unterstes Loch 36 über Unterkante Kasten; Zarge M (Fronten 231 mm, Kasten ab 57 bzw. 30 über der Front): Lochpaar 0/32
fb = ->(name) { bearbeitungen(dateien.find { |x| x.name == name }.text, 1).select { |x| x.include?('#1002=3 ') && x.include?('#3=-5 ') } }
u3 = fb.('HS1_U3_Front')
check(u3.size == 4 && u3.map { |x| x[/#1=(\S+)/, 1] }.tally == { '30' => 2, 'x-30' => 2 } &&
      u3.map { |x| x[/#2=(\S+)/, 1] }.uniq.sort == %w[91 y-104.3333],
      "Frontbefestigung Zarge M 0/32 ab 93 mm (unterste Schublade, Schiene 38 über Boden): #{u3}")
u1 = fb.('HS1_U1_Front')
check(u1.size == 4 && u1.map { |x| x[/#2=(\S+)/, 1] }.uniq.sort == %w[64 96],
      "Frontbefestigung Zarge M: #{u1}")
# Zarge F (hohe Front unten, 1;1;2 in 700): 4 Lochreihen 0/32/96/128 wie C ab 36 über Kastenunterkante (57 + 36 = 93)
mc = Sketchup.active_model = Sketchup::Model.new
UnterschrankSchubladen.erstellen({ 'Anz_Schubladen' => 3, 'Anteil_1' => 1.0, 'Anteil_2' => 1.0, 'Anteil_3' => 2.0 })
dc_, = S::Export.erzeugen(mc)
fc = bearbeitungen(dc_.find { |x| x.name == 'USS1_S3_Front' }.text, 1).select { |x| x.include?('#1002=3 ') && x.include?('#3=-5 ') }
dh3 = dc_.find { |x| x.name == 'USS1_S3_Front' }.lage.dh
zc = fc.map { |x| v = x[/#2=(\S+)/, 1]; v.start_with?('y-') ? dh3 - v[2..].to_f : v.to_f }.uniq.sort.map { |v| v.round(2) }
check(fc.size == 8 && zc == [91.0, 123.0, 187.0, 219.0], "Frontbefestigung Zarge F 0/32/96/128: #{zc}")
krc = dc_.find { |x| x.name == 'USS1_S3_KastenRueckwand' }
krm = dc_.find { |x| x.name == 'USS1_S1_KastenRueckwand' }
check(([krc.lage.dl, krc.lage.dh].min - 210).abs < 1e-6 && ([krm.lage.dl, krm.lage.dh].min - 60).abs < 1e-6, # Fräsmaß = 212 / 62 − 2 mm Anleimer oben
      "Kastenrückwand F 212 / M 62 (#{[krc.lage.dl, krc.lage.dh]} / #{[krm.lage.dl, krm.lage.dh]})")
Sketchup.active_model = model
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
# Kastenunterkanten 57/461/865/1269/1673 mm (ohne Lochraster); die oberen zwei misst die TCN von oben (DL 2098: x-829 = 1269)
check(hoehen == { '57' => 6, '461' => 6, '865' => 6, 'x-829' => 6, 'x-425' => 6 }, "Apothekerschrank: Schienen je Kasten (#{hoehen})")
fb = bearbeitungen(dap.find { |x| x.name == 'AP1_A_Front' }.text, 1).select { |x| x.include?('#1002=3 ') && x.include?('#3=-5 ') }
# die Hochfront liegt mit der Höhe in x: 14 mm von der Seiteninnenseite = 30 im Fräsmaß in y,
# unterstes Loch je Kasten 36 über Kastenunterkante (57 + 36 - 2 Anleimer = 91)
check(fb.size == 40 && fb.map { |x| x[/#2=(\S+)/, 1] }.tally == { '30' => 20, 'y-30' => 20 } && fb.any? { |x| x.include?('#1=91 ') },
      "Apothekerschrank: Hochfront mit Frontbefestigung je Kasten (5 × 8): #{fb.size}")
Apothekerschrank.erstellen({ 'Anz_Fronten' => 2.0, 'Anz_Kaesten_A' => 2.0, 'Anz_Kaesten_B' => 3.0 })
dap, = S::Export.erzeugen(model_ap)
fb = ->(n) { bearbeitungen(dap.find { |x| x.name == n }.text, 1).count { |x| x.include?('#1002=3 ') && x.include?('#3=-5 ') } }
check(fb.('AP2_A_Front') == 16 && fb.('AP2_B_Front') == 24, "Apothekerschrank zwei Fronten: Befestigung je Front nur für ihre Kästen (#{fb.('AP2_A_Front')}/#{fb.('AP2_B_Front')})")
# --- Hochschrank Vorrat: Innenschubkästen hinter der Tür, Schienen hinter der Innenfront ---
model_hv = Sketchup.active_model = Sketchup::Model.new
HochschrankVorrat.erstellen({ 'Tiefe' => 52.0 })
dhv, mhv = S::Export.erzeugen(model_hv)
check(mhv.empty?, "Hochschrank Vorrat: keine Meldungen #{mhv}")
hv = dhv.to_h { |x| [x.name, x] }
check((1..4).all? { |j| %w[Innenfront KastenBoden KastenRueckwand].all? { |t| hv["HV1_U#{j}_#{t}"] } } && hv['HV1_U_Tuer'] &&
      !hv['HV1_U5_Innenfront'] && !hv['HV1_O_Tuer'], "Hochschrank Vorrat: Dateien #{hv.keys.sort}")
z = bearbeitungen(hv['HV1_SeiteL'].text, 1)
sch = z.select { |x| x.include?('#1002=5 ') && x.include?('#3=-14 ') }
check(sch.size == 16, "Hochschrank Vorrat: 4 Schienenbohrungen je Kasten (#{sch.size})")
# Kasten 17 mm hinter der Korpusvorderkante (3 Rücksprung + 12 Innenfront + 2 Fuge): 37 + 17 - 2 Anleimer = 52
tiefen = sch.map { |x| x[/#2=(\S+)/, 1] }.uniq.sort
check(tiefen.include?('y-52') && tiefen.include?('y-84'), "Hochschrank Vorrat: Schienen ab Innenfront versetzt (#{tiefen})")
check(z.count { |x| x.include?('#8522=5 ') } == 2, 'Hochschrank Vorrat: Lochreihen nur im Fach oben')
fbi = bearbeitungen(hv['HV1_U1_Innenfront'].text, 1).count { |x| x.include?('#1002=3 ') && x.include?('#3=-5 ') }
check(fbi >= 4 && fbi.even?, "Hochschrank Vorrat: Frontbefestigung in der Innenfront (#{fbi})")
check(S::Frontfarbe.fronten(model_hv, kategorie: 'Hochschrank').count(&:sichtbar?) == 1, 'Hochschrank Vorrat: Frontfarbe Hochschränke nur die Tür')
inn = S::Frontfarbe.fronten(model_hv, kategorie: S::Frontfarbe::INNEN)
check(inn.count(&:sichtbar?) == 4, "Hochschrank Vorrat: Frontfarbe findet 4 Innenfronten (#{inn.count(&:sichtbar?)})")
fm = model_hv.materials.add('Front Eiche 12mm')
fm.set_attribute('ladb_opencutlist', 'type', 2)
S::Frontfarbe.anwenden(model_hv, inn, fm, griff: { lochmass: 160, lage: 'Mitte', hoehe: 35 })
neu = S::Frontfarbe.fronten(model_hv, kategorie: S::Frontfarbe::INNEN)
check(neu.all? { |f| f.inst.material == fm && !f.jt('griff_lochmass') }, 'Hochschrank Vorrat: Innenfronten umgefärbt, ohne Griff')
check(S::Frontfarbe.fronten(model_hv, kategorie: 'Hochschrank').none? { |f| f.inst.material == fm }, 'Hochschrank Vorrat: Tür bleibt')
Sketchup.active_model = model

# --- Schreiben: TCN + Fräsliste (keine eigene Teileliste mehr, alles steht in der Stückliste) ---
# Übermaß aus den allgemeinen Einstellungen (Länge 10, Breite 6 mm), nicht mehr aus OCL am Material
check(S::Einstellungen.uebermass_laenge == 10.0 && S::Einstellungen.uebermass_breite == 10.0, 'Einstellungen: Übermaß Standard 10/10 mm')
S::Einstellungen.setzen('uebermass_breite', 6)
platte = dateien.find { |x| x.name == 'HS1_Boden' }.ws.teil.inst.material
alt_li = platte.get_attribute('ladb_opencutlist', 'length_increase')
platte.set_attribute('ladb_opencutlist', 'length_increase', '40 mm')
Dir.mktmpdir do |dir|
  S::Export.schreiben(dir, dateien)
  check(dateien.all? { |x| File.exist?(File.join(dir, x.datei)) && x.datei == "#{x.nr}_#{x.name}.tcn" }, 'alle TCN geschrieben, Name = Nr_Tag.tcn')
  check(!File.exist?(File.join(dir, 'Teileliste.csv')), 'keine Teileliste.csv mehr (steht in der Stückliste)')
  # Nummer im Dateinamen = Nummer der Stückliste (Etiketten/Zuschnitt nutzen dieselbe)
  zs = S::Stueckliste.zeilen(dateien)
  check(zs.all? { |z| z.datei.start_with?("#{z.nr}_") } &&
        dateien.all? { |x| zs.any? { |z| z.nr == x.nr && z.datei == x.datei } },
        "Dateiname mit Stücklisten-Nummer: #{zs.first(3).map { |z| [z.nr, z.datei] }}")
  check(dateien.map(&:nr).uniq.size == dateien.size && dateien.map(&:nr).sort == (1..dateien.size).to_a, 'Nummern eindeutig 1..n')
  zb = zs.find { |z| z.tag == 'HS1_Boden' }
  check(zb && zb.datei == "#{zb.nr}_HS1_Boden.tcn" && zb.anzahl == 1 && zb.material == 'Melamin weiss' &&
        zb.fraes.map(&:round).sort == [562, 798] && zb.ds == 19, "Stückliste hat alles der alten Teileliste (Datei, Anzahl, Material, DL/DH, DS): #{zb.to_a.first(10)}")

  # Fräsliste .xmlst für das TpaCAD-Board
  liste = File.join(dir, S::Fraesliste.name(dir))
  check(File.exist?(liste) && liste.end_with?('.xmlst'), "Fräsliste geschrieben: #{liste}")
  x = File.binread(liste).force_encoding('UTF-8')
  check(x.start_with?("\uFEFF<?xml version=\"1.0\" encoding=\"utf-8\"?>\r\n<List>\r\n"), 'Fräsliste: BOM, XML-Kopf, CRLF')
  check(!x.gsub("\r\n", '').include?("\n"), 'Fräsliste: nur CRLF')
  rows = x.scan(/<Row Index="(\d+)".*?<\/Row>/m).size
  check(rows == dateien.size, "Fräsliste: eine Zeile je TCN (#{rows}/#{dateien.size})")
  namen = x.scan(/<Cell Name="NAME" DataType="161">"(.*?)"<\/Cell>/).flatten
  check(namen.all? { |n| n.start_with?(dir) } && namen.map { |n| File.basename(n) }.sort == dateien.map(&:datei).sort, 'Fräsliste: alle TCN mit Pfad')
  flaechen = x.scan(/"LENGTH" DataType="168">([\d.]+)<.*?"HEIGHT" DataType="169">([\d.]+)</m).map { |l, h| l.to_f * h.to_f }
  check(flaechen == flaechen.sort.reverse && flaechen.size == dateien.size, 'Fräsliste: größte Teile zuerst')
  boden = x[/<Row[^>]*HS1_Boden\.tcn.*?<\/Row>/m].to_s
  check(boden.include?('"REPETITIONS" DataType="164">1<') && boden.include?('"FIELD" DataType="171">9<'), 'Fräsliste Boden: Anzahl, Feld')
  check(boden.include?('"OFFSET X" DataType="277">5<') && boden.include?('"OFFSET Y" DataType="278">3<') &&
        boden.include?('"OFFSET Z" DataType="279">0<'), "Fräsliste Boden: Offset = halbes Übermaß aus den Einstellungen (10/6 mm, OCL-Wert am Material egal): #{boden[/OFFSET X.*?</m]}")
  check(boden.include?('"COMMENT" DataType="162">Boden<'), 'Fräsliste: OCL-Name als Kommentar')
  zb = x[/<Row[^>]*HS1_ZwischenbodenUnten\.tcn.*?<\/Row>/m].to_s
  check(zb.include?('"REPETITIONS" DataType="164">2<') || dateien.find { |d| d.name == 'HS1_ZwischenbodenUnten' }.anzahl == 1, 'Fräsliste: Wiederholungen = Anzahl')
end
platte.set_attribute('ladb_opencutlist', 'length_increase', alt_li)
S::Einstellungen.setzen('uebermass_breite', 10)

# Fräsliste: Windows-Pfade, Name, Maße aus OCL
check(S::Fraesliste.name('E:\\Auftrag\\Kueche Meier') == 'Liste_Kueche_Meier.xmlst', 'Fräsliste: Name aus Ordner')
check(S::Fraesliste.name('E:/') == 'Liste_Export.xmlst', 'Fräsliste: Laufwerk als Ordner')
check(S::Fraesliste.pfad('E:/Auftrag', 'A.tcn') == 'E:\\Auftrag\\A.tcn', 'Fräsliste: Windows-Pfad mit Backslash')
check(S::Fraesliste.pfad('/tmp/x', 'A.tcn') == '/tmp/x/A.tcn', 'Fräsliste: anderer Pfad unverändert')
check([S::Fraesliste.mm('10 mm'), S::Fraesliste.mm('1 cm'), S::Fraesliste.mm('0'), S::Fraesliste.mm(nil), S::Fraesliste.mm('0,5 m')] == [10.0, 10.0, 0.0, 0.0, 500.0], 'Fräsliste: OCL-Maße in mm')

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

# --- Hochschrank Kühlschrank: Lüftungsschacht (Böden kürzer, Rückwand oben in Nut), keine Lochreihe in der Nische ---
km = Sketchup.active_model = Sketchup::Model.new
HochschrankKuehlschrank.erstellen({})
dk, mk_ = S::Export.erzeugen(km)
check(mk_.empty?, "Hochschrank Kühlschrank: keine Meldungen #{mk_}")
check(dk.map(&:name).sort == %w[HK1_Boden HK1_Deckel HK1_N_Tuer HK1_O_Tuer HK1_RueckwandOben HK1_SeiteL HK1_SeiteR HK1_ZwischenbodenOben],
      "Hochschrank Kühlschrank: Teile ohne Platzhalter und ausgeblendete: #{dk.map(&:name).sort}")
zk = bearbeitungen(dk.find { |x| x.name == 'HK1_SeiteL' }.text, 1)
# Dübel 30 mm von der Hinterkante der gekürzten Böden: 30 + Schacht 40 + Rückwand 8 = 78
dueb = zk.select { |x| x.include?('fittingy.tmcr') && x.include?('#8522=8 ') }
check(dueb.size == 3 && dueb.all? { |x| x.include?('#8510=78 #8511=y-28') }, "Hochschrank Kühlschrank: Dübel Boden/Zwischenboden/Deckel: #{dueb}")
lr = zk.select { |x| x.include?('fittingx.tmcr') }
check(lr.size == 2 && lr.all? { |x| x.include?('#8510=x-242 #8511=x-50') } && lr.any? { |x| x.include?('#8518=83 ') },
      "Hochschrank Kühlschrank: Lochreihe nur oben, hinten 35 mm vor der Rückwand: #{lr}")
check(zk.count { |x| x.include?('#205=2200') } == 1, 'Hochschrank Kühlschrank: Nut für die Rückwand oben')
km = Sketchup.active_model = Sketchup::Model.new
HochschrankKuehlschrank.erstellen({ 'Lueftung' => 0.0 })
dk, = S::Export.erzeugen(km)
zk = bearbeitungen(dk.find { |x| x.name == 'HK1_SeiteL' }.text, 1)
check(dk.any? { |x| x.name == 'HK1_Rueckwand' } && zk.none? { |x| x.include?('#205=2200') } &&
      zk.select { |x| x.include?('#8522=8 ') }.all? { |x| x.include?('#8510=30 ') }, 'Hochschrank Kühlschrank Frontlüftung: Rückwand durchgehend, Böden volle Tiefe')

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
# --- Oberschrank Dunstabzug: Rohrausschnitt in Haubenboden, Deckel und Einlegeboden, Rückwand in der Haubenboden-Nut ---
om = Sketchup.active_model = Sketchup::Model.new
OberschrankDunstabzug.erstellen({ 'Anz_Einlegeboeden' => 1.0 })
dd, mo = S::Export.erzeugen(om)
check(mo.empty?, "Dunstabzug: keine Meldungen #{mo}")
ddz = dd.to_h { |x| [x.name, x] }
check(ddz.keys.sort == %w[OSD1_Boden OSD1_Deckel OSD1_Einlegeboden1 OSD1_Rueckwand OSD1_SeiteL OSD1_SeiteR OSD1_StrebeHinten
                          OSD1_TuerL OSD1_TuerR], "Dunstabzug: Dateien #{ddz.keys}")
# 170 x 170, mittig (562 breit: 196 vom Rand), 177 hinter der Korpusvorderkante = 175 im Fräsmaß (Anleimer vorn);
# Einlegeboden 10 mm zurückgesetzt: 165; durch 19 + 1 mm, Fräser Ø8,03 innen
{ 'OSD1_Boden' => 179.015, 'OSD1_Deckel' => 179.015, 'OSD1_Einlegeboden1' => 169.015 }.each do |n, y|
  k = bearbeitungen(ddz[n].text, 1).select { |x| x.start_with?('W#89', 'W#2201') }.last(5)
  check(ddz[n].lage.flaeche1 == :zmax && k[0].include?("#1=200.015 #2=#{y} #3=-20 ") && k[0].include?('#205=2200') &&
        k.drop(1) == ['W#2201{ ::WTl  #8015=1 #1=161.97 #2=0 }W', 'W#2201{ ::WTl  #8015=1 #1=0 #2=161.97 }W',
                      'W#2201{ ::WTl  #8015=1 #1=-161.97 #2=0 }W', 'W#2201{ ::WTl  #8015=1 #1=0 #2=-161.97 }W'],
        "Dunstabzug #{n}: Rohrausschnitt von oben, durch: #{k}")
end
check(bearbeitungen(ddz['OSD1_Boden'].text, 1).count { |x| x.start_with?('W#89') } == 2, 'Haubenboden: Nut für die Rückwand und Ausschnitt')
check(!ddz['OSD1_Boden'].text.include?('#8522=3 '), 'Haubenboden: keine Sockelfüße')
check(!ddz['OSD1_Deckel'].text.include?('#8522=3 '), 'Deckel: Kante nicht vorgebohrt (waagrecht nur Ø8)')
check(ddz['OSD1_Rueckwand'].text.include?('#8522=5 '), 'Rückwand: Schrauben zum Deckel Ø5 durch')
lr = bearbeitungen(ddz['OSD1_SeiteR'].text, 1).select { |x| x.include?('#8522=5 ') }
check(lr.size == 4 && lr.all? { |x| x.include?('#8510=116 #8511=345') || x.include?('#8510=x-261 #8511=x-50') },
      "Dunstabzug Seite: Lochreihen nur im Fach über dem Haubenboden: #{lr}")
# Umluft: kein Ausschnitt
om = Sketchup.active_model = Sketchup::Model.new
OberschrankDunstabzug.erstellen({ 'Abluft' => 0.0 })
dd, = S::Export.erzeugen(om)
check(dd.find { |x| x.name == 'OSD1_Deckel' }.text.split("\r\n").none? { |x| x.start_with?('W#89') }, 'Umluft: Deckel ohne Ausschnitt')
check(dd.find { |x| x.name == 'OSD1_Boden' }.text.split("\r\n").count { |x| x.start_with?('W#89') } == 1, 'Umluft: Haubenboden nur Nut')

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
# Seiten reichen bis zur Rückseite (Tiefe + 8 mm Rückwand), Nut 50 + 4 mm vor der Hinterkante
check(nut.size == 2 && nut[0].include?('#1=19 #2=752 #3=-9 ') && nut[1].include?('#1=686 #2=0 '),
      "Seite Spüle: Nut 50 + 4 mm vor der Hinterkante, ab Oberkante Boden bis über die Oberkante: #{nut}")
# Installationsebene 0 (Jürgen 2026-11-05): Rückwand wie beim Unterschrank voll hinter dem Korpus, keine Nut
sm0 = Sketchup.active_model = Sketchup::Model.new
Spuelenschrank.erstellen({ 'Rueckwand_Versatz' => 0.0 })
ds0, ms0 = S::Export.erzeugen(sm0)
d0 = ds0.to_h { |x| [x.name, x] }
check(ms0.empty?, "Spülenschrank Installationsebene 0: keine Meldungen #{ms0}")
check([d0['USP1_Rueckwand'].lage.dl, d0['USP1_Rueckwand'].lage.dh].sort == [700, 800].sort,
      "Spüle Installationsebene 0: Rückwand 800 x 700 wie Unterschrank (#{d0['USP1_Rueckwand'].lage.dl} x #{d0['USP1_Rueckwand'].lage.dh})")
check(%w[USP1_SeiteL USP1_SeiteR].none? { |n| d0[n].text.include?('#205=2200') && d0[n].text.include?('#3=-9 ') },
      'Spüle Installationsebene 0: keine Rückwandnut in den Seiten')
check(z.none? { |x| x.include?('#8522=5 ') && x.include?('fitting') }, 'Seite Spüle mit Auszug: keine Lochreihe')
check(z.count { |x| x.include?('#1002=5 ') && x.include?('#3=-14 ') } == 6, 'Seite Spüle: Schienenbohrungen für den Auszug (NL 650: 6)')
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
check(lr.size == 2 && lr.map { |x| x[/#8518=(\S+)/, 1] }.sort == %w[35 y-93], "Spüle mit Türen: Lochreihen 35 vorn, 93 hinten (50 + 8 Nut + 35): #{lr}")
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
# --- Kühlschrank-Nische: wie Geschirrspüler; Weinkühler/unterbaufähig ohne Möbelfront ---
km = Sketchup.active_model = Sketchup::Model.new
UnterschrankKuehlschrank.erstellen({ 'Art_Wange' => 3.0 })
UnterschrankKuehlschrank.erstellen({ 'Geraet_Art' => 1.0, 'Breite' => 30.0, 'Art_Wange' => 2.0 })
dk, = S::Export.erzeugen(km)
check(dk.map(&:name).sort == %w[UKS1_Front UKS1_WangeL UKS1_WangeR UKS2_WangeR], "Kühlschrank: Dateien #{dk.map(&:name)}")
dk.each do |x|
  z = bearbeitungen(x.text, 1)
  check(z.size == 1 && z.first.include?('squad.tmcr'), "Kühlschrank #{x.name}: nur Formatieren #{z}")
end
fk = dk.find { |x| x.name == 'UKS1_Front' }
check(fk && [fk.lage.dl, fk.lage.dh].sort.zip([594, 696]).all? { |a, b| (a - b).abs < 1e-6 }, "Kühlschrank Front Fräsmaß: #{fk && [fk.lage.dl, fk.lage.dh]}")
ff = S::Frontfarbe.fronten(km, kategorie: 'Unterschrank')
check(ff.size == 2 && ff.count(&:sichtbar?) == 1, 'Kühlschrank: Frontfarbe färbt auch die ausgeblendete Front mit, sichtbar ist eine')
zk, = S::Stueckliste.erzeugen(km)
check(zk.map(&:tag).sort == %w[UKS1_Front UKS1_WangeL UKS1_WangeR UKS2_WangeR], "Kühlschrank: Stückliste #{zk.map(&:tag)}")
# --- Unterschrank Mülltrennung: LEGRABOX-Auszug(e) wie Schubladen, Behälter werden nicht exportiert ---
schiene_bohr = ->(t) { bearbeitungen(t, 1).count { |x| x.include?('#1002=5 ') && x.include?('#3=-14 ') } }
[[0.0, 4, %w[A]], [1.0, 8, %w[A B]]].each do |fv, n_schiene, bereiche|
  am = Sketchup.active_model = Sketchup::Model.new
  UnterschrankAbfall.erstellen({ 'Frontvariante' => fv, 'Tiefe' => 52.0 })
  da_, ma = S::Export.erzeugen(am)
  check(ma.empty?, "Mülltrennung #{fv}: keine Meldungen #{ma}")
  dam = da_.to_h { |x| [x.name, x] }
  soll = %w[USM1_Boden USM1_Rueckwand USM1_SeiteL USM1_SeiteR USM1_StrebeHinten USM1_StrebeVorn] +
         bereiche.flat_map { |b| %w[Front KastenBoden KastenRueckwand].map { |t| "USM1_#{b}_#{t}" } }
  check(dam.keys.sort == soll.sort, "Mülltrennung #{fv}: Dateien ohne Behälter #{dam.keys}")
  %w[USM1_SeiteL USM1_SeiteR].each do |sn|
    check(schiene_bohr.(dam[sn].text) == n_schiene, "Mülltrennung #{fv} #{sn}: #{n_schiene} Schienenbohrungen (#{schiene_bohr.(dam[sn].text)})")
    check(bearbeitungen(dam[sn].text, 1).none? { |x| x.include?('#8522=5 ') && x.include?('fitting') }, "Mülltrennung #{fv} #{sn}: keine Lochreihe")
  end
  bereiche.each do |b|
    fb = bearbeitungen(dam["USM1_#{b}_Front"].text, 1).count { |x| x.include?('#1002=3 ') }
    check(fb >= 4 && fb.even?, "Mülltrennung #{fv}: Frontbefestigung #{b} (#{fb})")
  end
  check(dam['USM1_Boden'].text.include?('#8522=3 '), "Mülltrennung #{fv}: Sockelfüße")
  check(S::Frontfarbe.fronten(am, kategorie: 'Unterschrank').count(&:sichtbar?) == bereiche.size, "Mülltrennung #{fv}: Frontfarbe findet die Fronten")
end
# --- Inselschrank: Korpus und Schubladen wie bisher, Verkleidung, Wangen und Theke nur formatieren ---
[[{ 'Art_Wange' => 3.0 }, %w[A B C], %w[Verkleidung WangeL WangeR]],
 [{ 'Frontart' => 0.0, 'Theke' => 1.0 }, [], %w[Verkleidung Theke TuerL TuerR Einlegeboden1]]].each do |e, bereiche, extra|
  im = Sketchup.active_model = Sketchup::Model.new
  UnterschrankInsel.erstellen(e.merge('Tiefe' => 52.0))
  di_, mi = S::Export.erzeugen(im)
  check(mi.empty?, "Insel #{e}: keine Meldungen #{mi}")
  dim = di_.to_h { |x| [x.name, x] }
  soll = %w[Boden Rueckwand SeiteL SeiteR StrebeHinten StrebeVorn].map { |t| "USI1_#{t}" } + extra.map { |t| "USI1_#{t}" } +
         bereiche.flat_map { |b| %w[Front KastenBoden KastenRueckwand].map { |t| "USI1_#{b}_#{t}" } }
  check(dim.keys.sort == soll.sort, "Insel #{e}: Dateien #{dim.keys.sort}")
  (extra - %w[TuerL TuerR Einlegeboden1]).each do |t|
    z = bearbeitungen(dim["USI1_#{t}"].text, 1)
    check(z.size == 1 && z.first.include?('squad.tmcr'), "Insel #{t}: nur Formatieren #{z}")
  end
  %w[USI1_SeiteL USI1_SeiteR].each do |sn|
    check(schiene_bohr.(dim[sn].text) == 4 * bereiche.size, "Insel #{e} #{sn}: Schienenbohrungen (#{schiene_bohr.(dim[sn].text)})")
  end
  lr = bearbeitungen(dim['USI1_SeiteL'].text, 1).count { |x| x.include?('#8522=5 ') }
  check(bereiche.empty? ? lr == 2 : lr.zero?, "Insel #{e}: Lochreihen nur bei Türen (#{lr})")
  check(dim['USI1_Boden'].text.include?('#8522=3 '), "Insel #{e}: Sockelfüße")
  ff = S::Frontfarbe.fronten(im, kategorie: 'Unterschrank').select(&:sichtbar?)
  check(ff.map { |t| t.jt('teil') }.sort == (bereiche.map { 'Front' } + extra - %w[Theke Einlegeboden1]).sort,
        "Insel #{e}: Frontfarbe findet Fronten, Verkleidung und Wangen #{ff.map { |t| t.jt('teil') }}")
  S::Frontfarbe.anwenden(im, ff, im.materials.add('Front Eiche 19mm'), griff: { lochmass: 160, lage: 'Mitte', hoehe: 40 })
  neu = S::Frontfarbe.fronten(im, kategorie: 'Unterschrank').select(&:sichtbar?)
  check(neu.all? { |t| t.inst.material.name == 'Front Eiche 19mm' }, "Insel #{e}: Frontmaterial auf allen Sichtteilen")
  check(neu.all? { |t| t.front? == !t.jt('griff_lochmass').nil? }, "Insel #{e}: Griff nur an Fronten und Türen")
end
# --- Unterschrank Backofen (Herdumbau): Einbauboden wie Zwischenboden, keine Lochreihe, unten Blende oder Schublade ---
[[70.0, false], [76.0, true]].each do |hoehe, schublade|
  bm = Sketchup.active_model = Sketchup::Model.new
  UnterschrankBackofen.erstellen({ 'Tiefe' => 52.0, 'Hoehe' => hoehe })
  db_, mb_ = S::Export.erzeugen(bm)
  # 76 cm: unter dem Backofen bleiben 141 mm, die Schiene muss 38 über dem Boden sitzen (Kasten ab 57) -> M (90,5)
  # wäre 7 mm zu hoch, die Komponente nimmt Zarge N (66,5): keine Meldung
  soll_m = []
  check(mb_ == soll_m, "Herdumbau #{hoehe}: Meldungen #{mb_}")
  dbm = db_.to_h { |x| [x.name, x] }
  soll = %w[USB1_Boden USB1_Rueckwand USB1_SeiteL USB1_SeiteR USB1_ZwischenbodenUnten] +
         (schublade ? %w[USB1_S1_Front USB1_S1_KastenBoden USB1_S1_KastenRueckwand] : %w[USB1_Blende])
  check(dbm.keys.sort == soll.sort, "Herdumbau #{hoehe}: Dateien #{dbm.keys.sort}")
  eb = dbm['USB1_ZwischenbodenUnten']
  check((eb.lage.dh - 468).abs < 1e-6 && eb.text.lines.count { |x| x.include?('#8513=-22 ') } == 2,
        "Herdumbau #{hoehe}: Einbauboden 518 - 50 tief, Dübel in beiden Stirnseiten (#{eb.lage.dh})")
  %w[USB1_SeiteL USB1_SeiteR].each do |sn|
    z = bearbeitungen(dbm[sn].text, 1)
    duebel_eb = z.count { |x| x.include?('#8513=-14 ') && x.include?("#8518=#{(hoehe * 10 - 600 - 9.5).round(1)} ") }
    check(duebel_eb == 1, "Herdumbau #{hoehe} #{sn}: Dübelreihe Einbauboden (#{duebel_eb})")
    check(z.none? { |x| x.include?('#8522=5 ') }, "Herdumbau #{hoehe} #{sn}: keine Lochreihe")
    check(schiene_bohr.(dbm[sn].text) == (schublade ? 4 : 0), "Herdumbau #{hoehe} #{sn}: Schienenbohrungen #{schiene_bohr.(dbm[sn].text)}")
  end
  check(dbm['USB1_Boden'].text.include?('#8522=3 '), "Herdumbau #{hoehe}: Sockelfüße")
  if schublade # Zarge N: Rückwand 37 mm, Fronthalter nur das unterste Loch je Seite
    kr_ = dbm['USB1_S1_KastenRueckwand']
    fn = bearbeitungen(dbm['USB1_S1_Front'].text, 1).count { |x| x.include?('#1002=3 ') && x.include?('#3=-5 ') }
    check(([kr_.lage.dl, kr_.lage.dh].min - 35).abs < 1e-6 && fn == 2, "Herdumbau 76: Zarge N (Rückwand #{[kr_.lage.dl, kr_.lage.dh].min} + 2, Fronthalter #{fn})")
  end
  check(S::Frontfarbe.fronten(bm, kategorie: 'Unterschrank').count(&:sichtbar?) == 1, "Herdumbau #{hoehe}: eine sichtbare Front")
end
Sketchup.active_model = model

# --- Dialog: ein Export-Dialog für alle Ausgaben (hier nur TCN gewählt) ---
module UI
  class << self
    attr_accessor :antworten, :meldung, :url
    # :standard = Vorgaben übernehmen (Etikettenformat, Zuschnitt-Optionen)
    def inputbox(_l, werte, *) = ((a = (antworten || []).shift) == :standard ? werte : a)
    def messagebox(m, *) = (self.meldung = m)
    def openURL(u) = (self.url = u)
  end
end
# Alles gewählt: alle Ausgaben aus einem Lauf, überall dieselben Nummern
Dir.mktmpdir do |dir|
  UI.antworten = [%w[ja ja ja ja] + [dir], :standard, :standard]
  S::Export.dialog(model)
  check(%w[Stueckliste.pdf Stueckliste.csv Etiketten.pdf Zuschnitt.pdf tcn].all? { |f| File.exist?(File.join(dir, f)) },
        "alles gewählt: Stückliste, Etiketten, Zuschnitt im Zielordner, TCN im Unterordner (#{Dir.children(dir).sort})")
  check(Dir.children(dir).none? { |f| f =~ /\.(tcn|xmlst)\z/i }, 'keine TCN/xmlst direkt im Zielordner')
  csv = File.binread(File.join(dir, 'Stueckliste.csv')).force_encoding('Windows-1252').encode('UTF-8').split("\r\n").drop(1).map { |z| z.split(';') }
  tcn = Dir.children(File.join(dir, 'tcn')).grep(/\.tcn\z/).sort
  check(!csv.empty? && csv.map { |z| z[2] }.sort == tcn && csv.all? { |z| z[2].start_with?("#{z[0]}_#{z[1]}") },
        "Nummer und TCN-Datei in der Stückliste = Dateien im Ordner tcn (#{csv.first(2).map { |z| z.first(3) }})")
  et = PdfHelfer.texte(File.binread(File.join(dir, 'Etiketten.pdf')))
  check(csv.all? { |z| et.include?(z[2]) }, 'Etiketten tragen dieselben TCN-Dateinamen (Nummern)')
end
Dir.mktmpdir do |dir|
  ziel = File.join(dir, 'Kueche')
  File.write(File.join(dir, 'x.txt'), '') # nichts außerhalb tcn wird gelöscht
  FileUtils.mkdir_p(File.join(ziel, 'tcn'))
  File.write(File.join(ziel, 'tcn', '999_ALT_Teil.tcn'), 'alt')
  File.write(File.join(ziel, 'tcn', 'notiz.txt'), 'bleibt')
  UI.antworten = [%w[nein nein nein ja] + [ziel]]
  S::Export.dialog(model)
  tcn = File.join(ziel, 'tcn')
  check(UI.meldung.to_s.include?("#{dateien.size} TCN-Dateien"), "Dialog-Meldung: #{UI.meldung}")
  check(Dir.children(tcn).any? { |f| f =~ /\A\d+_HS1_SeiteL\.tcn\z/ }, 'TCN in den Unterordner tcn')
  check(Dir.children(tcn).include?('Liste_Kueche.xmlst'), "Fräsliste im Unterordner tcn, benannt nach dem Zielordner: #{Dir.children(tcn).grep(/xmlst/)}")
  check(File.binread(File.join(tcn, 'Liste_Kueche.xmlst')).include?(File.join(tcn, dateien.first.datei)), 'Fräsliste mit Pfad in tcn')
  check(!File.exist?(File.join(tcn, '999_ALT_Teil.tcn')) && File.exist?(File.join(tcn, 'notiz.txt')), 'alte TCN in tcn gelöscht, andere Dateien bleiben')
  check(Dir.children(ziel) == ['tcn'] && File.exist?(File.join(dir, 'x.txt')), "nur TCN gewählt: sonst nichts geschrieben (#{Dir.children(ziel)})")
  check(model.get_attribute('JT_Ausgabe', 'ordner') == ziel, 'Zielordner am Modell gemerkt')
  check(Sketchup.read_default('JT_Ausgabe', 'stueckliste') == 'nein' && Sketchup.read_default('JT_Ausgabe', 'tcn') == 'ja', 'Auswahl gemerkt')
  check(S::Ausgabe.ordner_vorschlag(model) == ziel, 'Vorschlag = zuletzt benutzter Ordner')
  UI.meldung = nil
  UI.antworten = [%w[nein nein nein nein] + [ziel]]
  S::Export.dialog(model)
  check(UI.meldung.to_s.include?('mindestens eine Ausgabe'), "nichts gewählt: Hinweis (#{UI.meldung})")
  UI.antworten = [%w[ja nein nein nein] + ['']]
  S::Export.dialog(model)
  check(UI.meldung.to_s.include?('Zielordner'), "kein Ordner: Hinweis (#{UI.meldung})")
end
UI.antworten = []
UI.meldung = nil
S::Export.dialog(model)
check(UI.meldung.nil?, 'Abbrechen im Dialog schreibt nichts')
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
# Seite wie Seite.tcn: DL = Höhe, DH = Tiefe 798 ab Vorderkante, also #1 = Höhe, #2 = Lage in der Tiefe
sr = bearbeitungen(k['USK1_SeiteR'].text, 1).select { |x| x.include?('#1002=5 ') && x.include?('#3=-14 ') }
xs = sr.map { |x| x[/#2=(\S+)/, 1].to_f }.uniq.sort
check(k['USK1_SeiteR'].lage.dh == 798 && xs == [35.0, 67.0, 259.0, 291.0, 355.0], "Kochfeld: Schienen NL 600 (37/69/261/293/357 roh): #{xs}")
check(sr.map { |x| x[/#1=(\S+)/, 1] }.uniq.size == 2, "Kochfeld: Schienen für 2 Schubladen: #{sr}")
check(S::Regeln.nennlaenge_schrank(km.definitions['Unterschrank Kochfeld mit Abzug']) == 600, 'NL-Attribut 60 cm = 600')
# Tiefe im Fenster Komponentenoptionen geändert: die DC schreibt die Werte (auch NL) an die Instanz,
# an der Definition steht noch der Stand beim Erzeugen -> der Export nimmt den Wert der Instanz
ki = km.entities.grep(Sketchup::ComponentInstance).first
ki.set_attribute('dynamic_attributes', 'nl', 45.0 / 2.54)
check(S::Regeln.nennlaenge_schrank(ki) == 450, "NL an der Instanz geht vor: #{S::Regeln.nennlaenge_schrank(ki)}")
ki.set_attribute('dynamic_attributes', 'hoehenoffset_schiene', 0.7 / 2.54)
check(S::Schraenke.dc(ki, 'hoehenoffset_schiene') == 0.7 / 2.54 && S::Schraenke.dc(ki, 'breite') == ki.definition.get_attribute('dynamic_attributes', 'breite'),
      'DC-Werte: Instanz vor Definition')
ki.set_attribute('dynamic_attributes', 'hoehenoffset_schiene', 0.0)
dk2, = S::Export.erzeugen(km)
sr2 = bearbeitungen(dk2.find { |x| x.name == 'USK1_SeiteR' }.text, 1).select { |x| x.include?('#1002=5 ') && x.include?('#3=-14 ') }
xs2 = sr2.map { |x| x[/#2=(\S+)/, 1].to_f }.uniq.sort
check(xs2 == [35.0, 67.0, 259.0, 291.0], "Kochfeld: Schienen NL 450 aus der Instanz (37/69/261/293 roh): #{xs2}")
# NL am Schrank größer als die gezeichnete lichte Tiefe (Tiefe 560 -> höchstens NL 550): Bohrungen für NL 550
schienen_hs = lambda do |nl_instanz|
  hm = Sketchup.active_model = Sketchup::Model.new
  hi = Hochschrank.erstellen({ 'Tiefe' => 56.0 })
  hi.set_attribute('dynamic_attributes', 'nl', nl_instanz / 2.54) if nl_instanz
  dh, = S::Export.erzeugen(hm)
  bearbeitungen(dh.find { |x| x.name == 'HS1_SeiteR' }.text, 1).select { |x| x.include?('#1002=5 ') && x.include?('#3=-14 ') }
end
soll_hs = schienen_hs.(nil)
ist_hs = schienen_hs.(65.0)
check(!soll_hs.empty? && ist_hs == soll_hs, "NL nie länger als die lichte Tiefe (Tiefe 560 -> NL 550): #{ist_hs - soll_hs}")
Sketchup.active_model = km
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
pos = schiene.(sl.text).map { |x| [sl.lage.dh - lage_mm(x[/#2=(\S+)/, 1], sl.lage.dh), lage_mm(x[/#1=(\S+)/, 1], sl.lage.dl)] }.sort
# Seite 700 hoch, 800 tief (wie Seite.tcn: DL = Höhe, DH = Tiefe 798, linke Seite mit der Vorderkante bei y = DH):
# 56/280/330 roh, 19 + 52 / 19 + 436 hoch
check(sl.lage.dh == 798 && pos == [54, 278, 328].product([71.0, 455.0]).sort, "Handtuch: Schienenbohrungen links (LH): #{pos}")
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
        lb.all? { |_, d| d == '5' } && # durch nur mit dem Durchgangsbohrer Ø5 (Werkzeugliste)
        lb.find { |(p, _)| p[0] == x_soll }[0][1].then { |y| [67.0, bo.lage.dh - 67].include?(y) },
        "#{tx}: Säulenlager im Boden (durchgebohrt von unten, alle Ø5): #{lb}")
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
# Strebe vorn B stößt mit dem Ende an die Kante der durchlaufenden Strebe vorn A: Dübel in
# beiden (A in der Kante, 22 tief); hinten nur eine Strebe an A
a = f['UES1_StrebeVorn1']
b = f['UES1_StrebeVorn2']
kante = [3, 5].flat_map { |sd| bearbeitungen(a.text, sd) }.select { |x| x.include?('#8522=8 ') && x.include?('#8513=-22 ') }
ende = [4, 6].map { |sd| bearbeitungen(b.text, sd).count { |x| x.include?('#8522=8 ') } }
check(kante.size == 1 && ende == [1, 1], "L-Form: Strebe vorn in der Ecke verdübelt (#{kante.size}, #{ende})")
check(a.lage.dl == 873 && f['UES1_StrebeHinten'] && !f['UES1_StrebeHinten2'],
      "L-Form: Strebe vorn A 873 lang bis an die Rückwand B, eine Strebe hinten (#{a.lage.dl}, #{f.keys.grep(/Strebe/)})")
check(S::Frontfarbe.fronten(lf).select(&:sichtbar?).map { |t| t.jt('teil') }.sort == %w[TuerL TuerR], 'L-Form: Frontfarbe findet beide Türen')


# --- Oberschrank mit Klappe: Korpus wie Oberschrank, Klappenteile als Front (HK-top eine, HF zwei) ---
model = Sketchup.active_model = Sketchup::Model.new
OberschrankKlappe.erstellen({})
OberschrankKlappe.erstellen({ 'Art_Klappe' => 2.0, 'Hoehe' => 72.0 })
dk, km = S::Export.erzeugen(model)
d = dk.to_h { |x| [x.name, x] }
check(km.size == 1 && km.first.start_with?('OK2: AVENTOS HF'), "Klappe: nur HF meldet fehlende Bohrungen: #{km}")
check(d['OK1_Klappe'] && !d['OK1_KlappeO'] && d['OK2_KlappeO'] && d['OK2_KlappeU'] && !d['OK2_Klappe'],
      "Klappe: nur sichtbare Klappenteile exportiert: #{d.keys.grep(/Klappe/)}")
check([d['OK1_Klappe'].lage.dl, d['OK1_Klappe'].lage.dh].map(&:round).sort == [394, 894], "HK-top-Klappe 898 x 398 Endmaß, im TCN ohne Anleimer 894 x 394 (#{d['OK1_Klappe'].lage.dl} x #{d['OK1_Klappe'].lage.dh})")
zk = bearbeitungen(d['OK1_SeiteR'].text, 1)
check(zk.count { |x| x.include?('#8522=5 ') } == 2, "Oberschrank mit Klappe Seite: Lochreihen wie Oberschrank: #{zk}")
# AVENTOS HK-top (Standard 900 x 400): Kraftspeicher 4 × Ø5 in einer Reihe, 37/69/101/133 ab Vorderkante,
# 36 unter der Oberkante; Frontbeschlag je Seite Ø5 12,5 ab Innenseite der Seite, 62/94 unter der Oberkante
ks = ->(w) { bearbeitungen(w.text, 1).select { |x| x.include?('#1002=5 ') && x.include?('#3=-12 ') && !x.include?('#8522') } }
%w[OK1_SeiteL OK1_SeiteR].each do |n|
  w = d[n]
  pk = ks.(w).map { |x| [lage_mm(x[/#1=(\S+)/, 1], w.lage.dl), lage_mm(x[/#2=(\S+)/, 1], w.lage.dh)] }
  check(pk.size == 4 && pk.map(&:first).uniq.size == 1, "#{n}: Kraftspeicher 4 Löcher in einer Reihe: #{pk}")
  vorn = pk.map(&:last).map { |y| [y, w.lage.dh - y].min }.sort
  check(vorn == [37, 69, 101, 133].map { |v| v - 2.0 }, "#{n}: Kraftspeicher ab Vorderkante (Fräsmaß, 2 mm Anleimer vorn): #{vorn}")
  hoch = pk.first && [pk.first.first, w.lage.dl - pk.first.first].min
  check(hoch && (hoch - 34.0).abs < 1e-6, "#{n}: Kraftspeicher 36 unter der Oberkante (Fräsmaß 34): #{hoch}")
end
fk = d['OK1_Klappe']
fb = ks.(fk).map { |x| [lage_mm(x[/#1=(\S+)/, 1], fk.lage.dl), lage_mm(x[/#2=(\S+)/, 1], fk.lage.dh)] }.sort
# Klappe 898 x 398, rundum Anleimer (Fräsmaß 894 x 394); Innenseite der Seite 18 vom Klappenrand -> 30,5 (28,5 im Fräsmaß),
# Oberkante Klappe 1 unter Korpusoberkante -> 61 / 93 (59 / 91 im Fräsmaß)
xs = fb.map { |p| [p[0], fk.lage.dl - p[0]].min }.uniq.sort
ys = fb.map { |p| [p[1], fk.lage.dh - p[1]].min }.uniq.sort
check(fb.size == 4 && xs == [28.5] && ys == [59.0, 91.0], "Klappe: Frontbeschlag HK-top #{fb} (x #{xs}, y #{ys})")
check(ks.(d['OK2_KlappeO']).empty? && ks.(d['OK2_SeiteL']).empty?, 'HF: noch keine AVENTOS-Bohrungen')
check(bearbeitungen(d['OK1_Rueckwand'].text, 1).any? { |x| x.include?('#8522=5 ') && x.include?('#8513=-9 ') }, 'Rückwand für die Deckelschrauben gebohrt')
check([3, 4, 5, 6].flat_map { |sd| bearbeitungen(d['OK1_Deckel'].text, sd) }.none? { |x| x.include?('#8522=3 ') }, 'Deckel: Kante nicht vorgebohrt')
# --- Abschlussregal: Schräge und Bogen als Kontur (Fräser 1004, Ø 20) ---
# Unterschrank 300 x 700 x 520, Seite außen rechts 150 tief: Schräge im Boden von (0, 0) nach
# (520 - 150, 262) im Werkstück (x = Tiefe), Bahn 10 - 2 mm (Radius - Anleimer) in den Abfall versetzt
rm = Sketchup.active_model = Sketchup::Model.new
RegalAbschluss.erstellen('Form' => 1.0, 'Anz_Einlegeboeden' => 1.0)
rd, rmeld = S::Export.erzeugen(rm)
rf = rd.to_h { |x| [x.name, x] }
check(rmeld.empty?, "Regal schräg: keine Meldungen #{rmeld}")
check(rf.keys.sort == %w[RA1_Boden RA1_Deckel RA1_Einlegeboden1 RA1_Rueckwand RA1_SeiteL RA1_SeiteR], "Regal schräg: Dateien #{rf.keys}")
rb = rf['RA1_Boden']
check(rb.lage.dl.round(3) == 520 && rb.lage.dh.round(3) == 262, "Regal schräg: Boden als Rechteck 520 x 262 (#{rb.lage.dl} x #{rb.lage.dh})")
k1 = bearbeitungen(rb.text, 1).drop_while { |x| !x.include?('W#89') }
check(k1.size == 4 && k1[0].include?('#205=1004 ') && k1[0].include?('#3=-20 ') && k1[2].include?('#1=370 #2=262 '),
      "Regal schräg: Kontur Gerade 370/262 mit 1004 ganz durch: #{k1}")
if k1.size == 4
  x0, y0 = k1[0][/#1=(\S+)/, 1].to_f, k1[0][/#2=(\S+)/, 1].to_f
  dx, dy = k1[1][/#1=(\S+)/, 1].to_f, k1[1][/#2=(\S+)/, 1].to_f
  ax, ay = x0 + dx, y0 + dy
  abstand = (ax * 262 - ay * 370).abs / Math.hypot(370, 262)
  check((abstand - 8).abs < 0.01, "Regal schräg: Bahn 8 mm neben der fertigen Schräge (#{abstand})")
  check(x0 < -10 || y0 < -10, "Regal schräg: Fräser startet außerhalb der Platte (#{x0}, #{y0})")
  check((dx * 262 - dy * 370).abs < 0.01 && dx > 0, 'Regal schräg: tangential einfahren')
end
# Dübel: Seite außen nur auf ihren 150 mm (x-120 … x-30), Seite innen über die volle Tiefe
st = [3, 5].flat_map { |sd| bearbeitungen(rb.text, sd) }.select { |x| x.include?('#8522=8 ') }
check(st.size == 2 && st.any? { |x| x.include?('#8510=x-120 #8511=x-30 ') } && st.any? { |x| x.include?('#8510=30 #8511=x-30 ') },
      "Regal schräg: Dübel Boden an beiden Seiten #{st}")
check(rf['RA1_SeiteR'].lage.dh.round(3) == 148 && bearbeitungen(rf['RA1_SeiteR'].text, 1).count { |x| x.include?('#8522=8 ') } == 2,
      'Regal schräg: Seite außen 150 tief mit Dübeln für Boden und Deckel')
check(%w[SeiteL SeiteR].all? { |n| bearbeitungen(rf["RA1_#{n}"].text, 1).count { |x| x.include?('#8522=5 ') } == 2 }, 'Regal: Lochreihen in beiden Seiten')
# Sockelfüße: alle innerhalb der Schräge (mindestens 20 mm vom Rand)
kd = S::Regeln.kontur_daten(rb.ws)
poly = kd[:umriss].map { |q| [rb.lage.x(q), rb.lage.y(q)] }
fuesse = rb.ws.ops.select { |o| o.titel == 'Sockelfuss' }
check(fuesse.size == 8 && fuesse.all? { |o| [o.p0, o.p1].all? { |q| v = [rb.lage.x(q), rb.lage.y(q)]; S::Regeln.innen?(v, poly) && S::Regeln.randabstand(v, poly) >= 20 - 1e-6 } },
      "Regal schräg: Sockelfüße im Boden (#{fuesse.size})")
check(!rf['RA1_Deckel'].text.include?('#8522=3 '), 'Regal: keine Sockelfüße im Deckel')
check(bearbeitungen(rf['RA1_Einlegeboden1'].text, 1).count { |x| x.include?('W#89') } == 1, 'Regal schräg: Einlegeboden mit Kontur')
# Stückliste: Rechteck als Zuschnitt, Schräge als Kante Kontur mit Länge
rz = S::Stueckliste.zeilen(rd).find { |x| x.tag == 'RA1_Boden' }
check(rz && rz.fraes.map(&:round) == [520, 262] && rz.kanten.values.compact.empty? &&
      (rz.kontur['Anleimer Melamin weiss'] - Math.hypot(370, 262)).abs < 0.01,
      "Regal schräg: Stückliste Boden #{rz && [rz.fraes, rz.kanten, rz.kontur]}")
rc = S::Stueckliste.csv(S::Stueckliste.zeilen(rd)).split("\r\n").find { |l| l.start_with?('') && l.include?('RA1_Boden;') }
check(rc.to_s.end_with?(';Anleimer Melamin weiss 453,4 mm'), "Regal: CSV Kante Kontur #{rc}")
check(PdfHelfer.texte(S::Stueckliste.pdf(S::Stueckliste.zeilen(rd))).any? { |t| t.end_with?('(Kontur: A 453,4 mm)') }, 'Regal: Stückliste-PDF Kontur')

# Rund, Seite außen links: Viertelkreis R 262, Bahn R 270 (Radius + 10 - 2) als kurze Geraden,
# kein W#2125 (Jürgen 2026-11-05: TPA meldete beim Deckel "Radius ungültig")
rm = Sketchup.active_model = Sketchup::Model.new
RegalAbschluss.erstellen('Form' => 2.0, 'Zeilenende' => 1.0, 'Anz_Einlegeboeden' => 0.0)
rd, rmeld = S::Export.erzeugen(rm)
rf = rd.to_h { |x| [x.name, x] }
check(rmeld.empty?, "Regal rund: keine Meldungen #{rmeld}")
def bahn_punkte(zeilen)
  x, y = zeilen[0].match(/#1=(\S+) #2=(\S+)/).captures.map(&:to_f)
  pts = [[x, y]]
  zeilen[1..].take_while { |l| l.start_with?('W#2201') }.each do |l|
    dx, dy = l.match(/#1=(\S+) #2=(\S+)/).captures.map(&:to_f)
    pts << [pts.last[0] + dx, pts.last[1] + dy]
  end
  pts
end
%w[RA1_Boden RA1_Deckel].each do |teil|
  z = bearbeitungen(rf[teil].text, 1).drop_while { |x| !x.include?('W#89') }
  check(z.none? { |x| x.include?('W#2125') }, "Regal rund #{teil}: kein W#2125")
  pts = bahn_punkte(z)
  # Stücke höchstens 10 mm lang und Richtungswechsel je Stück höchstens 5 Grad
  laengen = pts.each_cons(2).map { |p0, p1| Math.hypot(p1[0] - p0[0], p1[1] - p0[1]) }
  dirs = pts.each_cons(2).map { |p0, p1| Math.atan2(p1[1] - p0[1], p1[0] - p0[0]) }
  knicke = dirs.each_cons(2).map { |d0, d1| ((d1 - d0 + Math::PI) % (2 * Math::PI) - Math::PI).abs * 180 / Math::PI }
  check(z.size > 40 && laengen[2..-3].all? { |l| l <= 10.01 } && knicke.all? { |k| k <= 5.01 },
        "Regal rund #{teil}: Bogen aus kurzen Geraden, glatt (#{z.size} Zeilen, max Knick #{knicke.max&.round(2)})")
  gesamt = knicke.sum
  check((gesamt - 90).abs < 0.5, "Regal rund #{teil}: Bahn dreht insgesamt 90 Grad (#{gesamt.round(2)})")
end
check(rf['RA1_SeiteL'].lage.dh.round(3) == 256, "Regal rund: Seite außen links 258 tief (#{rf['RA1_SeiteL'].lage.dh})")
rz = S::Stueckliste.zeilen(rd).find { |x| x.tag == 'RA1_Boden' }
check(rz && (rz.kontur.values.sum - Math::PI / 2 * 262).abs < 1.0, "Regal rund: Bogenlänge #{rz && rz.kontur}")
fu = rf['RA1_Boden'].ws.ops.select { |o| o.titel == 'Sockelfuss' }
kd = S::Regeln.kontur_daten(rf['RA1_Boden'].ws)
check(fu.size == 8 && fu.all? { |o| S::Regeln.innen?([o.p0[0], o.p0[1]], kd[:umriss].map { |q| q[0, 2] }) }, 'Regal rund: Sockelfüße im Boden')

# Gerade: keine Kontur
rm = Sketchup.active_model = Sketchup::Model.new
RegalAbschluss.erstellen
rd, = S::Export.erzeugen(rm)
check(rd.none? { |x| x.text.include?('W#89') }, 'Regal gerade: keine Kontur')

# --- Wange mit Sockelausklinkung (Blenden & Wangen): Ausklinkung als Kontur mit 1004 ---
# Wange 19 mm, Unterschrank 700 + Sockel 100, Tiefe 520: Ausklinkung 100 hoch, bis 71 mm hinter
# die Front (Spalt 2 + Korpus 19 + Rücksprung 50). Bahn 10 mm (Fräserradius) neben beiden Kanten,
# in der Innenecke im Schnittpunkt verbunden, Start unten und Ende vorne außerhalb der Platte.
[[1.9, 1], [3.8, 2]].each do |st, stufen|
  wm = Sketchup.active_model = Sketchup::Model.new
  Blenden.erstellen(:wange, 'Seite' => 'rechts', 'Tiefe' => 52.0, 'Staerke' => st, 'Ausklinkung' => 1.0)
  wd, wmeld = S::Export.erzeugen(wm)
  wf = wd.find { |x| x.name == 'WG1_WangeR' }
  check(wmeld.empty? && wf, "Wange #{st * 10} mm: Datei, keine Meldungen #{wmeld}")
  next unless wf
  kd = S::Regeln.kontur_daten(wf.ws)
  check(kd && kd[:segmente].size == 2 && kd[:umriss].size == 6, "Wange: Kontur aus zwei Geraden #{kd && kd[:segmente].size}")
  z = bearbeitungen(wf.text, 1).drop_while { |x| !x.include?('W#89') }
  starts = z.select { |x| x.include?('W#89') }
  check(starts.size == stufen && starts.all? { |x| x.include?('#205=1004 ') } && z.none? { |x| x.include?('W#2125') },
        "Wange #{st * 10} mm: #{stufen} Zustellung(en) mit 1004, nur Geraden: #{starts}")
  tiefen = [0.0] + starts.map { |x| x[/#3=-(\S+)/, 1].to_f }
  check(tiefen.each_cons(2).all? { |a, b| b - a <= 20.0 + 1e-6 } && (tiefen.last - st * 10 - 1).abs < 1e-6,
        "Wange #{st * 10} mm: ganz durch, höchstens 20 mm je Zustellung #{tiefen}")
  pts = bahn_punkte(z)
  # Lage der Ausklinkung im Werkstück aus der Kontur: Ecke und Kanten
  ecke = [wf.lage.x(kd[:segmente][0][2]), wf.lage.y(kd[:segmente][0][2])]
  unten = [wf.lage.x(kd[:segmente][0][1]), wf.lage.y(kd[:segmente][0][1])]
  vorn = [wf.lage.x(kd[:segmente][1][2]), wf.lage.y(kd[:segmente][1][2])]
  pts = pts.take(5)
  check(pts.size == 5, "Wange: Einfahren, zwei Geraden, Ausfahren (#{pts.size} Punkte)")
  if pts.size == 5
    # Bahnecke 10 mm von beiden Kanten der Ausklinkung entfernt, auf der Abfallseite
    innen = [unten[0] + vorn[0] - ecke[0], unten[1] + vorn[1] - ecke[1]] # gegenüberliegende Ecke (Abfall)
    rx = innen[0] < ecke[0] ? -10 : 10
    ry = innen[1] < ecke[1] ? -10 : 10
    check((pts[2][0] - (ecke[0] + rx)).abs < 0.01 && (pts[2][1] - (ecke[1] + ry)).abs < 0.01,
          "Wange: Innenecke im Schnittpunkt #{pts[2]} (Ecke #{ecke})")
    aussen = ->(q) { q[0] < -9.99 || q[1] < -9.99 || q[0] > wf.lage.dl + 9.99 || q[1] > wf.lage.dh + 9.99 }
    check(aussen.(pts[0]) && aussen.(pts[4]), "Wange: Start und Ende außerhalb der Platte #{pts[0]} #{pts[4]}")
  end
end
wz = S::Stueckliste.zeilen(S::Export.erzeugen(Sketchup.active_model).first).find { |x| x.tag == 'WG1_WangeR' }
check(wz && wz.kanten.values.compact.size == 2 && wz.kontur.empty?, "Wange Ausklinkung: Stückliste Kanten vorne und oben #{wz && wz.kanten}")

# Frontfarbe: Regal mit Farbe Frontfarbe bekommt das Material, aber keine Griffe
rm = Sketchup.active_model = Sketchup::Model.new
RegalAbschluss.erstellen('Form' => 1.0, 'Farbe' => 1.0)
RegalAbschluss.erstellen
fm = rm.materials.add('Front Eiche 19mm')
fm.set_attribute('ladb_opencutlist', 'type', 2)
ff = S::Frontfarbe.fronten(rm)
check(ff.size == 6 && ff.all? { |t| t.jt('schrank') == 'RA1' }, "Frontfarbe: nur das Regal mit Frontfarbe (#{ff.map(&:name)})")
S::Frontfarbe.anwenden(rm, ff, fm, griff: { lochmass: 160, lage: 'Mitte', hoehe: 35 })
rt = S::Schraenke.teile(rm)
check(rt.select { |t| t.jt('schrank') == 'RA1' }.all? { |t| t.inst.material == fm && t.jt('griff_lochmass').nil? }, 'Frontfarbe: Regal in Frontmaterial, ohne Griff')
check(rt.select { |t| t.jt('schrank') == 'RA2' }.all? { |t| t.inst.material.name == 'Melamin weiss' }, 'Frontfarbe: Regal in Korpusfarbe bleibt')
kb = rt.find { |t| t.name == 'RA1_Boden' }.inst.definition.entities.grep(Sketchup::Face).select(&:material)
check(!kb.empty? && kb.all? { |x| x.material.name == 'Anleimer Eiche' }, 'Frontfarbe: Anleimer an der Schräge passend')

# --- Zustellung: Fräsungen nie tiefer als 20 mm in einem Schritt (gilt für alle TCN) ---
t = S::Tcn
check(t.stufen(9) == [9] && t.stufen(20) == [20] && t.stufen(39) == [19.5, 39] && t.stufen(45) == [15, 30, 45],
      "Zustellschritte: #{t.stufen(39)} #{t.stufen(45)}")
bahn = ['W#89{ ::WTs WS=@  #8015=0 #1=0 #2=0 #3=-39 #201=1 #205=1004 }W',
        'W#2201{ ::WTl  #8015=1 #1=100 #2=0 }W', 'W#2125{ ::WTa  #8015=0 #8017=30 #8046=-45 }W',
        'W#81{ ::WTp WS=@  #8015=0 #1=5 #2=5 #3=-25 #1002=8 }W',
        'W#89{ ::WTs WS=@  #8015=0 #1=0 #2=0 #3=-9 #201=1 #205=2200 }W', 'W#2201{ ::WTl  #8015=1 #1=50 #2=0 }W',
        'W#1022{ ::WT2 WS=@  #8098=rect.tmcr #8514=-30 #8515=100 }W']
z = t.zustellen(bahn)
check(z.size == 11 && z[0].include?(' #3=-19.5 ') && z[3].include?(' #3=-39 ') && z[1, 2] == bahn[1, 2] && z[4, 2] == bahn[1, 2],
      "Bahn 39 tief: 2 Durchgänge mit allen Bahnzeilen: #{z}")
check(z[6] == bahn[3] && z[7] == bahn[4] && z[8] == bahn[5], 'Bohrung und flache Nut unverändert')
check(z[9].include?(' #8514=-15 ') && z[10].include?(' #8514=-30 '), "Tasche 30 tief in 2 Schritten: #{z.last(2)}")
# --- Eck-Oberschrank L-Form: Rückwandnut in Seiten und L-Boden, Deckel an beide Rückwände geschraubt,
# Innenecke von oben (Fläche 1 des Bodens = Nutseite), keine Sockelfüße ---
eo = Sketchup.active_model = Sketchup::Model.new
EckOberschrank.erstellen({})
deo, meo = S::Export.erzeugen(eo)
o = deo.to_h { |x| [x.name, x] }
check(meo.empty?, "Eck-Oberschrank: keine Meldungen: #{meo}")
check(o.keys.sort == %w[OES1_Auflageleiste1 OES1_Boden OES1_Deckel OES1_Einlegeboden1 OES1_Rueckwand1 OES1_Rueckwand2
                        OES1_SeiteL OES1_SeiteR OES1_TuerL OES1_TuerR], "Eck-Oberschrank: Dateien #{o.keys}")
ob = o['OES1_Boden']
check(ob.lage.dl == 631 && ob.lage.dh == 631 && ob.lage.flaeche1 == :zmax, "Eck-Oberschrank Boden: 631 x 631, Fläche 1 oben: #{ob.lage.to_a.drop(1)}")
b1 = bearbeitungen(ob.text, 1)
check(b1.count { |x| x.include?('W#89') && x.include?('#3=-9 ') } == 2, "Eck-Oberschrank Boden: Nut für beide Rückwände: #{b1}")
check(b1.any? { |x| x.include?('W#89') && x.include?('#1=352.015 ') && x.include?('#3=-20 ') }, "Eck-Oberschrank Boden: Innenecke von oben ausgefräst: #{b1}")
check(deo.none? { |x| x.text.include?('#8522=3 ') && x.text.include?('#8513=-3 ') }, 'Eck-Oberschrank: keine Sockelfüße')
%w[OES1_SeiteL OES1_SeiteR].each do |n|
  check(bearbeitungen(o[n].text, 1).any? { |x| x.include?('W#89') } && o[n].text.include?('#8522=5 '), "#{n}: Rückwandnut und Lochreihen")
end
od = o['OES1_Deckel']
schr = [3, 4, 5, 6].flat_map { |sd| bearbeitungen(od.text, sd) }.reject { |x| x.include?('#8522=8 ') }
check(schr.empty?, "Eck-Oberschrank Deckel: Kanten nicht vorgebohrt (waagrecht nur Ø8): #{schr}")
check(bearbeitungen(od.text, 1).any? { |x| x.include?('W#89') && x.include?('#3=-20 ') }, 'Eck-Oberschrank Deckel: Innenecke ausgefräst')
check(%w[OES1_Rueckwand1 OES1_Rueckwand2].all? { |n| o[n].text.include?('#8513=-9 ') && o[n].text.include?('#8522=5 ') }, 'Eck-Oberschrank: Rückwände für die Deckelschrauben gebohrt')
check(S::Frontfarbe.fronten(eo).select(&:sichtbar?).map { |t| t.jt('teil') }.sort == %w[TuerL TuerR], 'Eck-Oberschrank: Frontfarbe findet beide Türen')

# --- Blum-Topfbänder an allen Türen (inge100 wie T_re_L_Topfband.tcn, Montageplatte im Raster der Lochreihe) ---
VORLAGE_TB = beispiel('T_re_L_Topfband.tcn').split(/\r?\n/).grep(/inge100/).first.sub(/WS=\d+ +/, 'WS ').sub(/ #8507=\S+/, '').tr(',', '.')
def topfbaender(d) = bearbeitungen(d.text, 1).grep(/inge100/)
def tb_x(d) = topfbaender(d).map { |z| v = z[/#8507=(\S+)/, 1]; v.start_with?('x-') ? d.lage.dl - v[2..].to_f : v.to_f }.sort
def tb_export(titel)
  m = Sketchup.active_model = Sketchup::Model.new
  yield
  dt, me = S::Export.erzeugen(m)
  [dt.to_h { |x| [x.name, x] }, me, dt]
end
[['Oberschrank', -> { Oberschrank.erstellen({}) }, %w[OS1_TuerL OS1_TuerR]],
 ['Oberschrank eine Tür', -> { Oberschrank.erstellen({ 'Art_Tuer' => 1.0, 'Breite' => 50.0 }) }, %w[OS1_Tuer]],
 ['Oberschrank eine Tür rechts', -> { Oberschrank.erstellen({ 'Art_Tuer' => 3.0, 'Breite' => 50.0 }) }, %w[OS1_Tuer]],
 ['Hochschrank', -> { Hochschrank.erstellen({}) }, %w[HS1_O_Tuer]],
 ['Spüle', -> { Spuelenschrank.erstellen({ 'Frontvariante' => 0.0 }) }, %w[USP1_TuerL USP1_TuerR]],
 ['Unterschrank Doppeltür', -> { UnterschrankDoppeltuer.erstellen({}) }, %w[USD1_TuerL USD1_TuerR]],
 ['Insel', -> { UnterschrankInsel.erstellen({ 'Frontart' => 0.0 }) }, %w[USI1_TuerL USI1_TuerR]],
 ['Dunstabzug', -> { OberschrankDunstabzug.erstellen({}) }, %w[OSD1_TuerL OSD1_TuerR]],
 ['Eckschrank', -> { Eckschrank.erstellen({}) }, %w[UES1_Tuer]],
 ['Eckschrank L-Form', -> { Eckschrank.erstellen({}, l_form: true) }, %w[UES1_TuerL UES1_TuerR]],
 ['Eck-Oberschrank', -> { EckOberschrank.erstellen({}) }, %w[OES1_TuerL OES1_TuerR]],
 ['Hochschrank Geräte', -> { HochschrankGeraete.erstellen({}) }, %w[HG1_O_Tuer]],
 ['Hochschrank Kühlschrank', -> { HochschrankKuehlschrank.erstellen({}) }, %w[HK1_O_Tuer]]].each do |titel, bau, namen|
  td, tm, = tb_export(titel, &bau)
  alle = td.values.select { |x| x.ws.rolle == 'Tuer' }.map(&:name)
  check((namen - alle).empty?, "#{titel}: Türen #{alle}")
  namen.each do |n|
    t = td[n]
    z = topfbaender(t)
    check(z.size == 2, "#{titel} #{n}: 2 Topfbänder (#{z.size})")
    check(z.all? { |l| l.sub(/ #8507=\S+/, '').tr(',', '.') == VORLAGE_TB }, "#{titel} #{n}: wie die Vorlage (Ø35, Schraublöcher 45/9,5, y-21,5): #{z.first}")
    x = tb_x(t)
    check(x.first.between?(60, 140) && (t.lage.dl - x.last).between?(60, 140), "#{titel} #{n}: Bänder #{x} nahe Ober-/Unterkante (DL #{t.lage.dl})")
    # (die kurze Falttür hängt an der langen Tür, nicht an der Lochreihe; Dunstabzug: Bänder in zwei
    # Fächern, unten über der Strebe vor dem Abzug)
    check(%w[UES1_TuerL OES1_TuerL].include?(n) || titel == 'Dunstabzug' || (((x.last - x.first) / 32.0) - ((x.last - x.first) / 32.0).round).abs < 1e-6,
          "#{titel} #{n}: Abstand im 32er-Raster (#{x})")
    check(t.lage.flaeche1 == t.ws.ops.find { |o| o.art == :topfband }.seite, "#{titel} #{n}: Topf auf Fläche 1")
  end
  check(tm.none? { |m| m.include?('Topfb') }, "#{titel}: keine Meldung zu Topfbändern: #{tm}")
  # Montageplatte: Systemschrauben Ø5 16 mm über und unter jedem Band liegen in der Lochreihe der Seite
  td.values.select { |x| x.ws.rolle == 'Seite' }.each do |s|
    mp = s.ws.ops.select { |o| o.titel.include?('Montageplatte') }
    check(mp.empty?, "#{titel} #{s.name}: Montageplatte in der vorhandenen Lochreihe, keine Extralöcher (#{mp.size})")
  end
end

# Unterschrank mit Doppeltür: alle Platten als Datei (ausgeblendete Einlegeböden nicht), keine Meldungen,
# linke Tür links, rechte rechts angeschlagen, Topf auf der Innenseite
td, tm, = tb_export('USD') { UnterschrankDoppeltuer.erstellen({ 'Anz_Einlegeboeden' => 2.0 }) }
check(td.keys.sort == %w[USD1_Boden USD1_Einlegeboden1 USD1_Einlegeboden2 USD1_Rueckwand USD1_SeiteL USD1_SeiteR
                         USD1_StrebeHinten USD1_StrebeVorn USD1_TuerL USD1_TuerR], "Doppeltür: Dateien #{td.keys.sort}")
check(tm.empty?, "Doppeltür: keine Meldungen: #{tm}")
%w[USD1_TuerL USD1_TuerR].each do |n|
  op = td[n].ws.ops.find { |o| o.art == :topfband }
  check(op && op.daten[:kante] == (n.end_with?('L') ? :xmin : :xmax), "Doppeltür #{n}: Anschlag #{op&.daten&.[](:kante)}")
  check(op && op.seite == :ymax, "Doppeltür #{n}: Topf auf der Innenseite")
end
check(%w[USD1_SeiteL USD1_SeiteR].all? { |n| td[n].text.include?('#8522=5 ') }, 'Doppeltür: Lochreihen in beiden Seiten')

# Ober- und Unterschrank: Anschlag links bzw. rechts, Topf auf der Innenseite an der Anschlagkante
td, = tb_export('OS') { Oberschrank.erstellen({}) }
%w[OS1_TuerL OS1_TuerR].each do |n|
  op = td[n].ws.ops.find { |o| o.art == :topfband }
  check(op.daten[:kante] == (n.end_with?('L') ? :xmin : :xmax), "#{n}: Anschlag #{op.daten[:kante]}")
  check(op.seite == :ymax, "#{n}: Topf auf der Innenseite (#{op.seite})")
  w = td[n].ws
  check((n.end_with?('L') ? op.p0[0] - w.lo_f(0) : w.hi_f(0) - op.p0[0]).round(3) == 21.5, "#{n}: Topfmitte 21,5 vom Rand")
end
# Oberschrank mit einer Tür: Anschlag links oder rechts wählbar
[[1.0, :xmin], [3.0, :xmax]].each do |art, kante|
  te, = tb_export('OS eine Tür') { Oberschrank.erstellen({ 'Art_Tuer' => art, 'Breite' => 50.0 }) }
  op = te['OS1_Tuer'].ws.ops.find { |o| o.art == :topfband }
  check(op.daten[:kante] == kante && op.seite == :ymax, "OS1_Tuer (Art #{art.to_i}): Anschlag #{op.daten[:kante]}, Topf #{op.seite}")
  w = te['OS1_Tuer'].ws
  check((kante == :xmin ? op.p0[0] - w.lo_f(0) : w.hi_f(0) - op.p0[0]).round(3) == 21.5, "OS1_Tuer (Art #{art.to_i}): Topfmitte 21,5 vom Rand")
end
# Bänder liegen in der Lochreihe: Schraublöcher der Montageplatte = Löcher der Reihe
sl = td['OS1_SeiteL'].ws
os_t = td['OS1_TuerL'].ws.ops.select { |o| o.art == :topfband }.map { |o| o.p0[2] }
reihe = sl.ops.find { |o| o.titel == 'Lochreihe' && (o.p0[1] - (sl.lo_f(1) + 35)).abs < 0.5 && os_t.first.between?(*[o.p0[2], o.p1[2]].minmax) }
check(reihe && os_t.all? { |z| [z - 16, z + 16].all? { |q| ((q - [reihe.p0[2], reihe.p1[2]].min) / 32.0).then { |f| (f - f.round).abs < 1e-6 } } },
      "Oberschrank: Montageplatte in der Lochreihe (#{os_t})")

# Falttür: lange Tür am Korpus, kurze am Eckscharnier (an der Kante zur langen Tür)
td, = tb_export('L') { Eckschrank.erstellen({}, l_form: true) }
lang, kurz = %w[UES1_TuerR UES1_TuerL].map { |n| td[n].ws }.sort_by { |w| -w.flaechen_achsen.reject { |a| a == 2 }.map { |a| w.mass(a) }.max }
k = kurz.ops.find { |o| o.art == :topfband }.daten[:kante]
a = S::Geometrie.achse(k)
check((S::Geometrie.max?(k) ? kurz.hi[a] : kurz.lo[a]).between?(lang.lo[a] - 30, lang.hi[a] + 30), "Falttür: kurze Tür am Eckscharnier (#{k})")

# Hochschrank Kühlschrank: Schlepptür ohne Topfbänder, Festtür mit 4 Bändern und Montageplatten (Nische ohne Lochreihe)
td, = tb_export('HK') { HochschrankKuehlschrank.erstellen({}) }
check(topfbaender(td['HK1_N_Tuer']).empty?, 'Schlepptür hängt am Gerät: keine Topfbänder')
td, = tb_export('HK fest') { HochschrankKuehlschrank.erstellen({ 'Tuertechnik' => 2.0 }) }
check(topfbaender(td['HK1_N_Tuer']).size == 4, "Festtür 1812 hoch: 4 Topfbänder (#{topfbaender(td['HK1_N_Tuer']).size})")
mp = td.values.flat_map { |x| x.ws.ops.select { |o| o.titel.include?('Montageplatte') } }
check(mp.size == 8 && mp.all? { |o| o.d == 5 && o.tiefe == 12 }, "Festtür: 8 Löcher Ø5 × 12 für die Montageplatten (#{mp.size})")

# Hochschrank Vorrat: Bänder auf den Höhen Scharnier_1..6 (im Fach mit Lochreihe ins Raster gerückt)
td, = tb_export('HV') { HochschrankVorrat.erstellen({}) }
hv_t = td['HV1_U_Tuer'].ws.ops.select { |o| o.art == :topfband }.map { |o| o.p0[2].round(1) }.sort
check(hv_t[0..2] == [229.5, 710.5, 951.0] && hv_t.size == 5, "Hochschrank Vorrat: Bänder #{hv_t}")

if $fehler.zero?
  puts 'test_export: alles OK'
else
  puts "test_export: #{$fehler} Fehler"
  exit 1
end
