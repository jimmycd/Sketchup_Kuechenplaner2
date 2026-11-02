# Abschlussregal (Dynamic Component)

Offenes Regal ohne Front am Ende einer Schrankzeile, **gerade**, **schräg** oder **rund**, als Unter-, Ober- oder Hochschrank.

## Installieren und benutzen
1. SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `regal_abschluss.rbz` wählen (oder `Kuechenplaner_alle.rbz` aus dem Hauptordner).
2. *Erweiterungen → Küchenplaner → Unterschränke / Oberschränke / Hochschränke → Abschlussregal…* (oder Symbolleiste *Schrank einfügen*) fragt Breite, Höhe, Tiefe, Form und Zeilenende ab und baut das Regal. Danach dockt es wie die anderen Schränke an.
3. Alles Weitere in den *Komponentenoptionen*. Nach *Übernehmen* baut die Erweiterung das Regal neu auf, weil sich eine Schräge oder ein Bogen nicht per Formel umformen lässt (wie die L-Form des Eckschranks). Frontmaterial bleibt dabei erhalten. Ungültige Werte (z. B. Tiefe außen größer als die Tiefe) werden mit einer Meldung zurückgesetzt.

## Komponentenoptionen
| Option | Standard | Bereich |
|---|---|---|
| Breite | 300 mm | lichte Breite mindestens 100 mm |
| Höhe | 700 (Unter-, Oberschrank), 2100 mm (Hochschrank) | |
| Tiefe (Korpus ohne Rückwand) | 520 mm, Oberschrank 400 mm (Dialog) | ab 200 mm |
| Form | gerade | gerade, schräg, rund |
| Zeilenende (Seite außen) | rechts | rechts (Nachbar steht links), links |
| Tiefe außen (bei schräg) | 150 mm | 50 mm (verstellbare Böden 60 mm) bis Tiefe − 20 mm |
| Radius (bei rund) | 300 mm | höchstens lichte Breite und Tiefe − 60 mm |
| Anzahl Einlegeböden | 1, Hochschrank 4 | 0–6, gleich hohe Fächer |
| Einlegeböden | verstellbar (Bodenträger) | verstellbar, fest (gedübelt) |
| Farbe | Korpusfarbe | Korpusfarbe, Frontfarbe |

Der Typ (Unter-, Ober-, Hochschrank) wird beim Anlegen über den Menüeintrag gewählt und bestimmt die Kategorie für Frontfarbe, Sockelfüße und TCN-Export. Feste Maße (*Komponentenattribute*): `Materialstaerke_Korpus` 19 mm, `Materialstarke_Rueckwand` 8 mm, `Rueckversatz_Einlegeboden` 10 mm.

## Aufbau
* **Seite innen** (am Nachbarschrank) über die volle Tiefe, **Seite außen** bei *gerade* ebenso, bei *schräg* mit der *Tiefe außen*, bei *rund* vom Bogenende bis hinten (Tiefe − Radius). Beide hinten bündig. Der Korpus beginnt wie bei den anderen Schränken bei y = 19 mm.
* **Boden** und **Deckel** zwischen den Seiten über die volle Tiefe. Einen Deckel statt Streben, weil das Regal offen ist.
* **Einlegeböden** verstellbar: 10 mm hinter der Vorderkante, Lochreihen in beiden Seiten. Fest: Mittelböden über die volle Tiefe, gedübelt wie Zwischenböden.
* **Rückwand** 8 mm hinter dem Korpus über die ganze Breite.
* **Schräg:** Böden als Trapez, Vorderkante von der Ecke an der Seite innen bis zur Vorderkante der Seite außen.
* **Rund:** Vorderkante gerade bis zum Bogen, dann ein Viertelkreis, der tangential in die Seite außen läuft. Der Radius wird auf die lichte Breite begrenzt.

