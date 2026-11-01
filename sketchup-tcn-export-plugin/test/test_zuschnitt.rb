# Test ohne SketchUp: Zuschnittplan (BinPacking2D aus OpenCutList) an echten Schränken
# aus Komponenten/: alle Teile platziert, keine Überlappung, innerhalb der besäumten
# Platte, Schnittbreite eingehalten, Maserung, Druckseite, Dialog.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
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

# Prüft eine Gruppe: Teile in der besäumten Platte, keine Überlappung inkl. Schnittbreite
def pruefen(g, sb, rand, name)
  g.platten.each do |p|
    p.teile.each do |t|
      check(t.x >= rand - 1e-6 && t.y >= rand - 1e-6 && t.x + t.l <= p.laenge - rand + 1e-6 && t.y + t.b <= p.breite - rand + 1e-6,
            "#{name} Platte #{p.nr}: Nr #{t.zeile.nr} liegt im Besäumrand oder außerhalb (#{t.x}/#{t.y} #{t.l}×#{t.b})")
      check([t.l, t.b].sort == t.zeile.roh.sort.map(&:to_f) || [t.l, t.b].map { |v| v.round(3) }.sort == t.zeile.roh.map { |v| v.round(3) }.sort,
            "#{name}: Nr #{t.zeile.nr} mit Rohmaß gelegt")
    end
    p.teile.combination(2).each do |a, b|
      frei = a.x + a.l + sb <= b.x + 1e-6 || b.x + b.l + sb <= a.x + 1e-6 || a.y + a.b + sb <= b.y + 1e-6 || b.y + b.b + sb <= a.y + 1e-6
      check(frei, "#{name} Platte #{p.nr}: Nr #{a.zeile.nr} und #{b.zeile.nr} überlappen oder liegen näher als die Schnittbreite")
    end
  end
end

model = Sketchup.active_model = Sketchup::Model.new
Hochschrank.erstellen({})
UnterschrankSchubladen.erstellen({ 'Breite' => 90.0, 'Tiefe' => 56.0 })
Oberschrank.erstellen({})
model.selection.clear
zs, = S::Stueckliste.erzeugen(model)

check(S::Einstellungen.schnittbreite == 3.0 && S::Einstellungen.besaeumen == 10.0, 'Standard: Schnittbreite 3, besäumen 10')
mel = model.materials.to_a.find { |m| m.name == 'Melamin weiss' }
check(Z.plattenformat(mel) == [2800.0, 2070.0], "Plattenformat aus std_sizes: #{Z.plattenformat(mel)}")
check(Z.plattenformat(nil) == [2800.0, 2070.0], 'ohne Material: Standardplatte')

gruppen, meldungen = Z.erzeugen(model)
check(meldungen.empty?, "keine Meldungen: #{meldungen}")
check(gruppen.map { |g| [g.material, g.ds] }.sort == zs.map { |z| [z.material, z.ds] }.uniq.sort, 'eine Gruppe je Material und Stärke')
platziert = gruppen.sum { |g| g.platten.sum { |p| p.teile.size } }
check(platziert == zs.sum(&:anzahl), "alle Teile platziert (#{platziert}/#{zs.sum(&:anzahl)})")
check(gruppen.all? { |g| g.nicht_platziert.empty? && g.fehler.nil? }, 'nichts übrig')
gruppen.each { |g| pruefen(g, 3.0, 10.0, "#{g.material} #{g.ds}") }
g19 = gruppen.find { |g| g.material == 'Melamin weiss' && g.ds == 19 }
check(g19 && g19.platten.size >= 1 && g19.platten.all? { |p| p.laenge == 2800 && p.breite == 2070 }, 'Platten 2800 × 2070')
check(g19.platten.all? { |p| p.ausnutzung > 0 && p.ausnutzung <= 100 }, 'Ausnutzung in %')

# Schnittliste: Besäumen zuerst, fortlaufend nummeriert
p1 = g19.platten.first
check(p1.schnitte.map(&:nr) == (1..p1.schnitte.size).to_a, 'Schnitte fortlaufend nummeriert')
besaeum = p1.schnitte.take_while { |s| s.art == 'Besäumen' }
check(besaeum.size >= 1 && p1.schnitte.drop(besaeum.size).none? { |s| s.art == 'Besäumen' }, 'Besäumen zuerst')
check(p1.schnitte.all? { |s| s.laenge > 0 }, 'Schnittlängen > 0')

