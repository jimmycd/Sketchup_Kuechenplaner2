# Test ohne SketchUp: Symbolleiste „Küchenplaner“ mit wenigen Icons; „Schrank einfügen“
# zeigt alle Schränke aus dem Menü, gegliedert nach Unter-, Ober- und Hochschränken.
haupt = File.expand_path('../..', __dir__)
$LOAD_PATH.unshift(File.join(haupt, 'sketchup-tcn-export-plugin/test'))
require 'sketchup_mock'

$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

module UI
  @timer = []
  def self.start_timer(_s, _r = false, &blk) = @timer << blk
  def self.timer_ablaufen
    @timer.shift.call until @timer.empty?
  end

  class HtmlDialog
    STYLE_DIALOG = 0
    class << self
      attr_accessor :letzter
    end
    attr_reader :html, :callbacks, :geschlossen
    def initialize(_opt) = (@callbacks = {}).tap { HtmlDialog.letzter = self }
    def set_html(h) = @html = h
    def add_action_callback(n, &blk) = @callbacks[n] = blk
    def center = nil
    def show = @geschlossen = false
    def visible? = !@geschlossen
    def close = @geschlossen = true
  end
end
Sketchup.active_model = Sketchup::Model.new

symbolleiste = File.join(haupt, 'kuechenplaner-symbolleiste/src/kuechenplaner_symbolleiste/main.rb')

# Nur die Symbolleiste geladen: alle Icons da, aber ausgegraut (keine anderen Erweiterungen)
load symbolleiste
tbs = UI::Toolbar.alle
check(tbs.size == 1 && tbs.first.name == 'Küchenplaner', "genau eine Symbolleiste Küchenplaner: #{tbs.map(&:name)}")
tb = tbs.first
titel = tb.befehle.map(&:titel)
check(titel == ['Schrank einfügen', 'Schrank andocken', 'Arbeitsplatte', 'Raum', 'Frontfarbe und Griffe', 'TCN exportieren'],
      "Icons der Symbolleiste: #{titel.inspect}")
check(tb.sichtbar, 'Symbolleiste beim ersten Start eingeblendet')
tb.befehle.each do |c|
  check(c.small_icon == c.large_icon && c.small_icon.end_with?('.svg') && File.exist?(c.small_icon), "#{c.titel}: SVG-Icon #{c.small_icon}")
  check(File.exist?(c.small_icon.sub(/\.svg\z/, '.png')), "#{c.titel}: PNG-Icon für Mac")
  check(c.tooltip && c.status_bar_text, "#{c.titel}: Tooltip und Hilfetext")
  check(c.validation.call == MF_GRAYED, "#{c.titel}: ohne die zugehörige Erweiterung ausgegraut")
end

# Alle Erweiterungen laden (wie SketchUp: alphabetisch), zweimal: Symbolleiste und Schränke nur einmal
src = Dir[File.join(haupt, 'Komponenten/*/src')] + %w[sketchup-tcn-export-plugin/src kuechenplaner-update/src].map { |s| File.join(haupt, s) }
lade = src.map { |s| File.join(s, File.basename(Dir[File.join(s, '*.rb')].first, '.rb'), 'main.rb') }
$VERBOSE = nil
2.times { lade.sort_by { |m| File.basename(File.dirname(m)) }.each { |m| load m }; load symbolleiste }
UI.timer_ablaufen
check(UI::Toolbar.alle.size == 1, 'Symbolleiste nur einmal angelegt')
tb.befehle.each { |c| check(c.validation.call == MF_ENABLED, "#{c.titel}: mit allen Erweiterungen aktiv") }

schraenke = Kuechenplaner.schraenke
gruppen = schraenke.group_by(&:first).transform_values { |l| l.map { |e| e[1] }.sort }
soll = {
  'Unterschränke' => ['Abschlussregal…', 'Eckschrank Blindeck…', 'Eckschrank L-Form…', 'Spülenschrank…', 'Unterschrank Geschirrspüler…', 'Unterschrank Handtuchauszug…',
                      'Unterschrank Kochfeld mit Abzug…', 'Unterschrank Mülltrennung…', 'Unterschrank mit Schubladen…', 'Unterschrank mit Tür…'],
  'Oberschränke' => ['Abschlussregal…', 'Oberschrank…'],
  'Hochschränke' => ['Abschlussregal…', 'Apothekerschrank…', 'Hochschrank Geräte…', 'Hochschrank…']
}
check(gruppen == soll, "Schränke für die Auswahl: #{gruppen.inspect}")

