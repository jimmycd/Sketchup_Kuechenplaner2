# Test ohne SketchUp: allgemeine Regeln von Jürgen, die für ALLE Module gelten
# (Konsistenzcheck 2026-11-02). Jede neue Komponente fällt hier automatisch mit hinein.
#  1. TCN nur mit Werkzeugen aus der CNC-Werkzeugliste (Fräser, Bohrer blind/durch, waagrecht nur Ø8)
#  2. Fräsungen in Zustellschritten von höchstens 20 mm
#  3. Bögen als W#2125 mit EW2 automatisch, Vorzeichen wie in der TPA-Ansicht
#  4. Kein OpenCutList mehr (Material, Kanten und Tag bleiben Pflicht)
#  5. Timer, die eine Meldung öffnen können, halten sich zuerst an (UI.stop_timer)
haupt = File.expand_path('..', __dir__)
$LOAD_PATH.unshift(File.join(haupt, 'sketchup-tcn-export-plugin/test'))
require 'sketchup_mock'

$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

# --- CNC-Werkzeugliste (Jürgen, 2026-11-01) ---
FRAESER = [1000, 1001, 1004, 1100, 1200, 1300, 1400, 2200, 5405, 5408].freeze # Fläche 1
BOHRER_BLIND = [3, 4, 5, 6, 7, 8, 9, 10, 12, 15, 16, 18, 20, 25, 35].freeze   # Fläche 1
BOHRER_DURCH = [5, 6, 8, 10].freeze                                            # Fläche 1
BOHRER_WAAGRECHT = [8].freeze                                                  # Fläche 3–6 (T71/T61)
# Ausnahme aus Jürgens eigener Vorlage Seite.tcn: Ø3 × 21 durch die Seite in die Strebe
AUSNAHME_DURCH = { 3 => 21.0 }.freeze
ZUSTELLUNG = 20.0

# --- alle Schränke einmal bauen und exportieren ---
$VERBOSE = nil
Dir[File.join(haupt, 'Komponenten/*/src/*/main.rb')].sort.each { |m| load m }
load File.join(haupt, 'sketchup-tcn-export-plugin/src/jt_schrank_cnc/main.rb')
S = JTools::SchrankCnc

# jede Schrank-Komponente mit erstellen(eingabe) und dazu die Varianten mit eigenen Bearbeitungen
schraenke = ObjectSpace.each_object(Module).select do |m|
  m.respond_to?(:erstellen) && m.name && m.method(:erstellen).source_location&.first&.include?('/Komponenten/')
end
varianten = {
  'Eckschrank' => [[{}], [{}, { l_form: true }], [{ 'Variante' => 2.0, 'LeMans' => 50.0, 'Breite' => 100.0 }]],
  'OberschrankKlappe' => [[{}], [{ 'Art_Klappe' => 2.0, 'Hoehe' => 72.0 }]],
  'RegalAbschluss' => [[{ 'Form' => 0.0 }], [{ 'Form' => 1.0 }], [{ 'Form' => 2.0 }]],
  'Blenden' => [[:wange], [:passblende]] # erstellen(art, eingabe); Sockelblende über erstellen_sockelblende
}
dateien = []
gebaut = []
schraenke.each do |m|
  (varianten[m.name.split('::').last] || [[{}]]).each do |eingabe, kw|
    model = Sketchup.active_model = Sketchup::Model.new
    begin
      kw ? m.erstellen(eingabe, **kw) : m.erstellen(eingabe)
      d, = S::Export.erzeugen(model)
      dateien.concat(d)
      gebaut << m.name
    rescue StandardError => e
      check(false, "#{m.name}: Schrank bauen/exportieren: #{e.class} #{e.message}")
    end
  end
end
check(gebaut.uniq.size >= 20, "alle Schrank-Komponenten exportiert: #{gebaut.uniq.sort}")
check(dateien.size > 100, "TCN-Dateien erzeugt: #{dateien.size}")

