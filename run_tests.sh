#!/bin/sh
# Führt alle Tests der Komponenten und des Plugins aus (ohne SketchUp)
cd "$(dirname "$0")"
status=0
for t in Komponenten/*/test/test_*.rb sketchup-tcn-export-plugin/test/test_*.rb; do
  echo "== $t"
  if out=$(ruby "$t" 2>&1); then echo "$out" | tail -1; else echo "$out"; status=1; fi
done
[ $status -eq 0 ] && echo "Alle Tests OK" || echo "Es gibt Fehler"
exit $status
