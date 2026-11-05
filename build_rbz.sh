#!/bin/sh
# Baut alle SketchUp-Erweiterungen (.rbz) aus den src/-Ordnern.
# Nach jeder Änderung an einem src/-Ordner ausführen; der Test prüft, dass die
# .rbz zum Quelltext passen.
#   Komponenten/<name>/<name>.rbz              eine Erweiterung je Komponente
#   sketchup-tcn-export-plugin/schrank_cnc.rbz TCN-Export, Frontfarbe und Griffe
#   kuechenplaner-update/kuechenplaner_update.rbz  Plugins aktualisieren (ohne Extension Manager)
#   kuechenplaner-symbolleiste/kuechenplaner_symbolleiste.rbz  Symbolleiste „Küchenplaner“
#   Kuechenplaner_alle.rbz                     alles zusammen in einer Datei
# Vorher werden gemeinsam/eingabe.rb (Eingabefenster im Treppenplaner-Stil),
# gemeinsam/einstellungen.rb (Sockelhöhe, Abstände) und gemeinsam/neuladen.rb (Neu laden
# ohne Neustart) in jede Erweiterung nach
# src/kuechenplaner_gemeinsam/ kopiert.
set -e
cd "$(dirname "$0")"
top=$(pwd)
rm -f Kuechenplaner_alle.rbz
for src in Komponenten/*/src sketchup-tcn-export-plugin/src kuechenplaner-update/src kuechenplaner-symbolleiste/src; do
  dir=$(dirname "$src")
  name=$(basename "$dir")
  [ "$name" = sketchup-tcn-export-plugin ] && name=schrank_cnc
  [ "$name" = kuechenplaner-update ] && name=kuechenplaner_update
  [ "$name" = kuechenplaner-symbolleiste ] && name=kuechenplaner_symbolleiste
  mkdir -p "$src/kuechenplaner_gemeinsam"
  cp gemeinsam/eingabe.rb "$src/kuechenplaner_gemeinsam/eingabe.rb"
  cp gemeinsam/einstellungen.rb "$src/kuechenplaner_gemeinsam/einstellungen.rb"
  cp gemeinsam/neuladen.rb "$src/kuechenplaner_gemeinsam/neuladen.rb"
  rm -f "$dir/$name.rbz"
  (cd "$src" && zip -q -X -r "$top/$dir/$name.rbz" . -x "*__pycache__*" && zip -q -X -r "$top/Kuechenplaner_alle.rbz" . -x "*__pycache__*")
  echo "$dir/$name.rbz erstellt"
done
echo "Kuechenplaner_alle.rbz erstellt"
