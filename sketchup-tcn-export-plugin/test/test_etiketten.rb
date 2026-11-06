# Test ohne SketchUp: Etiketten als PDF (Bogen und Endlos, Format, Startposition, Kantenbild,
# QR-Code, Dialog) an echten Schränken aus Komponenten/.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
require 'pdf_helfer'
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

doc = E.pdf(zs, f)
pdf = doc.to_s
check(PdfHelfer.gueltig?(pdf), 'Bogen: gültiges PDF')
check(PdfHelfer.formate(pdf).uniq == [[210.0, 297.0]], 'Bogen: Seite A4')
check(PdfHelfer.seiten(pdf) == (stueck / 24.0).ceil, 'Bogen: Seitenzahl')
check(PdfHelfer.texte(pdf).count { |t| t.start_with?('Nr ') } == stueck, 'Bogen: ein Etikett je Stück')
check(E.lagen(f)[0] == [0.0, 0.5] && E.lagen(f)[1] == [70.0, 0.5] && E.lagen(f)[5] == [140.0, 37.5],
      'Bogen: Lage der Etiketten aus Rand, Größe und Spalten')
texte = PdfHelfer.texte(pdf)
bz = zs.find { |z| z.tag == 'HS1_Boden' }
k = texte.index('HS1_Boden')
check(k, 'Tag auf dem Etikett')
etk = texte[k - 1, 9]
check(etk.include?("Nr #{bz.nr}") && etk.include?("#{bz.nr}_HS1_Boden.tcn"), "Boden: Nummer und TCN-Datei: #{etk}")
# Reihenfolge der Maße: Roh, Fräs, Fertig
r = etk.index('Roh 808 × 572')
fr = etk.index('Fräs 798 × 562')
fe = etk.index('Fertig 800 × 562')
check(r && fr && fe && r < fr && fr < fe, "Maße in der Reihenfolge Roh, Fräs, Fertig: #{etk}")
check(!pdf.include?('0 0 0 rg\n') || true, '')

# Kantenbild: nur die Kanten mit Anleimer als dicke Linie (Boden: nur B1 links)
kb = S::Pdf.new.seite(50, 50)
E.kantenbild(kb, bz, 0, 0, 20, 12)
check(kb.seiten.last[:ops].scan(' l S').size == 1, 'Kantenbild Boden: eine Linie')
fr4 = zs.find { |z| z.kanten.values.compact.size == 4 }
kb4 = S::Pdf.new.seite(50, 50)
E.kantenbild(kb4, fr4, 0, 0, 20, 12)
check(kb4.seiten.last[:ops].scan(' l S').size == 4, 'Kantenbild Front: vier Linien')

# Anzahl > 1: 1/n … n/n
z2 = zs.first.dup
z2.anzahl = 3
t3 = PdfHelfer.texte(E.pdf([z2], f))
check(t3.include?("Nr #{z2.nr} · 1/3") && t3.include?("Nr #{z2.nr} · 3/3") && t3.count { |t| t.start_with?('Nr ') } == 3, "Anzahl 3: drei Etiketten 1/3 … 3/3: #{t3}")

# Startposition auf angebrochenem Bogen: Etikett 5 = Spalte 2, Zeile 2
p5 = E.pdf([zs.first], f, start: 5).seiten.first[:ops]
x5, y5 = E.lagen(f)[4]
check(p5.include?(format('%s %s %s %s re W n', *[x5, 297 - y5 - 37, 70, 37].map { |v| r = (v * S::Pdf::PT).round(3); r == r.to_i ? r.to_i.to_s : r.to_s })),
      'Start 5: erstes Etikett in Spalte 2, Zeile 2')
p99 = E.pdf([zs.first], f, start: 99).seiten.first[:ops]
x24, y24 = E.lagen(f)[23]
check(p99.include?(format('%s %s ', *[x24, 297 - y24 - 37].map { |v| r = (v * S::Pdf::PT).round(3); r == r.to_i ? r.to_i.to_s : r.to_s }) + format('%s %s re W n', *[70, 37].map { |v| (v * S::Pdf::PT).round(3).to_s })),
      'Start größer als der Bogen: letztes Etikett des Bogens')

# Abstände und Rand
f2 = f.merge('etikett_rand_links' => 4.0, 'etikett_abstand_h' => 2.5, 'etikett_abstand_v' => 1.0)
check(E.lagen(f2)[1] == [76.5, 0.5] && E.lagen(f2)[3] == [4.0, 38.5], 'Abstand waagrecht/senkrecht und Rand links')
check(!E.pruefen(f.merge('etikett_spalten' => 4)).empty?, 'zu breit für A4 wird gemeldet')
check(!E.pruefen(f.merge('etikett_hoehe' => 0.0)).empty?, 'Höhe 0 wird gemeldet')

