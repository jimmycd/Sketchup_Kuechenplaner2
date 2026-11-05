# Test ohne SketchUp: Zuschnittplan (eigener Guillotine-Optimierer) an echten Schränken
# aus Komponenten/: alle Teile platziert, keine Überlappung, innerhalb der besäumten
# Platte, Schnittbreite eingehalten, alle Optionen (erster Schnitt, Schnitttyp, Stufen,
# Faserrichtung, Plattenreste), Schnitte wirklich durchgehend, PDF, Dialog.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
require 'pdf_helfer'
require 'tmpdir'
komp = File.expand_path('../../Komponenten', __dir__)
load File.join(komp, 'hochschrank/src/hochschrank/main.rb')
load File.join(komp, 'unterschrank_schubladen/src/unterschrank_schubladen/main.rb')
load File.join(komp, 'oberschrank/src/oberschrank/main.rb')
load File.expand_path('../src/jt_schrank_cnc/main.rb', __dir__)

S = JTools::SchrankCnc
Z = S::Zuschnitt
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

Gu = S::Guillotine
EPS = 1e-6

# Prüft eine Gruppe: Teile in der besäumten Platte, keine Überlappung inkl. Schnittbreite
def pruefen(g, sb, rand, name)
  g.platten.each_with_index do |p, k|
    p.teile.each do |t|
      z, = t.stueck.daten
      check(t.x >= rand - EPS && t.y >= rand - EPS && t.x + t.l <= p.l - rand + EPS && t.y + t.b <= p.b - rand + EPS,
            "#{name} Platte #{k + 1}: Nr #{z.nr} liegt im Randabfall oder außerhalb (#{t.x}/#{t.y} #{t.l}×#{t.b})")
      check([t.l, t.b].map { |v| v.round(3) }.sort == z.roh.map { |v| v.round(3) }.sort, "#{name}: Nr #{z.nr} mit Rohmaß gelegt")
      check(t.gedreht ? (t.l - z.roh[1]).abs < EPS : (t.l - z.roh[0]).abs < EPS, "#{name}: Nr #{z.nr} Drehung passt zur Lage")
    end
    p.teile.combination(2).each do |a, b|
      frei = a.x + a.l + sb <= b.x + EPS || b.x + b.l + sb <= a.x + EPS || a.y + a.b + sb <= b.y + EPS || b.y + b.b + sb <= a.y + EPS
      check(frei, "#{name} Platte #{k + 1}: Nr #{a.stueck.daten[0].nr} und #{b.stueck.daten[0].nr} überlappen oder liegen näher als die Schnittbreite")
    end
  end
end

# Kein Schnitt (Stufe ≥ 1) darf durch ein Teil gehen; jedes Teil ist von Schnitten oder
# vom Randabfall umschlossen; Stufen nicht über dem erlaubten Maximum
def schnitte_pruefen(p, o, name)
  kerf = o.kerf
  p.schnitte.each do |s|
    next if s.stufe.zero?
    a0 = s.horizontal ? s.x : s.y
    a1 = a0 + s.laenge
    q0 = s.horizontal ? s.y : s.x
    p.teile.each do |t|
      t0, t1 = s.horizontal ? [t.y, t.y + t.b] : [t.x, t.x + t.l]
      l0, l1 = s.horizontal ? [t.x, t.x + t.l] : [t.y, t.y + t.b]
      schneidet = q0 + kerf > t0 + EPS && q0 < t1 - EPS && a1 > l0 + EPS && a0 < l1 - EPS
      check(!schneidet, "#{name}: Schnitt #{s.nr} (Stufe #{s.stufe}) geht durch Nr #{t.stueck.daten[0].nr}")
    end
    check(a0 >= o.rand - EPS && a1 <= (s.horizontal ? p.l : p.b) - o.rand + EPS, "#{name}: Schnitt #{s.nr} innerhalb der besäumten Platte")
  end
  max = o.stufen + (o.typ == 'nicht exakt' ? 1 : 0)
  check(p.schnitte.all? { |s| s.stufe <= max }, "#{name}: höchstens #{max} Stufen (#{p.schnitte.map(&:stufe).max})")
  check(p.schnitte.map(&:nr) == (1..p.schnitte.size).to_a, "#{name}: Schnitte fortlaufend nummeriert")
  besaeum = p.schnitte.take_while { |s| s.stufe.zero? }
  check(besaeum.size == (o.rand > 0 ? 4 : 0) && p.schnitte.drop(besaeum.size).none? { |s| s.stufe.zero? }, "#{name}: Besäumen zuerst")
  # Stufe 1 läuft über die ganze besäumte Platte, in der gewählten Richtung
  s1 = p.schnitte.select { |s| s.stufe == 1 }
  check(s1.all? { |s| (s.laenge - ((s.horizontal ? p.l : p.b) - 2 * o.rand)).abs < EPS }, "#{name}: Stufe 1 durchgehend")
  check(s1.map(&:horizontal).uniq.size <= 1 && (s1.empty? || s1.first.horizontal == (p.erster == :h)), "#{name}: Stufe 1 in einer Richtung")
