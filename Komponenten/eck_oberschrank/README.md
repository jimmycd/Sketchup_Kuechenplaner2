# Eck-Oberschrank L-Form (Dynamic Component)

L-förmiger Oberschrank für die Ecke, mit Falttür. Gegenstück zur L-Form des [Eck-Unterschranks](../eckschrank/), aber mit dem Korpus des [Oberschranks](../oberschrank/) (Deckel, Rückwand in der Nut, Aufhängefach).

## Installieren und benutzen
1. SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `eck_oberschrank.rbz` wählen (oder `Kuechenplaner_alle.rbz` aus dem Hauptordner für alle Komponenten auf einmal).
2. *Erweiterungen → Küchenplaner → Oberschränke → Eck-Oberschrank L-Form…* (oder Symbolleiste *Schrank einfügen*) fragt Schenkel A, Schenkel B, Höhe und Tiefe ab und baut den Schrank. Danach hängt er am Andock-Werkzeug.
3. Alle Maße lassen sich danach im Fenster *Komponentenoptionen* ändern (siehe unten).

## Komponentenoptionen
| Option | Standard |
|---|---|
| Schenkel A (entlang der hinteren Wand, außen) | 650 mm |
| Schenkel B (entlang der linken Wand, außen) | 650 mm |
| Tiefe (Seite, mit 25 mm Aufhängefach, ohne Front) | 350 mm, mindestens 200 mm |
| Höhe | 700 mm |
| Anzahl Einlegeböden | 0–2; Standard 1 |

Feste Maße als Attribute (Fenster *Komponentenattribute*): `Materialstaerke_Korpus` 19 mm, `Materialstarke_Rueckwand` 8 mm, `Rueckwand_Versatz` 25 mm, `Nuttiefe` 9 mm, `Spaltbreite` 2 mm, `Rueckversatz_Einlegeboden` 10 mm, `Leiste_Laenge` 200 mm, `Leiste_Breite` 30 mm.

**Schenkel und Tiefe ändern:** Eine Dynamic Component ändert Maße, indem sie Teile skaliert; eine L-Platte würde dabei verzerrt. Deshalb baut die Erweiterung den Schrank neu auf, sobald sich Schenkel A, Schenkel B oder Tiefe ändern (ein Beobachter prüft nach jedem Vorgang, `EckOberschrank.l_pruefen`). Kürzel, Lage, Höhe, Einlegeböden, Frontmaterial und Griffe bleiben. Ist ein Schenkel innen vor der Ecke kürzer als 150 mm oder die Tiefe kleiner als 200 mm, kommt eine Meldung und die alten Maße bleiben. Höhe und Einlegeböden folgen direkt per Formel.

## Aufbau
* Draufsicht: Schenkel A an der hinteren Wand, Schenkel B an der linken Wand. Die Innenecke liegt an der Korpusvorderkante beider Schenkel. Der Korpus von A beginnt wie bei allen Schränken bei y = 19 mm, die Türen liegen davor.
* **Seiten** an den Schenkelenden (`SeiteR` am Ende von A, `SeiteL` am Ende von B), volle Höhe und Tiefe.
* **Boden**: eine L-Platte zwischen den Seiten über die volle Tiefe, mit Nut für beide Rückwände auf der Oberseite.
* **Deckel**: eine L-Platte, endet vor den Rückwänden und wird mit ihnen verschraubt (je Rückwand 3 Schrauben, 50 mm von den Enden und in der Mitte; die Bohrungen setzt der TCN-Export).
* **Rückwände** 8 mm, Rückseite 25 mm vor der Wand (Fach für die Aufhängung), in der 9 mm tiefen Nut von Seite und Boden, von oben eingeschoben, oben bündig. `Rueckwand1` hinter A läuft durch die Ecke bis zur Rückseite von B, `Rueckwand2` hinter B stößt an ihre Vorderseite.
* **Einlegeböden**: L-Platten, an beiden Vorderkanten 10 mm zurückgesetzt, hinten bis an die Rückwände, auf Bodenträgern in den Lochreihen der Seiten. Darunter je eine **Auflageleiste** (200 × 30 × 19 mm) an der Rückwand A, direkt neben Rückwand B: sie trägt die Ecke, die sonst frei hängen würde (angeleimt und durch die Rückwand verschraubt).
* **Falttür**: `TuerR` vor Schenkel A läuft durch die Ecke, `TuerL` vor Schenkel B endet 1 mm vor der Front von A. Beide verbindet ein Blum-Standardscharnier, die Tür an der Seite hängt an Topfbändern (Bohrungen folgen mit den Türen im TCN-Export). 1 mm Fuge oben und unten, 2 mm vor dem Korpus. Keine Öffnen-Animation.

