# Eck-Unterschrank (Dynamic Component)

Zwei Bauformen für die Ecke einer Küchenzeile:

* **Blindeck:** gerader Korpus wie der Unterschrank mit Tür. Ein Teil der Breite (Blindteil) steckt hinter der Nachbarzeile und ist mit einer festen Blende zu. Im Türbereich wahlweise **eine Tür**, **zwei Türen** oder **Le Mans** (Schwenkauszug Kesseböhmer LeMans II mit 2 Tablaren).
* **L-Form:** L-förmiger Korpus mit zwei Schenkeln und **Falttür** (zwei Türen, mit einem Blum-Standardscharnier verbunden).

## Installieren und benutzen
1. SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `eckschrank.rbz` wählen (oder `Kuechenplaner_alle.rbz` aus dem Hauptordner für alle Komponenten auf einmal).
2. *Erweiterungen → Küchenplaner → Unterschränke → Eckschrank Blindeck…* fragt alle Werte der Komponentenoptionen ab (Breite, Höhe, Tiefe, Variante, Blindseite, Türbreite, LeMans-Größe, Einlegeböden, Passleiste, Nachbarschrank Wand bis Front) und baut dann den Schrank. Ungültige Kombinationen (Türbreite ≥ Breite, LeMans-Korpus zu schmal) meldet das Fenster, ohne zu schließen. Alles bleibt danach in den *Komponentenoptionen* änderbar.
3. *Erweiterungen → Küchenplaner → Unterschränke → Eckschrank L-Form…* fragt Schenkel A, Schenkel B, Höhe, Tiefe und Anzahl Einlegeböden ab und baut dann den Schrank. Alle Maße lassen sich danach im Fenster *Komponentenoptionen* ändern (siehe unten).

Wer eine fertige `.skp` für die Komponenten-Bibliothek möchte: Rechtsklick auf den Schrank → *Speichern unter…*.

## Blindeck: Komponentenoptionen
| Option | Standard |
|---|---|
| Variante | eine Tür, zwei Türen oder Le Mans; Standard eine Tür |
| Blindseite | links (Tür rechts) oder rechts (Tür links); Standard links |
| Breite / Höhe / Tiefe (Korpus ohne Front/Rückwand) | 1000 / 700 / 560 mm |
| Türbreite (eine oder zwei Türen zusammen, mit Fugen) | 500 mm |
| LeMans-Größe (nur Variante Le Mans) = Türbreite | LeMans 40, 45, 50 oder 60; Standard 50 |
| Anzahl Einlegeböden (nicht bei Le Mans) | 0–2, gleichmäßig verteilt; Standard 1 |
| Nachbarschrank: Wand bis Front | 589 mm (8 + 560 + 19 + 2) |
| Passleiste (sichtbare Blende neben der Tür) | 50 mm |
| Abstand Blindseite zur Wand (nur Anzeige) | Nachbar + Passleiste − (Breite − Türbereich), Standard 139 mm |

Die Tiefe ist 560 mm (wie die Seiten in Jürgens Beispiel-TCN), nicht 800 mm wie beim Unterschrank mit Tür: mit 800 mm hätte eine L-Form 900 × 900 keinen Innenraum.

**Abstand zur Wand:** Der Nachbarschrank steht vor dem Blindteil. Damit neben der Tür noch die Passleiste frei bleibt (Platz für Front und Griff des Nachbarn), muss die Blindseite so weit von der Seitenwand wegbleiben. Die Komponente rechnet das aus; die Lücke verdeckt der Nachbarschrank. Eine eigene Passleiste wird nicht gezeichnet: Der Nachbarschrank schließt die Ecke mit seiner Seite, sichtbar bleibt der Streifen der Blende.

Feste Maße als Attribute (Fenster *Komponentenattribute*): `Materialstaerke_Korpus` 19 mm, `Materialstarke_Rueckwand` 8 mm, `BreiteStreben` 100 mm, `Spaltbreite` 2 mm, `Rueckversatz_Einlegeboden` 10 mm.

Mit *Interagieren* öffnen sich die Türen (um die Außenkante an der offenen Seite bzw. links/rechts bei zwei Türen).

