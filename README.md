# Küchenplaner 2 (SketchUp)

SketchUp-Komponenten für den Küchenbau und das TCN-Export-Plugin. Alles sind SketchUp-Erweiterungen (`.rbz`) und erscheint im gemeinsamen Menü **Erweiterungen › Küchenplaner**.

## Installieren
* **Alles auf einmal:** [`Kuechenplaner_alle.rbz`](Kuechenplaner_alle.rbz) in SketchUp über *Erweiterungen → Extension Manager → Erweiterung installieren* wählen.
* **Einzeln:** die `.rbz` im Ordner der Komponente (z. B. `Komponenten/hochschrank/hochschrank.rbz`) bzw. `sketchup-tcn-export-plugin/schrank_cnc.rbz` installieren.

Danach ist *Erweiterungen › Küchenplaner* nach Schranktypen geordnet: *Unterschränke* (Eckschrank Blindeck, Eckschrank L-Form, Inselschrank, Abschlussregal, Unterschrank Mülltrennung, Unterschrank Geschirrspüler, Unterschrank Handtuchauszug, Unterschrank Kochfeld mit Abzug, Unterschrank Backofen (Herdumbau), Unterschrank Kühlschrank, Unterschrank mit Schubladen, Spülenschrank, Unterschrank mit Tür), *Oberschränke* (Eck-Oberschrank L-Form, Oberschrank, Oberschrank Dunstabzug, Oberschrank mit Klappe, Abschlussregal) und *Hochschränke* (Apothekerschrank, Hochschrank, Hochschrank Geräte, Hochschrank Kühlschrank, Hochschrank Vorrat, Abschlussregal), dazu *Geräte* und *Raum* (Wände, Fenster, Türen, siehe [`Komponenten/raum/`](Komponenten/raum/)). Darunter stehen *TCN exportieren…*, *Stückliste…*, *Etiketten…*, *Zuschnittplan…*, *Frontfarbe und Griffe ändern…*, *Schrank andocken…* und *Einstellungen…*. Neu erzeugte Schränke hängen am Andock-Werkzeug und rasten an Nachbarschränke oder Wände an; ist ein Schrank ausgewählt, kommt der neue direkt rechts daneben (siehe [Schrank andocken](sketchup-tcn-export-plugin/README.md#schrank-andocken)). Ganz unten folgen *Plugins aktualisieren (GitHub)…* und *Plugins aus Ordner laden…*: damit kommen neue Versionen ohne Extension Manager und ohne Neustart (siehe [`kuechenplaner-update/`](kuechenplaner-update/)). Dazu kommt die Symbolleiste **Küchenplaner** mit sechs Icons: *Schrank einfügen* (eine Auswahl aller Schranktypen nach Unter-, Ober- und Hochschränken), *Schrank andocken*, *Arbeitsplatte*, *Raum* (Raum anlegen, Wände, Fenster und Türen), *Frontfarbe und Griffe* und *TCN exportieren* (siehe [`kuechenplaner-symbolleiste/`](kuechenplaner-symbolleiste/)). Das Untermenü gibt es nur einmal, egal wie viele der Erweiterungen installiert sind. Einzeln und zusammen installieren verträgt sich (gleiche Dateien).

Nach Änderungen an einem `src/`-Ordner alle `.rbz` neu bauen (der Test prüft, dass sie zum Quelltext passen):

```sh
./build_rbz.sh
```

| Ordner | Inhalt |
|---|---|
| [`Komponenten/`](Komponenten/) | eine Komponente je Unterordner: `src/` (Erweiterung), `<name>.rbz`, Tests, Kurzdoku (`README.md`) |
| [`Komponenten/unterschrank_tuer/`](Komponenten/unterschrank_tuer/) | Unterschrank mit Tür (`Unterschrank.skp`, Ausgangskomponente; `.rbz` fügt sie ein und richtet sie ein) |
| [`Komponenten/unterschrank_schubladen/`](Komponenten/unterschrank_schubladen/) | Unterschrank mit 1–6 Schubladen (`.rbz`) |
| [`Komponenten/unterschrank_spuele/`](Komponenten/unterschrank_spuele/) | Spülenschrank mit Türen oder Blende + Auszug, Installationsebene (`.rbz`) |
| [`Komponenten/unterschrank_kochfeld/`](Komponenten/unterschrank_kochfeld/) | Unterschrank für Kochfeld mit Abzug: Blende, 1–3 Schubladen, Kanal (`.rbz`) |
| [`Komponenten/unterschrank_backofen/`](Komponenten/unterschrank_backofen/) | Herdumbauschrank: Backofen unter dem Kochfeld, Einbauboden, darunter Schublade oder Blende (`.rbz`) |
| [`Komponenten/unterschrank_abfall/`](Komponenten/unterschrank_abfall/) | Unterschrank Mülltrennung: LEGRABOX-Auszug mit 1–4 Abfallbehältern, wahlweise Schublade oben (`.rbz`) |
| [`Komponenten/unterschrank_insel/`](Komponenten/unterschrank_insel/) | Inselschrank: Türen oder 1–4 Schubladen, Rückseite verkleidet, Wangen, erhöhte Theke (`.rbz`) |
| [`Komponenten/unterschrank_handtuch/`](Komponenten/unterschrank_handtuch/) | Schmaler Unterschrank 150/200 mm mit Hochauszug Häfele HU Slim Base (`.rbz`) |
| [`Komponenten/eckschrank/`](Komponenten/eckschrank/) | Eck-Unterschrank: Blindeck mit einer Tür, zwei Türen oder Kesseböhmer LeMans II; L-Form mit Falttür (`.rbz`) |
| [`Komponenten/eck_oberschrank/`](Komponenten/eck_oberschrank/) | Eck-Oberschrank L-Form mit Falttür, L-Böden, Rückwände in der Nut (`.rbz`) |
| [`Komponenten/hochschrank/`](Komponenten/hochschrank/) | Hochschrank (`.rbz`) |
| [`Komponenten/hochschrank_geraete/`](Komponenten/hochschrank_geraete/) | Hochschrank für zwei Einbaugeräte, z. B. Backofen + Mikrowelle (`.rbz`) |
| [`Komponenten/hochschrank_kuehlschrank/`](Komponenten/hochschrank_kuehlschrank/) | Hochschrank für Einbau-Kühlschrank, Gefrierschrank oder Kühl-Gefrier-Kombi, Schlepp- oder Festtür, Lüftungsschacht (`.rbz`) |
| [`Komponenten/hochschrank_vorrat/`](Komponenten/hochschrank_vorrat/) | Vorrats-Hochschrank: Tür außen, dahinter 2–6 LEGRABOX-Innenschubkästen und Einlegeböden (`.rbz`) |
| [`Komponenten/unterschrank_geschirrspueler/`](Komponenten/unterschrank_geschirrspueler/) | Nische für vollintegrierten Geschirrspüler 45/60 mit Front (`.rbz`) |
| [`Komponenten/unterschrank_kuehlschrank/`](Komponenten/unterschrank_kuehlschrank/) | Nische für Unterbau-Kühlschrank oder Weinkühler 30/45/60, ohne Korpus (`.rbz`) |
| [`Komponenten/oberschrank/`](Komponenten/oberschrank/) | Oberschrank mit 0–2 Türen (`.rbz`) |
| [`Komponenten/oberschrank_dunstabzug/`](Komponenten/oberschrank_dunstabzug/) | Oberschrank für eine Flachschirmhaube: unten offen, Haubenboden, Rohrausschnitt in Haubenboden und Deckel (`.rbz`) |
| [`Komponenten/oberschrank_klappe/`](Komponenten/oberschrank_klappe/) | Oberschrank mit Klappe Blum AVENTOS HK-top oder HF (Faltklappe) (`.rbz`) |
| [`Komponenten/apothekerschrank/`](Komponenten/apothekerschrank/) | Apothekerschrank: Hochfront mit Vollauszug und 2–6 LEGRABOX-Kästen (`.rbz`) |
| [`Komponenten/regal_abschluss/`](Komponenten/regal_abschluss/) | Abschlussregal fürs Zeilenende: offen, gerade, schräg oder rund, als Unter-, Ober- oder Hochschrank (`.rbz`) |
| [`Komponenten/geraete/`](Komponenten/geraete/) | Geräte für Planung und Kundenrendering: Spüler, Kochfeld mit und ohne Abzug, Spüle, Backofen, Kompaktgerät, Mikrowelle, Wärmeschublade (`.rbz`) |
| [`Komponenten/raum/`](Komponenten/raum/) | Raum gestalten: Wände (Rechteck oder aus Linien), Fenster, Türen, Durchgänge; Schränke docken an die Wände an (`.rbz`) |
| [`docs/`](docs/) | Pläne und Vorschläge aus den Projekt-Threads, Übersicht welcher Schrank in welchem Ordner liegt, Beschlag-Unterlagen |
| [`kuechenplaner-update/`](kuechenplaner-update/) | Erweiterung „Plugins aktualisieren“ (`kuechenplaner_update.rbz`): neue Versionen von GitHub oder aus einem Ordner laden, ohne Extension Manager |
| [`kuechenplaner-symbolleiste/`](kuechenplaner-symbolleiste/) | Erweiterung „Symbolleiste“ (`kuechenplaner_symbolleiste.rbz`): Symbolleiste Küchenplaner mit Schrank-Auswahl |
| [`sketchup-tcn-export-plugin/`](sketchup-tcn-export-plugin/) | Plugin „Schrank-CNC“ (`schrank_cnc.rbz`): TCN-Export für TpaCAD, Frontfarbe und Griffe ändern, Schrank andocken |

## Regeln für alle Komponenten
* **Material und Anleimer:** Jede Platte hat ein Material (Standard „Melamin weiss“). Sichtbare Kanten bekommen Anleimer nur als Kantenmaterial auf der Kantenfläche. In SketchUp wird immer das Endmaß gezeichnet; den 2-mm-Abzug für Zuschnitt- und Fräsmaß rechnen Stückliste, Zuschnitt und TCN-Export des Plugins.
* **Gemeinsame Regeln, automatisch geprüft** (`test/test_konsistenz.rb`, baut jeden Schrank und exportiert ihn): TCN nur mit Werkzeugen aus der CNC-Werkzeugliste (Fräser, Bohrer blind/durch, waagrecht nur Ø8), Fräsungen in Zustellschritten von höchstens 20 mm, Bögen als `W#2125` wie `bogen.tcn` mit Vorzeichen wie in der TPA-Ansicht, keine Verweise auf das frühere Zuschnittprogramm, Timer mit möglichem Meldungsfenster halten sich zuerst an (`UI.stop_timer`). Neue Komponenten fallen ohne Eintrag mit hinein.
* **Eindeutiger Tag je Teil** nach dem Schema `<Kürzel>_<Bereich>_<Teil>` (z. B. `HS1_U1_Front`, `USS1_SeiteL`), dazu das Wörterbuch `JT_Schrank` am Teil, damit jedes Teil seiner CAD/CAM-Datei zugeordnet werden kann. Die Tabelle `ROLLEN` ist in allen Komponenten gleich (der Hochschrank-Test prüft das).
* **Erweiterung mit Menüeintrag:** Jede Komponente ist eine Erweiterung (`src/<name>.rb` + `src/<name>/main.rb`) und hängt ihren Eintrag über `Kuechenplaner.schrank('Unterschränke' | 'Oberschränke' | 'Hochschränke', titel) { … }` in die passende Gruppe (damit erscheint er auch in der Schrank-Auswahl der Symbolleiste; Geräte und Raum über `Kuechenplaner.untermenu('Geräte' | 'Raum')`) unter *Erweiterungen › Küchenplaner* ein; Werkzeuge nutzen `Kuechenplaner.menu`. Nach dem Erzeugen ruft jeder Schrank `Kuechenplaner.neuer_schrank(inst) if Kuechenplaner.respond_to?(:neuer_schrank)` auf (vor `model.selection.clear`), damit das Andock-Werkzeug greift; neue Schrank-Komponenten brauchen diese Zeile auch (Test). Der Block, der dieses Untermenü anlegt, steht wortgleich in jeder `main.rb` (der Test prüft das).
* **Tiefe verstellbar:** Jeder Schrank fragt beim Anlegen seine Maße ab (Breite, Höhe, Tiefe; Vorschlag Tiefe 520 mm, Oberschrank 400 mm). Danach lässt sie sich im Fenster *Komponentenoptionen* ändern; alle abhängigen Teile (Seiten, Böden, Streben, Rückwand, Einlegeböden, Schubkästen) folgen per Formel. Die LEGRABOX-Schiene gibt es nur in festen Nennlängen (350–650 mm): genommen wird die größte mit NL + 3 mm ≤ lichte Tiefe. Der TCN-Export und *Geräte in Schränke setzen* lesen die geänderten Werte an der Instanz (nicht den Stand beim Erzeugen) und bohren die Schienen nie länger als die gezeichnete lichte Tiefe zulässt. Der gemeinsame Test `test/tiefe_helfer.rb` prüft je Komponente: Tiefe nachträglich ändern ergibt genau denselben Schrank wie gleich mit dieser Tiefe erzeugt. Er prüft auch, dass keine Formel auf ein anderes Formel-Attribut desselben Bauteils verweist: SketchUp rechnet die Formeln eines Bauteils nur einmal der Reihe nach, ein solcher Wert bliebe nach einer Änderung alt (so blieb beim Spülenschrank der Auszug nach einer Tiefenänderung gleich lang).
* **Kurzhilfe in der Komponente:** ein Satz als Summary der Dynamic Component (oben im Fenster *Komponentenoptionen*) und als Beschreibung; keine lange Description, die ausführliche Doku steht in der README der Komponente. Listen-Optionen mit Umlauten kodiert `dc_optionen` so, wie das DC-Fenster sie liest (%FC statt %C3%BC).

## Eingabefenster

Alle Fenster zum Eingeben (Maße neuer Schränke, Raum, Arbeitsplatte, Frontfarbe, Etiketten,
Einstellungen) sehen aus wie die Dialoge im Treppenplaner. Sie kommen aus einer Datei,
`gemeinsam/eingabe.rb` (`Kuechenplaner::Eingabe.abfragen`, Argumente wie `UI.inputbox`, Ergebnis
im Block). `./build_rbz.sh` kopiert sie in jede Erweiterung nach `src/kuechenplaner_gemeinsam/`.
Ungültige Eingaben bleiben im Fenster stehen, ein Doppelklick auf „Einfügen“ fügt nur einmal ein.
Neue Komponenten benutzen kein `UI.inputbox` (der Test prüft das).

## Generelle Einstellungen der Küche

Sockelhöhe (Stellfüße), Abstand Schrankrückseite – Wand und lichter Abstand Arbeitsplatte –
Oberschrank stehen unter *Küchenplaner › Einstellungen…* und gelten für die ganze Küche im Modell.
Sie kommen aus `gemeinsam/einstellungen.rb` (`Kuechenplaner::Einstellungen`), die `./build_rbz.sh`
wie das Eingabefenster in jede Erweiterung kopiert. Tabelle und Standardwerte siehe
[Einstellungen](sketchup-tcn-export-plugin/README.md#einstellungen).

## Tests
Alle Tests (Komponenten, Plugin und `test/test_erweiterungen.rb` für Menü und `.rbz`) laufen ohne SketchUp (Mock-API und DC-Formel-Auswerter), Ruby ≥ 3.1:

```sh
./run_tests.sh
```

Sie laufen auch automatisch bei jedem Pull Request (GitHub Actions).

## Arbeitsweise
Alle Änderungen auf einem eigenen Branch mit Pull Request; Jürgen prüft und gibt frei.
