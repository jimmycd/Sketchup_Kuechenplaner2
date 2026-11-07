# Unterschrank mit Doppeltür (Dynamic Component)

Unterschrank mit zwei Türen nebeneinander: die linke Tür ist links angeschlagen, die rechte rechts. Korpus wie beim [Unterschrank mit Tür](../unterschrank_tuer/), aber als Generator gebaut, damit alle Maße per Formel folgen.

## Installieren und benutzen
1. SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `unterschrank_doppeltuer.rbz` wählen (oder `Kuechenplaner_alle.rbz` aus dem Hauptordner für alle Komponenten auf einmal).
2. *Erweiterungen → Küchenplaner → Unterschränke → Unterschrank mit Doppeltür…* (oder Symbolleiste) fragt Breite, Höhe und Tiefe ab und baut den Schrank im aktuellen Modell; das Andock-Werkzeug setzt ihn an Nachbarn oder Wand. Maße und Optionen danach in den *Komponentenoptionen* ändern.

Wer eine fertige `.skp` für die Komponenten-Bibliothek möchte: Rechtsklick auf den Schrank → *Speichern unter…*.

## Komponentenoptionen
| Option | Standard |
|---|---|
| Breite / Höhe / Tiefe (Korpus ohne Front und Rückwand) | 800 / 700 / 520 mm |
| Anzahl Einlegeböden | 0–3 (Standard 1) |

Feste Maße als Attribute (Fenster *Komponentenattribute*): `Materialstaerke_Korpus` 19 mm, `Materialstarke_Rueckwand` 8 mm, `BreiteStreben` 100 mm, `Spaltbreite` 2 mm, `Rueckversatz_Einlegeboden` 10 mm.

## Aufbau
- Seiten über die volle Höhe und Tiefe, Boden zwischen den Seiten, oben Strebe vorn und Strebe hinten (100 mm breit).
- Rückwand 8 mm über die volle Breite und Höhe hinter dem Korpus (wie Unterschrank mit Tür), die Rückseite liegt also bei Tiefe + 8 mm in einer Flucht mit den anderen Unterschränken.
- Einlegeböden teilen den Raum zwischen Boden und Streben in gleich hohe lichte Fächer, vorne 10 mm zurückgesetzt; nicht benötigte Böden sind ausgeblendet.
- Zwei Türen über die volle Höhe, je Breite/2 − 2 mm, außen 1 mm und in der Mitte 2 mm Fuge. Mit *Interagieren* öffnet die linke Tür nach links, die rechte nach rechts.
- Topfbänder (Blum) bohrt der TCN-Export an beiden Türen, die Montageplatten in die Seiten; Anzahl nach Türhöhe wie bei allen Türen.

## Material und Anleimer
Alle Platten „Melamin weiss“ (Plattenwerkstoff). Anleimer „Anleimer Melamin weiss“ (2 mm, wird erst in Stückliste/Zuschnitt abgezogen):

| Teil | Anleimer |
|---|---|
| Seiten, Boden, Einlegeböden | vorne |
| Strebe vorn | nur vorne |
| Strebe hinten, Rückwand | keine |
| Türen | rundum |

## Tags
Jedes Teil bekommt den Tag `<Kürzel>_<Teil>`: `USD1_SeiteL`, `USD1_SeiteR`, `USD1_Boden`, `USD1_StrebeVorn`, `USD1_StrebeHinten`, `USD1_Rueckwand`, `USD1_TuerL`, `USD1_TuerR`, `USD1_Einlegeboden1` bis `3`. Der nächste Schrank im Modell bekommt `USD2` usw. Dazu steht an jedem Teil das Wörterbuch `JT_Schrank` (`schrank`, `typ` = `Unterschrank_Doppeltuer`, `kategorie` = `Unterschrank`, `teil`, `rolle`), daran erkennen TCN-Export, Stückliste, Etiketten und Frontfarbe die Teile.

## Grifflose Front
Schrank-CNC setzt bei der Öffnung *Griffkante 45°* (*Einstellungen › Öffnung* oder je Schrank, Plan „Grifflose Fronten“) das Attribut `Griff_Front` (Standard 25 mm) und zeichnet den Schrank neu: die Türen sind oben so viel kürzer; die Fase oben innen fräst der TCN-Export. Ohne Griffkante ist es 0. Die durchlaufende Griffmulde folgt.

## Tests
`ruby test/test_unterschrank_doppeltuer.rb` – Geometrie (keine Kollisionen, alles innerhalb des Schranks), gleich hohe Fächer für 0–3 Böden, Türen und Drehpunkte, Anleimer, Tags/`JT_Schrank`, Umkonfigurieren und nachträgliche Tiefenänderung mit der Mock-API. Der TCN-Export wird in `sketchup-tcn-export-plugin/test/test_export.rb` geprüft (Topfbänder an beiden Türen).
