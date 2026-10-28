> Quelle: [Plan: Hochschrank als Apothekerschrank](https://claude.ai/artifact/MEqP4Nak6nu5LU3Rc97pw5) (Plan-Dokument aus dem Projekt-Thread, Stand 28.10.2026)  
> Status: umgesetzt in PR #13, `Komponenten/apothekerschrank/`

# Plan: Hochschrank als Apothekerschrank

Oct 25, 2026 · @Jürgen Späder

Status: **Plan zur Freigabe**. Gebaut wird erst nach deinem OK (Branch von main, PR, du mergst).

## Ziel

Ein schmaler Hochschrank, dessen hohe Front als Vollauszug komplett herausfährt und dabei mehrere Innenkästen mitnimmt (klassischer Apothekerschrank). Er entsteht wie der Hochschrank als Skript, das einmal in der Ruby-Konsole geladen wird und `Apothekerschrank.skp` als Dynamic Component speichert.

## Beschlag (Entscheidung)

**Empfehlung: Blum LEGRABOX, mehrere Kästen an einer Hochfront** (Prinzip Blum SPACE TOWER). Vorteil: Es ist dasselbe System wie bei allen Schubladen. Schienenbohrungen, Bodenfalz, Frontbefestigung und NL-Tabelle aus dem TCN-Plugin funktionieren unverändert. In SketchUp entstehen aus Holz nur Kastenboden und Holzrückwand je Kasten, die Zargen sind Metall.

Alternative: klassischer Apothekerauszug (z. B. Kesseböhmer Dispensa oder Hettich) mit Gestell und Körben, Schiene unten am Boden und Führung oben. Geht auch für 150–300 mm Breite, braucht aber ein eigenes Bohrbild, das es im Plugin noch nicht gibt. Nicht Blum.

Annahme: Die Kopplung einer Hochfront an mehrere LEGRABOX-Kästen und die nötige Frontstabilisierung prüfe ich nicht gegen Blum-Unterlagen (habe nur MD-015/4). Bitte vor der Werkstatt mit dem Blum-Konfigurator gegenchecken.

## Komponentenoptionen

| Option | Werte | Standard |
| --- | --- | --- |
| Breite, Höhe, Tiefe | frei | 400 / 2100 / 800 mm (Höhe, Tiefe wie Hochschrank) |
| Anzahl Fronten | 1 (eine Hochfront) oder 2 (unten/oben getrennt ausziehbar) | 1 |
| Teilung (nur bei 2 Fronten) | Oberkante untere Front | 700 mm |
| Anzahl Kästen je Front | 2–6 | 5 bei einer Front |
| Verteilung | gleichmäßig, Kästen sitzen im 32er-Lochraster | gleichmäßig |
| Höhe Kastenrückwand | z. B. 148 mm (LEGRABOX C) oder niedriger | 148 mm |
| Fester Mittelboden | Ja/Nein, liegt in einer Lücke zwischen zwei Kästen (bei 2 Fronten an der Teilung) | Ja |
| Stärke Kastenboden, Höhenoffset Schiene | wie Hochschrank | 16 mm / 0 |

Mit *Interagieren* fährt die Front mit allen ihren Kästen heraus (Front und Kästen stecken zusammen in einer Auszug-Komponente).

## Aufbau

- Korpus wie beim Hochschrank: Seiten über die volle Höhe, Boden, Deckel, Rückwand 8 mm, Korpus 19 mm, Fugen 2 mm, Sockelfüße.
- Optional ein fester Mittelboden gegen das Ausbeulen der 2,1 m hohen Seiten.
- Kästen: LEGRABOX-Boden LW−35 × NL−10 (16 mm), Holzrückwand LW−38 × Höhe, NL aus der Tiefe (größte mit NL+3 ≤ lichte Tiefe). Jeder Kasten sitzt mit Schienenbohrung im Lochraster der Seite.
- Front 19 mm, 2 mm Fuge rundum; bei 2 Fronten 2 mm Fuge zwischen ihnen.
- Keine Lochreihen für Einlegeböden (das ganze Innere sind Auszüge).

## OCL, Tags, JT\_Schrank

- Alle Platten „Melamin weiss“, Anleimer nur in OCL wie beim Hochschrank (Seiten vorne/oben, Böden vorne, Rückwand links/rechts/oben, Fronten rundum, Kastenrückwand oben).
- Kürzel **AP1** (AP2 … falls vergeben). Tags z. B. `AP1_SeiteL`, `AP1_Mittelboden`, `AP1_A_Front`, `AP1_A3_KastenBoden`; bei 2 Fronten `AP1_B_Front` usw. (A = untere bzw. einzige Front, B = obere, Kasten 1 = oben).
- `JT_Schrank`: `typ` = Apothekerschrank, `kategorie` = Hochschrank (Frontfarbe und Sockelfüße greifen dadurch automatisch). Neu am Kasten: `front` = Bereich der zugehörigen Front.
- Kurzhilfe als DC-Summary/Description, README als Kurzdoku.

## Anpassung TCN-Plugin

Bisher sucht die Frontbefestigung die Front mit gleichem Bereich wie der Kasten. Bei einer Hochfront gehören mehrere Kästen (A1…A5) zu einer Front (A). Kleine Änderung: Kasten nutzt `front`, sonst wie bisher den Bereich. Die Hochfront bekommt dann je Kasten ihre 2 × 4 Bohrungen. Alles andere (Schienen je Kasten, Bodenfalz, Dübel, Sockel) läuft unverändert.

## Umsetzung und Tests

- `Komponenten/apothekerschrank/` mit `apothekerschrank.rb`, `README.md`, `test/` (Mock-API und DC-Formel-Auswerter wie beim Hochschrank): Geometrie, Formeln, OCL, Anleimer, Tags, ROLLEN-Tabelle identisch, Kurzhilfe.
- Plugin-Test: Apothekerschrank erzeugen und exportieren; prüfen, dass jede Seite Schienenbohrungen je Kasten hat und die Hochfront die Frontbefestigung je Kasten.
- `./run_tests.sh` grün, dann PR auf main.

## Fragen an dich

1. Beschlag: LEGRABOX-Hochfront (Empfehlung) oder klassischer Apothekerauszug? empfehlung
2. Standardbreite 400 mm ok? Unter etwa 300 mm wird LEGRABOX sehr eng. ok
3. Zargenhöhe der Kästen: C (148 mm Holzrückwand) als Standard, oder niedriger (M/K) mit Reling? ok
4. Fester Mittelboden standardmäßig an? ok
5. Kürzel AP ok? ok
