> Quelle: [Plan: Geschirrspüler-Unterschrank](https://claude.ai/artifact/NayCURgmMsvvXyJx2z653s) (Plan-Dokument aus dem Projekt-Thread, Stand 28.10.2026)  
> Status: umgesetzt in PR #9, `Komponenten/unterschrank_geschirrspueler/`

# Plan: Geschirrspüler-Unterschrank

Oct 25, 2026 · @Jürgen Späder

Status: **Plan, wartet auf Freigabe.** Gebaut wird erst nach deinem OK (Branch von main, PR, du mergst).

## Kurzfassung

Ein vollintegrierter Geschirrspüler hat keinen eigenen Korpus. Die Komponente „Unterschrank Geschirrspüler“ ist deshalb eine **Nische mit Möbelfront**: Sie hält die Breite in der Zeile frei, trägt die Front (auf die Gerätetür geschraubt), optional Abschlusswangen und den Geräte-Platzhalter. Sie verhält sich nach außen wie jeder andere Unterschrank (Tags, `JT_Schrank`, OCL, Frontfarbe), damit sie in der Küchenzeile und im TCN-Export nahtlos mitläuft.

## Komponentenoptionen

| Option | Standard | Bemerkung |
| --- | --- | --- |
| Nischenbreite | 600 mm | Auswahl 450 / 600 mm (Geräte 448 / 598 breit) |
| Höhe | 700 mm | wie Korpushöhe der anderen Unterschränke, Front schließt mit den Nachbarfronten ab |
| Tiefe | 800 mm | wie Unterschrank; nur für Wangen und Platzhalter, Gerät braucht min. 550 mm |
| Abschlusswange | keine | keine / links / rechts / beide (wenn der Spüler am Zeilenende steht) |
| Front | einteilig | Vorschlag Option: geteilt in Schubladen-Optik (siehe Frage 3) |

Feste Maße als Attribute wie bei den anderen: `Materialstaerke_Korpus` 19 mm (Front und Wange), `Spaltbreite` 2 mm.

## Aufbau

- **Front** 19 mm, Breite − 2 mm (1 mm Fuge je Seite), Höhe = Höhe, 2 mm vor der Korpusvorderkante (y = −Spalt), genau wie Fronten im Unterschrank mit Schubladen. Mit *Interagieren* klappt sie nach vorne unten auf (Drehpunkt Unterkante), wie die Gerätetür.
- **Abschlusswange** (optional) 19 mm, Höhe wie Seiten der Unterschränke, Tiefe = Korpustiefe + Rückwand, bündig mit den Seiten der Nachbarschränke. Die Front bleibt in der Nischenbreite; die Wange liegt außerhalb.
- **Kein Boden, keine Seiten, keine Streben, keine Rückwand** – das Gerät wird an der Arbeitsplatte bzw. den Nachbarseiten befestigt, Dampfschutz liefert der Hersteller.
- **Geräte-Platzhalter** im Nischenraum, kommt aus dem Thread „Geräte in Schränken darstellen“ (Tag `Geraete_Plan`/`Geraete_Render`, ohne OCL-Material, ohne `JT_Schrank`). Bis der fertig ist, setze ich einen einfachen halbtransparenten Block als Platzhalter.

## OpenCutList, Tags, TCN

- Material „Melamin weiss“ (OCL-Plattenwerkstoff), Endmaß gezeichnet, Anleimer nur als OCL-Zuweisung:

| Teil | Anleimer |
| --- | --- |
| Front | rundum |
| Wange | vorne und oben (Annahme, unten liegt sie auf dem Boden) |

- Tags `<Kürzel>_<Teil>` mit neuem Kürzel **USG1** (Unterschrank Geschirrspüler): `USG1_Front`, `USG1_WangeL`, `USG1_WangeR`.
- `JT_Schrank`: `typ` = Unterschrank Geschirrspueler, `kategorie` = **Unterschrank** (Frontfarbe „nur Unterschränke“ trifft ihn mit), Front `rolle` = Front.
- Neue Rolle **Wange** in der gemeinsamen `ROLLEN`-Tabelle (alle Komponenten, Test prüft Gleichheit). Bewusst nicht „Seite“, sonst bekäme die Wange Lochreihen und Dübel. Der TCN-Export macht für die Wange nur das Formatieren.
- Front im TCN: nur Formatieren und ggf. Griffbohrungen (Griff-Funktion). **Keine** Bohrungen für die Gerätebefestigung, weil das Schablonenmaß je Hersteller verschieden ist (siehe Frage 4).

## Umsetzung

- `Komponenten/unterschrank_geschirrspueler/geschirrspueler.rb` – Skript wie beim Oberschrank: einmal per `load` in der Ruby-Konsole, erzeugt die DC und speichert `Unterschrank_Geschirrspueler.skp` neben das Skript.
- README.md als Kurzdoku, Kurzhilfe als DC-Summary/Description mit Link.
- Tests mit Mock-API und DC-Formel-Auswerter: Maße bei 450/600, Fugen, Wangen an/aus, Klapp-Animation, OCL-Material und Anleimer, Tags, `JT_Schrank`, Kurzhilfe; im Plugin-Test: TCN-Export erzeugt Front und Wange ohne Lochreihen/Dübel, Frontfarbe greift.
- `./run_tests.sh` grün, dann PR.

## Fragen an dich

1. **Breite:** Nur Auswahl 450 / 600 mm, oder auch frei einstellbar? Mein Vorschlag: Auswahl. → ok
2. **Abschlusswange:** Brauchst du sie in dieser Komponente? Wenn ja: Wie hoch ist dein Sockel (für die Wangenhöhe bis zum Boden)? Und gibt es eine Sockelblende, die vor dem Spüler ausgespart werden muss? → sockel ist variabel (verstellbare füsse)
3. **Geteilte Front:** Soll es eine Option geben, die Front wie den Schubladenschrank daneben in 2–3 Felder zu teilen (gleiche Fugen), oder immer einteilig? spülmaschinen schrank hat nur das fach für die maschine, keine schubladen
4. **Gerätebefestigung:** Die Front wird vor Ort mit der Schablone des Herstellers verschraubt, also keine CNC-Bohrungen dafür. Passt das? → ja
5. **Gerätehöhe:** Die Front ist 700 mm hoch wie die anderen Unterschränke. Ob das zur Gerätetür passt, hängt von Gerät und Sockel ab (übliche Nischenhöhe 815–875 mm). Soll ich eine Warnung in der Kurzhilfe ergänzen oder einen Parameter „Fronthöhe“ getrennt von der Korpushöhe anbieten? ja
