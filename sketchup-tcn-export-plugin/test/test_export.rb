# Test ohne SketchUp: TCN-Export des Korpus (Schritt 5) an echten Schränken aus
# Komponenten/ (mit der Mock-API erzeugt), verglichen mit Jürgens Beispiel-TCN.
$LOAD_PATH.unshift(__dir__)
$HOCHSCHRANK_TEST = true
$OBERSCHRANK_TEST = true
require 'sketchup_mock'
require 'tmpdir'
komp = File.expand_path('../../Komponenten', __dir__)
load File.join(komp, 'hochschrank/hochschrank.rb')
load File.join(komp, 'oberschrank/oberschrank.rb')
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
check(bearbeitungen(boden.text, 1) == bearbeitungen(beispiel('Boden.tcn'), 1).first(1), 'Boden SIDE#1: nur squad (Lochreihen kommen in Schritt 6)')

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
check(boden_reihe&.include?('fittingy.tmcr') && boden_reihe.include?('#8510=30 #8511=y-30 #8512=150 #8513=-12') &&
      boden_reihe.include?('#8522=8 '), "Seite: Dübel Boden bei 9.5 (ohne Anleimer unten): #{boden_reihe}")
vorlage = bearbeitungen(beispiel('Seite.tcn'), 1)
hinten = vorlage.select { |x| x.include?('y-80') || x.include?('#2=y-50') }.map { |x| x.gsub('x-7.5', 'x-9.5').sub('#8508=0 #8509=0', '#8508=1 #8509=1') }
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

check(S::Export.dateiname('HS1 U1/Front') == 'HS1_U1_Front', 'Dateiname ohne Sonderzeichen')

# --- Hochschrank: Zwischenböden ---
model = Sketchup.active_model = Sketchup::Model.new
Hochschrank.erstellen({})
dateien, = S::Export.erzeugen(model)
z = bearbeitungen(dateien.find { |x| x.name == 'HS1_SeiteL' }.text, 1)
check(z.count { |x| x.include?('fittingy.tmcr') && x.include?('#8522=8 ') } == 4, "Hochschrank Seite: 4 Dübelreihen (Boden, 2 Zwischenböden, Deckel): #{z.size - 1}")
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
a, b = %w[HS1_SeiteL HS1_SeiteR].map { |n| dateien.find { |x| x.name == n } }
alt = b.ws.teil.inst.layer
b.ws.teil.inst.layer = a.ws.teil.inst.layer
check(S::Export.erzeugen(model)[0].find { |x| x.name == 'HS1_SeiteL' }.anzahl == 2, 'gleicher Tag, gleiche TCN: Anzahl 2')
b.ws.teil.inst.layer = alt
a, b = %w[HS1_SeiteL HS1_Boden].map { |n| dateien.find { |x| x.name == n } }
alt = b.ws.teil.inst.layer
b.ws.teil.inst.layer = a.ws.teil.inst.layer
dateien3, = S::Export.erzeugen(model)
check(dateien3.any? { |x| x.name == "#{S::Export.dateiname(a.name)}_2" }, 'gleicher Tag, andere TCN: Endung _2')
b.ws.teil.inst.layer = alt

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
