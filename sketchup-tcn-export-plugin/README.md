# SketchUp-Plugin „Schrank-CNC“ (TCN-Export, Stückliste, Etiketten, Zuschnitt, Materialien, Frontfarbe, Andocken)

**Stand:** *Frontfarbe und Griffe ändern* ist fertig. Der TCN-Export schreibt den Korpus: Formatieren, Dübel Boden/Deckel/Zwischenboden/Strebe an die Seiten, Schrauben in die Streben, Lochreihen für Einlegeböden, Sockelfüße, die Rückwandnut im Oberschrank und im Spülenschrank sowie den Rückwand-Ausschnitt im Spülenschrank und den Rohrausschnitt im Oberschrank Dunstabzug. Für Schubladen (Blum LEGRABOX), den Hochauszug Häfele HU Slim Base Kesseböhmer LeMans II im Eckschrank und die Klappe (Blum AVENTOS HK-top oder Häfele Free Slim) kommen die Schienenbohrungen in die Seiten, die Frontbefestigung in die Front und der Falz in den Kastenboden; Türen bekommen Blum-Topfbänder (Topf in der Tür, Montageplatte in der Seite); Griffe folgen.

Das Plugin findet im Modell alle Teile der Schränke aus `Komponenten/` an ihrem Tag `<Kürzel>_<Bereich>_<Teil>` und am Wörterbuch `JT_Schrank`. Es schreibt je Teil eine TCN-Datei für TpaCAD, dazu die Fräsliste (`.xmlst`), und erzeugt Stückliste, Etiketten und Zuschnittplan; alles zusammen über einen [Export-Dialog](#export) ([Plan](https://claude.ai/artifact/P3oz5CefPjFuUckMwss26v)).

* Ausführlicher Plan: [Plan: TCN-Export für Schrank-Komponenten](https://claude.ai/artifact/1txhjwKrxeGrWi3j7F5wNN)
* Vorbild für den TCN-Writer: [jimmycd/sketchup-treppenbauer](https://github.com/jimmycd/sketchup-treppenbauer) (`src/jt_treppenbau/tcn.rb`, `fraesliste.rb`)
* `beispiele/` – Jürgens 11 Beispiel-TCN-Dateien (Boden, Deckel, Strebe, Seite, Seiten_Duebel, Seiten_SK_L/R, Schubkastenboden, SK_Vorderstueck_Frontbef, T_re_L_Topfband, T_rR). Sie sind parametrisch (`x`, `y`, `s`) und nutzen die Makros `squad`, `fittingx`/`fittingy`, `inge100` und `rect`; sie sind die Vorlage für die Bearbeitungsregeln.

## Installieren
`schrank_cnc.rbz` im Erweiterungs-Manager installieren (*Erweiterung installieren*), oder `Kuechenplaner_alle.rbz` aus dem Hauptordner mit allen Komponenten. Die Einträge stehen unten im gemeinsamen Menü *Erweiterungen › Küchenplaner*, unter den Komponenten. Nach Änderungen an `src/` die `.rbz` im Hauptordner mit `./build_rbz.sh` neu bauen (der Test prüft das).

Wer vorher die Version 0.1 installiert hatte: Das alte Untermenü *Schrank-CNC* verschwindet nach dem Installieren der neuen `.rbz` und einem Neustart von SketchUp.

## Materialien
*Erweiterungen › Küchenplaner › Materialien…* zeigt alle Platten und Anleimer aus Modell und Bibliothek, mit *Neue Platte*, *Neuer Anleimer*, *Bearbeiten* und *Löschen*.

| Platte | |
|---|---|
| Name, Farbe, Texturbild | Farbe mit dem Farbwähler (Farbrad, Helligkeitsregler, Vorschau) oder als `#RRGGBB` / `R,G,B` eintippen; Texturbild optional über *…* wählen, mit Bildbreite in mm |
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
Neue Schränke muss man nicht von Hand verschieben und drehen. Gilt für alle Schränke aus dem Menü *Unterschränke*, *Oberschränke* und *Hochschränke*. Regeln von Jürgen (2026-11-05):

* **Immer an der Wand:** Jeder Schrank steht mit der Rückseite im *Abstand Schrankrückseite – Wand* (*Einstellungen*) an einer Wand des Raums und lässt sich nur an ihr entlang schieben. An den Wandenden rastet er ein (dort auch seitlich mit Wandabstand zur Nachbarwand), ebenso an Tür-/Durchgangslaibungen (Fang 100 mm).
* **Nie ineinander:** Ein Schrank kann nie in einen anderen Schrank oder in eine Wand gesetzt werden. Beim Schieben bleibt er am Hindernis liegen; passt er nirgends, steht „kein Platz“ in der Statuszeile.
* **Höhen fest:** Unter- und Hochschränke stehen auf Fußboden + Sockelhöhe, Oberschränke auf Arbeitsplattenhöhe + lichter Abstand Arbeitsplatte/Oberschrank (*Einstellungen*, Vorgabe 40 + 550 mm), höchstens bis unter die Decke.
* **Nachbarn berühren sich:** Unter-/Hochschränke und Oberschränke untereinander berühren sich an der **unteren vorderen Korpusecke** (Korpus, nicht Front). Ist der neue Schrank flacher als der Nachbar, kommt er mit der Vorderkante bündig nach vorn; ist er tiefer, bleibt die Rückseite im Wandabstand. Gemessen wird nur an Seiten, Wangen und Rückwand, nicht an Fronten, Geräten oder Arbeitsplatte. Geräteschränke ohne eigene Seite (Geschirrspüler, Unterbau-Kühlschrank) haben eine virtuelle Seite; ihr Gerät steht auf dem Fußboden. Neben einem L-Eckschrank oder Eck-Oberschrank zählt der Schenkel, an dem der neue Schrank steht: Vorderkante bündig mit dessen Seite, nicht mit der Vorderkante des ganzen Ecks.
* **Inselschränke** folgen der Maus frei im Raum (Kollision wird trotzdem geprüft).

**Einfügen:** Gibt es noch keinen Schrank, hängt der neue an der Maus (Andock-Werkzeug). Ist ein Schrank markiert, kommt der neue an dessen freie Seite (rechts, wenn beide frei sind); ist keine Seite frei, hängt er an der Maus. Ohne Markierung kommt er ans freie Ende der Zeile seiner Art (Unter-/Hochschränke eine Zeile, Oberschränke eine, Inselschränke eine eigene); der erste Oberschrank über den Anfang der Unterschrank-Zeile.

**Sockelhöhe ändern:** Wird die Sockelhöhe in den *Einstellungen* geändert, wandern alle Unter- und Hochschränke, Arbeitsplatten und Sockelblenden um die Differenz mit; Oberschränke auch, aber höchstens bis unter die Decke.

**Andock-Werkzeug** (Vorschau: blauer Kasten, Front rot; Statuszeile zeigt Wand und Abstand links/rechts bis zum Wandende):

* **Maus bewegen:** Schrank gleitet an der Wand entlang, die der Maus beim Start am nächsten war; eine andere Wand wählt man mit Tab.
* **Tab**: Schrank dreht sich und wechselt zur nächsten Wand, **Shift+Tab** zur vorigen. Beim Eckschrank dreht der erste Tab nur in der Ecke (andere Wand als Bezug für die Front), der zweite wechselt die Wand.
* **Strg gedrückt halten**: Freihand. Der Schrank folgt der Maus frei im Raum, **Pfeil hoch/runter** ändert die Höhe in 10-mm-Schritten, Tab dreht um 90°. Geprüft wird nur noch die Kollision mit Schränken und Wänden. Strg loslassen: wieder an der Wand.
* **Klick**: absetzen (ein Schritt *Rückgängig*), **Esc**: Schrank bleibt, wo er erzeugt wurde.
* Ohne Raum (keine Wände) folgt der Schrank der Maus auf fester Höhe, Tab dreht.
* Ausgeblendete Teile (z. B. abgeschaltete Wangen) zählen für die Maße nicht.

**Maße ändern** (Komponentenoptionen Breite/Tiefe, Jürgen 2026-11-05):

* **Breite:** Die angedockte Seite bleibt stehen, die freie Seite wandert. Angedockt ist eine Seite, an der ein anderer Schrank oder eine Wand (mit Wandabstand) anliegt. Ist nur die rechte Seite angedockt, wird der Schrank nach links breiter bzw. schmaler; sonst bleibt die linke Seite. Ist der Schrank links **und** rechts angedockt, bleibt die linke Seite; stößt er danach an den rechten Nachbarn, kommt eine Meldung, den Nachbarn bitte von Hand verschieben.
* **Tiefe:** Die Rückseite bleibt (an der Wand), die Front wandert nach vorn bzw. zurück.
* Erkannt wird die Änderung am Bezugskasten (Seiten, Wangen, Rückwand), der nach jedem Schritt am Schrank gemerkt wird (`JT_Masse/kasten`). Die Verschiebung gehört zum selben *Rückgängig*-Schritt wie die Maßänderung. Arbeitsplatten und Sockelblenden sind ausgenommen. Rechnung in `src/jt_schrank_cnc/massaenderung.rb`, getestet in `test/test_massaenderung.rb`.

**Schränke kopieren** (Jürgen 2026-11-06): Eine Kopie (Verschieben mit Strg, Kopieren/Einfügen) teilt sich zuerst die Komponentendefinition mit dem Original, dann würde das Interagieren-Werkzeug Schubladen, Türen und Klappen in beiden Schränken bewegen. Nach jedem Schritt (und beim Öffnen eines Modells) bekommt deshalb jede Kopie eine eigene Definition, ebenso jede Zwischenebene über einem beweglichen Teil (z. B. Türhalter). Starre Teile bleiben geteilt. Gehört zum selben *Rückgängig*-Schritt wie das Kopieren. Code in `src/jt_schrank_cnc/kopien.rb`, getestet in `test/test_kopien.rb` und für alle Schränke in `test/test_konsistenz.rb`.

Einen vorhandenen Schrank neu andocken: auswählen und *Erweiterungen › Küchenplaner › Schrank andocken…*.

Ohne Schrank-CNC-Erweiterung erzeugen die Komponenten ihre Schränke wie bisher rechts neben dem Modell. Die Rechnung steht in `src/jt_schrank_cnc/andocken.rb` (Modul `Rechnung`), getestet in `test/test_andocken.rb`. In echtem SketchUp noch nicht ausprobiert.

## Export
*Erweiterungen › Küchenplaner › Export (Stückliste, Etiketten, Zuschnitt, TCN)…* oder das Icon **Export** (TCN-Icon) der Symbolleiste öffnet einen Dialog: Stückliste, Etiketten, Zuschnittplan und TCN je *ja/nein*, dazu der **Zielordner** (Knopf „…“ zum Wählen; ein neuer Ordner wird angelegt; Vorschlag: zuletzt benutzter Ordner des Modells, sonst `Export_<Modell>` neben dem Modell). Die Auswahl wird gemerkt. Sind Etiketten bzw. Zuschnittplan gewählt, folgen danach deren Fenster (Etikettenformat, Zuschnitt-Optionen); Abbrechen dort schreibt nichts. Ist etwas ausgewählt, nur die Teile der ausgewählten Schränke. Zum Schluss öffnet sich der Zielordner.

| Datei | Ort |
|---|---|
| `Stueckliste_<Modell>.pdf` (mit Beschlagliste auf der letzten Seite), `.csv` und `_Beschlaege.csv` | Zielordner |
| `Etiketten.pdf`, `Zuschnitt.pdf` | Zielordner |
| `<Nr>_<Tag>.tcn` und Fräsliste `Liste_<Zielordner>.xmlst` | Unterordner `tcn` |

Alle Ausgaben kommen aus **einem** Export-Lauf, die Nummern sind daher überall gleich (Stückliste, Etiketten, Zuschnittplan, TCN-Dateiname). Vor dem Schreiben werden alte `.tcn`/`.xmlst` im Unterordner `tcn` gelöscht (andere Dateien bleiben), damit dort und in der Fräsliste nur der aktuelle Stand liegt.

**Eine Liste:** Die frühere `Teileliste.csv` des TCN-Exports gibt es nicht mehr; alles, was sie hatte (TCN-Datei, Anzahl, Schrank, Teil, Rolle, Material, Fräsmaß = DL/DH, Stärke), steht in der Stückliste (dazu Roh- und Fertigmaß, Kanten). Die Stückliste gibt es als PDF zum Drucken und gleich als CSV für Excel. Die Fräsliste `.xmlst` ist keine Teileliste, sondern der Auftrag für das TpaCAD-Board.

## Stückliste
Über den [Export-Dialog](#export). Geschrieben werden die **PDF** (A4 quer, je Material und Stärke eine Tabelle mit Stückzahl, Rohfläche und Anleimer-Laufmetern, Rohmaß fett, lange Tabellen laufen mit wiederholtem Spaltenkopf über mehrere Seiten, Fuß „Seite x von n“) und daneben mit gleichem Namen die **CSV** (Semikolon, Dezimalkomma, Windows-1252 für Excel). Drucken mit „Tatsächliche Größe“ oder „An Seite anpassen“. Ist die Datei noch im PDF-Leser offen und kann nicht überschrieben werden, kommt ein Hinweis. Eine Arbeitsplatte mit zwei Stoßenden hat eine Zeile mit beiden TCN-Dateien.

**Beschlagliste:** Die letzte Seite der PDF (und `<Name>_Beschlaege.csv` daneben) listet die Beschläge aller Schubladen, Türen und Klappen, gezählt aus denselben Bohrbildern wie der TCN-Export (`beschlaege.rb`): je Schublade LEGRABOX-free-Zargen F/C/K/M/N mit Nennlänge, Korpusschienen (40 kg, NL 650 70 kg), Rückwandhalter, Fronthalter, zwei Seiteneinsätze (Glas 10 mm, F 202 / C 138 / K 90 / M 52 × NL − 112, N ohne), Seitenstabilisierung ab Korpusbreite 600, Schrauben 4 × 15 für Fronthalter und Boden (8 je Boden, S. 5) und Systemschrauben für die Schienen; je Tür Blum-Topfbänder Ø35 mit Montageplatte und Systemschrauben; je Klappe AVENTOS HK-top bzw. Häfele Free Slim (Mechanismus L + R, Frontbeschläge, 4 Dübel, 8 Schrauben 4 × 20, 8 Schrauben 4 × 15). Höhenprobleme der Schubladen stehen auch als Hinweis auf der Stückliste.

Die PDF schreibt das Plugin selbst mit `pdf.rb` (kein Browser, kein Druckertreiber, keine fremde Bibliothek), wie Etiketten und Zuschnittplan; Tabellen zeichnet `Pdf#tabelle`, den Seitenfuß `Pdf#auf_seite`. Die frühere HTML-Druckseite gibt es nicht mehr.

* Eine Zeile je TCN-Datei wie beim TCN-Export (gleiche Teile zusammengefasst, Spalte Anzahl), mit laufender Nummer, Tag und TCN-Dateiname. So passen Stückliste, TCN und Fräsliste immer zusammen.
* **Fertigmaß** = Maß im Modell, **Fräsmaß** = Fertigmaß minus Anleimer an jeder Kante mit Anleimer (= DL/DH der TCN), **Rohmaß** = Fräsmaß plus Übermaß (Zuschnitt an der Formatsäge). L ist die längere, B die kürzere Seite.
* Kanten: L1/L2 die beiden Längskanten, B1/B2 die Querkanten, jeweils mit dem Anleimer-Material (in der PDF als Kürzel A, B … mit Legende).
* Maserung: aus dem Material (*Materialien…*). Mit Maserung ist L die Seite in Faserrichtung (Fronten senkrecht, siehe Maserrichtung), sonst die längere Seite.
* Arbeitsplatten stehen mit ihren Maßen drin (ohne Übermaß, Zuschnitt von Hand).

## Etiketten
Über den [Export-Dialog](#export) (Etiketten gewählt). Ein Etikett je Stück (Anzahl 3 = „1/3“, „2/3“, „3/3“), in der Reihenfolge und mit den Nummern der Stückliste. Inhalt: Tag, Nummer, Schrank · Teil, Material und Stärke, dann die Maße in der Reihenfolge **Rohmaß** (fett), **Fräsmaß**, **Fertigmaß**, dazu TCN-Dateiname und ein Kantenbild (Länge waagrecht, Anleimer als dicke Linie: L1 unten, L2 oben, B1 links, B2 rechts). Ist etwas ausgewählt, nur die Teile der ausgewählten Schränke.

Vor dem Schreiben fragt ein Fenster das Format ab (vorbelegt mit dem zuletzt benutzten, gespeichert für alle Modelle):

| Feld | Standard | Bedeutung |
| --- | --- | --- |
| Art | Bogen | **Bogen**: A4 hoch, Etiketten in Spalten × Zeilen. **Endlos**: Etikettendrucker mit Rolle, je Etikett eine Seite in Etikettengröße |
| Etikett Breite / Höhe | 70 × 37 mm | Größe eines Etiketts |
| Spalten / Zeilen | 3 × 8 | nur Bogen |
| Rand oben / links | 0,5 / 0 mm | nur Bogen, Abstand der ersten Etikettkante vom Blattrand |
| Abstand waagrecht / senkrecht | 0 / 0 mm | nur Bogen, Lücke zwischen den Etiketten |
| QR-Code | nein | ja: QR-Code mit dem TCN-Dateinamen (wird ins PDF gezeichnet, kein Internet nötig) |
| erstes freies Etikett | 1 | angebrochener Bogen: Nummer des ersten freien Etiketts, zeilenweise von oben links |

Danach fragt es nach einem Ordner, schreibt **`Etiketten.pdf`** und öffnet sie im PDF-Leser. Drucken mit „Tatsächliche Größe“ (100 %, nicht „an Seite anpassen“); die Seitengröße steht im PDF (A4 bzw. beim Endlos-Drucker die Etikettengröße).

## Schrank-Beschriftung
*Erweiterungen › Küchenplaner › Schrank-Beschriftung ein/aus* oder das Icon in der Symbolleiste. Jeder Schrank bekommt einen Text mit seinem Kürzel aus `JT_Schrank/schrank` – dieselbe Quelle wie Stückliste und Etiketten („Schrank · Teil“, Tag `<Kürzel>_…`). Die Texte stehen in der Gruppe „Schrank-Beschriftung“ auf dem Tag **Beschriftung**, als Text mit Pfeil wie das SketchUp-Werkzeug *Text* (immer lesbar, aus jedem Blickwinkel): die Pfeilspitze sitzt vorn mittig auf der größten sichtbaren Front (Tür, Klappe, Schubkasten), ohne Front vorn mittig am Schrank, bei der Arbeitsplatte oben mittig auf der größten Platte, der Text steht rechts davor und darüber (oberste Ebene, nicht im Schrank: TCN-Export, Stückliste und Andocken sehen sie nicht). Einschalten zeigt den Tag in den Szenen **Planung** und **Zuschnitt**, Ausschalten blendet ihn dort aus; in **Kunde** ist er nie zu sehen. Fehlen die Szenen, kommt ein Hinweis (*Geräte › Szenen Planung/Kunde/Zuschnitt anlegen*). Solange die Beschriftung an ist, folgt sie nach jedem Vorgang dem Modell (Schrank verschoben, neues Kürzel, Schrank neu oder gelöscht); die Anpassung hängt sich an den Vorgang davor, Rückgängig nimmt beides zurück.

## Beschläge zeigen
*Erweiterungen › Küchenplaner › Beschläge ein/aus* oder das Icon **Beschläge zeigen** in der Symbolleiste. Zeichnet die Beschläge, die nicht selbst gefertigt werden, als vereinfachte, maßhaltige Körper ins Modell:

| Beschlag | Lage | bewegt sich mit |
|---|---|---|
| LEGRABOX-Zarge C/M links + rechts (12,8 mm, Zargenhöhe wie `Regeln.zarge`, NL − 1 lang) | neben dem Kastenboden ab Kastenunterkante | Schublade |
| Korpusschiene (NL − 10, 4 mm stark, 20 hoch) | an den Schienenbohrungen der Seite, 4 mm hinter der Vorderkante | Schrank |
| Fronthalter, Rückwandhalter | an der Frontbefestigung bzw. an der Holzrückwand | Schublade |
| Blum-Topfband: Topf Ø35 × 13 | an jeder Topfband-Bohrung, ganz in der Tür (Maße der Tür bleiben) | Tür |
| Topfband-Arm, Montageplatte 48 × 20 × 4 | über den beiden Ø5-Löchern in der Seite, Arm bis zur Vorderkante der Seite | Schrank (bleibt beim Öffnen an der Seite) |
| AVENTOS HK-top Kraftspeicher, Frontbeschlag | an den Bohrungen in Seite bzw. Klappe | Schrank / Klappe |
| AVENTOS HK-top Hebelarm 8 × 8 | schräg vom Kraftspeicher zum Frontbeschlag (Lage bei geschlossener Klappe) | Schrank |
| Häfele Free Slim Mechanismus 245 × 165 × 22, Frontbeschlag 20 × 10 | über den Dübellöchern in der Seite bzw. an den Löchern in der Klappe | Schrank / Klappe |
| Häfele Free Slim Arm 10 × 10 | vom Mechanismus zum Frontbeschlag (Lage bei geschlossener Klappe) | Schrank |
| LEGRABOX-Seiteneinsatz (Glas, 10 mm, Einsatzhöhe × NL − 112) | im Fenster der Zarge (F/C/K/M; N ohne Einsatz) | Schublade |
| LEGRABOX-Seitenstabilisierung | quer zwischen den Zargen oben vor der Holzrückwand, ab Korpusbreite 600 | Schublade |
| Kesseböhmer LeMans II: Säule Ø30, Seitenprofil, 2 Tablare (Rand 50, Ecken R120) | Säule über den Lagern, Profil an den Profilbohrungen, Tablare von der Seite bis hinter die Säule | Schrank |
| Häfele HU Slim Base: 2 Schienen 12 × 30 | an den Schienenbohrungen der Seite | Schrank |
| HU Slim Base: Fronthalter, Gestell, 2 Körbe | an den Frontbohrungen, Körbe auf deren Höhe | Auszug |

Die Lagen kommen aus denselben Bohrbildern wie TCN-Export und Beschlagliste (`Regeln.anwenden`), passen also immer zu den Bohrungen. Die Körper liegen in einer Gruppe „Beschläge“ auf dem Tag **Beschlag** (Materialien „Beschlag Alu grau“, „Beschlag Stahl vernickelt“, „Beschlag Kunststoff grau“, im Rendern Metall) innerhalb des Schranks; sie haben kein `JT_Schrank/teil`, Stückliste, Etiketten, Zuschnitt, TCN-Export, Beschlagliste und Andocken sehen sie nicht. Solange der Schalter an ist, folgen sie jeder Änderung an einem Schrank (Komponentenoptionen); Verschieben und Öffnen (Interagieren) ändern nichts. Steht eine Tür oder Klappe gerade offen, wird der Schrank nicht neu berechnet (die Bohrbilder stimmen dann nicht), sondern erst, wenn sie wieder zu ist. Teilen sich zwei Türen eine Definition, aber die Töpfe säßen verschieden, bekommt sie keine Töpfe. Ausschalten löscht alle Beschlag-Gruppen. Die Platzhalter der Komponenten für LeMans und HU Slim Base (Tag `<Kürzel>_LeMans` bzw. `<Kürzel>_Beschlag`) sind ausgeblendet, solange die Beschläge gezeigt werden. Noch ohne Körper: AVENTOS HF (Bohrbild fehlt) und Sockelfüße (lägen unter dem Korpus, außerhalb der Komponentengrenzen).

## Rendern (Blender)
*Erweiterungen › Küchenplaner › Rendern (Blender)…* oder das Kamera-Icon in der Symbolleiste macht ein fotorealistisches Bild der Küche mit dem kostenlosen [Blender](https://www.blender.org/download/) (Renderer Cycles). Blender muss installiert sein; das Plugin sucht es selbst (`C:\Program Files\Blender Foundation\Blender …\blender.exe`, neueste Version zuerst, auch Steam, Mac und Linux), sonst im Fenster mit „…“ wählen. Der Pfad bleibt auf dem Rechner gemerkt.

Im Fenster: **Breite** in Pixeln (die Höhe folgt dem Seitenverhältnis der Ansicht), **Qualität** Entwurf/Normal/Hoch (32/128/512 Samples, mit Entrauschen), **Kamera** aktuelle Ansicht oder Szene Kunde (bei der aktuellen Ansicht wird der Bildausschnitt aus den Blickstrahlen der vier Bildecken übernommen, so zählen auch SketchUps Zweipunktperspektive und 2D-Zoom/-Verschieben mit: das Rendering zeigt dieselbe Totale), **Senkrechte Kanten gerade** (Zweipunktperspektive wie in der Architekturfotografie: die Kamera steht waagrecht, die Neigung wird über den Objektiv-Shift ausgeglichen; nur bis 40° Neigung), **Umgebung** (HDRI aus Blenders eigenen Dateien: Innenraum, Innenhof, Studio, Stadt, Wald, Sonnenuntergang, kein Download; es liefert Licht und Spiegelungen, dahinter sieht die Kamera einen ruhigen hellen Hintergrund; oder einfarbig hell), **Raumlicht von oben** (Flächenlicht über der Küche), **LED-Leisten unter Oberschränken** (warmweißes Flächenlicht an der Unterseite jedes Oberschranks, erkannt an `JT_Schrank/kategorie`), **Bilddatei** (Vorschlag: `<Modell>_Render.png` neben dem Modell). Alle Plattenkanten werden im Bild leicht gerundet (Bevel-Shader, 1,5 mm), die Geometrie bleibt unverändert. Für Kontrast sorgt ein **Fensterlicht** (kühles Tageslicht schräg von vorn links aus Sicht der Kamera, wirft Schatten); Raumlicht und Umgebung hellen nur leicht auf. Farbe: AgX mit Look „Punchy“, Belichtung −0,7. Fronten und Korpusse sind seidenmatt mit leichtem Glanz. Hat das Modell keinen Boden, legt Blender einen in den gewählten Belag (sonst Parkett), damit die Kamera nicht auf den grauen Hintergrund schaut.

**Ausstattung** (alles in Blender aus einfachen Formen und Shadern erzeugt, ohne Bilddateien, fremde Modelle oder Download; `rendern_ausstattung.py`):
* **Deko auf der Arbeitsplatte** keine/wenig/mittel/viel (0/3/6/10 Gegenstände): Schneidebrett, Obstschale, Pflanze, Kaffeemaschine, Flaschen, Vorratsdosen, Kochbücher, Wasserkocher, Vase. Sie stehen nur auf der Oberseite von Arbeitsplatten (`JT_Schrank/kategorie` = Arbeitsplatte), ganz auf der Platte (4 cm Abstand zur Kante), nicht auf Geräten (`JT_Geraet`, z. B. Spüle, Kochfeld), eher hinten (weg von der Kamera) und verteilt. **Deko-Variante** 1–9 wählt eine andere, aber wiederholbare Auswahl und Anordnung.
* **Pendelleuchten über der Insel** (`JT_Schrank/insel`): zwei, ab 1,6 m Länge drei, 75 cm über der Platte, mit warmweißem Licht.
* **Bodenbelag** für die Flächen auf dem Tag `Raum-Boden`: wie im Modell, Parkett Eiche, Fliesen hell, Fliesen anthrazit oder Beton.
* **Decke** über den Wänden (`Raum-Wand`), nur wenn die Kamera im Raum steht.
* Holz ohne Bilddatei bekommt eine senkrechte Maserung, Stein/Quarz ohne Bilddatei eine feine Körnung.

* Sichtbar ist, was die Szene **Kunde** zeigt (ihre Tags: Geräte als Modell, Raum, keine Beschriftung, keine Planungs-Platzhalter); ausgeblendete Teile (z. B. der virtuelle Korpus) fehlen immer. Ohne Szene Kunde gilt die aktuelle Sichtbarkeit, Beschriftung und Geräte-Platzhalter bleiben trotzdem weg.
* Licht: Sonne aus den Schatten-Einstellungen der Szene Kunde (sonst des Modells), heller Himmel, wahlweise Raumlicht.
* Materialien: Farbe, Transparenz und Textur aus SketchUp; die Oberfläche kommt aus dem Namen: *Glas*, *Schwarzglas/Ceran*, *Edelstahl/Stahl/Chrom/Griff/Armatur* (Metall), *Hochglanz/Lack*, *Stein/Granit/Quarz/Keramik*, *Holz/Eiche/Buche/Nuss…*, *Wand/Boden/Putz/matt*, sonst seidenmatt.
* Blender läuft unsichtbar im Hintergrund (`blender -b --factory-startup -P rendern.py -- szene.json`); das Fenster zeigt den Fortschritt (Samples), kann abbrechen und zeigt am Ende das Bild (*Bild öffnen*, *Ordner öffnen*). GPU wird benutzt, wenn Blender eine findet (OptiX, CUDA, HIP, Metal), sonst CPU.
* Neben dem Bild liegt der Ordner `<Bild>_blender/` mit `szene.obj/.mtl` (Meter, Z oben), Texturen, `szene.json`, `kp_status.txt` (Fortschritt und Ergebnis, Blender 5 unter Windows schreibt seine Ausgabe nur ins eigene Konsolenfenster), `blender.log` und `szene.blend`: die Szene lässt sich in Blender öffnen und weiter verfeinern (Licht, Materialien, Kamera).

## Zuschnittplan
Über den [Export-Dialog](#export) (Zuschnittplan gewählt), gedacht für die Formatsäge (alles von Hand, kein Zuschnittprogramm). Je Material und Stärke verteilt ein Guillotine-Optimierer (`guillotine.rb`, eigener Code) die **Rohmaße** der Stückliste auf Platten, nur mit durchgehenden Schnitten in Stufen. Ist etwas ausgewählt, nur die Teile der ausgewählten Schränke. Arbeitsplatten und Teile ohne Material bleiben draußen (Hinweis). Teile, die nicht auf die Platte passen, stehen in der Übersicht unter „passt nicht“.

Ein Fenster fragt die Optionen ab (gespeichert für alle Modelle):

| Option | Standard | Bedeutung |
| --- | --- | --- |
| Faserrichtung | wie Material | **wie Material**: Teile mit Maserung (`grained` im Material-Wörterbuch) werden nicht gedreht, L liegt längs der Platte. **beachten**: nie drehen. **ignorieren**: immer drehen erlaubt |
| Abstand / Schnittbreite | 3 mm | Sägeblatt, Abstand zwischen den Teilen (gleich wie in *Einstellungen*) |
| Randabfall | 10 mm | wird an jeder Plattenkante zuerst abgeschnitten (Besäumen) |
| Erster Schnitt | beliebig | **horizontal**: Stufe 1 läuft längs der Platte (Streifen über die ganze Länge), **vertikal**: quer, **beliebig**: je Platte das bessere |
| Schnitttyp | nicht exakt | **exakt**: genau so viele Stufen wie eingestellt, jedes Teil füllt seinen Streifen (2 Stufen) bzw. Abschnitt (3 Stufen) quer voll aus. **nicht exakt**: eine Stufe mehr, aber nur um Abfall vom Teil zu trennen. **homogen**: wie exakt, die letzte Ebene enthält nur gleiche Teile |
| Anzahl Stufen | 3 | 2: Streifen → Teile; 3: Streifen → Abschnitte → Teile |
| Reste behalten ab | 300 × 100 mm | Reste ab dieser Größe sind im Plan grün markiert und stehen in der Übersicht |
| Gleiche Platten zusammenfassen | ja | gleiche Belegung nur einmal zeichnen („Platte 2–3, 2× gleich“) |
| Schnitt- und Teileliste | keine | **eigene Seite je Platte**: Schnittliste in Reihenfolge (Stufe, Richtung, Lage, Länge) und Teileliste auf einer Seite nach der Grafik |
| Schnittnummern in der Grafik | ja | rote Nummern am Anfang jedes Schnitts (Reihenfolge an der Säge) |
| Teile einfärben | nein | ja: helle Farbe je Schrank |
| Anleimer anzeigen | nein | ja: blaue Linie an Kanten mit Anleimer |

Darunter je Material und Stärke **Plattenformat** (L x B) und **Plattenreste** (`1200 x 600 x 2; 800 x 400`, leer = keine). Beides wird je Stärke am Material gespeichert (Wörterbuch `JT_Zuschnitt`, z. B. `reste_19`); ohne Eintrag gilt `std_sizes` im Material-Wörterbuch (Formate mit Anzahl = Reste), sonst 2800 × 2070 mm. Plattenreste werden zuerst belegt, dann Standardplatten.

Ausgabe **`Zuschnitt.pdf`** (A4 quer): Übersicht (Platten, Ausnutzung, nicht platzierte Teile, Reste zum Behalten), dann je Platte eine Seite mit großer maßstäblicher Grafik. Auf jedem Teil stehen **Tag** (groß), Nummer und Rohmaß, bei hohen schmalen Teilen gedreht. Schnitte rot (Stufe 1 dick), Abfall schraffiert, Ursprung links oben, Länge waagrecht.

## Einstellungen
*Erweiterungen › Küchenplaner › Einstellungen…* hat drei Bereiche.

**Küche – dieses Modell** (Sockel und Abstände, gespeichert im Modell, Wörterbuch `Kuechenplaner_Einstellungen`; ein neues Modell übernimmt die zuletzt eingegebenen Werte). Quelle ist `gemeinsam/einstellungen.rb`, die jede Erweiterung als `src/kuechenplaner_gemeinsam/einstellungen.rb` mitbringt; Lesen mit `Kuechenplaner::Einstellungen.sockelhoehe`, `.wandabstand`, `.abstand_oberschrank`, `.arbeitsplatte_staerke`, `.unterschrank_hoehe`, `.oberschrank_unterkante(model, boden)` (alles mm):

| Einstellung | Standard | wirkt auf |
| --- | --- | --- |
| Sockelhöhe – Stellfüße (mm), 0–300 | 100 | Korpusunterkante von Unter- und Hochschränken über dem Fußboden. Der Sockel sind verstellbare Füße: keine Zuschnitt- oder Holzteile, nur die Sockelblende davor |
| Abstand Schrankrückseite – Wand (mm) | 0 | Andocken an die Wand; die Arbeitsplatte reicht trotzdem bis an die Wand (minus ihren eigenen Wandabstand 5 mm) |
| Lichter Abstand Arbeitsplatte – Oberschrank (mm) | 550 | Unterkante Oberschrank = Sockel + Korpushöhe + Arbeitsplatte + Abstand (Standard 1390 mm) |
| Stärke Arbeitsplatte (mm) | 40 | Höhe der Oberschränke |
| Korpushöhe Unterschrank (mm) | 700 | Höhe der Oberschränke |

**Beschläge – ganze Küche** (gespeichert im Modell, Wörterbuch `Kuechenplaner_Einstellungen`, Schlüssel `beschlag_<art>`; ein neues Modell übernimmt die zuletzt gewählten): je Beschlagart ein Modell aus dem **Beschlag-Katalog**, gültig für alle Schränke der Küche. TCN-Export, Beschlagliste und *Beschläge zeigen* folgen der Wahl sofort.

| Beschlagart | Modelle | Standard |
| --- | --- | --- |
| Klappe (eine Klappe) | Blum AVENTOS HK-top, Häfele Free Slim flap 1.12 | Blum AVENTOS HK-top |

Der Katalog liegt in `src/jt_schrank_cnc/katalog/`, eine JSON-Datei je Modell (`beschlagkatalog.rb`): Beschlagart, Bauart (Rechenweg, z. B. `klappe_seite`), Einsatzbereich (Hinweis im Export, wenn ein Schrank nicht passt), Bohrbild Korpus (`seite.loecher` = [ab Vorderkante, unter der Bezugskante]) und Front (`front.unter`, `front.innen` ab Innenseite der Seite) mit Bezugskante `oberkante` (Korpusoberkante) oder `deckel` (Unterseite des Deckels), Beschlagliste (`liste.posten`, Anzahl als Zahl oder `loecher_seite`/`loecher_front`/`loecher`), Modellkörper (`koerper`) und Quelle. Ein neues Modell einer vorhandenen Bauart ist nur eine neue Datei; der Test prüft jeden Eintrag auf Vollständigkeit. Alte Küchen ohne Einstellung: ein Klappenschrank mit der früheren Option Free Slim (`Art_Klappe` 3) behält Free Slim, bis die Einstellung gespeichert wird; der Dialog schlägt das häufigste Modell vor. Schubladen, Topfbänder, Hochauszug und Eckauszug kommen in den nächsten Schritten in den Katalog.

**CNC und Zuschnitt – alle Modelle** auf diesem Rechner (`Sketchup.write_default`, Sektion `JT_SchrankCnc`):

| Einstellung | Standard | wirkt auf |
| --- | --- | --- |
| Übermaß Länge gesamt (mm) | 10 | Rohmaß der längeren Seite, `OFFSET` der Fräsliste (halber Wert) |
| Übermaß Breite gesamt (mm) | 10 | Rohmaß der kürzeren Seite, `OFFSET` der Fräsliste (halber Wert) |
| Zuschnitt: Schnittbreite Sägeblatt (mm) | 3 | Abstand der Teile im Zuschnittplan (auch dort einstellbar) |
| Zuschnitt: Besäumen je Plattenkante (mm) | 10 | Randabfall im Zuschnittplan (auch dort einstellbar) |

## TCN exportieren
Über den [Export-Dialog](#export) (TCN gewählt), in den Unterordner `tcn` des Zielordners: je sichtbarem Teil eine TCN-Datei (Name = laufende Nummer der Stückliste + Tag, z. B. `102_UST2_StrebeVorn.tcn`; die Nummer ist dieselbe wie auf Stückliste, Etiketten und Zuschnittplan, wenn dieselben Schränke gewählt sind bzw. nichts ausgewählt ist; beide TCN einer Arbeitsplatte mit zwei Stoßenden haben die Nummer ihrer Stücklistenzeile). Eine eigene Teileliste gibt es nicht mehr (siehe [Export](#export)). Ist etwas ausgewählt, nur die Teile der ausgewählten Schränke.

**Fräsliste** `Liste_<Zielordner>.xmlst` (Aufbau wie csv2tcn und Treppenbau): alle TCN des Exports zusammen für das TpaCAD-Board, mit vollem Windows-Pfad, `REPETITIONS` = Stückzahl und `FIELD` 9. Sortiert nach Größe: größte Fläche DL × DH zuerst, bei gleicher Fläche die längere. `OFFSET X/Y` = halbes Übermaß aus den *Einstellungen* (Länge für die längere, Breite für die kürzere Seite), weil die TCN im Fräsmaß ist und das Rohteil um das Übermaß größer; `length_increase`/`width_increase` am Material werden nicht mehr gelesen; `OFFSET Z` = 0. `COMMENT` = Teilname (Name der Komponentendefinition, z. B. `Front S1`).

* Maße und Lagen sind **Fräsmaß**: an jeder Seite mit Anleimer (Kantenfläche mit Kante, Material-Typ 4) um dessen Stärke kleiner. DL ist die längere, DH die kürzere Plattenrichtung, DS die Stärke. Ausnahme Seiten: immer wie `Seite.tcn` DL = Höhe (Unterkante bei x = 0), DH = Tiefe, auch wenn die Seite tiefer als hoch ist.
* Stöße werden geometrisch gefunden: liegt die Stirnseite von Boden, Deckel, Zwischenboden oder Strebe an der Fläche einer Seite, gibt es eine Dübelreihe Ø8 (22 tief in die Stirnseite, 14 tief in die Seite wie `Seiten_SK`; Seiten sind immer gleich), mittig in der Plattenstärke. Boden/Deckel/Zwischenboden: erster und letzter Dübel 30 mm von der fertigen Kante (mit Anleimer), in der TCN (Fräsmaß) also 28 an einer Kante mit 2-mm-Anleimer und 30 ohne; „gerade Anzahl“ aus (0/0), Schritt ST errechnet: n = ⌈(L−60)/160⌉ + 1 Dübel, ST = (L−60)/(n−1) mit L = fertige Länge, also höchstens 160 mm Abstand (z. B. Tiefe 560, vorn Anleimer → 30 … x-28, 5 Dübel, ST 125). Die Seite bekommt dieselbe Reihe aus denselben Weltkoordinaten, nach dem Anleimen liegen die Löcher also übereinander. Strebe: genau 2 Dübel, 20 mm von der fertigen Kante (Fräsmaß 18 an der Kante mit Anleimer), ST = Abstand der beiden, 0/0 – wie `Strebe.tcn`. In die Seite kommt je Strebe eine Schraubbohrung Ø3, 21 tief, in der Mitte der Strebe.
* **Lochreihen** Ø5, 12 tief, Raster 32 in jeder Seite und jedem Fach ohne Schubladen zwischen zwei festen Böden (Boden, Zwischenboden, Deckel, Strebe): 35 mm von vorn und 35 mm vor der Hinterkante bzw. vor der Rückwandnut; in der Höhe ab 38 mm über dem Boden darunter bis 33 mm unter dem darüber (ergibt 55 … x-50 wie `Seite.tcn`). In Fächern mit Schubladen und in Gerätenischen (Fach über einem Boden mit `JT_Schrank`/`nische`, z. B. im Hochschrank Geräte) gibt es keine Lochreihe; Schubladen sitzen ohne Lochraster (Jürgen 2026-11-06), die Schienenbohrungen liegen genau unter dem Kasten.
* **Schienen** (Blum LEGRABOX free, Montageanleitung MD-015/4 S. 3, Bohrtiefe aus `Seiten_SK_L/R`): je sichtbarer Schublade Ø5, 14 tief, 37 und 69 mm ab Vorderkante der Seite und hinten alle bemaßten Schraubpunkte je Nennlänge NL: 350 → 37+192/224, 400–500 → 37+224/256, 550–600 → 37+224/256/320 (40 kg), 650 → 37+224/256/320/416 (nur 70 kg). NL steht als Attribut `NL` am Schrank und wird von dort gelesen; fehlt es, ist NL die größte mit NL + 3 ≤ lichte Tiefe (Vorderkante Seite bis Rückwand). Höhe = Kastenunterkante + `Hoehenoffset_Schiene`, mindestens 38 mm über dem festen Boden darunter (S. 4, sonst Meldung).
* **Zargenhöhe** (LEGRABOX free, alle Höhen aus dem Blum-Programm): F 241, C 177, K 128,5, M 90,5, N 66,5 mm. Holzrückwand C 148 (Anleitung), F 212, K 99, M 62, N 37 abgeleitet (Zarge − 29 mm); Fronthalter F/C 0/32/96/128, K/M 0/32, N 0 (abgeleitet). Die Komponenten nehmen die höchste Zarge, die unter der Front Platz hat (oberste Schublade 30 mm unter der Frontoberkante wegen der Strebe, darunter bis an die Frontoberkante, damit die Front Zarge und Fronthalter abdeckt) (F nur, wenn `Hoehe_Kastenrueckwand` nicht unter 148 gesenkt ist). Der Export erkennt das Modell an der Höhe der Kastenrückwand und meldet, wenn die Zarge über die Front oder in einen festen Boden ragt.
* **Frontbefestigung** (LEGRABOX, MD-015/4 S. 4; Bohrbild wie `SK_Vorderstueck_Frontbef.tcn`): Ø3, 5 tief in der Rückseite der Front, 14 mm von der Innenseite der Seite (= 14 + FA vom Frontrand), Löcher 0/32/96/128 mm übereinander bei Zarge C, 0/32 bei Zarge M. Das unterste sitzt 36 mm über der Kastenunterkante (mind. 51 mm über der Front-Unterkante). Stehende Teile (Fronten, Rückwand) haben y = 0 an der Unterkante. Hängen mehrere Kästen an einer Front (Apothekerschrank), nennt das Attribut `front` am Kasten deren Bereich; die Hochfront bekommt das Bohrbild dann für jeden Kasten.
* **Kastenboden** (`Schubkastenboden.tcn`): Falz in der Unterseite an beiden Enden der Breite für die Zargen, Rechteck 38 mm breit über die ganze Tiefe + 20 mm und ein zweites 20 mm breit, beide 8 tief (W#1022 `rect.tmcr`). Die Ø3-Löcher aus der Vorlage fehlen, Blum sieht sie nicht vor. Die Kastenrückwand wird nur formatiert.
* **Hochauszug Häfele HU Slim Base** (schmaler Unterschrank mit Handtuchauszug, Montageanleitung 4004110659MKT „Dimensions for CNC“): Schienen nur in der Seite aus dem Attribut `Seite_Beschlag` (links = LH, rechts = RH), je Schiene 3 Bohrungen bei 56, 280 und 330 mm ab Vorderkante der Seite, 52 und 436 mm über der Oberkante des Bodens. Front: 2 Halter mit je 2 Bohrungen, 14 mm von der Innenseite der Seiten (X = 84 bei M150, 134 bei M200), 103 und 487 mm über der Oberkante des Bodens. Alle Ø3 (mitgeliefert sind Schrauben Ø4 × 16), Seite 10 tief (Annahme), Front 5 tief. Keine Lochreihen in diesem Schrank. Ist der Einbauraum kleiner als von Häfele verlangt (lichte Weite 112, lichte Höhe 565, Tiefe 485 mm), kommt ein Hinweis.
* **Kesseböhmer LeMans II** (Eckschrank Blindeck, Variante Le Mans; Montageanleitung MA 406954 0000, S. 3 und 11): Größe aus dem Attribut `LeMans` (40/45/50/60), Türseite aus `Blindseite`. Säulenlager in Boden und Strebe vorn bei X = 426/476/526/626 mm ab der Innenseite der Seite an der Tür: Ø5 für die Systemschraube Ø6,3 × 13, 69 mm ab Vorderkante, dazu 2 × Ø3 (Holzschrauben Ø4,5, vorgebohrt, Annahme) 16 mm daneben auf 37 mm. Im Boden durchgebohrt von unten (dort liegen auch die Sockelfüße), dabei alle drei mit dem Durchgangsbohrer Ø5 (durch gibt es nur Ø5/6/8/10), in der Strebe 13 bzw. 10 tief von unten. Seitenprofil 500 in der Seite an der Tür: 8 × Ø5, 13 tief, 52 mm ab Vorderkante, unterstes 28 mm über dem Boden, Raster 64. Keine Lochreihen in diesem Schrank. Hinweis, wenn Korpusbreite (764/800/910/960 mm), Tiefe (500 mm) oder Strebe vorn (60 mm) zu klein sind.
* **Blum AVENTOS HK-top** (Oberschrank mit Klappe; Montageanleitung MD-039/2, S. 3–4, Maße abgeleitet und noch nicht an einem Probestück geprüft): Kraftspeicher in beiden Seiten mit 4 Bohrungen Ø5, 12 tief, in einer waagrechten Reihe 37/69/101/133 mm ab Vorderkante der Seite, 36 mm unter der Korpusoberkante. Frontbeschlag auf der Innenseite der Klappe je Seite 2 Bohrungen Ø5, 12 tief, 12,5 mm ab der Innenseite der Seite (Blum: SFA + 12,5 vom Frontrand), 62 und 94 mm unter der Korpusoberkante (Blum: 62 + FAo ab Frontoberkante, Raster 32). Maße im Katalog `katalog/blum-aventos-hk-top.json`. Für die Faltklappe AVENTOS HF gibt es noch keine Bohrungen, der Export meldet das.
* **Häfele Free Slim flap 1.12 / 1.10 push** (Oberschrank mit Klappe, Einstellungen › Beschläge › Klappe = Free Slim; Montageanleitung 732.23.046, Stand 02.10.2025): Mechanismus in beiden Seiten mit 2 Bohrungen Ø5, 10 tief (Dübel), 122,5 mm ab Vorderkante der Seite, 39,5 und 135,5 mm unter der Unterseite des Deckels (Schablone S. 15/16). Frontbeschlag auf der Innenseite der Klappe je Seite 4 Bohrungen Ø3, 5 tief, im Raster 32, 12 mm ab der Innenseite der Seite (Häfele: 12 + KS − F vom Klappenrand), 36/68/100/132 mm unter der Unterseite des Deckels (Häfele: 36 + KO − F ab Klappenoberkante). Maße im Katalog `katalog/haefele-free-slim-1.12.json`.
* **Blum-Topfbänder** (alle Türen, Vorlagen `T_re_L_Topfband.tcn` / `T_rR.tcn`): auf der Innenseite jeder Tür das Makro `inge100` (Topf Ø35, 14 tief, Schraublöcher Ø8 im Abstand 45 / 9,5) mit der Topfmitte 21,5 mm von der Anschlagkante; die Tür liegt dafür wie in der Vorlage mit der Anschlagkante bei `y = DH`. Anschlag = Drehpunkt des Türhalters, bei der Falttür hängt die längere Tür am Korpus und die kürzere am Eckscharnier an ihr (nur Topf, kein Gegenstück). Anzahl nach Türhöhe (Blum): bis 900 mm 2, bis 1600 3, bis 2000 4, bis 2400 5, darüber 6; das oberste und unterste Band möglichst 80 mm (mindestens 60 mm) vom Türrand. Die Montageplatte sitzt mit zwei Systemschrauben Ø5, 12 tief, 16 mm über und unter der Topfmitte 35 mm (Fräsmaß) hinter der Vorderkante der Seite. Wo die Seite eine Lochreihe hat, rücken die Bänder ins 32er-Raster und die Reihe bohrt die Schrauben mit; sonst (Gerätenische, Hochschrank Vorrat) kommen eigene Löcher. Hochschrank Vorrat: Höhen aus `Scharnier_1..6` am Schrank. Schlepptür des Hochschranks Kühlschrank: keine Bänder (hängt am Gerät). Maße in `Regeln::TOPFBAND`.
* **Innenecke einer L-Platte** (Eckschrank L-Form: Boden und Einlegeböden; Eck-Oberschrank: Boden, Deckel und Einlegeböden): Die Ecke steht als `ecke_x`/`ecke_y` an der Definition der Platte. Geschlossene Kontur mit dem Nutfräser 2200 durch die Platte (Stärke + 1 mm) von der Seite mit den übrigen Bearbeitungen (Unterschrank: unten bei den Sockelfüßen; Eck-Oberschrank-Boden: oben bei der Rückwandnut), an den Innenkanten 2 mm zurück (Anleimer, den die Stückliste dort nicht erkennt), nach außen 8 mm über die Platte hinaus. Sockelfüße je Schenkel, also auch an der Innenecke. In der Ecke stößt die Strebe von Schenkel B mit dem Ende an die Längskante der Strebe von A: Dübel wie Strebe–Seite, in die Kante 22 tief.
* **Kanalausschnitt** (Unterschrank Kochfeld mit Abzug): durchgehende Rechtecktasche (rect.tmcr, Stärke + 1 mm) von unten im Boden; Lage und Größe aus den Attributen `Ausschnitt_Links`, `Ausschnitt_Breite`, `Ausschnitt_Hinten`, `Ausschnitt_Tiefe` am Schrank (ab der Kante bei `SeiteL` bzw. bei der Rückwand).
* **Sockelfüße** (Unter- und Hochschränke): Bohrbild aus `Boden.tcn` in der Unterseite des Bodens, je Fuß 2 × 2 Bohrungen Ø3, 3 tief, Raster 64, 20 mm vom Rand in x und 60 mm in y; bei einem schmalen Boden (unter 248 mm, z. B. 112 mm im Handtuchschrank) nur ein Fuß je Ende, mittig. Der Boden liegt dafür mit der Unterseite nach oben.
* **Rückwandnut** (steckt eine Rückwand in Seiten und Boden, im Oberschrank; im Spülenschrank nur in den Seiten, die Rückwand steht dort auf dem Boden): Bahn mit dem Nutfräser 2200 (Ø 8,03 mm, wie im Treppenbau) als `W#89`/`W#2201`, Tiefe = Nuttiefe (9 mm), Breite = Rückwandstärke (breiter als der Fräser: mehrere Bahnen). Läuft die Nut aus der Platte, fräst sie 5 mm darüber hinaus.
* **Schräg- und Bogenkante** (Abschlussregal, Böden mit Wörterbuch `JT_Kontur` an der Definition): zugeschnitten wird das Rechteck, die Kante fräst der Konturfräser 1004 (Ø 20) von Fläche 1 ganz durch (Stärke + 1 mm), um den Fräserradius in den Abfall und um den Anleimer in die Platte versetzt. Ein- und Auslauf tangential außerhalb der Platte, Bögen als kurze Geraden (höchstens 5° und 10 mm je Stück), kein `W#2125` (TPA meldete beim runden Deckel „Radius ungültig“). Anleimer auf nicht achsparallelen Flächen zählt nicht ins Fräsmaß des Rechtecks, sondern steht in der Stückliste als *Kante Kontur* mit Länge. Sockelfüße, die über die Kante ragen würden, rücken nach innen.
* **Sockelausklinkung der Wange** (Blenden & Wangen, Wange mit *Sockelausklinkung ja*): `JT_Kontur` mit `ebene = yz` (Umriss in der Ebene der Wange). Gleicher Ablauf wie die Schrägkante mit 1004: zwei Geraden (Ausklinkung hinten, oben), in der Innenecke im Schnittpunkt der versetzten Bahnen verbunden, Start unter der Platte, Ende vor der Platte, Zustellung höchstens 20 mm. In der Innenecke bleibt Radius 10 mm. Kein Anleimer an der Ausklinkung.
* **Rückwand-Ausschnitt** (Spülenschrank): Lage und Größe stehen als Attribute `Ausschnitt_X/_Z/_B/_H` an der Rückwand. Geschlossene Kontur mit dem Nutfräser 2200 (`W#89` + 4 × `W#2201`), um den Fräserradius nach innen versetzt (Ecken bleiben mit Radius 4 mm), Tiefe = Rückwandstärke + 1 mm.
* **Zustellung**: Keine Fräsung geht in einem Zug tiefer als 20 mm (Materialschonung). Tiefere Bahnen (`W#89` + Bahnzeilen) und Taschen (`W#1022`) wiederholt der Export in gleich großen Schritten von höchstens 20 mm, z. B. 39 mm → 19,5 + 39. Jeder Schritt ist eine eigene Bearbeitung. Das gilt zentral für alle TCN (`Tcn.zustellen`), auch für die Arbeitsplatte.
* **Rohrausschnitt** (Oberschrank Dunstabzug): Attribute `Ausschnitt_X/_Y/_B/_T` an Haubenboden, Deckel und Einlegeboden (liegende Platte, Lage ab vorne links). Gleiche Kontur wie der Rückwand-Ausschnitt, von oben (Fläche 1), Tiefe = Plattenstärke + 1 mm. Bei Umluft ist die Breite 0, dann entfällt er.
* **Deckel–Rückwand** (nur Oberschrank): 3 Schrauben 50 mm von den Seiten und in der Mitte, Ø5 durch die Rückwand (1 mm tiefer als ihre Stärke, Durchgangsbohrer). Die Deckelkante wird nicht vorgebohrt, weil es waagrecht nur Ø8 gibt (Werkzeugliste).
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
* `src/jt_schrank_cnc/export.rb` – TCN-Export (Dateien, Nummern)
* `src/jt_schrank_cnc/ausgabe.rb` – Export-Dialog für Stückliste, Etiketten, Zuschnitt und TCN (Zielordner, Unterordner `tcn`)
* `src/jt_schrank_cnc/fraesliste.rb` – Fräsliste `Liste_<Ordner>.xmlst`
* `src/jt_schrank_cnc/einstellungen.rb` – allgemeine Einstellungen (Übermaß) und das Einstellungen-Fenster; Sockel und Abstände in `gemeinsam/einstellungen.rb`
* `src/jt_schrank_cnc/stueckliste.rb` – Stückliste (PDF und CSV)
* `src/jt_schrank_cnc/beschlaege.rb` – Beschlagliste (Schubladen, Türen, Klappen) für die Stückliste
* `src/jt_schrank_cnc/pdf.rb` – kleiner PDF-Schreiber (Text, Linien, Flächen, QR-Code), ohne fremde Bibliothek
* `src/jt_schrank_cnc/rqrcode_core/` – QR-Code-Erzeuger rqrcode_core (MIT, siehe `THIRD_PARTY.md`)
* `src/jt_schrank_cnc/etiketten.rb` – Etiketten als PDF (Bogen oder Endlos)
* `src/jt_schrank_cnc/guillotine.rb` – Guillotine-Optimierer in 2 oder 3 Stufen (erster Schnitt, Schnitttyp, Reste)
* `src/jt_schrank_cnc/zuschnitt.rb` – Zuschnittplan als PDF für die Formatsäge
* `test/test_materialien.rb` – Material-Konfigurator: Anlegen, Bearbeiten, Umbenennen, Löschen, Bibliothek, Maserrichtung, Korpusmaterial
* `test/test_frontfarbe.rb` – erzeugt Hochschrank, Oberschränke und Unterschrank mit den Skripten aus `Komponenten/` in der Mock-API und prüft Frontfarbe, Anleimer, Bereiche, Auswahl, Eindeutigmachen, Griffe und den Dialog
* `test/test_stueckliste.rb` – Stückliste an Hochschrank und Unterschrank: Roh-/Fräs-/Fertigmaß, Kanten, Übermaß aus den Einstellungen, CSV, Druckseite, Dialoge
* `test/test_zuschnitt.rb` – Zuschnittplan an Hoch-, Unter- und Oberschrank: alles platziert, keine Überlappung, Schnittbreite und Randabfall eingehalten, alle Kombinationen aus erstem Schnitt, Schnitttyp und Stufen (Schnitte wirklich durchgehend, Stufen eingehalten), Faserrichtung, Plattenreste, Reste behalten, gleiche Platten, PDF, Dialog
* `test/test_etiketten.rb` – Etiketten-PDF: Bogen-Lage, Startposition, Endlos, Roh-/Fräs-/Fertigmaß, QR-Code, Format-Dialog
* `test/test_pdf.rb` – PDF-Schreiber: gültiger Aufbau (xref), Umlaute, Textbreite, QR-Code
* `test/test_export.rb` – TCN-Export an Unterschrank, Oberschrank, Hochschrank, Hochschrank Geräte und Hochschrank Kühlschrank (Lüftungsschacht: gekürzte Böden, Nut der Rückwand), Vergleich mit `beispiele/` (Boden mit Sockelfüßen, Strebe, Seite mit Lochreihen), Nut und Schrauben im Oberschrank, Spülenschrank (Ausschnitt, Nut, Auszug, Türen), Eckschrank (Blende, Le Mans, L-Form), Eck-Oberschrank (Nut im L-Boden, Deckelschrauben, Innenecke)

## Grundidee
1. Teile einsammeln (sichtbare Instanzen mit Tag nach dem Schema `<Kürzel>_<Bereich>_<Teil>`).
2. Teile vermessen, Anleimer aus den Kantenflächen lesen, Lagen im Fräsmaß.
3. Stöße zwischen Teilen finden und daraus Dübel, Lochreihen, Topfbänder und Schienenbohrungen ableiten.
4. Eine TCN je Tag schreiben, dann die Fräsliste.

## Schritte
1. ~~Tags aller Komponenten vereinheitlichen.~~ Erledigt: Hochschrank `HS<n>`, Unterschrank Schubladen `USS<n>`, Unterschrank Tür `UST<n>`, jeweils mit `JT_Schrank`.
2. ~~Oberschrank-Skript~~ (`Komponenten/oberschrank/`, Kürzel `OS<n>`).
3. ~~Schubkasten:~~ Blum LEGRABOX (Boden und Holzrückwand), Schiene ohne Lochraster unter dem Kasten, Höhenoffset Schiene.
4. ~~Frontfarbe und Griffe.~~
5. ~~Erster Export nur Korpus, Vergleich mit den Beispiel-TCN.~~
6. ~~Lochreihen, Sockelfüße, Rückwandnut.~~
7. ~~Schubladen: Schienenbohrungen, Frontbefestigung, Kastenboden, Generatoren auf LEGRABOX.~~
8. Türen und Griffbohrungen.
9. Dialog, Listen.

## Lizenz
GPL-3.0 ([LICENSE](LICENSE)), von Jürgen am 01.11.2026 so festgelegt. Fremder Code: rqrcode_core (MIT), siehe [THIRD_PARTY.md](THIRD_PARTY.md).
