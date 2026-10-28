# Arbeitsplatte

Werkzeug, das nach dem Stellen der Unterschränke die Arbeitsplatte darüber legt,
auch für L- und U-Küchen mit Eckverbindung und Verbindungsfräsung.
Plan: [docs/plaene/arbeitsplatte.md](../../docs/plaene/arbeitsplatte.md).

**Stand: Schritt 1 von 5.** Erkannt werden Schrankzeilen, Ecken und Begrenzungen;
die Platten selbst folgen in den nächsten Schritten.

## Benutzung

1. `arbeitsplatte.rbz` installieren (oder `Kuechenplaner_alle.rbz`).
2. Unterschränke markieren, oder nichts markieren: dann gelten alle Schränke im Modell
   (oberste Ebene, nicht in Gruppen).
3. **Erweiterungen › Küchenplaner › Arbeitsplatte erzeugen…** zeigt, was erkannt wurde:
   Zeilen mit Länge und Tiefe, die Enden (frei, Hochschrank, Ecke), Lücken, Ecken mit
   Eckschrank und Passleiste, die Küchenform (gerade, L, U) und Warnungen.

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

## Dateien

- `src/arbeitsplatte/erkennung.rb`: Zeilen und Ecken aus Grundriss-Rechtecken, ohne SketchUp
- `src/arbeitsplatte/modell.rb`: Schränke aus dem Modell lesen
- `src/arbeitsplatte/main.rb`: Menü und Meldung
- `test/test_arbeitsplatte.rb`: gerade, Lücke, Hochschrank, L (Blindeck, L-Eckschrank), U, Drehung

Nach Änderungen in `src/`: `./build_rbz.sh` im Hauptordner, dann `./run_tests.sh`.
