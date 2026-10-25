# Unterschrank mit Schubladen (SketchUp)

Erweiterung, die analog zum bestehenden „Unterschrank“ (mit Tür) eine **Dynamic Component mit 1–6 Schubladen** erzeugt.

## Installation
1. SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `unterschrank_schubladen.rbz` wählen.
2. Danach: *Erweiterungen → Unterschrank mit Schubladen…*

Ohne Installation geht es auch über die Ruby-Konsole: `load 'C:/Pfad/zu/src/unterschrank_schubladen/main.rb'` und dann `UnterschrankSchubladen.dialog`.

## Dialog
| Feld | Bedeutung |
|---|---|
| Breite / Höhe / Tiefe (mm) | wie beim Unterschrank mit Tür (Standard 600 / 700 / 800) |
| Anzahl Schubladen | 1–6 |
| Abstand Schrankseite–Kasten (mm) | Abstand Innenseite Schrankseite bis Außenseite Schubkasten, je Seite (Standard 13 mm), passend zum Schienensystem |
| Kürzel für Tags | Vorschlag USS1, USS2 … (frei wählbar, muss im Modell neu sein) |
| Aufteilung von oben | Anteile, z. B. `1;1;2` (unterste doppelt so hoch) oder direkt mm, z. B. `140;140;416` – wird auf die Höhe skaliert |

Der Schrank wird rechts neben vorhandene Geometrie gesetzt.

## Danach ändern (Komponentenoptionen)
Mit dem Werkzeug *Komponentenoptionen* sind Breite, Höhe, Tiefe, **Anzahl Schubladen** und **Anteil Schublade 1–6** (1 = oben) sowie **Abstand Schrankseite–Kasten je Seite**, **Kastenboden** (tragend / zwischen den Seiten), **Stärke Kastenboden** und **Höhenoffset Schiene** jederzeit änderbar. Anteile nicht vorhandener Schubladen werden ignoriert.
Mit *Interagieren* auf eine Schublade klicken → sie fährt heraus.

## Aufbau
* Korpus identisch zum Unterschrank mit Tür: SeiteL/R, Boden, StrebeVorn/-Hinten, Rückwand (gleiche Attributnamen und Formeln, 19 mm Korpus, 8 mm Rückwand, 2 mm Fugen).
* Je Schublade: Front (19 mm, Fuge 2 mm zwischen den Fronten) und Schubkasten aus Seiten, Vorder-/Rückstück (16 mm) und Boden.
* Schubkasten: einstellbarer Abstand zur Schrankseite (Standard 13 mm je Seite), 20 mm kürzer als die Korpustiefe, mindestens 30 mm Abstand zur Front-Unter- und Oberkante.
* **Kastenboden** (Option *Kastenboden*): Standard **tragend**, 16 mm, über die volle Kastenbreite; Seiten, Vorder- und Rückstück stehen darauf (Unterflurschiene). Alternativ *zwischen den Seiten* (dann z. B. 8 mm, Option *Stärke Kastenboden*).
* **Lochraster:** Der Kasten sitzt so, dass die Schienenbohrung (Unterkante Kasten + *Höhenoffset Schiene*, Standard 0) auf dem 32-mm-Raster der Seite liegt: 35 mm über der Unterkante der Seite, dann alle 32 mm (`Lochraster_Start`, `Lochraster` in den Komponentenattributen). Dafür rückt der Kasten bis zu 32 mm über den Mindestabstand von 30 mm zur Front-Unterkante; oben bleiben 30 mm Abstand, der Kasten wird entsprechend niedriger.

Diese festen Maße stehen als Attribute am Unterschrank (Fenster *Komponentenattribute*) und können dort angepasst werden, z. B. `Materialstaerke_Schubkasten`, `Kasten_Abstand_unten`.

## OpenCutList (OCL)
* **Material:** Jedes Teil hat „Melamin weiss“ (Plattenmaterial in OCL). Falls das Material im Modell fehlt, wird es mit den OCL-Einstellungen aus `Unterschrank.skp` angelegt; vorhandene OCL-Einstellungen bleiben unverändert.
* **Anleimer:** Sichtbare Kanten haben das Material „Anleimer weiss“ (OCL-Typ Kante, 2 mm, „Abzug“ aktiv). In SketchUp sind alle Teile im **Endmaß** gezeichnet; den 2-mm-Abzug für das Fräsmaß rechnet nur OCL.

| Teil | Anleimer |
|---|---|
| Seiten, Boden, Strebe vorn | Vorderkante |
| Strebe hinten, Rückwand, Kastenboden | keiner |
| Fronten | rundum |
| Kastenseiten, Vorder-/Rückstück | Oberkante |

Die Tabelle steht als `KANTEN` am Anfang von `main.rb` und ist leicht anpassbar.

* **Tags:** Jedes Teil hat ein eigenes Tag `<Kürzel>_<Bereich>_<Teil>`, z. B. `USS1_SeiteL`, `USS1_Boden`, `USS1_S2_Front`, `USS1_S2_KastenSeiteR` (Bereich `S<n>` = Schublade n, Korpusteile ohne Bereich). Zusätzlich steht an jedem Teil das Attribut-Wörterbuch `JT_Schrank` mit `schrank` (Kürzel), `typ`, `kategorie` (Unterschrank, Oberschrank oder Hochschrank), `bereich`, `teil` und `rolle` (z. B. Seite, Boden, Front). Daran erkennt das TCN-Export-Plugin die Teile; die Frontfarbe-Funktion wählt über `kategorie` die Schränke aus. Die Schubladen-Gruppen selbst haben `USS1_S<n>_Schublade`, damit man eine Schublade komplett ausblenden kann.

## Hilfe in SketchUp
Eine Kurzfassung dieser Doku steckt in der Komponente selbst: Sie steht oben im Fenster *Komponentenoptionen* (Summary und Description, nur lesbar) und als Beschreibung in *Entitätsinformationen* bzw. im Komponenten-Browser. Am Ende steht der Link auf diese Seite. Der Text steht als `HILFE` in `src/unterschrank_schubladen/main.rb`.

## Tests
`ruby test/test_generator.rb` – prüft ohne SketchUp (Mock-API und DC-Formel-Auswerter) Geometrie, Formeln, OCL-Material, Anleimer, Tags und die Kurzhilfe. Prüft außerdem, ob die `.rbz` zum Quelltext passt; nach Änderungen an `src/` deshalb `./build_rbz.sh` ausführen.
