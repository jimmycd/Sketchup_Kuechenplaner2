# Blenden und Wangen (Dynamic Components)

Drei Befehle, um Restmaße und sichtbare Seiten einer Schrankzeile sauber zu schließen: **Passblende**, **Wange** und **Sockelblende**. Es sind keine Schränke. Sie verhalten sich aber für Stückliste, Etiketten, Zuschnitt, Frontfarbe und TCN-Export wie Schrankteile (Material, Kanten, Tags, `JT_Schrank`).

## Installieren und benutzen
1. SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `blenden.rbz` (oder `Kuechenplaner_alle.rbz` aus dem Hauptordner).
2. *Erweiterungen → Küchenplaner → Blenden & Wangen → Passblende… / Wange… / Sockelblende…* oder in der Symbolleiste *Schrank einfügen* → *Blenden & Wangen*.
3. Maße danach in den *Komponentenoptionen* ändern.

**Mit Auswahl geht es schneller:**
* *Passblende* und *Wange*: Genau einen Schrank auswählen. Der Dialog schlägt dessen Typ, Höhe, Tiefe und Sockelhöhe vor. Das Teil wird links oder rechts direkt an den Schrank gesetzt und bekommt dessen Frontmaterial. Ohne Auswahl startet das Andock-Werkzeug.
* *Sockelblende*: Alle Unter- und Hochschränke einer Zeile auswählen (gern samt Wangen und Passblenden). Die Blende läuft von der linken bis zur rechten Außenkante. Die Tiefe kommt von den Schränken, die Sockelhöhe aus den Küchen-Einstellungen. Quer stehende Schränke werden übergangen (Meldung), Oberschränke ignoriert.

## Passblende (Kürzel PB)
| Option | Standard |
|---|---|
| Breite | 50 mm (10–300 mm im Dialog) |
| Höhe | wie der Schrank, ohne Auswahl 700 mm (Hochschrank 2100 mm) |
| Winkelleiste | nein / ja |

* **Blende** 19 mm in der Frontebene (2 mm vor der Korpusvorderkante wie die Fronten), Kante rundum. Rolle *Front*: *Frontfarbe und Griffe* färbt sie mit um, einen Griff bekommt sie nicht.
* **Winkelleiste** (optional) 19 × 80 mm rechtwinklig hinter der Blende an der Schrankseite. Sie wird an die Seite geschraubt und hält die Blende, damit Türen und Auszüge an der Wand frei aufgehen. Kante nur vorne, Material „Melamin weiss“. Rolle *Leiste*.

## Wange (Kürzel WG)
| Option | Standard |
|---|---|
| Schranktyp | Unter-, Ober- oder Hochschrank (beim Anlegen) |
| Seite | links / rechts am Schrank (beim Anlegen) |
| Stärke | **19** / 25 / 38 mm (wächst nach außen) |
| Höhe / Tiefe Korpus | wie der Schrank |
| Sockelhöhe | aus Küchenplaner › Einstellungen (Standard 100 mm); Unter- und Hochschrank: die Wange reicht bis zum Boden |
| Überstand vorne | 0 mm |

* Tiefe = Front + Korpus + Rückwand: Die Wange schließt **bündig mit der Front** ab und hinten mit der Rückwand. Beim Geschirrspüler-Unterschrank beginnen die Abschlusswangen dagegen an der Korpusvorderkante.
* Kanten vorne und oben, beim Oberschrank auch unten. Rolle *Wange*: Der TCN-Export formatiert sie nur. *Frontfarbe* färbt sie mit um (Kennzeichen `frontfarbe` am Teil), einen Griff bekommt sie nicht.
* Andock-Werkzeug: Als Unterkante zählt die Korpusunterkante (Kennzeichen `sockel_unter_korpus`). So steht die Wange neben einem Schrank richtig auf dem Boden.

## Sockelblende (Kürzel SB)
| Option | Standard |
|---|---|
| Länge | aus der Auswahl, sonst 600 mm |
| Sockelhöhe | aus Küchenplaner › Einstellungen (Standard 100 mm), die Blende ist 3 mm niedriger (Luft zum Boden) |
| Tiefe Korpus | für die Seitenstücke |
| Seitenstücke | keine / links / rechts / beide |
| Stärke | **16** / 19 mm |
| Rücksprung | 50 mm hinter der Korpusvorderkante |

* Die Blende wird auf die Sockelfüße geclipst, deshalb gibt es keine Bohrungen.
* Über 2800 mm (`Max_Laenge`) wird sie in gleich lange Stücke geteilt, höchstens 5 (bis 14 m). Die Stücke heißen `Sockelblende1` … `Sockelblende5`.
* **Seitenstücke** schließen eine frei stehende Zeile seitlich bis zur Wand. Sie stehen außen, die Blende stößt stumpf dagegen. Kante vorne und oben.
* Kante an der Blende nur oben. Material „Melamin weiss“, Rolle *Sockel*. Die Sockelblende hat die Kategorie *Sockel*. Sie zählt also nicht als Unterschrank für Arbeitsplatte und Frontfarbe.

## Material, Kanten, Tags
Gezeichnet ist immer das **Endmaß**. Den Kantenabzug rechnet das Plugin Schrank-CNC. Platten haben „Melamin weiss“ (Typ Platte), Passblende und Wange das Frontmaterial des gewählten Schranks. Kantenflächen haben „Anleimer Melamin weiss“ oder den Anleimer der Nachbarfront (Typ Kante, 2 mm).

Tags: `PB1_Blende`, `PB1_Winkelleiste`, `WG1_WangeL`/`WG1_WangeR`, `SB1_Sockelblende1` …, `SB1_SockelSeiteL`/`R`. Jedes weitere Teil bekommt die nächste Nummer (`PB2` …). An jedem Teil steht `JT_Schrank` mit `schrank`, `typ` (Passblende, Wange, Sockelblende), `kategorie` (Unterschrank/Oberschrank/Hochschrank bzw. Sockel), `bereich`, `teil` und `rolle` (Front, Leiste, Wange, Sockel).

## Tests
`ruby test/test_blenden.rb` (oder `./run_tests.sh` im Hauptordner): Maße aller Teile, Neuberechnung nach geänderten Optionen, Tiefe nachträglich, Kanten, Material, Tags, Lage am gewählten Schrank, Zeile für die Sockelblende, Dialoge.
