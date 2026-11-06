# Unterschrank Backofen – Herdumbauschrank (SketchUp)

Erweiterung, die einen **Herdumbauschrank** als Dynamic Component erzeugt: einen Unterschrank für einen **Einbaubackofen unter dem Kochfeld**. Aufbau wie die anderen Unterschränke (Seiten, Boden, Rückwand), aber:

* oben die **Nische für den Backofen** (Front 595 mm), das Kochfeld liegt darüber in der Arbeitsplatte,
* der Ofen steht auf einem **Einbauboden**, hinten bleibt ein **Lüftungsspalt** (Standard 50 mm),
* **keine Streben oben**: Die Ofenfront reicht bis zur Korpusoberkante, und der Kochfeldausschnitt liegt fast über der ganzen Tiefe,
* die **Rückwand** gibt es nur unterhalb des Einbaubodens (oben Lüftung und Gerätetiefe, Backöfen sind meist um 550 mm tief),
* unter dem Einbauboden eine **flache Schublade** (Blum LEGRABOX), **wenn die lichte Höhe reicht, sonst eine feste Blende** (Entscheidung Jürgen, 2026-11-02).
* **Zargenhöhe und Schiene (LEGRABOX free, MD-015/4):** Zarge **C** (177 mm, Holzrückwand 148 mm), wenn der Kasten Platz hat, sonst **M** (90,5 mm, Holzrückwand 62 mm). Platz: oberste Schublade bis 30 mm (`Kasten_Abstand_oben`) unter die Frontoberkante, darunter bis an die Frontoberkante (die Front deckt Zarge und Fronthalter ab). Die Schiene sitzt mindestens 38 mm über dem festen Boden darunter. Passt nicht einmal M, meldet der TCN-Export das. Die Beschläge dazu stehen auf der letzten Seite der Stückliste.

Bei 700 mm Korpus und 600 mm Nische bleiben unter dem Einbauboden nur 62 mm frei (700 − 600 − 2 × 19). Das reicht für keinen LEGRABOX-Kasten, es wird eine Blende. Ab etwa 723 mm Korpushöhe (85 mm frei) kommt automatisch eine Schublade. Die Gerätemaße und die 85 mm sind **Richtwerte**; vor dem Bau mit der Einbauanleitung des Backofens und der Blum-Doku prüfen.

## Installation
1. SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `unterschrank_backofen.rbz` wählen (oder `Kuechenplaner_alle.rbz` aus dem Hauptordner für alle Komponenten auf einmal).
2. Danach: *Erweiterungen → Küchenplaner → Unterschränke → Unterschrank Backofen (Herdumbau)…* oder in der Symbolleiste *Schrank einfügen*.

Ohne Installation: Ruby-Konsole `load 'C:/Pfad/zu/src/unterschrank_backofen/main.rb'`, dann `UnterschrankBackofen.dialog`.

## Dialog und Komponentenoptionen
| Feld | Standard | Bedeutung |
|---|---|---|
| Breite / Höhe / Tiefe | 600 / 700 / 520 mm | Korpus ohne Front/Rückwand; lichte Breite 600 − 2 × 19 = 562 mm (Backöfen brauchen meist 560–568) |
| Nischenhöhe Backofen | 600 mm | Oberkante Einbauboden bis Korpusoberkante |
| Lüftungsspalt hinten | 50 mm | der Einbauboden ist um diesen Wert kürzer als der Korpus |
| Unten | automatisch | *automatisch*: Schublade, wenn die lichte Höhe unter dem Einbauboden mindestens *Min. lichte Höhe Schublade* (85 mm) ist, sonst Blende; *Blende*: immer Blende |
| Stärke Arbeitsplatte | 40 mm | nur für die Lage der Geräte |

Der Dialog warnt, wenn die lichte Breite unter 560 mm liegt oder statt der Schublade eine Blende kommt; der Schrank wird trotzdem gebaut. Alle Werte lassen sich später in den Komponentenoptionen ändern, Schublade und Blende wechseln dann von selbst. Mit *Interagieren* auf die Schublade klicken → sie fährt heraus.

