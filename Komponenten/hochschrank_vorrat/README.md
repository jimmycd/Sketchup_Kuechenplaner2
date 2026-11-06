# Hochschrank Vorrat (Dynamic Component)

Vorrats-Hochschrank: außen eine Tür (ganz oder geteilt), dahinter unten Blum-LEGRABOX-Innenschubkästen mit Innenfront, oben Einlegeböden. Eine Alternative zum Apothekerschrank.

* **Zargenhöhe und Schiene (LEGRABOX free, MD-015/4):** Zarge **C** (177 mm, Holzrückwand 148 mm), wenn der Kasten Platz hat, sonst **M** (90,5 mm, Holzrückwand 62 mm). Platz: oberste Schublade bis 30 mm (`Kasten_Abstand_oben`) unter die Frontoberkante, darunter bis an die Frontoberkante (die Front deckt Zarge und Fronthalter ab). Die Schiene sitzt mindestens 38 mm über dem festen Boden darunter. Passt nicht einmal M, meldet der TCN-Export das. Die Beschläge dazu stehen auf der letzten Seite der Stückliste.

## Installieren und benutzen
1. SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `hochschrank_vorrat.rbz` wählen (oder `Kuechenplaner_alle.rbz` aus dem Hauptordner).
2. *Erweiterungen → Küchenplaner → Hochschränke → Hochschrank Vorrat…* (oder Symbolleiste *Schrank einfügen*) fragt Breite, Höhe und Tiefe ab (Vorschlag 600 × 2100 × 520 mm) und baut den Schrank. Danach dockt er an (siehe Schrank andocken). Alle Maße und Optionen bleiben in den *Komponentenoptionen* änderbar, auch die Tiefe.

## Komponentenoptionen
| Option | Werte | Standard |
|---|---|---|
| Breite, Höhe, Tiefe | frei | Dialog: 600 / 2100 / 520 mm |
| Tür | *Eine Tür (ganze Höhe)* oder *Geteilt (unten und oben)* | eine |
| Flügel | 1 oder 2 | 1, ab Breite über 600 mm 2 |
| Anschlag (ein Flügel) | links / rechts | links |
| Unten: Höhe Bereich | bis Oberkante Zwischenboden | 1000 mm |
| Unten: Anzahl Innenschubkästen | 2–6 | 4 |
| Unten: Anteil Kasten 1–6 | wie beim Hochschrank, Kasten 1 = oben | 1 |
| Oben: Anzahl Einlegeböden | 0–6 | 3 |
| Stärke Kastenboden, Höhenoffset Schiene | wie Hochschrank | 16 mm / 0 |
| Scharnier 1–6 | nur Anzeige: Höhe der Scharniermitte über Unterkante Schrank (0 = keins) | – |

Mit *Interagieren* öffnen die Türen nach außen und die Innenschubkästen fahren heraus.

## Aufbau
* Korpus wie der Hochschrank: Seiten über die volle Höhe, Boden, Deckel, Rückwand 8 mm, Korpus 19 mm, Fugen 2 mm. Ein **fester Zwischenboden** (Oberkante = Höhe Bereich unten) trennt die Kästen vom Fach oben.
* **Tür:** eine Tür von 0 bis zur Höhe, oder geteilt: unten bis 2 mm unter die Oberkante des Zwischenbodens, oben ab dort. Je Tür ein Flügel (Anschlag links oder rechts) oder zwei Flügel.
* **Innenschubkästen** (Blum LEGRABOX free, MD-015/4): Der Bereich unten wird über die Anteile in Fächer geteilt. Im Fach sitzt der Kasten 38 mm über dem Fachboden (ohne Lochraster, Schiene mind. 38 mm über dem Boden), höchste Zarge, die passt, oben bleiben **60 mm frei für das Scharnier** (`Freiraum_Scharnier`).
  * **Innenfront** 12 mm, 3 mm hinter der Korpusvorderkante, 2 mm Luft zu den Seiten, so hoch wie der Kasten. Material wie der Korpus; eine andere Farbe setzt *Frontfarbe und Griffe ändern… → Bereich „Nur Innenfronten“* (Innenfronten bekommen keine Griffbohrungen).
  * Kasten (Boden LW − 35 × NL − 10, 16 mm; Holzrückwand LW − 38 × höchstens 148 mm) beginnt 17 mm hinter der Korpusvorderkante (3 + 12 + 2 mm Fuge). Die Nennlänge NL folgt deshalb der Tiefe minus 17 mm.