# Schnittbreite und Besäumen aus den Einstellungen
S::Einstellungen.setzen('schnittbreite', 5)
S::Einstellungen.setzen('besaeumen', 20)
g5 = Z.erzeugen(model)[0]
g5.each { |g| pruefen(g, 5.0, 20.0, "#{g.material} #{g.ds} (5/20)") }
S::Einstellungen.setzen('schnittbreite', 3)
S::Einstellungen.setzen('besaeumen', 10)

# Maserung: nicht drehen, Teillänge liegt längs der Platte
mel.set_attribute('ladb_opencutlist', 'grained', true)
zs_m, = S::Stueckliste.erzeugen(model)
gm = Z.berechnen(model, zs_m).find { |g| g.material == 'Melamin weiss' && g.ds == 19 }
check(gm.maserung && gm.platten.all? { |p| p.teile.none?(&:gedreht) && p.teile.all? { |t| t.l >= t.b - 1e-6 } }, 'Maserung: nicht gedreht, L längs')
mel.set_attribute('ladb_opencutlist', 'grained', false)

# Teil größer als die Platte: wird gemeldet, Rest trotzdem geplant
mel.set_attribute('ladb_opencutlist', 'std_sizes', '1000mm x 900mm')
gk, mk = Z.erzeugen(model)
gk19 = gk.find { |g| g.material == 'Melamin weiss' && g.ds == 19 }
check(gk19.nicht_platziert.any? { |z, _, _| z.tag == 'HS1_SeiteL' } && gk19.platten.size >= 1, 'zu großes Teil: nicht platziert, Rest geplant')
check(mk.any? { |m| m.include?('passen nicht auf die Platte') }, "Meldung für nicht platzierte Teile: #{mk}")
check(Z.html(gk, meldungen: mk).include?('Nr '), 'nicht platzierte Teile in der Übersicht')
mel.set_attribute('ladb_opencutlist', 'std_sizes', '2800mm x 2070mm')

# --- Druckseite ---
html = Z.html(gruppen, titel: 'Zuschnitt Test')
check(html.start_with?('<!DOCTYPE html>') && html.include?('@page{size:A4 landscape'), 'HTML A4 quer')
check(html.scan('<div class="platte">').size == gruppen.sum { |g| g.platten.size }, 'eine Seite je Platte')
check(html.scan('<svg class="skizze"').size == gruppen.sum { |g| g.platten.size }, 'eine Skizze je Platte')
check(html.include?('Schnittbreite 3 mm, besäumen 10 mm'), 'Einstellungen im Kopf')
check(html.include?('<td>Besäumen</td>'), 'Schnittliste mit Besäumen')
bz = zs.find { |z| z.tag == 'HS1_Boden' }
check(html.include?(">#{bz.nr}</text>") || html.include?(">#{bz.nr}<tspan"), 'Teilnummer in der Skizze')

# --- Dialog ---
module UI
  class << self
    attr_accessor :meldung, :ordner, :url
    def messagebox(m, *) = (self.meldung = m)
    def select_directory(**) = ordner
    def openURL(u) = (self.url = u)
  end
end
Dir.mktmpdir do |dir|
  UI.ordner = dir
  Z.dialog(model)
  check(File.exist?(File.join(dir, 'Zuschnitt.html')), 'Dialog schreibt Zuschnitt.html')
  check(UI.url.to_s.end_with?('Zuschnitt.html'), 'Druckseite wird geöffnet')
  check(UI.meldung.to_s.start_with?('Zuschnittplan: '), "Meldung: #{UI.meldung}")
end
UI.ordner = nil
UI.meldung = nil
Z.dialog(model)
check(UI.meldung.nil?, 'Abbrechen schreibt nichts')
Z.dialog(Sketchup::Model.new)
check(UI.meldung.to_s.start_with?('Keine Schrankteile'), 'leeres Modell: Hinweis')

puts $fehler.zero? ? 'OK: Zuschnitt' : "#{$fehler} Fehler"
exit($fehler.zero? ? 0 : 1)