# Schrank einfügen: Auswahl zeigt jede Gruppe mit ihren Schränken; Klick schließt und ruft die Menü-Aktion
tb.befehle[0].aktion.call
d = UI::HtmlDialog.letzter
check(d && !d.geschlossen, 'Schrank einfügen öffnet die Auswahl')
html = d.html
pos = %w[Unterschränke Oberschränke Hochschränke].map { |g| html.index("<h2>#{g}</h2>") }
check(pos.all? && pos == pos.sort, "Gruppen in der Reihenfolge Unter, Ober, Hoch: #{pos.inspect}")
knopf = ->(h, titel) { h[%r{sketchup\.waehlen\((\d+)\)"><svg(?:(?!<button).)*</svg><span>#{Regexp.escape(titel)}</span>}m, 1] }
schraenke.each { |_, t, _| check(knopf.(html, t.sub(/…\z/, '')), "Auswahl enthält #{t}") }
check(html.scan('<svg').size == schraenke.size, 'jeder Schrank mit Bild')
aufgerufen = nil
Kuechenplaner.schraenke << ['Unterschränke', 'Test<&>', -> { aufgerufen = true }]
tb.befehle[0].aktion.call
d = UI::HtmlDialog.letzter
d.callbacks['waehlen'].call(nil, knopf.(d.html, 'Test&lt;&amp;&gt;'))
check(d.geschlossen && !aufgerufen, 'Auswahl schließt sich vor dem Einfügen')
UI.timer_ablaufen
check(aufgerufen, 'Auswahl ruft die Aktion des Schranks')
Kuechenplaner.schraenke.pop

# Echter Ablauf über die Auswahl: Unterschrank mit Schubladen wird erzeugt
module UI
  def self.inputbox(_p, defaults, *_r) = defaults
end
m = Sketchup.active_model = Sketchup::Model.new
tb.befehle[0].aktion.call
d = UI::HtmlDialog.letzter
d.callbacks['waehlen'].call(nil, knopf.(d.html, 'Unterschrank mit Schubladen'))
UI.timer_ablaufen
check(m.entities.grep(Sketchup::ComponentInstance).size == 1, 'Schrank aus der Auswahl eingefügt')

# Raum: Auswahl mit den Befehlen der Raum-Erweiterung
tb.befehle[3].aktion.call
d = UI::HtmlDialog.letzter
raum = ['Raum anlegen', 'Wände aus Linien', 'Fenster/Tür einsetzen', 'Öffnung bearbeiten', 'Raum bearbeiten']
check(d.html.scan(%r{<span>(.*?)</span>}).flatten == raum, "Raum-Auswahl: #{d.html.scan(%r{<span>(.*?)</span>}).flatten.inspect}")
gerufen = nil
Raum.define_singleton_method(:einsetzen_dialog) { gerufen = :einsetzen }
d.callbacks['waehlen'].call(nil, knopf.(d.html, 'Fenster/Tür einsetzen'))
UI.timer_ablaufen
check(gerufen == :einsetzen, 'Raum-Auswahl ruft Fenster/Tür einsetzen')

# Arbeitsplatte: ohne Auswahl erzeugen, mit gewählter Arbeitsplatte neu berechnen
aufrufe = []
Arbeitsplatte.define_singleton_method(:erzeugen) { |*_a| aufrufe << :erzeugen }
Arbeitsplatte.define_singleton_method(:neu_berechnen) { |*_a| aufrufe << :neu }
ap = tb.befehle[2].aktion
check(tb.befehle[2].titel == 'Arbeitsplatte', 'Icon 3 ist Arbeitsplatte')
m = Sketchup.active_model = Sketchup::Model.new
ap.call
m.selection.add(m.entities.add_instance(Sketchup::ComponentDefinition.new('Schrank'), Geom::Transformation.new))
ap.call
d = Sketchup::ComponentDefinition.new('APL')
d.set_attribute(Arbeitsplatte::Ausgabe::JT_DICT, 'typ', Arbeitsplatte::Ausgabe::TYP)
m.selection.clear
m.selection.add(m.entities.add_instance(d, Geom::Transformation.new))
ap.call
check(aufrufe == %i[erzeugen erzeugen neu], "Arbeitsplatte: erzeugen/neu berechnen je nach Auswahl: #{aufrufe.inspect}")

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
