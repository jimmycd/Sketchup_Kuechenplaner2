# Oberschrank mit Klappe (Dynamic Component)

Oberschrank mit einer Klappe statt Türen, Beschlag Blum **AVENTOS**: wahlweise **HK-top** (eine Klappe, schwenkt nach oben) oder **HF** (Faltklappe aus zwei Teilen, für hohe Schränke). Der Korpus ist derselbe wie beim [Oberschrank](../oberschrank/).

## Installieren und benutzen
1. SketchUp → *Erweiterungen → Extension Manager → Erweiterung installieren* → `oberschrank_klappe.rbz` wählen (oder `Kuechenplaner_alle.rbz` aus dem Hauptordner).
2. *Erweiterungen → Küchenplaner → Oberschränke → Oberschrank mit Klappe…* (oder Symbolleiste *Schrank einfügen*) fragt Breite, Höhe, Tiefe und Klappenart ab und baut den Schrank. Passt die Höhe nicht zur Klappenart, kommt ein Hinweis. Danach hängt der Schrank am Andock-Werkzeug.

## Komponentenoptionen
| Option | Standard |
|---|---|
| Breite / Höhe / Tiefe (Korpus ohne Front) | 900 / 400 / 400 mm |
| Klappe | HK-top (eine Klappe) oder HF (Faltklappe, zwei Teile); Standard HK-top |
| Anzahl Einlegeböden | 0–2, gleichmäßig verteilt; Standard 0 |

Alles bleibt nachträglich änderbar, auch die Tiefe; alle Teile folgen per Formel.

Korpushöhen laut Blum (nur Hinweis, nicht erzwungen): HK-top etwa 205–600 mm, HF etwa 480–1040 mm.

Feste Maße als Attribute (Fenster *Komponentenattribute*): `Materialstaerke_Korpus` 19 mm, `Materialstarke_Rueckwand` 8 mm, `Rueckwand_Versatz` 25 mm, `Nuttiefe` 9 mm, `Spaltbreite` 2 mm, `Rueckversatz_Einlegeboden` 10 mm.

Mit *Interagieren* öffnet sich die Klappe nach vorne oben. Bei HF erst das obere Teil anklicken (schwenkt hoch), dann das untere (faltet).

## Aufbau
* Korpus wie beim Oberschrank: Seiten über die volle Höhe und Tiefe, Boden und Deckel zwischen den Seiten, **Rückwand** 8 mm in einer 9 mm tiefen Nut in Seiten und Boden, 25 mm vor der Hinterkante (Fach für die Aufhängung). Der **Deckel** endet vor der Rückwand und wird mit ihr verschraubt (Bohrungen setzt der TCN-Export).
* **Klappe** 2 mm vor dem Korpus, außen 1 mm Fuge: Breite − 2 mm.
  * HK-top: Höhe − 2 mm.
  * HF: zwei gleich hohe Teile, je Höhe/2 − 2 mm, mit 2 mm Fuge dazwischen.
* Einlegeböden 10 mm von vorne zurückgesetzt, hinten bis zur Rückwand.

Die AVENTOS-**Bohrungen** (Kraftspeicher in den Seiten, Frontbeschläge in der Klappe, bei HF die Scharniere zwischen den Teilen) setzt der TCN-Export noch nicht; das folgt mit der Blum-Montageanleitung. Am Schrank steht im Wörterbuch `JT_Schrank` der Eintrag `beschlag` (AVENTOS HK-top bzw. HF beim Erzeugen).

## Material und Kanten
Gezeichnet ist immer das **Endmaß**. Platten haben „Melamin weiss“, sichtbare Kanten das Kantenmaterial „Anleimer Melamin weiss“ (2 mm, wird erst in Stückliste/Zuschnitt abgezogen).

| Teil | Kanten mit Anleimer |
|---|---|
| Seiten | vorne, unten, oben |
| Boden, Deckel, Einlegeböden | vorne |
| Rückwand | keine |
| Klappe (alle Teile) | alle vier |

## Tags
Jedes Teil hat einen eigenen Tag `<Kürzel>_<Teil>`: `OK1_SeiteL`, `OK1_SeiteR`, `OK1_Boden`, `OK1_Deckel`, `OK1_Rueckwand`, `OK1_Einlegeboden1` und `2`, `OK1_Klappe` (HK-top) bzw. `OK1_KlappeO` und `OK1_KlappeU` (HF). Das Kürzel ist `OK1`, oder `OK2` usw., wenn es im Modell schon vergeben ist.

An jedem Teil steht das Wörterbuch `JT_Schrank` mit `schrank`, `typ` (Oberschrank_Klappe), `kategorie` (Oberschrank), `bereich`, `teil` und `rolle`. Die Klappenteile haben die Rolle *Front*, damit Frontfarbe, Griffe und Stückliste sie wie Fronten behandeln.

## Hilfe in SketchUp
Eine Kurzfassung (ein Satz, `HILFE_KURZ` in `src/oberschrank_klappe/main.rb`) steht oben im Fenster *Komponentenoptionen* und als Beschreibung der Komponente. Die ausführliche Doku steht nur hier, damit das Fenster ganz lesbar bleibt.

## Tests
`ruby test/test_oberschrank_klappe.rb` – prüft ohne SketchUp Geometrie (Korpus, Klappe und Fugen für HK-top und HF, Einlegeböden), Umkonfigurieren (Klappenart, Höhe, Breite), Tiefe nachträglich ändern, Material, Anleimer, Tags, `JT_Schrank`, Höhenhinweis und Kurzhilfe.
