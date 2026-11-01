# Geräte (Planung und Kundenrendering)

Setzt Geräte in die Nischen der Spezialschränke: **Geschirrspüler**, **Kochfeld mit Abzug**, **Spüle mit Armatur**, **Backofen**, **Kompaktgerät**, **Mikrowelle** und **Wärmeschublade**. Die Geräte werden selbst erzeugt (keine Herstellermodelle) und sind schlicht gehalten, damit das Modell leicht bleibt.

Geräte sind **keine Schrankteile**: kein Plattenmaterial, kein `JT_Schrank`, keine Teil-Tags. Der TCN-Export übergeht sie. Für OpenCutList die Szene **Zuschnitt** wählen (oder die Tags `Geraete_Plan` und `Geraete_Render` ausblenden), sonst listet OCL die Geräteteile mit.

## Installieren und benutzen
1. SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `geraete.rbz` wählen (oder `Kuechenplaner_alle.rbz` aus dem Hauptordner).
2. Schränke wie gewohnt erzeugen und einstellen.
3. *Erweiterungen → Küchenplaner → Geräte → Geräte in Schränke setzen*: setzt in alle gewählten Schränke (ohne Auswahl: in alle Schränke des Modells) das passende Gerät. Die alten Platzhalter der Schränke werden ausgeblendet.
4. Nach einer Änderung am Schrank (Breite, Gerätewahl …) den Befehl einfach erneut ausführen; vorhandene Geräte werden ersetzt.
5. *Erweiterungen → Küchenplaner → Geräte → Szenen Planung/Kunde/Zuschnitt anlegen*: legt drei Szenen an (oder aktualisiert sie).

| Szene | `Geraete_Plan` | `Geraete_Render` | wofür |
|---|---|---|---|
| Planung | an | aus | farbige, halbtransparente Blöcke mit Beschriftung (Gerät und Nischenmaß) |
| Kunde | aus | an | Rendering: Schwarzglas, Edelstahl, Gehäuse |
| Zuschnitt | aus | aus | OpenCutList, keine Geräte |

Farben im Planblock: orange = Kochen (Backofen, Kompakt, Kochfeld), türkis = Wasser (Spüler, Spüle), blau = sonstige (Mikrowelle, Wärmeschublade).

## Welcher Schrank bekommt welches Gerät
| Schrank | Nische | Gerät |
|---|---|---|
| Unterschrank Geschirrspüler | `JT_Nische` (N1) | vollintegrierter Spüler 45/60; die Möbelfront bleibt beim Schrank |
| Unterschrank Kochfeld mit Abzug | `JT_Nische` (KF) | Kochfeld 60/80/90 × 520 mm auf der Arbeitsplatte (Stärke aus der Nische, sonst 40 mm), Abzugsgitter in der Mitte, Lüftermodul unter der Platte, Kanal im Installationsraum |
| Spülenschrank | aus den Schrankmaßen (kein `JT_Nische`) | Edelstahlspüle mit einem Becken (höchstens 860 × 500 mm) und Armatur, Arbeitsplatte 40 mm |
| Hochschrank Geräte | `JT_Nische_N1`, `JT_Nische_N2` | Backofen 60 (Front 595 × 595), Kompaktgerät 45 (595 × 455), Mikrowelle 38 (595 × 382), Wärmeschublade 14 (595 × 140); „frei“ bleibt leer |

Einbaugeräte haben eine 595 mm breite Front, mittig über der Nische und bündig mit den Möbelfronten (2 mm vor der Korpusvorderkante); das Gehäuse steckt in der Nische.

## Schnittstelle für neue Schränke
Ein Schrank mit Gerätenische legt an seiner Definition ein Wörterbuch `JT_Nische` an (mehrere Nischen: `JT_Nische_N1`, `JT_Nische_N2` …):

| Schlüssel | Inhalt |
|---|---|
| `nische` | Name der Nische (N1, N2, KF …), wird zum Instanznamen `Geraet_<nische>` |
| `geraet` | Kennung, z. B. `Backofen60`, `Kompakt45`, `Mikrowelle38`, `Waermeschublade14`, `Geschirrspueler60`, `KochfeldAbzug80`, `Spuele`; `frei`/`keine` = kein Gerät |
| `breite`, `hoehe`, `tiefe` | lichte Maße in mm |
| `x`, `y`, `z` | Einfügepunkt in mm relativ zum Schrankursprung: vorne links an der Korpusvorderkante, auf dem Einbauboden (Spüler: Fußboden, Kochfeld: Korpusoberkante) |
| optional | `arbeitsplatte`, `installationstiefe`, `kanal_breite`, `kanal_x` (Kochfeld) |

Die Werte sind der Stand beim Erzeugen des Schranks. Jedes Gerät trägt das Wörterbuch `JT_Geraet` (`geraet`, `nische`, `schrank`, `text`).

## Tests
`ruby test/test_geraete.rb` (ohne SketchUp, mit Mock-API) erzeugt die echten Schränke Spüler, Kochfeld, Spüle und Hochschrank Geräte, setzt die Geräte und prüft Lage, Maße, Tags, Szenen, dass kein Geräteteil `JT_Schrank` oder OCL-Material trägt und dass der TCN-Export die Geräte übergeht.

**Noch nicht in echtem SketchUp geprüft.**