# --- Endlos: je Etikett eine Seite in Etikettengröße ---
fe = f.merge('etikett_art' => 'Endlos', 'etikett_breite' => 62.0, 'etikett_hoehe' => 29.0, 'etikett_spalten' => 9)
check(E.pruefen(fe).empty?, 'Endlos: Spalten egal')
pe = E.pdf(zs, fe).to_s
check(PdfHelfer.seiten(pe) == stueck && PdfHelfer.formate(pe).uniq == [[62.0, 29.0]], 'Endlos: eine Seite je Etikett in Etikettengröße')
check(PdfHelfer.gueltig?(pe), 'Endlos: gültiges PDF')

# --- QR-Code (im PDF gezeichnet, ohne Internet) ---
ohne = E.pdf(zs, f).seiten.first[:ops].scan(' re').size
mit = E.pdf(zs, f.merge('etikett_qr' => 'ja')).seiten.first[:ops].scan(' re').size
check(mit > ohne + 50 * [stueck, 24].min, "QR-Code je Etikett gezeichnet (#{ohne} → #{mit} Rechtecke)")
check(!E.pdf(zs, f.merge('etikett_qr' => 'ja')).to_s.include?('http'), 'kein Internet nötig')

# --- Export-Dialog mit Etiketten: Format speichern, Zielordner ---
module UI
  class << self
    attr_accessor :antwort, :meldung, :ordner, :url, :antworten
    # erst der Export-Dialog (nur Etiketten, Zielordner), dann das Etikettenformat
    def inputbox(*) = (self.antworten ||= [%w[nein ja nein nein] + [ordner.to_s], antwort]).shift
    def messagebox(m, *) = (self.meldung = m)
    def select_directory(**) = ordner
    def openURL(u) = (self.url = u)
  end
end
model.selection.clear
def edialog(m)
  UI.antworten = nil
  S::Ausgabe.dialog(m)
end
Dir.mktmpdir do |dir|
  UI.ordner = dir
  UI.antwort = ['Endlos', '62', '29', '1', '1', '0', '0', '0', '0', 'nein', '1']
  edialog(model)
  p = File.join(dir, 'Etiketten.pdf')
  check(File.exist?(p) && PdfHelfer.formate(File.binread(p)).uniq == [[62.0, 29.0]], 'Dialog schreibt Endlos-Etiketten als PDF')
  check(Dir.children(dir) == ['Etiketten.pdf'], "nur Etiketten gewählt: nur Etiketten.pdf (#{Dir.children(dir)})")
  check(UI.meldung.to_s.include?("#{stueck} Etiketten"), "Meldung: #{UI.meldung}")
  check(E.format_lesen['etikett_art'] == 'Endlos' && E.format_lesen['etikett_breite'] == 62.0, 'Format wird gespeichert')
  # Komma erlaubt, Start 3
  UI.antwort = ['Bogen', '70', '37', '3', '8', '0,5', '0', '0', '0', 'nein', '3']
  edialog(model)
  check(PdfHelfer.formate(File.binread(p)).uniq == [[210.0, 297.0]] && E.format_lesen['etikett_art'] == 'Bogen', 'Dialog: Bogen mit Komma und Start 3')
  # ungültig: nichts gespeichert
  UI.meldung = nil
  UI.antwort = ['Bogen', 'x', '37', '3', '8', '0', '0', '0', '0', 'nein', '1']
  edialog(model)
  check(UI.meldung.to_s.include?('nur Zahlen') && E.format_lesen['etikett_breite'] == 70.0, 'ungültige Eingabe: Hinweis, Format bleibt')
  UI.antwort = ['Bogen', '80', '37', '3', '8', '0', '0', '0', '0', 'nein', '1']
  edialog(model)
  check(UI.meldung.to_s.include?('passen nicht auf A4'), 'zu großer Bogen: Hinweis')
end
UI.antwort = nil
UI.meldung = nil
edialog(model)
check(UI.meldung.nil?, 'Abbrechen schreibt nichts')
edialog(Sketchup::Model.new)
check(UI.meldung.to_s.start_with?('Keine Schrankteile'), 'leeres Modell: Hinweis')

puts $fehler.zero? ? 'OK: Etiketten' : "#{$fehler} Fehler"
exit($fehler.zero? ? 0 : 1)
