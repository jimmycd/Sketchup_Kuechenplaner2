# Test ohne SketchUp: Stückliste (Roh-, Fräs-, Fertigmaß, Kanten, CSV, PDF) und
# die allgemeinen Einstellungen (Übermaß) an echten Schränken aus Komponenten/.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
require 'pdf_helfer'
require 'tmpdir'
komp = File.expand_path('../../Komponenten', __dir__)
load File.join(komp, 'hochschrank/src/hochschrank/main.rb')
load File.join(komp, 'unterschrank_schubladen/src/unterschrank_schubladen/main.rb')
load File.expand_path('../src/jt_schrank_cnc/main.rb', __dir__)

S = JTools::SchrankCnc
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

model = Sketchup.active_model = Sketchup::Model.new
Hochschrank.erstellen({})
UnterschrankSchubladen.erstellen({ 'Breite' => 90.0, 'Tiefe' => 56.0 })
dateien, = S::Export.erzeugen(model)
zs, meldungen = S::Stueckliste.erzeugen(model)

# --- eine Zeile je TCN-Datei, gleiche Anzahl Teile, laufende Nummer ---
check(zs.size == dateien.size, "eine Zeile je TCN (#{zs.size}/#{dateien.size})")
check(zs.sum(&:anzahl) == dateien.sum(&:anzahl), 'Stückzahl wie im TCN-Export')
check(zs.map(&:nr) == (1..zs.size).to_a, 'Nummern 1 … n')
check(zs.map(&:datei).sort == dateien.map(&:datei).sort, 'TCN-Dateinamen wie im Export')
check(meldungen.empty?, "keine Meldungen: #{meldungen}")

# --- Maße: Boden des Hochschranks (60 breit, 82 tief), Anleimer nur vorn an der
# kurzen Seite (Fräsmaß 798 × 562 wie im TCN-Export) ---
z = zs.find { |x| x.tag == 'HS1_Boden' }
check(z, 'Boden in der Stückliste')
if z
  check(z.fraes.map { |v| v.round(3) } == [798, 562], "Boden Fräsmaß: #{z.fraes}")
  check(z.fertig.map { |v| v.round(3) } == [800, 562], "Boden Fertigmaß = Fräsmaß + 2 mm Anleimer vorn: #{z.fertig}")
  check(z.roh.map { |v| v.round(3) } == [808, 572], "Boden Rohmaß = Fräsmaß + 10/10 mm Übermaß: #{z.roh}")
  check(z.ds == 19 && z.material == 'Melamin weiss', "Boden Stärke/Material: #{z.ds} #{z.material}")
  k = z.kanten
  check(k == { l1: nil, l2: nil, b1: 'Anleimer Melamin weiss', b2: nil }, "Boden: nur die vordere Querkante mit Anleimer: #{k}")
  check(z.kantenlaenge(:l1) == z.fertig[0] && z.kantenlaenge(:b2) == z.fertig[1], 'Kantenlänge L = Länge, B = Breite')
end
# Länge immer die längere Seite, Roh ≥ Fräs ≤ Fertig
check(zs.all? { |x| x.fertig[0] >= x.fertig[1] - 1e-6 && x.roh[0] >= x.fraes[0] && x.fertig[0] >= x.fraes[0] - 1e-6 }, 'L = längere Seite, Roh ≥ Fräs, Fertig ≥ Fräs')
# Front mit Anleimer ringsum: Fräsmaß 4 mm kleiner als Fertigmaß
fr = zs.find { |x| x.kanten.values.compact.size == 4 }
check(fr && (fr.fertig[0] - fr.fraes[0]).round(3) == 4 && (fr.fertig[1] - fr.fraes[1]).round(3) == 4, "Teil mit 4 Kanten: Fertig − Fräs = 4 mm (#{fr && fr.tag})")

