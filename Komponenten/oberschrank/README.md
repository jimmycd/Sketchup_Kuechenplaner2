# Oberschrank (Dynamic Component)

Ersetzt die beiden von Hand gebauten Oberschränke (`Oberschrank.skp` mit einer Tür, `Oberschrank_Doppeltuer.skp`): eine Komponente, die Türen sind eine Option.

## Installieren und benutzen
1. SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `oberschrank.rbz` wählen (oder `Kuechenplaner_alle.rbz` aus dem Hauptordner für alle Komponenten auf einmal).
2. *Erweiterungen → Küchenplaner → Oberschrank…* baut den Schrank im aktuellen Modell (Kürzel für die Tags automatisch, siehe unten). Maße und Optionen danach in den *Komponentenoptionen* einstellen.

Wer eine fertige `.skp` für die Komponenten-Bibliothek möchte: Rechtsklick auf den Schrank → *Speichern unter…*.

## Komponentenoptionen
| Option | Standard |
|---|---|
| Breite / Höhe / Tiefe (Korpus ohne Front) | 600 / 700 / 400 mm |
| Türen | keine (offen), eine Tür (Anschlag links), zwei Türen; Standard zwei |
| Anzahl Einlegeböden | 0–3, gleichmäßig verteilt; Standard 1 |

Feste Maße als Attribute (Fenster *Komponentenattribute*): `Materialstaerke_Korpus` 19 mm, `Materialstarke_Rueckwand` 8 mm, `Rueckwand_Versatz` 25 mm, `Nuttiefe` 9 mm, `Spaltbreite` 2 mm, `Rueckversatz_Einlegeboden` 10 mm.

Mit *Interagieren* öffnen sich die Türen (links um die linke, rechts um die rechte Kante).

## Aufbau
* Seiten über die volle Höhe und Tiefe, Boden und Deckel zwischen den Seiten.
* **Rückwand** 8 mm, ihre Rückseite liegt 25 mm vor der Hinterkante der Seiten (Fach für die Aufhängung). Sie steht in einer 8 mm breiten, 9 mm tiefen Nut in beiden Seiten und im Boden und wird von oben eingeschoben; oben ist sie bündig mit den Seiten.
* **Boden** geht über die volle Tiefe (Nut auf der Oberseite). Der **Deckel** endet vor der Rückwand und wird mit ihr verschraubt (3 Schrauben, je 50 mm von den Seiten und in der Mitte; die Bohrungen setzt der TCN-Export).
* **Türen** liegen 2 mm vor dem Korpus, mit 1 mm Fuge außen und oben/unten und 2 mm zwischen zwei Türen. Eine Tür: Breite − 2 mm; zwei Türen: je Breite/2 − 2 mm.
* Einlegeböden 10 mm von vorne zurückgesetzt und hinten bis zur Rückwand.
* Der Korpus beginnt wie bei den anderen Schränken bei y = 19 mm, die Tür liegt davor.

## OpenCutList (OCL)
Gezeichnet ist immer das **Endmaß**. Anleimer werden nur für OCL zugewiesen: Kantenflächen mit dem Material „Anleimer Melamin weiss“ (OCL-Typ *Kante*, 2 mm, „Kantenstärke abziehen“ an). Platten haben „Melamin weiss“ (*Plattenwerkstoff*).

| Teil | Kanten mit Anleimer |
|---|---|
| Seiten | vorne, unten, oben (beim Oberschrank von unten und oben sichtbar) |
| Boden, Deckel, Einlegeböden | vorne |
| Rückwand | keine |
| Türen | alle vier |

## Tags
Jedes Teil hat einen eigenen Tag `<Kürzel>_<Teil>`: `OS1_SeiteL`, `OS1_SeiteR`, `OS1_Boden`, `OS1_Deckel`, `OS1_Rueckwand`, `OS1_Einlegeboden1` bis `3`, `OS1_Tuer` (eine Tür) bzw. `OS1_TuerL` und `OS1_TuerR`. Das Kürzel ist `OS1`, oder `OS2` usw., wenn es im Modell schon vergeben ist.

Zusätzlich steht an jedem Teil das Wörterbuch `JT_Schrank` mit `schrank`, `typ` (Oberschrank), `kategorie` (Oberschrank), `bereich`, `teil` und `rolle`. Daran erkennen TCN-Export und Frontfarbe-Funktion die Teile.

Die Schrankaufhänger kommen später dazu.

## Hilfe in SketchUp
Eine Kurzfassung dieser Doku steht oben im Fenster *Komponentenoptionen* (Summary und Description) mit Link auf diese Seite. Der Text steht als `HILFE` in `oberschrank.rb`.

## Tests
`ruby test/test_oberschrank.rb` – prüft ohne SketchUp (Mock-API und DC-Formel-Auswerter) Geometrie (Rückwand in der Nut, Deckel vor der Rückwand, Türen und Fugen, Einlegeböden), Formeln nach Umkonfigurieren, OCL-Material, Anleimer, Tags, `JT_Schrank` und die Kurzhilfe.
