# Unterschrank Kochfeld mit Abzug (SketchUp)

Erweiterung, die einen **Unterschrank für ein Kochfeld mit integriertem Abzug** (Muldenlüfter, z. B. BORA, Siemens/Bosch/Neff, Miele, AEG) als Dynamic Component erzeugt. Aufbau wie beim [Unterschrank mit Schubladen](../unterschrank_schubladen/), aber:

* oben eine **feste Blende** statt einer Schublade (Einbauraum für Kochfeld und Lüftermodul),
* darunter **1–3 Schubladen** (Blum LEGRABOX, Standard 2 gleich hohe), kürzer um die Installationstiefe,
* hinten ein **freier Installationsraum** für den Kanal, der senkrecht in den Sockel läuft,
* ein **Kanalausschnitt im Boden** zum Sockel (Umluftfilter im Sockel oder Abluft nach außen),
* **Strebe vorn hochkant**, damit der Kochfeldausschnitt frei bleibt; **keine Strebe hinten** (dort sitzen Lüfter und Kanal).

Die Gerätemaße sind **Richtwerte**. Vor dem Bau mit der Einbauanleitung des Geräts prüfen (Einbauhöhe unter der Arbeitsplatte, Kanalmaße, Sockelhöhe, Lüftungsquerschnitt der Sockelblende bei Umluft).

## Installation
1. SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `unterschrank_kochfeld.rbz` wählen (oder `Kuechenplaner_alle.rbz` aus dem Hauptordner für alle Komponenten auf einmal).
2. Danach: *Erweiterungen → Küchenplaner → Unterschrank Kochfeld mit Abzug…*

Ohne Installation: Ruby-Konsole `load 'C:/Pfad/zu/src/unterschrank_kochfeld/main.rb'`, dann `UnterschrankKochfeld.dialog`.

## Dialog und Komponentenoptionen
| Feld | Standard | Bedeutung |
|---|---|---|
| Breite / Höhe / Tiefe | 800 / 700 / 800 mm | Korpus ohne Front/Rückwand, Breite passend zum Kochfeld (60/80/90) |
| Höhe Blende | 200 mm | mindestens Einbauraum von Kochfeld + Lüfter unter der Korpusoberkante |
| Anzahl Schubladen | 2 (1–3) | unter der Blende |
| Anteil Schublade 1–3 | 1 / 1 | Aufteilung wie beim Unterschrank mit Schubladen (1 = oben) |
| Installationstiefe | 150 mm | hinten frei für den Kanal |
| Breite / Lage Kanalausschnitt | 300 mm, mittig | links / mittig / rechts; links und rechts 100 mm von der Seite (frei von den Sockelfüßen) |
| Lüftung | Umluft | Umluft (Filter im Sockel, Sockelblende mit Lüftungsgitter) oder Abluft (Kanal durch den Sockel zur Wand). Ändert den Schrank nicht, steht für die Geräte-Darstellung in `JT_Nische` |
| Strebe vorn | hochkant | wahlweise flach wie beim Unterschrank |
| Stärke Arbeitsplatte | 40 mm | nur für die Lage der Geräte, nicht für OCL |

Mit *Interagieren* auf eine Schublade klicken → sie fährt heraus.