# --- Übermaß aus den Einstellungen, nicht aus OCL am Material ---
S::Einstellungen.setzen('uebermass_laenge', 20)
S::Einstellungen.setzen('uebermass_breite', 6)
z2 = S::Stueckliste.erzeugen(model)[0].find { |x| x.tag == 'HS1_Boden' }
check(z2 && z2.roh.map { |v| v.round(3) } == [818, 568], "Übermaß 20/6: #{z2 && z2.roh}")
S::Einstellungen.setzen('uebermass_laenge', 10)
S::Einstellungen.setzen('uebermass_breite', 10)

# Einstellungen-Dialog: Zahlen mit Komma, ungültige Eingabe ändert nichts
module UI
  class << self
    attr_accessor :antwort, :meldung, :ordner, :url
    def inputbox(*) = antwort
    def messagebox(m, *) = (self.meldung = m)
    def select_directory(**) = ordner
    attr_accessor :speichern, :speichern_args
    def savepanel(*a) = (self.speichern_args = a; speichern)
    def openURL(u) = (self.url = u)
  end
end
UI.antwort = %w[120 20 600 38 720] + ['Blum LEGRABOX free', 'Blum CLIP top Topfband Ø35', 'Blum CLIP top 155° (0-Einsprung) Ø35', 'Blum MODUL Kühlschrank-Schlepptürscharnier', 'Blum Eckschrank-Falttürscharnier CLIP top', 'Häfele Free Slim flap 1.12', 'Blum AVENTOS HF top', 'Häfele UTENSIO Matrix HU Slim Base', 'Kesseböhmer LeMans II', 'Griffe (keine Öffnungshilfe)', 'Häfele AXILO 78, Befestigungsplatte zum Schrauben', 'keine (Griffe von Hand)', 'schwarz matt', '12,5', '8', '3', '10']
check(S::Einstellungen.dialog && S::Einstellungen.uebermass_laenge == 12.5 && S::Einstellungen.uebermass_breite == 8, 'Einstellungen-Dialog speichert (Komma erlaubt)')
KE = Kuechenplaner::Einstellungen
check(KE.sockelhoehe == 120 && KE.wandabstand == 20 && KE.abstand_oberschrank == 600 && KE.arbeitsplatte_staerke == 38 &&
      KE.unterschrank_hoehe == 720, 'Einstellungen-Dialog speichert auch Sockel und Abstände der Küche')
