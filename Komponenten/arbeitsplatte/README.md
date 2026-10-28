# Arbeitsplatte

Werkzeug, das nach dem Stellen der Unterschränke die Arbeitsplatte darüber legt,
auch für L- und U-Küchen mit Eckverbindung und Verbindungsfräsung.
Plan: [docs/plaene/arbeitsplatte.md](../../docs/plaene/arbeitsplatte.md).

**Stand: Schritt 2 von 5.** Erkannt werden Schrankzeilen, Ecken und Begrenzungen,
und die Platten werden berechnet (Umriss, Stöße, Format). Gezeichnet werden sie ab Schritt 3.

## Benutzung

1. `arbeitsplatte.rbz` installieren (oder `Kuechenplaner_alle.rbz`).
2. Unterschränke markieren, oder nichts markieren: dann gelten alle Schränke im Modell
   (oberste Ebene, nicht in Gruppen).
3. **Erweiterungen › Küchenplaner › Arbeitsplatte erzeugen…** zeigt, was erkannt wurde:
   Zeilen mit Länge und Tiefe, die Enden (frei, Hochschrank, Ecke), Lücken, Ecken mit
   Eckschrank und Passleiste, die Küchenform (gerade, L, U), die Platten mit Maß und
   Format, die Stöße und Warnungen.

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
- `src/arbeitsplatte/main.rb`: Menü und Meldung
- `test/test_arbeitsplatte.rb`: Erkennung: gerade, Lücke, Hochschrank, L (Blindeck, L-Eckschrank), U, Drehung
- `test/test_layout.rb`: Layout: Überstände, Formate, Teilung, Stoßarten, Bogen, Flächen passen lückenlos

Nach Änderungen in `src/`: `./build_rbz.sh` im Hauptordner, dann `./run_tests.sh`.
