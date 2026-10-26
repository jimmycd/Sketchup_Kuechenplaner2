#!/bin/sh
# Baut alle SketchUp-Erweiterungen (.rbz) aus den src/-Ordnern.
# Nach jeder Änderung an einem src/-Ordner ausführen; der Test prüft, dass die
# .rbz zum Quelltext passen.
#   Komponenten/<name>/<name>.rbz              eine Erweiterung je Komponente
#   sketchup-tcn-export-plugin/schrank_cnc.rbz TCN-Export, Frontfarbe und Griffe
#   Kuechenplaner_alle.rbz                     alles zusammen in einer Datei
set -e
cd "$(dirname "$0")"
top=$(pwd)
rm -f Kuechenplaner_alle.rbz
for src in Komponenten/*/src sketchup-tcn-export-plugin/src; do
  dir=$(dirname "$src")
  name=$(basename "$dir")
  [ "$name" = sketchup-tcn-export-plugin ] && name=schrank_cnc
  rm -f "$dir/$name.rbz"
  (cd "$src" && zip -q -X -r "$top/$dir/$name.rbz" . && zip -q -X -r "$top/Kuechenplaner_alle.rbz" .)
  echo "$dir/$name.rbz erstellt"
done
echo "Kuechenplaner_alle.rbz erstellt"
