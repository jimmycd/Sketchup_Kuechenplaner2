# SketchUp-Plugin „Schrank-CNC“ (TCN-Export, Stückliste, Etiketten, Zuschnitt, Materialien, Frontfarbe, Andocken)

**Stand:** *Frontfarbe ändern* und der *Griffkatalog* sind fertig. Der TCN-Export schreibt den Korpus: Formatieren, Dübel Boden/Deckel/Zwischenboden/Strebe an die Seiten, Schrauben in die Streben, Lochreihen für Einlegeböden, Sockelfüße, die Rückwandnut im Oberschrank und im Spülenschrank sowie den Rückwand-Ausschnitt im Spülenschrank und den Rohrausschnitt im Oberschrank Dunstabzug. Für Schubladen (Blum LEGRABOX), den Hochauszug Häfele HU Slim Base Kesseböhmer LeMans II im Eckschrank und die Klappe (Blum AVENTOS HK-top oder Häfele Free Slim) kommen die Schienenbohrungen in die Seiten, die Frontbefestigung in die Front und der Falz in den Kastenboden; Türen bekommen Blum-Topfbänder (Topf in der Tür, Montageplatte in der Seite); Fronten mit Griff bekommen die Griffbohrungen.

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

## Frontfarbe ändern
*Erweiterungen › Küchenplaner › Frontfarbe ändern…*

Griffe stehen hier nicht mehr (Jürgen 2026-11-07): Serie und Oberfläche wählt man im *Griffkatalog*, Größe, Lage und Höhe je Schrank in *Beschläge und Griffe der gewählten Schränke…* (siehe *Griffkatalog*).

| Feld | Bedeutung |
|---|---|
| Frontmaterial | alle Platten mit Verwendung „Front“ aus Modell und Bibliothek (siehe *Materialien*; alte Modelle: Name beginnt mit „Front“). *Neues Frontmaterial…* legt eins an; gibt es noch keins, öffnet sich gleich dieses Formular. |
| Bereich | alle Schränke, nur Oberschränke, nur Unterschränke oder nur Hochschränke (`kategorie` in `JT_Schrank`) |
| Nur ausgewählte Schränke | Ja: nur Schränke, die gerade ausgewählt sind |

Das Frontmaterial kommt auf Fronten und Türen (`rolle` Front, Tuer) und auf die Sichtteile ohne Griff: Verkleidung der Inselrückseite (`Verkleidung`) und Abschlusswangen (`Wange`, Inselschrank und Geschirrspüler).

Vor dem Ändern fragt das Plugin nach, z. B. „5 Fronten in 3 Schränken bekommen „Front Eiche 19mm“. Übernehmen?“ (gezählt werden sichtbare Fronten). Ein Schritt *Rückgängig* macht alles zurück.

Was geändert wird:
* Fronten sind alle Teile mit `rolle` Front oder Tuer, auch ausgeblendete Schubladen und Türen. Korpus und Schubkästen bleiben unverändert.
* Dazu Teile mit `JT_Schrank/frontfarbe` (Abschlussregal mit Farbe „Frontfarbe“): sie bekommen Material und Anleimer, aber keine Griffe.
* Das Material kommt an die Instanz und als DC-Attribut `material`, damit es ein Neuzeichnen der Dynamic Component übersteht.
* Die Anleimer der Fronten (Kantenflächen mit einem Anleimer-Material) bekommen den zugeordneten Anleimer der Platte; ohne Zuordnung eine Kante mit dem Dekor im Namen („Anleimer Eiche“ zu „Front Eiche 19mm“), sonst legt das Plugin „Anleimer <Dekor>“ an (2 mm, Abzug an) und merkt sich die Zuordnung.
* Teilen sich Schränke im Modell dieselbe Definition (z. B. zweimal derselbe Oberschrank eingefügt) und ist nur einer gewählt, macht das Plugin den Weg zu dessen Fronten eindeutig. Korpusteile bleiben geteilt.
* Griffe (aus Griffkatalog und Schrank-Dialog) bleiben unverändert.

## Griffmulde gefräst (grifflos)
Jürgen 2026-11-07, Plan „Grifflose Fronten“ (Schritt 1 von 3; Griffkante und durchlaufende Mulde siehe unten). Unter *Einstellungen › Beschläge – ganze Küche › Öffnung* oder je Schrank (*Beschläge und Griffe der gewählten Schränke…*) **Griffmulde gefräst** wählen:

* Jede Front eines **Unter- oder Oberschranks** bekommt statt Griffbohrungen eine Ausklinkung ganz durch die Front: Unterschrank an der **Oberkante** (Eingriff von oben), Oberschrank an der **Unterkante** (von unten). **Hochschränke sind ausgenommen** und behalten ihre Griffe.
* Lage: Tür mit Topfbändern an der Öffnungskante (Abstand vom Rand), kurze Falttür des Eckschranks an ihrer freien Kante (die lange bekommt keine), Schubladen, Klappen und Türen ohne Topfband mittig. Im Oberschrank nur die unterste Front (nicht der obere Teil der Faltklappe). Ist die Front schmal, wird die Mulde schmaler (20 mm Steg je Seite); geht auch das nicht, meldet der Export die Front.
* Maße (Vorschlag, von Jürgen bestätigt, **änderbar** in den Einstellungen, im Modell gespeichert): Breite 160, Tiefe ab der Frontkante 30, Abstand zur Öffnungskante der Tür 40, Eckradius 10 mm. Der Eckradius ist mindestens 10, weil der Konturfräser **1004 (Ø 20)** die Mulde fräst (wie die Schrägkante des Abschlussregals: Bahn um den Fräserradius versetzt, Ein- und Auslauf außerhalb der Front, Bögen als kurze Geraden, ganz durch).
* Im Modell wird die Mulde in die Front geschnitten (die Maße der Front bleiben, die Schnittflächen haben die Frontfarbe) und gerendert; zurück auf Griffe gibt wieder den vollen Quader. Keine Griffe in der Beschlagliste.

## Griffkante 45° und Griffmulde durchlaufend (grifflos)
Plan „Grifflose Fronten“, Schritt 2: **Oberschränke** (Oberschrank, mit Klappe, Dunstabzug, Eck-Oberschrank), Schritt 3a: **Griffkante an allen Unterschränken**. Die **durchlaufende Mulde im Unterschrank folgt** (Schritt 3b: Strebe, Muldenblende oder Alu-Profil, Seiten ausgeklinkt); bis dahin behalten Unterschränke bei dieser Wahl ihre Griffe. **Hochschränke sind ausgenommen**. Wahl wie die Griffmulde unter *Öffnung* (Küche oder je Schrank):

* **Griffkante 45°** (Bild 2): die unterste Front des Oberschranks ist unten **25 mm kürzer** (Faltklappe: das untere Teil) und hat auf der **Rückseite an der Unterkante eine Fase 45°, 13 mm tief**. TCN: Bahn mit dem **1400 Folding 45°** entlang der Kante (Spitze auf der Kante der gefrästen Platte, Tiefe = Fase, Start und Ende 20 mm außerhalb der Front), auf Fläche 1 von innen wie die Griffbohrungen. **Unterschrank**: über **jeder Front** (Tür, jede Schubladenfront, Front von Geschirrspüler und Kühlschrank, Schublade unter dem Backofen) sind **25 mm Luft**, die Fase sitzt an der **Oberkante**. Schubladen teilen die Höhe wie vorher, jede ist um ihren Anteil kürzer; feste Blenden (Spüle, Kochfeld, Backofen, Blindeck) bleiben stehen, nur die Blende des Blindeckschranks wird bündig mit der Tür gekürzt. Im Modell wird die Fase in die Front gezeichnet (Fasenfläche in Frontfarbe). Angenommen: der Folding-Fräser hat 90° Spitze (45° je Flanke) – bitte am Probestück prüfen.
* **Griffmulde durchlaufend** (Bild 3): der **Boden sitzt 30 mm höher**, die Front bleibt und steht unten über; Rückwand und Einlegeböden rücken mit (Lochreihe, Bodenverbinder und Rückwandmaß folgen dem Modell). Der Dunstabzugsschrank hat unten keinen Boden und bleibt, wie er ist.
* Maße (Vorschlag, von Jürgen bestätigt, **änderbar** in den Einstellungen, im Modell gespeichert): Fase 13, Front kürzer 25, Boden höher 30 mm.
* Umsetzung: die Komponenten haben die Attribute `Griff_Front` (Oberschrank: Front unten kürzer, Unterschrank: Luft über jeder Front) und `Griff_Boden` (Boden höher). Schrank-CNC setzt sie nach der Wahl (Einstellungen, Schrank-Dialog, neuer Schrank) und zeichnet den Schrank neu (`grifflos.rb`). Schränke, die vor dieser Version angelegt sind, haben die Attribute nicht: das Programm nennt sie, bitte neu anlegen.

