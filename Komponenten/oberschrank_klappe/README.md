# Oberschrank mit Klappe (Dynamic Component)

Oberschrank mit einer Klappe statt Türen, die nach oben schwenkt. Beim Anlegen wählt man **eine Klappe** oder **Faltklappe (zweiteilig)**. Der Beschlag dazu gilt für die ganze Küche und wird in *Küchenplaner › Einstellungen…*, Abschnitt *Beschläge*, gewählt: eine Klappe Blum **AVENTOS HK top**, **HS top**, **HL top** oder **Häfele Free Slim**, Faltklappe Blum **AVENTOS HF top**. Der Korpus ist derselbe wie beim [Oberschrank](../oberschrank/).

## Installieren und benutzen
1. SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `oberschrank_klappe.rbz` wählen (oder `Kuechenplaner_alle.rbz` aus dem Hauptordner).
2. *Erweiterungen → Küchenplaner → Oberschränke → Oberschrank mit Klappe…* (oder Symbolleiste *Schrank einfügen*) fragt Breite, Höhe, Tiefe und Klappe (eine Klappe / Faltklappe) ab und baut den Schrank. Passt die Höhe nicht zur Klappenart, kommt ein Hinweis. Danach hängt der Schrank am Andock-Werkzeug.

## Komponentenoptionen
| Option | Standard |
|---|---|
| Breite / Höhe / Tiefe (Korpus ohne Front) | 900 / 400 / 400 mm |
| Anzahl Einlegeböden | 0–2, gleichmäßig verteilt; Standard 0 |

Alles bleibt nachträglich änderbar, auch die Tiefe; alle Teile folgen per Formel.

Korpushöhen laut Hersteller (nur Hinweis, nicht erzwungen, Blum-Katalog 2024/2025): HK top 205–600 mm, HS top 350–800 mm, HL top 300–580 mm, HF top 480–1200 mm, Free Slim 225–650 mm (Breite bis 1800 mm). Passt der Beschlag der Küche nicht, kommt beim Anlegen ein Hinweis und im TCN-Export eine Meldung.

Feste Maße als Attribute (Fenster *Komponentenattribute*): `Materialstaerke_Korpus` 19 mm, `Materialstarke_Rueckwand` 8 mm, `Rueckwand_Versatz` 25 mm, `Nuttiefe` 9 mm, `Spaltbreite` 2 mm, `Rueckversatz_Einlegeboden` 10 mm.

Mit *Interagieren* öffnet sich die Klappe nach vorne oben. Bei HF erst das obere Teil anklicken (schwenkt hoch), dann das untere (faltet).

## Aufbau
* Korpus wie beim Oberschrank: Seiten über die volle Höhe und Tiefe, Boden und Deckel zwischen den Seiten, **Rückwand** 8 mm in einer 9 mm tiefen Nut in Seiten und Boden, 25 mm vor der Hinterkante (Fach für die Aufhängung). Der **Deckel** endet vor der Rückwand und wird mit ihr verschraubt (Bohrungen setzt der TCN-Export).
* **Klappe** 2 mm vor dem Korpus, außen 1 mm Fuge: Breite − 2 mm.
  * HK-top und Free Slim: Höhe − 2 mm.
  * HF: zwei gleich hohe Teile, je Höhe/2 − 2 mm, mit 2 mm Fuge dazwischen.
* Einlegeböden 10 mm von vorne zurückgesetzt, hinten bis zur Rückwand.