end

model = Sketchup.active_model = Sketchup::Model.new
Hochschrank.erstellen({})
UnterschrankSchubladen.erstellen({ 'Breite' => 90.0, 'Tiefe' => 56.0 })
Oberschrank.erstellen({})
model.selection.clear
zs, = S::Stueckliste.erzeugen(model)
stueck = zs.reject { |z| z.hinweis == 'Arbeitsplatte' || z.material.empty? }.sum(&:anzahl)

o = Z.optionen_lesen
check(o['schnittbreite'] == 3.0 && o['besaeumen'] == 10.0 && o['zs_erster'] == 'beliebig' && o['zs_typ'] == 'nicht exakt' &&
      o['zs_stufen'] == '3' && o['zs_faser'] == 'wie Material' && o['zs_tabelle'] == 'keine', "Standardoptionen: #{o}")
mel = model.materials.to_a.find { |m| m.name == 'Melamin weiss' }
check(Z.plattenformat(mel) == [2800.0, 2070.0], "Plattenformat aus std_sizes: #{Z.plattenformat(mel)}")
check(Z.plattenformat(nil) == [2800.0, 2070.0], 'ohne Material: Standardplatte')
check(Z.plattenreste(mel) == [], 'ohne Eintrag keine Plattenreste')
check(Z.reste_lesen('1200 x 600 x 2; 800mm x 400') == [[1200.0, 600.0, 2], [800.0, 400.0, 1]] && Z.reste_lesen('') == [], 'Plattenreste lesen')
check((Z.reste_lesen('1200 x') rescue :fehler) == :fehler, 'ungültiger Plattenrest: Fehler')
check(Z.format_lesen('2070 × 2800') == [2800.0, 2070.0] && Z.format_lesen('abc').nil?, 'Plattenformat lesen')

gruppen, meldungen = Z.erzeugen(model)
check(meldungen.empty?, "keine Meldungen: #{meldungen}")
check(gruppen.map { |g| [g.material, g.ds] }.sort == zs.map { |z| [z.material, z.ds] }.uniq.sort, 'eine Gruppe je Material und Stärke')
platziert = gruppen.sum { |g| g.platten.sum { |p| p.teile.size } }
check(platziert == stueck, "alle Teile platziert (#{platziert}/#{stueck})")
check(gruppen.all? { |g| g.nicht_platziert.empty? && g.fehler.nil? }, 'nichts übrig')
g19 = gruppen.find { |g| g.material == 'Melamin weiss' && g.ds == 19 }
check(g19 && g19.platten.size >= 1 && g19.platten.all? { |p| p.l == 2800 && p.b == 2070 }, 'Platten 2800 × 2070')
check(g19.platten.all? { |p| p.ausnutzung > 0 && p.ausnutzung <= 100 }, 'Ausnutzung in %')

# --- Alle Kombinationen: erster Schnitt × Schnitttyp × Stufen ---
Gu::ERSTER.each do |e|
  Gu::TYPEN.each do |ty|
    %w[2 3].each do |st|
      oo = o.merge('zs_erster' => e, 'zs_typ' => ty, 'zs_stufen' => st)
      go = Z.berechnen(model, zs, oo)
      name = "#{e}/#{ty}/#{st}"
      check(go.sum { |g| g.platten.sum { |p| p.teile.size } } == stueck, "#{name}: alle Teile platziert")
      go.each do |g|
        pruefen(g, 3.0, 10.0, "#{name} #{g.ds}")
        g.platten.each { |p| schnitte_pruefen(p, Z.guillotine_optionen(oo), "#{name} #{g.ds}") }
        g.platten.each { |p| check(p.erster == { 'horizontal' => :h, 'vertikal' => :v }[e], "#{name}: erster Schnitt #{e}") } unless e == 'beliebig'
      end
    end
  end
