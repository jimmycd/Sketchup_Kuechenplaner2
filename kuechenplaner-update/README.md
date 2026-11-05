# Plugins aktualisieren (ohne Extension Manager)

Erweiterung `kuechenplaner_update.rbz` (steckt auch in `Kuechenplaner_alle.rbz`). Einmal über den Extension Manager installieren, danach kommen neue Versionen aller Küchenplaner-Erweiterungen direkt aus dem Menü:

* **Erweiterungen › Küchenplaner › Plugins aktualisieren (GitHub)…** holt den aktuellen Stand von Zweig `main` aus [jimmycd/sketchup_kuechenplaner2](https://github.com/jimmycd/sketchup_kuechenplaner2).
* **Erweiterungen › Küchenplaner › Plugins aus Ordner laden…** nimmt den Stand aus einem lokalen Repo-Ordner (z. B. ein Klon oder ein entpacktes ZIP von GitHub). Der zuletzt gewählte Ordner wird gemerkt.

Ablauf:
1. Vergleicht jede Datei der Erweiterungen (`Komponenten/*/src`, `sketchup-tcn-export-plugin/src`, `kuechenplaner-update/src`, `kuechenplaner-symbolleiste/src`, also genau den Inhalt von `Kuechenplaner_alle.rbz`) mit dem Plugins-Ordner. Ist alles gleich, kommt nur „Alles aktuell“.
2. Fragt nach („Neue Version gefunden … Jetzt installieren?“) und nennt die betroffenen Erweiterungen.
3. Lädt nur die geänderten Dateien und prüft jede gegen ihre Git-Prüfsumme. Erst wenn alle stimmen, wird in den Plugins-Ordner geschrieben; bei einem Fehler bleibt alles, wie es war.
4. Lädt die geänderten Erweiterungen sofort neu (ausgeschaltete bleiben aus). Neue Komponenten werden registriert und geladen; ihr Menüeintrag erscheint sofort in ihrer Gruppe. Kommt ein Update von der alten, ungeordneten Menüversion, stehen die neuen Gruppen bis zum nächsten Start unter den alten Einträgen; nach einem Neustart ist das Menü sauber.

## Neu laden ohne Neustart (auch nach dem Extension Manager)

Jede Küchenplaner-Erweiterung bringt `kuechenplaner_gemeinsam/neuladen.rb` mit (Vorlage `gemeinsam/neuladen.rb`, verteilt von `./build_rbz.sh`). Darin steckt ein Wächter: Er prüft alle 2 Sekunden, ob sich Dateien der Küchenplaner-Erweiterungen im Plugins-Ordner geändert haben. Installiert man eine neue `.rbz` über den Extension Manager (oder kopiert Dateien von Hand), lädt er die geänderten Erweiterungen und die gemeinsamen Dateien neu, sobald die Installation fertig ist (zwei Prüfungen ohne weitere Änderung). Die Statuszeile zeigt „Küchenplaner: neu geladen: …“, ein Fenster kommt nur bei Fehlern; dann bleibt der alte Stand der betroffenen Erweiterung aktiv.

* **Erweiterungen › Küchenplaner › Küchenplaner neu laden** lädt alle eingeschalteten Küchenplaner-Erweiterungen sofort neu (z. B. nach einer Änderung von Hand).
* Bestehende Menüeinträge und Icons rufen nach dem Neuladen den neuen Code auf. Neue Einträge und Icons erscheinen sofort (am Ende ihres Menüs bzw. der Symbolleiste). Nur entfernen kann SketchUp Menüeinträge und Icons nicht: weggefallene stehen bis zum nächsten Start noch da.
* Ganz neue Erweiterungen registriert und lädt SketchUp beim Installieren selbst; ausgeschaltete bleiben aus.
* Einmalig: Ist noch eine Version ohne Wächter installiert, das erste Update über *Plugins aktualisieren* machen (lädt ohne Neustart neu) oder SketchUp nach dem Extension Manager einmal neu starten. Danach geht beides ohne Neustart.

Regeln für Erweiterungen, damit das klappt (Test `test/test_neuladen.rb`, `test/test_erweiterungen.rb`): `main.rb` darf mehrfach laufen (Menüs, Symbolleiste, Beobachter nur einmal anlegen, ihre Blöcke rufen Modul-Methoden auf), weitere eigene Dateien mit `load` statt `require` laden, Beobachter als gemerkte Instanz (`@beobachter ||= …`).

Ein Neustart von SketchUp ist nicht nötig. Bereits eingefügte Schränke im Modell bleiben unverändert; neu erzeugte nutzen den neuen Stand.

Test (ohne SketchUp, GitHub wird durch das Arbeitsverzeichnis ersetzt): `ruby kuechenplaner-update/test/test_update.rb`
