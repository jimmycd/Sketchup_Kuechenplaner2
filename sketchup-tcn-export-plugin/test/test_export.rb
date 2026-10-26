# Test ohne SketchUp: TCN-Export des Korpus (Schritte 5 bis 7) an echten Schränken aus
# Komponenten/ (mit der Mock-API erzeugt), verglichen mit Jürgens Beispiel-TCN.
$LOAD_PATH.unshift(__dir__)
$HOCHSCHRANK_TEST = true
$OBERSCHRANK_TEST = true
$HOCHSCHRANK_GERAETE_TEST = true
require 'sketchup_mock'
require 'tmpdir'
komp = File.expand_path('../../Komponenten', __dir__)
load File.join(komp, 'hochschrank/hochschrank.rb')
load File.join(komp, 'oberschrank/oberschrank.rb')
load File.join(komp, 'hochschrank_geraete/hochschrank_geraete.rb')
load File.join(komp, 'unterschrank_schubladen/src/unterschrank_schubladen/main.rb')
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
[4, 6].each do |s|
  check(bearbeitungen(boden.text, s) == bearbeitungen(beispiel('Boden.tcn'), s), "Boden SIDE##{s}: #{bearbeitungen(boden.text, s)}")
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
check(boden_reihe&.include?('fittingy.tmcr') && boden_reihe.include?('#8510=30 #8511=y-30 #8512=150 #8513=-14') &&
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
end

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

if $fehler.zero?
  puts 'test_export: alles OK'
else
  puts "test_export: #{$fehler} Fehler"
  exit 1
end
