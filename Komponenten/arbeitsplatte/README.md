# Arbeitsplatte

Werkzeug, das nach dem Stellen der Unterschränke die Arbeitsplatte darüber legt,
auch für L- und U-Küchen mit Eckverbindung und Verbindungsfräsung.
Plan: [docs/plaene/arbeitsplatte.md](../../docs/plaene/arbeitsplatte.md).

**Stand: alle 5 Schritte gebaut, noch nicht in SketchUp und an der Maschine
erprobt.** Die Platten werden mit Eckverbindung und Ausschnitten für Spüle und
Kochfeld gezeichnet, OpenCutList-fähig (Material, Anleimer, Tags). *TCN exportieren…*
(Schrank-CNC-Plugin) schreibt je Stoßende eine TCN mit Stoßkontur, Hundeknochen
für die Verbinder und den Ausschnitten, siehe [TCN](#tcn).

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

## Ausschnitte

Mittig über dem Schrank, der sie vorgibt, als Loch in der Platte (Richtwerte, im Dialog
je Schrank änderbar oder abschaltbar; ein Kochfeld lässt sich über jedem Schrank ergänzen):

| Schrank | Ausschnitt | von der Vorderkante | Radius |
|---|---|---|---|
| Spülenschrank (USP) | Schrankbreite − 100 (höchstens 860) × 490 | 60 mm | 10 mm |
| Herdschrank (USK) 600 / 800 / 900 | 560 / 750 / 880 × 490, sonst Breite − 50 | 50 mm | 0 |

Warnungen: Ausschnitt näher als 150 mm an einem Stoß, näher als 50 mm an der Vorderkante,
breiter als der Schrank, ragt aus der Platte; Kochfeld näher als 300 mm am Hochschrank.
Längsstöße halten 150 mm Abstand zu Ausschnitten.

## TCN

Der Export steht in `sketchup-tcn-export-plugin/src/jt_schrank_cnc/arbeitsplatte.rb`
und liest Umriss, Kantenarten, Frontrichtung und Stöße aus `JT_Arbeitsplatte`.

- Je Stoßende eine Datei `APL<n>_Platte<k>_Stoss<nr>.tcn`, Platten ohne Stoß mit
  Ausschnitt `APL<n>_Platte<k>.tcn`. Abgelängt wird bauseits, die TCN fräst nur.
- Dekor unten, Stoßende am Anschlag links unten (x = 0). DL = Plattenlänge,
  DH = Tiefe, DS = Stärke. Arbeitsbereich 3200 × 1300 mm: was weiter weg liegt,
  fehlt in der TCN und steht in den Hinweisen.
- **Stoßkontur** mit dem Konturfräser (Annahme Werkzeug 2220, Ø 20) um den Radius in
  den Abfall versetzt, Stärke + 1 mm tief, 10 mm über die Plattenkanten hinaus.
  Gehrungsansatz mit Bogen, Gehrung und Längsstoß an beiden Platten; die
  durchlaufende Platte bekommt dazu ihr Ende an der Wand. Beim stumpfen Stoß wird
  die durchlaufende Platte nicht gefräst (die Vorderkante bleibt).
- **Hundeknochen** je Verbinder: Bohrung Ø 35, 20 tief, 65 mm vom Stoß, und ein
  Steg mit dem 12er Fräser (Annahme Werkzeug 2212) von der Stoßkante zur Bohrung.
  Verbinder 80 mm von Wand und Vorderkante, 2 bis 650 mm Stoßlänge, 3 bis 900,
  sonst 4, bei Gehrung immer 4. Keine Lamellos.
- **Ausschnitte** (Spüle, Kochfeld) als geschlossene Kontur in der TCN, in der sie
  am nächsten am Anschlag liegen. Ecken bis R 10 entstehen durch den Fräser, größere
  Radien werden mitgefräst.

Werkzeugnummern und -durchmesser stehen in `Arbeitsplatten::KONTUR` und `STEG`.

## Dateien

- `src/arbeitsplatte/erkennung.rb`: Zeilen und Ecken aus Grundriss-Rechtecken, ohne SketchUp
- `src/arbeitsplatte/ausschnitte.rb`: Spüle und Kochfeld, Prüfungen, ohne SketchUp
- `src/arbeitsplatte/layout.rb`: Platten, Stöße und Formate aus den Zeilen, ohne SketchUp
- `src/arbeitsplatte/modell.rb`: Schränke aus dem Modell lesen
- `src/arbeitsplatte/dialog.rb`: Einstellungen abfragen
- `src/arbeitsplatte/ausgabe.rb`: Platten zeichnen
- `src/arbeitsplatte/main.rb`: Menü, Erzeugen und Neuberechnen
- `test/test_arbeitsplatte.rb`: Erkennung: gerade, Lücke, Hochschrank, L (Blindeck, L-Eckschrank), U, Drehung
- `test/test_ausgabe.rb`: Zeichnen, OCL, Tags, Anleimer, Dialog, Neuberechnen, Schrank-Export übergeht die Platten
- `test/test_tcn.rb`: TCN der L-Küche (Kontur, Hundeknochen) und einer Platte mit Spüle, Teileliste
- `test/test_ausschnitte.rb`: Ausschnitte, Prüfungen, Längsstoß weicht aus, Dialog, Löcher
- `test/test_layout.rb`: Layout: Überstände, Formate, Teilung, Stoßarten, Bogen, Flächen passen lückenlos

Nach Änderungen in `src/`: `./build_rbz.sh` im Hauptordner, dann `./run_tests.sh`.
