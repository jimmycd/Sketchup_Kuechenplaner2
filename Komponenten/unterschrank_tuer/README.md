# Unterschrank mit Tür (Dynamic Component)

`Unterschrank.skp` (SketchUp 2022) ist die von Hand gebaute Ausgangskomponente, an der sich die anderen Schränke orientieren.

## Komponentenoptionen
| Option | Standard |
|---|---|
| Breite / Höhe / Tiefe (Korpus ohne Front/Rückwand) | 600 / 700 / 800 mm |
| Tür | Ja / Nein |
| Anzahl Einlegeböden | 0–3 |

Feste Maße als Attribute (Fenster *Komponentenattribute*): `Materialstaerke_Korpus` 19 mm, `Materialstarke_Rueckwand` 8 mm (Schreibweise wie im Original), `BreiteStreben` 100 mm, `Spaltbreite` 2 mm.

## Aufbau
SeiteL/R, Boden, StrebeVorn/-Hinten, Rückwand, Tür, Einlegeböden. Korpus beginnt bei y = Materialstärke, die Front sitzt um die Fuge davor, die Rückwand hinter dem Korpus.

## OpenCutList (OCL)
Alle Teile haben „Melamin weiss“ (Plattenmaterial in OCL). Eindeutige Tags je Teil setzt `einrichten.rb` (siehe unten). **Noch offen:** die Anleimer-Zuweisung.

## Tags
Jedes Teil bekommt den Tag `<Kürzel>_<Teil>`: `UST1_SeiteL`, `UST1_SeiteR`, `UST1_Boden`, `UST1_StrebeVorn`, `UST1_StrebeHinten`, `UST1_Rueckwand`, `UST1_Tuer`, `UST1_Einlegeboden1` bis `3`. Das Kürzel ist `UST1`, oder `UST2` usw., wenn es im Modell schon vergeben ist; ein zweiter Lauf behält es bei. Zusätzlich steht an jedem Teil das Attribut-Wörterbuch `JT_Schrank` mit `schrank` (Kürzel), `typ`, `kategorie` (Unterschrank, Oberschrank oder Hochschrank), `bereich`, `teil` und `rolle` (z. B. Seite, Boden, Front). Daran erkennt das TCN-Export-Plugin die Teile; die Frontfarbe-Funktion wählt über `kategorie` die Schränke aus.

## Einlegeböden
Die sichtbaren Einlegeböden teilen den Innenraum zwischen Boden und Streben in gleich hohe Fächer; nicht benötigte Böden sind ausgeblendet und liegen unten. Die Formeln dafür setzt `einrichten.rb` (in der von Hand gebauten `Unterschrank.skp` fehlten sie bzw. wurden nicht ausgewertet, deshalb hatte *Anzahl Einlegeböden* keine Wirkung).

## Einrichten in SketchUp (Hilfe, Tags, Einlegeböden)
Weil es für diese Komponente keinen Generator gibt, werden Kurzhilfe, Tags und die Formeln der Einlegeböden einmalig mit `einrichten.rb` gesetzt (auch wenn das Skript schon einmal lief, bitte erneut ausführen):
1. `Unterschrank.skp` in ein Modell einfügen und auswählen.
2. Ruby-Konsole: `load 'C:/Pfad/zu/einrichten.rb'`
3. Rechtsklick auf den Unterschrank → *Speichern unter…* → `Unterschrank.skp` ersetzen.

Danach steht die Hilfe oben im Fenster *Komponentenoptionen*, mit Link auf diese Seite. Teile, die das Skript nicht erkennt, nennt es in der Meldung; sie bleiben ohne Tag.

## Tests
`ruby test/test_einrichten.rb` – prüft Kurzhilfe, Tags, `JT_Schrank` und die Einlegeboden-Formeln (Sichtbarkeit und gleich hohe Fächer für 0–3 Böden) mit der Mock-API.
