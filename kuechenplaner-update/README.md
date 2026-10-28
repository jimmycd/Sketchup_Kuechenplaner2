# Plugins aktualisieren (ohne Extension Manager)

Erweiterung `kuechenplaner_update.rbz` (steckt auch in `Kuechenplaner_alle.rbz`). Einmal über den Extension Manager installieren, danach kommen neue Versionen aller Küchenplaner-Erweiterungen direkt aus dem Menü:

* **Erweiterungen › Küchenplaner › Plugins aktualisieren (GitHub)…** holt den aktuellen Stand von Zweig `main` aus [jimmycd/sketchup_kuechenplaner2](https://github.com/jimmycd/sketchup_kuechenplaner2).
* **Erweiterungen › Küchenplaner › Plugins aus Ordner laden…** nimmt den Stand aus einem lokalen Repo-Ordner (z. B. ein Klon oder ein entpacktes ZIP von GitHub). Der zuletzt gewählte Ordner wird gemerkt.

Ablauf:
1. Vergleicht jede Datei der Erweiterungen (`Komponenten/*/src`, `sketchup-tcn-export-plugin/src`, `kuechenplaner-update/src`, also genau den Inhalt von `Kuechenplaner_alle.rbz`) mit dem Plugins-Ordner. Ist alles gleich, kommt nur „Alles aktuell“.
2. Fragt nach („Neue Version gefunden … Jetzt installieren?“) und nennt die betroffenen Erweiterungen.
3. Lädt nur die geänderten Dateien und prüft jede gegen ihre Git-Prüfsumme. Erst wenn alle stimmen, wird in den Plugins-Ordner geschrieben; bei einem Fehler bleibt alles, wie es war.
4. Lädt die geänderten Erweiterungen sofort neu (ausgeschaltete bleiben aus). Neue Komponenten werden registriert und geladen; ihr Menüeintrag steht bis zum nächsten Start am Ende des Küchenplaner-Menüs.

Ein Neustart von SketchUp ist nicht nötig. Bereits eingefügte Schränke im Modell bleiben unverändert; neu erzeugte nutzen den neuen Stand.

Test (ohne SketchUp, GitHub wird durch das Arbeitsverzeichnis ersetzt): `ruby kuechenplaner-update/test/test_update.rb`
