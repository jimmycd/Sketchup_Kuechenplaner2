# Geräte (Planung und Kundenrendering)

Setzt Geräte in die Nischen der Spezialschränke: **Geschirrspüler**, **Kühlschrank/Weinkühler**, **Kochfeld mit Abzug**, **Kochfeld** (ohne Abzug), **Spüle mit Armatur**, **Backofen**, **Kompaktgerät**, **Mikrowelle**, **Wärmeschublade** und **Flachschirmhaube**. Die Geräte werden selbst erzeugt (keine Herstellermodelle) und sind schlicht gehalten, damit das Modell leicht bleibt.

Geräte sind **keine Schrankteile**: kein Plattenmaterial, kein `JT_Schrank`, keine Teil-Tags. Der TCN-Export übergeht sie. Für Stückliste und Etiketten die Szene **Zuschnitt** wählen (oder die Tags `Geraete_Plan` und `Geraete_Render` ausblenden), sonst listet die Stückliste die Geräteteile mit.

## Installieren und benutzen
1. SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `geraete.rbz` wählen (oder `Kuechenplaner_alle.rbz` aus dem Hauptordner).
2. Schränke wie gewohnt erzeugen und einstellen.
3. *Erweiterungen → Küchenplaner → Geräte → Geräte in Schränke setzen*: setzt in alle gewählten Schränke (ohne Auswahl: in alle Schränke des Modells) das passende Gerät. Die alten Platzhalter der Schränke werden ausgeblendet.
4. Nach einer Änderung am Schrank (Breite, Gerätewahl …) den Befehl einfach erneut ausführen; vorhandene Geräte werden ersetzt.
5. *Erweiterungen → Küchenplaner → Geräte → Geräte entfernen*: nimmt die eingesetzten Geräte wieder heraus. Ohne Auswahl alle Geräte des Modells, mit gewählten Schränken nur deren Geräte, mit einem gewählten Gerät (im geöffneten Schrank anklicken) nur dieses eine. Korpus, Nischen und TCN-Export bleiben unverändert; sobald ein Schrank kein Gerät mehr hat, sind seine alten Platzhalter wieder sichtbar. Wieder einsetzen mit Schritt 3. Die nicht mehr benutzten Gerätedefinitionen räumt *Fenster → Modellinformationen → Statistik → Nicht verwendete Elemente löschen* auf.
6. *Erweiterungen → Küchenplaner → Geräte → Szenen Planung/Kunde/Zuschnitt anlegen*: legt drei Szenen an (oder aktualisiert sie).

| Szene | `Geraete_Plan` | `Geraete_Render` | wofür |
|---|---|---|---|
| Planung | an | aus | Gerätemodell mit Beschriftung (Gerät und Nischenmaß) |
| Kunde | aus | an | Rendering: Schwarzglas, Edelstahl, Gehäuse |
| Zuschnitt | aus | aus | Stückliste/Etiketten, keine Geräte |

In der Planung steht das Gerät selbst in der Nische (kein farbiger Kasten mehr: der sah aus wie eine leere Nische), dazu die Beschriftung mit Nischenmaß. Die Beschriftung liegt auf dem Tag „Beschriftung“: der Schalter *Schrank-Beschriftung* in der Symbolleiste blendet sie zusammen mit den Schrank-Kürzeln ein und aus (Planung/Zuschnitt). Ältere Modelle: „Geräte in Schränke setzen“ erneut ausführen.

### Kundensicht (Szene „Kunde“)
Beim Anlegen/Aktualisieren der Szenen bekommt die Szene **Kunde** ihren eigenen Darstellungsstil (`src/geraete/kundensicht.rb`). Planung und Zuschnitt bleiben, wie sie sind.

| | Kunde |
|---|---|
| Flächen | schattiert mit Texturen (Materialien aus dem Material-Konfigurator), keine Farbe nach Tag |
| Kanten | dezent hellgrau, keine Profile, keine Silhouetten, keine verlängerten Linien |
| ausgeblendet | Texte (Beschriftungen), Bemaßungen, Achsen, Schnittebenen, Hilfslinien |
| Hintergrund | warmes Hellgrau mit Himmel und Boden |
| Schatten | an, Sonne am 21. Juni 12:30, hell 80 / dunkel 50 |
| Kamera | Perspektive (40°); neue Szene: aktuelle Ansicht, vorhandene Szene: ihre gespeicherte Kamera bleibt |

Den Blickwinkel stellt man wie gewohnt ein und speichert ihn mit Rechtsklick auf den Szenen-Reiter **Kunde › Aktualisieren**. Erneutes Anlegen legt keine zweite Kunden-Szene an, sondern aktualisiert den Stil.

**Kundenbild speichern…** (*Erweiterungen → Küchenplaner → Geräte*): wechselt ohne Überblendung in die Szene Kunde (legt die Szenen an, falls es sie noch nicht gibt) und speichert ein PNG: Full HD, QHD, 4K, A4 quer 300 dpi oder Fenstergröße, mit oder ohne Kantenglättung. Weicht das Seitenverhältnis vom Fenster ab, zeigt das Bild etwas mehr Umgebung.

