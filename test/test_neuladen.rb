# Test ohne SketchUp: Neu laden zur Laufzeit (gemeinsam/neuladen.rb).
# Alle Erweiterungen aus Kuechenplaner_alle.rbz liegen in einem Plugins-Ordner und sind
# geladen wie in SketchUp. Dann werden Dateien geändert wie beim Installieren einer
# .rbz über den Extension Manager: der Wächter lädt sie neu, ohne Neustart, ohne
# doppelte Menüeinträge oder Icons, und meldet Fehler, statt abzustürzen.
require 'tmpdir'
require 'fileutils'
haupt = File.expand_path('..', __dir__)
$LOAD_PATH.unshift(File.join(haupt, 'sketchup-tcn-export-plugin/test'))
require 'sketchup_mock'

$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

# leere sketchup.rb / extensions.rb für die Lade-Dateien
stubs = Dir.mktmpdir
%w[sketchup.rb extensions.rb].each { |f| File.write(File.join(stubs, f), "# mock\n") }
$LOAD_PATH.unshift(stubs)
PLUGINS = Dir.mktmpdir

module UI
  class Menu
    attr_reader :titel, :eintraege
    def initialize(titel = nil) = (@titel, @eintraege = titel, [])
    def add_submenu(t) = Menu.new(t).tap { |m| @eintraege << m }
    def add_item(t, &blk) = @eintraege << [t, blk]
    def add_separator = @eintraege << :trenner
  end
  @menues = {}
  @timer = {}
  @nr = 0
  @meldungen = []
  class << self
    attr_reader :meldungen, :timer
    def menu(n) = (@menues[n] ||= Menu.new(n))
    def messagebox(text, _typ = nil) = @meldungen << text
    def start_timer(_s, wiederholen = false, &blk) = (@timer[@nr += 1] = [wiederholen, blk]) && @nr
    def stop_timer(id) = @timer.delete(id)

    # einmalige Timer ablaufen lassen (Menüaufbau nach dem Start)
    def einmalige
      @timer.select { |_, (w, _)| !w }.each { |id, (_, blk)| @timer.delete(id) && blk.call }
    end

    # ein Takt aller wiederholten Timer (Wächter)
    def takt
      @timer.select { |_, (w, _)| w }.each_value { |_, blk| blk.call }
    end
  end
end

class SketchupExtension
  attr_accessor :description, :version, :creator, :copyright
  attr_reader :name, :extension_path
  attr_writer :geladen
  def initialize(name, pfad)
    @name = name
    @extension_path = File.expand_path("#{pfad}.rb", PLUGINS)
  end

  def loaded? = @geladen
  def laden!
    @geladen = true
    load @extension_path
  end
end

module Sketchup
  @erweiterungen = []
  class << self
    attr_accessor :status_text
    def extensions = @erweiterungen
    def register_extension(ext, laden)
      @erweiterungen << ext
      ext.laden! if laden
    end
    def read_default(*) = nil
    def write_default(*) = nil
  end
end
Sketchup.active_model = Sketchup::Model.new

# Installation wie SketchUp: alle Dateien der Gesamt-.rbz, Lade-Dateien alphabetisch
system('unzip', '-q', '-o', File.join(haupt, 'Kuechenplaner_alle.rbz'), '-d', PLUGINS) || abort('unzip fehlt')
$VERBOSE = nil
Dir[File.join(PLUGINS, '*.rb')].sort.each { |l| load l }
UI.einmalige
Kuechenplaner::Neuladen.plugins_ordner = PLUGINS
Kuechenplaner::Neuladen.stand_merken

kp = UI.menu('Extensions').eintraege.first
zaehlen = lambda do
  menue = ->(m) { m.eintraege.sum { |e| e.is_a?(UI::Menu) ? 1 + menue.(e) : 1 } }
  menue.(UI.menu('Extensions'))
end
eintraege = zaehlen.()
tb = UI::Toolbar.alle.last
icons = tb.befehle.size
alle_erw = Kuechenplaner::Neuladen.erweiterungen

