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
Alle Teile haben „Melamin weiss“ (Plattenmaterial in OCL). **Noch offen:** Anleimer-Zuweisung und eindeutige Tags je Teil fehlen in dieser Komponente noch (siehe Schritt 1 im Plan unter `sketchup-tcn-export-plugin/`).

## Hilfe in SketchUp
Weil es für diese Komponente keinen Generator gibt, wird die Kurzhilfe einmalig mit `hilfe_einbetten.rb` eingebettet:
1. `Unterschrank.skp` in ein Modell einfügen und auswählen.
2. Ruby-Konsole: `load 'C:/Pfad/zu/hilfe_einbetten.rb'`
3. Rechtsklick auf den Unterschrank → *Speichern unter…* → `Unterschrank.skp` ersetzen.

Danach steht die Hilfe oben im Fenster *Komponentenoptionen*, mit Link auf diese Seite.

## Tests
`ruby test/test_hilfe.rb` – prüft das Einbetten der Kurzhilfe mit der Mock-API.
