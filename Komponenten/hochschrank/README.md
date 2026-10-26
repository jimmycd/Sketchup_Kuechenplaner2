# Hochschrank (Dynamic Component)

## Installieren und benutzen
1. SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `hochschrank.rbz` wählen (oder `Kuechenplaner_alle.rbz` aus dem Hauptordner für alle Komponenten auf einmal).
2. *Erweiterungen → Küchenplaner → Hochschrank…* baut den Schrank im aktuellen Modell (Kürzel für die Tags automatisch, siehe unten). Maße und Optionen danach in den *Komponentenoptionen* einstellen.

Wer eine fertige `.skp` für die Komponenten-Bibliothek möchte: Rechtsklick auf den Schrank → *Speichern unter…*.

## Komponentenoptionen
| Bereich | Option |
|---|---|
| Gesamt | Breite, Höhe, Tiefe (Standard 600 / 2100 / 800 mm) |
| Schubladen | Stärke Kastenboden (16 mm), Höhenoffset Schiene (0 mm) |
| Unten | Höhe Bereich (bis Oberkante Zwischenboden, Standard 700 mm), Anzahl Schubladen 1–6, Anteil Schublade 1–6 (1 = oben) |
| Mitte | Ausführung *Offenes Fach* / *Schubladen*, lichte Höhe (Standard 600 mm, z. B. Backofen), Anzahl Schubladen 1–4, Anteil 1–4 |
| Oben | Ausführung *Offenes Fach* / *Tür*, Anzahl Einlegeböden 0–3; Höhe ergibt sich aus dem Rest (wird angezeigt) |

Anteile: `1/1/2` = unterste doppelt so hoch; mm-Werte gehen auch, sie werden auf die Bereichshöhe skaliert.
Mit *Interagieren*: Schubladen fahren heraus, die Tür (Anschlag links) öffnet sich.

## Aufbau
* Seiten über die volle Höhe, Boden, Deckel, zwei feste Zwischenböden (unter und über dem Mittelfach), Rückwand 8 mm. Korpus 19 mm, Fugen 2 mm.
* Schubladen wie beim Unterschrank mit Schubladen: Front 19 mm, mindestens 30 mm Abstand zu Front-Unter-/Oberkante.
* **Schubkasten Blum LEGRABOX free** (Montageanleitung MD-015/4): Seiten aus Metall, aus Holz nur **Boden** (lichte Weite − 35 mm × NL − 10 mm, 16 mm) und **Holzrückwand** (lichte Weite − 38 mm × 148 mm, 16 mm, hinten auf dem Boden; bei niedrigen Schubladen niedriger). NL ist die Blum-Nennlänge: die größte in 50-mm-Schritten (max. 650) mit NL + 3 mm ≤ Korpustiefe; sie steht als Attribut `NL` (cm) am Schrank. Der Kasten beginnt an der Korpusvorderkante, mindestens 30 mm über der Front-Unterkante.
* **Lochraster:** Der Kasten sitzt so, dass die Schienenbohrung (Unterkante Kasten + *Höhenoffset Schiene*, Standard 0) auf dem 32-mm-Raster der Seite liegt: 35 mm über der Unterkante der Seite (auch im Mittelfach), dann alle 32 mm (`Lochraster_Start`, `Lochraster` in den Komponentenattributen). Dafür rückt der Kasten bis zu 32 mm über den Mindestabstand von 30 mm zur Front-Unterkante; oben bleiben 30 mm Abstand, der Kasten wird entsprechend niedriger.
* Einlegeböden 10 mm von vorne zurückgesetzt, gleichmäßig verteilt.
* Material: alle Platten „Melamin weiss“, in OpenCutList als *Plattenwerkstoff* (Stärken 8/16/19 mm). Ist das Material im Modell schon in OCL eingerichtet, bleibt es unverändert.

## OpenCutList (OCL)
Geplant wird in SketchUp immer das **Endmaß**. Anleimer werden nur für OCL zugewiesen: Die Kantenflächen bekommen das Material „Anleimer Melamin weiss“ (OCL-Typ *Kante*, 2 mm, „Kantenstärke abziehen“ an). OCL zieht die 2 mm dann selbst ab und zeigt Zuschnitt- und Fertigmaß.

| Teil | Kanten mit Anleimer |
|---|---|
| Seiten | vorne, oben |
| Boden, Deckel, Zwischenböden, Einlegeböden | vorne |
| Rückwand | links, rechts, oben |
| Fronten, Tür | alle vier |
| Schubkasten: Rückwand | oben |
| Schubkasten-Boden | keine |

Ausgeblendete Schubladen und Einlegeböden erscheinen nicht in der OCL-Liste.

## Tags
Jedes Teil hat einen eigenen, eindeutigen Tag `<Kürzel>_<Bereich>_<Teil>` für die Zuordnung zu CAD/CAM-Dateien, z. B. `HS1_SeiteL`, `HS1_Deckel`, `HS1_O_Einlegeboden2`, `HS1_O_Tuer`, `HS1_U1_Front`, `HS1_M2_KastenRueckwand` (U = unten, M = Mitte, Nummer 1 = oberste Schublade im Bereich, O = oben). Korpusteile haben keinen Bereich.

Das Kürzel ist `HS1`, oder `HS2` usw., wenn es im Modell schon vergeben ist. Ein eigenes Kürzel: `Hochschrank.erstellen({ 'Kuerzel' => 'HS2' })` in der Ruby-Konsole.

Zusätzlich steht an jedem Teil das Attribut-Wörterbuch `JT_Schrank` mit `schrank` (Kürzel), `typ`, `kategorie` (Unterschrank, Oberschrank oder Hochschrank), `bereich`, `teil` und `rolle` (z. B. Seite, Boden, Front). Daran erkennt das TCN-Export-Plugin die Teile; die Frontfarbe-Funktion wählt über `kategorie` die Schränke aus.

Weitere feste Maße (Materialstärken, Abstände) stehen als Attribute im Fenster *Komponentenattribute*.

## Hilfe in SketchUp
Eine Kurzfassung dieser Doku steckt in der Komponente selbst: Sie steht oben im Fenster *Komponentenoptionen* (Summary und Description, nur lesbar) und als Beschreibung in *Entitätsinformationen* bzw. im Komponenten-Browser. Am Ende steht der Link auf diese Seite. Der Text steht als `HILFE` in `hochschrank.rb`.

## Tests
`ruby test/test_hochschrank.rb` – prüft ohne SketchUp (Mock-API und DC-Formel-Auswerter) Geometrie, Formeln, OCL-Material, Anleimer, Tags und die Kurzhilfe.
