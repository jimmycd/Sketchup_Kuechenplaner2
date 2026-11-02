# Unterschrank Mülltrennung (Dynamic Component)

Unterschrank mit einem Müllauszug: Die Front fährt mit einem Blum-LEGRABOX-Kasten heraus, darin stehen 1–4 Abfallbehälter. Wahlweise sitzt darüber eine Schublade.

## Installieren und benutzen
1. SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `unterschrank_abfall.rbz` wählen (oder `Kuechenplaner_alle.rbz` aus dem Hauptordner für alle Komponenten auf einmal).
2. *Erweiterungen → Küchenplaner → Unterschränke → Unterschrank Mülltrennung…* (oder Symbolleiste *Schrank einfügen*) fragt Breite, Höhe und Tiefe ab (Vorschlag 600 × 700 × 520 mm) und baut den Schrank. Danach dockt er wie die anderen Schränke an.
3. Maße und Optionen danach in den *Komponentenoptionen* einstellen; Auszug, Schublade und Behälter folgen per Formel, auch bei einer neuen Tiefe.

## Komponentenoptionen
| Option | Standard |
|---|---|
| Breite / Höhe / Tiefe (Korpus ohne Front/Rückwand) | 600 / 700 / 520 mm (Dialog) |
| Fronten | ein Auszug über die volle Höhe, oder Schublade oben + Auszug |
| Höhe Front Schublade oben | 200 mm (nur bei Schublade oben) |
| Anzahl Abfallbehälter | 3 (1–4) |
| Höhe Abfallbehälter | 400 mm, wird begrenzt, wenn der Auszug niedriger ist |

Feste Maße als Attribute (Fenster *Komponentenattribute*): `Materialstaerke_Korpus` 19 mm, `Materialstarke_Rueckwand` 8 mm, `BreiteStreben` 100 mm, `Spaltbreite` 2 mm, LEGRABOX wie beim Unterschrank mit Schubladen (Kastenboden/-rückwand 16 mm, Rückwand höchstens 148 mm, Lochraster 32 mm ab 35 mm), `Kasten_Abstand_unten`/`_oben` 30 mm, `Behaelter_Abstand` 10 mm.

Mit *Interagieren* fahren Auszug und Schublade heraus.

## Aufbau
* **Korpus** wie beim Unterschrank mit Schubladen: Seiten über die volle Höhe und Tiefe, Boden zwischen den Seiten, Streben vorn und hinten oben, Rückwand hinter dem Korpus. Der Korpus beginnt bei y = 19 mm, die Fronten liegen davor (2 mm Spalt).
* **Auszug** (Bereich `A`): Front ab Unterkante Korpus, über die volle Höhe oder bis 2 mm unter die Schublade. LEGRABOX free: Kastenboden LW−35 × NL−10, Holzrückwand LW−38, höchstens 148 mm und mindestens 30 mm unter der Oberkante der Front. Die Nennlänge NL folgt der Tiefe (größte NL 350…650 mit NL + 3 mm ≤ Tiefe). Unterkante Kasten liegt auf dem Lochraster der Seite.
* **Schublade oben** (Bereich `B`, nur bei Schublade oben): gleicher LEGRABOX-Kasten, Kasten ab ≥ 30 mm über Unterkante ihrer Front im Lochraster.
* **Abfallbehälter** als Platzhalter: gleich breit über die Breite des Kastenbodens verteilt (10 mm Luft dazwischen), vom Kastenanfang bis 10 mm vor die Kastenrückwand, auf dem Kastenboden. Die Höhe endet mindestens 30 mm unter der Oberkante der Auszugsfront, so passen sie beim Herausfahren unter der Schublade bzw. der Strebe vorn durch. Die Behälter stehen für ein Abfallsystem nach Wahl (z. B. Einsätze aus dem Fachhandel); die echten Maße folgen, sobald das System feststeht.

## Material und Anleimer
Gezeichnet ist immer das **Endmaß**. Anleimer werden nur als Material zugewiesen: Kantenflächen mit dem Material „Anleimer Melamin weiss“ (Typ *Kante*, 2 mm, „Kantenstärke abziehen“ an). Platten haben „Melamin weiss“ (*Plattenwerkstoff*).

| Teil | Kanten mit Anleimer |
|---|---|
| Seiten, Boden, Strebe vorn | vorne |
| Strebe hinten, Rückwand, Kastenboden | keine |
| Kastenrückwand | oben |
| Fronten | alle vier |

Die Behälter haben das Material „Abfallbehälter“ mit Typ *Beschlag* und kein `JT_Schrank`; Stückliste und TCN-Export übergehen sie.

## Tags
Jedes Teil hat einen eigenen Tag `<Kürzel>_<Bereich>_<Teil>`: `USM1_SeiteL`, `USM1_SeiteR`, `USM1_Boden`, `USM1_StrebeVorn`, `USM1_StrebeHinten`, `USM1_Rueckwand`, `USM1_A_Front`, `USM1_A_KastenBoden`, `USM1_A_KastenRueckwand`, `USM1_B_Front`, `USM1_B_KastenBoden`, `USM1_B_KastenRueckwand`, die Behälter `USM1_A_Behaelter1` … `4`, dazu die Gruppen `USM1_A_Auszug` und `USM1_B_Schublade`. Das Kürzel ist `USM1`, oder `USM2` usw., wenn es im Modell schon vergeben ist.

An jedem Teil außer den Behältern steht das Wörterbuch `JT_Schrank` mit `schrank`, `typ` (`Unterschrank_Abfall`), `kategorie` (`Unterschrank`), `bereich`, `teil` und `rolle`; die Rollen-Tabelle ist dieselbe wie in allen Komponenten.

## TCN-Export (Plugin Schrank-CNC)
Ohne Änderung am Plugin, wie beim Unterschrank mit Schubladen: Dübel der Böden und Streben, Rückwand, Sockelfüße im Boden, LEGRABOX-Schienenbohrungen je Kasten in beiden Seiten (Nennlänge aus `NL`), Frontbefestigung und Bodenfalz. Keine Lochreihen (Fach mit Auszug). Die Behälter haben kein `JT_Schrank` und werden übergangen.

## Hilfe in SketchUp
Eine Kurzfassung dieser Doku steht oben im Fenster *Komponentenoptionen* (Summary und Description) mit Link auf diese Seite. Der Text steht als `HILFE` in `src/unterschrank_abfall/main.rb`.

## Tests
`ruby test/test_unterschrank_abfall.rb` – prüft ohne SketchUp (Mock-API und DC-Formel-Auswerter) Korpus, Fronten, LEGRABOX-Kästen im Lochraster, Behälter (Anzahl, Breite, Höhe, unter der Schublade), Formeln nach Umkonfigurieren, nachträgliche Tiefenänderung, Materialien, Anleimer, Tags, `JT_Schrank` und die Kurzhilfe. Der Plugin-Test `sketchup-tcn-export-plugin/test/test_export.rb` prüft Schienen- und Frontbohrungen beider Varianten.
