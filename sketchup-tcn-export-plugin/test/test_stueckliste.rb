# Test ohne SketchUp: Stückliste (Roh-, Fräs-, Fertigmaß, Kanten, CSV, Druckseite) und
# die allgemeinen Einstellungen (Übermaß) an echten Schränken aus Komponenten/.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
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
check(zs.map(&:datei).sort == dateien.map { |d| "#{d.name}.tcn" }.sort, 'TCN-Dateinamen wie im Export')
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
    def openURL(u) = (self.url = u)
  end
end
UI.antwort = %w[120 20 600 38 720] + ['12,5', '8', '3', '10']
check(S::Einstellungen.dialog && S::Einstellungen.uebermass_laenge == 12.5 && S::Einstellungen.uebermass_breite == 8, 'Einstellungen-Dialog speichert (Komma erlaubt)')
KE = Kuechenplaner::Einstellungen
check(KE.sockelhoehe == 120 && KE.wandabstand == 20 && KE.abstand_oberschrank == 600 && KE.arbeitsplatte_staerke == 38 &&
      KE.unterschrank_hoehe == 720, 'Einstellungen-Dialog speichert auch Sockel und Abstände der Küche')
check(KE.oberschrank_unterkante == 120 + 720 + 38 + 600, "Unterkante Oberschrank = Sockel + Korpus + Platte + Abstand (#{KE.oberschrank_unterkante})")
UI.antwort = %w[120 20 600 38 720] + ['x', '8', '3', '10']
check(!S::Einstellungen.dialog && S::Einstellungen.uebermass_laenge == 12.5, 'ungültige Eingabe ändert nichts')
UI.antwort = %w[400 0 550 40 700] + ['10', '10', '3', '10']
check(!S::Einstellungen.dialog && KE.sockelhoehe == 120 && S::Einstellungen.uebermass_laenge == 12.5 && UI.meldung.to_s.include?('0–300'),
      "Sockelhöhe über 300 mm abgelehnt, nichts gespeichert (#{UI.meldung})")
%w[sockelhoehe wandabstand abstand_oberschrank arbeitsplatte_staerke unterschrank_hoehe].each { |k| KE.setzen(k, KE::WERTE[k][1]) }
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
check(bz[2] == 'HS1_Boden.tcn' && bz[8] == '19' && bz[9, 6] == %w[808 572 798 562 800 562] && bz[15, 5] == ['', '', 'Anleimer Melamin weiss', '', 'nein'] && bz[20].nil?, "CSV Boden: #{bz}")
check(S::Stueckliste.zahl(12.25) == '12,3' || S::Stueckliste.zahl(12.25) == '12,2', 'Dezimalkomma')
check(S::Stueckliste.zahl(564.0) == '564', 'ganze Zahl ohne Komma')

# --- Druckseite ---
html = S::Stueckliste.html(zs, titel: 'Stückliste Test', meldungen: ['A<B'])
check(html.start_with?('<!DOCTYPE html>') && html.include?('<meta charset="utf-8">'), 'HTML-Kopf')
check(html.include?('@page{size:A4 landscape'), 'Druck A4 quer')
check(html.include?('<h2>Melamin weiss – 19 mm</h2>'), 'Gruppe Melamin weiss 19 mm')
check(html.include?('A&lt;B') && !html.include?('A<B'), 'Meldungen escaped')
check(html.include?('<b>A</b> = '), 'Legende der Anleimer')
check(html.scan('<tr><td class="z">').size == zs.size, 'eine Tabellenzeile je Teil')

# --- Schreiben und Dialog ---
Dir.mktmpdir do |dir|
  UI.ordner = dir
  S::Stueckliste.dialog(model)
  check(File.exist?(File.join(dir, 'Stueckliste.csv')) && File.exist?(File.join(dir, 'Stueckliste.html')), 'Dialog schreibt CSV und HTML')
  check(File.binread(File.join(dir, 'Stueckliste.csv')).force_encoding('Windows-1252').encode('UTF-8').include?('Fräs L'), 'CSV in Windows-1252 (Excel)')
  check(UI.url.to_s.start_with?('file:///') && UI.url.end_with?('Stueckliste.html'), "Druckseite wird geöffnet: #{UI.url}")
  check(UI.meldung.to_s.start_with?('Stückliste mit'), "Meldung: #{UI.meldung}")
end
UI.ordner = nil
UI.meldung = nil
S::Stueckliste.dialog(model)
check(UI.meldung.nil?, 'Abbrechen bei der Ordnerwahl schreibt nichts')
S::Stueckliste.dialog(Sketchup::Model.new)
check(UI.meldung.to_s.start_with?('Keine Schrankteile'), 'leeres Modell: Hinweis')

puts $fehler.zero? ? 'OK: Stückliste' : "#{$fehler} Fehler"
exit($fehler.zero? ? 0 : 1)
