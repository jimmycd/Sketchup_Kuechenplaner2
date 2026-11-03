# Unterschrank Kühlschrank (Dynamic Component)

Nische für einen **Unterbau-Kühlschrank oder Weinkühler** in Unterschrankhöhe. Wie beim Geschirrspüler gibt es **keinen eigenen Korpus**: Das Gerät wird unter der Arbeitsplatte und an den Seiten der Nachbarschränke befestigt. Die Komponente besteht aus der Möbelfront (nur beim integrierten Kühlschrank), optionalen Abschlusswangen und einem Platzhalter für das Gerät. Nach außen verhält sie sich wie die anderen Unterschränke (Tags, `JT_Schrank`, Material und Anleimer, Frontfarbe, Andocken, TCN-Export, Stückliste).

## Installieren und benutzen
1. SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `unterschrank_kuehlschrank.rbz` wählen (oder `Kuechenplaner_alle.rbz` aus dem Hauptordner).
2. *Erweiterungen → Küchenplaner → Unterschränke → Unterschrank Kühlschrank…* (oder Symbolleiste *Schrank einfügen*) fragt Gerät, Breite, Höhe und Tiefe ab (Tiefe Standard 520 mm) und setzt den Schrank mit dem Andock-Werkzeug. Alles andere danach in den *Komponentenoptionen*.

## Komponentenoptionen
| Option | Standard |
|---|---|
| Gerät | **Kühlschrank integriert (Möbelfront)** / Weinkühler (Glastür) / Kühlschrank unterbaufähig (eigene Tür) |
| Nischenbreite | 300 / 450 / **600** mm (Gerät 296 / 446 / 596 mm) |
| Höhe / Tiefe | 700 / 800 mm, wie der Korpus der Unterschränke daneben (Tiefe auch nachträglich) |
| Fronthöhe | 700 mm; die Oberkante bleibt bündig mit den Nachbarfronten, eine höhere Front reicht nach unten in den Sockel |
| Abschlusswange | keine / links / rechts / beide |
| Sockelhöhe | 100 mm; Wangen und Platzhalter reichen bis zum Boden |

Feste Maße als Attribute (*Komponentenattribute*): `Materialstaerke_Korpus` 19 mm, `Materialstarke_Rueckwand` 8 mm (für die Wangentiefe), `Spaltbreite` 2 mm, `Geraet_Luft` 4 mm (Nische − Gerätebreite), `Geraet_Tiefe` 550 mm.

**Achtung:** Ob Nischenhöhe und Fronthöhe zum Gerät passen, steht in der Einbauanleitung des Herstellers (übliche Nische 820–870 mm inkl. Sockel). Die meisten Geräte brauchen ein **Lüftungsgitter im Sockel** (etwa 200 cm²); das ist kein Bauteil der Komponente, sondern ein Hinweis in der Kurzhilfe.

## Aufbau
* **Front** (nur Kühlschrank integriert) 19 mm wie die Fronten der Unterschränke: Nischenbreite − 2 mm, 2 mm vor der Korpusvorderkante. Sie wird vor Ort mit der Schablone des Herstellers auf die Gerätetür geschraubt (Schlepp- oder Festtür), deshalb **keine CNC-Bohrungen**. Mit *Interagieren* öffnet sie um die linke Kante. Bei Weinkühler und unterbaufähigem Kühlschrank ist sie ausgeblendet und erscheint weder im TCN-Export noch in der Stückliste.
* **Abschlusswangen** (optional) 19 mm außerhalb der Nische, ab der Korpusvorderkante, Tiefe = Korpustiefe + Rückwand, vom Boden bis Oberkante Korpus. Mit Wange links beginnt die Nische 19 mm weiter rechts.
* **Kein Boden, keine Seiten, keine Streben, keine Rückwand.**
* **Geräte-Platzhalter** 596 (446/296) × 550 mm, vom Boden bis Oberkante Korpus, halbtransparent auf dem Tag `Geraete_Plan`, ohne Plattenmaterial und ohne `JT_Schrank`.
* **Nische für die Geräte-Komponenten:** Wörterbuch `JT_Nische` am Schrank mit `nische` (N1), `geraet` (`Kuehlschrank60`, `Weinkuehler30/45/60`, `KuehlschrankFrei60` …), `breite`/`hoehe`/`tiefe`, Einfügepunkt `x`/`y`/`z` (vorne links auf dem Fußboden an der Korpusvorderkante) und `sockel`, alles in mm. *Geräte in Schränke setzen* liest Gerät, Breite, Wange und Sockel aus den aktuellen Komponentenoptionen, ein Umstellen braucht also keinen Neubau.

## Material, Anleimer, Tags
Gezeichnet ist immer das **Endmaß**. Platten haben „Melamin weiss“, Anleimer sind als Material „Anleimer Melamin weiss“ (2 mm) auf den Kantenflächen zugewiesen; Stückliste und Zuschnitt rechnen sie ab.

| Teil | Kanten mit Anleimer |
|---|---|
| Front | rundum |
| Wangen | vorne und oben |

Tags `UKS1_Front`, `UKS1_WangeL`, `UKS1_WangeR` (Kürzel `UKS1`, `UKS2` … je Schrank). An jedem Teil steht `JT_Schrank` mit `schrank`, `typ` (Unterschrank_Kuehlschrank), `kategorie` (Unterschrank), `bereich`, `teil` und `rolle` (Front bzw. Wange; die Wange wird im TCN-Export nur formatiert).

## Hilfe in SketchUp
Eine Kurzfassung (ein Satz, `HILFE_KURZ` in `src/unterschrank_kuehlschrank/main.rb`) steht oben im Fenster *Komponentenoptionen* und als Beschreibung der Komponente. Die ausführliche Doku steht nur hier, damit das Fenster ganz lesbar bleibt.

## Tests
`ruby test/test_kuehlschrank.rb` – prüft ohne SketchUp alle drei Geräte, 300/450/600, Wangen, Platzhalter, Formeln nach Umkonfigurieren (auch Gerät umstellen), Material, Anleimer, Tags, `JT_Schrank`, `JT_Nische`, Kurzhilfe und Tiefe nachträglich. Dazu prüfen der Plugin-Test (TCN-Export, Frontfarbe, Stückliste) und der Geräte-Test (Kühlgeräte, Umstellen in den Komponentenoptionen) die Komponente mit.

## Komponentengrenze (virtueller Korpus)

Die Nische hat keinen Korpus. Damit Einfügen und Andocken wie bei den anderen Unterschränken
funktionieren, enthält die Komponente einen unsichtbaren Kasten „Korpus“ (Wörterbuch `JT_Korpus`,
`virtuell` = true): Nischenbreite plus sichtbare Wangen, von der Front (2 mm vor dem Korpus) bis
hinter die Rückwand, Unterkante bis Oberkante Korpus. Die Front ist links und rechts um die halbe
Fuge kleiner, wie bei allen Fronten. Das Andock-Werkzeug nimmt diesen Kasten; Geräte-Platzhalter
und bis zum Boden reichende Wangen zählen dafür nicht. Ausgeblendete Wangen liegen innerhalb der
Nische, weil SketchUp auch ausgeblendete Teile zum Komponentenrahmen zählt.
