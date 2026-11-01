# Fremder Code im Plugin Schrank-CNC

## BinPacking2D aus OpenCutList

* Quelle: [OpenCutList](https://github.com/lairdubois/lairdubois-opencutlist-sketchup-extension) von L'Air du Bois, Ordner `src/ladb_opencutlist/ruby/lib/bin_packing_2d`, Commit `1ef3e14c896171eed8cd77ede440c7f5563e943e` (19.10.2026)
* Lizenz: GNU General Public License v3.0 (GPL-3.0), siehe [`LICENSE`](LICENSE)
* Hier: [`src/jt_schrank_cnc/bin_packing_2d/`](src/jt_schrank_cnc/bin_packing_2d/), benutzt vom Zuschnittplan (`zuschnitt.rb`)
* Änderungen: Namensraum `JTools::SchrankCnc::BinPacking2D` statt `Ladb::OpenCutList::BinPacking2D`, Herkunftsvermerk am Dateianfang, eine Debug-Ausgabe (`puts(object_id)` in `packer.rb`) entfernt. Sonst unverändert.

## Folge für das Plugin

Weil das Plugin diesen Code enthält, steht das ganze Plugin Schrank-CNC (`sketchup-tcn-export-plugin/`, `schrank_cnc.rbz` und der Plugin-Teil in `Kuechenplaner_alle.rbz`) unter der GPL-3.0 (von Jürgen freigegeben am 01.11.2026). Wer die `.rbz` weitergibt, muss den Quelltext mitgeben oder zugänglich machen (dieses Repository) und die Lizenz beilegen; `LICENSE.txt` liegt deshalb auch in der `.rbz`. Für die eigene Nutzung ändert sich nichts.

Die Komponenten unter `Komponenten/` enthalten keinen Code aus OpenCutList; sie schreiben nur Material-Attribute im Format von OpenCutList (Wörterbuch `ladb_opencutlist`).

## Optional beim Drucken geladen

* [qrcodejs](https://github.com/davidshimjs/qrcodejs) 1.0.0 (MIT), nur wenn bei den Etiketten „QR-Code: ja“ gewählt ist; die Etiketten-Seite lädt es von cdnjs.
