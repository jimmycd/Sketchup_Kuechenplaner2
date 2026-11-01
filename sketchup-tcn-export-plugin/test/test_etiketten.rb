# Test ohne SketchUp: Etiketten (Bogen und Endlos, Format, Startposition, Kantenbild,
# QR-Code, Dialog) an echten Schränken aus Komponenten/.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
require 'tmpdir'
komp = File.expand_path('../../Komponenten', __dir__)
load File.join(komp, 'hochschrank/src/hochschrank/main.rb')
load File.join(komp, 'unterschrank_schubladen/src/unterschrank_schubladen/main.rb')
load File.expand_path('../src/jt_schrank_cnc/main.rb', __dir__)

S = JTools::SchrankCnc
E = S::Etiketten
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

model = Sketchup.active_model = Sketchup::Model.new
Hochschrank.erstellen({})
UnterschrankSchubladen.erstellen({ 'Breite' => 90.0, 'Tiefe' => 56.0 })
zs, = S::Stueckliste.erzeugen(model)
stueck = zs.sum(&:anzahl)

# --- Standardformat: A4-Bogen 3 × 8 à 70 × 37 ---
f = E.format_lesen
check(f['etikett_art'] == 'Bogen' && f['etikett_breite'] == 70.0 && f['etikett_hoehe'] == 37.0 && E.je_bogen(f) == 24, "Standardformat: #{f}")
check(E.pruefen(f).empty?, "Standardformat passt auf A4: #{E.pruefen(f)}")
check(E.stuecke(zs).size == stueck, 'ein Etikett je Stück')

html = E.html(zs, f)
check(html.include?('@page{size:210mm 297mm;margin:0}'), 'Bogen: Seite A4 ohne Rand')
check(html.scan('<div class="etikett"').size == stueck, "Bogen: #{html.scan('<div class="etikett"').size} Etiketten statt #{stueck}")
check(html.scan('<div class="seite">').size == (stueck / 24.0).ceil, 'Bogen: Seitenzahl')
check(html.include?('style="left:0mm;top:0.5mm"') && html.include?('style="left:70mm;top:0.5mm"') && html.include?('style="left:140mm;top:37.5mm"'),
      'Bogen: Lage der Etiketten aus Rand, Größe und Spalten')
check(html.include?('<span class="tag">HS1_Boden</span>'), 'Tag auf dem Etikett')
bz = zs.find { |z| z.tag == 'HS1_Boden' }
check(html.include?("Nr #{bz.nr}</span>") && html.include?('Roh 808 × 572') && html.include?('Fertig 800 × 562') && html.include?('HS1_Boden.tcn'),
      'Boden: Nummer, Roh- und Fertigmaß, TCN-Datei')
check(!html.include?('qrcode'), 'ohne QR keine Bibliothek')

# Kantenbild: nur die Kanten mit Anleimer als dicke Linie (Boden: nur B1 links)
kb = E.kantenbild(bz, 20, 12)
check(kb.scan('<line').size == 1 && kb.include?('x1="0" y1="0" x2="0"'), "Kantenbild Boden: eine Linie links: #{kb}")
fr = zs.find { |z| z.kanten.values.compact.size == 4 }
check(E.kantenbild(fr, 20, 12).scan('<line').size == 4, 'Kantenbild Front: vier Linien')

# Anzahl > 1: 1/n … n/n
z2 = zs.first.dup
z2.anzahl = 3
h3 = E.html([z2], f)
check(h3.include?('· 1/3') && h3.include?('· 3/3') && h3.scan('<div class="etikett"').size == 3, 'Anzahl 3: drei Etiketten 1/3 … 3/3')

# Startposition auf angebrochenem Bogen: Etikett 5 = Spalte 2, Zeile 2
h5 = E.html([zs.first], f, start: 5)
check(h5.scan('<div class="etikett"').size == 1 && h5.include?('style="left:70mm;top:37.5mm"'), 'Start 5: erstes Etikett in Spalte 2, Zeile 2')
check(E.html(zs, f, start: 99).include?('<div class="etikett" style="left:140mm;top:259.5mm">'), 'Start größer als der Bogen: letztes Etikett des Bogens')

