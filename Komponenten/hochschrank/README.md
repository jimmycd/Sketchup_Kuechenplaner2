# Hochschrank (Dynamic Component)

## Installieren und benutzen
1. SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `hochschrank.rbz` wählen (oder `Kuechenplaner_alle.rbz` aus dem Hauptordner für alle Komponenten auf einmal).
2. *Erweiterungen → Küchenplaner → Hochschränke → Hochschrank…* baut den Schrank im aktuellen Modell (Kürzel für die Tags automatisch, siehe unten). Maße und Optionen danach in den *Komponentenoptionen* einstellen.

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
* **Zargenhöhe und Schiene (LEGRABOX free, MD-015/4):** Zarge **C** (177 mm, Holzrückwand 148 mm), wenn der Kasten Platz hat, sonst **M** (90,5 mm, Holzrückwand 62 mm). Platz: oberste Schublade bis 30 mm (`Kasten_Abstand_oben`) unter die Frontoberkante, darunter bis an die Frontoberkante (die Front deckt Zarge und Fronthalter ab). Die Schiene sitzt mindestens 38 mm über dem festen Boden darunter. Passt nicht einmal M, meldet der TCN-Export das. Die Beschläge dazu stehen auf der letzten Seite der Stückliste.
* **Kein Lochraster** (Jürgen 2026-11-06): Der Kasten sitzt genau 30 mm (`Kasten_Abstand_unten`) über der Front-Unterkante, die unterste Schublade so, dass die Schiene 38 mm über dem Korpusboden liegt. Die Schienenbohrungen sitzen dort, wo der Kasten sie braucht (`Lochraster_Start`/`Lochraster` gelten nur noch für die Lochreihen der Fächer ohne Schubladen). Zarge: die höchste LEGRABOX-free-Zarge, die Platz hat (F 241, C 177, K 128,5, M 90,5, N 66,5 mm; Holzrückwand F 212, C 148, K 99, M 62, N 37 – nur C aus der Anleitung, die anderen abgeleitet).
* Einlegeböden 10 mm von vorne zurückgesetzt, gleichmäßig verteilt.
* Material: alle Platten „Melamin weiss“ (*Plattenwerkstoff*) (Stärken 8/16/19 mm). Ist das Material im Modell schon eingerichtet, bleibt es unverändert.

## Material und Anleimer
Geplant wird in SketchUp immer das **Endmaß**. Anleimer werden nur als Material zugewiesen: Die Kantenflächen bekommen das Material „Anleimer Melamin weiss“ (Typ *Kante*, 2 mm, „Kantenstärke abziehen“ an). Stückliste und Zuschnitt ziehen die 2 mm ab und zeigen Zuschnitt- und Fertigmaß.

| Teil | Kanten mit Anleimer |
|---|---|
| Seiten | vorne, oben |
| Boden, Deckel, Zwischenböden, Einlegeböden | vorne |
| Rückwand | links, rechts, oben |
| Fronten, Tür | alle vier |
| Schubkasten: Rückwand | oben |
| Schubkasten-Boden | keine |

Ausgeblendete Schubladen und Einlegeböden erscheinen nicht in der Stückliste.

## Tags
Jedes Teil hat einen eigenen, eindeutigen Tag `<Kürzel>_<Bereich>_<Teil>` für die Zuordnung zu CAD/CAM-Dateien, z. B. `HS1_SeiteL`, `HS1_Deckel`, `HS1_O_Einlegeboden2`, `HS1_O_Tuer`, `HS1_U1_Front`, `HS1_M2_KastenRueckwand` (U = unten, M = Mitte, Nummer 1 = oberste Schublade im Bereich, O = oben). Korpusteile haben keinen Bereich.

Das Kürzel ist `HS1`, oder `HS2` usw., wenn es im Modell schon vergeben ist. Ein eigenes Kürzel: `Hochschrank.erstellen({ 'Kuerzel' => 'HS2' })` in der Ruby-Konsole.

Zusätzlich steht an jedem Teil das Attribut-Wörterbuch `JT_Schrank` mit `schrank` (Kürzel), `typ`, `kategorie` (Unterschrank, Oberschrank oder Hochschrank), `bereich`, `teil` und `rolle` (z. B. Seite, Boden, Front). Daran erkennt das TCN-Export-Plugin die Teile; die Frontfarbe-Funktion wählt über `kategorie` die Schränke aus.

Weitere feste Maße (Materialstärken, Abstände) stehen als Attribute im Fenster *Komponentenattribute*.

## Hilfe in SketchUp
Eine Kurzfassung (ein Satz, `HILFE_KURZ` in `src/hochschrank/main.rb`) steht oben im Fenster *Komponentenoptionen* und als Beschreibung der Komponente. Die ausführliche Doku steht nur hier, damit das Fenster ganz lesbar bleibt.

## Tests
`ruby test/test_hochschrank.rb` – prüft ohne SketchUp (Mock-API und DC-Formel-Auswerter) Geometrie, Formeln, Material, Anleimer, Tags und die Kurzhilfe.
