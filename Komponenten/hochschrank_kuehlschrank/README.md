# Hochschrank Kühlschrank (Dynamic Component)

Hochschrank für einen Einbau-Kühlschrank, Gefrierschrank oder eine Kühl-Gefrier-Kombi mit Möbeltür. Unten optional Schubladen, oben ein Fach mit Tür oder offen. Basis ist der [Hochschrank Geräte](../hochschrank_geraete/). Plan: [docs/plaene/hochschrank-kuehlschrank.md](../../docs/plaene/hochschrank-kuehlschrank.md).

## Installieren und benutzen
1. SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `hochschrank_kuehlschrank.rbz` wählen (oder `Kuechenplaner_alle.rbz` aus dem Hauptordner für alle Komponenten auf einmal).
2. *Erweiterungen → Küchenplaner → Hochschränke → Hochschrank Kühlschrank…* (oder Symbolleiste *Schrank einfügen*) fragt Breite, Höhe und Tiefe ab und baut den Schrank. Vorschlag für die Tiefe ist **560 mm**, weil Einbau-Kühlgeräte mindestens 550 mm Nischentiefe brauchen. Ist die Tiefe, die lichte Breite (unter 560 mm) oder die Höhe zu knapp, kommt ein Hinweis; gebaut wird trotzdem.
3. Alle Maße und Optionen bleiben in den *Komponentenoptionen* änderbar, auch die Tiefe.

## Komponentenoptionen
| Bereich | Option | Standard |
|---|---|---|
| Gesamt | Breite, Höhe, Tiefe; angezeigt wird die lichte Breite der Nische | 600 / 2100 / 560 mm |
| Nische | lichte Höhe 880 / 1020 / 1220 / 1400 / 1580 / 1780 / 1940 mm oder *frei* (eigene Höhe) | 1780 mm |
| Nische | Gerät: Kühlschrank, Gefrierschrank, Kühl-Gefrier-Kombi | Kühlschrank |
| Nische | Lüftung: *Schacht hinten* oder *über Sockel und Front* | Schacht hinten |
| Tür | Technik: *Schlepptür* oder *Festtür*; Anschlag links/rechts | Schlepptür, rechts |
| Tür | Höhe untere Tür bei Kühl-Gefrier-Kombi (laut Einbauskizze des Geräts) | 720 mm |
| Unten | Anzahl Schubladen 0–4 (0 = Gerät steht auf dem Boden), Höhe Bereich, Anteil je Schublade, Stärke Kastenboden, Höhenoffset Schiene | 0, 700 mm |
| Oben | *Offenes Fach* oder *Tür*, Einlegeböden 0–2; Höhe ergibt sich (wird angezeigt) | Tür, 0 |

Feste Maße (Materialstärken, Schachttiefe 40 mm, Nuttiefe 9 mm, Fugen 2 mm) stehen im Fenster *Komponentenattribute*.

## Aufbau
* Seiten über die volle Höhe, Boden, Deckel, Zwischenboden über der Nische (`ZwischenbodenOben`) und mit Schubladen einer darunter (`ZwischenbodenUnten`). Korpus 19 mm, Rückwand 8 mm, Fugen 2 mm.
* **Lüftung Schacht hinten:** Die Nische hat keine Rückwand. Boden, Zwischenböden, Einlegeböden und Deckel enden 48 mm (Schacht 40 + Rückwand 8) vor der Hinterkante der Seiten. Oberes Fach (`RueckwandOben`) und Schubladenbereich (`RueckwandUnten`) haben eigene Rückwände in einer 9 mm tiefen Nut der Seiten. Dahinter bleibt ein Schacht über die ganze Höhe: Luft kommt unten durch das Sockelgitter (gehört nicht zum Schrank, ca. 200 cm² vorsehen) und geht oben hinaus.
* **Lüftung über Sockel und Front:** Rückwand durchgehend hinter den Seiten, Böden in voller Tiefe (wie Hochschrank Geräte).
* **Türen:** Die Möbeltür deckt die Nische von der Unterkante (bzw. über der obersten Schubladenfront) bis 2 mm unter die Tür des oberen Fachs. Bei der Kombi sind es zwei Türen (`TuerUnten`, `TuerOben`). Jede Tür sitzt in einer Scharnier-Komponente am Anschlag und öffnet mit *Interagieren*.
* **Schlepptür / Festtür:** steht als Komponentenattribut `Tuertechnik` am Schrank (1 = Schlepptür mit Topfbändern am Korpus, 2 = Festtür auf der Gerätetür). Topfbandbohrungen macht der TCN-Export noch für keinen Schrank.
* Schubladen wie beim Hochschrank: **Blum LEGRABOX free** im Lochraster der Seite, Nennlänge aus der lichten Tiefe bis zur Rückwand.
* Material: alle Platten „Melamin weiss“.

