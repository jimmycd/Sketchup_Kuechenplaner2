# Hochschrank Geräte (Dynamic Component)

Hochschrank für zwei Einbaugeräte übereinander, z. B. Backofen + Mikrowelle oder Backofen + Dampfgarer. Basis ist der [Hochschrank](../hochschrank/).

## Installieren und benutzen
1. SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `hochschrank_geraete.rbz` wählen (oder `Kuechenplaner_alle.rbz` aus dem Hauptordner für alle Komponenten auf einmal).
2. *Erweiterungen → Küchenplaner → Hochschränke → Hochschrank Geräte…* baut den Schrank im aktuellen Modell (Kürzel für die Tags automatisch, siehe unten). Maße und Optionen danach in den *Komponentenoptionen* einstellen.

Wer eine fertige `.skp` für die Komponenten-Bibliothek möchte: Rechtsklick auf den Schrank → *Speichern unter…*.

## Komponentenoptionen
| Bereich | Option |
|---|---|
| Gesamt | Breite, Höhe, Tiefe (Standard 600 / 2100 / 800 mm); angezeigt wird die lichte Breite der Nischen |
| Schubladen | Stärke Kastenboden (16 mm), Höhenoffset Schiene (0 mm) |
| Unten | Höhe Bereich (bis Oberkante Zwischenboden, Standard 700 mm), Anzahl Schubladen 1–6, Anteil Schublade 1–6 (1 = oben) |
| Nische 1 | Gerät (Standard Backofen 60), lichte Höhe bei „frei“; angezeigt wird die lichte Höhe |
| Nische 2 | Gerät (Standard Kompaktgerät 45) oder *keine*, lichte Höhe bei „frei“ |
| Oben | Ausführung *Offenes Fach* / *Tür*, Anzahl Einlegeböden 0–3; Höhe ergibt sich aus dem Rest (wird angezeigt) |

Lichte Nischenhöhen je Gerät (übliche Einbaumaße von Bosch, Siemens, Neff, Miele; im Zweifel Herstellerangabe prüfen und *frei* wählen):

| Gerät | Kennung | lichte Höhe |
|---|---|---|
| Backofen 60 | `Backofen60` | 590 mm |
| Kompaktgerät 45 (Mikrowelle, Dampfgarer, Kompaktbackofen) | `Kompakt45` | 450 mm |
| Mikrowelle 38 | `Mikrowelle38` | 380 mm |
| Wärmeschublade 14 | `Waermeschublade14` | 140 mm |
| frei | `frei` | eigene Höhe |

Die Reihenfolge ist egal: Beide Nischen können jedes Gerät aufnehmen. Die meisten Geräte brauchen eine lichte Breite von mindestens 560 mm (bei 600 mm Breite: 562 mm).

## Aufbau
* Seiten über die volle Höhe, Boden, Deckel, Rückwand 8 mm durchgehend. Korpus 19 mm, Fugen 2 mm.
* Drei feste Zwischenböden: unter Nische 1 (`ZwischenbodenUnten`, Oberkante = Höhe unten), unter Nische 2 (`ZwischenbodenMitte`) und über der obersten Nische (`ZwischenbodenOben`). Bei Nische 2 = *keine* entfällt der mittlere Boden.
* Die Gerätefronten decken die Nischen ab; die oberste Schubladenfront endet 2 mm unter Nische 1, die Tür beginnt an der Oberkante des oberen Zwischenbodens.
* Schubladen wie beim Hochschrank: **Blum LEGRABOX free**, aus Holz nur Boden (LW − 35 × NL − 10, 16 mm) und Holzrückwand (LW − 38 × 148). Der Kasten sitzt im Lochraster der Seite (35 mm, dann alle 32 mm).
* Einlegeböden oben 10 mm von vorne zurückgesetzt, gleichmäßig verteilt.
* Material: alle Platten „Melamin weiss“, in OpenCutList als *Plattenwerkstoff*.

## Geräte
In jeder Nische steht ein halbtransparenter **Platzhalter** auf dem Tag `Geraete_Plan` (Material „Geraet Plan“, kein Plattenmaterial, kein `JT_Schrank`). Er wird nicht exportiert; vor dem OCL-Lauf den Tag ausblenden.

Für die Geräte-Komponenten steht jede Nische im Wörterbuch `JT_Nische_N1` bzw. `JT_Nische_N2` am Schrank: `nische`, `geraet` (Kennung oben), lichte `breite`, `hoehe`, `tiefe` und der Einfügepunkt `x`, `y`, `z` (vorne links auf der Oberkante des Zwischenbodens, an der Korpusvorderkante), alles in mm. Die Werte gelten für den Stand beim Erzeugen.

## OpenCutList (OCL)
Geplant wird in SketchUp immer das **Endmaß**. Anleimer werden nur für OCL zugewiesen (Material „Anleimer Melamin weiss“, 2 mm, „Kantenstärke abziehen“ an).

| Teil | Kanten mit Anleimer |
|---|---|
| Seiten | vorne, oben |
| Boden, Deckel, Zwischenböden, Einlegeböden | vorne |
| Rückwand | links, rechts, oben |
| Fronten, Tür | alle vier |
| Schubkasten: Rückwand | oben |
| Schubkasten-Boden | keine |

## Tags
Jedes Teil hat einen eigenen Tag `<Kürzel>_<Bereich>_<Teil>`, z. B. `HG1_SeiteL`, `HG1_ZwischenbodenMitte`, `HG1_O_Tuer`, `HG1_U1_Front`, `HG1_U2_KastenBoden` (U = unten, Nummer 1 = oberste Schublade, O = oben). Das Kürzel ist `HG1`, oder `HG2` usw., wenn es im Modell schon vergeben ist. Ein eigenes Kürzel: `HochschrankGeraete.erstellen({ 'Kuerzel' => 'HG2' })`.

An jedem Teil steht das Wörterbuch `JT_Schrank` mit `schrank`, `typ` (`Hochschrank_Geraete`), `kategorie` (`Hochschrank`), `bereich`, `teil` und `rolle`. Die Zwischenböden unter den Geräten tragen zusätzlich `nische` (N1/N2): Das TCN-Plugin bohrt in den Nischen keine Lochreihen. Frontfarbe (Auswahl Hochschränke) und Sockelfüße funktionieren wie beim Hochschrank.

## Hilfe in SketchUp
Eine Kurzfassung dieser Doku steht oben im Fenster *Komponentenoptionen* und als Beschreibung in *Entitätsinformationen*, mit Link auf diese Seite (`HILFE` in `hochschrank_geraete.rb`).

## Tests
`ruby test/test_hochschrank_geraete.rb` – prüft ohne SketchUp (Mock-API und DC-Formel-Auswerter) Nischenmaße je Gerät, Zwischenböden, Fronten und Fugen, Schubladen im Lochraster, Platzhalter, `JT_Nische`, OCL-Material, Anleimer, Tags und die Kurzhilfe, jeweils auch nach dem Umstellen in den Komponentenoptionen. Der TCN-Export des Schranks wird in `sketchup-tcn-export-plugin/test/test_export.rb` geprüft.