### Aufbau Blindeck
* **Korpus** wie beim Unterschrank mit Tür: Seiten über die volle Höhe und Tiefe, Boden zwischen den Seiten, oben Strebe vorn und hinten (100 mm, liegend), Rückwand hinter dem Korpus. Der Korpus beginnt bei y = 19 mm, die Fronten liegen 2 mm davor.
* **Blende** über dem Blindteil, volle Höhe, Breite = Breite − Türbereich − 2 mm. Sie hat die Rolle Front (Frontfarbe ändert sie mit), bekommt aber keinen Griff und keine Bohrungen (Befestigung mit Winkeln).
* **Türen** im Türbereich an der offenen Seite: eine Tür = Türbereich − 2 mm; zwei Türen je Türbereich/2 − 2 mm. Außen 1 mm Fuge, zwischen Blende und Tür bzw. zwischen zwei Türen 2 mm.
* **Le Mans:** Türbreite = LeMans-Größe (z. B. LeMans 50 = Tür 500 mm). Der Beschlag ist als Platzhalter gezeichnet (Tag `<Kürzel>_LeMans`): Einbauraum von der Innenseite der Seite an der Tür bis zum Säulenlager (X = 426/476/526/626 mm), bis 500 mm tief, vom Boden bis unter die Streben. Er hat das Material „Kesseböhmer LeMans II“ (Typ *Beschlag*) und kein `JT_Schrank`; der TCN-Export übergeht ihn. Einlegeböden entfallen. Laut Kesseböhmer braucht der Korpus mindestens 764/800/910/960 mm Breite (LeMans 40/45/50/60), 500 mm Tiefe, Seiten ab 16 mm und eine obere Strebe ab 60 mm; die Tür muss aufschlagen (Vollanschlag).

## L-Form
| Option | Standard |
|---|---|
| Schenkel A (entlang der hinteren Wand, außen) | 900 mm |
| Schenkel B (entlang der linken Wand, außen) | 900 mm |
| Tiefe (Korpus ohne Front/Rückwand) | 560 mm |
| Höhe | 700 mm |
| Anzahl Einlegeböden | 0–2; Standard 1 |

**Schenkel und Tiefe ändern:** Eine Dynamic Component ändert Maße, indem sie Teile skaliert; eine L-Platte würde dabei verzerrt (die Innenecke wanderte mit). Deshalb baut die Erweiterung den Schrank neu auf, sobald sich Schenkel A, Schenkel B oder Tiefe in den Komponentenoptionen ändern (ein Beobachter prüft nach jedem Vorgang, `Eckschrank.l_pruefen`). Kürzel, Lage, Höhe, Einlegeböden, Frontmaterial und Griffe bleiben; ein Rückgängig nimmt Änderung und Neuaufbau zusammen zurück. Ungültige Maße (Schenkel A und B innen vor der Ecke unter 150 mm) werden mit einer Meldung abgelehnt, die alten Maße bleiben. Das klappt nur, wenn die Erweiterung geladen ist; ohne sie bleibt der Schrank beim Ändern dieser drei Werte unverändert.

### Aufbau L-Form
* Draufsicht: Schenkel A an der hinteren Wand, Schenkel B an der linken Wand, nach vorne herausragend. Die Innenecke liegt an der Korpusvorderkante beider Schenkel.
* **Seiten** an den Enden der Schenkel (`SeiteR` am Ende von A, `SeiteL` am Ende von B).
* **Boden** und **Einlegeböden** sind je **eine L-Platte** (in SketchUp als L gezeichnet, Endmaß). Die Einlegeböden sind an beiden Vorderkanten 10 mm zurückgesetzt und liegen auf Bodenträgern in den Lochreihen der Seiten; hinten in der Ecke bei Bedarf eine Auflageleiste.
* **Streben** oben, liegend (nach Jürgens Skizze): die vordere Strebe von A (`StrebeVorn1`) läuft durch die Ecke bis an die Rückwand von B; die vordere Strebe von B (`StrebeVorn2`) stößt mit dem Ende an sie. Hinten liegt eine Strebe über die ganze Länge von A an der Wand (`StrebeHinten`); Schenkel B hat hinten keine Strebe.
* **Rückwände:** `Rueckwand1` hinter A geht durch die Ecke, `Rueckwand2` hinter B stößt daran.
* **Falttür:** `TuerR` vor Schenkel A läuft durch die Ecke, `TuerL` vor Schenkel B endet 1 mm vor der Front von A. Beide sind mit einem Blum-Standardscharnier verbunden; die Tür an der Seite hängt an Topfbändern (Bohrungen folgen mit den Türen im TCN-Export).
* **Öffnen mit Interagieren** (Klick auf eine der beiden Türen), nacheinander in fester Reihenfolge, damit sich die Türen nicht durchdringen:
  1. Klick: die kürzere Tür klappt am Eckscharnier vor die längere (90°).
  2. Klick: beide zusammen schwenken um das Scharnier an der Seite auf (100°).
  3. Klick: zurück an den Korpus. 4. Klick: die kürzere Tür klappt wieder auf, die Falttür ist zu.

  Am Korpus hängt die längere Tür: bei Schenkel A ≥ Schenkel B Tür A (`TuerR`, Scharnier an `SeiteR`), sonst Tür B (`TuerL`, Scharnier an `SeiteL`). Im zweiten Fall streift beim Klappen die hintere Kante vom Ende der Tür A in der Animation bis zu 7 mm die Korpusvorderkante (das reale Scharnier führt die Tür anders). Aufbau: Halter `FaltHalter` am Korpusscharnier mit der langen Tür und `FaltHalterInnen` am Eckscharnier mit der kurzen Tür; das onClick sitzt am `FaltHalter`. Der Test spielt die vier Klicks durch und prüft in kleinen Schritten, dass sich die Türen nicht berühren und nicht in den Korpus fahren. Ältere L-Schränke bekommen das Öffnen, sobald Schenkel oder Tiefe einmal geändert (neu aufgebaut) werden oder der Schrank neu angelegt wird.

