# Test ohne SketchUp: Fenster "Komponentenoptionen" bleibt lesbar
# - keine lange "description" mehr (machte das Fenster zu lang/zu breit), nur die Kurzfassung als "summary"
# - Listen-Optionen mit Umlauten so kodiert, wie das DC-Fenster sie liest (unescape, Latin-1)
haupt = File.expand_path('..', __dir__)

$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

dateien = Dir[File.join(haupt, 'Komponenten/*/src/*/main.rb')].sort
mit_hilfe = dateien.select { |f| File.read(f, encoding: 'UTF-8').include?('def self.hilfe(') }
check(mit_hilfe.size >= 20, "Komponenten mit Kurzhilfe gefunden: #{mit_hilfe.size}")

mit_hilfe.each do |f|
  s = File.read(f, encoding: 'UTF-8')
  n = File.basename(File.dirname(f))
  check(s !~ /^\s*HILFE(_L)? = \[/, "#{n}: lange Hilfe (HILFE) entfernt")
  check(!s.include?("'description' => ['Description'"), "#{n}: keine description im Fenster")
  check(s.include?("d.set_attribute(DICT, 'summary', kurz)"), "#{n}: summary gesetzt")
  check(!s.include?("_summary_access\", 'VIEW'"), "#{n}: summary ohne eigene Zeile")
end

# Jede Komponente mit Listen-Optionen kodiert sie über dc_optionen
dateien.each do |f|
  s = File.read(f, encoding: 'UTF-8')
  next unless s.include?('_options')
  n = File.basename(File.dirname(f))
  check(s.include?('"_#{k}_options", dc_optionen(options))') && s.include?('def self.dc_optionen('),
        "#{n}: Listen-Optionen über dc_optionen")
end

# dc_optionen ist in allen Komponenten wortgleich; einmal ausführlich prüfen
bloecke = dateien.map { |f| File.read(f, encoding: 'UTF-8')[/^  def self\.dc_optionen\(text\)\n.*?\n  end\n/m] }.compact
check(bloecke.uniq.size == 1, "dc_optionen überall gleich (#{bloecke.uniq.size} Varianten)")
m = Module.new
m.module_eval(bloecke.first)
{
  '&Ein%20Auszug%20%C3%BCber%20die%20volle%20H%C3%B6he=0&Schublade%20oben%20%2B%20Auszug=1&' =>
    '&Ein%20Auszug%20%FCber%20die%20volle%20H%F6he=0&Schublade%20oben%20%2B%20Auszug=1&',
  '&Tür links=0&Tür rechts=1&' => '&T%FCr links=0&T%FCr rechts=1&',
  '&1=1&2=2&' => '&1=1&2=2&',
  '&3%E2%80%934=1&' => '&3%u20134=1&',
  '' => '',
  nil => ''
}.each do |ein, soll|
  ist = m.dc_optionen(ein)
  check(ist == soll, "dc_optionen(#{ein.inspect}) = #{ist.inspect}, soll #{soll.inspect}")
end
# zurück wie JavaScript unescape(): Zeichen für Zeichen -> wieder die richtigen Umlaute
unescape = ->(t) { t.gsub(/%u([0-9A-F]{4})|%([0-9A-F]{2})/) { [($1 || $2).hex].pack('U') } }
check(unescape.call(m.dc_optionen('&Ein%20Auszug%20%C3%BCber%20die%20volle%20H%C3%B6he=0&')) == '&Ein Auszug über die volle Höhe=0&',
      'unescape ergibt die Umlaute')

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
