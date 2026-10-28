> Quelle: [Plan: Eck-Unterschrank (einfach, doppelt, Le Mans)](https://claude.ai/artifact/Tw9s6uuZSr6NpYj1Xuf3TU) (Plan-Dokument aus dem Projekt-Thread, Stand 28.10.2026)  
> Status: **noch offen**: Plan in Arbeit, noch nicht gebaut

# Plan: Eck-Unterschrank (einfach, doppelt, Le Mans)

Oct 25, 2026 · @Jürgen Späder

Ein Generator-Skript `Komponenten/eckschrank/eckschrank.rb` erzeugt eine Dynamic Component „Eck-Unterschrank“ mit der Option Variante (einfach, doppelt, Le Mans), nach denselben Regeln wie Ober- und Hochschrank: OCL-Material, Anleimer nur in OCL, eigener Tag je Teil, JT\_Schrank, Kurzhilfe, Tests. Gebaut wird erst nach deiner Freigabe.

## Die drei Varianten

Meine Lesart von „einfach, doppelt, Le Mans“ (bitte bestätigen, siehe offene Fragen):

| Variante | Grundriss | Front | Innenleben |
| --- | --- | --- | --- |
| einfach | Blindeckschrank, gerader Korpus, ein Teil der Breite steckt hinter der Nachbarzeile | eine Tür + feste Blende über dem Blindteil | 0–2 Einlegeböden |
| doppelt | L-Eckschrank (90°, z. B. 900 × 900 mm) | zwei Türen, als Falttür verbunden | 0–2 L-förmige Einlegeböden (aus zwei Teilen) |
| Le Mans | Blindeckschrank wie „einfach“ | eine Tür + Blende | Kesseböhmer LeMans II Schwenkauszug (2 Tablare) statt Einlegeböden |

Einfach und Le Mans teilen sich denselben Korpus; nur das Innenleben und die Türbreite unterscheiden sich. Le Mans ist ein Kesseböhmer-Beschlag (Blum hat keinen), die Tür hängt trotzdem an Blum-Topfbändern.

Die Blindseite (links oder rechts) ist eine Option, damit der Schrank in beide Ecken passt.

## Komponentenoptionen

Höhe, Tiefe, Materialstärken, Strebenbreite und Fuge übernehme ich vom Unterschrank mit Tür, damit der Eckschrank bündig in der Zeile steht. Neue Standardwerte sind Vorschläge:

| Option | Werte | Standard (Vorschlag) |
| --- | --- | --- |
| Variante | einfach / doppelt / Le Mans | einfach |
| Blindseite (einfach, Le Mans) | links / rechts | links |
| Breite (einfach, Le Mans) | frei | 1000 mm |
| Türbreite (einfach, Le Mans) | frei; Le Mans 400 / 450 / 500 / 600 (Korpus mind. 764 / 800 / 910 / 960 mm breit) | 500 mm |
| Breite links / rechts (doppelt) | frei, je Schenkel | 900 / 900 mm |
| Passleiste | Breite der Leiste zwischen Blende und Nachbarschrank, damit Tür und Griff nicht anstoßen | 50 mm |
| Anzahl Einlegeböden (nicht Le Mans) | 0–2 | 1 |
| Höhe / Tiefe | wie Unterschrank mit Tür | 700 / wie Unterschrank |

Die Blendenbreite rechnet die Komponente selbst aus: Breite − Türbreite − Fugen. Ist der Blindteil kleiner als Tiefe des Nachbarschranks + Front + Passleiste, steht in der Kurzhilfe ein Hinweis (eine DC kann keine Fehlermeldung zeigen).

## Aufbau, Anleimer und Tags

Alle Teile bleiben rechteckige Platten, damit OCL und der TCN-Export ohne Konturfräsen auskommen. Gezeichnet wird im Endmaß, Anleimer nur als OCL-Zuweisung („Anleimer Melamin weiss“, 2 mm, abziehen), Platten in „Melamin weiss“, Fronten im Frontmaterial.

**Blindeck (einfach, Le Mans):** Aufbau wie Unterschrank mit Tür: SeiteL/R, Boden, StrebeVorn/-Hinten, Rückwand, Tür, Blende, Passleiste, Einlegeböden. Die Blende wird von innen an die Strebe und die Seite geschraubt.

**L-Eck (doppelt):** zwei Seiten an den offenen Enden, L-förmiger Boden aus einem Teil (Innenecke gefräst), je Schenkel eine StrebeVorn und eine StrebeHinten, zwei Rückwände (eine überlappt in der Ecke), TürL und TürR, L-förmige Einlegeböden, ebenfalls gefräst.

| Teil | Anleimer | Tag (Beispiel) | Rolle |
| --- | --- | --- | --- |
| Seiten | vorne | UES1\_SeiteL | Seite |
| Boden, Bodenteile | vorne | UES1\_Boden1 | Boden |
| Streben | keine | UES1\_StrebeVorn1 | Strebe |
| Rückwand | keine | UES1\_Rueckwand1 | Rueckwand |
| Einlegeböden | vorne | UES1\_Einlegeboden1 | Einlegeboden |
| Tür(en), Blende | alle vier | UES1\_Tuer, UES1\_Blende | Tuer, Front |
| Passleiste | vorne + sichtbare Stirnseite | UES1\_Passleiste | Front |
| LeMans-Tablare | – (Beschlag, OCL-Typ Zubehör) | UES1\_LeMans | Beschlag |

Kürzel `UES<n>` (Unterschrank Eck), `kategorie` Unterschrank, `typ` Eckschrank. Damit greifen Frontfarbe und die Unterschrank-Auswahl ohne Änderung. Die neuen Teilnamen (Blende, Passleiste, LeMans, nummerierte Bodenteile) kommen in die gemeinsame ROLLEN-Tabelle aller Komponenten, wie der Test es verlangt.

Die Tablare zeichne ich nur vereinfacht als Platzhalter, damit man den Schwenkraum sieht. In OCL erscheinen sie als Zubehör, nicht im Zuschnitt.

## TCN-Export und Beschläge

Der Korpus nutzt die vorhandenen Regeln (Dübel Seite–Boden/Strebe, Sockelfüße, Lochreihen bei Einlegeböden). Der Export rechnet mit achsparallelen Quadern, das passt auch für das L-Eck, weil alle Teile rechtwinklig stehen. Neu im Plugin:

- Konturfräsung für L-förmige Böden: Fräsbahn um die Innenecke, Werkstück = umschließendes Rechteck wie in OCL.
- Blende und Passleiste: Schraublöcher von innen durch Seite bzw. Strebe (Lage nach deinem Standard, sonst wie Deckel–Rückwand: je 50 mm vom Rand + Mitte).
- Teile mit Rolle Beschlag werden nicht exportiert.
- Le Mans: keine Einlegeboden-Lochreihe; stattdessen die Bohrungen für Säulenlager und Seitenprofil nach Montageanleitung (Abschnitt unten).
- Falttür (doppelt): Blum-Topfbänder an der Seite, zwischen den Türen ein Blum-Falttürscharnier. Die Topfbandbohrungen kommen mit Schritt 8 des Export-Plans (Türen); bis dahin exportiere ich Türen ohne Topf.

## Le Mans nach Montageanleitung

Aus deiner Kesseböhmer-Anleitung LeMans II (MA 406954 0000, Rev. 2025-11-10). Unser Unterschrank erfüllt alle Bedingungen: Tiefe ≥ 500, Seiten ≥ 16, obere Strebe ≥ 60 breit (wir haben 100), Säule 600–750 passt zur Innenhöhe von etwa 680 mm. Die Tür muss aufschlagend sein (Vollanschlag), wie bei uns.

| Modell | Tür / lichte Öffnung max. | Korpus min. | X: Seite innen bis Säulenlager |
| --- | --- | --- | --- |
| LeMans 40 | 400 mm | 764 mm | 426 mm |
| LeMans 45 | 450 mm | 800 mm | 476 mm |
| LeMans 50 | 500 mm | 910 mm | 526 mm |
| LeMans 60 | 600 mm | 960 mm | 626 mm |

Bohrungen, die der TCN-Export setzen würde (meine Lesart der Zeichnung auf Seite 11):

- **Boden (oben) und StrebeVorn (unten)**, je ein Säulenlager: 1× Ø5 für die Systemschraube Ø6,3 × 13, Mitte X − 26 von der Innenseite der Schwenkseite, 53 + 16 = 69 mm hinter der Vorderkante; dazu 2 Ø4,5-Schrauben im Abstand 32 auf der Linie 53 mm (nur angekörnt oder Ø3 vorgebohrt).
- **Seite auf der Türseite**, Profil für die Schwenkarme: Lochreihe 52 mm hinter der Vorderkante, Raster 64 mm, 8 Löcher (Profil 500) oder 9 Löcher (Profil 600), Ø5 für Systemschraube Ø6,3; Profil beginnt 28 mm über dem Boden.

Der Karton enthält eine Bohrschablone. Ich würde die Maße einmal mit der Schablone auf einem Probeteil abgleichen, bevor wir sie fest einbauen.

## Umsetzung und Tests

Nach Freigabe ein Branch von main und ein PR, den du mergst:

1. `Komponenten/eckschrank/eckschrank.rb`: wie beim Oberschrank einmal per `load` in der Ruby-Konsole ausführen, erzeugt `Eckschrank.skp` neben dem Skript. Kurzhilfe (HILFE) in Summary/Description, README.md als Kurzdoku.
2. ROLLEN-Tabelle in allen Komponenten um die neuen Teile erweitern.
3. Plugin Schrank-CNC: Boden–Boden-Stoß, Blendenverschraubung, Beschlag überspringen; `schrank_cnc.rbz` neu bauen.
4. Tests ohne SketchUp (Mock + Formel-Auswerter): jede Variante und beide Blindseiten, Maße nach Umkonfigurieren, Fugen, OCL-Material und Anleimer, eindeutige Tags, JT\_Schrank, Kurzhilfe; Export-Test mit einem Eckschrank je Variante. `./run_tests.sh` und GitHub Actions grün.

In echtem SketchUp ist danach noch dein Blick nötig, vor allem auf die Falttür-Animation und den Schwenkraum von Le Mans.

Später möglich: Karussell (Dreiviertel- oder Halbkreis) als vierte Variante.

## Offene Fragen an Jürgen

- [x] „doppelt“: beides wählbar. Variante hat damit vier Werte: einfach (Blindeck, 1 Tür), Blindeck 2 Türen, L-Eck mit Falttür, Le Mans.
- [x] Standardmaße ok: Blindeck 1000 mm mit Tür 500 mm, L-Eck 900 × 900 mm, Passleiste 50 mm.
- [x] L-Eck-Boden und L-Einlegeböden aus einem Teil, Kontur gefräst. Der TCN-Export bekommt dafür eine Konturfräsung (Ausschnitt der Innenecke), OCL rechnet mit dem Rechteck als Zuschnitt.
- [ ] Le Mans: Standard LeMans 50 (Tür 500), Bohrungen per CNC, Seitenprofil 500 (8 Löcher).
- [x] Falttür: Blum-Standardscharnier zwischen den Türen (Topf in der Tür an der Ecke, Montageplatte auf der anderen Tür).

Wenn du „passt“ schreibst, baue ich mit den Vorschlägen und setze Le Mans zuerst ohne Beschlagbohrungen um.

Quelle Türbreiten LeMans II (400–600 mm): [Hranipex, LeMans II Arena](https://www.hranipex.com/de/produkt/kesse-lemans-ii-2-tablare-arena-pure-links-w600-anthrazit-fwf005394)
