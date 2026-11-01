> Quelle: [Plan: TCN-Export für Schrank-Komponenten](https://claude.ai/artifact/1txhjwKrxeGrWi3j7F5wNN) (Plan-Dokument aus dem Projekt-Thread, Stand 28.10.2026)  
> Status: umgesetzt in PR #2–#8, Plugin in `sketchup-tcn-export-plugin/`

# Plan: TCN-Export für Schrank-Komponenten

Oct 25, 2026 · @Jürgen Späder

## Ziel und Umfang

Ein SketchUp-Plugin „Schrank-CNC“ findet im Modell alle Teile der generierten Schränke, erkennt jedes Teil an seinem Tag und schreibt je Teil eine TCN-Datei für TpaCAD, plus Fräsliste (`.xmlst`) und Teileliste (`.csv`).

- **Rein:** Hochschrank, Unterschrank mit Schubladen, Unterschrank mit Tür, Oberschrank (einfach und Doppeltür); später weitere Komponenten nach demselben Schema.
- **Bearbeitungen:** Bohrungen von oben (Dübel, Lochreihen, Topfbänder, Schienen) und waagerecht in die Stirnkanten (Dübel), optional Nuten und Außenkontur.
- **Woher die Regeln kommen:** aus deinen Beispiel-TCN-Dateien. Das Plugin lernt nichts selbst, sondern bildet jede Vorlage als feste Regel nach.
- **Nicht drin (erst einmal):** Verschachtelung mehrerer Teile auf einer Platte, Werkzeugwahl nach Material, Beschläge, die nicht in SketchUp gezeichnet sind und nicht aus Regeln folgen.

## Was es schon gibt

Der TCN-Teil aus dem Treppenbau ([jimmycd/sketchup-treppenbauer](https://github.com/jimmycd/sketchup-treppenbauer), Stand 2.21.0) lässt sich fast unverändert übernehmen; neu sind nur das Einsammeln der Teile und die Bearbeitungsregeln.

| Baustein im Treppenbau | Was er tut | Übernahme |
| --- | --- | --- |
| `tcn.rb` → `build_prog` | Kopf wie dxf4tcn (`TPA\ALBATROS\EDICAD\02.00`, `DL/DH/DS`), `SIDE#1` oben, Windows-1252, CRLF | direkt, als gemeinsames Modul; Feld `s…` in der Kopfzeile bleibt wie in den Vorlagen |
| `Tcn.drill` | Bohrung `W#81` (`#1002` = Ø, `#3` = Tiefe, `#205` = Werkzeug, 0 = nach Ø) | direkt |
| `Tcn.setup` + `lines` | Fräsbahn `W#89` + relative Linien `W#2201` (Nuten) | für die Rückwandnut |
| `Lauf.drill_face` (Hilfsflächen) | waagerechte Bohrung mit dem Bohraggregat | **entfällt:** Stirnbohrungen laufen mit den Standard-Horizontalbohrern in X und Y auf `SIDE#3…6`, keine Hilfsflächen |
| `fraesliste.rb` | `Liste_<Name>.xmlst` aus den geschriebenen TCN (wie csv2tcn), mit `REPETITIONS` | direkt |
| `cnc.rb` + `cnc_dialog.rb` | Dialog, Vorschau, Export + `Teileliste.csv` | als Vorlage, schlanker |
| `nesting.rb` | Verschachtelung | **entfällt:** das macht OCL |

Die Schränke liefern schon, was der Export braucht: jedes Teil ist eine Instanz mit eigenem Tag (SketchUp-Layer), Material „Melamin weiss“ und Anleimer-Material auf den Kantenflächen (das liest OCL). Die Maße stehen in der Dynamic Component (`LenX/LenY/LenZ`, Position), die festen Werte (19/16/8 mm, Fugen) als Attribute am Schrank.

Im Treppenbau noch offen und hier genauso wichtig: die TpaCAD-Prüfung von `W#81` auf Hilfsflächen und die Feldzuordnung (`s1` → FIELD 9).

## Tag-Schema vereinheitlichen

Vorschlag: alle Schränke benennen ihre Teile `<Kürzel>_<Bereich>_<Teil>` mit Unterstrich, und der Export liest zusätzlich ein Attribut-Wörterbuch am Teil statt den Namen zu zerlegen.

Heute passen die beiden Schränke nicht zusammen: der Hochschrank schreibt `Hochschrank-SeiteL` und `Hochschrank-U1-Front` (Bindestrich, fester Name, also nur ein Hochschrank je Modell eindeutig), der Unterschrank `USS1_SeiteL` und `USS1_S2_Front`. Der Unterschrank mit Tür (`Unterschrank.skp`) hat noch gar keine Teile-Tags.

| Teil | Hochschrank heute | Unterschrank Schubl. heute | Neu |
| --- | --- | --- | --- |
| Seite links | `Hochschrank-SeiteL` | `USS1_SeiteL` | `HS1_SeiteL` / `USS1_SeiteL` |
| Boden | `Hochschrank-Boden` | `USS1_Boden` | `HS1_Boden` / `USS1_Boden` |
| Einlegeboden 2 | `Hochschrank-Einlegeboden2` | – | `HS1_O_Einlegeboden2` |
| Front Schublade 1 | `Hochschrank-U1-Front` | `USS1_S1_Front` | `HS1_U1_Front` / `USS1_S1_Front` |
| Kastenseite rechts | `Hochschrank-M2-KastenSeiteR` | `USS1_S2_KastenSeiteR` | `HS1_M2_KastenSeiteR` / `USS1_S2_KastenSeiteR` |
| Tür | `Hochschrank-Tuer` | – | `HS1_O_Tuer` |

- **Kürzel** je Schrank im Modell eindeutig, vom Dialog vorgeschlagen: `HS1`, `USS1`, `UST1` (Unterschrank Tür) …
- **Bereich** nur wo es mehrere gibt: `U1`/`M2` (Hochschrank unten/Mitte, Schublade n), `S1` (Unterschrank Schublade n), `O` (Hochschrank oben). Korpusteile ohne Bereich.
- **Teil** aus einer festen Liste, für alle Schränke gleich: `SeiteL`, `SeiteR`, `Boden`, `Deckel`, `StrebeVorn`, `StrebeHinten`, `ZwischenbodenUnten`, `ZwischenbodenOben`, `Rueckwand`, `Einlegeboden<n>`, `Tuer`, `Front`, `KastenSeiteL`, `KastenSeiteR`, `KastenVorne`, `KastenHinten`, `KastenBoden`.
- **Attribute** am Teil im Wörterbuch `JT_Schrank`: `schrank` (HS1), `typ` (Hochschrank), `bereich`, `teil` (SeiteL), `rolle` (Seite, Boden, Front …). Die Regeln hängen an der `rolle`, damit `SeiteL` im Hochschrank und im Unterschrank dieselbe Regel nutzen.
- **Dateiname** der TCN = Tag, z. B. `HS1_U1_Front.tcn`. So bleibt die Zuordnung Tag ↔ Datei eins zu eins, auch in OCL.
- Bestehende Modelle: der Export erkennt auch die alten Namen (`Hochschrank-…`) über eine Übersetzungstabelle, damit nichts neu gezeichnet werden muss.

## Ablauf des Plugins

Der Export rechnet die Bohrbilder aus der Geometrie der Teile, nicht aus festen Maßen je Schranktyp: wo die Stirnseite eines Teils auf der Fläche eines anderen sitzt, ist ein Stoß, und dort setzt eine Regel Dübel in beide Teile.

1. **Teile einsammeln:** alle sichtbaren Instanzen im Modell (oder in der Auswahl) mit `JT_Schrank`-Attribut oder einem Tag nach dem Schema. Ausgeblendete Schubladen und Einlegeböden fallen weg, wie in OCL.
2. **Teil vermessen:** Quader in Weltkoordinaten aus Definition und Transformation; Länge × Breite × Dicke in mm, dazu die Anleimer-Kanten aus den Flächenmaterialien (wie OCL sie liest).
3. **Stöße finden:** für jedes Teilepaar prüfen, ob eine Stirnseite bündig auf einer Fläche liegt (Toleranz 0,1 mm). Ergebnis z. B. „Boden-Stirn links auf SeiteL innen, Länge 780 mm“.
4. **Regeln anwenden:** je Stoß die Verbindungsregel (Dübel: Flächenbohrung im einen, Stirnbohrung im anderen Teil), je Rolle die Teileregeln (Lochreihe in Seiten, Topfband in Tür und Seite, Schienenbohrungen in Seiten auf Höhe jeder Schublade).
5. **In die Maschinenlage drehen:** jedes Teil flach, größte Fläche = `DL × DH`, Dicke = `DS`, die Fläche mit den meisten Bohrungen oben (`SIDE#1`), Stirnbohrungen auf die Seiten `SIDE#3…6` mit den Horizontalbohrern (keine Hilfsfläche).
6. **TCN schreiben:** Kopf und Rahmen vom Treppenbau-Writer, Bearbeitungen als deine Makros (\`fittingx\`, \`inge100\` …) mit \`x\`/\`y\`/\`s\`-Ausdrücken, alle Lagen im Fräsmaß; eine Datei je Tag; danach Fräsliste und Teileliste mit Tag, Maßen, Material, Anleimer.
7. **Prüfen und anzeigen:** Vorschau je Teil mit allen Bohrungen; Warnungen bei Bohrung zu nah am Rand, Kollision zweier Bohrungen, Teil ohne Regel.

Vorteil: änderst du in den Komponentenoptionen Höhe oder Schubladenzahl, stimmen die Bohrbilder automatisch, und neue Schranktypen brauchen nur Tags, keine eigene Export-Logik.

## Bearbeitungen und Standards (aus deinen 11 Beispielen)

Deine Beispiele sind parametrisch geschrieben (`x`, `y`, `s` = Länge, Breite, Dicke) und nutzen TpaCAD-Makros; der Export soll genau so schreiben, nicht als einzelne Koordinaten wie der Treppenbau. Dann bleiben die Dateien in TpaCAD lesbar und nachjustierbar. Die Dateien liegen unter `tcn_export/beispiele/` im Projekt.

**Makros**

| Makro | Block | Zweck | Wichtige Parameter |
| --- | --- | --- | --- |
| `squad.tmcr` | `W#1510`, `W$=forma` | Formatieren / Außenkontur | Tiefe `-s-2` |
| `fittingx.tmcr` | `W#1001` | Bohrreihe längs X | `#8510` Start, `#8511` Ende, `#8512` Raster, `#8513` Tiefe, `#8518` Y-Lage, `#8522` Ø, `#8508/#8509` Verteilung? |
| `fittingy.tmcr` | `W#1003` | Bohrreihe längs Y | wie oben, `#8518` = X-Lage |
| `inge100.tmcr` | `W#1506` | Topfband | Topf Ø35, 2 × Ø8, Lochabstand 45, `#8507` Lage längs, `#8508` = `y-21,5` |
| `rect.tmcr` | `W#1022` | Rechtecktasche | Mitte `#8020/#8021`, Breite `#8509`, Länge `#8510`, Tiefe `#8514` |
| – | `W#81` | Einzelbohrung | wie im Treppenbau, hier mit `::WTp` statt `::WT2` |

**Bohrbilder je Teil**

| Teil (Beispiel) | Bearbeitung | Maße |
| --- | --- | --- |
| Boden, Deckel (862 × 558) | Dübel in beide Stirnseiten (`SIDE#4`, `#6`) | Ø8, 22 tief, Mitte Dicke 9,5, von 30 bis `x-30`, Raster 150 |
| Boden | Bohrreihen von oben, 4 je Seite | Ø3, 3 tief, 20 vom Rand, Raster 64, bei 60 / 124 von vorn und hinten (Sockel/Füße?) |
| Strebe (562 × 100) | Dübel in beide Stirnseiten | Ø8, 22 tief, 20 und 80 (Raster 60) |
| Seite (716 × 558) | Dübel für Boden/Deckel, Fläche | Ø8, 12 tief, Reihe bei `x` = 7,5, 30 bis `y-30`, Raster 150 |
| Seite | Lochreihe 32er-System, vorn und hinten | Ø5, 12 tief, 35 vom Rand, 55 bis `x-50` |
| Seite | Dübel für Strebe, Raster 60, dazu Ø3 bei 50 | bei `x-7,5` |
| Seite mit Schublade (656 × 551) | Schienen-Lochbild je Schublade | Ø5, 14 tief, Spalten bei 55 / 350 / 532, Zeilen 35, +32, +192, +32, +64 von vorn |
| Seite mit Schublade | Ø5 tief 21, Werkzeug 12 | an `7,5` und `x-7,5`, bei 50/60, `y/2 ± 80` |
| Seite SK links / rechts | gleiches Bild, rechts über `2*(y/2)-…` gespiegelt |  |
| Schubkastenboden (525 × 340 × 16) | Befestigung Schiene von oben | Ø3, 5 tief, 48,5 vom Rand, bei 24 / 152 / 257 / 397 |
| Schubkastenboden | 4 Taschen an den Seiten | 38 bzw. 20 breit, Länge `h+20` / `h`, 8 tief, Mitte 19 vom Rand |
| Schubkasten-Vorderstück (596 × 228) | Frontbefestigung | Ø3, 5 tief, 31 vom Rand, ab 69 im Raster 32 / 64 / 32 |
| Tür links (696 × 661) | 2 Topfbänder + Griff | Töpfe bei 90 und 90+512, `y-21,5`; Griff Ø3 bei 212 und 212+160, 35 vom Rand |
| Tür rechts (715 × 444) | 2 Topfbänder | bei 73 (55+2+16) und 73+576 |

**Was das für unsere Schränke heißt**

- **Fräsmaß (bestätigt):** alle Lagen und `DL/DH` sind Fräsmaß, also ohne Anleimer (Lochreihe 35 = 37 − 2, Dübel 7,5 = 9,5 − 2). Der Export zieht je Teil die Anleimer ab, genau wie OCL, und verschiebt alle Lagen um 2 mm an jeder bekanteten Kante.
- **Immer formatieren:** jedes Teil bekommt `squad`, auch Türen und Vorderstück. Das Übermaß des Rohteils legt OCL fest, nicht der Export.
- **Schubkasten:** der Boden wird in den Generatoren konfigurierbar (Stärke und Aufbau). Die Schubladenhöhe muss ins Standard-Lochraster passen; die Höhe der Schiene über der Schubladenunterkante wird ein Parameter (Höhenoffset).
- **Schienen-Lochbild:** die Spalten haben immer denselben Abstand von vorne bzw. hinten, die Zeilen sind immer gleich. Der Export rechnet also nur die Lage aus Korpustiefe und Schubladenhöhe.
- **Türen:** die Topfbänder müssen ins Lochraster der Seite passen; die Bohrhöhe in der Tür wird daraus berechnet.
- **Sockelfüße:** die Ø3-Bohrungen im Boden sind immer gleich, nur ihre Lage wird an Breite und Tiefe angepasst.
- **Ø5, 21 tief** in den Seiten sind Schraubenbohrungen.
- **Tiefen einheitlich:** Frontbefestigung und Griffbohrung immer 5 mm tief (die Abweichungen in zwei Vorlagen waren Tippfehler).
- **Unsere Unterschrank-Seiten passen schon:** Boden/Deckel und Strebe stumpf zwischen den Seiten, Dübel in die Stirnseiten, Flächenbohrung in der Seite, das ergibt sich aus den Stößen (Ablauf, Schritt 3).
- **Was fest bleibt und was gerechnet wird:** Raster, Ø, Tiefen und Randabstände kommen fest aus den Vorlagen; die Lage längs der Kante rechnet der Export aus dem Modell.

## Zusatzfunktion: Frontfarbe ändern

Ein zweiter Menüpunkt „Frontfarbe ändern…“ setzt ein neues Material auf alle Fronten, wahlweise für alle Schränke, nur Oberschränke, nur Unterschränke oder nur Hochschränke, und setzt auf Wunsch die Griffbohrungen neu. Er braucht nur das einheitliche Tag-Schema (Schritt 1) und kann deshalb vor dem TCN-Export fertig sein.

**Dialog**

- **Material:** Auswahl aus der OCL-Materialliste: nur die Frontmaterialien unter den OCL-Plattenwerkstoffen im Modell (Wörterbuch \`ladb\_opencutlist\`, Typ 2), mit Name, Farbe und Stärke. Dazu wählt der Dialog den Anleimer aus den OCL-Kanten (Typ 4), bevorzugt den mit passendem Namen. Fehlt ein Dekor im Modell, legst du es in OCL an (oder importierst es dort aus der Bibliothek) und es erscheint dann in der Liste. Ob sich OCLs eigene Material-Bibliothek außerhalb des Modells direkt lesen lässt, prüfe ich im OCL-Quelltext.
- **Bereich:** Alle · nur Oberschränke · nur Unterschränke · nur Hochschränke; zusätzlich Häkchen „nur ausgewählte Schränke“.
- Vorschau-Zeile: „14 Fronten in 5 Schränken werden geändert“, dann Übernehmen. Ein Schritt Rückgängig macht alles zurück.

**Was geändert wird**

- **Welche Teile Fronten sind:** alle Teile mit `rolle` = Front oder Tür (Schubladenfronten, Türen, später Klappen). Korpus und Schubkästen bleiben „Melamin weiss“.
- **Ober / Unter:** dazu bekommt jeder Schrank im `JT_Schrank`-Wörterbuch eine `kategorie` (Unterschrank, Oberschrank, Hochschrank). Die Generatoren setzen sie beim Erzeugen.
- **OCL bleibt richtig:** das neue Material wird als OCL-Plattenwerkstoff angelegt (Typ 2, Stärke 19), und die Kanten der Fronten bekommen einen passenden Anleimer „Anleimer \<Farbe>“ (Typ Kante, 2 mm, Abzug an). So listet OCL Fronten und Kanten getrennt nach Farbe.
- **Gemeinsame Definitionen:** sind Fronten mehrerer Schränke dieselbe Definition, wird sie vor dem Umfärben eindeutig gemacht, damit nur die gewählten Schränke die neue Kantenfarbe bekommen.
- **Dynamic Components:** das Material wird an der Instanz und als DC-Attribut `material` gesetzt, damit es ein Neuzeichnen über die Komponentenoptionen übersteht (in SketchUp zu prüfen).
- **TCN-Export:** Material und Stärke der Fronten kommen in die Teileliste; die Bohrbilder bleiben gleich.

**Griffe**

- Im selben Dialog: Lochmaß des Griffs (z. B. 160 mm), Lage seitlich (links / Mitte / rechts) und Höhe in mm ab Unterkante der Front.
- Die Griffbohrungen (Ø3, 5 tief) landen in der Front-TCN; bei Türen richtet sich „links/rechts“ nach dem Anschlag.

**Noch zu klären**

- [ ] Frontmaterial = Name beginnt mit „Front“ (z. B. „Front Eiche 19mm“). Entschieden.

## Oberschränke (aus deinen zwei Komponenten)

Deine `Oberschrank.skp` und `Oberschrank_Doppeltuer.skp` sind Dynamic Components im Stil des Unterschranks mit Tür. Für Export und Frontfarbe fehlen ihnen nur Tags und die `JT_Schrank`-Attribute. Die Dateien liegen jetzt unter `oberschrank/` im Projekt.

| Merkmal | Oberschrank | Oberschrank Doppeltür |
| --- | --- | --- |
| Standardmaße B × H × T | 400 × 700 × 400 mm | 600 × 700 × 400 mm |
| Optionen | Breite, Höhe, Tiefe, Tür Ja/Nein, Einlegeböden 0–3 | gleich |
| Teile | Seite (2×), Boden, Deckel, Einlegeboden 1–3, Rückwand, Front | wie links, aber FrontL + FrontR je halbe Breite |
| Korpus | 19 mm, Boden/Deckel zwischen den Seiten, Spaltmaß 2 mm | gleich |
| Rückwand | heute „HPL 3mm“, 25 mm von hinten; **richtig:** 8 mm, in Nut in Seiten und Boden, von oben eingeschoben (keine Nut im Deckel) | gleich |
| Materialien | „Melamin weiss 19mm“, „HPL 3mm“, „Anleimer weiss“ | gleich |
| Tags | keine (alles auf Layer0) | keine |

**Entschieden:** die Komponenten entstehen hier mit Claude Code, wie beim Hochschrank (Ruby-Skript, das die `.skp` erzeugt), nicht über ein Plugin. Das Export-Plugin erzeugt keine Schränke, es liest sie nur. Für den Oberschrank heißt das: ein Skript `oberschrank.rb` nach dem Vorbild deiner zwei Dateien, mit Option Türen 1 / 2 statt zwei getrennten Komponenten, Tags `OS1_SeiteL`, `OS1_FrontR` … und `JT_Schrank` mit `kategorie` = Oberschrank.

**Was sich gegenüber deinen Dateien ändert**

- Deckel-Formel in Y: statt `Unterschrank!Tiefe-Unterschrank!BreiteStreben` auf den Oberschrank bezogen; `BreiteStreben` fällt weg.
- Ein Materialname überall: „Melamin weiss“ wie in den Generatoren (statt „Melamin weiss 19mm“).
- Rückwand 8 mm statt 3 mm HPL, 25 mm von hinten, in einer Nut in Seiten und Boden (8-mm-Fräser).
- Deckel endet vor der Rückwand, damit sie von oben eingeschoben werden kann; danach wird sie mit dem Deckel verschraubt (Bohrungen in Rückwand und Deckelkante).
- TCN für den Oberschrank ohne eigene Vorlage: Lochreihe, Topfbänder und Dübel wie bei den Unterschrank-Vorlagen; die Nut als Fräsbahn `W#89` wie im Treppenbau. Die erste Oberschrank-TCN prüfst du in TpaCAD.

## Entscheidungen

| Thema | Entscheidung |
| --- | --- |
| Tag-Schema | `<Kürzel>_<Bereich>_<Teil>` für alle Schränke; Hochschrank und Unterschrank mit Tür werden umgestellt |
| Komponenten | entstehen hier mit Claude Code als Skript; kein Plugin, das Schränke erzeugt (vielleicht später) |
| Maße in der TCN | Fräsmaß, auch `DL/DH` |
| Formatieren | immer `squad` auf der Fräse, Übermaß kommt aus OCL |
| Waagerechte Bohrungen | Standard-Horizontalbohrer in X und Y, kein Aggregat, keine Hilfsflächen |
| Verschachtelung | macht OCL, nicht das Plugin |
| Feld in der Kopfzeile | `s…` bleibt wie in den Vorlagen; Pendeln kommt später |
| `fittingx` `#8508/#8509` | `1/1` = gleichmäßig verteilen, `0/0` = festes Raster ab Start |
| Schubkasten | Boden konfigurierbar, Schublade im Standard-Lochraster, Höhenoffset der Schiene als Parameter, Standard 0 mm |
| Kastenboden-Taschen | bleiben: nötig für euer Schubkastensystem, 1:1 aus `Schubkastenboden.tcn` |
| Schienen-Lochbild | Spalten fester Abstand von vorn/hinten, Zeilen immer gleich |
| Topfbänder | im Lochraster der Seite, Bohrhöhe in der Tür wird berechnet |
| Ø5, 21 tief | Schraubenbohrung |
| Ø3 im Boden | Sockelfüße, Bild immer gleich, Lage angepasst |
| Bohrtiefen Front | immer 5 mm |
| Rückwandnut | für 8-mm-Rückwand, normaler 8-mm-Fräser, 9 mm tief |
| Rückwand-Versatz 25 mm | nur bei Oberschränken (Fach dahinter für die Aufhängung); Unter- und Hochschränke wie bisher |
| Oberschrank-Rückwand | 8 mm in Nut in Seiten und Boden, von oben eingeschoben; Deckel endet vor der Rückwand und wird mit ihr verschraubt: 3 Schrauben, je 50 mm von den Seiten und eine in der Mitte (Ø4 durch die Rückwand, Ø3 × 15 in die Deckelkante, Ø als Annahme) |
| Frontfarbe | Bereiche alle / Ober / Unter / Hoch; nur Frontmaterialien, erkannt am Namen (beginnt mit „Front“, z. B. „Front Eiche 19mm“); Griff mit Lochmaß und Lage |
| dxf4tcn-Quelltext | wird nicht gebraucht |

## Noch offen

- [ ] **Schrankaufhänger:** Typ und CNC-Bearbeitung klärst du noch. Bis dahin plane ich nur das Fach hinter der Rückwand.

&#32;→ nein die sind nötig für das schubkasten system das wir nutzen

&#32;→ 8mm stärke, normaler 8mm fräser;  → NUR für Hiochschränke (andere bauswiese für das  "fach" hinterm schrank das so ensteht, um die auhängung unterzubringen);&#32;

&#32;ja und wird dann mit der rückwand verschraube, diese benötigt dafür bohrungen

&#32;muss ich noch klären

&#32;0

## Schritte

Vorschlag: in kleinen, einzeln prüfbaren Stücken, jedes mit Tests ohne SketchUp wie bei Treppenbau und Schränken. Nach Schritt 3 kannst du die erste echte TCN in TpaCAD öffnen.

1. **Tags vereinheitlichen:** Hochschrank, Unterschrank Schubladen und Unterschrank Tür auf `<Kürzel>_<Bereich>_<Teil>` + `JT_Schrank` (mit `kategorie`) umstellen.
2. **Oberschrank-Skript:** eine Komponente mit 1 oder 2 Türen, 8-mm-Rückwand in Nut, korrigierte Deckel-Formel, Material „Melamin weiss“.
3. **Schubkasten:** Boden konfigurierbar, Schubladenhöhen im Lochraster, Höhenoffset der Schiene.
4. **Frontfarbe und Griffe:** eigener Menüpunkt; geht schon nach Schritt 1.
5. **Erster Export, nur Korpus:** Teile einsammeln, vermessen, Fräsmaß, Kopf + `squad` + Dübel Boden/Deckel/Strebe ↔ Seiten. Vergleich gegen deine `Boden.tcn`, `Strebe.tcn`, `Seite.tcn`.
6. **Lochreihen, Sockelfüße, Rückwandnut** dazu.
7. **Schubladen:** Schienen-Lochbild in den Seiten, Kastenboden, Vorderstück.
8. **Türen:** Topfbänder in Tür und Seite, Griffbohrungen.
9. **Dialog und Listen:** Auswahl, Vorschau, Warnungen, Fräsliste `.xmlst`, Teileliste `.csv`, als eigene `.rbz`.

Das Plugin kommt ins Repo `sketchup_kuechenplaner2`, Ordner `sketchup-tcn-export-plugin/`; dort liegen schon README und deine Beispiel-TCN. Den TCN-Writer aus dem Treppenbau kopiere ich als gemeinsame Datei hinüber.