# Abstände und Rand
f2 = f.merge('etikett_rand_links' => 4.0, 'etikett_abstand_h' => 2.5, 'etikett_abstand_v' => 1.0)
check(E.html([zs.first, zs.last], f2).include?('style="left:76.5mm;top:0.5mm"'), 'Abstand waagrecht und Rand links')
check(!E.pruefen(f.merge('etikett_spalten' => 4)).empty?, 'zu breit für A4 wird gemeldet')
check(!E.pruefen(f.merge('etikett_hoehe' => 0.0)).empty?, 'Höhe 0 wird gemeldet')

# --- Endlos: je Etikett eine Seite in Etikettengröße ---
fe = f.merge('etikett_art' => 'Endlos', 'etikett_breite' => 62.0, 'etikett_hoehe' => 29.0, 'etikett_spalten' => 9)
check(E.pruefen(fe).empty?, 'Endlos: Spalten egal')
he = E.html(zs, fe)
check(he.include?('@page{size:62mm 29mm;margin:0}'), 'Endlos: Seite = Etikett')
check(he.scan('<div class="seite">').size == stueck && he.scan('style="left:0;top:0"').size == stueck, 'Endlos: eine Seite je Etikett')

# --- QR-Code ---
hq = E.html(zs, f.merge('etikett_qr' => 'ja'))
check(hq.include?(E::QR_JS) && hq.scan('class="qr" data-text=').size == stueck && hq.include?('data-text="HS1_Boden.tcn"'), 'QR-Code mit TCN-Dateiname')
check(hq.scan(/id="(qr\d+)"/).flatten.uniq.size == stueck, 'QR-Ids eindeutig')

# --- Dialog: Format speichern, Ordner, Druckseite öffnen ---
module UI
  class << self
    attr_accessor :antwort, :meldung, :ordner, :url
    def inputbox(*) = antwort
    def messagebox(m, *) = (self.meldung = m)
    def select_directory(**) = ordner
    def openURL(u) = (self.url = u)
  end
end
model.selection.clear
Dir.mktmpdir do |dir|
  UI.ordner = dir
  UI.antwort = ['Endlos', '62', '29', '1', '1', '0', '0', '0', '0', 'nein', '1']
  E.dialog(model)
  p = File.join(dir, 'Etiketten.html')
  check(File.exist?(p) && File.read(p).include?('@page{size:62mm 29mm'), 'Dialog schreibt Endlos-Etiketten')
  check(UI.url.to_s.end_with?('Etiketten.html'), 'Druckseite wird geöffnet')
  check(UI.meldung.to_s.start_with?("#{stueck} Etiketten"), "Meldung: #{UI.meldung}")
  check(E.format_lesen['etikett_art'] == 'Endlos' && E.format_lesen['etikett_breite'] == 62.0, 'Format wird gespeichert')
  # Komma erlaubt, Start 3
  UI.antwort = ['Bogen', '70', '37', '3', '8', '0,5', '0', '0', '0', 'nein', '3']
  E.dialog(model)
  check(File.read(p).include?('style="left:140mm;top:0.5mm"'), 'Dialog: Start 3 = oben rechts')
  # ungültig: nichts gespeichert
  UI.meldung = nil
  UI.antwort = ['Bogen', 'x', '37', '3', '8', '0', '0', '0', '0', 'nein', '1']
  E.dialog(model)
  check(UI.meldung.to_s.include?('nur Zahlen') && E.format_lesen['etikett_breite'] == 70.0, 'ungültige Eingabe: Hinweis, Format bleibt')
  UI.antwort = ['Bogen', '80', '37', '3', '8', '0', '0', '0', '0', 'nein', '1']
  E.dialog(model)
  check(UI.meldung.to_s.include?('passen nicht auf A4'), 'zu großer Bogen: Hinweis')
end
UI.antwort = nil
UI.meldung = nil
E.dialog(model)
check(UI.meldung.nil?, 'Abbrechen schreibt nichts')
E.dialog(Sketchup::Model.new)
check(UI.meldung.to_s.start_with?('Keine Schrankteile'), 'leeres Modell: Hinweis')

puts $fehler.zero? ? 'OK: Etiketten' : "#{$fehler} Fehler"
exit($fehler.zero? ? 0 : 1)
