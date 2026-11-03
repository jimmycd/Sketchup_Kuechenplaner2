# SketchUp-Plugin „Schrank-CNC“ (TCN-Export, Stückliste, Etiketten, Zuschnitt, Materialien, Frontfarbe, Andocken)

**Stand:** *Frontfarbe und Griffe ändern* ist fertig. Der TCN-Export schreibt den Korpus: Formatieren, Dübel Boden/Deckel/Zwischenboden/Strebe an die Seiten, Schrauben in die Streben, Lochreihen für Einlegeböden, Sockelfüße, die Rückwandnut im Oberschrank und im Spülenschrank sowie den Rückwand-Ausschnitt im Spülenschrank und den Rohrausschnitt im Oberschrank Dunstabzug. Für Schubladen (Blum LEGRABOX), den Hochauszug Häfele HU Slim Base Kesseböhmer LeMans II im Eckschrank und die Klappe Blum AVENTOS HK-top kommen die Schienenbohrungen in die Seiten, die Frontbefestigung in die Front und der Falz in den Kastenboden; Türen und Griffe folgen.

Das Plugin findet im Modell alle Teile der Schränke aus `Komponenten/` an ihrem Tag `<Kürzel>_<Bereich>_<Teil>` und am Wörterbuch `JT_Schrank`. Es schreibt je Teil eine TCN-Datei für TpaCAD, dazu Fräsliste (`.xmlst`) und Teileliste (`.csv`). Stückliste, Etiketten und Zuschnittplan ersetzen OpenCutList ([Plan](https://claude.ai/artifact/P3oz5CefPjFuUckMwss26v)).

* Ausführlicher Plan: [Plan: TCN-Export für Schrank-Komponenten](https://claude.ai/artifact/1txhjwKrxeGrWi3j7F5wNN)
* Vorbild für den TCN-Writer: [jimmycd/sketchup-treppenbauer](https://github.com/jimmycd/sketchup-treppenbauer) (`src/jt_treppenbau/tcn.rb`, `fraesliste.rb`)
* `beispiele/` – Jürgens 11 Beispiel-TCN-Dateien (Boden, Deckel, Strebe, Seite, Seiten_Duebel, Seiten_SK_L/R, Schubkastenboden, SK_Vorderstueck_Frontbef, T_re_L_Topfband, T_rR). Sie sind parametrisch (`x`, `y`, `s`) und nutzen die Makros `squad`, `fittingx`/`fittingy`, `inge100` und `rect`; sie sind die Vorlage für die Bearbeitungsregeln.

## Installieren
`schrank_cnc.rbz` im Erweiterungs-Manager installieren (*Erweiterung installieren*), oder `Kuechenplaner_alle.rbz` aus dem Hauptordner mit allen Komponenten. Die Einträge stehen unten im gemeinsamen Menü *Erweiterungen › Küchenplaner*, unter den Komponenten. Nach Änderungen an `src/` die `.rbz` im Hauptordner mit `./build_rbz.sh` neu bauen (der Test prüft das).

Wer vorher die Version 0.1 installiert hatte: Das alte Untermenü *Schrank-CNC* verschwindet nach dem Installieren der neuen `.rbz` und einem Neustart von SketchUp.

## Materialien (ohne OpenCutList)
*Erweiterungen › Küchenplaner › Materialien…* zeigt alle Platten und Anleimer aus Modell und Bibliothek, mit *Neue Platte*, *Neuer Anleimer*, *Bearbeiten* und *Löschen*. OpenCutList wird dafür nicht gebraucht.

| Platte | |
|---|---|
| Name, Farbe, Texturbild | Farbe als `#RRGGBB` oder `R,G,B`; Texturbild optional mit Bildbreite in mm |
| Verwendung | Korpus, Front oder Rückwand – Frontfarbe bietet die Front-Platten an, Korpusmaterial die Korpus- bzw. Rückwand-Platten |
| Stärke, Format | Plattenstärke und Rohplattenformat (Zuschnittplan) |
| Maserung | Ja: Zuschnitt dreht nicht, L der Stückliste ist die Seite in Faserrichtung |
| Anleimer | zugeordneter Anleimer; *automatisch* = Kante mit dem Dekor im Namen, sonst neu „Anleimer <Dekor>“ |

Anleimer: Name, Farbe, Dicke (wird in Stückliste und TCN abgezogen), Breite.

* Die Angaben stehen wie bisher im Wörterbuch `ladb_opencutlist` am Material (gleiches Format, alte Modelle und alle Komponenten laufen unverändert), dazu `JT_Material` (`verwendung`, `kante`). Nur `materialien.rb` liest und schreibt sie.
* **Bibliothek**: jedes gespeicherte Material steht auch in der Bibliothek auf diesem Rechner und wird in ein Modell übernommen, sobald man es dort auswählt.
* **Maserrichtung**: bei Platten mit Maserung läuft die Faser bei Fronten, Türen und Sichtteilen senkrecht, sonst längs der längeren Seite. *Maserrichtung…* im Fenster setzt für die ausgewählten Schränke/Teile *senkrecht*, *waagrecht*, *längere Seite* oder wieder *automatisch* (`JT_Schrank/maserung`).

## Korpusmaterial ändern
*Erweiterungen › Küchenplaner › Korpusmaterial ändern…*: Teile (Korpus = Seiten, Böden, Deckel, Streben, Zwischen-/Einlegeböden, Leisten, Wangen; oder Rückwände), Material, Bereich (alle, Ober-, Unter-, Hochschränke) und *Nur ausgewählte Schränke*. Fronten, Sichtteile und Schubkästen bleiben, die Anleimer der Teile bekommen den zugeordneten Anleimer. Kopien eines Schranks werden wie bei der Frontfarbe vorher eindeutig gemacht.

## Frontfarbe und Griffe ändern
*Erweiterungen › Küchenplaner › Frontfarbe und Griffe ändern…*

| Feld | Bedeutung |
|---|---|
| Frontmaterial | alle Platten mit Verwendung „Front“ aus Modell und Bibliothek (siehe *Materialien*; alte Modelle: Name beginnt mit „Front“). *Neues Frontmaterial…* legt eins an; gibt es noch keins, öffnet sich gleich dieses Formular. |
| Bereich | alle Schränke, nur Oberschränke, nur Unterschränke oder nur Hochschränke (`kategorie` in `JT_Schrank`) |
| Nur ausgewählte Schränke | Ja: nur Schränke, die gerade ausgewählt sind |
| Griffe | unverändert lassen, setzen oder entfernen |

Das Frontmaterial kommt auf Fronten und Türen (`rolle` Front, Tuer) und auf die Sichtteile ohne Griff: Verkleidung der Inselrückseite (`Verkleidung`) und Abschlusswangen (`Wange`, Inselschrank und Geschirrspüler). Griffe bekommen nur Fronten und Türen.
| Griff: Lochmaß, Lage, Höhe | Lochmaß in mm (z. B. 160), Lage seitlich links / Mitte / rechts, Höhe in mm ab Unterkante der Front |

Vor dem Ändern fragt das Plugin nach, z. B. „5 Fronten in 3 Schränken bekommen „Front Eiche 19mm“. Übernehmen?“ (gezählt werden sichtbare Fronten). Ein Schritt *Rückgängig* macht alles zurück.

Was geändert wird:
* Fronten sind alle Teile mit `rolle` Front oder Tuer, auch ausgeblendete Schubladen und Türen. Korpus und Schubkästen bleiben unverändert.
* Dazu Teile mit `JT_Schrank/frontfarbe` (Abschlussregal mit Farbe „Frontfarbe“): sie bekommen Material und Anleimer, aber keine Griffe.
* Das Material kommt an die Instanz und als DC-Attribut `material`, damit es ein Neuzeichnen der Dynamic Component übersteht.
* Die Anleimer der Fronten (Kantenflächen mit einem Anleimer-Material) bekommen den zugeordneten Anleimer der Platte; ohne Zuordnung eine Kante mit dem Dekor im Namen („Anleimer Eiche“ zu „Front Eiche 19mm“), sonst legt das Plugin „Anleimer <Dekor>“ an (2 mm, Abzug an) und merkt sich die Zuordnung.
* Teilen sich Schränke im Modell dieselbe Definition (z. B. zweimal derselbe Oberschrank eingefügt) und ist nur einer gewählt, macht das Plugin den Weg zu dessen Fronten eindeutig. Korpusteile bleiben geteilt.
* Griffe: Lochmaß, Lage und Höhe stehen danach an jeder Front in `JT_Schrank` (`griff_lochmass`, `griff_lage`, `griff_hoehe`, mm). Der TCN-Export setzt daraus die Griffbohrungen (Ø3, 5 tief).

## Schrank andocken
Neue Schränke muss man nicht mehr von Hand verschieben und drehen. Gilt für alle Schränke aus dem Menü *Unterschränke*, *Oberschränke* und *Hochschränke*.

**Anreihen ohne Maus:** Ist beim Erzeugen genau ein Schrank ausgewählt, steht der neue sofort rechts bündig daneben: gleiche Drehung, Rückwände in einer Flucht, gleiche Unterkante. Weil der neue Schrank danach ausgewählt ist, entsteht so eine Zeile von links nach rechts, einfach durch mehrmaliges Erzeugen.

**Andock-Werkzeug:** Ist nichts ausgewählt, hängt der neue Schrank als Vorschau an der Maus (blauer Kasten, Front rot):

| Maus über … | Ergebnis |
|---|---|
| einem Schrank (Seite, Deckel) | links oder rechts bündig daneben, je nach Hälfte unter der Maus; übernimmt Drehung und Höhe |
| der Front eines Schranks | quer davor, Rückseite in der Flucht von dessen linker bzw. rechter Seite (Ecke einer L- oder U-Küche, z. B. vor die Blindseite eines Eckschranks) |
| einer Wand des Raums ([Erweiterung Raum](../Komponenten/raum/)) | Rückseite an die Wand, rastet an Wandenden und Tür-/Durchgangslaibungen ein (Fang 100 mm); Unter- und Hochschränke stehen auf dem Fußboden des Raums (Korpusunterkante um die Sockelhöhe des Raums darüber, einstellbar unter *Raum › Raum bearbeiten…*), Oberschränke behalten ihre Höhe; Anzeige: Abstand links und rechts bis zum Wandende |
| einer anderen senkrechten Fläche | Rückseite an die Wand, Mitte unter der Maus, Front in den Raum |
| sonst | folgt der Maus auf seiner Höhe |

* **Tab** oder **Pfeil rechts/links**: um 90° drehen (am Nachbarn: gegenüber dem Nachbarn, z. B. für den zweiten Schenkel einer L-Küche, Rückwand an der Wand des Nachbarn)
* **Pfeil hoch/runter**: Rückwände bündig (Vorgabe) oder Fronten bündig, wenn die Schränke verschieden tief sind
* **Klick**: absetzen (ein Schritt *Rückgängig*), **Esc**: Schrank bleibt, wo er erzeugt wurde
* Höhe: Unterkanten gleich; ein Oberschrank neben einem Hochschrank bekommt dieselbe Oberkante; Ober- neben Unterschrank behält seine Höhe.
* Ausgeblendete Teile (z. B. abgeschaltete Wangen) zählen für die Maße nicht.

Einen vorhandenen Schrank neu andocken: auswählen und *Erweiterungen › Küchenplaner › Schrank andocken…*.

Ohne Schrank-CNC-Erweiterung erzeugen die Komponenten ihre Schränke wie bisher rechts neben dem Modell. Die Rechnung steht in `src/jt_schrank_cnc/andocken.rb` (Modul `Rechnung`), getestet in `test/test_andocken.rb`. In echtem SketchUp noch nicht ausprobiert.

## Stückliste
*Erweiterungen › Küchenplaner › Stückliste…* ersetzt die Stückliste aus OpenCutList. Sie fragt nach einem Ordner, schreibt `Stueckliste.csv` (Semikolon, Dezimalkomma, Windows-1252 für Excel) und `Stueckliste.html` und öffnet die Druckseite im Browser (A4 quer, je Material und Stärke eine Tabelle mit Stückzahl, Rohfläche und Anleimer-Laufmetern). Ist etwas ausgewählt, nur die Teile der ausgewählten Schränke.

* Eine Zeile je TCN-Datei wie beim TCN-Export (gleiche Teile zusammengefasst, Spalte Anzahl), mit laufender Nummer, Tag und TCN-Dateiname. So passen Stückliste, TCN und Fräsliste immer zusammen.
* **Fertigmaß** = Maß im Modell, **Fräsmaß** = Fertigmaß minus Anleimer an jeder Kante mit Anleimer (= DL/DH der TCN), **Rohmaß** = Fräsmaß plus Übermaß (Zuschnitt an der Formatsäge). L ist die längere, B die kürzere Seite.
* Kanten: L1/L2 die beiden Längskanten, B1/B2 die Querkanten, jeweils mit dem Anleimer-Material (auf der Druckseite als Kürzel A, B … mit Legende).
* Maserung: aus dem Material (*Materialien…*). Mit Maserung ist L die Seite in Faserrichtung (Fronten senkrecht, siehe Maserrichtung), sonst die längere Seite.
* Arbeitsplatten stehen mit ihren Maßen drin (ohne Übermaß, Zuschnitt von Hand).

## Etiketten
*Erweiterungen › Küchenplaner › Etiketten…* ersetzt die Etiketten aus OpenCutList. Ein Etikett je Stück (Anzahl 3 = „1/3“, „2/3“, „3/3“), in der Reihenfolge und mit den Nummern der Stückliste. Inhalt: Tag, Nummer, Schrank · Teil, Material und Stärke, Rohmaß (fett), Fertigmaß, TCN-Dateiname und ein Kantenbild (Länge waagrecht, Anleimer als dicke Linie: L1 unten, L2 oben, B1 links, B2 rechts). Ist etwas ausgewählt, nur die Teile der ausgewählten Schränke.

Vor dem Schreiben fragt ein Fenster das Format ab (vorbelegt mit dem zuletzt benutzten, gespeichert für alle Modelle):

| Feld | Standard | Bedeutung |
| --- | --- | --- |
| Art | Bogen | **Bogen**: A4 hoch, Etiketten in Spalten × Zeilen. **Endlos**: Etikettendrucker mit Rolle, je Etikett eine Seite in Etikettengröße |
| Etikett Breite / Höhe | 70 × 37 mm | Größe eines Etiketts |
| Spalten / Zeilen | 3 × 8 | nur Bogen |
| Rand oben / links | 0,5 / 0 mm | nur Bogen, Abstand der ersten Etikettkante vom Blattrand |
| Abstand waagrecht / senkrecht | 0 / 0 mm | nur Bogen, Lücke zwischen den Etiketten |
| QR-Code | nein | ja: QR-Code mit dem TCN-Dateinamen (die QR-Bibliothek kommt beim Öffnen aus dem Internet) |
| erstes freies Etikett | 1 | angebrochener Bogen: Nummer des ersten freien Etiketts, zeilenweise von oben links |

Danach fragt es nach einem Ordner, schreibt `Etiketten.html` und öffnet sie im Browser. Drucken mit Größe 100 % (nicht „an Seite anpassen“) und ohne Ränder; die Seitengröße steht in der Datei (`@page`), beim Endlos-Drucker also die Etikettengröße.

## Zuschnittplan
*Erweiterungen › Küchenplaner › Zuschnittplan…* ersetzt den Zuschnitt aus OpenCutList, gedacht für die Formatsäge (alles von Hand, kein Zuschnittprogramm). Je Material und Stärke verteilt der Guillotine-Optimierer BinPacking2D (aus OpenCutList übernommen, siehe [THIRD_PARTY.md](THIRD_PARTY.md)) die **Rohmaße** der Stückliste auf Platten, nur mit durchgehenden Schnitten. Ist etwas ausgewählt, nur die Teile der ausgewählten Schränke.

* Plattenformat aus dem Material (*Materialien…*), sonst 2800 × 2070 mm.
* Schnittbreite und Besäumen aus den *Einstellungen* (Standard 3 mm und 10 mm je Plattenkante).
* Maserung am Material (`grained`): dann wird nicht gedreht, die Teillänge L liegt längs der Platte.
* Arbeitsplatten und Teile ohne Material bleiben draußen (Hinweis). Teile, die nicht auf die Platte passen, stehen in der Übersicht unter „passt nicht“.

Ausgabe `Zuschnitt.html` (A4 quer, im Browser drucken): Übersicht je Material (Platten, Teile, Ausnutzung), dann je Platte eine Seite mit maßstäblicher Skizze (Teilnummern wie Stückliste und Etiketten, Reste schraffiert, Schnitte rot und nummeriert) und daneben die **Schnittliste in Reihenfolge**: zuerst Besäumen, dann die durchgehenden Schnitte, dann die Schnitte in den Streifen. Je Schnitt Richtung (längs/quer), Lage (`y =` bzw. `x =` ab der Plattenecke links oben) und Länge.

## Einstellungen
*Erweiterungen › Küchenplaner › Einstellungen…* hat zwei Bereiche.

**Küche – dieses Modell** (Sockel und Abstände, gespeichert im Modell, Wörterbuch `Kuechenplaner_Einstellungen`; ein neues Modell übernimmt die zuletzt eingegebenen Werte). Quelle ist `gemeinsam/einstellungen.rb`, die jede Erweiterung als `src/kuechenplaner_gemeinsam/einstellungen.rb` mitbringt; Lesen mit `Kuechenplaner::Einstellungen.sockelhoehe`, `.wandabstand`, `.abstand_oberschrank`, `.arbeitsplatte_staerke`, `.unterschrank_hoehe`, `.oberschrank_unterkante(model, boden)` (alles mm):

| Einstellung | Standard | wirkt auf |
| --- | --- | --- |
| Sockelhöhe – Stellfüße (mm), 0–300 | 100 | Korpusunterkante von Unter- und Hochschränken über dem Fußboden. Der Sockel sind verstellbare Füße: keine Zuschnitt- oder Holzteile, nur die Sockelblende davor |
| Abstand Schrankrückseite – Wand (mm) | 0 | Andocken an die Wand; die Arbeitsplatte reicht trotzdem bis an die Wand (minus ihren eigenen Wandabstand 5 mm) |
| Lichter Abstand Arbeitsplatte – Oberschrank (mm) | 550 | Unterkante Oberschrank = Sockel + Korpushöhe + Arbeitsplatte + Abstand (Standard 1390 mm) |
| Stärke Arbeitsplatte (mm) | 40 | Höhe der Oberschränke |
| Korpushöhe Unterschrank (mm) | 700 | Höhe der Oberschränke |

**CNC und Zuschnitt – alle Modelle** auf diesem Rechner (`Sketchup.write_default`, Sektion `JT_SchrankCnc`):

| Einstellung | Standard | wirkt auf |
| --- | --- | --- |
| Übermaß Länge gesamt (mm) | 10 | Rohmaß der längeren Seite, `OFFSET` der Fräsliste (halber Wert) |
| Übermaß Breite gesamt (mm) | 10 | Rohmaß der kürzeren Seite, `OFFSET` der Fräsliste (halber Wert) |
| Zuschnitt: Schnittbreite Sägeblatt (mm) | 3 | Abstand der Teile im Zuschnittplan |
| Zuschnitt: Besäumen je Plattenkante (mm) | 10 | Rand der Rohplatte, der zuerst abgeschnitten wird |

## TCN exportieren
*Erweiterungen › Küchenplaner › TCN exportieren…* fragt nach einem Ordner und schreibt je sichtbarem Teil eine TCN-Datei (Name = Tag, z. B. `USS1_Boden.tcn`) und `Teileliste.csv` (Datei, Anzahl, Schrank, Teil, Rolle, Material, DL, DH, DS, OCL-Teil). Ist etwas ausgewählt, nur die Teile der ausgewählten Schränke.

**Fräsliste** `Liste_<Ordnername>.xmlst` (Aufbau wie csv2tcn und Treppenbau): alle TCN des Exports zusammen für das TpaCAD-Board, mit vollem Windows-Pfad, `REPETITIONS` = Stückzahl und `FIELD` 9. Sortiert nach Größe: größte Fläche DL × DH zuerst, bei gleicher Fläche die längere. `OFFSET X/Y` = halbes Übermaß aus den *Einstellungen* (Länge für die längere, Breite für die kürzere Seite), weil die TCN im Fräsmaß ist und das Rohteil um das Übermaß größer; `length_increase`/`width_increase` aus OpenCutList werden nicht mehr gelesen; `OFFSET Z` = 0. `COMMENT` = Teilname in OCL (Name der Komponentendefinition, z. B. `Front S1`); denselben Namen hat die Teileliste in der Spalte OCL-Teil.

* Maße und Lagen sind **Fräsmaß** wie in OpenCutList: an jeder Seite mit Anleimer (Kantenfläche mit OCL-Kante, Typ 4) um dessen Stärke kleiner. DL ist die längere, DH die kürzere Plattenrichtung, DS die Stärke. Ausnahme Seiten: immer wie `Seite.tcn` DL = Höhe (Unterkante bei x = 0), DH = Tiefe, auch wenn die Seite tiefer als hoch ist.
* Stöße werden geometrisch gefunden: liegt die Stirnseite von Boden, Deckel, Zwischenboden oder Strebe an der Fläche einer Seite, gibt es eine Dübelreihe Ø8 (22 tief in die Stirnseite, 14 tief in die Seite wie `Seiten_SK`; Seiten sind immer gleich), mittig in der Plattenstärke. Boden/Deckel/Zwischenboden: erster und letzter Dübel 30 mm von der fertigen Kante (mit Anleimer), in der TCN (Fräsmaß) also 28 an einer Kante mit 2-mm-Anleimer und 30 ohne; „gerade Anzahl“ aus (0/0), Schritt ST errechnet: n = ⌈(L−60)/160⌉ + 1 Dübel, ST = (L−60)/(n−1) mit L = fertige Länge, also höchstens 160 mm Abstand (z. B. Tiefe 560, vorn Anleimer → 30 … x-28, 5 Dübel, ST 125). Die Seite bekommt dieselbe Reihe aus denselben Weltkoordinaten, nach dem Anleimen liegen die Löcher also übereinander. Strebe: genau 2 Dübel, 20 mm von der fertigen Kante (Fräsmaß 18 an der Kante mit Anleimer), ST = Abstand der beiden, 0/0 – wie `Strebe.tcn`. In die Seite kommt je Strebe eine Schraubbohrung Ø3, 21 tief, in der Mitte der Strebe.
* **Lochreihen** Ø5, 12 tief, Raster 32 in jeder Seite und jedem Fach ohne Schubladen zwischen zwei festen Böden (Boden, Zwischenboden, Deckel, Strebe): 35 mm von vorn und 35 mm vor der Hinterkante bzw. vor der Rückwandnut; in der Höhe ab 38 mm über dem Boden darunter bis 33 mm unter dem darüber (ergibt 55 … x-50 wie `Seite.tcn`). In Fächern mit Schubladen und in Gerätenischen (Fach über einem Boden mit `JT_Schrank`/`nische`, z. B. im Hochschrank Geräte) gibt es keine Lochreihe; das Schubladen-Lochraster (`Lochraster_Start`, `Lochraster`) dient dort nur zum Ausrichten der Schienen.
* **Schienen** (Blum LEGRABOX, Montageanleitung MD-015/4 S. 3, Bohrtiefe aus `Seiten_SK_L/R`): je sichtbarer Schublade Ø5, 14 tief, 37 und 69 mm ab Vorderkante der Seite und hinten je Nennlänge NL: 350 → 37+192/224, 400–500 → 37+224/256, 550–600 → 37+256/320, 650 → 37+320/416. NL steht als Attribut `NL` am Schrank und wird von dort gelesen; fehlt es, ist NL die größte mit NL + 3 ≤ lichte Tiefe (Vorderkante Seite bis Rückwand). Höhe = Kastenunterkante + `Hoehenoffset_Schiene`.
* **Frontbefestigung** (LEGRABOX, MD-015/4 S. 4; Bohrbild wie `SK_Vorderstueck_Frontbef.tcn`): Ø3, 5 tief in der Rückseite der Front, 14 mm von der Innenseite der Seite (= 14 + FA vom Frontrand), Löcher 0/32/96/128 mm übereinander. Das unterste sitzt 36 mm über der Kastenunterkante (mind. 51 mm über der Front-Unterkante); obere Löcher entfallen, wenn sie über dem Kasten lägen. Stehende Teile (Fronten, Rückwand) haben y = 0 an der Unterkante. Hängen mehrere Kästen an einer Front (Apothekerschrank), nennt das Attribut `front` am Kasten deren Bereich; die Hochfront bekommt das Bohrbild dann für jeden Kasten.
* **Kastenboden** (`Schubkastenboden.tcn`): Falz in der Unterseite an beiden Enden der Breite für die Zargen, Rechteck 38 mm breit über die ganze Tiefe + 20 mm und ein zweites 20 mm breit, beide 8 tief (W#1022 `rect.tmcr`). Die Ø3-Löcher aus der Vorlage fehlen, Blum sieht sie nicht vor. Die Kastenrückwand wird nur formatiert.
* **Hochauszug Häfele HU Slim Base** (schmaler Unterschrank mit Handtuchauszug, Montageanleitung 4004110659MKT „Dimensions for CNC“): Schienen nur in der Seite aus dem Attribut `Seite_Beschlag` (links = LH, rechts = RH), je Schiene 3 Bohrungen bei 56, 280 und 330 mm ab Vorderkante der Seite, 52 und 436 mm über der Oberkante des Bodens. Front: 2 Halter mit je 2 Bohrungen, 14 mm von der Innenseite der Seiten (X = 84 bei M150, 134 bei M200), 103 und 487 mm über der Oberkante des Bodens. Alle Ø3 (mitgeliefert sind Schrauben Ø4 × 16), Seite 10 tief (Annahme), Front 5 tief. Keine Lochreihen in diesem Schrank. Ist der Einbauraum kleiner als von Häfele verlangt (lichte Weite 112, lichte Höhe 565, Tiefe 485 mm), kommt ein Hinweis.
* **Kesseböhmer LeMans II** (Eckschrank Blindeck, Variante Le Mans; Montageanleitung MA 406954 0000, S. 3 und 11): Größe aus dem Attribut `LeMans` (40/45/50/60), Türseite aus `Blindseite`. Säulenlager in Boden und Strebe vorn bei X = 426/476/526/626 mm ab der Innenseite der Seite an der Tür: Ø5 für die Systemschraube Ø6,3 × 13, 69 mm ab Vorderkante, dazu 2 × Ø3 (Holzschrauben Ø4,5, vorgebohrt, Annahme) 16 mm daneben auf 37 mm. Im Boden durchgebohrt von unten (dort liegen auch die Sockelfüße), in der Strebe 13 bzw. 10 tief von unten. Seitenprofil 500 in der Seite an der Tür: 8 × Ø5, 13 tief, 52 mm ab Vorderkante, unterstes 28 mm über dem Boden, Raster 64. Keine Lochreihen in diesem Schrank. Hinweis, wenn Korpusbreite (764/800/910/960 mm), Tiefe (500 mm) oder Strebe vorn (60 mm) zu klein sind.
* **Blum AVENTOS HK-top** (Oberschrank mit Klappe; Montageanleitung MD-039/2, S. 3–4, Maße abgeleitet und noch nicht an einem Probestück geprüft): Kraftspeicher in beiden Seiten mit 4 Bohrungen Ø5, 12 tief, in einer waagrechten Reihe 37/69/101/133 mm ab Vorderkante der Seite, 36 mm unter der Korpusoberkante. Frontbeschlag auf der Innenseite der Klappe je Seite 2 Bohrungen Ø5, 12 tief, 12,5 mm ab der Innenseite der Seite (Blum: SFA + 12,5 vom Frontrand), 62 und 94 mm unter der Korpusoberkante (Blum: 62 + FAo ab Frontoberkante, Raster 32). Maße in `Regeln::AVENTOS_HK`. Für die Faltklappe AVENTOS HF gibt es noch keine Bohrungen, der Export meldet das.
* **Innenecke einer L-Platte** (Eckschrank L-Form: Boden und Einlegeböden; Eck-Oberschrank: Boden, Deckel und Einlegeböden): Die Ecke steht als `ecke_x`/`ecke_y` an der Definition der Platte. Geschlossene Kontur mit dem Nutfräser 2200 durch die Platte (Stärke + 1 mm) von der Seite mit den übrigen Bearbeitungen (Unterschrank: unten bei den Sockelfüßen; Eck-Oberschrank-Boden: oben bei der Rückwandnut), an den Innenkanten 2 mm zurück (Anleimer, den OCL dort nicht erkennt), nach außen 8 mm über die Platte hinaus. Sockelfüße je Schenkel, also auch an der Innenecke. In der Ecke stößt die Strebe von Schenkel B mit dem Ende an die Längskante der Strebe von A: Dübel wie Strebe–Seite, in die Kante 22 tief.
* **Kanalausschnitt** (Unterschrank Kochfeld mit Abzug): durchgehende Rechtecktasche (rect.tmcr, Stärke + 1 mm) von unten im Boden; Lage und Größe aus den Attributen `Ausschnitt_Links`, `Ausschnitt_Breite`, `Ausschnitt_Hinten`, `Ausschnitt_Tiefe` am Schrank (ab der Kante bei `SeiteL` bzw. bei der Rückwand).
* **Sockelfüße** (Unter- und Hochschränke): Bohrbild aus `Boden.tcn` in der Unterseite des Bodens, je Fuß 2 × 2 Bohrungen Ø3, 3 tief, Raster 64, 20 mm vom Rand in x und 60 mm in y; bei einem schmalen Boden (unter 248 mm, z. B. 112 mm im Handtuchschrank) nur ein Fuß je Ende, mittig. Der Boden liegt dafür mit der Unterseite nach oben.
* **Rückwandnut** (steckt eine Rückwand in Seiten und Boden, im Oberschrank; im Spülenschrank nur in den Seiten, die Rückwand steht dort auf dem Boden): Bahn mit dem Nutfräser 2200 (Ø 8,03 mm, wie im Treppenbau) als `W#89`/`W#2201`, Tiefe = Nuttiefe (9 mm), Breite = Rückwandstärke (breiter als der Fräser: mehrere Bahnen). Läuft die Nut aus der Platte, fräst sie 5 mm darüber hinaus.
* **Schräg- und Bogenkante** (Abschlussregal, Böden mit Wörterbuch `JT_Kontur` an der Definition): zugeschnitten wird das Rechteck, die Kante fräst der Konturfräser 1004 (Ø 20) von Fläche 1 ganz durch (Stärke + 1 mm), um den Fräserradius in den Abfall und um den Anleimer in die Platte versetzt. Ein- und Auslauf tangential außerhalb der Platte, Bögen als `W#2125` mit Radius und Winkel wie in `bogen.tcn`. Anleimer auf nicht achsparallelen Flächen zählt nicht ins Fräsmaß des Rechtecks, sondern steht in der Stückliste als *Kante Kontur* mit Länge. Sockelfüße, die über die Kante ragen würden, rücken nach innen.
* **Rückwand-Ausschnitt** (Spülenschrank): Lage und Größe stehen als Attribute `Ausschnitt_X/_Z/_B/_H` an der Rückwand. Geschlossene Kontur mit dem Nutfräser 2200 (`W#89` + 4 × `W#2201`), um den Fräserradius nach innen versetzt (Ecken bleiben mit Radius 4 mm), Tiefe = Rückwandstärke + 1 mm.
* **Zustellung**: Keine Fräsung geht in einem Zug tiefer als 20 mm (Materialschonung). Tiefere Bahnen (`W#89` + Bahnzeilen) und Taschen (`W#1022`) wiederholt der Export in gleich großen Schritten von höchstens 20 mm, z. B. 39 mm → 19,5 + 39. Jeder Schritt ist eine eigene Bearbeitung. Das gilt zentral für alle TCN (`Tcn.zustellen`), auch für die Arbeitsplatte.
* **Rohrausschnitt** (Oberschrank Dunstabzug): Attribute `Ausschnitt_X/_Y/_B/_T` an Haubenboden, Deckel und Einlegeboden (liegende Platte, Lage ab vorne links). Gleiche Kontur wie der Rückwand-Ausschnitt, von oben (Fläche 1), Tiefe = Plattenstärke + 1 mm. Bei Umluft ist die Breite 0, dann entfällt er.
* **Deckel–Rückwand** (nur Oberschrank): 3 Schrauben 50 mm von den Seiten und in der Mitte, Ø4 durch die Rückwand (1 mm tiefer als ihre Stärke), Ø3 × 15 in die Hinterkante des Deckels (Annahme).
* Die Bearbeitungen einer Seite sind nach Inhalt sortiert, so ergeben gespiegelte Teile mit gleichem Bohrbild dieselbe TCN.
* Fläche 1 (oben auf der Maschine) ist die große Fläche mit den meisten Bohrungen, bei Seiten also die Innenseite. Die linke Seite ist die gespiegelte rechte.
* Jede TCN beginnt mit `squad` (Formatieren). Das Feld `s` im Kopf kommt aus den Vorlagen (Boden 13, Deckel 11, Strebe 10, Seite 54, sonst 1).
* Gleiche Teile (gleicher Tag, gleiche TCN, z. B. zweimal derselbe Schrank) werden einmal geschrieben und gezählt. Weicht ein gleichnamiges Teil ab, heißt die Datei `<Tag>_2.tcn`.
* **Arbeitsplatten** (`Komponenten/arbeitsplatte`): je Stoßende eine TCN mit Stoßkontur, Hundeknochen (Ø 35 + Steg, 20 tief) und Ausschnitten, Dekor unten, Stoß am Anschlag links; Einzelheiten in `Komponenten/arbeitsplatte/README.md`. Kein `squad`, abgelängt wird bauseits.
* Der Test vergleicht Boden und Strebe zeilengleich mit `beispiele/Boden.tcn` und `Strebe.tcn` und die Seite mit `Seite.tcn`. Abweichungen gewollt: Boden-Dübel 0/0 mit errechnetem ST statt Raster 150 (1/1) und vorn x-28 (30 ab fertiger Kante), Strebe vorn 18 … x-20 (20 ab fertiger Kante), Seite ohne Anleimer oben/unten hat die Reihen bei 9.5 statt 7.5, Seiten bekommen an der Dübellinie des Bodens die Ø3-Schraubenreihe aus `Seite.tcn` (12 tief, Raster 130, 1/1, gleiche Enden wie die Dübel).

## Aufbau
* `src/jt_schrank_cnc.rb` – Registrierung der Erweiterung
* `src/jt_schrank_cnc/main.rb` – Menü, lädt die Untermodule
* `src/jt_schrank_cnc/schraenke.rb` – Schränke und Teile im Modell finden
* `src/jt_schrank_cnc/materialien.rb` – Materialangaben lesen/schreiben, Bibliothek, Maserrichtung
* `src/jt_schrank_cnc/materialdialog.rb` – Fenster „Materialien…“
* `src/jt_schrank_cnc/korpus.rb` – Korpusmaterial ändern
* `src/jt_schrank_cnc/frontfarbe.rb` – Frontfarbe und Griffe
* `src/jt_schrank_cnc/geometrie.rb` – Teile vermessen (Weltquader, Anleimer, Lage auf der Maschine)
* `src/jt_schrank_cnc/regeln.rb` – Stöße finden, Bearbeitungen ableiten
* `src/jt_schrank_cnc/tcn.rb` – TCN schreiben (Windows-1252, CRLF)
* `src/jt_schrank_cnc/arbeitsplatte.rb` – TCN für Arbeitsplatten (Verbindungsfräsung, Ausschnitte)
* `src/jt_schrank_cnc/export.rb` – Export, Teileliste, Dialog
* `src/jt_schrank_cnc/fraesliste.rb` – Fräsliste `Liste_<Ordner>.xmlst`
* `src/jt_schrank_cnc/einstellungen.rb` – allgemeine Einstellungen (Übermaß) und das Einstellungen-Fenster; Sockel und Abstände in `gemeinsam/einstellungen.rb`
* `src/jt_schrank_cnc/stueckliste.rb` – Stückliste (CSV und Druckseite)
* `src/jt_schrank_cnc/etiketten.rb` – Etiketten (Bogen oder Endlos, HTML zum Drucken)
* `src/jt_schrank_cnc/zuschnitt.rb` – Zuschnittplan für die Formatsäge
* `src/jt_schrank_cnc/bin_packing_2d/` – Guillotine-Optimierer aus OpenCutList (GPL-3.0, siehe `THIRD_PARTY.md`)
* `test/test_materialien.rb` – Material-Konfigurator: Anlegen, Bearbeiten, Umbenennen, Löschen, Bibliothek, Maserrichtung, Korpusmaterial
* `test/test_frontfarbe.rb` – erzeugt Hochschrank, Oberschränke und Unterschrank mit den Skripten aus `Komponenten/` in der Mock-API und prüft Frontfarbe, Anleimer, Bereiche, Auswahl, Eindeutigmachen, Griffe und den Dialog
* `test/test_stueckliste.rb` – Stückliste an Hochschrank und Unterschrank: Roh-/Fräs-/Fertigmaß, Kanten, Übermaß aus den Einstellungen, CSV, Druckseite, Dialoge
* `test/test_zuschnitt.rb` – Zuschnittplan an Hoch-, Unter- und Oberschrank: alles platziert, keine Überlappung, Schnittbreite und Besäumen eingehalten, Maserung, zu große Teile, Druckseite, Dialog
* `test/test_etiketten.rb` – Etiketten: Bogen-Lage, Startposition, Endlos, Kantenbild, QR-Code, Format-Dialog
* `test/test_export.rb` – TCN-Export an Unterschrank, Oberschrank, Hochschrank, Hochschrank Geräte und Hochschrank Kühlschrank (Lüftungsschacht: gekürzte Böden, Nut der Rückwand), Vergleich mit `beispiele/` (Boden mit Sockelfüßen, Strebe, Seite mit Lochreihen), Nut und Schrauben im Oberschrank, Spülenschrank (Ausschnitt, Nut, Auszug, Türen), Eckschrank (Blende, Le Mans, L-Form), Eck-Oberschrank (Nut im L-Boden, Deckelschrauben, Innenecke)

## Grundidee
1. Teile einsammeln (sichtbare Instanzen mit Tag nach dem Schema `<Kürzel>_<Bereich>_<Teil>`).
2. Teile vermessen, Anleimer wie OpenCutList aus den Kantenflächen lesen, Lagen im Fräsmaß.
3. Stöße zwischen Teilen finden und daraus Dübel, Lochreihen, Topfbänder und Schienenbohrungen ableiten.
4. Eine TCN je Tag schreiben, dann Fräsliste und Teileliste.

## Schritte
1. ~~Tags aller Komponenten vereinheitlichen.~~ Erledigt: Hochschrank `HS<n>`, Unterschrank Schubladen `USS<n>`, Unterschrank Tür `UST<n>`, jeweils mit `JT_Schrank`.
2. ~~Oberschrank-Skript~~ (`Komponenten/oberschrank/`, Kürzel `OS<n>`).
3. ~~Schubkasten:~~ Blum LEGRABOX (Boden und Holzrückwand), Schiene im 32-mm-Lochraster (Start 35 mm), Höhenoffset Schiene.
4. ~~Frontfarbe und Griffe.~~
5. ~~Erster Export nur Korpus, Vergleich mit den Beispiel-TCN.~~
6. ~~Lochreihen, Sockelfüße, Rückwandnut.~~
7. ~~Schubladen: Schienenbohrungen, Frontbefestigung, Kastenboden, Generatoren auf LEGRABOX.~~
8. Türen und Griffbohrungen.
9. Dialog, Listen.

## Lizenz
GPL-3.0 ([LICENSE](LICENSE)), weil der Zuschnitt-Optimierer aus OpenCutList stammt; Herkunft und Änderungen in [THIRD_PARTY.md](THIRD_PARTY.md).
