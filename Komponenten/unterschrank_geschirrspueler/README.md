# Unterschrank Geschirrspüler (Dynamic Component)

Nische für einen **vollintegrierten Geschirrspüler** (45 oder 60 cm) in der Unterschrankzeile. Der Spüler hat keinen eigenen Korpus: Die Komponente besteht aus der Möbelfront, optionalen Abschlusswangen und einem Platzhalter für das Gerät. Nach außen verhält sie sich wie die anderen Unterschränke (Tags, `JT_Schrank`, OCL, Frontfarbe, TCN-Export).

## Einmalig die .skp erzeugen
1. `geschirrspueler.rb` z. B. nach `C:/Users/<Name>/Downloads/` speichern.
2. SketchUp öffnen → *Fenster → Ruby-Konsole*.
3. Eingeben: `load 'C:/Users/<Name>/Downloads/geschirrspueler.rb'`
4. Der Schrank erscheint im Modell und wird als **`Unterschrank_Geschirrspueler.skp`** neben das Skript gespeichert. Nichts wird installiert.

Anderes Kürzel für die Tags: `UnterschrankGeschirrspueler.erstellen({ 'Kuerzel' => 'USG2' }, 'C:/…/Unterschrank_Geschirrspueler.skp')`.

## Komponentenoptionen
| Option | Standard |
|---|---|
| Nischenbreite | 450 / **600** mm (Gerät 448 / 598 mm) |
| Höhe / Tiefe | 700 / 800 mm, wie der Korpus der Unterschränke daneben |
| Fronthöhe | 700 mm; die Oberkante bleibt bündig mit den Nachbarfronten, eine höhere Front reicht nach unten in den Sockel |
| Abschlusswange | keine / links / rechts / beide |
| Sockelhöhe | 100 mm (Füße sind verstellbar); Wangen und Platzhalter reichen bis zum Boden |

Feste Maße als Attribute (Fenster *Komponentenattribute*): `Materialstaerke_Korpus` 19 mm (Front, Wangen), `Materialstarke_Rueckwand` 8 mm (für die Wangentiefe), `Spaltbreite` 2 mm, `Geraet_Luft` 2 mm (Nische − Gerätebreite), `Geraet_Tiefe` 550 mm.

**Achtung Fronthöhe:** Ob die Front zur Gerätetür passt, hängt vom Gerät und vom Sockel ab (Herstellerangaben zu Fronthöhe und Nischenhöhe, übliche Nische 815–875 mm inkl. Sockel). Das steht auch in der Kurzhilfe.

## Aufbau
* **Front** 19 mm wie die Fronten der Unterschränke: Nischenbreite − 2 mm (1 mm Fuge je Seite), 2 mm vor der Korpusvorderkante. Sie wird vor Ort mit der Schablone des Geräteherstellers auf die Gerätetür geschraubt, deshalb gibt es **keine CNC-Bohrungen** dafür. Mit *Interagieren* klappt sie um die Unterkante auf.
* **Abschlusswangen** (optional) 19 mm außerhalb der Nische, wie die Seiten der Unterschränke ab der Korpusvorderkante, Tiefe = Korpustiefe + Rückwand, vom Boden (Sockelhöhe) bis Oberkante Korpus. Mit Wange links beginnt die Nische 19 mm weiter rechts; die Gesamtbreite ist Nische + Wangen.
* **Kein Boden, keine Seiten, keine Streben, keine Rückwand.** Das Gerät wird an Arbeitsplatte und Nachbarseiten befestigt; den Dampfschutz liefert der Hersteller.
* **Geräte-Platzhalter** 598 (448) × 550 mm, vom Boden bis Oberkante Korpus, halbtransparent auf dem Tag `Geraete_Plan`. Er hat kein Plattenmaterial und kein `JT_Schrank`, der TCN-Export übergeht ihn. Vor dem OCL-Lauf den Tag `Geraete_Plan` ausblenden. Er wird später durch die Geräte-Komponenten ersetzt.
* **Nische für die Geräte-Komponenten:** Wörterbuch `JT_Nische` am Schrank mit `nische` (N1), `geraet` (Geschirrspueler60/45), lichten Maßen `breite`/`hoehe`/`tiefe` und dem Einfügepunkt `x`/`y`/`z` (vorne links auf dem Fußboden an der Korpusvorderkante), alles in mm, Stand beim Erzeugen.

## OpenCutList (OCL)
Gezeichnet ist immer das **Endmaß**. Anleimer werden nur für OCL zugewiesen: Kantenflächen mit dem Material „Anleimer Melamin weiss“ (OCL-Typ *Kante*, 2 mm, „Kantenstärke abziehen“ an). Platten haben „Melamin weiss“ (*Plattenwerkstoff*).

| Teil | Kanten mit Anleimer |
|---|---|
| Front | rundum |
| Wangen | vorne und oben |

## Tags
`USG1_Front`, `USG1_WangeL`, `USG1_WangeR`. Das Kürzel ist `USG1`, oder `USG2` usw., wenn es im Modell schon vergeben ist. An jedem Teil steht `JT_Schrank` mit `schrank`, `typ` (Unterschrank_Geschirrspueler), `kategorie` (**Unterschrank**, damit „Frontfarbe → nur Unterschränke“ ihn mit erfasst), `bereich`, `teil` und `rolle` (Front bzw. **Wange**). Die Rolle *Wange* ist bewusst nicht *Seite*: Der TCN-Export formatiert die Wange nur und bohrt keine Lochreihen oder Dübel.

## Hilfe in SketchUp
Eine Kurzfassung dieser Doku steht oben im Fenster *Komponentenoptionen* (Summary und Description) mit Link auf diese Seite. Der Text steht als `HILFE` in `geschirrspueler.rb`.

## Tests
`ruby test/test_geschirrspueler.rb` – prüft ohne SketchUp (Mock-API und DC-Formel-Auswerter) Front, Fugen, Wangen links/rechts/beide, Platzhalter, Formeln nach Umkonfigurieren (450/600, Fronthöhe, Sockel), OCL-Material, Anleimer, Tags, `JT_Schrank`, `JT_Nische` und die Kurzhilfe. Der Plugin-Test prüft, dass der TCN-Export Front und Wangen nur formatiert und die Frontfarbe-Funktion die Front findet.
