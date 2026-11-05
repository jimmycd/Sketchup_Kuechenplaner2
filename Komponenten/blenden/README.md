# Blenden und Wangen (Dynamic Components)

Drei Befehle, um Restmaße und sichtbare Seiten einer Schrankzeile sauber zu schließen: **Passblende**, **Wange** und **Sockelblende**. Es sind keine Schränke. Sie verhalten sich aber für Stückliste, Etiketten, Zuschnitt, Frontfarbe und TCN-Export wie Schrankteile (Material, Kanten, Tags, `JT_Schrank`).

## Installieren und benutzen
1. SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `blenden.rbz` (oder `Kuechenplaner_alle.rbz` aus dem Hauptordner).
2. *Erweiterungen → Küchenplaner → Blenden & Wangen → Passblende… / Wange… / Sockelblende…* oder in der Symbolleiste *Schrank einfügen* → *Blenden & Wangen*.
3. Maße danach in den *Komponentenoptionen* ändern.

**Mit Auswahl geht es schneller:**
* *Passblende* und *Wange*: Genau einen Schrank auswählen. Der Dialog schlägt dessen Typ, Höhe, Tiefe und Sockelhöhe vor. Das Teil wird links oder rechts direkt an den Schrank gesetzt und bekommt dessen Frontmaterial. Ohne Auswahl startet das Andock-Werkzeug.
* *Sockelblende*: Ohne Auswahl deckt sie **alle Unter- und Hochschränke der Küche** ab. Mit Auswahl deckt sie nur die gewählten Schränke ab. Je Zeile entsteht eine Blende von der linken bis zur rechten Außenkante. Passblenden zählen mit. An Wangen endet die Blende, weil die Wange bis zum Boden reicht. Eine Lücke über 20 mm beginnt eine neue Zeile. Oberschränke werden ignoriert.
  * **Unterschiedliche Fronten in der Zeile** (Jürgen 2026-11-05): Schränke gleicher Richtung, deren Fronten bis 150 mm versetzt stehen (z. B. Kühlschrank-Hochschrank 560 mm tief neben 520-mm-Unterschränken, Rückseiten an der Wand), gehören zu einer Zeile. Die Blende läuft ohne Versatz durch. Flucht und Tiefe geben die Standard-Unterschränke (Tür, Schubladen) vor. Sonderschränke zählen nur, wenn kein Standard-Unterschrank in der Zeile steht (z. B. allein um die Ecke).
  * **Innenecke (L- oder U-Küche):** Die Zeile, deren Schränke hinter die Ecke laufen, endet an der Rückseite der Blende der Querzeile. Die Querzeile wird bis an die Vorderseite dieser Blende verlängert. So bleibt keine Lücke und nichts überlappt.
  * **Zeilenenden** (Jürgen 2026-11-05) erkennt der Befehl selbst:
    | Ende | Was passiert |
    |---|---|
    | an einer Raumwand (Erweiterung *Raum*) | Die Blende endet an der Schrankkante. |
    | an einer Wange | Die Blende endet an der Innenseite der Wange. |
    | an einer Innenecke | wie oben (Querblende) |
    | frei | *Sockel ums Eck* (Standard): Die Blende springt auch seitlich um den Rücksprung (50 mm) zurück. Ein Seitenstück läuft bis zur Wand, also bis Korpusrückseite + Wandabstand aus den Küchen-Einstellungen. Mit *nur Blende* endet die Blende an der Schrankkante wie bisher. |
    | Insel (Inselschrank in der Zeile) | Beide Enden sind frei, die Sockelblende läuft ringsum: vorne und hinten je eine Blende, die Seitenstücke enden an der Rückseite der hinteren Blende. Wände zählen hier nicht. |
    Ohne Raum im Modell gelten alle Enden ohne Wange und ohne Innenecke als frei. Der Dialog zeigt, wie viele freie Enden er gefunden hat.
  * Der Dialog fragt Sockelhöhe (aus den Küchen-Einstellungen), Stärke, *Freie Enden* (Sockel ums Eck / nur Blende) und *Eckstoß* (stumpf / Gehrung). Ohne Auswahl fragt er außerdem, ob vorhandene Sockelblenden ersetzt werden sollen (Standard: ja).
  * Gibt es keine Unter- oder Hochschränke, entsteht eine freie Blende mit Länge aus dem Dialog.

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
| Sockelausklinkung | **nein** / ja (nur Unter- und Hochschrank) |