## Gerät
In der Nische steht ein halbtransparenter **Platzhalter** auf dem Tag `Geraete_Plan` (Material „Geraet Plan“, kein Plattenmaterial, kein `JT_Schrank`); er wird nicht exportiert. Für *Geräte in Schränke setzen* steht die Nische im Wörterbuch `JT_Nische_N1` am Schrank: `nische`, `geraet` (`Kuehlgeraet88` … `Kuehlgeraet194`, bei *frei* `Kuehlgeraet`), `art` (`Kuehlschrank`, `Gefrierschrank`, `KuehlGefrier`), lichte `breite`, `hoehe`, `tiefe` und der Einfügepunkt `x`, `y`, `z` (vorne links auf dem Boden unter dem Gerät), alles in mm, Stand beim Erzeugen.

## Kanten
Geplant wird immer das **Endmaß**. Die Kanten bekommen das Material „Anleimer Melamin weiss“ (2 mm); Stückliste, Etiketten und Zuschnitt im Küchenplaner-Plugin ziehen sie ab.

| Teil | Kanten mit Anleimer |
|---|---|
| Seiten | vorne, oben |
| Boden, Deckel, Zwischenböden, Einlegeböden | vorne |
| Rückwand (durchgehend) | links, rechts, oben |
| Rückwand oben/unten (in der Nut) | keine |
| Fronten, Türen | alle vier |
| Schubkasten: Rückwand | oben |
| Schubkasten-Boden | keine |

## Tags
Jedes Teil hat einen eigenen Tag `<Kürzel>_<Bereich>_<Teil>`, z. B. `HK1_SeiteL`, `HK1_RueckwandOben`, `HK1_N_Tuer`, `HK1_N_TuerUnten`, `HK1_O_Tuer`, `HK1_U1_Front` (N = Nische, O = oben, U = unten, Nummer 1 = oberste Schublade). Das Kürzel ist `HK1`, oder `HK2` usw., wenn es im Modell schon vergeben ist. Eigenes Kürzel: `HochschrankKuehlschrank.erstellen({ 'Kuerzel' => 'HK2' })`.

An jedem Teil steht das Wörterbuch `JT_Schrank` mit `schrank`, `typ` (`Hochschrank_Kuehlgeraet`), `kategorie` (`Hochschrank`), `bereich`, `teil` und `rolle`. Boden und `ZwischenbodenUnten` tragen zusätzlich `nische` = `N1`: Das TCN-Plugin bohrt in der Nische keine Lochreihen. Frontfarbe (Auswahl Hochschränke) und Sockelfüße funktionieren wie beim Hochschrank.

## Hilfe in SketchUp
Eine Kurzfassung dieser Doku steht oben im Fenster *Komponentenoptionen* und als Beschreibung in *Entitätsinformationen*, mit Link auf diese Seite.

## Tests
`ruby test/test_hochschrank_kuehlschrank.rb` prüft ohne SketchUp (Mock-API und DC-Formel-Auswerter) Nischenhöhen, Lüftungsschacht und Rückwände, Türen und Fugen, Anschlag, Schubladen im Lochraster, Platzhalter, `JT_Nische_N1`, Material, Kanten, Tags, Hinweise im Dialog, die Kurzhilfe und das nachträgliche Ändern der Tiefe, jeweils auch nach dem Umstellen in den Komponentenoptionen. Der TCN-Export (Dübel an den gekürzten Böden, Nut, Lochreihen) steht in `sketchup-tcn-export-plugin/test/test_export.rb`. In echtem SketchUp noch nicht ausprobiert.
