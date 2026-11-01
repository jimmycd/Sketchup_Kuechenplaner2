# Test ohne SketchUp: Anleimer-Regel für alle Unterschränke (Jürgen, 2026-10-28):
# Boden und Einlegeboden vorne, Strebe vorn nur vorne, Strebe hinten keine.
# Prüft die KANTEN-Tabellen der Generatoren (Unterschrank mit Tür: siehe dessen Test).
haupt = File.expand_path('..', __dir__)
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

SOLL = { 'Boden' => %i[ymin], 'Einlegeboden' => %i[ymin], 'StrebeVorn' => %i[ymin], 'StrebeHinten' => [] }.freeze
# Kochfeld: vordere Strebe liegt verdeckt hinter der Blende, deshalb ohne Kante
AUSNAHMEN = { 'unterschrank_kochfeld' => { 'StrebeVorn' => [] } }.freeze

geprueft = 0
Dir[File.join(haupt, 'Komponenten/unterschrank_*/src/*/main.rb')].sort.each do |f|
  k = f[%r{Komponenten/([^/]+)/}, 1]
  next if k == 'unterschrank_tuer' # Teile aus der .skp, Anleimer nach Blickrichtung, eigener Test
  tabelle = File.read(f, encoding: 'UTF-8')[/^  KANTEN = \{\n(.*?)^  \}/m, 1] or next
  kanten = tabelle.scan(/'(\w+)'\s*=>\s*(%i\[[^\]]*\]|\[\])/).to_h { |n, v| [n, eval(v)] }
  SOLL.merge(AUSNAHMEN.fetch(k, {})).each do |teil, soll|
    next unless kanten.key?(teil)
    geprueft += 1
    check(kanten[teil] == soll, "#{k}: Anleimer #{teil} #{kanten[teil].inspect}, soll #{soll.inspect}")
  end
end
check(geprueft >= 10, "zu wenig geprüft (#{geprueft})")
puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
