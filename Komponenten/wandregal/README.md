# Wandregal (Dynamic Component)

Offenes Regal, das **frei an der Wand hängt**: es steht nicht in einer Zeile mit den Oberschränken und wird nicht an andere Schränke angedockt (Jürgen, 2026-11-07). Kürzel `WR`, Kategorie `Wandregal`.

## Installieren und benutzen
1. SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `wandregal.rbz` wählen (oder `Kuechenplaner_alle.rbz` aus dem Hauptordner). Für das Platzieren an der Wand braucht es das Plugin Schrank-CNC ab 0.19.0.
2. *Erweiterungen → Küchenplaner → Oberschränke → Wandregal…* (oder Symbolleiste *Schrank einfügen*) fragt Breite, Höhe, Tiefe, Unterkante über der Arbeitsplatte, Spalten, Reihen je Spalte und Rückwand ab.
3. Das Regal hängt dann an der Maus: Rücken direkt an der Wand, nur entlang der Wand verschiebbar, **Tab** = andere Wand, **Pfeil hoch/runter** = 10 mm höher/tiefer, Klick setzt ab. Auch wenn ein Oberschrank markiert ist, reiht es sich nicht an; in Wände oder Schränke hinein lässt es sich nicht setzen. Ohne Raum folgt es der Maus auf seiner Höhe.
4. Alles Weitere in den *Komponentenoptionen*. Nach *Übernehmen* baut die Erweiterung das Regal neu auf (eine andere Aufteilung lässt sich nicht per Formel umbauen). Ungültige Werte werden mit einer Meldung zurückgesetzt.

## Komponentenoptionen
| Option | Standard | Bereich |
|---|---|---|
| Breite | 600 mm | ab 100 mm |
| Höhe | 350 mm | ab 100 mm |
| Tiefe (Seiten) | 250 mm | 100–800 mm |
| Unterkante über Arbeitsplatte | 500 mm | Änderung hebt bzw. senkt das Regal um die Differenz |
| Materialstärke | 19 mm | 16–30 mm |
| Rückwand | ja | ja, nein |
| Farbe | Korpusfarbe | Korpusfarbe, Frontfarbe |
| Spalten (mit Mittelwand) | 1 | 1–4 |
| Breiten | gleich | lichte Breiten in mm von links, z. B. `400;200` |
| Spalte n: Reihen | 2 | 1–5 |
| Spalte n: Höhen | gleich | lichte Fachhöhen in mm von unten, z. B. `150;250` |

**Aufteilung:** `gleich` (oder leer) teilt gleichmäßig. Mit Maßen bekommen die ersten Fächer diese Maße, die übrigen teilen sich den Rest; gibt man so viele Maße an wie Fächer (oder mehr), ergibt sich das letzte aus dem Rest. Komma oder Punkt als Dezimalzeichen. Jedes Fach muss mindestens 50 mm licht haben. Die Felder *Reihen* und *Höhen* gibt es nur für die vorhandenen Spalten; mehr Spalten → nach *Übernehmen* erscheinen die neuen Felder.

Feste Maße (*Komponentenattribute*): `Materialstarke_Rueckwand` 8 mm, `Rueckwand_Versatz` 25 mm (Rückseite Rückwand vor der Hinterkante der Seiten, Platz für die Aufhängung), `Nuttiefe` 9 mm.

## Aufbau
* **Seiten** über die volle Höhe und Tiefe; **Boden** und **Deckel** zwischen den Seiten über die volle Tiefe.
* **Mittelwände** zwischen den Spalten, vom Boden bis zum Deckel. Mit Rückwand enden sie vor ihr, ohne Rückwand reichen sie über die volle Tiefe.
* **Fachböden** je Spalte zwischen Seite und Mittelwand bzw. zwischen zwei Mittelwänden, immer **fest** (gedübelt), Tiefe wie die Mittelwände. Jede Spalte hat ihre eigenen Höhen.
* **Rückwand** (ja): 8 mm in einer 9-mm-Nut in Seiten, Boden und Deckel, 25 mm vor der Hinterkante.
* **Aufhängung:** noch nicht drin (Jürgen sucht den Regalträger aus). Bohrbild und Beschlagliste kommen, wenn das Fabrikat feststeht.

## Material, Anleimer, Stückliste
Gezeichnet ist immer das **Endmaß**. Platten haben „Melamin weiss“, sichtbare Kanten „Anleimer Melamin weiss“ (2 mm).

| Teil | Kanten mit Anleimer |
|---|---|
| Seiten | vorne, oben, unten (das Regal hängt, Ober- und Unterkante sind zu sehen); ohne Rückwand auch hinten |
| Boden, Deckel, Mittelwände, Fachböden | vorne; ohne Rückwand auch hinten |
| Rückwand | keine (steckt ringsum in der Nut) |

**Farbe Frontfarbe:** alle Teile tragen `JT_Schrank/frontfarbe` und bekommen mit *Frontfarbe und Griffe ändern* das Frontmaterial.

## Tags
Jedes Teil hat einen eigenen Tag `<Kürzel>_<Teil>`: `WR1_SeiteL`, `WR1_SeiteR`, `WR1_Boden`, `WR1_Deckel`, `WR1_Rueckwand`, `WR1_Mittelwand1` … (von links), `WR1_Mittelboden1` … (Spalte für Spalte von links, in der Spalte von unten; die Spalte steht zusätzlich als `JT_Schrank/spalte` am Fachboden). Rollen: Mittelwand = `Seite`, Fachboden (`Mittelboden`) = `Zwischenboden` (gemeinsame Rollen-Tabelle, um `Mittelwand` ergänzt).

## TCN-Export (Plugin Schrank-CNC)
* Boden, Deckel und Fachböden: Dübel in die Seiten bzw. Mittelwände wie bei den anderen Schränken.
* Mittelwand: mit Boden und Deckel gedübelt (Dübel Ø8 in die Kante der Mittelwand, Gegenreihe in Boden bzw. Deckel), Fachböden wie an einer Seite.
* **Fachböden auf beiden Seiten einer Mittelwand:** die Maschine bohrt nur von oben, deshalb gibt es für die Mittelwand ein zweites Programm `<Nr>_WR1_Mittelwand1_Rueckseite.tcn` fürs gewendete Werkstück (nur die Bohrungen der anderen Seite, ohne Formatieren). Beide Dateien stehen in derselben Stücklistenzeile.
* Keine Lochreihen (alle Böden fest), keine Sockelfüße, Rückwandnut mit 2200 wie beim Oberschrank.
* Rendern (Blender): unter dem Regal hängt eine LED-Leiste wie unter den Oberschränken.

## Hilfe in SketchUp
Eine Kurzfassung (ein Satz, `HILFE_KURZ` in `src/wandregal/main.rb`) steht oben im Fenster *Komponentenoptionen* und als Beschreibung der Komponente.

## Tests
`ruby test/test_wandregal.rb` prüft ohne SketchUp Teile, Lage, Spalten mit Mittelwänden, Reihen und Höhen je Spalte, Breiten, Rückwand ja/nein, Anleimer, Tags, `JT_Schrank`, ungültige Eingaben und den Neuaufbau (Spalten dazu/weg, Höhe über Arbeitsplatte). `sketchup-tcn-export-plugin/test/test_export.rb` prüft Dübel, Rückseiten-Programm, Lochreihen und Stückliste, `test_andocken.rb` das freie Platzieren.

Noch nicht in echtem SketchUp erprobt.
