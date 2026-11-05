# Symbolleiste „Küchenplaner“

Erweiterung `kuechenplaner_symbolleiste.rbz` (steckt auch in `Kuechenplaner_alle.rbz`). Sie wird beim ersten Start eingeblendet; danach über *Ansicht › Symbolleisten › Küchenplaner* ein- und ausblenden.

| Icon | Befehl | Was passiert |
|---|---|---|
| ![](src/kuechenplaner_symbolleiste/icons/schrank.svg) | Schrank einfügen | Öffnet eine Auswahl aller Schranktypen, gegliedert nach Unter-, Ober- und Hochschränken. Klick auf einen Schrank: Maße abfragen, erzeugen und andocken, genau wie über das Menü. Esc schließt. |
| ![](src/kuechenplaner_symbolleiste/icons/andocken.svg) | Schrank andocken | Startet das Andock-Werkzeug für den gewählten Schrank. |
| ![](src/kuechenplaner_symbolleiste/icons/arbeitsplatte.svg) | Arbeitsplatte | Ist eine Arbeitsplatte gewählt, wird sie neu berechnet, sonst wird eine neue erzeugt. |
| ![](src/kuechenplaner_symbolleiste/icons/raum.svg) | Raum | Auswahl der Raum-Befehle: Raum anlegen, Wände aus Linien, Fenster/Tür einsetzen, Öffnung bearbeiten, Raum bearbeiten (Erweiterung [`Komponenten/raum/`](../Komponenten/raum/)). |
| ![](src/kuechenplaner_symbolleiste/icons/beschriftung.svg) | Schrank-Beschriftung | Schalter: zeigt bzw. verbirgt die Beschriftungen der Geräte und die Kürzel der Schränke (dieselben wie auf den Etiketten, z. B. US1, HS2) in den Szenen *Planung* und *Zuschnitt* als Text mit Pfeil auf die Front; in *Kunde* nie. Eingeschaltet ist das Icon gedrückt. Die Texte folgen dem Modell (verschieben, neues Kürzel, neuer/gelöschter Schrank). Szenen anlegen: *Geräte › Szenen Planung/Kunde/Zuschnitt anlegen*. |
| ![](src/kuechenplaner_symbolleiste/icons/frontfarbe.svg) | Frontfarbe und Griffe | Dialog für Frontfarbe und Griffe. |
| ![](src/kuechenplaner_symbolleiste/icons/tcn.svg) | TCN exportieren | TCN-Export für TpaCAD. |
| ![](src/kuechenplaner_symbolleiste/icons/stueckliste.svg) | Stückliste | Stückliste aller Teile (Fertig-, Fräs- und Rohmaß, Material, Kanten) als CSV/HTML. |
| ![](src/kuechenplaner_symbolleiste/icons/etiketten.svg) | Etiketten | Etiketten für die Teile drucken, Bogen A4 oder Endlos. |
| ![](src/kuechenplaner_symbolleiste/icons/zuschnitt.svg) | Zuschnittplan | Druckbarer Zuschnittplan je Platte für die Formatsäge. |
| ![](src/kuechenplaner_symbolleiste/icons/rendern.svg) | Rendern | Fotorealistisches Bild der Küche mit Blender (Cycles), Sichtbarkeit und Sonne wie Szene *Kunde*, Kamera wie Ansicht; siehe [Rendern](../sketchup-tcn-export-plugin/README.md#rendern-blender). |
| ![](src/kuechenplaner_symbolleiste/icons/materialien.svg) | Materialien | Material-Konfigurator wie im Menü *Materialien…*: Platten und Anleimer anlegen, bearbeiten, löschen; Maserrichtung. |
| ![](src/kuechenplaner_symbolleiste/icons/einstellungen.svg) | Einstellungen | Generelle Einstellungen wie im Menü *Einstellungen…*: oben Küche (Sockelhöhe, Wandabstand, Abstand Arbeitsplatte–Oberschrank), unten CNC (Übermaß, Zuschnitt). |

Seltene Befehle (Geräte in Schränke setzen, Szenen anlegen, Plugins aktualisieren) stehen nur im Menü *Erweiterungen › Küchenplaner*. Fehlt die Erweiterung zu einem Icon, ist es ausgegraut.

Neue Schränke erscheinen automatisch in der Auswahl, wenn sie sich mit `Kuechenplaner.schrank('<Gruppe>', '<Titel>…') { … }` ins Menü eintragen.

Icons: SVG unter Windows, PNG (32 px) auf dem Mac.

Test (ohne SketchUp): `ruby kuechenplaner-symbolleiste/test/test_symbolleiste.rb`