## Griffkatalog
*Erweiterungen › Küchenplaner › Griffkatalog…* (Jürgen, 2026-11-07)

Der Griffkatalog enthält alle Griffe und Knöpfe der **Häfele DÉCO Kollektion 2025** (81 Serien, 563 Artikel), aus Jürgens Blätterkatalog ausgelesen: je Serie Bauart (Griff oder Knopf), Oberflächen, Größen (Länge × Höhe, Lochabstand), Artikel-Nr., Katalogseite und **ein Bild** (die Fotoseite der Serie aus dem Katalog). Daten: `src/jt_schrank_cnc/griffe/haefele-deco-2025.json`, Bilder `griffe/<Serie>.jpg` (`griffkatalog.rb`); ein weiterer Katalog ist eine weitere JSON-Datei in diesem Ordner. Ausgelesen mit `werkzeuge/griffkatalog_auslesen.py`.

* **Fenster Griffkatalog**: alle Serien als Karten mit Bild (Klick vergrößert), Lochabständen, Oberfläche zur Auswahl und Tabelle der Größen mit Artikel-Nr.; Suche und Filter Griffe/Knöpfe. *Für diese Küche wählen* setzt **Griffserie und Oberfläche der Küche** (im Modell gespeichert, auch unter *Einstellungen › Beschläge – ganze Küche*). *Keine Serie* schaltet das ab.
* **Automatisch**: Hat die Küche eine Griffserie, bekommt jede Front und Tür (nicht Blenden, Innenfronten, Wangen) einen Griff in der vorgeschlagenen Größe, mittig, auf der automatischen Höhe. Ohne Serie bleibt es wie vorher: Griffe nur dort, wo sie von Hand gesetzt sind.
* **Vorschlag** (Regel, nicht aus dem Katalog): Ziel-Lochabstand = 20 % der **Frontbreite** (30 % war Jürgen zu groß), genommen wird der nächstliegende Lochabstand der Serie (bei Gleichstand der kleinere), dessen Griff mit 20 mm Abstand je Seite auf die Front passt. Grundlage ist die Front, nicht der Schrank (Doppeltür am 800er-Schrank: zwei 400er-Türen → 96). Beispiele mit 96/128/160/192/320: 300 → 96, 450 → 96, 600 → 128, 900 → 192. Knopf-Serien: eine Bohrung in der Mitte.
* **Eckschrank L (Falttür)**: nur die kurze Tür (am Eckscharnier, an ihr zieht man) bekommt einen Griff, äußeres Loch 35 mm von ihrer freien Kante; die lange Tür am Korpus keinen (außer von Hand gesetzt).
* **Höhe automatisch**: Griffmitte möglichst 1000 mm über dem Boden, mindestens 35 mm von Ober- und Unterkante der Front: Unterschrank-Fronten oben, Oberschränke unten, hohe Türen auf 1000 mm. **Lage automatisch**: Mitte.
* **Je Schrank änderbar** (*Beschläge und Griffe der gewählten Schränke…*): Griff = *Vorschlag nach Frontbreite*, eine Größe der Serie, *eigenes Lochmaß* oder *kein Griff*; Lage *automatisch (Mitte)*, links, Mitte, rechts; Höhe leer = unverändert, `auto` oder mm ab Unterkante Front. Der Dialog zeigt den Vorschlag je Frontbreite der gewählten Schränke. Die Angaben stehen an der Front (`griff_lochmass`, `griff_lage`, `griff_hoehe`, `griff_aus`).
* **TCN**: die Griffbohrungen (Ø3, 5 tief, von innen) nehmen den Lochabstand aus dem Katalog (Griffe mit zwei Lochabständen wie 128/160 werden mit dem gewählten gebohrt). Grifflos (TIP-ON, SERVO-DRIVE): keine Griffe.
* **Beschlagliste**: Gruppe *Griffe*, z. B. „Häfele H2585 Griff 192 mm, schwarz matt – Art.-Nr. 106.71.433, 204 × 32 mm“, Stückzahl je Front. Ein Lochmaß, das die Serie nicht hat, steht ohne Artikel-Nr. da.
* **Modell und Rendern**: Griffe werden immer gezeichnet (nicht nur bei *Beschläge ein/aus*): Stange über die Länge mit Stützen an den Bohrungen bzw. Knopf, Maße aus dem Katalog, Material nach der Oberfläche („Griff schwarz matt“ → Metall im Rendern; Eiche → Holz). Gruppe „Griffe“ auf Tag *Griffe* im Elternteil der Front (Schublade, Türhalter, Schrank), damit die Front ihre Maße behält; sie folgen Änderungen am Schrank. Der Blender-Export nimmt den Tag *Griffe* immer mit, auch wenn die Szene *Kunde* ihn ausblendet.

## Freier Schrank
Ein Schrank, den es als Komponente nicht gibt, kann frei modelliert werden und läuft trotzdem in Stückliste, Etiketten, Zuschnitt, TCN-Export, Beschlagliste und Rendern mit (Jürgen, 2026-11-07). Menü *Küchenplaner › Freier Schrank*:

**Neu anlegen:** *Freien Schrank anlegen…* fragt Kategorie, Name, Breite, Höhe, Tiefe, Korpusstärke und Rückwand ab (Standard: Unterschrank aufgesetzt mit Streben vorn/hinten 100 mm, Ober-/Hochschrank genutet 8 mm in 9 mm Nut 25 mm von hinten mit Deckel) und dockt den Schrank an. Danach in den gewählten Schrank, je Fach (zwischen Seiten/Mittelwänden):
* *Mittelwand einsetzen…* (Abstand von links, leer = Mitte; gedübelt mit Boden, Deckel/Streben und Zwischenböden),
* *Einlegeboden einsetzen…* (vorn 10 mm zurück) und *Zwischenboden einsetzen…* (volle Tiefe, gedübelt), Höhe über dem Boden, leer = Mitte,
* *Tür einsetzen…* (Anschlag links, rechts oder doppelt; außen voller, an Mittelwänden halber Aufschlag, 2 mm Spalt; Tür im Halter, Topfbänder an der Anschlagseite, öffnet mit Interagieren),
* *Schublade einsetzen…* (Unterkante und Höhe der Front; Kastenboden, Holzrückwand und Zarge nach dem Schubladenauszug der Küche, Bereich S1, S2 … automatisch, fährt mit Interagieren aus),
* *Blende einsetzen…* (feste Front).

Bearbeitungen auf beiden Flächen (Mittelwand: Schienen zur einen, Lochreihe zur anderen Seite; Boden mit Sockelfüßen unten und Mittelwand-Dübeln oben) bekommen wie beim Wandregal ein zweites Programm `<Nr>_<Tag>_Rueckseite.tcn` fürs gewendete Werkstück; in Stückliste, Etiketten und Zuschnitt bleibt es ein Teil. Lochreihen gibt es nur in Fächern ohne Schubladen, bei Mittelwänden je Fach.

**Von Hand modelliert:**

