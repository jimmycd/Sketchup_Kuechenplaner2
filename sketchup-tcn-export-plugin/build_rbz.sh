#!/bin/sh
# Baut schrank_cnc.rbz aus src/ (nach jeder Änderung an src/ ausführen)
set -e
cd "$(dirname "$0")"
rm -f schrank_cnc.rbz
cd src && zip -q -X -r ../schrank_cnc.rbz jt_schrank_cnc.rb jt_schrank_cnc
echo "schrank_cnc.rbz erstellt"