## Aufbau
* **SeiteL/R, Boden** wie beim Unterschrank mit Schubladen (Seiten sind immer gleich).
* **Einbauboden** (Tag `…_ZwischenbodenUnten`, Rolle Zwischenboden): Oberkante = Höhe − Nischenhöhe, Tiefe = Korpustiefe − Lüftungsspalt, vorne bündig. Er trägt `JT_Schrank/nische = N1`, damit der TCN-Export in der Nische keine Lochreihe bohrt; er wird wie ein Zwischenboden mit Dübeln an die Seiten angeschlagen.
* **Rückwand:** hinter dem Korpus wie bei den anderen Unterschränken, aber nur bis zur Oberkante des Einbaubodens.
* **Blende** (feste Front, Höhe = Oberkante Einbauboden − 2 mm Fuge, damit die Ofenfront darüber passt) oder **Schublade**: Front gleich groß, LEGRABOX-Kasten (Boden LW − 35 × NL − 10, Holzrückwand LW − 38, nach der höchsten Zarge, die bis 30 mm unter den Einbauboden passt, F/C/K/M/N), Unterkante 38 mm über dem Korpusboden ohne Lochraster. Die Nennlänge NL ist die größte mit NL + 3 mm ≤ Tiefe und steht als Attribut `NL` am Schrank. Die Blende bekommt beim Ändern der Frontfarbe keine Griffbohrungen.

Arbeitsplatte, Kochfeldausschnitt (die Arbeitsplatte macht ihn über diesem Schrank von selbst) und Sockelblende gehören wie bei den anderen Komponenten nicht zum Schrank.

## Material, Kanten und Tags
* **Material:** jedes Teil „Melamin weiss“ (Plattenmaterial), Endmaß in SketchUp; den 2-mm-Abzug für den Anleimer rechnen Stückliste und Zuschnitt.

| Teil | Anleimer |
|---|---|
| Seiten, Boden, Einbauboden | Vorderkante |
| Rückwand, Kastenboden | keiner |
| Blende, Front | rundum |
| Kastenrückwand | Oberkante |

* **Tags:** `<Kürzel>_<Bereich>_<Teil>`, Kürzel `USB1`, `USB2` …: `USB1_SeiteL`, `USB1_Boden`, `USB1_ZwischenbodenUnten`, `USB1_Rueckwand`, `USB1_Blende`, `USB1_S1_Front`, `USB1_S1_KastenBoden`, `USB1_S1_KastenRueckwand`, Gruppe `USB1_S1_Schublade`. Am Teil das Wörterbuch `JT_Schrank` mit `typ` = Unterschrank_Backofen und `kategorie` = Unterschrank. Ausgeblendete Teile (Blende oder Schublade) übergehen TCN-Export, Stückliste und Zuschnitt.

## Nischen für die Geräte-Darstellung
Am Schrank stehen zwei Wörterbücher (Stand beim Erzeugen, Maße in mm):
* `JT_Nische_N1`: `geraet` = Backofen60, lichte `breite`/`hoehe`/`tiefe`, Einfügepunkt `x`/`y`/`z` vorne links auf dem Einbauboden.
* `JT_Nische_KF`: `geraet` = Kochfeld60 (nach Breite), Einfügepunkt vorne links auf der Korpusoberkante, `arbeitsplatte`.

*Geräte in Schränke setzen* setzt dort Backofen und Kochfeld (ohne Abzug) ein.

## Hilfe in SketchUp
Eine Kurzfassung (ein Satz, `HILFE_KURZ` in `src/unterschrank_backofen/main.rb`) steht oben im Fenster *Komponentenoptionen* und als Beschreibung der Komponente. Die ausführliche Doku steht nur hier, damit das Fenster ganz lesbar bleibt.

## Tests
`ruby test/test_generator.rb` – prüft ohne SketchUp (Mock-API und DC-Formel-Auswerter) Geometrie und Formeln (Einbauboden, Nische, Rückwand nur unten, Schublade oder Blende je nach lichter Höhe, NL, Kastenhöhe), auch nach Umkonfiguration und Tiefenänderung, dazu Material, Anleimer, Tags, Nischen, Warnungen und die Kurzhilfe. Der TCN-Export für diesen Schrank wird in `sketchup-tcn-export-plugin/test/test_export.rb` geprüft. Nach Änderungen an `src/` im Hauptordner `./build_rbz.sh` ausführen. In echtem SketchUp noch nicht getestet.
