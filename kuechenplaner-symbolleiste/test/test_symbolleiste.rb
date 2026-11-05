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
  # Timer wie in SketchUp: start_timer gibt eine Nummer zurück, stop_timer hält an.
  # SketchUp-Eigenheit: öffnet ein Timer-Block ein modales Fenster, feuert derselbe
  # (auch einmalige) Timer erneut, solange das Fenster offen ist – nachgestellt in modal.
  @timer = []
  @laufend = []
  @gestoppt = []
  @nr = 0
  def self.start_timer(_s, _r = false, &blk) = (@timer << [@nr += 1, blk]).last.first
  def self.stop_timer(id) = @gestoppt << id
  def self.timer_ablaufen
    until @timer.empty?
      id, blk = @timer.shift
      next if @gestoppt.include?(id)
      @laufend << [id, blk]
      begin
        blk.call
      ensure
        @laufend.pop
      end
    end
  end

  def self.modal
    return if @laufend.size > 3
    @laufend.dup.each do |id, blk|
      next if @gestoppt.include?(id)
      @laufend << [id, blk]
      begin
        blk.call
      ensure
        @laufend.pop
      end
    end
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
    def execute_script(js) = (@skripte ||= []) << js
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
check(titel == ['Schrank einfügen', 'Schrank andocken', 'Arbeitsplatte', 'Raum', 'Schrank-Beschriftung', 'Geräte einsetzen/entfernen', 'Frontfarbe und Griffe', 'TCN exportieren',
                 'Stückliste', 'Etiketten', 'Zuschnittplan', 'Rendern', 'Materialien', 'Einstellungen'],
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

# Schrank-Beschriftung: Schalter, eingeschaltet gedrückt
bs = tb.befehle.find { |c| c.titel == 'Schrank-Beschriftung' }
umgeschaltet = 0
an = false
JTools::SchrankCnc::Beschriftung.define_singleton_method(:umschalten) { |*_a| umgeschaltet += 1; an = !an }
JTools::SchrankCnc::Beschriftung.define_singleton_method(:an?) { |*_a| an }
bs.aktion.call
check(umgeschaltet == 1 && bs.validation.call == MF_CHECKED, 'Beschriftung: Klick schaltet ein, Icon gedrückt')
bs.aktion.call
check(umgeschaltet == 2 && bs.validation.call == MF_ENABLED, 'Beschriftung: zweiter Klick schaltet aus')

# Geräte: Schalter, gedrückt = Geräte eingesetzt
gs = tb.befehle.find { |c| c.titel == 'Geräte einsetzen/entfernen' }
geschaltet = 0
drin = false
Geraete.define_singleton_method(:umschalten) { |*_a| geschaltet += 1; drin = !drin }
Geraete.define_singleton_method(:eingesetzt?) { |*_a| drin }
gs.aktion.call
check(geschaltet == 1 && gs.validation.call == MF_CHECKED, 'Geräte: Klick setzt ein, Icon gedrückt')
gs.aktion.call
check(geschaltet == 2 && gs.validation.call == MF_ENABLED, 'Geräte: zweiter Klick entfernt, Icon nicht gedrückt')

schraenke = Kuechenplaner.schraenke
gruppen = schraenke.group_by(&:first).transform_values { |l| l.map { |e| e[1] }.sort }
soll = {
  'Unterschränke' => ['Abschlussregal…', 'Eckschrank Blindeck…', 'Eckschrank L-Form…', 'Inselschrank…', 'Spülenschrank…', 'Unterschrank Backofen (Herdumbau)…', 'Unterschrank Geschirrspüler…', 'Unterschrank Handtuchauszug…',
                      'Unterschrank Kochfeld mit Abzug…', 'Unterschrank Kühlschrank…', 'Unterschrank Mülltrennung…', 'Unterschrank mit Schubladen…', 'Unterschrank mit Tür…'],
  'Oberschränke' => ['Abschlussregal…', 'Eck-Oberschrank L-Form…', 'Oberschrank Dunstabzug…', 'Oberschrank mit Klappe…', 'Oberschrank…'],
  'Hochschränke' => ['Abschlussregal…', 'Apothekerschrank…', 'Hochschrank Geräte…', 'Hochschrank Kühlschrank…', 'Hochschrank Vorrat…', 'Hochschrank…'],
  'Blenden & Wangen' => ['Passblende…', 'Sockelblende…', 'Wange…']
}
check(gruppen == soll, "Schränke für die Auswahl: #{gruppen.inspect}")

# Schrank einfügen: Auswahl zeigt jede Gruppe mit ihren Schränken; Klick schließt und ruft die Menü-Aktion
tb.befehle[0].aktion.call
d = UI::HtmlDialog.letzter
check(d && !d.geschlossen, 'Schrank einfügen öffnet die Auswahl')
html = d.html
pos = ['Unterschränke', 'Oberschränke', 'Hochschränke', 'Blenden &amp; Wangen'].map { |g| html.index("<legend>#{g}</legend>") }
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
require_relative '../../test/eingabe_helfer'
m = Sketchup.active_model = Sketchup::Model.new
tb.befehle[0].aktion.call
d = UI::HtmlDialog.letzter
d.callbacks['waehlen'].call(nil, knopf.(d.html, 'Unterschrank mit Schubladen'))
UI.timer_ablaufen
e = UI::HtmlDialog.letzter
check(e != d && e.html.include?('<h1>Unterschrank mit Schubladen</h1>'), 'Auswahl öffnet das Eingabefenster des Schranks')
EingabeHelfer.ok(e)
check(e.geschlossen, 'Eingabefenster schließt nach dem Einfügen')
EingabeHelfer.ok(e) # Doppelklick
check(UI::HtmlDialog.letzter == e, 'Eingabefenster genau einmal')
check(m.entities.grep(Sketchup::ComponentInstance).size == 1,
      "genau ein Schrank aus der Auswahl eingefügt: #{m.entities.grep(Sketchup::ComponentInstance).size}")

# Raum: Auswahl mit den Befehlen der Raum-Erweiterung
tb.befehle[3].aktion.call
d = UI::HtmlDialog.letzter
raum = ['Raum anlegen', 'Wände aus Linien', 'Fenster/Tür einsetzen', 'Öffnung bearbeiten', 'Raum bearbeiten']
check(d.html.scan(%r{<span>(.*?)</span>}).flatten == raum, "Raum-Auswahl: #{d.html.scan(%r{<span>(.*?)</span>}).flatten.inspect}")
# Raum anlegen über die Auswahl: Dialog einmal, genau ein Raum
raeume = 0
Raum.define_singleton_method(:anlegen) { |*_a| raeume += 1 }
Raum.define_singleton_method(:auswaehlen) { |*_a| nil }
d.callbacks['waehlen'].call(nil, knopf.(d.html, 'Raum anlegen'))
UI.timer_ablaufen
e = UI::HtmlDialog.letzter
check(e != d && e.html.include?('<h1>Raum anlegen</h1>'), 'Raum anlegen: Eingabefenster offen')
EingabeHelfer.ok(e)
EingabeHelfer.ok(e) # Doppelklick
check(UI::HtmlDialog.letzter == e, 'Raum anlegen: Eingabefenster genau einmal')
check(raeume == 1, "Raum anlegen: genau ein Raum: #{raeume}")
tb.befehle[3].aktion.call
d = UI::HtmlDialog.letzter
gerufen = nil
Raum.define_singleton_method(:einsetzen_dialog) { gerufen = :einsetzen }
d.callbacks['waehlen'].call(nil, knopf.(d.html, 'Fenster/Tür einsetzen'))
UI.timer_ablaufen
check(gerufen == :einsetzen, 'Raum-Auswahl ruft Fenster/Tür einsetzen')

# Stückliste, Etiketten, Zuschnittplan: Icons öffnen dieselben Dialoge wie das Menü
gerufen = []
{ 'Stückliste' => JTools::SchrankCnc::Stueckliste, 'Etiketten' => JTools::SchrankCnc::Etiketten,
  'Zuschnittplan' => JTools::SchrankCnc::Zuschnitt, 'Materialien' => JTools::SchrankCnc::Materialdialog,
  'Einstellungen' => JTools::SchrankCnc::Einstellungen }.each do |t, mod|
  mod.define_singleton_method(:dialog) { |*_a| gerufen << t }
  tb.befehle.find { |c| c.titel == t }.aktion.call
end
check(gerufen == %w[Stückliste Etiketten Zuschnittplan Materialien Einstellungen], "Stückliste/Etiketten/Zuschnittplan/Materialien/Einstellungen öffnen ihren Dialog: #{gerufen.inspect}")

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
