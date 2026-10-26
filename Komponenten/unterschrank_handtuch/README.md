# Schmaler Unterschrank mit Hochauszug (Dynamic Component)

Schmaler Unterschrank (150 oder 200 mm) für einen Handtuch- bzw. Utensilienauszug mit dem Beschlag **Häfele UTENSIO Matrix HU Slim Base** (Montageanleitung 4004110659MKT). Die Front geht über die volle Höhe und fährt mit dem Gestell heraus.

## Installieren und benutzen
1. SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `unterschrank_handtuch.rbz` wählen (oder `Kuechenplaner_alle.rbz` aus dem Hauptordner für alle Komponenten auf einmal).
2. *Erweiterungen → Küchenplaner → Unterschrank Handtuchauszug…* baut den Schrank im aktuellen Modell (Kürzel für die Tags automatisch, siehe unten). Maße und Optionen danach in den *Komponentenoptionen* einstellen.

Wer eine fertige `.skp` für die Komponenten-Bibliothek möchte: Rechtsklick auf den Schrank → *Speichern unter…*.

## Komponentenoptionen
| Option | Standard |
|---|---|
| Häfele HU Slim Base | M150 (Schrank 150 mm breit) oder M200 (200 mm); die Breite folgt dem Modell |
| Schienen an Seite | links (LH) oder rechts (RH) |
| Höhe / Tiefe (Korpus ohne Front/Rückwand) | 700 / 800 mm wie die anderen Unterschränke |

Feste Maße als Attribute (Fenster *Komponentenattribute*): `Materialstaerke_Korpus` 19 mm, `Materialstarke_Rueckwand` 8 mm, `BreiteStreben` 100 mm, `Spaltbreite` 2 mm, `Bauraum_Tiefe` 485 mm, `Bauraum_Hoehe` 565 mm, `Auszug_Weg` 450 mm (nur Animation).

Mit *Interagieren* fährt der Auszug heraus.

## Aufbau
* **Korpus** wie beim Unterschrank mit Schubladen: Seiten über die volle Höhe und Tiefe, Boden zwischen den Seiten, Streben vorn und hinten oben, Rückwand hinter dem Korpus. Lichte Weite 112 mm (M150) bzw. 162 mm (M200), genau das Mindestmaß von Häfele.
* **Front** 19 mm über die volle Höhe, 1 mm Fuge seitlich, 2 mm vor dem Korpus (wie eine einzelne Schublade).
* **Beschlag** als Platzhalter: der Einbauraum laut Häfele (lichte Weite × 485 × 565 mm) auf dem Boden ab Korpusvorderkante. Er steckt mit der Front in der Gruppe `Auszug`.
* Häfele verlangt lichte Höhe ≥ 565 mm (also Höhe ≥ 603 mm) und Tiefe ≥ 485 mm. Die Komponente prüft das nicht; der TCN-Export meldet einen zu kleinen Einbauraum.
* Der Korpus beginnt wie bei den anderen Schränken bei y = 19 mm, die Front liegt davor.

## OpenCutList (OCL)
Gezeichnet ist immer das **Endmaß**. Anleimer werden nur für OCL zugewiesen: Kantenflächen mit dem Material „Anleimer Melamin weiss“ (OCL-Typ *Kante*, 2 mm, „Kantenstärke abziehen“ an). Platten haben „Melamin weiss“ (*Plattenwerkstoff*).

| Teil | Kanten mit Anleimer |
|---|---|
| Seiten, Boden, Strebe vorn | vorne |
| Strebe hinten, Rückwand | keine |
| Front | alle vier |

Der Platzhalter hat das Material „Häfele HU Slim Base“ mit OCL-Typ *Beschlag*; OCL führt ihn damit als Kaufteil und nicht als Platte.

## Tags
Jedes Teil hat einen eigenen Tag `<Kürzel>_<Teil>`: `USH1_SeiteL`, `USH1_SeiteR`, `USH1_Boden`, `USH1_StrebeVorn`, `USH1_StrebeHinten`, `USH1_Rueckwand`, `USH1_Front`, dazu `USH1_Beschlag` (Platzhalter) und `USH1_Auszug` (Gruppe aus Front und Beschlag). Das Kürzel ist `USH1`, oder `USH2` usw., wenn es im Modell schon vergeben ist.

An jedem Teil außer dem Beschlag steht das Wörterbuch `JT_Schrank` mit `schrank`, `typ` (Unterschrank_Handtuch), `kategorie` (Unterschrank), `bereich`, `teil` und `rolle`. Am Schrank steht zusätzlich `beschlag` = `Haefele HU Slim Base`. Daran erkennt der TCN-Export, dass er die Häfele-Bohrungen setzen soll; die Frontfarbe-Funktion zählt den Schrank zu den Unterschränken.

## TCN-Export (Plugin Schrank-CNC)
Nach Häfele „Dimensions for CNC“ (Maße ab Oberkante Boden bzw. Vorderkante Seite):
* **Schienen** nur in der gewählten Seite: je Schiene Bohrungen bei 56, 280 und 330 mm ab Vorderkante, untere Schiene 52 mm, obere 436 mm (52 + 384) über dem Boden.
* **Front:** zwei Halter mit je zwei Bohrungen, 14 mm von der Innenseite der Seiten (X = 84 mm bei M150, 134 mm bei M200), 103 und 487 mm über dem Boden.
* Alle Ø3 vorgebohrt für die mitgelieferten Schrauben Ø4 × 16; Seite 10 mm tief (Annahme), Front 5 mm tief.
* Keine Lochreihen. Der schmale Boden bekommt nur einen Sockelfuß je Ende, mittig.

## Hilfe in SketchUp
Eine Kurzfassung dieser Doku steht oben im Fenster *Komponentenoptionen* (Summary und Description) mit Link auf diese Seite. Der Text steht als `HILFE` in `unterschrank_handtuch.rb`.

## Tests
`ruby test/test_unterschrank_handtuch.rb` – prüft ohne SketchUp (Mock-API und DC-Formel-Auswerter) Geometrie (Korpus, Front, Einbauraum M150/M200), Formeln nach Umkonfigurieren, OCL-Material und -Typ des Beschlags, Anleimer, Tags, `JT_Schrank` und die Kurzhilfe. Der Plugin-Test `sketchup-tcn-export-plugin/test/test_export.rb` prüft die Schienen- und Frontbohrungen (links und rechts, M150 und M200), die Hinweise bei zu kleinem Einbauraum und die Sockelfüße.
