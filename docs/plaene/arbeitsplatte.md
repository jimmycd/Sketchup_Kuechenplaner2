> Quelle: [Plan: Arbeitsplatte über geplanten Unterschränken](https://claude.ai/artifact/AmbiukmZYXGJrdpz25sYmG) (Plan-Dokument aus dem Projekt-Thread, Stand 28.10.2026)  
> Status: **Plan**, wartet auf Jürgens Antworten und Freigabe

# Plan: Arbeitsplatte über geplanten Unterschränken

Ein neues Werkzeug im Menü **Küchenplaner** legt die Arbeitsplatte über die schon platzierten Unterschränke. Es findet die Schrankzeilen, erkennt L- und U-Ecken, schneidet die Platten mit der passenden Eckverbindung zu und setzt die Verbindungsfräsung (Hundeknochen für Zugbolzen, Lamellos). Spüle und Kochfeld bekommen ihren Ausschnitt dort, wo die Schränke es vorgeben. Alles ist OpenCutList-tauglich und geht über das Schrank-CNC-Plugin als TCN an die Maschine.

## Fragen an Jürgen (mit Vorschlag)

1. **Plattenaufbau und Vorderkante?** Vorschlag: 38 mm Spanplatte mit Schichtstoff, Vorderkante wählbar: Postforming oder gerade mit 2-mm-ABS-Anleimer.
2. **Material und Rohformat?** Vorschlag: „Arbeitsplatte Dekor 38“, Rohformat 4100 × 900 mm. Korpusse sind 800 mm tief, mit Front und Überstand wird die Platte etwa 840 mm tief.
3. **Eckverbindung als Standard?** Vorschlag: Stoß mit Gehrungsansatz bei Postforming, stumpfer Stoß bei gerader Kante. Die längere Zeile läuft durch, je Ecke umschaltbar. Gehrung 45° als dritte Wahl.
4. **Verbinder, Lamellos per CNC?** Vorschlag: Zugbolzen 150 mm (M8), Hundeknochen mit Ø35 (Topfbandbohrer) und 12-mm-Steg, 3 Stück bei 840 mm Tiefe, 4 bei Gehrung. Lamellos Gr. 20 nur mit Horizontalaggregat, sonst Handfräse.
5. **CNC-Grenzen?** Bitte nennen: maximale Länge × Breite und Dicke. Vorschlag: Dekor unten aufspannen (Taschen und Ausschnitte in einer Aufspannung, Lamellonut von der Dekorseite gemessen). Platte länger als Tisch: nur das Stoßende bearbeiten (eigene TCN je Plattenende).
6. **Überstände und Wand?** Vorschlag: vorn 20 mm vor der Front, seitlich an freien Enden 0 mm, 5 mm Wandluft (Wandabschlussleiste), 2 mm Fuge an Hochschränken.
7. **Passt der Ablauf?** Nach Freigabe Bau in den Schritten unten.

## Ablauf in SketchUp

1. Schränke stellen wie bisher.
2. Unterschränke markieren (oder nichts: dann alle Unterschränke im Modell) und **Küchenplaner › Arbeitsplatte erzeugen** wählen.
3. Dialog mit erkannten Zeilen und Ecken: Stärke, Material, Überstände, Wandabstand, je Ecke Verbindungsart und durchlaufende Platte, Ausschnitte.
4. Platten werden als Gruppe `APL1` angelegt, mit Ausschnitten, Eckfräsung und Taschen; Warnungen im Dialog und im Ruby-Log.
5. **Arbeitsplatte neu berechnen** baut `APL1` mit denselben Einstellungen neu auf (Handänderungen gehen verloren, Hinweis vorher).
6. OCL listet die Platten, das Schrank-CNC-Plugin schreibt die TCN je Platte.

## Schrankzeilen und Ecken erkennen

Gelesen werden nur Instanzen mit `JT_Schrank`; Vorderkante lokal auf `ymin`. Daraus: Rechteck im Grundriss, Blickrichtung, Oberkante.

- Unter der Platte: `kategorie = Unterschrank` (UST, USS, USG, USK, USP, USH, UES).
- Hochschränke (HS, HG, AP) beenden eine Zeile, Platte endet mit Fuge ohne Überstand.
- Zeile: gleiche Blickrichtung, gleiche Oberkante (±1 mm), gleiche Frontlinie, nebeneinander. Lücken bis 650 mm werden überbrückt (einstellbar).
- Ecke: zwei Zeilen im rechten Winkel, deren Enden sich berühren. UES gehört zu der Zeile, an deren Rückwand er steht; beim L-Eckschrank liegt die Ecke über ihm. Zwei Ecken an einer Mittelzeile = U.
- Hinter jeder Zeile wird eine Wand angenommen. Insel/Theke später.
- Erkennung ist reines Ruby ohne SketchUp-Aufrufe und damit testbar.

## Platten zuschneiden

- Tiefe: Wand (minus Wandabstand) bis Frontlinie (Vorderkante Fronten) plus Überstand vorn.
- Länge: Zeilenanfang bis -ende, an freien Enden plus seitlichem Überstand, an Hochschrank/Wand minus Fuge.
- Unterkante Platte = Oberkante Schrank; unterschiedliche Oberkanten ergeben eine Warnung.
- Ecke: standardmäßig läuft die längere Zeile bis zur Wand durch, die andere stößt an. U mit Mittelplatte von Wand zu Wand: Hinweis auf beidseitige Wandluft.
- Überlänge (Rohformat minus Besäumen, Annahme 4100 − 2 × 10 mm): gerader Stoß über einer Schrankseite, mindestens 150 mm neben jedem Ausschnitt, gleiche Fräsung wie Eckstoß.

## Eckverbindung und Verbindungsfräsung

- **Stumpfer Stoß** (gerade Kante): anstoßende Platte endet an der Vorderkante der durchlaufenden.
- **Stoß mit Gehrungsansatz** (Postforming): durchlaufende Platte bekommt die weibliche Fräsung (Vorderkante auf Profiltiefe zurückgesetzt), anstoßende die männliche mit kurzem 45°-Schnitt über das Profil.
- **Gehrung 45°**: für jede Kante, Stoß sichtbar, längere Fuge.

| Bearbeitung | Werte | Wo |
|---|---|---|
| Stoßkante | gerade oder 45°, Profiltiefe als Parameter (Annahme 30 mm) | Kontur |
| Zugbolzen-Tasche (Hundeknochen) | 2 × Ø35, 20 tief, Mitte 65 vom Stoß; Steg 12 breit, 20 tief (Annahme) | Unterseite, quer zum Stoß |
| Anzahl Zugbolzen | bis 650: 2, bis 900: 3, Gehrung: 4; erster/letzter 80 von den Kanten | gleich verteilt |
| Lamello Gr. 20 | Nut 4 mm, Mitte 15 unter Dekor, 3–5 Stück zwischen den Bolzen | Stirnseite, optional |
| Fuge | keine, Platten stoßen auf Endmaß | – |

Die Fräsung liegt als Daten am Teil (`JT_Arbeitsplatte`: Liste der Stöße mit Art, Lage, Taschen, Lamellos), gezeichnet wird nur die Kontur.

## Ausschnitte für Spüle und Kochfeld

Mittig über dem vorgebenden Schrank, als echtes Loch in der Platte, im Dialog änderbar.

| Schrank | Ausschnitt (Richtwert) | Lage |
|---|---|---|
| Spülenschrank USP | Breite − 100 × 490, R10 | 60 mm hinter Vorderkante (Annahme) |
| Herdschrank USK | 600: 560 × 490, 800: 750 × 490, 900: 880 × 490 | 50 mm hinter Vorderkante |
| Normaler Unterschrank | keiner, im Dialog zuschaltbar | – |

Unterbauspüle und flächenbündiges Kochfeld später.

## OpenCutList, Tags und Kanten

- Material mit `ladb_opencutlist` Typ 2, Dicke 38 mm, Standardformat 4100 × 900.
- Anleimer (Typ 4, 2 mm, abgezogen) an gerader Vorderkante und freien Enden; keiner an Wand- und Stoßkanten; bei Postforming keiner vorn.
- Kürzel `APL` (AP ist der Apothekerschrank): `APL1_Platte1` …, `JT_Schrank` mit `kategorie`/`typ = Arbeitsplatte`, neue Rolle `Arbeitsplatte` in der ROLLEN-Tabelle (in allen Komponenten gleich).
- Zugbolzen und Lamellos als OCL-Beschlag; Wandabschlussleiste optional.
- „Frontfarbe ändern“ lässt die Arbeitsplatte in Ruhe.

## TCN-Export

Neue Regel für die Rolle Arbeitsplatte in `regeln.rb` des Schrank-CNC-Plugins, Lagen im Fräsmaß.

- Kontur mit `W#89`/`W#2201` (wie Nut/Ausschnitt in `tcn.rb`), inkl. Gehrung und Gehrungsansatz; `squad.tmcr` nur für gerade Kanten.
- Ausschnitte über die vorhandene Methode `ausschnitt`.
- Hundeknochen: 2 × `W#81` Ø35 plus Tasche `rect.tmcr` (`W#1022`).
- Lamellos auf `SIDE#4`/`SIDE#6` nur mit Horizontalaggregat; auf der Gehrung nur Zugbolzen.
- Platte länger als Tisch: je Stoßende eine TCN mit Nullpunkt am Stoß (`APL1_Platte1_StossA.tcn`).
- Wunsch: eine echte TCN einer schon gefrästen Arbeitsplatte als Testvorlage.

## Prüfungen und Warnungen

- Platte länger als Rohformat oder CNC-Tisch.
- Ausschnitt < 150 mm am Stoß, < 50 mm an der Vorderkante, oder über einer Schrankseite.
- Kochfeld < 300 mm neben Hochschrank.
- Unterschiedliche Oberkante/Frontlinie, überlappende Schränke.
- Eckschrank ohne passende Ecke, Ecke ohne Eckschrank (Hinweis).

## Bau in Schritten

`Komponenten/arbeitsplatte/` nach dem Erweiterungs-Schema (`src/arbeitsplatte.rb`, `src/arbeitsplatte/main.rb`, `.rbz`), Menü über `Kuechenplaner.menu`. Ruby 2.7, Tests in `./run_tests.sh`, je Schritt ein PR.

| PR | Inhalt | Test |
|---|---|---|
| 1 | Erkennung Zeilen, Ecken, Begrenzungen | gerade, L, U, Lücke, Hochschrank, UES |
| 2 | Plattenlayout, Stoßarten, Teilung | Umrisse und Maße |
| 3 | SketchUp-Ausgabe, Material, Anleimer, Tags, Dialog, Neu berechnen | SketchUp-Mock, OCL-Regeln |
| 4 | Ausschnitte, Prüfungen | Lage, Abstände, Warnungen |
| 5 | Verbindungsfräsung als Daten, TCN-Regel | TCN gegen Beispieldatei |

Später: Kochinsel/Theke, schräge Ecken (135°), runde Enden, Nischenrückwand, Unterbauspüle mit Falz.
