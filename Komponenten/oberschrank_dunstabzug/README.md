# Oberschrank Dunstabzug (Dynamic Component)

Oberschrank für eine **Flachschirmhaube**, die unten in den Schrank eingebaut wird. Das Abluftrohr geht nach oben durch Haubenboden und Deckel. Aufbau, Maße und Türen wie beim [Oberschrank](../oberschrank/README.md).

## Installieren und benutzen
1. SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `oberschrank_dunstabzug.rbz` wählen (oder `Kuechenplaner_alle.rbz` aus dem Hauptordner).
2. *Erweiterungen → Küchenplaner → Oberschränke → Oberschrank Dunstabzug…* (oder Symbolleiste *Schrank einfügen*) fragt Breite, Höhe und Tiefe ab (Vorschlag 600 × 700 × 400 mm) und baut den Schrank. Danach dockt er wie die anderen Schränke an.
3. Alles Weitere in den *Komponentenoptionen*.
4. *Küchenplaner → Geräte → Geräte in Schränke setzen* setzt eine Flachschirmhaube (Platzhalter) in den Haubenraum.

## Komponentenoptionen
| Option | Standard |
|---|---|
| Breite / Höhe / Tiefe (Korpus ohne Front) | 600 / 700 / 400 mm (900 breit für eine 90er-Haube) |
| Türen | eine Tür (Anschlag links) oder zwei Türen; Standard zwei |
| Haubenraum: Unterkante bis Haubenboden | 380 mm |
| Betrieb | Abluft (mit Rohrausschnitt) oder Umluft (kein Ausschnitt) |
| Rohrausschnitt: Breite / Tiefe | 170 / 170 mm (Rundrohr Ø150; für Flachkanal z. B. 222 × 89) |
| Rohrausschnitt: Abstand zur Rückwand | 20 mm (Hinterkante Ausschnitt bis Vorderseite Rückwand) |
| Einlegeboden über dem Haubenboden | 0 oder 1; Standard 0 |
| Türen unten frei (Blende Wrasenschirm) | 0 mm = Türen bis unten |

Feste Maße als Attribute (Fenster *Komponentenattribute*): `Materialstaerke_Korpus` 19 mm, `Materialstarke_Rueckwand` 8 mm, `Rueckwand_Versatz` 25 mm, `Nuttiefe` 9 mm, `Spaltbreite` 2 mm, `Rueckversatz_Einlegeboden` 10 mm, `Strebe_Hoehe` 80 mm.

## Aufbau
* Seiten über die volle Höhe und Tiefe. **Unten ist kein Boden**, dort sitzt die Haube.
* **Haubenboden** über die volle Tiefe, seine Unterseite liegt auf der Höhe des Haubenraums. Er ist das Teil `Boden` (Rolle Boden), denn die Rückwand steht in seiner Nut wie beim Oberschrank im Boden.
* **Rückwand** 8 mm nur vom Haubenboden bis oben, 25 mm vor der Hinterkante, in der Nut von Seiten und Haubenboden. Unter dem Haubenboden ist die Wand frei für die Montage der Haube.
* **Deckel** endet vor der Rückwand und wird mit ihr verschraubt (wie beim Oberschrank).
* **Strebe hinten unten**, hochkant 80 mm, hinten bündig mit den Seiten, damit der unten offene Korpus stabil bleibt.
* **Einlegeboden** (optional) in der Mitte des Fachs über dem Haubenboden, 10 mm von vorne zurückgesetzt.
* **Türen** wie beim Oberschrank (2 mm vor dem Korpus, Fugen 1 mm außen, 2 mm dazwischen). Mit *Türen unten frei* enden sie höher, dann bleibt die Blende des Wrasenschirms sichtbar.

## Rohrausschnitt
Rechteckig, mittig in der Breite, in **Haubenboden, Deckel und Einlegeboden** an derselben Stelle. Er steht als Attribute `Ausschnitt_X`, `Ausschnitt_Y`, `Ausschnitt_B`, `Ausschnitt_T` (Lage auf der Platte ab vorne links) an jeder Platte. In SketchUp ist die Platte voll gezeichnet, der Ausschnitt ist als Umriss knapp darüber zu sehen (Tags `<Kürzel>_Boden_Ausschnitt` usw.). Bei Umluft gibt es keinen Ausschnitt und keinen Umriss.

Der TCN-Export fräst ihn von oben als geschlossene Kontur mit dem Nutfräser 2200 (Ø 8,03 mm), innen an der Kante entlang, 1 mm tiefer als die Plattenstärke (wie der Rückwand-Ausschnitt im Spülenschrank). Die Ecken sind deshalb mit dem Fräserradius gerundet.

## Material und Kanten
Gezeichnet ist immer das **Endmaß**. Platten haben „Melamin weiss“, sichtbare Kanten „Anleimer Melamin weiss“ (2 mm, wird in Stückliste und Zuschnitt abgezogen).

| Teil | Kanten mit Anleimer |
|---|---|
| Seiten | vorne, unten, oben |
| Haubenboden, Deckel, Einlegeboden | vorne |
| Strebe hinten | unten (von unten sichtbar) |
| Rückwand | keine |
| Türen | alle vier |

## Tags
Jedes Teil hat einen eigenen Tag `<Kürzel>_<Teil>`: `OSD1_SeiteL`, `OSD1_SeiteR`, `OSD1_Boden` (Haubenboden), `OSD1_Deckel`, `OSD1_Rueckwand`, `OSD1_StrebeHinten`, `OSD1_Einlegeboden1`, `OSD1_Tuer` bzw. `OSD1_TuerL` und `OSD1_TuerR`. Das Kürzel ist `OSD1`, oder `OSD2` usw., wenn es im Modell schon vergeben ist.

Am Teil steht das Wörterbuch `JT_Schrank` mit `schrank`, `typ` (OberschrankDunstabzug), `kategorie` (Oberschrank), `bereich`, `teil` und `rolle`.

## Gerätenische
Am Schrank steht `JT_Nische` (`nische` DA, `geraet` z. B. `Flachschirmhaube60`, lichte Breite, Haubenraum als Höhe, Tiefe, Einfügepunkt vorne links an der Korpusvorderkante auf der Unterkante, dazu `abluft`, `rohr_x`, `rohr_y`, `rohr_breite`, `rohr_tiefe`, `schrank_hoehe`). Die Geräte-Erweiterung liest Breite, Haubenraum, Abluft und Rohr aus den aktuellen Komponentenoptionen.

## Hilfe in SketchUp
Eine Kurzfassung dieser Doku steht oben im Fenster *Komponentenoptionen* mit Link auf diese Seite (`HILFE` in `main.rb`).

## Tests
`ruby test/test_oberschrank_dunstabzug.rb` prüft ohne SketchUp (Mock-API und DC-Formel-Auswerter) Geometrie (kein Boden unten, Haubenboden, Rückwand in der Nut, Strebe, Türen mit freier Höhe unten, Einlegeboden), Rohrausschnitt und Umriss in allen Platten, Umluft, Formeln nach Umkonfigurieren, Tiefe nachträglich ändern, Material, Anleimer, Tags, `JT_Schrank`, `JT_Nische`, ungültige Maße und die Kurzhilfe. Den TCN-Export prüft `sketchup-tcn-export-plugin/test/test_export.rb`, die Haube `Komponenten/geraete/test/test_geraete.rb`.

Noch nicht in echtem SketchUp getestet.
