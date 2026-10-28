# Küchenplaner 2 (SketchUp)

SketchUp-Komponenten für den Küchenbau und das TCN-Export-Plugin. Alles sind SketchUp-Erweiterungen (`.rbz`) und erscheint im gemeinsamen Menü **Erweiterungen › Küchenplaner**.

## Installieren
* **Alles auf einmal:** [`Kuechenplaner_alle.rbz`](Kuechenplaner_alle.rbz) in SketchUp über *Erweiterungen → Extension Manager → Erweiterung installieren* wählen.
* **Einzeln:** die `.rbz` im Ordner der Komponente (z. B. `Komponenten/hochschrank/hochschrank.rbz`) bzw. `sketchup-tcn-export-plugin/schrank_cnc.rbz` installieren.

Danach ist *Erweiterungen › Küchenplaner* nach Schranktypen geordnet: *Unterschränke* (Eckschrank Blindeck, Eckschrank L-Form, Unterschrank Geschirrspüler, Unterschrank Handtuchauszug, Unterschrank Kochfeld mit Abzug, Unterschrank mit Schubladen, Spülenschrank, Unterschrank mit Tür), *Oberschränke* (Oberschrank) und *Hochschränke* (Apothekerschrank, Hochschrank, Hochschrank Geräte). Darunter stehen *TCN exportieren…* und *Frontfarbe und Griffe ändern…*. Ganz unten folgen *Plugins aktualisieren (GitHub)…* und *Plugins aus Ordner laden…*: damit kommen neue Versionen ohne Extension Manager und ohne Neustart (siehe [`kuechenplaner-update/`](kuechenplaner-update/)). Das Untermenü gibt es nur einmal, egal wie viele der Erweiterungen installiert sind. Einzeln und zusammen installieren verträgt sich (gleiche Dateien).

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
| [`Komponenten/unterschrank_handtuch/`](Komponenten/unterschrank_handtuch/) | Schmaler Unterschrank 150/200 mm mit Hochauszug Häfele HU Slim Base (`.rbz`) |
| [`Komponenten/eckschrank/`](Komponenten/eckschrank/) | Eck-Unterschrank: Blindeck mit einer Tür, zwei Türen oder Kesseböhmer LeMans II; L-Form mit Falttür (`.rbz`) |
| [`Komponenten/hochschrank/`](Komponenten/hochschrank/) | Hochschrank (`.rbz`) |
| [`Komponenten/hochschrank_geraete/`](Komponenten/hochschrank_geraete/) | Hochschrank für zwei Einbaugeräte, z. B. Backofen + Mikrowelle (`.rbz`) |
| [`Komponenten/unterschrank_geschirrspueler/`](Komponenten/unterschrank_geschirrspueler/) | Nische für vollintegrierten Geschirrspüler 45/60 mit Front (`.rbz`) |
| [`Komponenten/oberschrank/`](Komponenten/oberschrank/) | Oberschrank mit 0–2 Türen (`.rbz`) |
| [`Komponenten/apothekerschrank/`](Komponenten/apothekerschrank/) | Apothekerschrank: Hochfront mit Vollauszug und 2–6 LEGRABOX-Kästen (`.rbz`) |
| [`Komponenten/geraete/`](Komponenten/geraete/) | Geräte für Planung und Kundenrendering: Spüler, Kochfeld mit Abzug, Spüle, Backofen, Kompaktgerät, Mikrowelle, Wärmeschublade (`.rbz`) |
| [`docs/`](docs/) | Pläne und Vorschläge aus den Projekt-Threads, Übersicht welcher Schrank in welchem Ordner liegt, Beschlag-Unterlagen |
| [`kuechenplaner-update/`](kuechenplaner-update/) | Erweiterung „Plugins aktualisieren“ (`kuechenplaner_update.rbz`): neue Versionen von GitHub oder aus einem Ordner laden, ohne Extension Manager |
| [`sketchup-tcn-export-plugin/`](sketchup-tcn-export-plugin/) | Plugin „Schrank-CNC“ (`schrank_cnc.rbz`): TCN-Export für TpaCAD, Frontfarbe und Griffe ändern |

## Regeln für alle Komponenten
* **OpenCutList-fähig:** Jede Platte hat ein Material (Standard „Melamin weiss“). Sichtbare Kanten bekommen Anleimer nur als OCL-Zuweisung (Kantenmaterial auf der Kantenfläche). In SketchUp wird immer das Endmaß gezeichnet; den 2-mm-Abzug für Zuschnitt- und Fräsmaß rechnet nur OCL.
* **Eindeutiger Tag je Teil** nach dem Schema `<Kürzel>_<Bereich>_<Teil>` (z. B. `HS1_U1_Front`, `USS1_SeiteL`), dazu das Wörterbuch `JT_Schrank` am Teil, damit jedes Teil seiner CAD/CAM-Datei zugeordnet werden kann. Die Tabelle `ROLLEN` ist in allen Komponenten gleich (der Hochschrank-Test prüft das).
* **Erweiterung mit Menüeintrag:** Jede Komponente ist eine Erweiterung (`src/<name>.rb` + `src/<name>/main.rb`) und hängt ihren Eintrag über `Kuechenplaner.untermenu('Unterschränke' | 'Oberschränke' | 'Hochschränke' | 'Geräte')` in die passende Gruppe unter *Erweiterungen › Küchenplaner* ein; Werkzeuge nutzen `Kuechenplaner.menu`. Der Block, der dieses Untermenü anlegt, steht wortgleich in jeder `main.rb` (der Test prüft das).
* **Kurzhilfe in der Komponente:** Summary/Description der Dynamic Component (oben im Fenster *Komponentenoptionen*) mit Link auf die README der Komponente.

## Tests
Alle Tests (Komponenten, Plugin und `test/test_erweiterungen.rb` für Menü und `.rbz`) laufen ohne SketchUp (Mock-API und DC-Formel-Auswerter), Ruby ≥ 3.1:

```sh
./run_tests.sh
```

Sie laufen auch automatisch bei jedem Pull Request (GitHub Actions).

## Arbeitsweise
Alle Änderungen auf einem eigenen Branch mit Pull Request; Jürgen prüft und gibt frei.