* **Scharniere** (Blum, öffnen nach außen, so dass die Kästen herausfahren können): Sie sitzen in den Lücken über den Kästen, nie auf Höhe eines Kastens:
  1. über dem untersten Kasten,
  2. über dem mittleren Kasten (nur ganze Tür über 2 m Höhe mit mindestens 3 Kästen),
  3. über dem obersten Kasten, unter dem Zwischenboden,
  4. 100 mm über der Unterkante der oberen Tür (nur geteilt),
  5. im Fach oben zwischen zwei Einlegeböden,
  6. 100 mm unter der Oberkante.
  
  Eine ganze Tür hat damit 4 (über 2 m: 5) Scharniere, geteilt unten 2 und oben 3. Die Höhen stehen in den Komponentenoptionen (Scharnier 1–6) und am Schrank als `Scharnier_1` … `Scharnier_6` für den späteren Topfband-Export. Die Einlegeböden sind verstellbar; beim Umstecken darauf achten, dass sie nicht auf Scharnierhöhe liegen.
* Einlegeböden 10 mm von vorne zurückgesetzt, gleichmäßig im Fach oben verteilt.

## Material und Kanten
Gezeichnet ist immer das **Endmaß**. Platten haben das Material „Melamin weiss“ (Plattenwerkstoff, jetzt auch 12 mm), sichtbare Kanten „Anleimer Melamin weiss“ (2 mm). Beides nutzen Stückliste, Etiketten und Zuschnittplan des Schrank-CNC-Plugins.

| Teil | Kanten mit Anleimer |
|---|---|
| Seiten | vorne, oben |
| Boden, Deckel, Zwischenboden, Einlegeböden | vorne |
| Rückwand | links, rechts, oben |
| Türen, Innenfronten | alle vier |
| Kastenrückwand | oben |
| Kastenboden | keine |

## Tags
Jedes Teil hat einen eigenen Tag `<Kürzel>_<Bereich>_<Teil>`, z. B. `HV1_SeiteL`, `HV1_ZwischenbodenUnten`, `HV1_O_Einlegeboden2`, `HV1_U_Tuer` (unten bzw. ganze Tür), `HV1_O_TuerR`, `HV1_U2_Innenfront`, `HV1_U2_KastenBoden` (Kasten 1 = oben). Das Kürzel ist `HV1`, oder `HV2` usw., wenn es im Modell schon vergeben ist.

An jedem Teil steht `JT_Schrank` mit `schrank`, `typ` (Hochschrank Vorrat), `kategorie` (Hochschrank), `bereich`, `teil` und `rolle`. Neu in der gemeinsamen Rollen-Tabelle ist die Rolle **Innenfront**.

## TCN-Export (Plugin Schrank-CNC)
* Schienenbohrungen je Kasten in beiden Seiten, um 17 mm nach hinten versetzt (der Kasten beginnt hinter der Innenfront).
* Frontbefestigung in der Innenfront wie bei einer normalen Schubkastenfront.
* Lochreihen nur im Fach oben (zwischen Zwischenboden und Deckel), Dübel für Boden, Zwischenboden und Deckel, Sockelfüße im Boden.
* Topfbandbohrungen in Tür und Seite gibt es im Export noch nicht (kommt mit den Türen); die Höhen stehen schon in `Scharnier_1…6`.

## Hilfe in SketchUp
Eine Kurzfassung (ein Satz, `HILFE_KURZ` in `src/hochschrank_vorrat/main.rb`) steht oben im Fenster *Komponentenoptionen* und als Beschreibung der Komponente. Die ausführliche Doku steht nur hier, damit das Fenster ganz lesbar bleibt.

## Tests
`ruby test/test_hochschrank_vorrat.rb` prüft ohne SketchUp (Mock-API und DC-Formel-Auswerter) Türen (ganz/geteilt, Flügel, Anschlag), Kästen, Innenfront, Scharnierhöhen (keine Kollision mit Kästen, Böden und Einlegeböden, Anzahl je Tür), Kollisionen, Formeln nach dem Umkonfigurieren, nachträgliche Tiefenänderung, Material, Anleimer, Tags und die Kurzhilfe. Der Export wird in `sketchup-tcn-export-plugin/test/test_export.rb` geprüft.