## Material, Anleimer, Stückliste
Gezeichnet ist immer das **Endmaß**. Platten haben „Melamin weiss“, sichtbare Kanten „Anleimer Melamin weiss“ (2 mm). Die Angaben stehen im Wörterbuch `ladb_opencutlist` am Material; Stückliste, Zuschnittplan, Etiketten und TCN-Export des Plugins Schrank-CNC lesen sie.

| Teil | Kanten mit Anleimer |
|---|---|
| Seiten | vorne |
| Boden, Deckel, Einlegeböden | vorne bzw. Schräge oder Bogen |
| Rückwand | an der Seite außen (am Zeilenende sichtbar) |

Bei Schräge und Bogen sind Roh-, Fräs- und Fertigmaß das umschließende Rechteck: zugeschnitten wird das Rechteck, die Kontur fräst die CNC. In der Stückliste steht die Schräg- oder Bogenkante unter *Kante Kontur* mit ihrer Länge und zählt in die Anleimer-Laufmeter; auf dem Etikett steht „Kontur mit Anleimer (CNC)“.

**Farbe Frontfarbe:** alle Teile tragen `JT_Schrank/frontfarbe`. *Frontfarbe und Griffe ändern* gibt ihnen das Frontmaterial und den passenden Anleimer, aber keine Griffbohrungen.

## Tags
Jedes Teil hat einen eigenen Tag `<Kürzel>_<Teil>`: `RA1_SeiteL`, `RA1_SeiteR`, `RA1_Boden`, `RA1_Deckel`, `RA1_Rueckwand`, `RA1_Einlegeboden1` … bzw. `RA1_Mittelboden1` … (fest). Das Kürzel ist `RA1`, oder `RA2` usw., wenn es schon vergeben ist. An jedem Teil steht `JT_Schrank` mit `schrank`, `typ` (`Abschlussregal`), `kategorie`, `teil` und `rolle` (gemeinsame Rollen-Tabelle, unverändert).

## TCN-Export (Plugin Schrank-CNC)
Dübel, Lochreihen, Rückwand und Sockelfüße wie bei den anderen Schränken; an der Seite außen sitzen die Dübel nur auf ihrer Tiefe. Neu für Schräge und Bogen:
* Der Umriss steht im Wörterbuch `JT_Kontur` an der Definition des Bodens (`umriss`, `kante`).
* Die Kante fräst der Konturfräser **1004** (Ø 20) ganz durch (Stärke + 1 mm), um den Fräserradius in den Abfall und um den Anleimer (2 mm) in die Platte versetzt.
* Die Bahn beginnt und endet tangential außerhalb der Platte (Fräser samt Radius 10 mm frei) und fährt ins Material.
* Bögen als echte Kreisbögen `W#2125` mit Radius und Winkel wie in `bogen.tcn` (EW2 automatisch: positiv gegen den Uhrzeigersinn).
* Sockelfüße, die bei einer Schräge oder einem Bogen über die Kante ragen würden, rücken auf kürzestem Weg nach innen (mindestens 20 mm vom Rand).

Die Arbeitsplatte über dem Regal bleibt rechteckig; die Schräge schneidest du von Hand.

## Hilfe in SketchUp
Eine Kurzfassung steht oben im Fenster *Komponentenoptionen* (Summary und Description) mit Link auf diese Seite. Der Text steht als `HILFE` in `src/regal_abschluss/main.rb`.

## Tests
`ruby test/test_regal_abschluss.rb` prüft ohne SketchUp alle Formen, Typen und Zeilenenden (Teile, Lage, Tiefe der Seite außen, Fächer, Anleimer, Tags, `JT_Schrank`, `JT_Kontur`), feste Böden, Frontfarbe-Markierung, ungültige Maße, den Neuaufbau nach Änderungen (gleich wie frisch erzeugt, Kürzel und Typ bleiben, Frontmaterial bleibt), den Dialog und die Kurzhilfe. `sketchup-tcn-export-plugin/test/test_export.rb` prüft Kontur, Dübel, Sockelfüße, Stückliste und Frontfarbe am Regal.

Noch nicht in echtem SketchUp erprobt.