end

# Exakt mit 2 Stufen: jedes Teil füllt seinen Streifen quer voll aus (keine Stufe 3)
ge = Z.berechnen(model, zs, o.merge('zs_typ' => 'exakt', 'zs_stufen' => '2'))
check(ge.all? { |g| g.platten.all? { |p| p.schnitte.none? { |s| s.stufe > 2 } } }, 'exakt/2: nur Stufe 1 und 2')
# Homogen mit 3 Stufen: in einem Abschnitt nur gleiche Teile (gleiche Nummer übereinander)
gh = Z.berechnen(model, zs, o.merge('zs_typ' => 'homogen', 'zs_stufen' => '3', 'zs_erster' => 'horizontal'))
gh.each do |g|
  g.platten.each do |p|
    p.teile.group_by { |t| t.x.round(3) }.each_value do |spalte|
      spalte.group_by { |t| ((t.y - 10) / 1).floor }.size # nur Lauf prüfen
    end
    abschnitte = p.teile.group_by { |t| [t.x.round(3), p.schnitte.select { |s| s.stufe == 1 }.count { |s| s.y < t.y }] }
    check(abschnitte.values.all? { |ts| ts.map { |t| t.stueck.schluessel }.uniq.size == 1 }, "homogen/3: Abschnitte mit gleichen Teilen (#{g.ds})")
  end
end

# Schnittbreite und Randabfall aus den Optionen
g5 = Z.berechnen(model, zs, o.merge('schnittbreite' => 5.0, 'besaeumen' => 20.0))
g5.each { |g| pruefen(g, 5.0, 20.0, "#{g.material} #{g.ds} (5/20)") }

# Faserrichtung: Material mit Maserung → nicht drehen, L längs; „ignorieren“ darf drehen; „beachten“ nie
mel.set_attribute('ladb_opencutlist', 'grained', true)
zs_m, = S::Stueckliste.erzeugen(model)
gm = Z.berechnen(model, zs_m, o).find { |g| g.material == 'Melamin weiss' && g.ds == 19 }
check(gm.maserung && gm.platten.all? { |p| p.teile.none?(&:gedreht) && p.teile.all? { |t| (t.l - t.stueck.daten[0].roh[0]).abs < EPS } },
      'Maserung: nicht gedreht, L (Faserrichtung) längs der Platte')
gi = Z.berechnen(model, zs_m, o.merge('zs_faser' => 'ignorieren')).find { |g| g.ds == 19 }
check(!gi.maserung && gi.platten.any? { |p| p.teile.any?(&:gedreht) }, 'Faserrichtung ignorieren: drehen erlaubt')
mel.set_attribute('ladb_opencutlist', 'grained', false)
gb = Z.berechnen(model, zs, o.merge('zs_faser' => 'beachten'))
check(gb.all? { |g| g.maserung && g.platten.all? { |p| p.teile.none?(&:gedreht) } }, 'Faserrichtung beachten: nie drehen')

# Plattenreste: zuerst belegt, Anzahl begrenzt; am Material gespeichert
mel.set_attribute('JT_Zuschnitt', 'reste', '900 x 650 x 2')
check(Z.plattenreste(mel) == [[900.0, 650.0, 2]], 'Plattenreste vom Material')
gr = Z.berechnen(model, zs, o).find { |g| g.ds == 19 }
check(gr.platten.first(2).all?(&:rest) && gr.platten.count(&:rest) <= 2 && gr.platten.select(&:rest).all? { |p| p.l == 900 && p.b == 650 },
      "Plattenreste zuerst, höchstens 2: #{gr.platten.map { |p| [p.l, p.b, p.rest] }}")
pruefen(gr, 3.0, 10.0, 'mit Resten')
check(gr.platten.sum { |p| p.teile.size } == g19.platten.sum { |p| p.teile.size }, 'mit Resten: alle Teile platziert')
mel.set_attribute('JT_Zuschnitt', 'reste', '')
# OCL std_sizes: Formate mit Anzahl sind Reste
mel.set_attribute('JT_Zuschnitt', 'reste', nil)
mel.set_attribute('ladb_opencutlist', 'std_sizes', '2800mm x 2070mm;1000mm x 500mm x 3')
check(Z.plattenreste(mel) == [[1000.0, 500.0, 3]] && Z.plattenformat(mel) == [2800.0, 2070.0], 'OCL std_sizes: Format und Reste')