check(UI.menu('Extensions').eintraege.size == 1, 'ein Küchenplaner-Menü')
check(kp.eintraege.last.is_a?(Array) && kp.eintraege.last.first == 'Küchenplaner neu laden', 'Menüpunkt „Küchenplaner neu laden“ ganz unten')
check(alle_erw.size == Dir[File.join(PLUGINS, '*.rb')].size, "alle Erweiterungen erkannt: #{alle_erw.size}")
check(UI.timer.count { |_, (w, _)| w } == 1, "genau ein Wächter, obwohl #{alle_erw.size} Erweiterungen ihn laden")

aendern = lambda do |rel, text|
  f = File.join(PLUGINS, rel)
  File.write(f, File.read(f, encoding: 'UTF-8') + text)
  t = File.mtime(f) + 5
  File.utime(t, t, f)
end
neu = -> { Sketchup.status_text.to_s }

# 1) Nichts geändert: der Wächter tut nichts
Sketchup.status_text = nil
2.times { UI.takt }
check(Sketchup.status_text.nil?, "ohne Änderung kein Neuladen: #{Sketchup.status_text.inspect}")

# 2) Komponente geändert (z. B. neue .rbz über den Extension Manager): erst beim zweiten Takt laden
aendern.('hochschrank/main.rb', "\nmodule Hochschrank\n  def self.neuladen_test\n    'neu'\n  end\nend\n")
UI.takt
check(!Hochschrank.respond_to?(:neuladen_test), 'nicht laden, solange die Installation noch läuft')
UI.takt
check(Hochschrank.respond_to?(:neuladen_test) && Hochschrank.neuladen_test == 'neu', 'neuer Code ist aktiv, ohne Neustart')
check(neu.() == 'Küchenplaner: neu geladen: hochschrank', "nur der Hochschrank neu geladen: #{neu.().inspect}")
check(UI.meldungen.empty?, "kein Fenster beim automatischen Neuladen: #{UI.meldungen.inspect}")
check(zaehlen.() == eintraege, 'keine doppelten Menüeinträge')
Sketchup.status_text = nil
UI.takt
check(Sketchup.status_text.nil?, 'danach nicht noch einmal')

# 3) Neuer Code im Menüeintrag: der vorhandene Eintrag ruft die neue Methode auf
aendern.('hochschrank/main.rb', "\nmodule Hochschrank\n  def self.dialog\n    $hochschrank_neu = true\n  end\nend\n")
2.times { UI.takt }
hs = kp.eintraege.find { |e| e.is_a?(UI::Menu) && e.titel == 'Hochschränke' }.eintraege.find { |t, _| t == 'Hochschrank…' }
hs[1].call
check($hochschrank_neu, 'alter Menüeintrag nutzt den neuen Code')

# 4) Gemeinsame Datei geändert: wird neu geladen (main.rb lädt sie nur einmal mit require)
aendern.('kuechenplaner_gemeinsam/eingabe.rb', "\nmodule Kuechenplaner\n  module Eingabe\n    def self.neuladen_test\n      'neu'\n    end\n  end\nend\n")
2.times { UI.takt }
check(Kuechenplaner::Eingabe.respond_to?(:neuladen_test), 'gemeinsames Eingabefenster neu geladen')

# 5) Fehler in einer Datei: Meldung, alter Stand bleibt, die anderen werden geladen
aendern.('oberschrank/main.rb', "\ndef kaputt(\n")
aendern.('apothekerschrank/main.rb', "\nmodule Apothekerschrank\n  def self.neuladen_test\n    'neu'\n  end\nend\n")
UI.meldungen.clear
2.times { UI.takt }
check(UI.meldungen.size == 1 && UI.meldungen.first.include?('oberschrank: SyntaxError'), "Fehler gemeldet: #{UI.meldungen.inspect}")
check(Apothekerschrank.respond_to?(:neuladen_test), 'andere Erweiterung trotzdem geladen')
check(Oberschrank.respond_to?(:dialog), 'Oberschrank läuft mit altem Stand weiter')
UI.meldungen.clear
2.times { UI.takt }
check(UI.meldungen.empty?, 'Fehler nur einmal gemeldet')
FileUtils.cp(File.join(haupt, 'Komponenten/oberschrank/src/oberschrank/main.rb'), File.join(PLUGINS, 'oberschrank/main.rb'))
2.times { UI.takt }

