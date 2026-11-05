# Unterschrank Geschirrspüler (Dynamic Component)

Nische für einen **vollintegrierten Geschirrspüler** (45 oder 60 cm) in der Unterschrankzeile. Der Spüler hat keinen eigenen Korpus: Die Komponente besteht aus der Möbelfront, optionalen Abschlusswangen und einem Platzhalter für das Gerät. Nach außen verhält sie sich wie die anderen Unterschränke (Tags, `JT_Schrank`, Material, Frontfarbe, TCN-Export).

## Installieren und benutzen
1. SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `unterschrank_geschirrspueler.rbz` wählen (oder `Kuechenplaner_alle.rbz` aus dem Hauptordner für alle Komponenten auf einmal).
2. *Erweiterungen → Küchenplaner → Unterschränke → Unterschrank Geschirrspüler…* baut den Schrank im aktuellen Modell (Kürzel für die Tags automatisch, siehe unten). Maße und Optionen danach in den *Komponentenoptionen* einstellen.

Wer eine fertige `.skp` für die Komponenten-Bibliothek möchte: Rechtsklick auf den Schrank → *Speichern unter…*.

## Komponentenoptionen
| Option | Standard |
|---|---|
| Nischenbreite | 450 / **600** mm (Gerät 448 / 598 mm) |
| Höhe / Tiefe | 700 / 800 mm, wie der Korpus der Unterschränke daneben |
| Fronthöhe | 700 mm; die Oberkante bleibt bündig mit den Nachbarfronten, eine höhere Front reicht nach unten in den Sockel |
| Abschlusswange | keine / links / rechts / beide |
| Sockelhöhe | 100 mm (Füße sind verstellbar); Wangen und Platzhalter reichen bis zum Boden |

Feste Maße als Attribute (Fenster *Komponentenattribute*): `Materialstaerke_Korpus` 19 mm (Front, Wangen), `Materialstarke_Rueckwand` 8 mm (für die Wangentiefe), `Spaltbreite` 2 mm, `Geraet_Luft` 2 mm (Nische − Gerätebreite), `Geraet_Tiefe` 550 mm (der Platzhalter ist höchstens so tief wie der Korpus, bei 520 mm Tiefe also 520 mm), `Geraet_Sockel_Versatz` 85 mm (Vorderkante Gerätesockel ab Korpusvorderkante).

**Achtung Fronthöhe:** Ob die Front zur Gerätetür passt, hängt vom Gerät und vom Sockel ab (Herstellerangaben zu Fronthöhe und Nischenhöhe, übliche Nische 815–875 mm inkl. Sockel). Das steht auch in der Kurzhilfe.

## Aufbau
* **Front** 19 mm wie die Fronten der Unterschränke: Nischenbreite − 2 mm (1 mm Fuge je Seite), 2 mm vor der Korpusvorderkante. Sie wird vor Ort mit der Schablone des Geräteherstellers auf die Gerätetür geschraubt, deshalb gibt es **keine CNC-Bohrungen** dafür. Mit *Interagieren* klappt sie um die Unterkante auf.
* **Abschlusswangen** (optional) 19 mm außerhalb der Nische, wie die Seiten der Unterschränke ab der Korpusvorderkante, Tiefe = Korpustiefe + Rückwand, vom Boden (Sockelhöhe) bis Oberkante Korpus. Mit Wange links beginnt die Nische 19 mm weiter rechts; die Gesamtbreite ist Nische + Wangen.
* **Kein Boden, keine Seiten, keine Streben, keine Rückwand.** Das Gerät wird an Arbeitsplatte und Nachbarseiten befestigt; den Dampfschutz liefert der Hersteller.
* **Geräte-Platzhalter** 598 (448) × 550 mm (höchstens Korpustiefe), von Unterkante bis Oberkante Korpus, darunter der **Gerätesockel**: Er springt wie bei echten Unterbaugeräten zurück und beginnt `Geraet_Sockel_Versatz` = 85 mm hinter der Korpusvorderkante, also hinter der Sockelblende (19 mm Korpus + 50 mm Rücksprung + 16 mm Blende). Beides halbtransparent auf dem Tag `Geraete_Plan`. Er hat kein Plattenmaterial und kein `JT_Schrank`, der TCN-Export übergeht ihn. Für Stückliste und Etiketten den Tag `Geraete_Plan` ausblenden. Er wird später durch die Geräte-Komponenten ersetzt.
* **Nische für die Geräte-Komponenten:** Wörterbuch `JT_Nische` am Schrank mit `nische` (N1), `geraet` (Geschirrspueler60/45), lichten Maßen `breite`/`hoehe`/`tiefe` und dem Einfügepunkt `x`/`y`/`z` (vorne links auf dem Fußboden an der Korpusvorderkante), alles in mm, Stand beim Erzeugen.

## Material und Anleimer
Gezeichnet ist immer das **Endmaß**. Anleimer werden nur als Material zugewiesen: Kantenflächen mit dem Material „Anleimer Melamin weiss“ (Typ *Kante*, 2 mm, „Kantenstärke abziehen“ an). Platten haben „Melamin weiss“ (*Plattenwerkstoff*).

| Teil | Kanten mit Anleimer |
|---|---|
| Front | rundum |
| Wangen | vorne und oben |

## Tags
`USG1_Front`, `USG1_WangeL`, `USG1_WangeR`. Das Kürzel ist `USG1`, oder `USG2` usw., wenn es im Modell schon vergeben ist. An jedem Teil steht `JT_Schrank` mit `schrank`, `typ` (Unterschrank_Geschirrspueler), `kategorie` (**Unterschrank**, damit „Frontfarbe → nur Unterschränke“ ihn mit erfasst), `bereich`, `teil` und `rolle` (Front bzw. **Wange**). Die Rolle *Wange* ist bewusst nicht *Seite*: Der TCN-Export formatiert die Wange nur und bohrt keine Lochreihen oder Dübel.

## Hilfe in SketchUp
Eine Kurzfassung (ein Satz, `HILFE_KURZ` in `src/unterschrank_geschirrspueler/main.rb`) steht oben im Fenster *Komponentenoptionen* und als Beschreibung der Komponente. Die ausführliche Doku steht nur hier, damit das Fenster ganz lesbar bleibt.

## Tests
`ruby test/test_geschirrspueler.rb` – prüft ohne SketchUp (Mock-API und DC-Formel-Auswerter) Front, Fugen, Wangen links/rechts/beide, Platzhalter, Formeln nach Umkonfigurieren (450/600, Fronthöhe, Sockel), Material, Anleimer, Tags, `JT_Schrank`, `JT_Nische` und die Kurzhilfe. Der Plugin-Test prüft, dass der TCN-Export Front und Wangen nur formatiert und die Frontfarbe-Funktion die Front findet.

## Komponentengrenze (virtueller Korpus)

Die Nische hat keinen Korpus. Damit Einfügen und Andocken wie bei den anderen Unterschränken
funktionieren, enthält die Komponente einen unsichtbaren Kasten „Korpus“ (Wörterbuch `JT_Korpus`,
`virtuell` = true): Nischenbreite plus sichtbare Wangen, von der Front (2 mm vor dem Korpus) bis
hinter die Rückwand, Unterkante bis Oberkante Korpus. Die Front ist links und rechts um die halbe
Fuge kleiner, wie bei allen Fronten. Das Andock-Werkzeug nimmt diesen Kasten; Geräte-Platzhalter
und bis zum Boden reichende Wangen zählen dafür nicht. Ausgeblendete Wangen liegen innerhalb der
Nische, weil SketchUp auch ausgeblendete Teile zum Komponentenrahmen zählt.