# Reste behalten ab Mindestgröße
check(g19.platten.flat_map(&:reste).select(&:behalten).all? { |r| [r.l, r.b].max >= 300 && [r.l, r.b].min >= 100 }, 'Reste behalten ab 300 × 100')
check(g19.platten.flat_map(&:reste).reject(&:behalten).all? { |r| [r.l, r.b].max < 300 || [r.l, r.b].min < 100 }, 'kleine Reste sind Abfall')

# Teil größer als die Platte: wird gemeldet, Rest trotzdem geplant
mel.set_attribute('ladb_opencutlist', 'std_sizes', '1000mm x 900mm')
gk, mk = Z.erzeugen(model)
gk19 = gk.find { |g| g.material == 'Melamin weiss' && g.ds == 19 }
check(gk19.nicht_platziert.any? { |z, _, _| z.tag == 'HS1_SeiteL' } && gk19.platten.size >= 1, 'zu großes Teil: nicht platziert, Rest geplant')
check(mk.any? { |m| m.include?('passen nicht auf die Platte') }, "Meldung für nicht platzierte Teile: #{mk}")
check(PdfHelfer.texte(Z.pdf(gk, o, meldungen: mk), 0).any? { |t| t.include?('Nr ') && t.include?('(') || t.start_with?('Nr ') }, 'nicht platzierte Teile in der Übersicht')
mel.set_attribute('ladb_opencutlist', 'std_sizes', '2800mm x 2070mm')
# eigenes Format am Material geht vor
mel.set_attribute('JT_Zuschnitt', 'platte', '3050 x 1300')
check(Z.plattenformat(mel) == [3050.0, 1300.0], 'Plattenformat am Material (JT_Zuschnitt)')
mel.set_attribute('JT_Zuschnitt', 'platte', nil)

# Gleiche Platten zusammenfassen
z4 = zs.find { |z| z.tag == 'HS1_SeiteL' }.dup
z4.anzahl = 6
gg = Z.berechnen(model, [z4], o).first
ls = Z.layouts(gg, true)
check(gg.platten.size >= 2 && ls.size < gg.platten.size && ls.sum { |_, n| n.size } == gg.platten.size, "gleiche Platten zusammengefasst: #{gg.platten.size} → #{ls.size}")
check(Z.layouts(gg, false).size == gg.platten.size, 'nicht zusammenfassen: jede Platte einzeln')

# --- PDF ---
doc = Z.pdf(gruppen, o, titel: 'Zuschnitt Test')
pdf = doc.to_s
nplatten = gruppen.sum { |g| Z.layouts(g, true).size }
check(PdfHelfer.gueltig?(pdf), 'gültiges PDF')
check(PdfHelfer.formate(pdf).uniq == [[297.0, 210.0]], 'A4 quer')
check(PdfHelfer.seiten(pdf) == 1 + nplatten, "Übersicht + eine Seite je Platte (#{PdfHelfer.seiten(pdf)})")
check(PdfHelfer.texte(pdf, 0).any? { |t| t.include?('Schnittbreite 3 mm') && t.include?('Randabfall 10 mm') && t.include?('3 Stufen') }, 'Optionen auf der Übersicht')
bz = zs.find { |z| z.tag == 'HS1_Boden' }
alle = PdfHelfer.texte(pdf)
check(alle.include?('HS1_Boden') && alle.any? { |t| t.start_with?("Nr #{bz.nr} ·") && t.include?('808 × 572') }, 'Tag, Nummer und Rohmaß auf dem Teil in der Grafik')
check(alle.none? { |t| t == 'Stufe 1' }, 'ohne Tabelle keine Schnittliste')
mit = Z.pdf(gruppen, o.merge('zs_tabelle' => 'eigene Seite je Platte')).to_s
check(PdfHelfer.seiten(mit) == 1 + 2 * nplatten, 'Tabelle: eigene Seite nach jeder Platte')
check(PdfHelfer.texte(mit).include?('Besäumen') && PdfHelfer.texte(mit).include?('Stufe 1'), 'Schnittliste auf der Tabellenseite')
# Reste und Anleimer/Farbe ändern nichts am Aufbau
check(PdfHelfer.gueltig?(Z.pdf(gruppen, o.merge('zs_farbe' => 'ja', 'zs_kanten' => 'ja', 'zs_nummern' => 'nein')).to_s), 'Darstellungsoptionen')

