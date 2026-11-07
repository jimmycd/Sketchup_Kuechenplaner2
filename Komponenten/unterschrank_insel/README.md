# Inselschrank (Dynamic Component)

Unterschrank für eine Kücheninsel. Weil die Rückseite einer Insel zu sehen ist, sitzt hinter der Rückwand eine Verkleidung bis zum Fußboden. Dazu kommen wahlweise Abschlusswangen an den Inselenden und eine erhöhte Theke. Die Front besteht aus Türen oder aus 1–4 Schubladen.

## Installieren und benutzen
1. SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `unterschrank_insel.rbz` wählen (oder `Kuechenplaner_alle.rbz` aus dem Hauptordner für alle Komponenten auf einmal).
2. *Erweiterungen → Küchenplaner → Unterschränke → Inselschrank…* (oder Symbolleiste *Schrank einfügen*) fragt Breite, Höhe und Tiefe ab (Vorschlag 600 × 700 × 520 mm), dazu die Front (Schubladen oder Türen) und die Rückseite (Verkleidung mit Sitzüberstand, Verkleidung mit erhöhter Theke oder ohne Verkleidung). Danach dockt der Schrank wie die anderen an.
3. Für eine Insel mehrere Inselschränke nebeneinander stellen. Wangen nur am ersten (links) und letzten (rechts) Schrank einschalten.
4. Maße und Optionen danach in den *Komponentenoptionen* einstellen. Alle Teile folgen per Formel, auch bei einer neuen Tiefe.

## Komponentenoptionen
| Option | Standard |
|---|---|
| Breite / Höhe / Tiefe (Korpus ohne Front/Rückwand) | 600 / 700 / 520 mm (Dialog) |
| Front | Schubladen oder Türen |
| Türen (bei Türen) | zwei Türen oder eine Tür mit Anschlag links |
| Anzahl Einlegeböden (bei Türen) | 1 (0–2) |
| Anzahl Schubladen (bei Schubladen) | 3 (1–4), gleich hohe Fronten |
| Rückseite verkleiden | Ja |
| Abschlusswange | keine, links, rechts oder beide |
| Erhöhte Theke | Nein |
| Sitzüberstand Arbeitsplatte hinten | 300 mm (nur ohne erhöhte Theke, siehe unten) |
| Thekenhöhe ab Fußboden / Tiefe Thekenplatte / Überstand zur Sitzseite | 1100 / 350 / 250 mm |

Feste Maße als Attribute (Fenster *Komponentenattribute*): `Materialstaerke_Korpus` 19 mm, `Materialstarke_Rueckwand` 8 mm, `Materialstaerke_Verkleidung` 19 mm (auch Wangen), `Staerke_Theke` 38 mm, `Sockelhoehe` 100 mm, `BreiteStreben` 100 mm, `Spaltbreite` 2 mm, `Rueckversatz_Einlegeboden` 10 mm, LEGRABOX wie beim Unterschrank mit Schubladen.

* **Zargenhöhe und Schiene (LEGRABOX free, MD-015/4):** Zarge **C** (177 mm, Holzrückwand 148 mm), wenn der Kasten Platz hat, sonst niedrigere Zargen (K 128,5 / M 90,5 / N 66,5 mm, Holzrückwand 101 / 63 / 39 mm). Platz: oberste Schublade bis 30 mm (`Kasten_Abstand_oben`) unter die Frontoberkante, darunter bis an die Frontoberkante (die Front deckt Zarge und Fronthalter ab). Die Schiene sitzt mindestens 38 mm über dem festen Boden darunter. Passt nicht einmal N, meldet der TCN-Export das. Die Beschläge dazu stehen auf der letzten Seite der Stückliste.

Mit *Interagieren* öffnen sich Türen und Schubladen.

