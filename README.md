# Küchenplaner 2 (SketchUp)

SketchUp-Komponenten für den Küchenbau und das geplante TCN-Export-Plugin.

| Ordner | Inhalt |
|---|---|
| [`Komponenten/`](Komponenten/) | eine Komponente je Unterordner: technische Dateien, Tests, Kurzdoku (`README.md`) |
| [`Komponenten/unterschrank_tuer/`](Komponenten/unterschrank_tuer/) | Unterschrank mit Tür (`Unterschrank.skp`, Ausgangskomponente) |
| [`Komponenten/unterschrank_schubladen/`](Komponenten/unterschrank_schubladen/) | Unterschrank mit 1–6 Schubladen (Erweiterung `.rbz`) |
| [`Komponenten/hochschrank/`](Komponenten/hochschrank/) | Hochschrank (Skript erzeugt `Hochschrank.skp`) |
| [`Komponenten/oberschrank/`](Komponenten/oberschrank/) | Oberschrank mit 0–2 Türen (Skript erzeugt `Oberschrank.skp`) |
| [`sketchup-tcn-export-plugin/`](sketchup-tcn-export-plugin/) | TCN-Export für TpaCAD, bisher Plan und Beispieldateien |

## Regeln für alle Komponenten
* **OpenCutList-fähig:** Jede Platte hat ein Material (Standard „Melamin weiss“). Sichtbare Kanten bekommen Anleimer nur als OCL-Zuweisung (Kantenmaterial auf der Kantenfläche). In SketchUp wird immer das Endmaß gezeichnet; den 2-mm-Abzug für Zuschnitt- und Fräsmaß rechnet nur OCL.
* **Eindeutiger Tag je Teil** nach dem Schema `<Kürzel>_<Bereich>_<Teil>` (z. B. `HS1_U1_Front`, `USS1_SeiteL`), dazu das Wörterbuch `JT_Schrank` am Teil, damit jedes Teil seiner CAD/CAM-Datei zugeordnet werden kann. Die Tabelle `ROLLEN` ist in allen Komponenten gleich (der Hochschrank-Test prüft das).
* **Kurzhilfe in der Komponente:** Summary/Description der Dynamic Component (oben im Fenster *Komponentenoptionen*) mit Link auf die README der Komponente.

## Tests
Alle Tests laufen ohne SketchUp (Mock-API und DC-Formel-Auswerter), Ruby ≥ 3.1:

```sh
./run_tests.sh
```

Sie laufen auch automatisch bei jedem Pull Request (GitHub Actions).

## Arbeitsweise
Alle Änderungen auf einem eigenen Branch mit Pull Request; Jürgen prüft und gibt frei.