## Welcher Schrank bekommt welches Gerät
| Schrank | Nische | Gerät |
|---|---|---|
| Unterschrank Geschirrspüler | `JT_Nische` (N1) | vollintegrierter Spüler 45/60; die Möbelfront bleibt beim Schrank. Der Gerätesockel springt zurück und beginnt 85 mm hinter der Korpusvorderkante, hinter der Sockelblende (wie die Füße der Unterbau-Kühlgeräte) |
| Unterschrank Kochfeld mit Abzug | `JT_Nische` (KF) | Kochfeld 60/80/90 × 520 mm mittig über dem Arbeitsplatten-Ausschnitt (Stärke aus der Arbeitsplatte, sonst 38 mm), Abzugsgitter in der Mitte, Lüftermodul unter der Platte, Kanal im Installationsraum |
| Unterschrank Backofen (Herdumbau) | `JT_Nische_KF`, `JT_Nische_N1` | Kochfeld 60/80/90 ohne Abzug (Glas 590/790/890 × 520 mm mittig über dem Arbeitsplatten-Ausschnitt, Wanne 50 mm darunter) und Backofen 60 auf dem Einbauboden |
| Unterschrank Kühlschrank | `JT_Nische` (N1), Gerät/Breite/Wange/Sockel aus den aktuellen Komponentenoptionen | Kühlschrank integriert (Gehäuse und Gerätetür, die Möbelfront bleibt beim Schrank), Kühlschrank unterbaufähig (Edelstahltür mit Griff), Weinkühler (Glastür im schwarzen Rahmen), 30/45/60 |
| Spülenschrank | aus den Schrankmaßen (kein `JT_Nische`) | Edelstahlspüle mit einem Becken und Armatur im Arbeitsplatten-Ausschnitt: Rand rundum 10 mm auf der Platte, Becken im Ausschnitt |
| Oberschrank Dunstabzug | `JT_Nische` (DA), Breite, Haubenraum, Abluft und Rohr aus den aktuellen Komponentenoptionen | Flachschirmhaube 60/90 unten bündig im Haubenraum: Wrasenschirm, Filterwanne, Lüfterbaustein; bei Abluft das Rohr durch den Ausschnitt bis zur Oberkante des Schranks |
| Hochschrank Geräte | `JT_Nische_N1`, `JT_Nische_N2` | Backofen 60 (Front 595 × 595), Kompaktgerät 45 (595 × 455), Mikrowelle 38 (595 × 382), Wärmeschublade 14 (595 × 140); „frei“ bleibt leer |
| Hochschrank Kühlschrank | `JT_Nische_N1` | Einbau-Kühlgerät (`Kuehlgeraet178` usw.): Gehäuse und Gerätetür hinter der Möbeltür des Schranks, Höhe = Nischenhöhe |

Einbaugeräte haben eine 595 mm breite Front, mittig über der Nische und bündig mit den Möbelfronten (2 mm vor der Korpusvorderkante); das Gehäuse steckt in der Nische.

## Schnittstelle für neue Schränke
Ein Schrank mit Gerätenische legt an seiner Definition ein Wörterbuch `JT_Nische` an (mehrere Nischen: `JT_Nische_N1`, `JT_Nische_N2` …):

| Schlüssel | Inhalt |
|---|---|
| `nische` | Name der Nische (N1, N2, KF …), wird zum Instanznamen `Geraet_<nische>` |
| `geraet` | Kennung, z. B. `Backofen60`, `Kompakt45`, `Mikrowelle38`, `Waermeschublade14`, `Geschirrspueler60`, `Kuehlschrank60`, `KuehlschrankFrei60`, `Weinkuehler30`, `KochfeldAbzug80`, `Kochfeld60`, `Spuele`, `Flachschirmhaube60`; `frei`/`keine` = kein Gerät |
| `breite`, `hoehe`, `tiefe` | lichte Maße in mm |
| `x`, `y`, `z` | Einfügepunkt in mm relativ zum Schrankursprung: vorne links an der Korpusvorderkante, auf dem Einbauboden (Spüler: Fußboden, Kochfeld: Korpusoberkante, Haube: Unterkante des Oberschranks) |
| optional | `arbeitsplatte`, `installationstiefe`, `kanal_breite`, `kanal_x` (Kochfeld); `abluft`, `rohr_x`, `rohr_y`, `rohr_breite`, `rohr_tiefe`, `schrank_hoehe` (Haube) |

Die Werte sind der Stand beim Erzeugen des Schranks. Jedes Gerät trägt das Wörterbuch `JT_Geraet` (`geraet`, `nische`, `schrank`, `text`).

## Tests
`ruby test/test_geraete.rb` (ohne SketchUp, mit Mock-API) erzeugt die echten Schränke Spüler, Kochfeld, Spüle, Hochschrank Geräte, Herdumbauschrank und Oberschrank Dunstabzug, setzt und entfernt die Geräte und prüft Lage, Maße, Tags, Szenen, dass kein Geräteteil `JT_Schrank` oder Material trägt und dass der TCN-Export die Geräte übergeht.

**Noch nicht in echtem SketchUp geprüft.**

## Spüle und Kochfeld im Arbeitsplatten-Ausschnitt

Der Ausschnitt der Arbeitsplatte ist maßgebend (er geht in den TCN-Export), das Gerät richtet sich danach:

- Liegt im Modell eine Arbeitsplatte mit Ausschnitt über dem Schrank, sitzen Spüle und Kochfeld genau darin; die Plattenstärke kommt ebenfalls von dort.
- Ohne Arbeitsplatte gelten dieselben Richtwerte wie beim Erzeugen der Arbeitsplatte (Überstand vorn 20 mm, Spüle 60 mm und Kochfeld 50 mm hinter der Plattenvorderkante, Schichtstoff 38 mm).
- „Arbeitsplatte erzeugen…“ und „neu berechnen“ setzen schon eingesetzte Spülen und Kochfelder automatisch neu, damit sie dem Ausschnitt folgen.
