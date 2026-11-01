# Raum gestalten

Baut den Küchenraum maßstäblich als Planungshilfe: **Wände**, **Fenster**, **Türen** und **Durchgänge**. Die Schränke docken mit dem Andock-Werkzeug an die Wände an und rasten in den Ecken und an den Türlaibungen ein.

Der Raum ist **kein Fertigungsteil**: kein Plattenmaterial, kein `JT_Schrank`, eigene Tags `Raum-Wand`, `Raum-Boden`, `Raum-Fenster`, `Raum-Tuer`, `Raum-Aufschlag`. Der TCN-Export übergeht ihn. Für OpenCutList die Szene **Zuschnitt** wählen (*Geräte › Szenen Planung/Kunde/Zuschnitt anlegen* blendet dort auch die Raum-Tags aus).

## Installieren
SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `raum.rbz` (oder `Kuechenplaner_alle.rbz` aus dem Hauptordner). Danach *Erweiterungen → Küchenplaner → Raum*.

## Befehle
| Befehl | was er tut |
|---|---|
| **Raum anlegen…** | Rechteckraum aus Innenmaßen (Vorschlag 4000 × 3000 mm, Höhe 2500, Wanddicke 240, Sockelhöhe 100). Ursprung = Innenecke vorne links. Wand 1 hinten, 2 rechts, 3 vorne, 4 links. |
| **Wände aus Linien…** | Grundriss vorher als Linien zeichnen (Innenkante der Wände = Aufmaß), Linien auswählen, Befehl wählen. Geschlossener Zug = ganzer Raum mit Boden, offener Zug = Wandreihe (z. B. L-Form; der Raum liegt auf der Innenseite des Knicks, bei einer einzelnen Wand auf der Seite, von der man schaut). Schräge Ecken werden auf Gehrung gebaut. |
| **Fenster/Tür einsetzen…** | Art und Maße wählen, dann hängt die Öffnung als rotes Rechteck an der Maus. Klick auf eine Wand setzt sie ein (10-mm-Raster). Exakt: über der Wand eine Zahl tippen und Enter, `850` = 850 mm von der linken Wandecke, `r850` = 850 mm von der rechten. Das Werkzeug bleibt aktiv für weitere Öffnungen, Esc beendet. |
| **Öffnung bearbeiten…** | Wand (oder den Raum) auswählen; Maße, Abstand von links ändern oder die Öffnung löschen. |
| **Raum bearbeiten…** | Raumhöhe, Wanddicke und Sockelhöhe ändern. |

Links/rechts gilt immer **aus dem Raum gesehen**. Die Wanddicke geht vom gezeichneten Grundriss **nach außen**, die Innenmaße bleiben also gleich.

Die Wände werden aus den gespeicherten Daten neu gebaut. Deshalb den Raum nur über diese Befehle ändern, nicht mit Push/Pull. Verschieben oder Drehen der ganzen Gruppe „Raum“ geht.

## Öffnungen
| Art | Maße (Vorschlag) | Darstellung |
|---|---|---|
| Fenster | Rohbau 1000 × 1200, Brüstung 950 ab Fußboden, Fensterbank innen ja/nein, Überstand 30 | Rahmen 60 × 70 mm in Wandmitte, Glas, Fensterbank 20 mm (Oberkante = Brüstung) |
| Tür | Rohbau 885 × 2010, Bänder links/rechts, öffnet nach innen/außen | Zarge 30 mm, Türblatt 40 mm, Aufschlag als Viertelkreis am Boden (Tag `Raum-Aufschlag`) |
| Durchgang | 1000 × 2010 | nur die Öffnung |

Regeln: Öffnungen mindestens 10 mm von Wandende, Decke und anderen Öffnungen; Wanddicke mindestens 100 mm; Fenster und Türen gehen nicht bis an die Decke. Was nicht passt, wird mit einer Meldung abgelehnt und nichts geändert.

## Zusammenspiel mit dem Andock-Werkzeug
Über einer Wand des Raums stellt das Andock-Werkzeug den Schrank mit der Rückseite an die Wand und zeigt den Abstand bis zu den Wandenden. Die linke Schrankseite rastet an der linken Wandecke und an der rechten Laibung von Türen/Durchgängen ein, die rechte Seite an der rechten Ecke und linken Laibungen (Fang 100 mm). Unter- und Hochschränke stehen auf dem Fußboden des Raums, die Korpusunterkante um die **Sockelhöhe** darüber (einstellbar beim Anlegen und unter *Raum bearbeiten…*, Vorschlag 100 mm, 0–300 mm), Oberschränke behalten ihre Höhe.

## Technik
Gruppe „Raum“ mit Wörterbuch `JT_Raum` (`typ` = Raum, `daten` = JSON mit Grundriss, Höhe, Dicke, Öffnungen in mm). Jede Wand ist eine Komponente mit dem Koordinatensystem eines Schranks: x entlang der Wand (links → rechts aus dem Raum), y in die Wand hinein, z nach oben ab Fußboden. Die Wand-Instanz trägt `typ` = Wand, `wand`, `laenge`, `kanten_links`, `kanten_rechts`, `sockel` (mm).

Test: `ruby test/test_raum.rb` (ohne SketchUp; prüft u. a. dass jede Wand eine geschlossene Hülle mit dem richtigen Volumen ist).

## Geplant
Stufe 2: Nischen, Vorsprünge/Schächte, Säulen, Dachschrägen. Stufe 3: *Raum prüfen* (Brüstung über Arbeitsplatte, Aufschläge, Schränke unter der Schräge), Installationen.