check(S::Beschlagkatalog.gewaehlt('klappe')['kennung'] == 'haefele-free-slim-1.12', 'Einstellungen-Dialog speichert die Klappe der Küche')
check(Sketchup.active_model.get_attribute('Kuechenplaner_Einstellungen', 'beschlag_klappe') == 'haefele-free-slim-1.12', 'Klappe im Modell gespeichert')
check(KE.oberschrank_unterkante == 120 + 720 + 38 + 600, "Unterkante Oberschrank = Sockel + Korpus + Platte + Abstand (#{KE.oberschrank_unterkante})")
UI.antwort = %w[120 20 600 38 720] + ['Blum LEGRABOX free', 'Blum CLIP top Topfband Ø35', 'Blum CLIP top 155° (0-Einsprung) Ø35', 'Blum MODUL Kühlschrank-Schlepptürscharnier', 'Blum Eckschrank-Falttürscharnier CLIP top', 'Blum AVENTOS HK-top', 'Blum AVENTOS HF top', 'Häfele UTENSIO Matrix HU Slim Base', 'Kesseböhmer LeMans II', 'Griffe (keine Öffnungshilfe)', 'Häfele AXILO 78, Befestigungsplatte zum Schrauben', 'keine (Griffe von Hand)', 'schwarz matt', 'x', '8', '3', '10']
check(!S::Einstellungen.dialog && S::Einstellungen.uebermass_laenge == 12.5 && S::Beschlagkatalog.gewaehlt('klappe')['kennung'] == 'haefele-free-slim-1.12', 'ungültige Eingabe ändert nichts')
UI.antwort = %w[120 20 600 38 720] + ['Blum LEGRABOX free', 'Blum CLIP top Topfband Ø35', 'Blum CLIP top 155° (0-Einsprung) Ø35', 'Blum MODUL Kühlschrank-Schlepptürscharnier', 'Blum Eckschrank-Falttürscharnier CLIP top', 'Unbekannt', 'Blum AVENTOS HF top', 'Häfele UTENSIO Matrix HU Slim Base', 'Kesseböhmer LeMans II', 'Griffe (keine Öffnungshilfe)', 'Häfele AXILO 78, Befestigungsplatte zum Schrauben', 'keine (Griffe von Hand)', 'schwarz matt', '12,5', '8', '3', '10']
check(!S::Einstellungen.dialog && UI.meldung.to_s.include?('Liste'), "unbekannter Beschlag abgelehnt (#{UI.meldung})")
UI.antwort = %w[400 0 550 40 700] + ['Blum LEGRABOX free', 'Blum CLIP top Topfband Ø35', 'Blum CLIP top 155° (0-Einsprung) Ø35', 'Blum MODUL Kühlschrank-Schlepptürscharnier', 'Blum Eckschrank-Falttürscharnier CLIP top', 'Blum AVENTOS HK-top', 'Blum AVENTOS HF top', 'Häfele UTENSIO Matrix HU Slim Base', 'Kesseböhmer LeMans II', 'Griffe (keine Öffnungshilfe)', 'Häfele AXILO 78, Befestigungsplatte zum Schrauben', 'keine (Griffe von Hand)', 'schwarz matt', '10', '10', '3', '10']
check(!S::Einstellungen.dialog && KE.sockelhoehe == 120 && S::Einstellungen.uebermass_laenge == 12.5 && UI.meldung.to_s.include?('0–300'),
      "Sockelhöhe über 300 mm abgelehnt, nichts gespeichert (#{UI.meldung})")
%w[sockelhoehe wandabstand abstand_oberschrank arbeitsplatte_staerke unterschrank_hoehe].each { |k| KE.setzen(k, KE::WERTE[k][1]) }
S::Beschlagkatalog.waehlen('klappe', 'blum-aventos-hk-top')
UI.antwort = nil
check(!S::Einstellungen.dialog, 'Abbrechen ändert nichts')
S::Einstellungen.setzen('uebermass_laenge', 10)
S::Einstellungen.setzen('uebermass_breite', 10)
check(S::Einstellungen.uebermass(100, 500) == [10, 10] && S::Einstellungen.uebermass(500, 100) == [10, 10], 'Übermaß je Richtung')

# --- Sortierung: nach Material, dann Stärke, große Teile zuerst ---
gr = S::Stueckliste.gruppen(zs)
check(gr.map { |g| [g[:material], -g[:ds]] } == gr.map { |g| [g[:material], -g[:ds]] }.sort, 'Gruppen nach Material und Stärke')
check(gr.all? { |g| g[:stueck] == g[:zeilen].sum(&:anzahl) && g[:flaeche] > 0 }, 'Gruppensummen')
mel = gr.find { |g| g[:material] == 'Melamin weiss' && g[:ds] == 19 }
check(mel && mel[:kanten_lfm].values.sum > 0, 'Anleimer-Laufmeter je Kantenmaterial')