Die Schrankaufhänger kommen wie beim Oberschrank später dazu.

## Material und Kanten
Gezeichnet ist immer das **Endmaß**. Platten haben „Melamin weiss“, sichtbare Kanten das Material „Anleimer Melamin weiss“ (2 mm, Stückliste und Zuschnitt ziehen ihn ab).

| Teil | Kanten mit Anleimer |
|---|---|
| Seiten | vorne, unten, oben (von unten und oben sichtbar) |
| Boden, Deckel, Einlegeböden (L-Platten) | Innenecke: der TCN-Export fräst sie 2 mm zurück; Stückliste und Zuschnitt rechnen mit dem umschließenden Rechteck |
| Auflageleisten | vorne und am freien Ende |
| Rückwände | keine |
| Türen | alle vier |

## Tags
Jedes Teil hat den Tag `<Kürzel>_<Teil>`: `OES1_SeiteL`, `OES1_SeiteR`, `OES1_Boden`, `OES1_Deckel`, `OES1_Rueckwand1`/`2`, `OES1_Einlegeboden1`/`2`, `OES1_Auflageleiste1`/`2`, `OES1_TuerL`, `OES1_TuerR`. Das Kürzel ist `OES1`, oder `OES2` usw., wenn es im Modell schon vergeben ist.

An jedem Teil steht das Wörterbuch `JT_Schrank` mit `schrank`, `typ` (Eckschrank), `kategorie` (Oberschrank), `bereich`, `teil` und `rolle`. Die Auflageleiste hat die neue Rolle `Leiste` (in der gemeinsamen ROLLEN-Tabelle aller Komponenten).

## TCN-Export (Plugin Schrank-CNC)
* Dübel Boden und Deckel an die Seiten, Ø3-Schraubenreihe am Boden, Lochreihen für Einlegeböden, keine Sockelfüße.
* Rückwandnut in beiden Seiten und im L-Boden (zwei Nuten), Schrauben Deckel–Rückwand an beiden Rückwänden.
* Innenecke von Boden, Deckel und Einlegeböden als Kontur mit dem Nutfräser durch die Platte; beim Boden von oben (Fläche 1 mit den Nuten).
* Auflageleisten und Türen nur formatieren; Topfbänder folgen mit den Türen.

## Hilfe in SketchUp
Eine Kurzfassung dieser Doku steht oben im Fenster *Komponentenoptionen* (Summary und Description) und als Beschreibung der Komponente, mit Link auf diese Seite. Der Text steht als `HILFE` in `src/eck_oberschrank/main.rb`.

## Tests
`ruby test/test_eck_oberschrank.rb` – prüft ohne SketchUp (Mock-API und DC-Formel-Auswerter) Geometrie (Seiten, L-Boden, Deckel vor den Rückwänden, Rückwände in der Nut, Falttür, Einlegeböden mit Leisten, keine Kollisionen), Höhe und Einlegeböden umschalten, den Neuaufbau nach Schenkel- oder Tiefenänderung (gleich wie frisch gebaut, Frontmaterial und Griff bleiben, ungültige Maße abgelehnt), Material, Anleimer, Tags, `JT_Schrank` und die Kurzhilfe. Den TCN-Export prüft `sketchup-tcn-export-plugin/test/test_export.rb`. In echtem SketchUp ist die Komponente noch nicht getestet.