# --- Dialog ---
module UI
  class << self
    attr_accessor :meldung, :ordner, :url, :antwort, :letzte_labels, :letzte_werte
    def inputbox(labels, werte, *_)
      self.letzte_labels = labels
      self.letzte_werte = werte
      antwort
    end
    def messagebox(m, *) = (self.meldung = m)
    def select_directory(**) = ordner
    def openURL(u) = (self.url = u)
  end
end
Dir.mktmpdir do |dir|
  UI.ordner = dir
  Z.dialog(model)
  UI.antwort = nil
  Z.dialog(model)
  check(!File.exist?(File.join(dir, 'Zuschnitt.pdf')), 'Optionen abgebrochen: nichts geschrieben')
  feld = UI.letzte_labels
  check(feld.include?('Optimierung: Schnitttyp') && feld.include?('Darstellung: Schnitt- und Teileliste') &&
        feld.any? { |l| l.start_with?('Melamin weiss 19 mm: Plattenreste') }, "Fenster mit Optionen und Plattenresten je Material: #{feld}")
  w = UI.letzte_werte.dup
  w[Z::OPTIONEN.keys.index('zs_typ')] = 'exakt'
  w[Z::OPTIONEN.keys.index('zs_stufen')] = '2'
  w[Z::OPTIONEN.keys.index('zs_tabelle')] = 'eigene Seite je Platte'
  i19 = feld.index { |l| l.start_with?('Melamin weiss 19 mm: Plattenreste') }
  w[i19] = '1000 x 700 x 1'
  UI.antwort = w
  Z.dialog(model)
  pdf = File.join(dir, 'Zuschnitt.pdf')
  check(File.exist?(pdf) && PdfHelfer.gueltig?(File.binread(pdf)), 'Dialog schreibt Zuschnitt.pdf')
  check(UI.url.to_s.end_with?('Zuschnitt.pdf'), 'PDF wird geöffnet')
  check(UI.meldung.to_s.start_with?('Zuschnittplan: '), "Meldung: #{UI.meldung}")
  check(Z.optionen_lesen['zs_typ'] == 'exakt' && Z.optionen_lesen['zs_stufen'] == '2', 'Optionen gespeichert')
  check(mel.get_attribute('JT_Zuschnitt', 'reste_19') == '1000 x 700' && mel.get_attribute('JT_Zuschnitt', 'platte_19') == '2800 x 2070' &&
        mel.get_attribute('JT_Zuschnitt', 'reste_16') == '', 'Plattenreste und Format je Stärke am Material gespeichert')
  check(Z.plattenreste(mel, 19) == [[1000.0, 700.0, 1]] && Z.plattenreste(mel, 16) == [], 'Plattenreste je Stärke gelesen')
  check(PdfHelfer.texte(File.binread(pdf)).include?('Stufe 2') && PdfHelfer.texte(File.binread(pdf)).none? { |t| t == 'Stufe 3' }, 'PDF mit exakt/2 Stufen und Tabelle')
  # ungültig: Hinweis, nichts gespeichert
  w2 = w.dup
  w2[Z::OPTIONEN.keys.index('schnittbreite')] = 'x'
  UI.antwort = w2
  Z.dialog(model)
  check(UI.meldung.to_s.include?('Schnittbreite') && Z.optionen_lesen['schnittbreite'] == 3.0, "ungültige Schnittbreite: Hinweis (#{UI.meldung})")
  w3 = w.dup
  w3[i19] = '1000 x'
  UI.antwort = w3
  Z.dialog(model)
  check(UI.meldung.to_s.include?('Plattenrest'), 'ungültiger Plattenrest: Hinweis')
  %w[reste_19 reste_16 reste_8].each { |k| mel.set_attribute('JT_Zuschnitt', k, nil) }
end
UI.ordner = nil
UI.meldung = nil
UI.antwort = UI.letzte_werte
Z.dialog(model)
check(UI.meldung.nil?, 'Ordner abgebrochen: nichts geschrieben')
Z.dialog(Sketchup::Model.new)
check(UI.meldung.to_s.start_with?('Keine Schrankteile'), 'leeres Modell: Hinweis')

puts $fehler.zero? ? 'OK: Zuschnitt' : "#{$fehler} Fehler"
exit($fehler.zero? ? 0 : 1)
