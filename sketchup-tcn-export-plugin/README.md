# SketchUp-Plugin „Schrank-CNC“ (TCN-Export und Frontfarbe)

**Stand:** Die Funktion *Frontfarbe und Griffe ändern* ist fertig. Der TCN-Export für TpaCAD folgt in den nächsten Schritten.

Das Plugin findet im Modell alle Teile der Schränke aus `Komponenten/` an ihrem Tag `<Kürzel>_<Bereich>_<Teil>` und am Wörterbuch `JT_Schrank`. Später schreibt es je Teil eine TCN-Datei für TpaCAD, dazu Fräsliste (`.xmlst`) und Teileliste (`.csv`).

* Ausführlicher Plan: [Plan: TCN-Export für Schrank-Komponenten](https://claude.ai/artifact/1txhjwKrxeGrWi3j7F5wNN)
* Vorbild für den TCN-Writer: [jimmycd/sketchup-treppenbauer](https://github.com/jimmycd/sketchup-treppenbauer) (`src/jt_treppenbau/tcn.rb`, `fraesliste.rb`)
* `beispiele/` – Jürgens 11 Beispiel-TCN-Dateien (Boden, Deckel, Strebe, Seite, Seiten_Duebel, Seiten_SK_L/R, Schubkastenboden, SK_Vorderstueck_Frontbef, T_re_L_Topfband, T_rR). Sie sind parametrisch (`x`, `y`, `s`) und nutzen die Makros `squad`, `fittingx`/`fittingy`, `inge100` und `rect`; sie sind die Vorlage für die Bearbeitungsregeln.

## Installieren
`schrank_cnc.rbz` im Erweiterungs-Manager installieren (*Erweiterung installieren*). Das Menü steht unter *Erweiterungen › Schrank-CNC*. Nach Änderungen an `src/` die `.rbz` mit `./build_rbz.sh` neu bauen (der Test prüft das).

## Frontfarbe und Griffe ändern
*Erweiterungen › Schrank-CNC › Frontfarbe und Griffe ändern…*

| Feld | Bedeutung |
|---|---|
| Frontmaterial | alle OCL-Plattenwerkstoffe (OpenCutList-Typ 2) im Modell, deren Name mit „Front“ beginnt, z. B. „Front Eiche 19mm“. Fehlt eins, in OCL anlegen. |
| Bereich | alle Schränke, nur Oberschränke, nur Unterschränke oder nur Hochschränke (`kategorie` in `JT_Schrank`) |
| Nur ausgewählte Schränke | Ja: nur Schränke, die gerade ausgewählt sind |
| Griffe | unverändert lassen, setzen oder entfernen |
| Griff: Lochmaß, Lage, Höhe | Lochmaß in mm (z. B. 160), Lage seitlich links / Mitte / rechts, Höhe in mm ab Unterkante der Front |

Vor dem Ändern fragt das Plugin nach, z. B. „5 Fronten in 3 Schränken bekommen „Front Eiche 19mm“. Übernehmen?“ (gezählt werden sichtbare Fronten). Ein Schritt *Rückgängig* macht alles zurück.

Was geändert wird:
* Fronten sind alle Teile mit `rolle` Front oder Tuer, auch ausgeblendete Schubladen und Türen. Korpus und Schubkästen bleiben unverändert.
* Das Material kommt an die Instanz und als DC-Attribut `material`, damit es ein Neuzeichnen der Dynamic Component übersteht.
* Die Anleimer der Fronten (Kantenflächen mit einer OCL-Kante, Typ 4) bekommen den passenden Anleimer: eine OCL-Kante mit dem Dekor im Namen („Anleimer Eiche“ zu „Front Eiche 19mm“), sonst legt das Plugin „Anleimer <Dekor>“ an (Kante, 2 mm, Abzug an).
* Teilen sich Schränke im Modell dieselbe Definition (z. B. zweimal derselbe Oberschrank eingefügt) und ist nur einer gewählt, macht das Plugin den Weg zu dessen Fronten eindeutig. Korpusteile bleiben geteilt.
* Griffe: Lochmaß, Lage und Höhe stehen danach an jeder Front in `JT_Schrank` (`griff_lochmass`, `griff_lage`, `griff_hoehe`, mm). Der TCN-Export setzt daraus die Griffbohrungen (Ø3, 5 tief).

## Aufbau
* `src/jt_schrank_cnc.rb` – Registrierung der Erweiterung
* `src/jt_schrank_cnc/main.rb` – Menü, lädt die Untermodule
* `src/jt_schrank_cnc/schraenke.rb` – Schränke und Teile im Modell finden
* `src/jt_schrank_cnc/frontfarbe.rb` – Frontfarbe und Griffe
* `test/test_frontfarbe.rb` – erzeugt Hochschrank, Oberschränke und Unterschrank mit den Skripten aus `Komponenten/` in der Mock-API und prüft Frontfarbe, Anleimer, Bereiche, Auswahl, Eindeutigmachen, Griffe und den Dialog

## Grundidee
1. Teile einsammeln (sichtbare Instanzen mit Tag nach dem Schema `<Kürzel>_<Bereich>_<Teil>`).
2. Teile vermessen, Anleimer wie OpenCutList aus den Kantenflächen lesen, Lagen im Fräsmaß.
3. Stöße zwischen Teilen finden und daraus Dübel, Lochreihen, Topfbänder und Schienenbohrungen ableiten.
4. Eine TCN je Tag schreiben, dann Fräsliste und Teileliste.

## Schritte
1. ~~Tags aller Komponenten vereinheitlichen.~~ Erledigt: Hochschrank `HS<n>`, Unterschrank Schubladen `USS<n>`, Unterschrank Tür `UST<n>`, jeweils mit `JT_Schrank`.
2. ~~Oberschrank-Skript~~ (`Komponenten/oberschrank/`, Kürzel `OS<n>`).
3. ~~Schubkasten:~~ Boden tragend 16 mm oder zwischen den Seiten, Schiene im 32-mm-Lochraster (Start 35 mm), Höhenoffset Schiene.
4. ~~Frontfarbe und Griffe.~~
5. Erster Export nur Korpus, Vergleich mit den Beispiel-TCN.
6. Lochreihen, Sockelfüße, Rückwandnut.
7. Schubladen.
8. Türen und Griffbohrungen.
9. Dialog, Listen.
