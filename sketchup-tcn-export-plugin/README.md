# SketchUp TCN-Export-Plugin („Schrank-CNC“)

**Stand: nur Planung, noch kein Code.**

Das Plugin soll im Modell alle Teile der Schränke aus `Komponenten/` finden, jedes Teil an seinem Tag erkennen und je Teil eine TCN-Datei für TpaCAD schreiben, dazu Fräsliste (`.xmlst`) und Teileliste (`.csv`).

* Ausführlicher Plan mit offenen Fragen: [Plan: TCN-Export für Schrank-Komponenten](https://claude.ai/artifact/1txhjwKrxeGrWi3j7F5wNN)
* Vorbild für den TCN-Writer: [jimmycd/sketchup-treppenbauer](https://github.com/jimmycd/sketchup-treppenbauer) (`src/jt_treppenbau/tcn.rb`, `fraesliste.rb`)
* `beispiele/` – Jürgens 11 Beispiel-TCN-Dateien (Boden, Deckel, Strebe, Seite, Seiten_Duebel, Seiten_SK_L/R, Schubkastenboden, SK_Vorderstueck_Frontbef, T_re_L_Topfband, T_rR). Sie sind parametrisch (`x`, `y`, `s`) und nutzen die Makros `squad`, `fittingx`/`fittingy`, `inge100` und `rect`; sie sind die Vorlage für die Bearbeitungsregeln.

## Grundidee
1. Teile einsammeln (sichtbare Instanzen mit Tag nach dem Schema `<Kürzel>_<Bereich>_<Teil>`).
2. Teile vermessen, Anleimer wie OpenCutList aus den Kantenflächen lesen, Lagen im Fräsmaß.
3. Stöße zwischen Teilen finden und daraus Dübel, Lochreihen, Topfbänder und Schienenbohrungen ableiten.
4. Eine TCN je Tag schreiben, dann Fräsliste und Teileliste.

## Geplante Schritte
1. Tags aller Komponenten vereinheitlichen.
2. Schubkasten auf Jürgens Standard umbauen (Boden 16 mm tragend), falls gewünscht.
3. Erster Export nur Korpus, Vergleich mit den Beispiel-TCN.
4. Lochreihen und Bodenbohrungen.
5. Schubladen.
6. Türen.
7. Dialog, Listen, eigene `.rbz`.