## Material und Anleimer
Gezeichnet ist immer das **Endmaß**. Anleimer werden nur als Material zugewiesen: Kantenflächen mit dem Material „Anleimer Melamin weiss“ (Typ *Kante*, 2 mm, „Kantenstärke abziehen“ an). Platten haben „Melamin weiss“ (*Plattenwerkstoff*).

| Teil | Kanten mit Anleimer |
|---|---|
| Seiten, Boden, Strebe vorn, Einlegeböden (Blindeck) | vorne |
| Strebe hinten, Rückwand | keine |
| Türen, Blende | alle vier |
| L-Boden, L-Einlegeböden | keine in der Stückliste (siehe unten) |

**L-Platten:** Stückliste und Zuschnitt rechnen mit dem umschließenden Rechteck (Zuschnitt) und erkennt Anleimer nur an dessen Außenseiten. Die Kanten der Innenecke bekommen trotzdem einen Anleimer; der TCN-Export fräst sie dafür 2 mm zurück. In der Stückliste steht bei diesen Platten deshalb kein Anleimer.

## Tags
Jedes Teil hat den Tag `<Kürzel>_<Teil>`:
* Blindeck: `UES1_SeiteL`, `UES1_SeiteR`, `UES1_Boden`, `UES1_StrebeVorn`, `UES1_StrebeHinten`, `UES1_Rueckwand`, `UES1_Einlegeboden1`/`2`, `UES1_Blende`, `UES1_Tuer` (eine Tür, auch Le Mans), `UES1_TuerL`/`UES1_TuerR` (zwei Türen), `UES1_LeMans` (Platzhalter Beschlag).
* L-Form: `UES1_SeiteL`, `UES1_SeiteR`, `UES1_Boden`, `UES1_StrebeVorn1`/`2`, `UES1_StrebeHinten`, `UES1_Rueckwand1`/`2`, `UES1_Einlegeboden1`/`2`, `UES1_TuerL`, `UES1_TuerR`.

Das Kürzel ist `UES1`, oder `UES2` usw., wenn es im Modell schon vergeben ist. An jedem Teil steht das Wörterbuch `JT_Schrank` mit `schrank`, `typ` (Eckschrank), `kategorie` (Unterschrank), `bereich`, `teil` und `rolle`. Die Blende hat die Rolle `Front`.

## TCN-Export (Plugin Schrank-CNC)
* Korpus wie beim Unterschrank: Dübel Boden und Streben an die Seiten, Schrauben in die Streben, Sockelfüße, Lochreihen für Einlegeböden. Blende nur formatieren.
* **Le Mans** (nach der Kesseböhmer-Montageanleitung, S. 3 und 11): Säulenlager in Boden und Strebe vorn bei X ab der Innenseite der Seite an der Tür, Ø5 für die Systemschraube Ø6,3 69 mm ab Vorderkante und 2 × Ø3 für Holzschrauben Ø4,5 (Annahme: vorgebohrt) 16 mm daneben auf 37 mm. Im Boden von unten durchgebohrt (oben wäre Fläche 2), in der Strebe von unten. Seitenprofil 500: 8 × Ø5, 13 tief, 52 mm ab Vorderkante, unterstes 28 mm über dem Boden, Raster 64. Keine Lochreihen. Hinweis, wenn der Korpus für die gewählte LeMans-Größe zu schmal oder zu flach ist. **Die Maße einmal mit der mitgelieferten Bohrschablone an einem Probeteil prüfen.**
* **L-Form:** Innenecke von Boden und Einlegeböden als Kontur mit dem Nutfräser durch die Platte; Sockelfüße je Schenkel (auch an der Innenecke); Dübel am Stoß der vorderen Streben in der Ecke.
* Topfbänder (auch das Scharnier der Falttür) kommen mit den Türen im TCN-Export.

## Hilfe in SketchUp
Eine Kurzfassung (ein Satz, `HILFE_KURZ` in `src/eckschrank/main.rb`) steht oben im Fenster *Komponentenoptionen* und als Beschreibung der Komponente. Die ausführliche Doku steht nur hier, damit das Fenster ganz lesbar bleibt.

## Tests
`ruby test/test_eckschrank.rb` – prüft ohne SketchUp (Mock-API und DC-Formel-Auswerter) alle Blindeck-Varianten mit beiden Blindseiten und Umschalten über die Komponentenoptionen (Lage von Blende, Türen und Drehpunkten, Einlegeböden, Le-Mans-Platzhalter, Abstand zur Wand), die L-Form (Innenecke, Streben, Rückwände, Falttür, Einlegeböden, Höhe ändern), Material, Anleimer, Tags, `JT_Schrank` und die Kurzhilfe. Den TCN-Export prüft `sketchup-tcn-export-plugin/test/test_export.rb`. In echtem SketchUp ist die Komponente noch nicht getestet.