## Aufbau
* **Korpus** wie beim Unterschrank mit Schubladen: Seiten über die volle Höhe und Tiefe, Boden zwischen den Seiten, Streben vorn und hinten oben, Rückwand hinter dem Korpus. Der Korpus beginnt bei y = 19 mm, die Fronten liegen davor (2 mm Spalt).
* **Türen** über die volle Korpushöhe, Einlegeböden gleichmäßig verteilt, 10 mm hinter der Vorderkante.
* **Schubladen** (Bereich `A` = oben, `B`, `C`, `D`): gleich hohe Fronten mit 2 mm Fuge, Blum LEGRABOX free (Kastenboden LW−35 × NL−10, Holzrückwand LW−38, nach Zarge). Die Nennlänge NL folgt der Tiefe, der Kasten sitzt ohne Lochraster 30 mm über der Front (Schiene mind. 38 mm über dem Boden). Zarge: die höchste LEGRABOX-free-Zarge, die Platz hat (C 177, K 128,5, M 90,5, N 66,5 mm; Holzrückwand C 148, K 101, M 63, N 39 laut Blum-Tabelle; ist in den Einstellungen LEGRABOX pure gewählt, zusätzlich F 241 mit Holzrückwand 212).
* **Verkleidung** (19 mm) direkt hinter der Rückwand über die volle Schrankbreite, vom Fußboden (Sockelhöhe unter dem Korpus) bis Oberkante Korpus. Sie wird von innen durch die Rückwand verschraubt; dafür gibt es keine CNC-Bohrungen.
* **Abschlusswangen** (19 mm) außen neben den Seiten, von der Frontfläche bis hinter die Verkleidung und vom Fußboden bis Oberkante Korpus. Die Wangen machen den Schrank um je 19 mm breiter. Die linke liegt bei x = −19 mm.
* **Erhöhte Theke**: Die Verkleidung geht bis unter die Thekenplatte hoch (Thekenhöhe − 38 mm ab Fußboden). Die Thekenplatte ist aus dem Material der Arbeitsplatte („Arbeitsplatte Schichtstoff“, 38 mm) und steht hinten um den Überstand über die Verkleidung (Sitzseite). Vorne liegt sie über der Arbeitsplatte. Die Theke erzwingt die Verkleidung.
* **Sitzüberstand ohne Theke**: Der Schrank trägt im Wörterbuch `JT_Schrank` den Eintrag `insel = true` und im Attribut `Sitzueberstand` den gewünschten Überstand der Arbeitsplatte hinten. *Arbeitsplatte erzeugen* liest das: Eine Zeile nur aus Inselschränken bekommt keinen Wandabstand, die Platte steht hinten um den Sitzüberstand über, und die Hinterkante bekommt den Anleimer. Mit erhöhter Theke endet die Platte an der Verkleidung (siehe [Arbeitsplatte](../arbeitsplatte/README.md#wie-erkannt-wird)).

Ab etwa 350 mm Überstand braucht die Platte Stützen oder Konsolen; die sind nicht gezeichnet.

## Material und Anleimer
Gezeichnet ist immer das **Endmaß**. Anleimer sind Kantenflächen mit dem Material „Anleimer Melamin weiss“ (2 mm, die Stückliste zieht sie ab). Platten haben „Melamin weiss“. *Frontfarbe ändern* setzt das Frontmaterial auch auf Verkleidung und Wangen; Griffe bekommen nur Fronten und Türen.

| Teil | Kanten mit Anleimer |
|---|---|
| Seiten, Boden, Einlegeböden, Strebe vorn | vorne |
| Strebe hinten, Rückwand, Kastenboden | keine |
| Kastenrückwand | oben |
| Fronten, Türen | alle vier |
| Verkleidung | links, rechts, oben (unten steht sie auf dem Fußboden) |
| Wangen | vorne, hinten, oben |
| Thekenplatte | rundum („Anleimer Arbeitsplatte“) |

## Tags
Jedes Teil hat einen eigenen Tag `<Kürzel>_<Bereich>_<Teil>`: `USI1_SeiteL`, `USI1_SeiteR`, `USI1_Boden`, `USI1_StrebeVorn`, `USI1_StrebeHinten`, `USI1_Rueckwand`, `USI1_Einlegeboden1`/`2`, `USI1_Tuer`, `USI1_TuerL`, `USI1_TuerR`, `USI1_A_Front`, `USI1_A_KastenBoden`, `USI1_A_KastenRueckwand` (Schublade 1, entsprechend `B` bis `D`), `USI1_Verkleidung`, `USI1_WangeL`, `USI1_WangeR`, `USI1_Theke`, dazu die Gruppen `USI1_A_Schublade` usw. Das Kürzel ist `USI1`, oder `USI2` usw., wenn es im Modell schon vergeben ist.

An jedem Teil steht das Wörterbuch `JT_Schrank` mit `schrank`, `typ` (`Unterschrank_Insel`), `kategorie` (`Unterschrank`), `bereich`, `teil` und `rolle`. Neu in der gemeinsamen Rollen-Tabelle: `Verkleidung` und `Theke`.

## TCN-Export (Plugin Schrank-CNC)
Korpus, Türen, Einlegeböden und Schubladen laufen wie bei den anderen Unterschränken: Dübel der Böden und Streben, Sockelfüße im Boden, Lochreihen bei Türen, LEGRABOX-Schienenbohrungen, Frontbefestigung und Bodenfalz bei Schubladen. Verkleidung, Wangen und Thekenplatte bekommen eine TCN nur mit Formatieren.

## Hilfe in SketchUp
Eine Kurzfassung (ein Satz, `HILFE_KURZ` in `src/unterschrank_insel/main.rb`) steht oben im Fenster *Komponentenoptionen* und als Beschreibung der Komponente. Die ausführliche Doku steht nur hier, damit das Fenster ganz lesbar bleibt.

## Tests
`ruby test/test_unterschrank_insel.rb` prüft ohne SketchUp (Mock-API und DC-Formel-Auswerter) Korpus, Türen, Schubladen, Verkleidung, Wangen und Theke, Kollisionen, Formeln nach Umkonfigurieren, nachträgliche Tiefenänderung, Materialien, Anleimer, Tags, `JT_Schrank`, den Dialog und die Kurzhilfe. Der Plugin-Test `sketchup-tcn-export-plugin/test/test_export.rb` prüft die TCN-Dateien und die Frontfarbe.
