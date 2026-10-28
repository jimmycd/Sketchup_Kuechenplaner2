# Arbeitsplatte

Werkzeug, das nach dem Stellen der Unterschränke die Arbeitsplatte darüber legt,
auch für L- und U-Küchen mit Eckverbindung und Verbindungsfräsung.
Plan: [docs/plaene/arbeitsplatte.md](../../docs/plaene/arbeitsplatte.md).

**Stand: Schritt 3 von 5.** Die Platten werden mit Eckverbindung gezeichnet,
OpenCutList-fähig (Material, Anleimer, Tags). Noch offen: Ausschnitte für Spüle und
Kochfeld (Schritt 4), Verbindungsfräsung und TCN-Export (Schritt 5); bis dahin übergeht
der TCN-Export die Arbeitsplatten.

## Benutzung

1. `arbeitsplatte.rbz` installieren (oder `Kuechenplaner_alle.rbz`).
2. Unterschränke markieren, oder nichts markieren: dann gelten alle Schränke im Modell
   (oberste Ebene, nicht in Gruppen).
3. **Erweiterungen › Küchenplaner › Arbeitsplatte erzeugen…**: im Dialog Plattenart,
   Stärke, Überstände, Wandabstand, Fuge zum Hochschrank, Format, Gehrungstiefe und Radius
   einstellen, je Ecke Stoßart und durchlaufende Platte. Danach liegt die Komponente
   `APL1` (bzw. `APL2` …) über den Schränken, und eine Meldung zeigt Zeilen, Ecken,
   Platten, Stöße und Warnungen.
4. Schränke verschoben? **Arbeitsplatte neu berechnen** baut `APL1` (markiert, sonst alle
   Arbeitsplatten) mit denselben Einstellungen über denselben Schränken neu auf.
   Handänderungen an den Platten gehen dabei verloren.

## Was gezeichnet wird

- Komponente `Arbeitsplatte APL1` mit `JT_Schrank` (schrank APL1, typ und kategorie
  Arbeitsplatte), darin je Platte eine Komponente mit Tag `APL1_Platte1`, `APL1_Platte2` …
  und `JT_Schrank` (teil Platte1 …, rolle Arbeitsplatte). Gezeichnet im Endmaß.
- Material: Schichtstoff „Arbeitsplatte Schichtstoff“ (OCL Plattenwerkstoff, 38 mm) oder
  „Arbeitsplatte Massivholz“ (OCL Massivholz, 40 mm).
- Anleimer (nur bei Schichtstoff): Vorderkante „Anleimer Arbeitsplatte ab Werk“ (wird in
  OCL nicht abgezogen, die Platte kommt bekantet), freie Enden „Anleimer Arbeitsplatte“
  (2 mm, wird in OCL abgezogen). Wand-, Stoß- und Hochschrankkanten ohne.
- Im Wörterbuch `JT_Arbeitsplatte`: an der Definition Einstellungen, Schränke und Stöße
  (mit Pfad, für den späteren TCN-Export), an jeder Platte Umriss, Kantenarten und Format.

## Wie erkannt wird

- Gelesen werden Instanzen mit dem Wörterbuch `JT_Schrank` an der Definition.
  `kategorie = Unterschrank` kommt unter die Platte, `Hochschrank` begrenzt eine Zeile.
- Die Front liegt bei allen Schränken lokal auf `ymin`. Schränke müssen im rechten
  Winkel stehen (0°, 90°, 180°, 270°); schräge werden mit Warnung übergangen.
- Eine **Zeile** sind Unterschränke mit gleicher Blickrichtung, gleicher Oberkante (±1 mm)
  und gleicher Frontlinie (±5 mm). Lücken bis 650 mm (Spüler, Unterbaukühlschrank) werden
  überbrückt. Die Wand liegt hinter dem tiefsten Schrank.
- Eine **Ecke** verbindet die Enden zweier Zeilen im rechten Winkel, die bis auf 100 mm
  an die andere Zeile heranreichen. Die Zeile, deren Schränke bis an die Wand der anderen
  laufen, steht in der Ecke; der Abstand der anderen zu deren Front ist die Passleiste.
- Der **L-Eckschrank** zählt als zwei Schenkel (A an der hinteren, B an der linken Wand).

## Wie die Platten zugeschnitten werden

| Einstellung | Standard |
|---|---|
| Plattenart | Schichtstoff mit Anleimer ab Werk (38 mm) oder Massivholz (40 mm) |
| Überstand vorn / seitlich an freien Enden | 20 / 0 mm |
| Wandabstand / Fuge zum Hochschrank | 5 / 2 mm |
| Stoß in der Ecke | Gehrungsansatz (Gehrungstiefe 30 mm, Bogen R 30 mm), Option stumpf oder Gehrung 45°, je Ecke |
| Durchlaufende Platte | die längere Zeile, je Ecke umschaltbar |
| Format | schmalstes aus 4100 × 600 / 650 / 900 / 1200, das die Tiefe abdeckt, oder fest |
| Teilen | länger als Format − 2 × 10 mm Besäumen: Längsstoß über einer Schrankseite |

- Gehrungsansatz: die durchlaufende Platte bekommt die weibliche Fräsung (Vorderkante im
  Stoßbereich 30 mm zurück), die anstoßende ragt 30 mm hinein. Der Schnitt läuft vom
  inneren Eckpunkt der Vorderkanten 45° nach innen und im Bogen R in die Gerade zur Wand.
- Jede Plattenkante hat eine Art: vorne, Wand, frei, Hochschrank, Stoß (für Anleimer und CNC).

## Dateien

- `src/arbeitsplatte/erkennung.rb`: Zeilen und Ecken aus Grundriss-Rechtecken, ohne SketchUp
- `src/arbeitsplatte/layout.rb`: Platten, Stöße und Formate aus den Zeilen, ohne SketchUp
- `src/arbeitsplatte/modell.rb`: Schränke aus dem Modell lesen
- `src/arbeitsplatte/dialog.rb`: Einstellungen abfragen
- `src/arbeitsplatte/ausgabe.rb`: Platten zeichnen
- `src/arbeitsplatte/main.rb`: Menü, Erzeugen und Neuberechnen
- `test/test_arbeitsplatte.rb`: Erkennung: gerade, Lücke, Hochschrank, L (Blindeck, L-Eckschrank), U, Drehung
- `test/test_ausgabe.rb`: Zeichnen, OCL, Tags, Anleimer, Dialog, Neuberechnen, TCN-Export übergeht die Platten
- `test/test_layout.rb`: Layout: Überstände, Formate, Teilung, Stoßarten, Bogen, Flächen passen lückenlos

Nach Änderungen in `src/`: `./build_rbz.sh` im Hauptordner, dann `./run_tests.sh`.