* Tiefe = Front + Korpus + Rückwand: Die Wange schließt **bündig mit der Front** ab und hinten mit der Rückwand. Beim Geschirrspüler-Unterschrank beginnen die Abschlusswangen dagegen an der Korpusvorderkante.
* Kanten vorne und oben, beim Oberschrank auch unten. Rolle *Wange*: Der TCN-Export formatiert sie nur. *Frontfarbe* färbt sie mit um (Kennzeichen `frontfarbe` am Teil), einen Griff bekommt sie nicht.
* **Sockelausklinkung** (Variante C): Unten vorne wird die Wange um die Sockelhöhe ausgeklinkt, so tief wie die Vorderseite der Sockelblende (Spalt + Korpus + Rücksprung 50 mm). Die Sockelfuge läuft dadurch optisch um die Ecke, die Wange steht trotzdem auf dem Boden. Die Sockelblende endet weiter an der Innenseite der Wange.
  * Der TCN-Export fräst die Ausklinkung mit dem Konturfräser 1004 (Ø 20 mm) ganz durch: Die Bahn beginnt unter der Platte, fährt hoch in die Ecke und vorne wieder hinaus, in Zustellschritten von höchstens 20 mm. In der Innenecke bleibt ein Radius von 10 mm.
  * Die Flächen der Ausklinkung bekommen keinen Anleimer. Kante vorne und oben bleiben wie bisher.
* Andock-Werkzeug: Als Unterkante zählt die Korpusunterkante (Kennzeichen `sockel_unter_korpus`). So steht die Wange neben einem Schrank richtig auf dem Boden.

## Sockelblende (Kürzel SB)
| Option | Standard |
|---|---|
| Länge | je Zeile aus den Schränken, sonst 600 mm |
| Sockelhöhe | aus Küchenplaner › Einstellungen (Standard 100 mm), die Blende ist 3 mm niedriger (Luft zum Boden) |
| Tiefe Korpus | für die Seitenstücke |
| Seitenstücke | keine / links / rechts / beide |
| Stärke | **16** / 19 mm |
| Rücksprung | 50 mm hinter der Korpusvorderkante |
| Eckstoß Seitenstücke | **stumpf** / Gehrung |

* Die Blende wird auf die Sockelfüße geclipst, deshalb gibt es keine Bohrungen.
* Über 2800 mm (`Max_Laenge`) wird sie in gleich lange Stücke geteilt, höchstens 5 (bis 14 m). Ist eine Zeile länger, bekommt sie mehrere Sockelblenden. Die Stücke heißen `Sockelblende1` … `Sockelblende5`.
* **Seitenstücke** schließen eine frei stehende Zeile seitlich bis zur Wand. Sie stehen außen, die Blende stößt stumpf dagegen. Kante vorne und oben.
* **Gehrung:** Blende und Seitenstück laufen beide bis zur Außenecke und sind dort auf 45° geschnitten. Das Seitenstück hat dann vorne keine Kante. Die Stückliste nennt die lange Seite, die Gehrung wird an der Säge geschnitten (keine TCN-Bearbeitung).
* Kante an der Blende nur oben. Material „Melamin weiss“, Rolle *Sockel*. Die Sockelblende hat die Kategorie *Sockel*. Sie zählt also nicht als Unterschrank für Arbeitsplatte und Frontfarbe.

## Ändern in den Komponentenoptionen
Ausklinkung und Gehrung sind keine Quader. Die DC würde sie nach einer Änderung nur strecken. Deshalb wird eine Wange mit Ausklinkung bzw. eine Sockelblende mit Gehrung nach *Übernehmen* neu gebaut (wie das Abschlussregal). Das gilt auch, wenn Ausklinkung oder Gehrung gerade ein- oder ausgeschaltet wurde. Alle anderen Blenden rechnet die DC wie bisher.

## Material, Kanten, Tags
Gezeichnet ist immer das **Endmaß**. Den Kantenabzug rechnet das Plugin Schrank-CNC. Platten haben „Melamin weiss“ (Typ Platte), Passblende und Wange das Frontmaterial des gewählten Schranks. Kantenflächen haben „Anleimer Melamin weiss“ oder den Anleimer der Nachbarfront (Typ Kante, 2 mm).

Tags: `PB1_Blende`, `PB1_Winkelleiste`, `WG1_WangeL`/`WG1_WangeR`, `SB1_Sockelblende1` …, `SB1_SockelSeiteL`/`R`. Jedes weitere Teil bekommt die nächste Nummer (`PB2` …). An jedem Teil steht `JT_Schrank` mit `schrank`, `typ` (Passblende, Wange, Sockelblende), `kategorie` (Unterschrank/Oberschrank/Hochschrank bzw. Sockel), `bereich`, `teil` und `rolle` (Front, Leiste, Wange, Sockel).

## Tests
`ruby test/test_blenden.rb` (oder `./run_tests.sh` im Hauptordner): Maße aller Teile, Neuberechnung nach geänderten Optionen, Tiefe nachträglich, Kanten, Material, Tags, Lage am gewählten Schrank, Zeilen und Innenecken für die Sockelblende (L-Küche), Zeilenenden (Wand, Wange, frei, Innenecke, Insel), Gehrung, Sockelausklinkung, Neuaufbau, Dialoge. Den TCN-Export der Ausklinkung prüft `sketchup-tcn-export-plugin/test/test_export.rb`.
