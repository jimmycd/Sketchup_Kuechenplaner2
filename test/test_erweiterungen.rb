# Test ohne SketchUp: alle Komponenten, der TCN-Export und das Aktualisieren sind Erweiterungen (.rbz)
# und erscheinen unter Erweiterungen > Küchenplaner, das Untermenü gibt es nur einmal.
haupt = File.expand_path('..', __dir__)
$LOAD_PATH.unshift(File.join(haupt, 'sketchup-tcn-export-plugin/test'))
require 'sketchup_mock'

$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

# Menü-Aufzeichnung statt der Attrappe
module UI
  class Menu
    attr_reader :titel, :eintraege
    def initialize(titel = nil) = (@titel, @eintraege = titel, [])
    def add_submenu(t) = Menu.new(t).tap { |m| @eintraege << m }
    def add_item(t, &blk) = @eintraege << [t, blk]
    def add_separator = @eintraege << :trenner
  end
  @menues = {}
  @timer = []
  def self.menu(n) = (@menues[n] ||= Menu.new(n))
  def self.start_timer(_s, _r = false, &blk) = @timer << blk
  def self.timer_ablaufen
    @timer.shift.call until @timer.empty?
  end
end
Sketchup.active_model = Sketchup::Model.new

SRC = Dir[File.join(haupt, 'Komponenten/*/src')].sort + %w[sketchup-tcn-export-plugin/src kuechenplaner-update/src kuechenplaner-symbolleiste/src].map { |s| File.join(haupt, s) }
RBZ = ->(src) { d = File.dirname(src); n = File.basename(d); File.join(d, "#{{ 'sketchup-tcn-export-plugin' => 'schrank_cnc', 'kuechenplaner-update' => 'kuechenplaner_update', 'kuechenplaner-symbolleiste' => 'kuechenplaner_symbolleiste' }.fetch(n, n)}.rbz") }
dateien = ->(src) { Dir.chdir(src) { Dir['**/*'].reject { |f| File.directory?(f) }.sort } }
im_zip = ->(rbz, f) { IO.popen(['unzip', '-p', rbz, f], err: File::NULL, &:read).b }
zip_liste = ->(rbz) { IO.popen(['zipinfo', '-1', rbz], err: File::NULL, &:read).split("\n").reject { |f| f.end_with?('/') }.sort }

komponenten = Dir[File.join(haupt, 'Komponenten/*/')].map { |d| File.basename(d) }.sort
check(komponenten.all? { |k| File.directory?(File.join(haupt, 'Komponenten', k, 'src')) },
      "jede Komponente hat src/: #{komponenten.reject { |k| File.directory?(File.join(haupt, 'Komponenten', k, 'src')) }}")