1. **Als freien Schrank kennzeichnen…** – die Gruppe/Komponente mit allen Teilen wählen, Kategorie (Unter-, Ober-, Hochschrank) und Name angeben. Der Schrank bekommt das Kürzel FS1, FS2 … und den Typ „Frei“.
2. **Teil zuweisen…** (auch im Kontextmenü) – den Schrank öffnen, ein oder mehrere Teile (Komponenten, Gruppen werden umgewandelt) wählen: Teil (Seite links/rechts, Mittelwand, Boden, Deckel, Streben, Zwischen-/Einlegeboden, Rückwand, Tür, Klappe, Front, Blende, Kastenboden, Kastenrückwand, Innenfront, Wange, Leiste, Sockelblende), Bereich (z. B. S1 für eine Schublade), Material (Standard *Melamin weiss*), Anleimer je Richtung (vorn, hinten, oben, unten, links, rechts; die Hauptflächen bekommen nie einen) und bei Seiten/Mittelwänden **Lochreihe ja/nein**. Der Tag `<Kürzel>_<Bereich>_<Teil>` entsteht automatisch und eindeutig (Einlegeboden, Einlegeboden2 …).
3. **Schrank prüfen** – meldet Teile ohne Rolle (fehlen sonst in Stückliste und TCN), Teile ohne Plattenmaterial, Formteile ohne Kontur, schräg liegende Teile, doppelte Tags, Überschneidungen sowie Schubladen ohne Bereich, Front oder Kastenrückwand. Dieselben Meldungen zeigt der Export.

**Bibliothek eigener Schränke:** *Als eigenen Schrank speichern…* legt den gewählten freien (oder gelösten) Schrank als `<Name>.skp` mit `<Name>.json` (Version, Datum, Kategorie, Maße, Beschreibung) im Bibliotheksordner ab (Standard `E:\sketchup komponenten\Bibliothek`, änderbar über *Bibliotheksordner…*). Erneut gespeichert zählt die Version hoch, die vorige Fassung kommt nach `alt/<Name>_v<n>.skp`. *Eigenen Schrank einfügen…* lädt ihn in die aktuelle Küche, gibt ihm ein neues Kürzel (FS2, FS3 …, alle Tags umbenannt) und dockt ihn an. *Freier Schrank…* steht auch in den Menüs Unter-, Ober- und Hochschränke und in der Schrank-Auswahl der Symbolleiste.

**Schrank lösen:** *Schrank lösen (frei bearbeiten)…* macht einen fertigen Schrank (z. B. USS1) frei bearbeitbar: eigene Definition, die Formeln der Komponentenoptionen werden entfernt (Maße bleiben, nichts zeichnet sich mehr neu), Kürzel und Tags bleiben. Danach gehen Teil zuweisen, Einsetzen und Speichern wie beim freien Schrank.

Die Bearbeitungen entstehen wie bei allen Schränken aus Rolle und Lage: Dübel, wo Böden/Streben an Seiten stoßen, Nut für die Rückwand, Lochreihen je Fach, Schienen und Frontbefestigung je Schublade (Bereich), Topfbänder für Türen in einem „…Halter“, Beschläge aus dem globalen Beschlagkatalog. Eine Mittelwand zwischen durchlaufendem Boden und Deckel bekommt die Lochreihen auf beiden Flächen. Ein freier Schrank ist nicht parametrisch (keine Maßänderung über Komponentenoptionen).

## Schrank andocken
Neue Schränke muss man nicht von Hand verschieben und drehen. Gilt für alle Schränke aus dem Menü *Unterschränke*, *Oberschränke* und *Hochschränke*. Regeln von Jürgen (2026-11-05):

* **Immer an der Wand:** Jeder Schrank steht mit der Rückseite im *Abstand Schrankrückseite – Wand* (*Einstellungen*) an einer Wand des Raums und lässt sich nur an ihr entlang schieben. An den Wandenden rastet er ein (dort auch seitlich mit Wandabstand zur Nachbarwand), ebenso an Tür-/Durchgangslaibungen (Fang 100 mm).
* **Nie ineinander:** Ein Schrank kann nie in einen anderen Schrank oder in eine Wand gesetzt werden. Beim Schieben bleibt er am Hindernis liegen; passt er nirgends, steht „kein Platz“ in der Statuszeile.
* **Höhen fest:** Unter- und Hochschränke stehen auf Fußboden + Sockelhöhe, Oberschränke auf Arbeitsplattenhöhe + lichter Abstand Arbeitsplatte/Oberschrank (*Einstellungen*, Vorgabe 40 + 550 mm), höchstens bis unter die Decke.
* **Nachbarn berühren sich:** Unter-/Hochschränke und Oberschränke untereinander berühren sich an der **unteren vorderen Korpusecke** (Korpus, nicht Front). Ist der neue Schrank flacher als der Nachbar, kommt er mit der Vorderkante bündig nach vorn; ist er tiefer, bleibt die Rückseite im Wandabstand. Gemessen wird nur an Seiten, Wangen und Rückwand, nicht an Fronten, Geräten oder Arbeitsplatte. Geräteschränke ohne eigene Seite (Geschirrspüler, Unterbau-Kühlschrank) haben eine virtuelle Seite; ihr Gerät steht auf dem Fußboden. Neben einem L-Eckschrank oder Eck-Oberschrank zählt der Schenkel, an dem der neue Schrank steht: Vorderkante bündig mit dessen Seite, nicht mit der Vorderkante des ganzen Ecks.
* **Inselschränke** folgen der Maus frei im Raum (Kollision wird trotzdem geprüft).
* **Wandregal** (Kategorie `Wandregal`, Jürgen 2026-11-07): hängt frei an der Wand, reiht sich nie an Oberschränke an und wird nicht angedockt (auch nicht, wenn ein Schrank markiert ist), andere Schränke reihen sich auch nicht an ihm an. Es hängt immer an der Maus, Rücken direkt an der Wand, nur entlang der Wand verschiebbar (Tab = andere Wand), Kollision wie bei allen. Höhe: Unterkante = Arbeitsplattenoberkante (Sockel + Unterschrankhöhe + Arbeitsplatte, *Einstellungen*) + *Unterkante über Arbeitsplatte* des Regals, höchstens bis unter die Decke; Pfeil hoch/runter ändert sie beim Platzieren um 10 mm, die neue Höhe steht danach im Regal.

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

**Beschlagliste:** Die letzte Seite der PDF (und `<Name>_Beschlaege.csv` daneben) listet die Beschläge aller Schubladen, Türen und Klappen, gezählt aus denselben Bohrbildern wie der TCN-Export (`beschlaege.rb`): je Schublade LEGRABOX-Zargen C/K/M/N (bei LEGRABOX pure auch F) mit Nennlänge, Korpusschienen (40 kg, NL 650 70 kg), Rückwandhalter, Fronthalter, bei Zarge C zwei seitliche Einschubelemente (Glas 10 mm, 138 × NL − 112; laut Blum-Katalog nur bei C), Seitenstabilisierung ab Korpusbreite 600, Schrauben 4 × 15 für Fronthalter und Boden (8 je Boden, S. 5) und Systemschrauben für die Schienen; je Tür Blum-Topfbänder Ø35 mit Montageplatte und Systemschrauben; je Klappe AVENTOS HK-top bzw. Häfele Free Slim (Mechanismus L + R, Frontbeschläge, 4 Dübel, 8 Schrauben 4 × 20, 8 Schrauben 4 × 15). Höhenprobleme der Schubladen stehen auch als Hinweis auf der Stückliste.

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
| LEGRABOX-Seiteneinsatz (Glas, 10 mm, Einsatzhöhe × NL − 112) | im Fenster der Zarge (nur Zarge C) | Schublade |
| LEGRABOX-Seitenstabilisierung | quer zwischen den Zargen oben vor der Holzrückwand, ab Korpusbreite 600 | Schublade |
| Kesseböhmer LeMans II: Säule Ø30, Seitenprofil, 2 Tablare (Rand 50, Ecken R120) | Säule über den Lagern, Profil an den Profilbohrungen, Tablare von der Seite bis hinter die Säule | Schrank |
| Häfele HU Slim Base: 2 Schienen 12 × 30 | an den Schienenbohrungen der Seite | Schrank |
| HU Slim Base: Fronthalter, Gestell, 2 Körbe | an den Frontbohrungen, Körbe auf deren Höhe | Auszug |
| AVENTOS HS top / HL top: Kraftspeicher, Hebel, Frontbefestigung | wie HK-top, Maße aus dem Katalogeintrag | Schrank / Klappe |
| AVENTOS HF top Kraftspeicher 30 stark (Katalog S. 24: Oberkante A 66,5/89 unter Korpusoberkante, B 171,5/194 hoch je Korpushöhe), Hebel 10 × 10, Hebelhalter | Kraftspeicher an den Bohrungen der Seite, Hebel zum Halter an der unteren Klappe | Schrank / untere Klappe |
| AVENTOS HF top Scharniere: 4 Töpfe Ø35 × 13, Montageplatten 48 × 20 × 4, Arme | Töpfe an den Oberkanten beider Klappen, Platten unter dem Deckel und auf der oberen Klappe | Klappe bzw. Schrank |
| Eckschrank-Falttürscharnier: Topf an der Ecke der langen Tür, Montageplatte | an den Bohrungen der langen bzw. kurzen Tür | Tür |
| MERIVOBOX / TANDEMBOX antaro: Zargen, Schienen, Halter | wie LEGRABOX, Maße aus dem gewählten Schubladenauszug | Schublade / Schrank |
| SERVO-DRIVE (Öffnung): Trägerprofil 30 × 12 (PL = LH − 10 auf 10 abgerundet), Antriebseinheit 120 × 60 je Auszug, Distanzpuffer Ø8 × 2 | Profil senkrecht mittig vor der Rückwand, Antrieb A = 45 (TANDEMBOX 35) über Unterkante Korpusschiene, Puffer auf der Front (FH bis 300: 2 in halber Höhe, sonst 4 je 20 vom Rand, seitlich Mitte des Aufschlags) | Schrank / Schublade |

