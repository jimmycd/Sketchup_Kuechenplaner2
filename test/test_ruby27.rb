# Test ohne SketchUp: der Quelltext der Erweiterungen muss auch mit Ruby 2.7 laufen
# (SketchUp 2021–2023). Methoden in Kurzform "def x = ..." gibt es erst ab Ruby 3.0;
# damit lädt die Erweiterung in älterem SketchUp nicht und erscheint nicht im Menü.
# Die vollständige Prüfung mit Ruby 2.7 (ruby -c) läuft in GitHub Actions.
haupt = File.expand_path('..', __dir__)
KURZ = /^\s*def\s+(?:self\.)?\w+[?!]?(?:\((?:[^()]|\([^()]*\))*\))?\s+=\s/

fehler = Dir[File.join(haupt, '{Komponenten/*/src,sketchup-tcn-export-plugin/src}/**/*.rb')].sort.flat_map do |f|
  File.readlines(f, encoding: 'UTF-8').each_with_index.select { |l, _| l =~ KURZ }
      .map { |l, i| "#{f.sub("#{haupt}/", '')}:#{i + 1}: #{l.strip}" }
end
fehler.each { |m| puts "FEHLER (nicht Ruby 2.7): #{m}" }
puts fehler.empty? ? 'OK: kein Ruby-3-only-Syntax in src/' : "#{fehler.size} Fehler"
exit(fehler.empty? ? 0 : 1)
