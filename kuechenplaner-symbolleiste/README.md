# Symbolleiste „Küchenplaner“

Erweiterung `kuechenplaner_symbolleiste.rbz` (steckt auch in `Kuechenplaner_alle.rbz`). Sie wird beim ersten Start eingeblendet; danach über *Ansicht › Symbolleisten › Küchenplaner* ein- und ausblenden.

| Icon | Befehl | Was passiert |
|---|---|---|
| ![](src/kuechenplaner_symbolleiste/icons/schrank.svg) | Schrank einfügen | Öffnet eine Auswahl aller Schranktypen, gegliedert nach Unter-, Ober- und Hochschränken. Klick auf einen Schrank: Maße abfragen, erzeugen und andocken, genau wie über das Menü. Esc schließt. |
| ![](src/kuechenplaner_symbolleiste/icons/andocken.svg) | Schrank andocken | Startet das Andock-Werkzeug für den gewählten Schrank. |
| ![](src/kuechenplaner_symbolleiste/icons/arbeitsplatte.svg) | Arbeitsplatte | Ist eine Arbeitsplatte gewählt, wird sie neu berechnet, sonst wird eine neue erzeugt. |
| ![](src/kuechenplaner_symbolleiste/icons/frontfarbe.svg) | Frontfarbe und Griffe | Dialog für Frontfarbe und Griffe. |
| ![](src/kuechenplaner_symbolleiste/icons/tcn.svg) | TCN exportieren | TCN-Export für TpaCAD. |

Seltene Befehle (Geräte in Schränke setzen, Szenen anlegen, Plugins aktualisieren) stehen nur im Menü *Erweiterungen › Küchenplaner*. Fehlt die Erweiterung zu einem Icon, ist es ausgegraut.

Neue Schränke erscheinen automatisch in der Auswahl, wenn sie sich mit `Kuechenplaner.schrank('<Gruppe>', '<Titel>…') { … }` ins Menü eintragen. Das Icon „Raum“ kommt dazu, sobald „Raum gestalten“ gebaut ist.

Icons: SVG unter Windows, PNG (32 px) auf dem Mac.

Test (ohne SketchUp): `ruby kuechenplaner-symbolleiste/test/test_symbolleiste.rb`