# 6) Ausgeschaltete Erweiterung bleibt aus
Sketchup.extensions.find { |e| e.extension_path.end_with?('/blenden/main.rb') }.geladen = false
aendern.('blenden/main.rb', "\nmodule Blenden\n  def self.neuladen_test\n    'neu'\n  end\nend\n")
2.times { UI.takt }
check(!Blenden.respond_to?(:neuladen_test), 'ausgeschaltete Erweiterung nicht geladen')
Sketchup.extensions.find { |e| e.extension_path.end_with?('/blenden/main.rb') }.geladen = true

# 7) Menü „Küchenplaner neu laden“: alles, mit Meldung; Menü und Symbolleiste bleiben einfach
UI.meldungen.clear
kp.eintraege.last[1].call
erwartet = alle_erw.size
check(neu.().scan(',').size + 1 == erwartet, "alle #{erwartet} Erweiterungen neu geladen: #{neu.()}")
check(UI.meldungen.size == 1 && UI.meldungen.first.include?('ohne Neustart'), "Meldung: #{UI.meldungen.inspect}")
check(Blenden.respond_to?(:neuladen_test), 'jetzt auch Blenden (eingeschaltet)')
check(zaehlen.() == eintraege, "Menü unverändert nach vollem Neuladen (#{zaehlen.()} statt #{eintraege})")
check(UI::Toolbar.alle.size == 1 && tb.befehle.size == icons, 'Symbolleiste nicht doppelt')
check(UI.timer.count { |_, (w, _)| w } == 1, 'weiter genau ein Wächter')

# 8) Symbolleiste: Icons holen ihre Aktion beim Klick; neue Icons kommen hinten dazu
alt = KuechenplanerSymbolleiste::BEFEHLE
geklickt = nil
KuechenplanerSymbolleiste.send(:remove_const, :BEFEHLE)
KuechenplanerSymbolleiste.const_set(:BEFEHLE, [alt[0][0..3] + [-> { geklickt = :neu_0 }]] + alt[1..] +
                                              [['tcn', 'Neu', 'neues Icon', -> { true }, -> { geklickt = :neues_icon }]])
tb.befehle[0].aktion.call
check(geklickt == :neu_0, 'vorhandenes Icon ruft die neue Aktion auf')
KuechenplanerSymbolleiste.symbolleiste
check(tb.befehle.size == icons + 1 && UI::Toolbar.alle.size == 1, 'neues Icon in derselben Symbolleiste ergänzt')
tb.befehle.last.aktion.call
check(geklickt == :neues_icon && tb.befehle.last.validation.call == MF_ENABLED, 'neues Icon funktioniert')

# 9) Neue Menügruppe aus einem Update: wird angehängt statt Fehler
check(Kuechenplaner.untermenu('Testgruppe').is_a?(UI::Menu) && kp.eintraege.last.titel == 'Testgruppe', 'neue Gruppe angehängt')

# 10) Plugins aktualisieren lädt selbst neu und merkt sich den Stand: der Wächter lädt nicht doppelt
aendern.('hochschrank/main.rb', "\n# geändert\n")
KuechenplanerUpdate.plugins_ordner = PLUGINS
check(KuechenplanerUpdate.neu_laden(['hochschrank/main.rb'], []) == ['hochschrank'], 'Aktualisieren lädt den Hochschrank')
Sketchup.status_text = nil
2.times { UI.takt }
check(Sketchup.status_text.nil?, "Wächter lädt danach nicht noch einmal: #{Sketchup.status_text.inspect}")

FileUtils.rm_rf([PLUGINS, stubs])
puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