# --- CSV ---
csv = S::Stueckliste.csv(zs)
zeilen = csv.split("\r\n")
check(zeilen.first == 'Nr;Tag;TCN-Datei;Anzahl;Schrank;Teil;Rolle;Material;Stärke;Roh L;Roh B;Fräs L;Fräs B;Fertig L;Fertig B;Kante L1;Kante L2;Kante B1;Kante B2;Maserung;Kante Kontur', "CSV-Kopf: #{zeilen.first}")
check(zeilen.size == zs.size + 1 && zeilen.all? { |l| l.count(';') == 20 }, 'CSV: eine Zeile je Teil, 21 Spalten')
bz = zeilen.find { |l| l.split(';')[1] == 'HS1_Boden' }.to_s.split(';')
check(bz[2] == "#{bz[0]}_HS1_Boden.tcn" && bz[8] == '19' && bz[9, 6] == %w[808 572 798 562 800 562] && bz[15, 5] == ['', '', 'Anleimer Melamin weiss', '', 'nein'] && bz[20].nil?, "CSV Boden: #{bz}")
check(S::Stueckliste.zahl(12.25) == '12,3' || S::Stueckliste.zahl(12.25) == '12,2', 'Dezimalkomma')
check(S::Stueckliste.zahl(564.0) == '564', 'ganze Zahl ohne Komma')

