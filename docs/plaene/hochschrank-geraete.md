> Quelle: [Plan: Hochschrank für zwei Großgeräte](https://claude.ai/artifact/Npz8wjeDMibuAtpuEEu7Rd) (Plan-Dokument aus dem Projekt-Thread, Stand 28.10.2026)  
> Status: umgesetzt in PR #12, `Komponenten/hochschrank_geraete/`

# Plan: Hochschrank für zwei Großgeräte

Oct 25, 2026 · @Jürgen Späder

## Kurzfassung

Ich baue eine neue Komponente **Hochschrank Geräte** unter `Komponenten/hochschrank_geraete/`: unten Schubladen, darüber zwei Gerätenischen (z. B. Backofen + Mikrowelle oder Backofen + Dampfgarer), oben ein Fach mit Tür. Basis ist der bestehende Hochschrank auf main: gleiches Skript-Prinzip (einmal in der Ruby-Konsole laden, ergibt eine .skp), gleiche Schubladen (Blum LEGRABOX, Lochraster), gleiche OCL-Regeln, Tags, `JT_Schrank` und Kurzhilfe.

Eine eigene Komponente statt einer Erweiterung des Hochschranks, weil die Komponentenoptionen sonst zu lang werden. Der normale Hochschrank bleibt unverändert.

## Aufbau und Komponentenoptionen

Von unten nach oben, mit Standardwerten bei 600 × 2100 × 800 mm (wie der Hochschrank):

| Bereich | Höhe (Standard) | Optionen |
| --- | --- | --- |
| Unten: Schubladen | bis Oberkante Einbauboden 1 = 700 mm | Anzahl 1–4, Anteile 1–4 (1 = oben), wie beim Hochschrank |
| Nische 1 (unteres Gerät) | lichte Höhe 590 mm | Gerät: Backofen 60 / Kompaktgerät 45 / Mikrowelle 38 / Wärmeschublade 14 / frei |
| Nische 2 (oberes Gerät) | lichte Höhe 450 mm | wie Nische 1, zusätzlich *keine* |
| Oben: Fach | Rest, hier ca. 300 mm lichte Höhe | offen oder Tür, 0–2 Einlegeböden; Höhe wird angezeigt |

Die Geräteauswahl setzt die lichte Nischenhöhe: Backofen 590, Kompaktgerät 450 (Mikrowelle, Dampfgarer, Kompaktbackofen), Mikrowelle 380, Wärmeschublade 140 mm. Bei *frei* gilt ein eigenes Feld „Lichte Höhe“. Die Werte decken die gängigen Einbaumaße von Bosch, Siemens, Neff und Miele ab; sie stammen aus meinem Wissen und sind nicht nachgeschlagen.

In den Komponentenoptionen steht zusätzlich eine nur lesbare Prüfung: „Lichte Breite 562 mm, Gerätenische ok“ oder „zu schmal (min. 560)“. Bei 600 mm Breite und 19 mm Seiten passt es genau.

## Gerätenischen

Jedes Gerät steht auf einem festen **Einbauboden** (19 mm, verdübelt wie die Zwischenböden). Über der oberen Nische schließt ein weiterer fester Boden das obere Fach ab. Damit hat der Schrank drei feste Zwischenböden statt zwei.

- **Lüftung:** Die Einbauböden sind hinten um den *Lüftungsspalt* gekürzt (Standard 50 mm). Dahinter entsteht ein Kamin, durch den die Abwärme nach oben abzieht und das Kabel läuft.
- **Rückwand:** Im Nischenbereich ausgespart. Es gibt eine Rückwand unten (Schubladen) und eine oben (oberes Fach); hinter den Geräten bleibt der Schrank offen zur Wand.
- **Stabilität:** Ohne Rückwand in der Mitte steifen die verdübelten Einbauböden den Korpus aus. Optional kommt hinten unter dem oberen Einbauboden eine Strebe (100 mm) dazu.
- **Fronten und Fugen:** Die Gerätefront deckt die Nische und die Vorderkante der Böden ab. Die oberste Schubladenfront endet 2 mm unter Nische 1, die Tür beginnt 2 mm über Nische 2, wie beim Hochschrank.
- **Keine Lochreihe in den Nischen:** Dort gibt es keine Einlegeböden, der TCN-Export bohrt dort also schon heute nichts.

Ist Nische 2 auf *keine* gestellt, entfällt der mittlere Boden und das obere Fach wird entsprechend höher.

## Geräte-Darstellung

Der Schrank liefert nur die Nische, das Gerät selbst kommt aus dem Thread „Geräte in Schränken darstellen“. Dort wird gerade ein Geräte-Generator mit Plan- und Render-Darstellung vorgeschlagen.

Damit beides zusammenpasst, bekommt jede Nische ein Wortärbuch `JT_Nische` am Schrank: Gerätetyp, lichte Breite, Höhe und Tiefe sowie den Einfügepunkt (vorne links auf dem Einbauboden, an der Korpusvorderkante). Ein Gerät kann so passend eingesetzt oder getauscht werden. Geräte bekommen kein Plattenmaterial, keinen `JT_Schrank` und keinen Teil-Tag, OCL und TCN bleiben unberührt. Die Schnittstelle stimme ich mit dem Geräte-Thread ab.

## Tags, OCL und TCN-Export

Kürzel **HG1** (HG2 … wenn vergeben), `typ` = Hochschrank Geräte, `kategorie` = Hochschrank. Damit greifen Frontfarbe (Auswahl Hochschränke) und Sockelfüße ohne Änderung am Plugin.

| Teil | Tag (Beispiel) | Rolle | Anleimer |
| --- | --- | --- | --- |
| Seiten | HG1\_SeiteL, HG1\_SeiteR | Seite | vorne, oben |
| Boden, Deckel | HG1\_Boden, HG1\_Deckel | Boden, Deckel | vorne |
| Einbauboden unter Nische 1 / 2, Boden über Nische 2 | HG1\_N1\_Einbauboden, HG1\_N2\_Einbauboden, HG1\_ZwischenbodenOben | Zwischenboden | vorne |
| Rückwand unten / oben | HG1\_RueckwandUnten, HG1\_RueckwandOben | Rueckwand | links, rechts, oben (unten: links, rechts) |
| Strebe hinten (optional) | HG1\_StrebeHinten | Strebe | keine |
| Einlegeböden, Tür | HG1\_O\_Einlegeboden1, HG1\_O\_Tuer | Einlegeboden, Tuer | vorne / alle vier |
| Schubladen | HG1\_U1\_Front, HG1\_U1\_KastenBoden, HG1\_U1\_KastenRueckwand | wie Hochschrank | wie Hochschrank |

Die neuen Teilnamen (Einbauboden, RueckwandUnten, RueckwandOben) kommen in die gemeinsame `ROLLEN`-Tabelle, die in allen Komponenten gleich sein muss. Ich ergänze sie deshalb in allen Komponenten. Der TCN-Export braucht sonst nichts Neues: Dübel, Sockelfüße und Lochreihen laufen über die Rollen. Ein Test exportiert den neuen Schrank und prüft das.

## Umsetzung und Lieferung

1. Neuer Branch von main, Ordner `Komponenten/hochschrank_geraete/` mit `hochschrank_geraete.rb`, README (Kurzdoku) und Kurzhilfe in der Komponente.
2. Mock-Tests wie beim Hochschrank: Geometrie und DC-Formeln für alle Gerätekombinationen, Nischenmaße, Lüftungsspalt, Schubladen im Lochraster, OCL-Material und Anleimer, Tags, `JT_Nische`. Dazu ein Export-Test im Plugin.
3. `ROLLEN` in allen Komponenten ergänzen, `./run_tests.sh` grün.
4. Ein PR, du gibst frei. In echtem SketchUp ist danach ein Test von dir nötig, wie bei den anderen Komponenten.

## Fragen zur Freigabe

Ohne Antwort nehme ich jeweils den ersten Vorschlag.

- [ ] **Reihenfolge Standard:** Backofen unten (Nische 1), Kompaktgerät darüber? Oder Backofen oben auf Augenhöhe und Kompaktgerät darunter? am ende sind es beides nischen, sollt egal sein
- [ ] **Rückwand und Lüftung:** Rückwand im Nischenbereich aussparen und Einbauböden hinten 50 mm kürzen? Oder Rückwand durchgehend lassen? - rückwand durchgehend
- [ ] **Strebe hinten:** standardmäßig an oder aus? -- strebe wofür?
- [ ] **Höhe unten:** 700 mm bis Oberkante Einbauboden 1 passt, oder bevorzugst du ein anderes Maß (Backofen-Unterkante über Boden mit Sockel)? - einstellbar