snippet = nil
alle = File.join(haupt, 'Kuechenplaner_alle.rbz')
alle_liste = zip_liste.(alle)
SRC.each do |src|
  loader = Dir[File.join(src, '*.rb')]
  check(loader.size == 1, "#{src}: genau eine Lade-Datei")
  name = File.basename(loader.first, '.rb')
  l = File.read(loader.first, encoding: 'UTF-8')
  check(l.include?("SketchupExtension.new('Küchenplaner – ") && l.include?('Sketchup.register_extension'),
        "#{name}: registriert Erweiterung „Küchenplaner – …“")
  main = File.read(File.join(src, name, 'main.rb'), encoding: 'UTF-8')
  s = main[/^# Gemeinsames Untermenü.*?^end # gemeinsames Untermenü\n/m]
  check(s, "#{name}: gemeinsames Küchenplaner-Menü fehlt")
  snippet ||= s
  check(s == snippet, "#{name}: Küchenplaner-Menü nicht wortgleich")
  check(main.scan("UI.menu(").size == 1, "#{name}: Menüeinträge nur über Kuechenplaner.menu")
  check(!main.include?('_TEST)'), "#{name}: kein automatischer Lauf beim Laden")

  rbz = RBZ.(src)
  check(File.exist?(rbz), "#{rbz} fehlt (./build_rbz.sh ausführen)")
  check(zip_liste.(rbz) == dateien.(src), "#{File.basename(rbz)}: Dateiliste passt nicht zu src/ (./build_rbz.sh ausführen)")
  dateien.(src).each do |f|
    inhalt = File.binread(File.join(src, f))
    check(im_zip.(rbz, f) == inhalt, "rbz veraltet: #{File.basename(rbz)} #{f} (./build_rbz.sh ausführen)")
    check(alle_liste.include?(f) && im_zip.(alle, f) == inhalt, "Kuechenplaner_alle.rbz veraltet: #{f} (./build_rbz.sh ausführen)")
  end
end

# Tag-Schema: ROLLEN-Tabelle in jeder Komponente vorhanden und gleich
# (Schränke; Geräte und Raum sind keine Schrankteile und haben keine ROLLEN)
schraenke = komponenten - %w[geraete raum]
rollen = schraenke.map { |k| File.read(File.join(haupt, 'Komponenten', k, 'src', k, 'main.rb'), encoding: 'UTF-8')[/  ROLLEN = \{.*?\}\.freeze/m] }
check(rollen.all? && rollen.uniq.size == 1,
      "ROLLEN-Tabelle in allen #{schraenke.size} Schrank-Komponenten gleich (#{rollen.compact.size} gefunden, #{rollen.compact.uniq.size} Varianten)")

# Alle Erweiterungen laden (wie SketchUp beim Start: alphabetisch nach Lade-Datei), dann zweimal
lade = SRC.map { |src| File.join(src, File.basename(Dir[File.join(src, '*.rb')].first, '.rb'), 'main.rb') }
         .sort_by { |m| File.basename(File.dirname(m)) }
$VERBOSE = nil # zweites Laden überschreibt Konstanten
2.times { lade.each { |m| load m } }
UI.timer_ablaufen
erw = UI.menu('Extensions').eintraege
check(erw.size == 1 && erw.first.is_a?(UI::Menu) && erw.first.titel == 'Küchenplaner',
      "genau ein Untermenü Küchenplaner unter Erweiterungen: #{erw.map { |e| e.respond_to?(:titel) ? e.titel : e }}")
kp = erw.first.eintraege
titel = kp.map { |e| e.is_a?(Array) ? e.first : e.is_a?(UI::Menu) ? e.titel : e }
soll = ['Unterschränke', 'Oberschränke', 'Hochschränke', 'Blenden & Wangen', 'Geräte', 'Raum', :trenner, 'Arbeitsplatte erzeugen…', 'Arbeitsplatte neu berechnen', :trenner, 'Export (Stückliste, Etiketten, Zuschnitt, TCN)…', 'Schrank-Beschriftung ein/aus', 'Beschläge ein/aus', 'Rendern (Blender)…', 'Materialien…', 'Frontfarbe und Griffe ändern…', 'Korpusmaterial ändern…', 'Schrank andocken…', 'Einstellungen…',
        :trenner, 'Plugins aktualisieren (GitHub)…', 'Plugins aus Ordner laden…', 'Küchenplaner neu laden']
check(titel == soll, "Einträge im Küchenplaner-Menü: #{titel.inspect}")
gruppen = {
  'Unterschränke' => ['Eckschrank Blindeck…', 'Eckschrank L-Form…', 'Abschlussregal…', 'Unterschrank Mülltrennung…', 'Unterschrank Backofen (Herdumbau)…', 'Unterschrank mit Doppeltür…', 'Unterschrank Geschirrspüler…', 'Unterschrank Handtuchauszug…', 'Inselschrank…',
                      'Unterschrank Kochfeld mit Abzug…', 'Unterschrank Kühlschrank…', 'Unterschrank mit Schubladen…', 'Spülenschrank…', 'Unterschrank mit Tür…'],
  'Oberschränke' => ['Eck-Oberschrank L-Form…', 'Oberschrank…', 'Oberschrank Dunstabzug…', 'Oberschrank mit Klappe…', 'Abschlussregal…', 'Wandregal…'],
  'Hochschränke' => ['Apothekerschrank…', 'Hochschrank…', 'Hochschrank Geräte…', 'Hochschrank Kühlschrank…', 'Hochschrank Vorrat…', 'Abschlussregal…'],
  'Blenden & Wangen' => ['Passblende…', 'Wange…', 'Sockelblende…'],
  'Geräte' => ['Geräte in Schränke setzen', 'Geräte entfernen', 'Szenen Planung/Kunde/Zuschnitt anlegen', 'Kundenbild speichern…'],
  'Raum' => ['Raum anlegen…', 'Wände aus Linien…', 'Fenster/Tür einsetzen…', 'Öffnung bearbeiten…', 'Raum bearbeiten…']
}
alle_eintraege = kp.grep(Array)
gruppen.each do |g, eintraege|
  m = kp.find { |e| e.is_a?(UI::Menu) && e.titel == g }
  ist = m ? m.eintraege.map { |e| e.is_a?(Array) ? e.first : e } : []
  check(ist == eintraege, "Untermenü #{g}: #{ist.inspect}")
  alle_eintraege += m.eintraege.grep(Array) if m
end
check(alle_eintraege.all? { |_, blk| blk }, 'jeder Eintrag hat eine Aktion')

# Neue Schränke: jeder Menüeintrag öffnet ein Eingabefenster (HtmlDialog im Treppenplaner-Stil, kein
# UI.inputbox) mit der Tiefe (Vorschlag 520 mm, Oberschrank 400 mm, Eck-Oberschrank 350 mm,
# Hochschrank Kühlschrank 560 mm, weil Einbau-Kühlgeräte 550 mm Nischentiefe brauchen), und der Schrank wird nach „Einfügen“
# mit der eingegebenen Tiefe gebaut
require_relative 'eingabe_helfer'
module UI
  class HtmlDialog
    STYLE_DIALOG = 0
    class << self
      attr_accessor :alle
    end
    attr_reader :html, :callbacks, :optionen, :skripte
    def initialize(opt) = (@optionen, @callbacks, @skripte = opt, {}, []).tap { (HtmlDialog.alle ||= []) << self }
    def set_html(h) = @html = h
    def add_action_callback(n, &blk) = @callbacks[n] = blk
    def center = nil
    def show = @offen = true
    def visible? = @offen
    def close = @offen = false
    def execute_script(js) = @skripte << js
  end
  def self.inputbox(*) = raise('UI.inputbox benutzt – bitte Kuechenplaner::Eingabe.abfragen')
end
unterschraenke = kp.find { |e| e.is_a?(UI::Menu) && e.titel == 'Unterschränke' }.eintraege
schrank_eintraege = %w[Unterschränke Oberschränke Hochschränke].flat_map do |g|
  kp.find { |e| e.is_a?(UI::Menu) && e.titel == g }.eintraege.grep(Array).map { |t, b| [t, b, g] }
end
schrank_eintraege.each do |titel, blk, gruppe|
  next if titel == 'Unterschrank mit Tür…' # lädt Unterschrank.skp, eigener Test in Komponenten/unterschrank_tuer
  m = Sketchup.active_model = Sketchup::Model.new
  UI::HtmlDialog.alle = []
  blk.call
  d = UI::HtmlDialog.alle.last
  check(d && d.visible?, "#{titel}: öffnet ein Eingabefenster")
  next unless d
  felder = EingabeHelfer.felder(d.html)
  tiefe = felder.assoc('Tiefe Korpus')
  soll = titel.start_with?('Eck-Oberschrank') ? '350' : titel == 'Wandregal…' ? '250' : gruppe == 'Oberschränke' ? '400' : titel == 'Hochschrank Kühlschrank…' ? '560' : '520'
  check(tiefe && tiefe[1] == soll, "#{titel}: Dialog fragt die Tiefe ab, Vorschlag #{soll} mm (#{felder.inspect})")
  check(d.html.include?('<span class="unit">mm</span>'), "#{titel}: Einheit mm neben dem Feld")
  check(felder.assoc('Höhe'), "#{titel}: Dialog fragt auch die Höhe ab (#{felder.inspect})")
  check(d.html.include?('#f4f2ee') && d.html.include?('Einfügen</button>') && d.html.include?('Neuer Schrank'),
        "#{titel}: Fenster im Treppenplaner-Stil mit Knopf Einfügen")
  EingabeHelfer.ok(d, 'Tiefe Korpus' => '610', 'Schenkel A, hinten' => '1300', 'Schenkel B, links' => '1300')
  check(!d.visible? && d.skripte.empty?, "#{titel}: Fenster schließt nach dem Einfügen (#{d.skripte.inspect})")
  inst = m.entities.grep(Sketchup::ComponentInstance).last
  t = inst && inst.definition.get_attribute('dynamic_attributes', 'tiefe')
  check(t && (t * 2.54 - 61.0).abs < 1e-9, "#{titel}: Schrank mit eingegebener Tiefe 610 mm gebaut (#{t && t * 25.4})")
  # Eckschränke: jede Komponentenoption (TEXTBOX/LIST) steht schon im Anlage-Dialog
  next unless titel.start_with?('Eck')
  d_attr = inst.definition.attribute_dictionary('dynamic_attributes')
  optionen = d_attr.keys.select { |k| k.end_with?('_access') && %w[TEXTBOX LIST].include?(d_attr[k]) }
  check(optionen.size == felder.size, "#{titel}: alle #{optionen.size} Komponentenoptionen im Dialog (#{felder.size} Felder)")
end

# Oberschrank: Türen (eine links/rechts, zwei, keine) und Einlegeböden im Anlage-Dialog
m = Sketchup.active_model = Sketchup::Model.new
UI::HtmlDialog.alle = []
kp.find { |e| e.is_a?(UI::Menu) && e.titel == 'Oberschränke' }.eintraege.assoc('Oberschrank…')[1].call
d = UI::HtmlDialog.alle.last
check(EingabeHelfer.felder(d.html).assoc('Türen') && d.html.include?('Eine Tür, Anschlag rechts'), 'Oberschrank: Dialog fragt die Türen ab')
EingabeHelfer.ok(d, 'Türen' => 'Eine Tür, Anschlag rechts', 'Anzahl Einlegeböden' => '2')
inst = m.entities.grep(Sketchup::ComponentInstance).last
w = ->(k) { inst.definition.get_attribute('dynamic_attributes', k) }
check(w.('art_tuer') == 3.0 && w.('anz_einlegeboeden') == 2.0, "Oberschrank: eine Tür rechts aus dem Dialog (#{w.('art_tuer')}/#{w.('anz_einlegeboeden')})")

# Blindeck: Auswahlen im Dialog kommen am Schrank an
m = Sketchup.active_model = Sketchup::Model.new
UI::HtmlDialog.alle = []
unterschraenke.assoc('Eckschrank Blindeck…')[1].call
d = UI::HtmlDialog.alle.last
EingabeHelfer.ok(d, 'Variante' => 'Le Mans (Kesseböhmer)', 'Blindseite' => 'rechts (Tür links)',
                    'LeMans-Größe' => 'LeMans 45', 'Passleiste' => '60', 'Wand bis Front Nachbar' => '600', 'Breite' => '1000')
inst = m.entities.grep(Sketchup::ComponentInstance).last
w = ->(k) { inst.definition.get_attribute('dynamic_attributes', k) }
check(w.('variante') == 2.0 && w.('blindseite') == 1.0 && w.('lemans') == 45.0, "Blindeck: Variante/Blindseite/LeMans aus dem Dialog (#{w.('variante')}/#{w.('blindseite')}/#{w.('lemans')})")
check((w.('passleiste') * 25.4 - 60).abs < 1e-6 && (w.('tiefe_nachbar') * 25.4 - 600).abs < 1e-6, 'Blindeck: Passleiste und Nachbarmaß aus dem Dialog')
UI::HtmlDialog.alle = []
unterschraenke.assoc('Eckschrank Blindeck…')[1].call
d = UI::HtmlDialog.alle.last
EingabeHelfer.ok(d, 'Variante' => 'Le Mans (Kesseböhmer)', 'LeMans-Größe' => 'LeMans 60', 'Breite' => '900')
check(d.visible? && d.skripte.last.to_s.include?('mindestens 960 mm'), "Blindeck: LeMans 60 in 900 mm abgelehnt, Fenster bleibt offen (#{d.skripte.inspect})")
EingabeHelfer.ok(d, 'Türbreite' => '1200')
check(d.visible? && d.skripte.last.to_s.include?('passt nicht'), 'Blindeck: Türbreite größer als Breite abgelehnt')

# Eingabefenster: in jeder Erweiterung die gleiche Datei aus gemeinsam/eingabe.rb, geladen von main.rb;
# kein UI.inputbox mehr im Quelltext
vorlage = File.read(File.join(haupt, 'gemeinsam/eingabe.rb'), encoding: 'UTF-8')
SRC.each do |src|
  kopie = File.join(src, 'kuechenplaner_gemeinsam/eingabe.rb')
  check(File.exist?(kopie) && File.read(kopie, encoding: 'UTF-8') == vorlage, "#{kopie}: fehlt oder veraltet (./build_rbz.sh ausführen)")
  name = File.basename(Dir[File.join(src, '*.rb')].first, '.rb')
  main = File.read(File.join(src, name, 'main.rb'), encoding: 'UTF-8')
  check(main.include?("require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'eingabe')"), "#{name}: lädt das Eingabefenster")
  Dir[File.join(src, '**/*.rb')].reject { |f| f.include?('kuechenplaner_gemeinsam') }.each do |f|
    check(!File.read(f, encoding: 'UTF-8').include?('UI.inputbox'), "#{f}: UI.inputbox statt Kuechenplaner::Eingabe.abfragen")
  end
end
check(unterschraenke.size == 14, 'alle Unterschränke geprüft')

# Neu laden ohne Neustart: in jeder Erweiterung die gleiche Datei aus gemeinsam/neuladen.rb, geladen von main.rb;
# das gemeinsame Menü darf mehrfach laufen (kein „unless defined?“ mehr, sonst bliebe nach dem Neuladen der alte Stand)
vorlage = File.read(File.join(haupt, 'gemeinsam/neuladen.rb'), encoding: 'UTF-8')
SRC.each do |src|
  kopie = File.join(src, 'kuechenplaner_gemeinsam/neuladen.rb')
  check(File.exist?(kopie) && File.read(kopie, encoding: 'UTF-8') == vorlage, "#{kopie}: fehlt oder veraltet (./build_rbz.sh ausführen)")
  name = File.basename(Dir[File.join(src, '*.rb')].first, '.rb')
  main = File.read(File.join(src, name, 'main.rb'), encoding: 'UTF-8')
  check(main.include?("require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'neuladen')"), "#{name}: lädt den Neulade-Wächter")
  check(!main.include?('unless defined?(Kuechenplaner.schrank)'), "#{name}: gemeinsames Menü nicht neu ladbar")
  # weitere Dateien der Erweiterung mit load, nicht require (sonst bleibt beim Neuladen der alte Code)
  check(main.scan(/^\s*require(?:_relative)? .*(?:PATH|__dir__, ['"](?!\.\.)|File\.dirname\(__FILE__\))/).reject { |z| z.include?('kuechenplaner_gemeinsam') }.empty?,
        "#{name}: eigene Dateien mit require statt load")
end

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
