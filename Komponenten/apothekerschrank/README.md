# Apothekerschrank (Dynamic Component)

Hochschrank mit Vollauszug: Eine hohe Front fährt komplett heraus und nimmt 2–6 Innenkästen mit (Prinzip Blum SPACE TOWER, Kästen Blum LEGRABOX). Wahlweise zwei Fronten, die unten und oben getrennt ausziehen.

## Einmalig die .skp erzeugen
1. `apothekerschrank.rb` z. B. nach `C:/Users/<Name>/Downloads/` speichern.
2. SketchUp öffnen → *Erweiterungen → Developer → Ruby-Konsole* (bzw. *Fenster → Ruby-Konsole*).
3. Eingeben: `load 'C:/Users/<Name>/Downloads/apothekerschrank.rb'`
4. Der Apothekerschrank erscheint im Modell und wird als **`Apothekerschrank.skp`** neben das Skript gespeichert. Danach wird das Skript nicht mehr gebraucht – nichts wird installiert.

## Komponentenoptionen
| Option | Werte | Standard |
|---|---|---|
| Breite, Höhe, Tiefe | frei | 400 / 2100 / 800 mm |
| Fronten | *Eine Hochfront* oder *Zwei (unten/oben)* | eine |
| Zwei Fronten: Höhe untere Front | bis Oberkante Mittelboden | 700 mm |
| Kästen an der unteren bzw. einzigen Front | 2–6 | 5 |
| Zwei Fronten: Kästen an der oberen Front | 2–6 | 3 |
| Fester Mittelboden | Ja/Nein (bei zwei Fronten immer) | Ja |
| Höhe Kastenrückwand | 148 mm = LEGRABOX C, kleiner für flachere Zargen | 148 mm |
| Stärke Kastenboden, Höhenoffset Schiene | wie Hochschrank | 16 mm / 0 |

Mit *Interagieren* fährt eine Front mit allen ihren Kästen heraus (Front und Kästen stecken zusammen in der Komponente `AuszugA` bzw. `AuszugB`).

## Aufbau
* Korpus wie der Hochschrank: Seiten über die volle Höhe, Boden, Deckel, Rückwand 8 mm, Korpus 19 mm, Fugen 2 mm. Die Front deckt den Korpus ganz ab (0 bis Höhe), bei zwei Fronten mit 2 mm Fuge an der Teilung.
* **Mittelboden** (fest, gegen das Ausbeulen der hohen Seiten): bei einer Front zwischen zwei Kästen in der Mitte (unter dem Kasten Nr. Anzahl/2, von oben gezählt), mit *Kasten_Abstand_unten* (30 mm) unter dem Kasten darüber; bei zwei Fronten an der Teilung.
* **Kästen Blum LEGRABOX free** (MD-015/4): aus Holz nur **Boden** (lichte Weite − 35 mm × NL − 10 mm, 16 mm) und **Holzrückwand** (lichte Weite − 38 mm × 148 mm, 16 mm, hinten auf dem Boden). NL wie beim Hochschrank aus der Tiefe (größte mit NL + 3 mm ≤ Tiefe, max. 650).
* **Verteilung:** Je Front liegen die Kästen gleichmäßig im 32-mm-Lochraster der Seite (Schienenbohrung = Unterkante Kasten + Höhenoffset auf 35 + n · 32 mm). Der Abstand von Kasten zu Kasten ist ein Vielfaches von 32 mm, der unterste Kasten sitzt mindestens 30 mm über dem festen Boden darunter, die Gruppe wird im Raum mittig ausgerichtet.
* Passt die volle Rückwandhöhe nicht, werden alle Kastenrückwände der Front niedriger (mindestens 30 mm Luft zum nächsten Teil; unter dem Mittelboden zusätzlich Platz für Boden + 30 mm). Für Zarge C braucht jeder Kasten etwa 22 cm.
* Keine Lochreihen für Einlegeböden – das ganze Innere sind Auszüge.

**Bitte vor der Werkstatt prüfen:** Kopplung der Hochfront an mehrere LEGRABOX-Kästen und Frontstabilisierung sind nicht gegen Blum-Unterlagen geprüft (nur MD-015/4 lag vor) – mit dem Blum-Konfigurator gegenchecken.

## OpenCutList (OCL)
Geplant wird in SketchUp immer das **Endmaß**. Anleimer werden nur für OCL zugewiesen (Material „Anleimer Melamin weiss“, OCL-Typ *Kante*, 2 mm, „Kantenstärke abziehen“ an).

| Teil | Kanten mit Anleimer |
|---|---|
| Seiten | vorne, oben |
| Boden, Deckel, Mittelboden | vorne |
| Rückwand | links, rechts, oben |
| Fronten | alle vier |
| Kastenrückwand | oben |
| Kastenboden | keine |

Ausgeblendete Kästen, Front B und Mittelboden erscheinen nicht in der OCL-Liste.

## Tags
Jedes Teil hat einen eigenen Tag `<Kürzel>_<Bereich>_<Teil>`, z. B. `AP1_SeiteL`, `AP1_Mittelboden`, `AP1_A_Front`, `AP1_A3_KastenBoden`, `AP1_B1_KastenRueckwand` (A = untere bzw. einzige Front, B = obere Front, Kasten 1 = oben). Korpusteile haben keinen Bereich.

Das Kürzel ist `AP1`, oder `AP2` usw., wenn es im Modell schon vergeben ist. Ein eigenes Kürzel: `Apothekerschrank.erstellen({ 'Kuerzel' => 'AP2' }, ziel)` in der Ruby-Konsole.

Am Teil steht das Wörterbuch `JT_Schrank` mit `schrank`, `typ` (Apothekerschrank), `kategorie` (Hochschrank – damit greifen Frontfarbe und Sockelfüße), `bereich`, `teil` und `rolle`. Die Kastenteile haben zusätzlich `front` (A oder B): Daran findet das TCN-Plugin die Front, an der der Kasten befestigt wird, und bohrt die Frontbefestigung für jeden Kasten in die Hochfront.

## Hilfe in SketchUp
Eine Kurzfassung dieser Doku steht oben im Fenster *Komponentenoptionen* (Summary und Description) und als Beschreibung in *Entitätsinformationen*, mit Link auf diese Seite. Der Text steht als `HILFE` in `apothekerschrank.rb`.

## Tests
`ruby test/test_apothekerschrank.rb` – prüft ohne SketchUp (Mock-API und DC-Formel-Auswerter) Geometrie, Formeln, Lochraster, Kollisionen, OCL-Material, Anleimer, Tags und die Kurzhilfe, auch nach dem Umkonfigurieren. Der TCN-Export des Apothekerschranks wird in `sketchup-tcn-export-plugin/test/test_export.rb` geprüft.
