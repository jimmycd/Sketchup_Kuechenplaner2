# Fremder Code im Plugin Schrank-CNC

## rqrcode_core (QR-Codes auf den Etiketten)

* Quelle: [rqrcode_core](https://github.com/whomwah/rqrcode_core) 2.1.0 von Duncan Robertson, Ordner `lib/rqrcode_core/qrcode`
* Lizenz: MIT, siehe [`src/jt_schrank_cnc/rqrcode_core/LICENSE.txt`](src/jt_schrank_cnc/rqrcode_core/LICENSE.txt)
* Hier: [`src/jt_schrank_cnc/rqrcode_core/`](src/jt_schrank_cnc/rqrcode_core/), benutzt von `pdf.rb` (QR-Code im Etiketten-PDF)
* Änderungen: Namensraum `JTools::SchrankCnc::RQRCodeCore` statt `RQRCodeCore`, Herkunftsvermerk am Dateianfang. Sonst unverändert.

## Früher: BinPacking2D aus OpenCutList

Bis Version 0.6 nutzte der Zuschnittplan den Optimierer BinPacking2D aus [OpenCutList](https://github.com/lairdubois/lairdubois-opencutlist-sketchup-extension) (GPL-3.0). Seit Version 0.7 rechnet der eigene Guillotine-Optimierer `guillotine.rb` (Stufen, erster Schnitt, Schnitttyp wie im heutigen OpenCutList); der OCL-Code ist nicht mehr enthalten.

## Lizenz des Plugins

Das Plugin Schrank-CNC (`sketchup-tcn-export-plugin/`, `schrank_cnc.rbz` und der Plugin-Teil in `Kuechenplaner_alle.rbz`) steht unter der GPL-3.0 (von Jürgen festgelegt am 01.11.2026), `LICENSE.txt` liegt auch in der `.rbz`. Die MIT-Lizenz von rqrcode_core ist damit verträglich.

Die Komponenten unter `Komponenten/` enthalten keinen Code aus OpenCutList; sie schreiben nur Material-Attribute im Format von OpenCutList (Wörterbuch `ladb_opencutlist`).
