> Quelle: [Plan: Geräte-Generator für Kundenrenderings](https://claude.ai/artifact/JF7SYsCoZHFVMbYFrZ8XzP) (Plan-Dokument aus dem Projekt-Thread, Stand 28.10.2026)  
> Status: **noch offen**: wartet auf Jürgens Antworten; Schnittstelle `JT_Nische` ist in den Spezialschränken schon umgesetzt

# Plan: Geräte-Generator für Kundenrenderings

Oct 25, 2026 · @Jürgen Späder · Status: Plan, wartet auf Jürgens Freigabe

## Ziel

Geräte (Geschirrspüler, Kochfeld, Backofen usw.) werden als eigene, selbst erzeugte Komponenten in die Schränke gesetzt. Sie dienen zwei Zwecken: In der Planung sieht man, welches Gerät wohin kommt, und für den Kunden entsteht ein ordentliches Rendering. Herstellermodelle werden nicht verwendet (Entscheidung Jürgen, 25.10.2026).

## Reihenfolge (wie die Spezialschränke vorliegen)

1. **Geschirrspüler** für den Spülmaschinen-Unterschrank: vollintegriert 60 und 45 cm, Nischenhöhe 815–875 mm. Die Möbelfront kommt vom Schrank, das Gerät zeigt Innenleben, Bedienleiste oben und Sockel mit Lichtpunkt.
2. **Kochfeld mit Abzug** für den Herdschrank: Glaskeramik-Kochfeld 60/80/90 cm mit Abzug in der Mitte, Lüftermodul im Installationsraum, Kanal durch den Bodenausschnitt, Sockelfilter. Richtet sich nach den Schrank-Attributen Hoehe\_Blende, Installationstiefe, Kanal\_Breite, Kanal\_Lage.
3. **Spüle und Armatur** für den Spülenschrank: Einbauspüle (Edelstahl oder Granit, 1 oder 1,5 Becken) mit Armatur. Kein Gerät im engeren Sinn, aber für das Rendering wichtig.
4. **Einbaugeräte für den Hochschrank mit zwei Großgeräten:** Backofen 60 (Nische 590), Kompaktgerät 45 (Backofen/Dampfgarer/Mikrowelle-Kombi, Nische 450), Mikrowelle 38 (Nische 380), Wärmeschublade 14 (Nische 140). Lichte Breite 562 mm beim 600er Schrank.

Später, sobald die Schränke geplant sind: Einbaukühlschrank/Gefrierschrank (Nischen 880/1020/1220/1580/1780), Unterbau-Kühlschrank 820, Dunstabzugshaube für den Oberschrank.

## Schnittstelle Schrank ↔ Gerät

Der Schrank liefert nur die Nische, das Gerät richtet sich danach. Jede Nische hat am Schrank ein Wörterbuch **JT\_Nische** (Vorschlag aus dem Hochschrank-Thread, gilt für alle Spezialschränke):

- `nische`: N1, N2 … (bei Kochfeld KF, bei Spüle SP)
- `geraet`: z. B. Geschirrspueler60, KochfeldAbzug80, Spuele, Backofen60, Kompakt45, Mikrowelle38, Waermeschublade14, frei
- `breite`, `hoehe`, `tiefe`: lichte Maße in mm
- Einfügepunkt: vorne links auf der Oberkante des Einbaubodens, an der Korpusvorderkante (x nach rechts, y nach hinten, z nach oben). Bei Kochfeld und Spüle ist es die Korpusoberkante vorne links, die Arbeitsplattenstärke kommt als Attribut dazu.

Das Gerät setzt seine Front selbst richtig vor den Korpus (bei Backöfen steht die Blende vor der Korpuskante). Ändert man die Nische, passt man das Gerät per Komponentenoptionen an oder setzt es neu ein.

## Aufbau einer Geräte-Komponente

- Ein Generator (Ruby, wie die Schränke) unter `Komponenten/geraete/`, ein Menüpunkt je Gerätetyp.
- Jede Komponente ist eine DC mit Gerätetyp und Hauptmaßen als Optionen, plus Kurzhilfe wie bei den Schränken.
- **Zwei Darstellungen:** Tag `Geraete_Plan` zeigt einen farbigen, halbtransparenten Block mit Beschriftung (Typ und Nischenmaß). Tag `Geraete_Render` zeigt das Modell mit Schwarzglas, Edelstahl, Griffen und Bedienblende. Zwei Szenen „Planung“ und „Kunde“ schalten um.
- Einfache Geometrie (Quader, Fasen, wenige Kreise), damit die Datei leicht bleibt.

## OpenCutList und TCN-Export

- Geräte haben kein Plattenmaterial, kein JT\_Schrank-Wörterbuch und keine Teil-Tags. Der TCN-Export überspringt sie daher.
- Die Gerätematerialien werden in OCL als Typ „Kein Material“/Zubehör markiert, damit sie nicht in der Plattenliste landen. Das prüfe ich im Mock-Test. Notfalls blendet man die Geräte-Tags vor dem OCL-Lauf aus.

## Tests

Mock-Tests wie bei den anderen Komponenten: Maße je Gerätetyp, Tags, keine JT\_Schrank-Daten, OCL-Materialtypen, Einpassen in eine JT\_Nische.

## Offene Fragen an Jürgen

- Reicht die Reihenfolge oben, und soll der Kühlschrank vorgezogen werden?
- Sollen die Geräte automatisch beim Erzeugen des Schranks in die Nische gesetzt werden oder immer von Hand?
- Spüle und Armatur gehören mit in den Geräte-Generator, einverstanden?
