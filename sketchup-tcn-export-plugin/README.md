# SketchUp-Plugin „Schrank-CNC“ (TCN-Export und Frontfarbe)

**Stand:** *Frontfarbe und Griffe ändern* ist fertig. Der TCN-Export schreibt den Korpus: Formatieren, Dübel Boden/Deckel/Zwischenboden/Strebe an die Seiten, Schrauben in die Streben, Lochreihen für Einlegeböden, Sockelfüße und die Rückwandnut im Oberschrank. Für Schubladen (Blum LEGRABOX) kommen die Schienenbohrungen in die Seiten, die Frontbefestigung in die Front und der Falz in den Kastenboden; Türen und Griffe folgen.

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

## TCN exportieren
*Erweiterungen › Schrank-CNC › TCN exportieren…* fragt nach einem Ordner und schreibt je sichtbarem Teil eine TCN-Datei (Name = Tag, z. B. `USS1_Boden.tcn`) und `Teileliste.csv` (Datei, Anzahl, Schrank, Teil, Rolle, Material, DL, DH, DS). Ist etwas ausgewählt, nur die Teile der ausgewählten Schränke.

* Maße und Lagen sind **Fräsmaß** wie in OpenCutList: an jeder Seite mit Anleimer (Kantenfläche mit OCL-Kante, Typ 4) um dessen Stärke kleiner. DL ist die längere, DH die kürzere Plattenrichtung, DS die Stärke.
* Stöße werden geometrisch gefunden: liegt die Stirnseite von Boden, Deckel, Zwischenboden oder Strebe an der Fläche einer Seite, gibt es eine Dübelreihe Ø8 (22 tief in die Stirnseite, 14 tief in die Seite wie `Seiten_SK`; Seiten sind immer gleich), mittig in der Plattenstärke. Boden/Deckel/Zwischenboden 30 … x-30, Raster 150; Strebe 20 … x-20, Raster 60; beide gleichmäßig verteilt (1/1). In die Seite kommt je Strebe eine Schraubbohrung Ø3, 21 tief, in der Mitte der Strebe.
* **Lochreihen** Ø5, 12 tief, Raster 32 in jeder Seite und jedem Fach ohne Schubladen zwischen zwei festen Böden (Boden, Zwischenboden, Deckel, Strebe): 35 mm von vorn und 35 mm vor der Hinterkante bzw. vor der Rückwandnut; in der Höhe ab 38 mm über dem Boden darunter bis 33 mm unter dem darüber (ergibt 55 … x-50 wie `Seite.tcn`). In Fächern mit Schubladen gibt es keine Lochreihe; das Schubladen-Lochraster (`Lochraster_Start`, `Lochraster`) dient dort nur zum Ausrichten der Schienen.
* **Schienen** (Blum LEGRABOX, Montageanleitung MD-015/4 S. 3, Bohrtiefe aus `Seiten_SK_L/R`): je sichtbarer Schublade Ø5, 14 tief, 37 und 69 mm ab Vorderkante der Seite und hinten je Nennlänge NL: 350 → 37+192/224, 400–500 → 37+224/256, 550–600 → 37+256/320, 650 → 37+320/416. NL ist die größte mit NL + 3 ≤ lichte Tiefe (Vorderkante Seite bis Rückwand). Höhe = Kastenunterkante + `Hoehenoffset_Schiene`.
* **Frontbefestigung** (LEGRABOX, MD-015/4 S. 4; Bohrbild wie `SK_Vorderstueck_Frontbef.tcn`): Ø3, 5 tief in der Rückseite der Front, 14 mm von der Innenseite der Seite (= 14 + FA vom Frontrand), Löcher 0/32/96/128 mm übereinander. Das unterste sitzt 36 mm über der Kastenunterkante (mind. 51 mm über der Front-Unterkante); obere Löcher entfallen, wenn sie über dem Kasten lägen. Stehende Teile (Fronten, Rückwand) haben y = 0 an der Unterkante.
* **Kastenboden** (`Schubkastenboden.tcn`): Falz in der Unterseite an beiden Enden der Breite für die Zargen, Rechteck 38 mm breit über die ganze Tiefe + 20 mm und ein zweites 20 mm breit, beide 8 tief (W#1022 `rect.tmcr`). Die Ø3-Löcher aus der Vorlage fehlen, Blum sieht sie nicht vor. Die Kastenrückwand wird nur formatiert.
* **Sockelfüße** (Unter- und Hochschränke): Bohrbild aus `Boden.tcn` in der Unterseite des Bodens, je Fuß 2 × 2 Bohrungen Ø3, 3 tief, Raster 64, 20 mm vom Rand in x und 60 mm in y. Der Boden liegt dafür mit der Unterseite nach oben.
* **Rückwandnut** (steckt eine Rückwand in Seiten und Boden, also im Oberschrank): Bahn mit dem Nutfräser 2200 (Ø 8,03 mm, wie im Treppenbau) als `W#89`/`W#2201`, Tiefe = Nuttiefe (9 mm), Breite = Rückwandstärke (breiter als der Fräser: mehrere Bahnen). Läuft die Nut aus der Platte, fräst sie 5 mm darüber hinaus.
* **Deckel–Rückwand** (nur Oberschrank): 3 Schrauben 50 mm von den Seiten und in der Mitte, Ø4 durch die Rückwand (1 mm tiefer als ihre Stärke), Ø3 × 15 in die Hinterkante des Deckels (Annahme).
* Die Bearbeitungen einer Seite sind nach Inhalt sortiert, so ergeben gespiegelte Teile mit gleichem Bohrbild dieselbe TCN.
* Fläche 1 (oben auf der Maschine) ist die große Fläche mit den meisten Bohrungen, bei Seiten also die Innenseite. Die linke Seite ist die gespiegelte rechte.
* Jede TCN beginnt mit `squad` (Formatieren). Das Feld `s` im Kopf kommt aus den Vorlagen (Boden 13, Deckel 11, Strebe 10, Seite 54, sonst 1).
* Gleiche Teile (gleicher Tag, gleiche TCN, z. B. zweimal derselbe Schrank) werden einmal geschrieben und gezählt. Weicht ein gleichnamiges Teil ab, heißt die Datei `<Tag>_2.tcn`.
* Der Test vergleicht Boden und Strebe zeilengleich mit `beispiele/Boden.tcn` und `Strebe.tcn` und die Seite mit `Seite.tcn`. Abweichungen gewollt: Strebe 1/1 verteilt (bei 98 mm Fräsmaß bleiben es zwei Dübel), Seite ohne Anleimer oben/unten hat die Reihen bei 9.5 statt 7.5, und die Ø3-Reihe Raster 130 aus `Seite.tcn` fehlt noch.

## Aufbau
* `src/jt_schrank_cnc.rb` – Registrierung der Erweiterung
* `src/jt_schrank_cnc/main.rb` – Menü, lädt die Untermodule
* `src/jt_schrank_cnc/schraenke.rb` – Schränke und Teile im Modell finden
* `src/jt_schrank_cnc/frontfarbe.rb` – Frontfarbe und Griffe
* `src/jt_schrank_cnc/geometrie.rb` – Teile vermessen (Weltquader, Anleimer, Lage auf der Maschine)
* `src/jt_schrank_cnc/regeln.rb` – Stöße finden, Bearbeitungen ableiten
* `src/jt_schrank_cnc/tcn.rb` – TCN schreiben (Windows-1252, CRLF)
* `src/jt_schrank_cnc/export.rb` – Export, Teileliste, Dialog
* `test/test_frontfarbe.rb` – erzeugt Hochschrank, Oberschränke und Unterschrank mit den Skripten aus `Komponenten/` in der Mock-API und prüft Frontfarbe, Anleimer, Bereiche, Auswahl, Eindeutigmachen, Griffe und den Dialog
* `test/test_export.rb` – TCN-Export an Unterschrank, Oberschrank und Hochschrank, Vergleich mit `beispiele/` (Boden mit Sockelfüßen, Strebe, Seite mit Lochreihen), Nut und Schrauben im Oberschrank

## Grundidee
1. Teile einsammeln (sichtbare Instanzen mit Tag nach dem Schema `<Kürzel>_<Bereich>_<Teil>`).
2. Teile vermessen, Anleimer wie OpenCutList aus den Kantenflächen lesen, Lagen im Fräsmaß.
3. Stöße zwischen Teilen finden und daraus Dübel, Lochreihen, Topfbänder und Schienenbohrungen ableiten.
4. Eine TCN je Tag schreiben, dann Fräsliste und Teileliste.

## Schritte
1. ~~Tags aller Komponenten vereinheitlichen.~~ Erledigt: Hochschrank `HS<n>`, Unterschrank Schubladen `USS<n>`, Unterschrank Tür `UST<n>`, jeweils mit `JT_Schrank`.
2. ~~Oberschrank-Skript~~ (`Komponenten/oberschrank/`, Kürzel `OS<n>`).
3. ~~Schubkasten:~~ Blum LEGRABOX (Boden und Holzrückwand), Schiene im 32-mm-Lochraster (Start 35 mm), Höhenoffset Schiene.
4. ~~Frontfarbe und Griffe.~~
5. ~~Erster Export nur Korpus, Vergleich mit den Beispiel-TCN.~~
6. ~~Lochreihen, Sockelfüße, Rückwandnut.~~
7. ~~Schubladen: Schienenbohrungen, Frontbefestigung, Kastenboden, Generatoren auf LEGRABOX.~~
8. Türen und Griffbohrungen.
9. Dialog, Listen.
