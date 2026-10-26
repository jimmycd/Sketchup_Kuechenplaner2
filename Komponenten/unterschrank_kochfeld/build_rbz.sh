#!/bin/sh
# Baut unterschrank_kochfeld.rbz aus src/ (nach jeder Änderung an src/ ausführen)
set -e
cd "$(dirname "$0")"
rm -f unterschrank_kochfeld.rbz
cd src && zip -q -X -r ../unterschrank_kochfeld.rbz unterschrank_kochfeld.rb unterschrank_kochfeld
echo "unterschrank_kochfeld.rbz erstellt"
