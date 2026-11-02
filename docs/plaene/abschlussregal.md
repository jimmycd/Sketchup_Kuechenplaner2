> Quelle: [Plan: Abschlussregal fürs Zeilenende](https://claude.ai/artifact/NdzRUu3Dk3ubmfMjxLifPM) (Plan-Dokument aus dem Projekt-Thread, Stand 02.11.2026)
> Status: umgesetzt in `Komponenten/regal_abschluss/` (Kürzel `RA`), siehe [README](../../Komponenten/regal_abschluss/README.md)

# Plan: Abschlussregal fürs Zeilenende

Offenes Regal ohne Front am Ende einer Schrankzeile, gerade oder mit Schräge, als Unter-, Ober- oder Hochschrank.

## Jürgens Antworten (02.11.2026)

| Frage | Antwort |
|---|---|
| Typen: alle drei (Unter-, Ober-, Hochschrank) oder nur Unterschrank? | alle |
| Schräge mit Tiefe außen 150 mm; zusätzlich runde Variante (Viertelkreis)? | ja, mit echtem Bogen |
| Einlegeböden verstellbar (Bodenträger) oder fest gedübelt? | als Auswahl |
| Farbe: geht das Regal bei „Frontfarbe ändern“ mit oder bleibt es Korpusfarbe? | als Auswahl |
| Arbeitsplatte: Schräge im Generator oder von Hand? | von Hand |
| Zusatz | OpenCutList ist nicht mehr im Einsatz: Stückliste, Zuschnitt und Etiketten laufen über das eigene Plugin |

## Umsetzung

* Komponente `regal_abschluss`, Menüeintrag *Abschlussregal…* in Unter-, Ober- und Hochschränken (Typ = Kategorie).
* Seite innen volle Tiefe, Seite außen je Form (gerade: voll, schräg: Tiefe außen, rund: Tiefe − Radius), Boden, Deckel statt Streben, Rückwand hinter dem Korpus, 0–6 Einlegeböden verstellbar oder fest.
* Nach jeder Änderung in den Komponentenoptionen baut die Erweiterung das Regal neu auf (eine Schräge lässt sich nicht per DC-Formel umformen), wie die L-Form des Eckschranks.
* Anleimer an Schräge und Bogen; das eigene Plugin rechnet diese Kante nicht ins Rechteck, sondern führt sie in der Stückliste als *Kante Kontur* mit Länge.
* TCN: Rechteck zuschneiden, Kontur mit Fräser 1004 (Ø 20) ganz durch, um den Anleimer versetzt, Ein- und Auslauf außerhalb der Platte, Bögen als `W#2125`. Sockelfüße rücken bei Schräge/Bogen nach innen.
* Farbe „Frontfarbe“: Teile tragen `JT_Schrank/frontfarbe`, *Frontfarbe und Griffe ändern* färbt sie mit, ohne Griffe.
