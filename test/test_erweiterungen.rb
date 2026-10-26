# Test ohne SketchUp: alle Komponenten und der TCN-Export sind Erweiterungen (.rbz)
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

SRC = Dir[File.join(haupt, 'Komponenten/*/src')].sort + [File.join(haupt, 'sketchup-tcn-export-plugin/src')]
RBZ = ->(src) { d = File.dirname(src); n = File.basename(d); File.join(d, "#{n == 'sketchup-tcn-export-plugin' ? 'schrank_cnc' : n}.rbz") }
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
  s = main[/^# Gemeinsames Untermenü.*?^end unless defined\?\(Kuechenplaner\.menu\)\n/m]
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
rollen = Dir[File.join(haupt, 'Komponenten/*/src/*/main.rb')].map { |f| File.read(f, encoding: 'UTF-8')[/  ROLLEN = \{.*?\}\.freeze/m] }
check(rollen.size == komponenten.size && rollen.all? && rollen.uniq.size == 1,
      "ROLLEN-Tabelle in allen #{komponenten.size} Komponenten gleich (#{rollen.compact.size} gefunden, #{rollen.compact.uniq.size} Varianten)")

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
titel = kp.map { |e| e.is_a?(Array) ? e.first : e }
soll = ['Apothekerschrank…', 'Hochschrank…', 'Hochschrank Geräte…', 'Oberschrank…', 'Unterschrank Geschirrspüler…',
        'Unterschrank Handtuchauszug…', 'Unterschrank Kochfeld mit Abzug…', 'Unterschrank mit Schubladen…',
        'Spülenschrank…', 'Unterschrank mit Tür…', :trenner, 'TCN exportieren…', 'Frontfarbe und Griffe ändern…']
check(titel == soll, "Einträge im Küchenplaner-Menü: #{titel.inspect}")
check(kp.grep(Array).all? { |_, blk| blk }, 'jeder Eintrag hat eine Aktion')

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