Die AVENTOS-**Bohrungen** setzt der TCN-Export nach dem Blum-Katalog 2024/2025. HK top (S. 48): Kraftspeicher 4 × Ø5 in den Seiten (37/69/133/165 mm ab Vorderkante, 36 mm unter der Oberkante) und Frontbefestigung 2 × 4 × Ø5 in der Klappe (12,5 mm ab Innenseite der Seiten, 62/94/126/158 mm unter der Oberkante). HS top und HL top: Kraftspeicher 2 × 2 Ø5 (101/229 mm ab Vorderkante, 63/127 mm unter der Oberkante), Frontbefestigung 4 × Ø5 ab 195 mm (HS) bzw. 113/153/203/256 mm je Hebel-Set nach Korpushöhe (HL) unter der Oberkante. HF top: Kraftspeicher 101/229 mm ab Vorderkante, 93,5/157,5 mm (Korpushöhe bis 519) bzw. 116/180 mm unter der Oberkante; Hebel an der unteren Klappe 2 × 2 Ø5, 170 bzw. 189 mm unter ihrer Oberkante; je Klappe zwei Töpfe Ø35 an der Oberkante (oben 120°-Scharnier mit Montageplatte unter dem Deckel, Mitte Zwischenscharnier mit Montageplatte auf der oberen Klappe), 100 mm vom Klappenrand (abgeleitet, im Katalog nicht bemaßt). Siehe siehe [TCN-Export](../../sketchup-tcn-export-plugin/README.md). Für **Free Slim** (Häfele Montageanleitung 732.23.046): Mechanismus je Seite 2 × Ø5 × 10 für die Dübel, 122,5 mm ab Vorderkante, 39,5 und 135,5 mm unter der Unterseite des Deckels; Frontbeschlag je Seite 4 × Ø3 × 5 im Raster 32, 12 mm ab Innenseite der Seiten, 36/68/100/132 mm unter der Unterseite des Deckels. Welche Bohrungen gesetzt werden, richtet sich nach dem Klappenbeschlag der Küche (Einstellungen › Beschläge); die Maße stehen im Beschlag-Katalog des Plugins (`katalog/*.json`). Das Attribut `Art_Klappe` (1 eine Klappe, 2 Faltklappe) steht nicht in den Komponentenoptionen; es wird beim Anlegen gewählt.

## Material und Kanten
Gezeichnet ist immer das **Endmaß**. Platten haben „Melamin weiss“, sichtbare Kanten das Kantenmaterial „Anleimer Melamin weiss“ (2 mm, wird erst in Stückliste/Zuschnitt abgezogen).

| Teil | Kanten mit Anleimer |
|---|---|
| Seiten | vorne, unten, oben |
| Boden, Deckel, Einlegeböden | vorne |
| Rückwand | keine |
| Klappe (alle Teile) | alle vier |

## Tags
Jedes Teil hat einen eigenen Tag `<Kürzel>_<Teil>`: `OK1_SeiteL`, `OK1_SeiteR`, `OK1_Boden`, `OK1_Deckel`, `OK1_Rueckwand`, `OK1_Einlegeboden1` und `2`, `OK1_Klappe` (HK-top, Free Slim) bzw. `OK1_KlappeO` und `OK1_KlappeU` (HF). Das Kürzel ist `OK1`, oder `OK2` usw., wenn es im Modell schon vergeben ist.

An jedem Teil steht das Wörterbuch `JT_Schrank` mit `schrank`, `typ` (Oberschrank_Klappe), `kategorie` (Oberschrank), `bereich`, `teil` und `rolle`. Die Klappenteile haben die Rolle *Front*, damit Frontfarbe, Griffe und Stückliste sie wie Fronten behandeln.

## Hilfe in SketchUp
Eine Kurzfassung (ein Satz, `HILFE_KURZ` in `src/oberschrank_klappe/main.rb`) steht oben im Fenster *Komponentenoptionen* und als Beschreibung der Komponente. Die ausführliche Doku steht nur hier, damit das Fenster ganz lesbar bleibt.

## Tests
`ruby test/test_oberschrank_klappe.rb` – prüft ohne SketchUp Geometrie (Korpus, Klappe und Fugen für HK-top, HF und Free Slim, Einlegeböden), Umkonfigurieren (Klappenart, Höhe, Breite), Tiefe nachträglich ändern, Material, Anleimer, Tags, `JT_Schrank`, Höhenhinweis und Kurzhilfe.