# --- PDF ---
doc = S::Stueckliste.pdf(zs, titel: 'Stückliste Test', meldungen: ['A<B'])
pdf = doc.to_s
texte = PdfHelfer.texte(pdf)
check(PdfHelfer.gueltig?(pdf), 'gültiges PDF (xref)')
check(PdfHelfer.formate(pdf).uniq == [[297.0, 210.0]], "A4 quer: #{PdfHelfer.formate(pdf).uniq}")
check(texte.first == 'Stückliste Test', "Titel mit Umlaut: #{texte.first}")
check(texte.include?('Melamin weiss – 19 mm'), 'Gruppe Melamin weiss 19 mm')
check(texte.include?('A<B'), 'Hinweise im Kopf')
check(texte.any? { |t| t.start_with?('Anleimer: A = ') }, 'Legende der Anleimer')
%w[Nr Tag Schrank Teil Anz. Fräsmaß Fertigmaß L1 L2 B1 B2 TCN-Datei].each { |k| check(texte.include?(k), "Spaltenkopf #{k}") }
check(zs.all? { |x| texte.include?(x.tag) }, 'jeder Tag in der Tabelle')
check(zs.all? { |x| texte.include?(x.datei) }, 'jede TCN-Datei in der Tabelle')
bt = texte.index('HS1_Boden')
check(bt && texte[bt + 4] == '808 × 572' && texte[bt + 5] == '798 × 562' && texte[bt + 6] == '800 × 562', "Boden Roh/Fräs/Fertig: #{bt && texte[bt, 8]}")
check(pdf.b.scan(/\/F(\d) [\d.]+ Tf [^(]*\(808 \xD7 572\) Tj/n).flatten.uniq == ['2'], 'Rohmaß fett')
check(S::Stueckliste::SPALTEN.sum { |c| c[1] } == 277, 'Spalten füllen A4 quer')
gr.each { |g| check(texte.any? { |t| t.start_with?("#{g[:stueck]} Teile, Rohfläche") }, "Summenzeile #{g[:material]} #{g[:ds]}") }
n = PdfHelfer.seiten(pdf)
check(texte.include?("Seite 1 von #{n}") && texte.include?("Seite #{n} von #{n}"), "Seitenfuß Seite x von #{n}")

# viele Teile: Tabelle läuft über mehrere Seiten, Kopf wiederholt, keine Zeile verloren
viele = (1..120).map { |i| zs.first.dup.tap { |x| x.nr = i; x.tag = "T#{i}" } }
pv = S::Stueckliste.pdf(viele).to_s
tv = PdfHelfer.texte(pv)
sv = PdfHelfer.seiten(pv)
check(sv >= 3 && PdfHelfer.gueltig?(pv), "120 Zeilen: mehrere Seiten (#{sv})")
check((1..120).all? { |i| tv.count("T#{i}") == 1 }, '120 Zeilen: jede genau einmal')
check(tv.count('Rohmaß L × B') == sv, 'Spaltenkopf auf jeder Seite')
check(tv.count { |t| t.end_with?('(Fortsetzung)') } == sv - 1, 'Fortsetzung auf Folgeseiten')
(0...sv).each { |i| check(PdfHelfer.texte(pv, i).include?("Seite #{i + 1} von #{sv}"), "Fuß Seite #{i + 1}") }
# Zeilen liegen über dem Fuß (y in pt von unten: Fuß bei 205 mm, Tabelle bis 198 mm)
ys = pv.scan(/1 0 0 1 [\d.]+ ([\d.]+) Tm/).flatten.map { |v| 210 - v.to_f * 25.4 / 72 }
check(ys.all? { |v| v <= 198 || (v - 205).abs < 0.01 }, 'nichts im Fußbereich außer dem Fuß')
check(S::Stueckliste.dateiname(Sketchup::Model.new) == 'Stueckliste.pdf', 'Dateiname ohne Modell')

# --- Schreiben über den Export-Dialog (Stückliste gewählt, Zielordner) ---
module UI
  class << self
    attr_accessor :antworten
    def inputbox(*) = (antworten || []).shift
  end
end
model.define_singleton_method(:title) { 'Kueche Meier' }
Dir.mktmpdir do |dir|
  UI.antworten = [%w[ja nein nein nein] + [dir]]
  S::Ausgabe.dialog(model)
  pp = File.join(dir, 'Stueckliste_Kueche Meier.pdf')
  check(File.exist?(pp) && File.exist?(File.join(dir, 'Stueckliste_Kueche Meier.csv')), "Dialog schreibt PDF und CSV in den Zielordner: #{Dir.children(dir)}")
  check(PdfHelfer.gueltig?(File.binread(pp)) && PdfHelfer.texte(File.binread(pp)).first == 'Stückliste Kueche Meier', 'PDF mit Titel aus dem Modell')
  check(Dir.children(dir).none? { |f| f.end_with?('.html') || f == 'tcn' || f == 'Teileliste.csv' }, "nur die Stückliste gewählt: kein HTML, keine TCN, keine Teileliste (#{Dir.children(dir)})")
  check(File.binread(File.join(dir, 'Stueckliste_Kueche Meier.csv')).force_encoding('Windows-1252').encode('UTF-8').include?('Fräs L'), 'CSV in Windows-1252 (Excel)')
  check(UI.url.to_s.start_with?('file:///') && UI.url.to_s.include?(File.basename(dir)), "Zielordner wird geöffnet: #{UI.url}")
  check(UI.meldung.to_s.start_with?('Export') && UI.meldung.include?('Stückliste ('), "Meldung: #{UI.meldung}")
  # Schreiben scheitert (z. B. PDF noch im Leser offen): Meldung statt Absturz
  File.write(File.join(dir, 'datei'), '')
  UI.antworten = [%w[ja nein nein nein] + [File.join(dir, 'datei', 'unter')]]
  S::Ausgabe.dialog(model)
  check(UI.meldung.to_s.include?('konnte nicht geschrieben'), "Fehler beim Schreiben: #{UI.meldung}")
end
model.singleton_class.send(:remove_method, :title)
UI.antworten = []
UI.meldung = nil
S::Ausgabe.dialog(model)
check(UI.meldung.nil?, 'Abbrechen im Dialog schreibt nichts')
S::Ausgabe.dialog(Sketchup::Model.new)
check(UI.meldung.to_s.start_with?('Keine Schrankteile'), 'leeres Modell: Hinweis')

# --- Beschlagliste (LEGRABOX free, Topfbänder): eigene Seite in der Stückliste ---
bm = Sketchup.active_model = Sketchup::Model.new
UnterschrankSchubladen.erstellen({ 'Breite' => 60.0, 'Tiefe' => 52.0, 'Anz_Schubladen' => 3,
                                   'Anteil_1' => 1.0, 'Anteil_2' => 1.0, 'Anteil_3' => 2.0 })
Hochschrank.erstellen({})
bzs, bmeld, bp = S::Stueckliste.erzeugen(bm)
such = ->(text, hinweis = nil) { bp.select { |x| x.beschlag.start_with?(text) && (hinweis.nil? || x.hinweis.include?(hinweis)) } }
# höchste Zarge, die passt: USS1 Fronten 174/174/348 -> oben M (30 mm unter der Front), Mitte K, unten C (F nur bei LEGRABOX pure);
# NL 500 bei 520 Tiefe (40 kg, hinten 224/256). HS1: drei Schubladen C, K, K (NL 650)
check(such.('Zargen F').empty? && such.('Zargen C', 'NL 500').sum(&:anzahl) == 1 && such.('Zargen K', 'NL 500').sum(&:anzahl) == 1 &&
      such.('Zargen M', 'NL 500').sum(&:anzahl) == 1 && such.('Zargen C', 'NL 650').sum(&:anzahl) == 1 &&
      such.('Zargen K', 'NL 650').sum(&:anzahl) == 2 && such.('Zargen N').empty?,
      "Beschläge: Zargen C/K/M je Schublade #{such.('Zargen').map { |x| [x.beschlag, x.hinweis, x.anzahl] }}")
check(such.('Korpusschienen', 'NL 500, 40 kg').sum(&:anzahl) == 3, 'Beschläge: Korpusschienen NL 500 (USS1)')
check(such.('Korpusschienen', 'NL 650, 70 kg').sum(&:anzahl) == 3, 'Beschläge: Korpusschienen NL 650 70 kg (Hochschrank)')
check(such.('Seiteneinsatz').sum(&:anzahl) == 4 && such.('Seiteneinsatz', '138 × 538').sum(&:anzahl) == 2 &&
      such.('Seiteneinsatz', '138 × 388').sum(&:anzahl) == 2,
      "Beschläge: seitliches Einschubelement nur bei Zarge C (Katalog: 138 × NL − 112) #{such.('Seiteneinsatz').map { |x| [x.hinweis, x.anzahl] }}")
check(such.('Seitenstabilisierung').sum(&:anzahl) == 6, 'Beschläge: Seitenstabilisierung ab Korpusbreite 600')
check(such.('Spanplattenschraube', 'Fronthalter').sum(&:anzahl) == 8 + 8 + 4 * 4, 'Beschläge: Schrauben Fronthalter (C 8, K/M 4)')
# Schienen-Systemschrauben = Bohrungen in den Seiten
bws = []
S::Export.erzeugen(bm, alle_ws: bws)
loecher = bws.sum { |w| w.ops.count { |o| o.titel.to_s.start_with?('Schiene') } }
check(such.('Systemschraube', 'Korpusschienen').sum(&:anzahl) == loecher, "Beschläge: Systemschrauben = Schienenbohrungen (#{loecher})")
baender = bws.sum { |w| w.ops.count { |o| o.art == :topfband } }
check(baender.positive? && such.('Blum Topfband').sum(&:anzahl) == baender && such.('Blum Montageplatte').sum(&:anzahl) == baender,
      "Beschläge: Topfbänder und Montageplatten wie im TCN-Export (#{baender})")
check(bp.all? { |x| x.schraenke.all? { |k| %w[USS1 HS1].include?(k) } }, 'Beschläge: Schrankkürzel')
Dir.mktmpdir do |dir|
  pfad, = S::Stueckliste.schreiben(File.join(dir, 'Stueckliste_B.pdf'), bzs, bmeld, beschlaege: bp)
  check(File.binread(pfad).include?('Beschl') && File.exist?(File.join(dir, 'Stueckliste_B_Beschlaege.csv')),
        'Beschlagliste im PDF und als CSV')
  csv = File.read(File.join(dir, 'Stueckliste_B_Beschlaege.csv'))
  check(csv.lines.first.start_with?('Gruppe;Beschlag') && csv.lines.size == bp.size + 1, 'Beschlag-CSV: eine Zeile je Posten')
end
Sketchup.active_model = model

puts $fehler.zero? ? 'OK: Stückliste' : "#{$fehler} Fehler"
exit($fehler.zero? ? 0 : 1)