Die Lagen kommen aus denselben Bohrbildern wie TCN-Export und Beschlagliste (`Regeln.anwenden`), passen also immer zu den Bohrungen. Die Körper liegen in einer Gruppe „Beschläge“ auf dem Tag **Beschlag** (Materialien „Beschlag Alu grau“, „Beschlag Stahl vernickelt“, „Beschlag Kunststoff grau“, im Rendern Metall) innerhalb des Schranks; sie haben kein `JT_Schrank/teil`, Stückliste, Etiketten, Zuschnitt, TCN-Export, Beschlagliste und Andocken sehen sie nicht. Solange der Schalter an ist, folgen sie jeder Änderung an einem Schrank (Komponentenoptionen); Verschieben und Öffnen (Interagieren) ändern nichts. Steht eine Tür oder Klappe gerade offen (eine Instanz zwischen Schrank und Tür ist gedreht, z. B. Türhalter oder Falttür-Halter), wird der Schrank nicht neu berechnet (die Bohrbilder stimmen dann nicht), sondern erst, wenn sie wieder zu ist. Bis Plugin 0.22 galt der Eckschrank L zu als offen und gefaltet als zu; die Bänder lagen dann quer im Schrank. Teilen sich zwei Türen eine Definition, aber die Töpfe säßen verschieden, bekommt sie keine Töpfe. Ausschalten löscht alle Beschlag-Gruppen. Die Platzhalter der Komponenten für LeMans und HU Slim Base (Tag `<Kürzel>_LeMans` bzw. `<Kürzel>_Beschlag`) sind ausgeblendet, solange die Beschläge gezeigt werden. Jedes Modell im Beschlag-Katalog muss hier einen Körper haben, `test/test_beschlagmodell_alle.rb` prüft das für jeden Katalogeintrag (ein neuer Eintrag ohne Zeichnung lässt den Test scheitern). Bewusst ohne Körper: Griffe (Griffbohrungen im TCN; ein Griff stünde vor der Front, außerhalb der Komponentengrenzen) und Sockelfüße (unter dem Korpus, ebenfalls außerhalb). Abgeleitet, nicht im Katalog bemaßt: Querschnitt SERVO-DRIVE-Trägerprofil und Antriebseinheit, Vorderkante HF-Kraftspeicher 15 hinter der Seitenvorderkante.

## Bohrungen, Dübel und Schrauben zeigen
*Erweiterungen › Küchenplaner › Bohrungen, Dübel, Schrauben ein/aus* oder das Icon **Bohrungen zeigen** (Jürgen 2026-11-07: „Rendere alle Bohrungen, Schrauben und Dübel“). Eigener Schalter, unabhängig von *Beschläge zeigen*: eine Küche hat einige tausend Löcher, das Modell soll nur dann so schwer sein, wenn man es prüfen will.

| Körper | woher | Maß |
|---|---|---|
| Bohrung (Material „Bohrung“, fast schwarz) | jede Einzelbohrung und jedes Loch einer Reihe aus `Regeln.anwenden`: Lochreihen, Dübel, Schienen, Fronthalter, Montageplatten, Klappenbeschläge, Griffe, Sockelfüße, Sockelklemmen, Rückwand … | Ø × Tiefe wie im TCN; Reihe ab p0 im Raster ST, „verteilt“ gleichmäßig |
| Topfband | Topf und die 2 Dübellöcher (inge100: Abstand längs der Kante, Versatz von der Kante weg) | Ø35 × 13, Ø8 × 14 |
| Fräsung (Nut, Tasche) | Rückwandnut, Taschen | Breite × Tiefe wie im TCN |
| Dübel (Material „Dübel Buche“) | jede Dübelbohrung in der Stirnseite von Boden, Deckel, Zwischenboden, Strebe, Mittelwand | Ø8 × 35: 21 im Teil, 14 in der Seite |
| Schraube mit Senkkopf (Material „Schraube verzinkt“) | Schraubenbohrungen („Schraube …“: Strebe und Boden in der Seite, Rückwand–Deckel im Oberschrank) | Ø4, von der Außenseite durch das gebohrte Teil und 30 mm ins anstoßende; **angenommen**, nicht aus einer Vorlage |

Alles liegt innerhalb der Platten: die Bohrung beginnt 0,2 mm unter der Oberfläche (sonst flimmert sie mit der Plattenfläche), eine Durchgangsbohrung endet 0,2 mm vor der Gegenseite. Ohne Röntgen sieht man die Löcher daher kaum; zum Prüfen **Röntgen** einschalten. Bohrungen in Türen, Klappen und Fronten liegen im Teil selbst (drehen sich mit), alle anderen in einer Gruppe „Bohrungen“ im Elternteil (Schrank, Schublade): linke und rechte Seite teilen sich eine Definition, ihre Löcher liegen aber spiegelbildlich. Tag **Bohrungen**, kein `JT_Schrank/teil`: Stückliste, Etiketten, Zuschnitt, TCN und Beschlagliste sehen sie nicht, Rendern (Blender) lässt den Tag immer weg. Eingeschaltet folgen sie jeder Änderung an einem Schrank (gerechnet wird über das ganze Modell, weil die Sockelklemmen der Blenden an den Füßen der Nachbarschränke hängen; neu gezeichnet wird nur, wo sich etwas geändert hat). Steht eine Tür oder Klappe offen, bleibt der Schrank, wie er ist.

## Röntgen
*Erweiterungen › Küchenplaner › Röntgen (Auswahl) ein/aus* oder das Icon **Röntgen**. Ist genau ein Schrank (oder ein Teil, eine Gruppe) gewählt, öffnet SketchUp ihn wie zum Bearbeiten, blendet den Rest des Modells aus und schaltet die Darstellung *Röntgen* ein: man sieht durch alle Platten auf versteckte Teile, Beschläge, Bohrungen, Dübel und Schrauben. Bei keiner oder mehreren gewählten Sachen wird das ganze Modell geröntgt (die Auswahl bleibt markiert). Zweiter Klick: Darstellung und Bearbeitungsebene wie vorher. Solange ein Schrank so geöffnet ist, rechnen Beschläge, Bohrungen und Griffe nicht nach (SketchUp meldet die Lage der Teile im geöffneten Schrank anders), beim Ausschalten wird nachgeholt; *Export* und *Rendern* schalten das Röntgen vorher aus.

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

