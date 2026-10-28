> Quelle: [Plan: Herdschrank mit Kochfeldabzug](https://claude.ai/artifact/Jbi4YBocaY5nCERsPjeXGQ) (Plan-Dokument aus dem Projekt-Thread, Stand 28.10.2026)  
> Status: umgesetzt in PR #10, `Komponenten/unterschrank_kochfeld/`

# Plan: Herdschrank mit Kochfeldabzug

Oct 25, 2026 · @Jürgen Späder

## Kurzfassung und Fragen

Ein Unterschrank mit Schubladen für ein **Kochfeld mit integriertem Abzug** (z. B. BORA, Siemens/Bosch/Neff, Miele, AEG). Unter dem Kochfeld sitzt das Lüftermodul, dahinter läuft der Kanal nach unten in den Sockel (Umluftfilter im Sockel oder Abluft nach außen). Der Schrank bekommt deshalb oben eine **feste Blende** statt einer Schublade, darunter **1–3 verkürzte Schubladen**, hinten einen **freien Installationsraum** für den Kanal und einen **Ausschnitt im Boden** zum Sockel.

Er wird eine eigene Komponente `Komponenten/unterschrank_kochfeld/` (Kürzel **USK**), technisch gleich aufgebaut wie der Unterschrank mit Schubladen (LEGRABOX, OCL, Tags, TCN).

**Fragen an dich:**

1. Welches Gerät verbaust du meistens (Hersteller/Modell)? Dann nehme ich dessen Einbaumaße als Standard, sonst die Richtwerte unten. - richtwerte
2. Umluft (Filter im Sockel, Sockelblende mit Lüftungsgitter), Abluft oder beides als Option? beides
3. Unten nur Schubladen, oder auch eine Variante mit Backofen unter dem Kochfeld? Das geht nur mit bestimmten Geräten; ich würde es zunächst weglassen. → weglassen, das wird ein anderer schrank, also nur schubladen (2 grosse als standard 1:1 geteilt)
4. Passt der Aufbau? Nach deiner Freigabe baue ich ihn.&#32;

## Was ein Kochfeldabzug im Schrank braucht

Richtwerte aus allgemeinen Herstellerangaben, nicht für ein bestimmtes Modell geprüft:

- **Einbauhöhe unter der Arbeitsplatte:** Kochfeld plus Lüftermodul brauchen etwa 200 mm. Die oberste Schublade entfällt, an ihrer Stelle sitzt eine Blende.
- **Kanal:** Flachkanal (typisch etwa 222 × 89 mm) läuft hinter den Schubkästen senkrecht nach unten. Dazu bleibt hinten ein Installationsraum von etwa 120–150 mm frei, die Schubkästen werden kürzer.
- **Sockel:** Bei Umluft liegt die Filterbox im Sockel (Sockelhöhe je nach Gerät ab etwa 100–150 mm), die Luft strömt durch ein Lüftungsgitter in der Sockelblende zurück. Bei Abluft geht der Kanal durch den Sockel zur Außenwand.
- **Breite:** Kochfelder mit Abzug gibt es meist in 60, 80 und 90 cm, Standard wird 800 mm.
- **Streben:** Der Kochfeldausschnitt beginnt etwa 50 mm hinter der Vorderkante der Arbeitsplatte und kann eine flache 100-mm-Strebe vorn anschneiden. Hinten sitzen Lüftermodul und Kanal genau dort, wo sonst die hintere Strebe liegt.
- **Wartung:** Filter und Motor müssen erreichbar bleiben. Die LEGRABOX-Kästen lassen sich aushängen, die Sockelblende muss abnehmbar sein.

## Aufbau des Schranks

**Parameter in den Komponentenoptionen** (alles danach änderbar):

| Parameter | Standard | Bedeutung |
| --- | --- | --- |
| Breite / Höhe / Tiefe | 800 / 700 / 800 mm | wie Unterschrank, Breite passend zum Kochfeld |
| Höhe Blende | 200 mm | mindestens Einbauhöhe des Geräts unter der Arbeitsplatte |
| Anzahl Schubladen | 2 (1–3) | unter der Blende |
| Anteil Schublade 1–3 | 1 / 1 | Aufteilung wie beim Unterschrank mit Schubladen |
| Installationstiefe | 150 mm | hinten frei für den Kanal |
| Kanalausschnitt Boden | 300 mm breit, mittig | Lage links / mittig / rechts wählbar |
| Strebe vorn | hochkant | wahlweise flach wie beim Unterschrank |

**Teile:**

- **SeiteL / SeiteR:** genau wie bei allen Schränken (Seiten sind immer gleich).
- **Boden:** wie beim Unterschrank, zusätzlich ein rechteckiger Ausschnitt hinten (Installationstiefe × Kanalbreite), durch den der Kanal in den Sockel geht.
- **StrebeVorn:** hochkant (100 mm hoch, 19 mm stark) direkt hinter der Blende, damit der Kochfeldausschnitt frei bleibt. Die Blende wird von innen durch diese Strebe angeschraubt.
- **StrebeHinten:** entfällt, dort sitzen Lüftermodul und Kanal. Die Steifigkeit kommt von Rückwand und Arbeitsplatte.
- **Rückwand:** bleibt hinten wie beim Unterschrank, ohne Versatz und ohne Nut. Der Kanal läuft innen davor.
- **Blende:** feste Front oben, gleiche Fugen und gleiches Material wie die Fronten. Rolle „Front“, damit „Frontfarbe ändern“ sie mitnimmt.
- **Schubladen S1–S3:** Front plus LEGRABOX-Kasten wie beim Unterschrank mit Schubladen, mit Lochraster und Höhenoffset Schiene. Die Nennlänge ergibt sich aus Tiefe minus Installationstiefe (bei 800 / 150 mm also NL 600). Mit „Interagieren“ fahren sie heraus.

Arbeitsplatte, Kochfeldausschnitt in der Platte und Sockelblende gehören nicht zum Schrank, wie bei den anderen Komponenten.

## OCL, Tags und TCN-Export

- **Material und Anleimer** wie beim Unterschrank mit Schubladen: „Melamin weiss“, Endmaß in SketchUp, Abzug nur in OCL. Neu: Blende rundum, hochkante Strebe vorn ohne Anleimer (verdeckt), Kanten am Bodenausschnitt ohne Anleimer.
- **Tags:** `USK1_SeiteL`, `USK1_Boden`, `USK1_StrebeVorn`, `USK1_Blende`, `USK1_S1_Front`, `USK1_S1_KastenBoden` usw. Im Dictionary `JT_Schrank` steht `typ` = Unterschrank\_Kochfeld und `kategorie` = Unterschrank, so greifen „nur Unterschränke“ bei der Frontfarbe und die Sockelfüße im Export.
- **ROLLEN-Tabelle:** Sie bekommt den neuen Eintrag `Blende` → `Front`. Weil die Tabelle in allen Komponenten gleich sein muss, ändere ich sie in allen Generatoren mit (eine Zeile je Datei).
- **TCN-Export, drei Anpassungen im Plugin:**
  1. *Bodenausschnitt:* Der Export kennt nur Quader. Der Generator schreibt den Ausschnitt deshalb als Attribut `ausschnitt` an den Boden, das Plugin macht daraus eine durchgehende Tasche (rect.tmcr, W#1022).
  2. *Schienen-Nennlänge:* Das Plugin rechnet die NL heute aus dem Abstand bis zur Rückwand und würde hier NL 650 statt 600 bohren. Es soll künftig das Attribut `NL` am Schrank nehmen, wenn es da ist.
  3. *Strebe hochkant:* Die Dübelregel arbeitet schon jetzt nach Lage der Teile. Ich prüfe im Test, dass auch die stehende Strebe Dübel und Schraube bekommt.
- **Lochreihen:** keine, weil der Schrank nur Schubladen hat.

## Umsetzung nach Freigabe

- Neuer Branch von `main` und ein Pull Request, du gibst frei.
- `Komponenten/unterschrank_kochfeld/`: Erweiterung `.rbz` mit Dialog wie beim Unterschrank mit Schubladen, `README.md` als Kurzdoku, Kurzhilfe in der Komponente (Summary/Description mit Link).
- Tests ohne SketchUp (Mock und DC-Formel-Auswerter): Geometrie, Formeln, Nennlänge, Ausschnitt, OCL-Material, Anleimer, Tags, Kurzhilfe; im Plugin TCN für Bodenausschnitt, Schienen und hochkante Strebe. Alles läuft über `./run_tests.sh` und GitHub Actions. In echtem SketchUp kann ich nicht testen, das musst du einmal prüfen.
- **Geräte-Darstellung:** Der Schrank legt seinen Einbauraum als Attribute ab (Blendenhöhe, Installationstiefe, Lage des Kanals). Daran kann der Platzhalter „Kochfeld mit Abzug“ (Kochfeld, Lüfter, Kanal, Sockelfilter) aus dem Thread „Geräte in Schränken darstellen“ genau einrasten. Geräte bekommen kein Plattenmaterial und kein `JT_Schrank`, OCL und TCN bleiben unberührt. Das stimme ich mit dem Thread ab.

Abgestimmt mit der Geräte-Darstellung: Der Schrank bekommt zusätzlich wie alle Spezialschränke das Wörterbuch `JT_Nische` mit `nische` = KF, `geraet` = KochfeldAbzug60 / 80 / 90 (nach Breite), lichter Breite, Höhe und Tiefe in mm und dem Einfügepunkt vorne links auf der Korpusoberkante. Die Arbeitsplattenstärke kommt als eigenes Attribut dazu (Standard 40 mm, nur für die Gerätelage, nicht für OCL).
