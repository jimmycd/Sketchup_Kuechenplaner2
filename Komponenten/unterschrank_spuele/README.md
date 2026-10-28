# Spülenschrank (Dynamic Component)

Unterschrank für die Spüle: Korpus wie der Unterschrank mit Tür, aber mit Installationsebene und Rückwand-Ausschnitt für die Anschlüsse, ohne Einlegeböden. Fronten wahlweise Türen oder oben eine feste Blende und darunter ein Auszug für den Abfallsammler.

## Installieren und benutzen
1. SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `unterschrank_spuele.rbz` wählen (oder `Kuechenplaner_alle.rbz` aus dem Hauptordner für alle Komponenten auf einmal).
2. *Erweiterungen → Küchenplaner → Unterschränke → Spülenschrank…* baut den Schrank im aktuellen Modell (Kürzel für die Tags automatisch, siehe unten). Maße und Optionen danach in den *Komponentenoptionen* einstellen.

Wer eine fertige `.skp` für die Komponenten-Bibliothek möchte: Rechtsklick auf den Schrank → *Speichern unter…*.

## Komponentenoptionen
| Option | Standard |
|---|---|
| Breite / Höhe / Tiefe (Korpus ohne Front) | 800 / 700 / 800 mm |
| Fronten | Türen oder Blende + Auszug; Standard Blende + Auszug |
| Türen (bei Fronten = Türen) | eine Tür (Anschlag links) oder zwei Türen; Standard zwei |
| Höhe Blende | 200 mm |
| Siphon-Freiraum unter der Blende | 200 mm |
| Installationsebene (Rückwand vor der Hinterkante) | 50 mm |
| Rückwand-Ausschnitt: Unterkante über Korpus-Unterkante / Höhe / Steg seitlich und oben | 250 / 400 / 50 mm; Höhe 0 = kein Ausschnitt |

Feste Maße als Attribute (Fenster *Komponentenattribute*): `Materialstaerke_Korpus` 19 mm, `Materialstarke_Rueckwand` 8 mm, `Nuttiefe` 9 mm, `BreiteStreben` 100 mm, `Spaltbreite` 2 mm und die LEGRABOX-Werte wie im Unterschrank mit Schubladen (`Materialstaerke_Kastenboden`, `Hoehe_Kastenrueckwand`, `Lochraster_Start`, `Lochraster`, `Kasten_Abstand_unten`, `Hoehenoffset_Schiene`).

Mit *Interagieren* öffnen sich die Türen bzw. fährt der Auszug heraus.

## Aufbau
* **Korpus** wie beim Unterschrank mit Tür: Seiten über die volle Höhe und Tiefe, Boden zwischen den Seiten über die volle Tiefe, oben Strebe vorn und Strebe hinten (100 mm, liegend). Der Korpus beginnt bei y = 19 mm, die Fronten liegen 2 mm davor.
* **Installationsebene:** Die Rückwand (8 mm) liegt 50 mm vor der Hinterkante der Seiten. Sie steckt in einer 9 mm tiefen Nut der Seiten, steht auf dem Boden und ist oben bündig. Dahinter ist Platz für die Leitungen; der Boden geht bis hinten durch. Die Strebe hinten endet vor der Rückwand.
* **Rückwand-Ausschnitt** für Wasser und Abfluss: Rechteck über die lichte Breite minus 50 mm Steg je Seite, Standard 250 bis 650 mm über der Korpus-Unterkante (dort liegen bei 100–150 mm Sockel die üblichen Wandanschlüsse). Oben bleibt mindestens der Steg stehen. Der Ausschnitt ist als Umriss vor der Rückwand gezeichnet (Tag `<Kürzel>_Rueckwand_Ausschnitt`, nur Kanten, kein Teil für OpenCutList); die Rückwand selbst bleibt eine volle Platte (Zuschnitt), den Ausschnitt fräst der TCN-Export.
* **Türen** über die volle Höhe, außen 1 mm Fuge, zwischen zwei Türen 2 mm. Topfbänder setzt der TCN-Export, sobald Türen dort umgesetzt sind.
* **Blende + Auszug:** oben eine feste Blende vor dem Spülbecken, darunter 2 mm Fuge und die Front des Auszugs bis zur Unterkante. Der Auszug ist ein **Blum LEGRABOX free** wie im Unterschrank mit Schubladen: Boden LW − 35 × NL − 10 (16 mm), Holzrückwand LW − 38 (16 mm), Schienen-Nennlänge NL aus der Tiefe bis zur Rückwand (Standard NL 650). Der Kasten sitzt unten im Lochraster (35 mm über Korpus-Unterkante). Seine Oberkante bleibt mindestens den **Siphon-Freiraum** unter der Blende; die Holzrückwand ist höchstens 148 mm hoch und wird bei niedrigen Schränken entsprechend niedriger. Der Abfallsammler steht im Kasten.