## Aufbau
* **SeiteL/R, Boden, Rückwand** wie beim Unterschrank mit Schubladen (Seiten sind immer gleich).
* **Boden:** in SketchUp voll gezeichnet (OCL-Zuschnitt = volles Rechteck). Der **Kanalausschnitt** steckt nur in den CNC-Daten: Der TCN-Export fräst ihn als durchgehende Tasche (rect.tmcr, Stärke + 1 mm) von unten. Lage: `Ausschnitt_Links` ab der linken Bodenkante, 20 mm Steg vor der Hinterkante (`Kanal_Steg`), Tiefe = Installationstiefe − 2 × Steg (Standard 110 mm für einen Flachkanal ca. 222 × 89 mm).
* **StrebeVorn:** hochkant 100 × 19 mm direkt hinter der Blende, die Blende wird von innen durch die Strebe verschraubt (die Schraubbohrungen der Blende sind noch nicht im TCN).
* **Blende:** feste Front oben, 2 mm Fuge zur obersten Schubladenfront, Anleimer rundum. Rolle „Front“, damit *Frontfarbe ändern* sie mitnimmt; Griffbohrungen bekommt sie nicht.
* **Schubladen:** Front + LEGRABOX-Kasten (Boden LW − 35 × NL − 10, Holzrückwand LW − 38 × 148) im Lochraster wie beim Unterschrank mit Schubladen. Die Nennlänge NL ist die größte mit NL + 3 mm ≤ Tiefe − Installationstiefe (800 / 150 → NL 600) und steht als Attribut `NL` am Schrank; der TCN-Export bohrt die Schienen nach diesem Wert.

Arbeitsplatte, Kochfeldausschnitt in der Platte und Sockelblende gehören wie bei den anderen Komponenten nicht zum Schrank.

## OpenCutList (OCL)
* **Material:** jedes Teil „Melamin weiss“ (Plattenmaterial in OCL), Endmaß in SketchUp, den 2-mm-Abzug für den Anleimer rechnet nur OCL.

| Teil | Anleimer |
|---|---|
| Seiten, Boden | Vorderkante |
| Strebe vorn (verdeckt), Rückwand, Kastenboden | keiner |
| Blende, Fronten | rundum |
| Kastenrückwand | Oberkante |

* **Tags:** `<Kürzel>_<Bereich>_<Teil>`, Kürzel `USK1`, `USK2` …: `USK1_SeiteL`, `USK1_Boden`, `USK1_StrebeVorn`, `USK1_Rueckwand`, `USK1_Blende`, `USK1_S1_Front`, `USK1_S1_KastenBoden`, `USK1_S1_KastenRueckwand`, Gruppen `USK1_S1_Schublade`. Am Teil das Wörterbuch `JT_Schrank` mit `typ` = Unterschrank_Kochfeld und `kategorie` = Unterschrank (Frontfarbe „nur Unterschränke“, Sockelfüße im Export). Die Rolle `Blende` → `Front` steht in der gemeinsamen `ROLLEN`-Tabelle aller Komponenten.

## Nische für die Geräte-Darstellung
Am Schrank steht das Wörterbuch `JT_Nische` (Stand beim Erzeugen, Maße in mm): `nische` = KF, `geraet` = KochfeldAbzug80 (nach Breite), `breite` (lichte Weite), `hoehe` (= Höhe Blende), `tiefe`, Einfügepunkt `x`/`y`/`z` vorne links auf der Korpusoberkante, dazu `lueftung` (Umluft/Abluft), `installationstiefe`, `kanal_breite`, `kanal_lage`, `kanal_x` (linke Kante des Ausschnitts ab Außenkante Schrank) und `arbeitsplatte`. Daran richtet sich der Platzhalter „Kochfeld mit Abzug“ aus. Geräte haben kein Plattenmaterial und kein `JT_Schrank`, OCL und TCN bleiben davon unberührt.

## Hilfe in SketchUp
Eine Kurzfassung dieser Doku steht oben im Fenster *Komponentenoptionen* (Summary/Description) mit Link auf diese Seite. Der Text steht als `HILFE` in `src/unterschrank_kochfeld/main.rb`.

## Tests
`ruby test/test_generator.rb` – prüft ohne SketchUp (Mock-API und DC-Formel-Auswerter) Geometrie und Formeln (Blende, Fronten, Installationsraum, Einbauraum, Strebe hochkant/flach, Kanalausschnitt, NL), OCL-Material, Anleimer, Tags, `JT_Nische` und die Kurzhilfe, auch nach Umkonfiguration. Der TCN-Export für diesen Schrank wird in `sketchup-tcn-export-plugin/test/test_export.rb` geprüft. Nach Änderungen an `src/` im Hauptordner `./build_rbz.sh` ausführen. In echtem SketchUp noch nicht getestet.
