# Unterschrank mit Schubladen (SketchUp)

Erweiterung, die analog zum bestehenden „Unterschrank“ (mit Tür) eine **Dynamic Component mit 1–6 Schubladen** erzeugt.

## Installation
1. SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `unterschrank_schubladen.rbz` wählen (oder `Kuechenplaner_alle.rbz` aus dem Hauptordner für alle Komponenten auf einmal).
2. Danach: *Erweiterungen → Küchenplaner → Unterschränke → Unterschrank mit Schubladen…*

Ohne Installation geht es auch über die Ruby-Konsole: `load 'C:/Pfad/zu/src/unterschrank_schubladen/main.rb'` und dann `UnterschrankSchubladen.dialog`.

## Dialog
| Feld | Bedeutung |
|---|---|
| Breite / Höhe / Tiefe (mm) | Standard 600 / 700 / 800, im Dialog Tiefe 520 vorgeschlagen |
| Anzahl Schubladen | 1–6 |
| Kürzel für Tags | Vorschlag USS1, USS2 … (frei wählbar, muss im Modell neu sein) |
| Aufteilung von oben | Anteile, z. B. `1;1;2` (unterste doppelt so hoch) oder direkt mm, z. B. `140;140;416` – wird auf die Höhe skaliert |

Der Schrank wird rechts neben vorhandene Geometrie gesetzt.

## Danach ändern (Komponentenoptionen)
Mit dem Werkzeug *Komponentenoptionen* sind Breite, Höhe, Tiefe, **Anzahl Schubladen** und **Anteil Schublade 1–6** (1 = oben) sowie **Stärke Kastenboden** und **Höhenoffset Schiene** jederzeit änderbar. Anteile nicht vorhandener Schubladen werden ignoriert.
Mit *Interagieren* auf eine Schublade klicken → sie fährt heraus.

## Aufbau
* Korpus identisch zum Unterschrank mit Tür: SeiteL/R, Boden, StrebeVorn/-Hinten, Rückwand (gleiche Attributnamen und Formeln, 19 mm Korpus, 8 mm Rückwand, 2 mm Fugen).
* Je Schublade: Front (19 mm, Fuge 2 mm zwischen den Fronten) und Schubkasten.
* **Schubkasten Blum LEGRABOX free** (Montageanleitung MD-015/4): Seiten aus Metall, aus Holz nur **Boden** (lichte Weite − 35 mm × NL − 10 mm, 16 mm) und **Holzrückwand** (lichte Weite − 38 mm × 148 mm bei Zarge C bzw. 62 mm bei Zarge M, 16 mm, hinten auf dem Boden). NL ist die Blum-Nennlänge: die größte in 50-mm-Schritten (max. 650) mit NL + 3 mm ≤ Korpustiefe; sie steht als Attribut `NL` (cm) am Schrank. Der Kasten beginnt an der Korpusvorderkante, mindestens 30 mm über der Front-Unterkante.
* **Zargenhöhe und Schiene (LEGRABOX free, MD-015/4):** Zarge **C** (177 mm, Holzrückwand 148 mm), wenn der Kasten Platz hat, sonst niedrigere Zargen (K 128,5 / M 90,5 / N 66,5 mm, Holzrückwand 101 / 63 / 39 mm). Platz: oberste Schublade bis 30 mm (`Kasten_Abstand_oben`) unter die Frontoberkante, darunter bis an die Frontoberkante (die Front deckt Zarge und Fronthalter ab). Die Schiene sitzt mindestens 38 mm über dem festen Boden darunter. Passt nicht einmal N, meldet der TCN-Export das. Die Beschläge dazu stehen auf der letzten Seite der Stückliste.
* **Kein Lochraster** (Jürgen 2026-11-06): Der Kasten sitzt genau 30 mm (`Kasten_Abstand_unten`) über der Front-Unterkante, die unterste Schublade so, dass die Schiene 38 mm über dem Korpusboden liegt. Die Schienenbohrungen sitzen dort, wo der Kasten sie braucht (`Lochraster_Start`/`Lochraster` gelten nur noch für die Lochreihen der Fächer ohne Schubladen). Zarge: die höchste LEGRABOX-free-Zarge, die Platz hat (C 177, K 128,5, M 90,5, N 66,5 mm; Holzrückwand C 148, K 101, M 63, N 39 laut Blum-Tabelle; ist in den Einstellungen LEGRABOX pure gewählt, zusätzlich F 241 mit Holzrückwand 212).

Diese festen Maße stehen als Attribute am Unterschrank (Fenster *Komponentenattribute*) und können dort angepasst werden, z. B. `Materialstaerke_Kastenrueckwand`, `Hoehe_Kastenrueckwand`, `Kasten_Abstand_unten`.

**Schmaler Schrank (Blum SPACE TWIN):** Bei 185–250 mm Breite nennt die Beschlagliste die diagonal versetzten SPACE-TWIN-Korpusschienen (20 kg je Auszug, Zargen M/K/C; Blum-Katalog 2024/2025 S. 232). Bohrbild und Kastenmaße bleiben wie bei LEGRABOX.

## Material und Anleimer
* **Material:** Jedes Teil hat „Melamin weiss“ (Plattenwerkstoff). Falls das Material im Modell fehlt, wird es mit den Material-Einstellungen aus `Unterschrank.skp` angelegt; vorhandene Einstellungen bleiben unverändert.
* **Anleimer:** Sichtbare Kanten haben das Material „Anleimer weiss“ (Typ Kante, 2 mm, „Abzug“ aktiv). In SketchUp sind alle Teile im **Endmaß** gezeichnet; den 2-mm-Abzug für das Fräsmaß rechnen Stückliste, Zuschnitt und TCN-Export.

| Teil | Anleimer |
|---|---|
| Seiten, Boden, Strebe vorn | Vorderkante |
| Strebe hinten, Rückwand, Kastenboden | keiner |
| Fronten | rundum |
| Kastenrückwand | Oberkante |

Die Tabelle steht als `KANTEN` am Anfang von `main.rb` und ist leicht anpassbar.

* **Tags:** Jedes Teil hat ein eigenes Tag `<Kürzel>_<Bereich>_<Teil>`, z. B. `USS1_SeiteL`, `USS1_Boden`, `USS1_S2_Front`, `USS1_S2_KastenRueckwand` (Bereich `S<n>` = Schublade n, Korpusteile ohne Bereich). Zusätzlich steht an jedem Teil das Attribut-Wörterbuch `JT_Schrank` mit `schrank` (Kürzel), `typ`, `kategorie` (Unterschrank, Oberschrank oder Hochschrank), `bereich`, `teil` und `rolle` (z. B. Seite, Boden, Front). Daran erkennt das TCN-Export-Plugin die Teile; die Frontfarbe-Funktion wählt über `kategorie` die Schränke aus. Die Schubladen-Gruppen selbst haben `USS1_S<n>_Schublade`, damit man eine Schublade komplett ausblenden kann.

## Hilfe in SketchUp
Eine Kurzfassung (ein Satz, `HILFE_KURZ` in `src/unterschrank_schubladen/main.rb`) steht oben im Fenster *Komponentenoptionen* und als Beschreibung der Komponente. Die ausführliche Doku steht nur hier, damit das Fenster ganz lesbar bleibt.

## Tests
`ruby test/test_generator.rb` – prüft ohne SketchUp (Mock-API und DC-Formel-Auswerter) Geometrie, Formeln, Material, Anleimer, Tags und die Kurzhilfe. Prüft außerdem, ob die `.rbz` zum Quelltext passt; nach Änderungen an `src/` deshalb im Hauptordner `./build_rbz.sh` ausführen.