## OpenCutList (OCL)
Gezeichnet ist immer das **Endmaß**. Anleimer werden nur für OCL zugewiesen: Kantenflächen mit dem Material „Anleimer Melamin weiss“ (OCL-Typ *Kante*, 2 mm, „Kantenstärke abziehen“ an). Platten haben „Melamin weiss“ (*Plattenwerkstoff*).

| Teil | Kanten mit Anleimer |
|---|---|
| Seiten, Boden, Strebe vorn | vorne |
| Strebe hinten, Rückwand, Kastenboden | keine |
| Türen, Blende, Front Auszug | alle vier |
| Kastenrückwand | oben |

## Tags
Jedes Teil hat den Tag `<Kürzel>_<Bereich>_<Teil>`: `USP1_SeiteL`, `USP1_SeiteR`, `USP1_Boden`, `USP1_StrebeVorn`, `USP1_StrebeHinten`, `USP1_Rueckwand`, `USP1_Tuer`, `USP1_TuerL`, `USP1_TuerR`, `USP1_B_Front` (Blende), `USP1_A_Front`, `USP1_A_KastenBoden`, `USP1_A_KastenRueckwand` (Bereich A = Auszug). Der Auszug als Ganzes hat `USP1_A_Auszug`. Das Kürzel ist `USP1`, oder `USP2` usw., wenn es im Modell schon vergeben ist. An jedem Teil steht das Wörterbuch `JT_Schrank` mit `schrank`, `typ` (Spuelenschrank), `kategorie` (Unterschrank), `bereich`, `teil` und `rolle`; die Blende hat die Rolle `Front`, die Frontfarbe-Funktion ändert sie also mit.

## TCN-Export (Plugin Schrank-CNC)
Wie beim Unterschrank: Dübel Boden und Streben an die Seiten, Sockelfüße im Boden, Schienen und Frontbefestigung für den Auszug, Falz im Kastenboden, Lochreihen nur bei Türen. Dazu die Nut für die Rückwand in den Seiten und der Ausschnitt in der Rückwand (Kontur mit dem Nutfräser, 1 mm tiefer als die Rückwand). Die Seiten des Spülenschranks unterscheiden sich damit durch die Nut von den Seiten der anderen Unterschränke.

## Hilfe in SketchUp
Eine Kurzfassung dieser Doku steht oben im Fenster *Komponentenoptionen* (Summary und Description) und als Beschreibung der Komponente, mit Link auf diese Seite. Der Text steht als `HILFE` in `spuelenschrank.rb`.

## Tests
`ruby test/test_spuelenschrank.rb` – prüft ohne SketchUp (Mock-API und DC-Formel-Auswerter) beide Frontvarianten, Umschalten über die Komponentenoptionen, Installationsebene, Ausschnitt, Siphon-Freiraum, LEGRABOX-Maße, Material, Anleimer, Tags und die Kurzhilfe. Den TCN-Export prüft `sketchup-tcn-export-plugin/test/test_export.rb`. In echtem SketchUp ist die Komponente noch nicht getestet.
