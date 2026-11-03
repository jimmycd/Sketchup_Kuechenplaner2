# Test ohne SketchUp: gemeinsam/einstellungen.rb – Sockelhöhe und Abstände der Küche,
# gespeichert im Modell, Rückfall auf den letzten Wert des Rechners und Standardwerte.
haupt = File.expand_path('..', __dir__)
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

module Sketchup
  class Model
    def initialize = @a = {}
    def get_attribute(d, k, std = nil) = @a.fetch([d, k], std)
    def set_attribute(d, k, v) = @a[[d, k]] = v
  end

  class << self
    attr_accessor :active_model
    def defaults = (@defaults ||= {})
    def read_default(s, k, d = nil) = defaults.fetch([s, k], d)
    def write_default(s, k, v) = defaults[[s, k]] = v
  end
end

load File.join(haupt, 'gemeinsam/einstellungen.rb')
E = Kuechenplaner::Einstellungen
m1 = Sketchup.active_model = Sketchup::Model.new

# Standardwerte
check(E.sockelhoehe == 100 && E.wandabstand == 0 && E.abstand_oberschrank == 550 && E.arbeitsplatte_staerke == 40 &&
      E.unterschrank_hoehe == 700, 'Standardwerte 100 / 0 / 550 / 40 / 700 mm')
check(E.arbeitsplatte_oberkante == 840 && E.oberschrank_unterkante == 1390, "Oberschrank-Unterkante 1390 mm (#{E.oberschrank_unterkante})")
check(E.oberschrank_unterkante(nil, 50) == 1440, 'Fußboden höher: alles um den Fußboden verschoben')

# speichern im Modell, Komma erlaubt
E.setzen('sockelhoehe', '120,5')
check(E.sockelhoehe == 120.5 && m1.get_attribute(E::DICT, 'sockelhoehe') == 120.5, 'Sockelhöhe im Modell gespeichert')

# anderes Modell: hat selbst nichts gespeichert, nimmt den letzten Wert des Rechners
m2 = Sketchup::Model.new
check(E.sockelhoehe(m2) == 120.5, 'neues Modell übernimmt den zuletzt eingegebenen Wert')
E.setzen('sockelhoehe', 80, m2)
check(E.sockelhoehe(m1) == 120.5 && E.sockelhoehe(m2) == 80, 'jedes Modell behält seinen Wert')

# Grenzen
begin
  E.setzen('sockelhoehe', 301)
  check(false, 'Sockelhöhe 301 mm muss abgelehnt werden')
rescue ArgumentError => e
  check(e.message.include?('0–300'), "Meldung nennt den Bereich: #{e.message}")
end
check(E.sockelhoehe(m1) == 120.5, 'abgelehnter Wert ändert nichts')

# Dialog-Hilfen: alle prüfen, dann speichern
check(E.prompts.size == 5 && E.prompts.all? { |p| p.start_with?("#{E::GRUPPE}: ") && p.end_with?('(mm)') }, 'Beschriftungen mit Gruppe und Einheit')
check(E.vorgaben(m1) == %w[120.5 0 550 40 700], "Vorgaben: #{E.vorgaben(m1)}")
begin
  E.uebernehmen(%w[110 20 abc 38 720], m1)
  check(false, 'Text statt Zahl muss abgelehnt werden')
rescue ArgumentError
  check(E.sockelhoehe(m1) == 120.5 && E.wandabstand(m1) == 0, 'bei Fehler wird nichts halb übernommen')
end
check(E.uebernehmen(%w[110 20 600 38 720], m1) && E.wandabstand(m1) == 20 && E.oberschrank_unterkante(m1) == 110 + 720 + 38 + 600,
      'alle fünf Werte übernommen')

# jede Erweiterung, die die Einstellungen lädt, hat die aktuelle Kopie
Dir[File.join(haupt, '{Komponenten/*,sketchup-tcn-export-plugin,kuechenplaner-update,kuechenplaner-symbolleiste}/src')].each do |src|
  kopie = File.join(src, 'kuechenplaner_gemeinsam/einstellungen.rb')
  check(File.exist?(kopie) && File.read(kopie) == File.read(File.join(haupt, 'gemeinsam/einstellungen.rb')),
        "#{kopie}: fehlt oder veraltet (./build_rbz.sh ausführen)")
end
%w[sketchup-tcn-export-plugin/src/jt_schrank_cnc Komponenten/raum/src/raum Komponenten/arbeitsplatte/src/arbeitsplatte].each do |d|
  check(File.read(File.join(haupt, d, 'main.rb')).include?("'kuechenplaner_gemeinsam', 'einstellungen')"), "#{d}/main.rb lädt die Einstellungen")
end

puts $fehler.zero? ? 'OK: Einstellungen Sockel und Abstände' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