def seiten(text)
  side = nil
  text.split(/\r?\n/).each_with_object(Hash.new { |h, k| h[k] = [] }) do |z, h|
    if z =~ /\ASIDE#(\d+)\{/ then side = Regexp.last_match(1).to_i
    elsif z == '}SIDE' then side = nil
    elsif side && z.start_with?('W#') then h[side] << z
    end
  end
end

zahl = ->(z, feld) { z[/ #{feld}=(-?[\d.]+)/, 1]&.to_f }
falsch = Hash.new { |h, k| h[k] = [] }
dateien.each do |d|
  ds = d.text[/DS=([\d.]+)/, 1].to_f
  seiten(d.text).each do |side, zeilen|
    zeilen.each do |z|
      # Fräser: Bahnen (W#89 #205), Formatieren (squad #8502), Taschen (rect #8522)
      w = if z.start_with?('W#89{') then zahl.(z, '#205')
          elsif z.include?('squad.tmcr') then zahl.(z, '#8502')
          elsif z.include?('rect.tmcr') then zahl.(z, '#8522')
          end
      falsch[:fraeser] << "#{d.name}: #{w.to_i}" if w && !FRAESER.include?(w.to_i)
      falsch[:fraeser_flaeche] << "#{d.name} Fläche #{side}" if w && side != 1

      # Fräsungen: Zustellung höchstens 20 mm je Durchgang (Bahn W#89 #3, Tasche rect #8514)
      t = z.start_with?('W#89{') ? zahl.(z, '#3') : z.include?('rect.tmcr') ? zahl.(z, '#8514') : nil
      falsch[:zustellung] << "#{d.name}: #{t.abs}" if t && t.abs > ZUSTELLUNG + 1e-6

      # Bohrer: Einzelbohrung W#81 (#1002, Tiefe #3), Reihe fittingx/y (#8522, Tiefe #8513)
      dm, tief = if z.start_with?('W#81{') then [zahl.(z, '#1002'), zahl.(z, '#3')]
                 elsif z.include?('fitting') then [zahl.(z, '#8522'), zahl.(z, '#8513')]
                 end
      next unless dm
      dm = dm.round(3)
      tief = tief.abs
      if side != 1
        falsch[:waagrecht] << "#{d.name} Fläche #{side}: Ø#{dm}" unless BOHRER_WAAGRECHT.include?(dm)
      elsif tief >= ds - 1e-6
        ok = BOHRER_DURCH.include?(dm) || AUSNAHME_DURCH[dm.to_i] == tief
        falsch[:durch] << "#{d.name}: Ø#{dm} × #{tief} (Stärke #{ds})" unless ok
      else
        falsch[:blind] << "#{d.name}: Ø#{dm}" unless BOHRER_BLIND.include?(dm)
      end
    end
  end
end
check(falsch[:fraeser].empty?, "Fräser nicht in der Werkzeugliste: #{falsch[:fraeser].uniq.first(10)}")
check(falsch[:fraeser_flaeche].empty?, "Fräsen nur auf Fläche 1: #{falsch[:fraeser_flaeche].uniq.first(10)}")
check(falsch[:zustellung].empty?, "Fräsung tiefer als 20 mm in einem Durchgang: #{falsch[:zustellung].uniq.first(10)}")
check(falsch[:blind].empty?, "Bohrer (blind) nicht in der Werkzeugliste: #{falsch[:blind].uniq.first(10)}")
check(falsch[:durch].empty?, "Durchgangsbohrung nur mit Ø5/6/8/10: #{falsch[:durch].uniq.first(10)}")
check(falsch[:waagrecht].empty?, "waagrecht nur Ø8 (T71/T61): #{falsch[:waagrecht].uniq.first(10)}")

# Werkzeugnummern auch im Quelltext (z. B. Arbeitsplatte, die hier nicht exportiert wird)
plugin = Dir[File.join(haupt, 'sketchup-tcn-export-plugin/src/jt_schrank_cnc/*.rb')]
plugin.each do |f|
  File.read(f, encoding: 'UTF-8').scan(/(?<!\w)werkzeug: *(\d+)/).flatten.map(&:to_i).each do |w|
    check(FRAESER.include?(w), "#{File.basename(f)}: Fräser #{w} nicht in der Werkzeugliste")
  end
end

# Bögen nur als kurze Geraden, kein W#2125 (Jürgen 2026-11-05: Arbeitsplatte zurückgerollt,
# runder Deckel des Abschlussregals meldete in TPA "Radius ungültig")
boegen = dateien.flat_map { |d| d.text.split(/\r?\n/).grep(/\AW#2125\{/).map { |l| "#{d.name}: #{l}" } }
check(boegen.empty?, "keine Kreisbögen W#2125 in den TCN: #{boegen.first(3)}")
plugin.each do |f|
  check(!File.read(f, encoding: 'UTF-8').match?(/"W#2125\{/), "#{File.basename(f)}: erzeugt W#2125")
end

# --- Quelltext aller Module ---
quellen = Dir[File.join(haupt, '{Komponenten/*,sketchup-tcn-export-plugin,kuechenplaner-update,kuechenplaner-symbolleiste}/src/**/*.{rb,html,js}')]
          .reject { |f| f.include?('/bin_packing_2d/') } # Code aus OCL (GPL), Herkunft in THIRD_PARTY.md
doku = Dir[File.join(haupt, '{Komponenten/*,sketchup-tcn-export-plugin,kuechenplaner-update,kuechenplaner-symbolleiste}/README.md')] +
       [File.join(haupt, 'README.md')]

# Kein OpenCutList mehr: erlaubt ist nur der Name des Material-Wörterbuchs (Datenformat, bleibt)
ocl = (quellen + doku).flat_map do |f|
  File.readlines(f, encoding: 'UTF-8').each_with_index.filter_map do |z, i|
    next if z.include?('ladb_opencutlist') || z.include?('GPL') # Wörterbuch-Name und Lizenzhinweis (BinPacking2D) bleiben
    "#{f.delete_prefix("#{haupt}/")}:#{i + 1}" if z =~ /opencutlist|\bOCL\b/i
  end
end
check(ocl.empty?, "OpenCutList/OCL erwähnt (#{ocl.size}×): #{ocl.first(10)}")

# Eingabefenster im Treppenplaner-Stil (Kuechenplaner::Eingabe), kein natives UI.inputbox mehr
quellen.grep(/\.rb\z/).reject { |f| f.include?('/kuechenplaner_gemeinsam/') }.each do |f|
  t = File.read(f, encoding: 'UTF-8')
  check(!t.match?(/UI\.inputbox\(/), "#{f.delete_prefix("#{haupt}/")}: UI.inputbox statt Kuechenplaner::Eingabe")
  # eigene HtmlDialoge übernehmen das Aussehen der Eingabefenster
  check(!t.include?('HtmlDialog.new') || t.include?('Eingabe.css'), "#{f.delete_prefix("#{haupt}/")}: HtmlDialog ohne Kuechenplaner::Eingabe.css")
end

# Timer: öffnet der Block womöglich ein Fenster (alles außer dem Menüaufbau), hält er sich zuerst an
quellen.grep(/\.rb\z/).each do |f|
  z = File.readlines(f, encoding: 'UTF-8')
  z.each_with_index do |l, i|
    next unless l =~ /UI\.start_timer\(/
    block = z[(i + 1)..(i + 3)].join
    menue = block.include?('Kuechenplaner.menu') || block.include?('add_item')
    check(menue || (l =~ /(\w+) = UI\.start_timer/ && z[i + 1].include?("UI.stop_timer(#{Regexp.last_match(1)})")),
          "#{f.delete_prefix("#{haupt}/")}:#{i + 1}: Timer ohne UI.stop_timer als erste Zeile")
  end
end

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
