# Plan: Hochschrank Kühlschrank (HK)
> Status: umgesetzt in `Komponenten/hochschrank_kuehlschrank/`. Original: [Plan-Dokument](https://claude.ai/artifact/GrSJxRVUZYqDuxqjxQRxsy) (Stand 02.11.2026, mit Jürgens Antworten)

Neue Komponente **Hochschrank Kühlschrank** (Kürzel `HK`, Menü *Küchenplaner › Hochschränke › Hochschrank Kühlschrank…*) auf Basis des Hochschranks Geräte: unten optional Schubladen, darüber eine Nische für einen Einbau-Kühl- oder Gefrierschrank mit Möbeltür(en), oben ein Fach mit Tür oder offen. Standard: 600 × 2100 mm, keine Schubladen, Nische 1780 mm, Schlepptür, Lüftungsschacht hinten, oben Tür. Tiefe im Dialog: Vorschlag 560 mm, weil Einbau-Kühlgeräte mindestens 550 mm Nischentiefe brauchen.

## Nischenmaße
Lichte Höhe 880, 1020, 1220, 1400, 1580, 1780, 1940 mm oder frei (übliche Rastermaße von Bosch, Siemens, Neff, Miele, Liebherr; im Zweifel Einbauskizze prüfen). Breite 560–570 mm, Tiefe mindestens 550 mm. Kennung in `JT_Nische_N1`: `Kuehlgeraet<cm>`, dazu `art` = `Kuehlschrank`, `Gefrierschrank` oder `KuehlGefrier`.

## Lüftung
Empfohlen und Standard: **Schacht hinten über die ganze Höhe** (40 mm, einstellbar). Nische ohne Rückwand; Böden, Einlegeböden und Deckel enden vor Schacht und Rückwand; oberes Fach und Schubladenbereich haben eigene Rückwände in einer Nut der Seiten, um den Schacht nach vorn versetzt. Zuluft durch das Sockelgitter (nicht Teil des Schranks), Abluft oben. Alternative: Lüftung über Sockel und Front mit durchgehender Rückwand.

## Türen
Schlepptür (Topfbänder am Korpus, Gerätetür läuft über die Gleitschiene mit) oder Festtür (Möbeltür auf der Gerätetür), wählbar. Kühl-Gefrier-Kombi mit zwei Türen, Teilung über die Höhe der unteren Tür einstellbar. Anschlag links oder rechts.

## Antworten von Jürgen (02.11.2026)
* Lüftungsschacht 40 mm und Tiefe 560: Vorschlag ok.
* Schlepptür oder Festtür: wählbar.
* Teilung der Kombi-Türen: einstellbar machen.
