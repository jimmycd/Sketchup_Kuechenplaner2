# Unterschrank mit Tür (Dynamic Component)

`src/unterschrank_tuer/Unterschrank.skp` (SketchUp 2022) ist die von Hand gebaute Ausgangskomponente, an der sich die anderen Schränke orientieren.

## Installieren und benutzen
1. SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `unterschrank_tuer.rbz` wählen (oder `Kuechenplaner_alle.rbz` aus dem Hauptordner für alle Komponenten auf einmal).
2. *Erweiterungen → Küchenplaner → Unterschrank mit Tür…* fügt die `Unterschrank.skp` ins Modell ein und richtet sie gleich ein (Kurzhilfe, Tags, Einlegeboden-Formeln, siehe unten). Jeder weitere Unterschrank bekommt eine eigene Definition und ein eigenes Kürzel.

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
Alle Teile haben „Melamin weiss“ (Plattenmaterial in OCL). Eindeutige Tags je Teil setzt die Erweiterung beim Einfügen.

Anleimer (Material „Anleimer weiss“, in OCL Kante 2 mm, wird nur dort abgezogen) wie bei den anderen Unterschränken:

| Teil | Anleimer |
|---|---|
| Boden, Einlegeböden | vorne |
| Strebe vorn | nur vorne |
| Strebe hinten | keine |
| Seiten, Tür, Rückwand | unverändert aus der `Unterschrank.skp` |

Die Erweiterung setzt sie beim Einfügen bzw. mit `UnterschrankTuer.einrichten` (in der von Hand gebauten `.skp` fehlte die Kante am Boden, die Streben hatten falsche Kanten). Teilen sich beide Streben eine Definition, bekommt eine davon eine eigene.

## Tags
Jedes Teil bekommt den Tag `<Kürzel>_<Teil>`: `UST1_SeiteL`, `UST1_SeiteR`, `UST1_Boden`, `UST1_StrebeVorn`, `UST1_StrebeHinten`, `UST1_Rueckwand`, `UST1_Tuer`, `UST1_Einlegeboden1` bis `3`. Das Kürzel ist `UST1`, oder `UST2` usw., wenn es im Modell schon vergeben ist; ein zweiter Lauf behält es bei. Zusätzlich steht an jedem Teil das Attribut-Wörterbuch `JT_Schrank` mit `schrank` (Kürzel), `typ`, `kategorie` (Unterschrank, Oberschrank oder Hochschrank), `bereich`, `teil` und `rolle` (z. B. Seite, Boden, Front). Daran erkennt das TCN-Export-Plugin die Teile; die Frontfarbe-Funktion wählt über `kategorie` die Schränke aus.

## Einlegeböden
Die sichtbaren Einlegeböden teilen den Innenraum zwischen Boden und Streben in gleich hohe Fächer; nicht benötigte Böden sind ausgeblendet und liegen unten. Die Formeln dafür setzt die Erweiterung beim Einfügen (in der von Hand gebauten `Unterschrank.skp` fehlten sie bzw. wurden nicht ausgewertet, deshalb hatte *Anzahl Einlegeböden* keine Wirkung).

## Einrichten (Hilfe, Tags, Einlegeböden, Anleimer)
Weil es für diese Komponente keinen Generator gibt, setzt `src/unterschrank_tuer/main.rb` Kurzhilfe, Tags und die Formeln der Einlegeböden beim Einfügen über das Menü. Ein Unterschrank, der schon vorher im Modell war, lässt sich nachträglich einrichten: auswählen und in der Ruby-Konsole `UnterschrankTuer.einrichten` eingeben.

Danach steht die Hilfe oben im Fenster *Komponentenoptionen*, mit Link auf diese Seite. Teile, die nicht erkannt werden, bleiben ohne Tag (sie stehen in der Ruby-Konsole bzw. in der Meldung).

## Tests
`ruby test/test_einrichten.rb` – prüft Kurzhilfe, Tags, Anleimer, `JT_Schrank` und die Einlegeboden-Formeln (Sichtbarkeit und gleich hohe Fächer für 0–3 Böden) mit der Mock-API, außerdem das Einfügen über das Menü (eigene Definition und eigenes Kürzel je Schrank).