**Beschläge und Griffe je Schrank** (*Küchenplaner › Beschläge und Griffe der gewählten Schränke…*, auch im Kontextmenü eines Schranks): für die gewählten Schränke je Beschlagart, die sie haben (Schubladenauszug, Topfband, Klappe, Hochauszug, Eckauszug, Öffnung Griffe/TIP-ON/SERVO-DRIVE …), „wie Küche (…)“ oder ein eigenes Modell; dazu die Griffe ihrer Fronten (Lochmaß, Lage, Höhe). Die eigene Wahl steht am Schrank (`JT_Schrank/beschlag_<art>`) und bleibt, wenn die Einstellung der Küche geändert wird; TCN, Beschlagliste und Beschlagmodell rechnen je Schrank. Ein eigener Schubladenauszug passt Kastenboden, Rückwand und Zargen dieses Schranks an (Ausz_*).

| Beschlagart | Modelle | Standard |
| --- | --- | --- |
| Schubladenauszug | Blum LEGRABOX free, Blum LEGRABOX pure (zusätzlich Zarge F 241), Blum MERIVOBOX (N/M/K/E, Boden LW − 51), Blum TANDEMBOX antaro (N/M/K/D, Boden LW − 75, Rückwand LW − 87) | Blum LEGRABOX free |
| Topfband (Türen) | Blum CLIP top Topfband Ø35, CLIP top 155° (0-Einsprung), CLIP top 170° Weitwinkel | Blum CLIP top |
| Topfband vor Innenauszügen (Türen, hinter denen Kastenböden liegen, z. B. Hochschrank Vorrat) | wie Topfband | Blum CLIP top 155° (0-Einsprung, Blum-Empfehlung für Innenauszüge, Katalog S. 84) |
| Falttür-Eckscharnier (Eckschrank L, Eck-Oberschrank: Scharnier zwischen den beiden Türen; die lange Tür am Korpus bekommt das *Topfband vor Innenauszügen*, Blum erlaubt nur 155°/170°) | Blum Eckschrank-Falttürscharnier CLIP top | Blum Eckschrank-Falttürscharnier (Katalog S. 116–117) |
| Topfband Kühlschrank-Schlepptür (Hochschrank Kühlschrank, Tür vor dem Gerät bei Tuertechnik Schlepptür) | Blum MODUL Kühlschrank-Schlepptürscharnier, oder ein Topfband | Blum MODUL Kühlschrank-Schlepptürscharnier (Katalog S. 168) |
| Klappe (eine Klappe) | Blum AVENTOS HK-top, AVENTOS HS top, AVENTOS HL top, Häfele Free Slim flap 1.12 | Blum AVENTOS HK-top |
| Faltklappe (zweiteilig, Oberschrank mit Klappe › Faltklappe) | Blum AVENTOS HF top | Blum AVENTOS HF top |
| Hochauszug (Handtuchauszug) | Häfele UTENSIO Matrix HU Slim Base | HU Slim Base |
| Eckauszug (Eckschrank Le Mans) | Kesseböhmer LeMans II | LeMans II |
| Öffnung (Griffe oder grifflos) | Griffe (keine Öffnungshilfe), Griffmulde gefräst, Griffkante 45°, Griffmulde durchlaufend, Blum TIP-ON + TIP-ON BLUMOTION, Blum SERVO-DRIVE + TIP-ON (Türen) | Griffe |
| Sockelfuß (Sockelversteller unter dem Korpusboden, Unter- und Hochschränke; Häfele MB 2026 Kap. 9) | Häfele AXILO 78 mit Befestigungsplatte zum Schrauben (637.76.333) oder zum Einpressen (637.76.335, Zapfen Ø10), Häfele Sockelverstellfuß Kunststoff 637.38.45x (80–150), Häfele Sockelverstellfuß Stahl 637.19.2xx (100–170) | AXILO 78 zum Schrauben (Bohrbild wie `Boden.tcn`) |

