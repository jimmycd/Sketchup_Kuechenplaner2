#!/bin/sh
# Baut unterschrank_schubladen.rbz aus src/ (nach jeder Änderung an src/ ausführen)
set -e
cd "$(dirname "$0")"
rm -f unterschrank_schubladen.rbz
cd src && zip -q -X -r ../unterschrank_schubladen.rbz unterschrank_schubladen.rb unterschrank_schubladen
echo "unterschrank_schubladen.rbz erstellt"