Der Katalog liegt in `src/jt_schrank_cnc/katalog/`, eine JSON-Datei je Modell (`beschlagkatalog.rb`): Beschlagart, Bauart (Rechenweg, z. B. `klappe_seite`), Einsatzbereich (Hinweis im Export, wenn ein Schrank nicht passt), Bohrbild Korpus (`seite.loecher` = [ab Vorderkante, unter der Bezugskante]) und Front (`front.unter`, `front.innen` ab Innenseite der Seite) mit Bezugskante `oberkante` (Korpusoberkante) oder `deckel` (Unterseite des Deckels), Beschlagliste (`liste.posten`, Anzahl als Zahl oder `loecher_seite`/`loecher_front`/`loecher`), Modellkörper (`koerper`) und Quelle. Ein neues Modell einer vorhandenen Bauart ist nur eine neue Datei; der Test prüft jeden Eintrag auf Vollständigkeit. Alte Küchen ohne Einstellung: ein Klappenschrank mit der früheren Option Free Slim (`Art_Klappe` 3) behält Free Slim, bis die Einstellung gespeichert wird; der Dialog schlägt das häufigste Modell vor. Topfbänder (Bauart `topfband_platte`): `topf` (Ø, Tiefe, Abstand Topfmitte–Anschlagkante, Schraublöcher des Makros inge100), `verteilung` (Randabstand Ziel/Minimum, Anzahl nach Türhöhe), `platte` (Ø, Tiefe, Abstand über/unter der Topfmitte). Schubladenauszug (Bauart `auszug_zarge`, `katalog/blum-legrabox-free.json`): `schiene` (Bohrungen Ø/Tiefe, vorn ab Vorderkante, hinten je Nennlänge, Abstand NL zur lichten Tiefe, Mindesthöhe über dem Boden, Tragkraft), `zargen` (Höhe, Holzrückwand, Lochbild Fronthalter, Seiteneinsatz; von hoch nach niedrig, höchstens 5) mit `standard_zarge`, `kasten` (Abzüge Boden Breite/Tiefe, Rückwand Breite, Seiteneinsatz), `front` (Frontbefestigung), `boden_falz` (`streifen` leer = kein Falz, z. B. MERIVOBOX/TANDEMBOX), `schiene.ueber_kasten` (Schienenbohrung über der Kastenunterkante, LEGRABOX 0, MERIVOBOX 8, TANDEMBOX 21), `tip_on_blumotion` (Sets und Synchronisierung für die grifflose Öffnung), `stabilisierung_ab`, `liste`, `koerper`. Die Schränke mit Schubladen tragen die Maße, die sie zum Bauen brauchen (Zargen, Rückwände, Nennlängen, Abzüge), als Attribute `Ausz_*` (`gemeinsam/schubkasten.rb`); ein neuer Schrank nimmt das gewählte System. Wird ein anderer Auszug gewählt, setzt das Plugin die Attribute in allen Schränken neu, zieht `Hoehe_Kastenrueckwand` mit, wenn sie auf der Standardrückwand stand, und zeichnet die Schränke neu. Schränke, die vor dieser Version angelegt wurden, haben die Attribute nicht und werden nach dem Speichern genannt (neu anlegen). Klappen mit Stufen nach Korpushöhe (`seite.stufen` / `front.stufen`, je Stufe `bis` = größte Korpushöhe in mm, z. B. Hebel-Set bei AVENTOS HL top). Faltklappe (Bauart `faltklappe_seite`, `katalog/blum-aventos-hf-top.json`): `seite` und `front` wie bei der Klappe (Hebel an der unteren Klappe, Bezug `klappe_unten_oben` = ihre Oberkante), `scharnier` (Topf Ø, Tiefe, Topfmitte ab Oberkante oben/zwischen, Abstand vom Klappenrand, Schraublöcher), `platte` (Montageplatten Ø/Tiefe, ±Abstand, Höhe der Zwischenscharnier-Platte über der Unterkante der oberen Klappe). Hochauszug (Bauart `hochauszug_seite`, `katalog/haefele-hu-slim-base.json`): `schiene` (Bohrungen ab Vorderkante und über dem Boden), `front` (Fronthalter), `bauraum` (Mindestmaße). Eckauszug (Bauart `eckauszug_saeule`, `katalog/kesseboehmer-lemans-ii.json`): `groessen` (Säulenlager X je LeMans-Größe), `korpus_min`, `lager`, `lager_schraube`, `profil`, `tiefe_min`, `strebe_min`. Welche Schränke einen Hoch- oder Eckauszug haben, steht wie bisher in `JT_Schrank/beschlag` (Handtuchauszug, Eckschrank Variante Le Mans); beide kommen mit Satz und Schrauben in die Beschlagliste.

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
* **Zargenhöhe** (Blum-Katalog 2024/2025): LEGRABOX free C 177, K 128,5, M 90,5, N 66,5 mm; LEGRABOX pure dieselben und zusätzlich F 241 (Frontauszug F gibt es nur bei pure, Katalog S. 198). Pure und free haben dieselben Korpusschienen, Holzrückwände und Böden; die Wahl steht unter Einstellungen › Beschläge – ganze Küche › Schubladenauszug. Holzrückwand F 212, C 148, K 101, M 63, N 39 (Blum-Tabelle); Fronthalter laut Blum-Katalog 2024/2025 (Schraubmontage, Alternative 4a): F 0/32/96/128/160/192, C 0/32/96/128, K und M 0/32, N 0/16 mit dem untersten Loch 5,5 mm tiefer (45,5 statt 51). Die Komponenten nehmen die höchste Zarge, die unter der Front Platz hat (oberste Schublade 30 mm unter der Frontoberkante wegen der Strebe, darunter bis an die Frontoberkante, damit die Front Zarge und Fronthalter abdeckt) (F nur bei LEGRABOX pure und nur, wenn `Hoehe_Kastenrueckwand` nicht unter 148 gesenkt ist). Der Export erkennt das Modell an der Höhe der Kastenrückwand und meldet, wenn die Zarge über die Front oder in einen festen Boden ragt.
* **Frontbefestigung** (LEGRABOX, MD-015/4 S. 4; Bohrbild wie `SK_Vorderstueck_Frontbef.tcn`): Ø3, 5 tief in der Rückseite der Front, 14 mm von der Innenseite der Seite (= 14 + FA vom Frontrand), Löcher 0/32/96/128 mm übereinander bei Zarge C, 0/32 bei Zarge M. Das unterste sitzt 36 mm über der Kastenunterkante (mind. 51 mm über der Front-Unterkante). Stehende Teile (Fronten, Rückwand) haben y = 0 an der Unterkante. Hängen mehrere Kästen an einer Front (Apothekerschrank), nennt das Attribut `front` am Kasten deren Bereich; die Hochfront bekommt das Bohrbild dann für jeden Kasten.
* **Kastenboden** (`Schubkastenboden.tcn`): Falz in der Unterseite an beiden Enden der Breite für die Zargen, Rechteck 38 mm breit über die ganze Tiefe + 20 mm und ein zweites 20 mm breit, beide 8 tief (W#1022 `rect.tmcr`). Die Ø3-Löcher aus der Vorlage fehlen, Blum sieht sie nicht vor. Die Kastenrückwand wird nur formatiert.
* **Hochauszug Häfele HU Slim Base** (schmaler Unterschrank mit Handtuchauszug, Montageanleitung 4004110659MKT „Dimensions for CNC“): Schienen nur in der Seite aus dem Attribut `Seite_Beschlag` (links = LH, rechts = RH), je Schiene 3 Bohrungen bei 56, 280 und 330 mm ab Vorderkante der Seite, 52 und 436 mm über der Oberkante des Bodens. Front: 2 Halter mit je 2 Bohrungen, 14 mm von der Innenseite der Seiten (X = 84 bei M150, 134 bei M200), 103 und 487 mm über der Oberkante des Bodens. Alle Ø3 (mitgeliefert sind Schrauben Ø4 × 16), Seite 10 tief (Annahme), Front 5 tief. Keine Lochreihen in diesem Schrank. Ist der Einbauraum kleiner als von Häfele verlangt (lichte Weite 112, lichte Höhe 565, Tiefe 485 mm), kommt ein Hinweis.
* **Kesseböhmer LeMans II** (Eckschrank Blindeck, Variante Le Mans; Montageanleitung MA 406954 0000, S. 3 und 11): Größe aus dem Attribut `LeMans` (40/45/50/60), Türseite aus `Blindseite`. Säulenlager in Boden und Strebe vorn bei X = 426/476/526/626 mm ab der Innenseite der Seite an der Tür: Ø5 für die Systemschraube Ø6,3 × 13, 69 mm ab Vorderkante, dazu 2 × Ø3 (Holzschrauben Ø4,5, vorgebohrt, Annahme) 16 mm daneben auf 37 mm. Im Boden durchgebohrt von unten (dort liegen auch die Sockelfüße), dabei alle drei mit dem Durchgangsbohrer Ø5 (durch gibt es nur Ø5/6/8/10), in der Strebe 13 bzw. 10 tief von unten. Seitenprofil 500 in der Seite an der Tür: 8 × Ø5, 13 tief, 52 mm ab Vorderkante, unterstes 28 mm über dem Boden, Raster 64. Keine Lochreihen in diesem Schrank. Hinweis, wenn Korpusbreite (764/800/910/960 mm), Tiefe (500 mm) oder Strebe vorn (60 mm) zu klein sind.
* **Blum AVENTOS HK-top** (Oberschrank mit Klappe; Blum-Katalog 2024/2025 S. 48): Kraftspeicher in beiden Seiten mit 4 Bohrungen Ø5, 12 tief, in einer waagrechten Reihe 37/69/133/165 mm ab Vorderkante der Seite, 36 mm unter der Korpusoberkante. Frontbefestigung auf der Innenseite der Klappe je Seite 4 Bohrungen Ø5, 12 tief, 12,5 mm ab der Innenseite der Seite, 62/94/126/158 mm unter der Korpusoberkante. Maße im Katalog `katalog/blum-aventos-hk-top.json`; HS top, HL top und die Faltklappe HF top stehen in eigenen Dateien.
* **Grifflos (Einstellung Öffnung, Blum TIP-ON / SERVO-DRIVE)**: Jede Tür mit Topfbändern (außer der kurzen Falttür und der Kühlschrank-Schlepptür) bekommt an der Öffnungskante einen TIP-ON. Steht dort eine Seite, kommt eine gerade Adapterplatte innen an die Seite: 2 Bohrungen Ø5, 12 tief, 20 und 37 mm ab Vorderkante (Langversion ab 1300 mm Türhöhe: 20 und 52), 100 mm unter der Oberkante der Tür (Oberschrank: über der Unterkante, abgeleitet), im Raster der Lochreihe. Bei Doppeltüren (keine Seite) sitzt eine Kreuzadapterplatte 37/32 mit der Langversion im Boden (Oberschrank) bzw. im obersten festen Boden, Mitte 50 mm von der Öffnungskante (abgeleitet). Schubladen: TIP-ON BLUMOTION-Set nach Nennlänge und Schiene, Synchronisierung nach lichter Weite (Werte unter `tip_on_blumotion` im Schubladenauszug), Korpusschienen in der Ausführung TIP-ON BLUMOTION; oder SERVO-DRIVE (Antriebseinheit und Distanzpuffer je Auszug, Trägerprofil je Schrank, Netzteil einmal je Küche). Klappen: Kraftspeicher in TIP-ON- bzw. SERVO-DRIVE-Ausführung (nur Beschlagliste). Bohrungen für SERVO-DRIVE (Unterboden, Distanzpuffer) und TIP-ON an Klappen setzt der TCN-Export noch nicht.
* **Häfele Free Slim flap 1.12 / 1.10 push** (Oberschrank mit Klappe, Einstellungen › Beschläge › Klappe = Free Slim; Montageanleitung 732.23.046, Stand 02.10.2025): Mechanismus in beiden Seiten mit 2 Bohrungen Ø5, 10 tief (Dübel), 122,5 mm ab Vorderkante der Seite, 39,5 und 135,5 mm unter der Unterseite des Deckels (Schablone S. 15/16). Frontbeschlag auf der Innenseite der Klappe je Seite 4 Bohrungen Ø3, 5 tief, im Raster 32, 12 mm ab der Innenseite der Seite (Häfele: 12 + KS − F vom Klappenrand), 36/68/100/132 mm unter der Unterseite des Deckels (Häfele: 36 + KO − F ab Klappenoberkante). Maße im Katalog `katalog/haefele-free-slim-1.12.json`.
* **Topfbänder** (alle Türen, Standard Blum CLIP top, Vorlagen `T_re_L_Topfband.tcn` / `T_rR.tcn`): auf der Innenseite jeder Tür das Makro `inge100` (Topf Ø35, 14 tief, Schraublöcher Ø8 im Abstand 45 / 9,5) mit der Topfmitte 21,5 mm von der Anschlagkante; die Tür liegt dafür wie in der Vorlage mit der Anschlagkante bei `y = DH`. Anschlag = Drehpunkt des Türhalters. **Falttür** (Eckschrank L, Eck-Oberschrank; Blum Eckschrank-Falttürscharnier, Katalog 2024/2025 S. 116–117, `katalog/blum-clip-top-falttuer.json`): die längere Tür hängt mit dem *Topfband vor Innenauszügen* (155°, wahlweise 170°) am Korpus; an ihrer Kante zur kurzen Tür der Topf des Falttürscharniers (Bohrung Ø35, 13 tief, Mitte 12,5 ab der fertigen Türkante, läuft über die Kante) und 2 Einpressdübel Ø8 (11 tief, 9,5 ab Kante, 45 Abstand), auf Höhe der Topfbänder. Die kürzere Tür trägt die Montageplatte (2 × Ø5, 11 tief, 37 ab Außenseite der langen Tür, ±16 um die Bandhöhe) und keinen Topf. Anzahl nach Türhöhe (Blum): bis 900 mm 2, bis 1600 3, bis 2000 4, bis 2400 5, darüber 6; das oberste und unterste Band möglichst 80 mm (mindestens 60 mm) vom Türrand. Die Montageplatte sitzt mit zwei Systemschrauben Ø5, 12 tief, 16 mm über und unter der Topfmitte 35 mm (Fräsmaß) hinter der Vorderkante der Seite. Wo die Seite eine Lochreihe hat, rücken die Bänder ins 32er-Raster und die Reihe bohrt die Schrauben mit; sonst (Gerätenische, Hochschrank Vorrat) kommen eigene Löcher. Hochschrank Vorrat: Höhen aus `Scharnier_1..6` am Schrank. Hochschrank Kühlschrank: die Schlepptür hängt mit dem Topfband der Art *Topfband Kühlschrank-Schlepptür* (Standard Blum MODUL Kühlschrank-Schlepptürscharnier, `katalog/blum-modul-kuehlschrank.json`) am Korpus und nimmt die Gerätetür mit; die Festtür sitzt auf der Gerätetür und bekommt keine Bänder. Modell und Maße aus dem Beschlag-Katalog (Einstellungen › Beschläge › Topfband, Standard `katalog/blum-clip-top.json`). Türen, hinter denen ein Kastenboden liegt (Innenauszüge, Hochschrank Vorrat), bekommen das Topfband der Art *Topfband vor Innenauszügen* (Standard 155°-Scharnier mit 0-Einsprung, `katalog/blum-clip-top-155.json`); Bohrbild wie 110° (Topf Ø35, Topfbohrabstand 4, Schraublöcher 45/9,5), andere Posten in der Beschlagliste.
* **Innenecke einer L-Platte** (Eckschrank L-Form: Boden und Einlegeböden; Eck-Oberschrank: Boden, Deckel und Einlegeböden): Die Ecke steht als `ecke_x`/`ecke_y` an der Definition der Platte. Geschlossene Kontur mit dem Nutfräser 2200 durch die Platte (Stärke + 1 mm) von der Seite mit den übrigen Bearbeitungen (Unterschrank: unten bei den Sockelfüßen; Eck-Oberschrank-Boden: oben bei der Rückwandnut), an den Innenkanten 2 mm zurück (Anleimer, den die Stückliste dort nicht erkennt), nach außen 8 mm über die Platte hinaus. Sockelfüße je Schenkel, also auch an der Innenecke. In der Ecke stößt die Strebe von Schenkel B mit dem Ende an die Längskante der Strebe von A: Dübel wie Strebe–Seite, in die Kante 22 tief.
* **Kanalausschnitt** (Unterschrank Kochfeld mit Abzug): durchgehende Rechtecktasche (rect.tmcr, Stärke + 1 mm) von unten im Boden; Lage und Größe aus den Attributen `Ausschnitt_Links`, `Ausschnitt_Breite`, `Ausschnitt_Hinten`, `Ausschnitt_Tiefe` am Schrank (ab der Kante bei `SeiteL` bzw. bei der Rückwand).
* **Sockelfüße** (Unter- und Hochschränke; Modell aus *Einstellungen › Beschläge › Sockelfuß*, je Schrank änderbar): Bohrbild des Modells in der Unterseite des Bodens (`bohrung.punkte` ab der Ecke des Fußes, am anderen Ende gespiegelt), Lage `lage.rand_x` vom Seitenrand und `lage.rand_y` von vorn/hinten. Standard AXILO 78 zum Schrauben wie `Boden.tcn`: je Fuß 2 × 2 Bohrungen Ø3, 3 tief, Raster 64, 20 mm vom Rand in x; seit Plugin 0.27 80 mm (statt 60) von vorn/hinten, damit der Teller Ø78 hinter der Sockelblende steht (Rücksprung 50 + 16 mm, Jürgen 2026-11-07). AXILO zum Einpressen: 4 × Ø10, 12 tief (Zapfen Ø10,4 × 11). Kunststofffuß: Ø3-Markierung der Fußmitte (50 vom Seitenrand, 100 von vorn/hinten). Stahlfuß: Ø10 durch (Stärke + 1) für die Befestigungsschraube M10. Boden länger als 900 mm (`verteilung.mitte_ab`): zusätzlich ein Paar in der Mitte (6 Füße). Bei einem schmalen Boden (unter 2 × (rand_y + Bohrbild), bei AXILO 288 mm, z. B. Handtuchschrank, Abschlussregal 262 tief) nur ein Fuß je Ende, mittig. Schräge/Bogen (Abschlussregal): der ganze Fuß rückt nach innen, bis alle Bohrungen 20 mm vom Rand liegen. Der Boden liegt dafür mit der Unterseite nach oben. Beschlagliste: je Fuß das Modell in der Höhe, deren Einstellbereich die Sockelhöhe der Küche enthält (bei zweien die mittigere; passt keine, die nächste mit Hinweis, und die Einstellungen warnen beim Speichern), dazu Befestigung je Fuß und Sockelblendenclips je vorderem Fuß. Selbst festgelegt (nicht Katalog): Mittelfüße ab 900, Lage der Kunststoff-/Stahlfüße, Schraubenlängen. Sockelfüße werden nicht gezeichnet (unter dem Korpus, außerhalb der Komponentengrenzen).
* **Sockelklemmen** (Sockelblende aus *Blenden & Wangen*): in der Rückseite der Blende hinter jedem Sockelfuß, der höchstens 200 mm hinter ihr steht (vordere Reihe, aller Schränke der Zeile), 2 Vorbohrungen Ø3 × 8 für den Halter des Sockelblendenclips, nebeneinander mittig über der Fußmitte, auf halber Blendenhöhe; Abstand je Modell (`klemme.abstand`: AXILO 28, Kunststoff/Stahl 32 – angenommen, Halter nachmessen). Klemmen näher als 10 mm am Blendenende entfallen. Liegt die Rückseite auf Fläche 2, kommen sie ins Programm `_Rueckseite.tcn`.
* **Rückwandnut** (steckt eine Rückwand in Seiten und Boden, im Oberschrank; im Spülenschrank nur in den Seiten, die Rückwand steht dort auf dem Boden): Bahn mit dem Nutfräser 2200 (Ø 8,03 mm, wie im Treppenbau) als `W#89`/`W#2201`, Tiefe = Nuttiefe (9 mm), Breite = Rückwandstärke (breiter als der Fräser: mehrere Bahnen). Läuft die Nut aus der Platte, fräst sie 5 mm darüber hinaus.
* **Schräg- und Bogenkante** (Abschlussregal, Böden mit Wörterbuch `JT_Kontur` an der Definition): zugeschnitten wird das Rechteck, die Kante fräst der Konturfräser 1004 (Ø 20) von Fläche 1 ganz durch (Stärke + 1 mm), um den Fräserradius in den Abfall und um den Anleimer in die Platte versetzt. Ein- und Auslauf tangential außerhalb der Platte, Bögen als kurze Geraden (höchstens 5° und 10 mm je Stück), kein `W#2125` (TPA meldete beim runden Deckel „Radius ungültig“). Anleimer auf nicht achsparallelen Flächen zählt nicht ins Fräsmaß des Rechtecks, sondern steht in der Stückliste als *Kante Kontur* mit Länge. Sockelfüße, die über die Kante ragen würden, rücken nach innen.
* **Sockelausklinkung der Wange** (Blenden & Wangen, Wange mit *Sockelausklinkung ja*): `JT_Kontur` mit `ebene = yz` (Umriss in der Ebene der Wange). Gleicher Ablauf wie die Schrägkante mit 1004: zwei Geraden (Ausklinkung hinten, oben), in der Innenecke im Schnittpunkt der versetzten Bahnen verbunden, Start unter der Platte, Ende vor der Platte, Zustellung höchstens 20 mm. In der Innenecke bleibt Radius 10 mm. Kein Anleimer an der Ausklinkung.
* **Rückwand-Ausschnitt** (Spülenschrank): Lage und Größe stehen als Attribute `Ausschnitt_X/_Z/_B/_H` an der Rückwand. Geschlossene Kontur mit dem Nutfräser 2200 (`W#89` + 4 × `W#2201`), um den Fräserradius nach innen versetzt (Ecken bleiben mit Radius 4 mm), Tiefe = Rückwandstärke + 1 mm.
* **Zustellung**: Keine Fräsung geht in einem Zug tiefer als 20 mm (Materialschonung). Tiefere Bahnen (`W#89` + Bahnzeilen) und Taschen (`W#1022`) wiederholt der Export in gleich großen Schritten von höchstens 20 mm, z. B. 39 mm → 19,5 + 39. Jeder Schritt ist eine eigene Bearbeitung. Das gilt zentral für alle TCN (`Tcn.zustellen`), auch für die Arbeitsplatte.
* **Rohrausschnitt** (Oberschrank Dunstabzug): Attribute `Ausschnitt_X/_Y/_B/_T` an Haubenboden, Deckel und Einlegeboden (liegende Platte, Lage ab vorne links). Gleiche Kontur wie der Rückwand-Ausschnitt, von oben (Fläche 1), Tiefe = Plattenstärke + 1 mm. Bei Umluft ist die Breite 0, dann entfällt er.
* **Deckel–Rückwand** (nur Oberschrank): 3 Schrauben 50 mm von den Seiten und in der Mitte, Ø5 durch die Rückwand (1 mm tiefer als ihre Stärke, Durchgangsbohrer). Die Deckelkante wird nicht vorgebohrt, weil es waagrecht nur Ø8 gibt (Werkzeugliste).
* Die Bearbeitungen einer Seite sind nach Inhalt sortiert, so ergeben gespiegelte Teile mit gleichem Bohrbild dieselbe TCN.
* Fläche 1 (oben auf der Maschine) ist die große Fläche mit den meisten Bohrungen, bei Seiten also die Innenseite. Die linke Seite ist die gespiegelte rechte.
* **Rückseite** (z. B. Mittelwand mit Böden auf beiden Seiten im Wandregal oder freien Schrank, Boden mit Sockelfüßen und Mittelwand): Bohrungen auf der Unterseite kann die Maschine nicht. Hat ein Teil welche, gibt es ein zweites Programm `<Nr>_<Tag>_Rueckseite.tcn` fürs gewendete Werkstück, nur mit diesen Bohrungen und ohne Formatieren. Es hat dieselbe Nummer und steht in derselben Stücklistenzeile wie das erste.
* **Wandregal:** Mittelwände (Rolle Seite) bekommen die Fachböden wie eine Seite und sind selbst mit Boden und Deckel gedübelt wie ein Zwischenboden mit der Seite (Dübel in die Kante der Mittelwand, Reihe in Boden bzw. Deckel). Keine Lochreihen, die Fachböden sind fest.
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
* `src/jt_schrank_cnc/frontfarbe.rb` – Frontfarbe ändern
* `src/jt_schrank_cnc/griffkatalog.rb`, `griffdialog.rb`, `griffmodell.rb`, `griffe/` – Griffkatalog (Daten, Fenster, Griffe im Modell)
* `src/jt_schrank_cnc/griffmulde.rb` – Griffmulde gefräst (Regel, TCN-Kontur, Mulde in der Front im Modell)
* `src/jt_schrank_cnc/grifflos.rb` – Griffkante 45° und Griffmulde durchlaufend (Komponenten anpassen, Fase im TCN und im Modell)
* `src/jt_schrank_cnc/geometrie.rb` – Teile vermessen (Weltquader, Anleimer, Lage auf der Maschine)
* `src/jt_schrank_cnc/regeln.rb` – Stöße finden, Bearbeitungen ableiten
* `src/jt_schrank_cnc/freier_schrank.rb` – freier Schrank: kennzeichnen, Teil zuweisen, prüfen
* `src/jt_schrank_cnc/freier_korpus.rb` – freier Schrank: Korpus anlegen, Mittelwand, Böden, Türen, Schubladen, Blenden
* `src/jt_schrank_cnc/freier_bibliothek.rb` – Bibliothek eigener Schränke (speichern, Versionen, einfügen), Schrank lösen
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
* `test/test_griffkatalog.rb` – Griffkatalog: Daten, Vorschlag, automatische Griffe, Schrank-Dialog, TCN, Beschlagliste, Modell und Rendern
* `test/test_grifflos.rb` – Griffkante und durchlaufende Mulde: Attribute in allen Oberschränken, je Schrank, ältere Schränke, Fase im TCN und Modell (unten im Ober-, oben im Unterschrank), Hochschrank behält Griffe
* `test/test_griffmulde.rb` – Griffmulde gefräst: Lage je Front, Hochschrank ausgenommen, TCN-Kontur, Maße änderbar, je Schrank, Falttür, Flächen im Modell
* `test/test_frontfarbe.rb` – erzeugt Hochschrank, Oberschränke und Unterschrank mit den Skripten aus `Komponenten/` in der Mock-API und prüft Frontfarbe, Anleimer, Bereiche, Auswahl, Eindeutigmachen, Griffe und den Dialog
* `test/test_stueckliste.rb` – Stückliste an Hochschrank und Unterschrank: Roh-/Fräs-/Fertigmaß, Kanten, Übermaß aus den Einstellungen, CSV, Druckseite, Dialoge
* `test/test_zuschnitt.rb` – Zuschnittplan an Hoch-, Unter- und Oberschrank: alles platziert, keine Überlappung, Schnittbreite und Randabfall eingehalten, alle Kombinationen aus erstem Schnitt, Schnitttyp und Stufen (Schnitte wirklich durchgehend, Stufen eingehalten), Faserrichtung, Plattenreste, Reste behalten, gleiche Platten, PDF, Dialog
* `test/test_etiketten.rb` – Etiketten-PDF: Bogen-Lage, Startposition, Endlos, Roh-/Fräs-/Fertigmaß, QR-Code, Format-Dialog
* `test/test_pdf.rb` – PDF-Schreiber: gültiger Aufbau (xref), Umlaute, Textbreite, QR-Code
* `test/test_freier_schrank.rb` – freier Schrank: Oberschrank und Schubladenschrank ohne Kennzeichen nachgebaut ergeben dieselben Bearbeitungen; frei modellierter Korpus mit Mittelwand (Lochreihen wählbar, beidseitig), Anleimer je Richtung, Tags, Prüf-Meldungen
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
