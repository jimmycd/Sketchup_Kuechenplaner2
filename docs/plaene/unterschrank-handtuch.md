> Quelle: [Plan: Schmaler Unterschrank mit Handtuchhalter](https://claude.ai/artifact/2ak7dcVPUF2K9pnnCs1gAJ) (Plan-Dokument aus dem Projekt-Thread, Stand 28.10.2026)  
> Status: umgesetzt in PR #14, `Komponenten/unterschrank_handtuch/` (Jürgen: nur Hochauszug, Beschlag Häfele HU Slim Base)

# Plan: Schmaler Unterschrank mit Handtuchhalter

Oct 25, 2026 · @Jürgen Späder

Vorschlag: eine neue Komponente **Unterschrank Handtuchhalter** (Kürzel `USH`), Standardbreite 150 mm (150–300 mm), mit dem Korpus des Unterschranks mit Schubladen und einer Front als Hochauszug mit Handtuchstangen. Gebaut wird erst nach deiner Freigabe; vorher bitte die Fragen am Ende beantworten (Ausführung, Beschlag, Breite).

## Ausführungen und Komponentenoptionen

Zwei Ausführungen in einer Komponente, umschaltbar in *Komponentenoptionen*:

- **Hochauszug (Standard):** Front über die volle Höhe auf Vollauszugschienen, dahinter ein Gestell mit Handtuchstangen. Mit *Interagieren* fährt der Auszug heraus.
- **Tür:** Tür mit Blum-Topfbändern, Anschlag links oder rechts. Oben unter der Arbeitsplatte ein seitlich ausziehbarer Handtuchhalter (an die Seite geschraubt), darunter Einlegeböden.

| Option | Standard | Bereich |
| --- | --- | --- |
| Breite (mm) | 150 | 150–300 |
| Höhe / Tiefe (mm) | 700 / 800 | wie Unterschrank mit Tür |
| Ausführung | Hochauszug | Hochauszug, Tür |
| Anschlag Tür | links | links, rechts |
| Einlegeböden (nur Tür) | 1 | 0–2 |

Feste Maße als Komponentenattribute mit denselben Namen wie bei den anderen Unterschränken (`Materialstaerke_Korpus` 19 mm, `Materialstarke_Rueckwand` 8 mm, `BreiteStreben` 100 mm, `Spaltbreite` 2 mm).

## Aufbau

- **Korpus** identisch zum Unterschrank mit Schubladen: SeiteL/R, Boden, StrebeVorn/-Hinten, Rückwand, gleiche Formeln (Code wird übernommen). Bei 150 mm Breite bleiben 112 mm lichte Weite.
- **Front / Tür** 19 mm, 2 mm Fuge, Höhe wie die Front einer einzelnen Schublade. Griffe über die vorhandenen Angaben `griff_*` im `JT_Schrank`, damit „Griffe ändern“ im Plugin funktioniert.
- **Handtuchhalter** ist ein Kaufteil. Er wird als Platzhalter gezeichnet (Quader mit dem Bauraum des Beschlags), nicht als Platte. So sieht man in SketchUp, wo er sitzt, und er steht in OCL als Beschlag in der Liste.
- **Hochauszug:** Front an das Auszugsgestell geschraubt, keine Lochreihe in den Seiten (gleiche Regel wie bei Schubladen). Die Schienenbohrungen hängen vom gewählten Beschlag ab.
- **Tür:** Topfbänder im Lochraster der Seite, Lochreihen für die Einlegeböden nach den bestehenden Regeln (38 mm über / 33 mm unter festem Boden, 35 mm vorn).
- Der Korpus beginnt wie bei den anderen Schränken bei y = 19 mm, die Front liegt davor.

## OpenCutList, Tags und TCN-Export

Gezeichnet wird im Endmaß; den 2-mm-Abzug rechnet nur OCL.

| Teil | Material | Anleimer | Tag |
| --- | --- | --- | --- |
| Seiten | Melamin weiss | vorne | `USH1_SeiteL`, `USH1_SeiteR` |
| Boden, Strebe vorn | Melamin weiss | vorne | `USH1_Boden`, `USH1_StrebeVorn` |
| Strebe hinten, Rückwand | Melamin weiss | keiner | `USH1_StrebeHinten`, `USH1_Rueckwand` |
| Front bzw. Tür | Melamin weiss | rundum | `USH1_Front` bzw. `USH1_Tuer` |
| Einlegeböden (Tür) | Melamin weiss | vorne | `USH1_Einlegeboden1`, `2` |
| Handtuchhalter | Beschlag Handtuchhalter (OCL-Typ Beschlag) | – | `USH1_Handtuchhalter` |

- `JT_Schrank` an jedem Teil: `typ` Unterschrank Handtuchhalter, `kategorie` Unterschrank. Damit greift „Frontfarbe ändern“ mit der Auswahl Unterschränke ohne Änderung am Plugin.
- Neue Rolle `Handtuchhalter` → `Beschlag` in der Tabelle `ROLLEN`, in allen Komponenten gleich (der Test prüft das).
- TCN-Export: Korpusteile wie beim Unterschrank mit Schubladen (Dübel, Sockelfüße, Rückwand). Teile mit Rolle Beschlag werden übersprungen. Bohrungen für Auszugschienen kommen dazu, sobald der Beschlag feststeht; die Topfband-Bohrungen der Tür kommen mit dem allgemeinen Schritt „Türen“ im Plugin.

## Umsetzung nach Freigabe

1. Branch von `main`, neuer Ordner `Komponenten/unterschrank_handtuch/` mit dem Skript `unterschrank_handtuch.rb` (wie Ober- und Hochschrank: einmal per `load` in der Ruby-Konsole, speichert `Unterschrank_Handtuch.skp`).
2. `README.md` als Kurzdoku, Kurzhilfe (`HILFE`) oben in *Komponentenoptionen* mit Link auf die README; Zeile in der Tabelle der Haupt-README.
3. `ROLLEN` in allen Komponenten um `Handtuchhalter` erweitern; TCN-Export überspringt Rolle Beschlag.
4. Tests ohne SketchUp: Geometrie beider Ausführungen, Formeln nach Umkonfigurieren (Breite, Ausführung, Anschlag, Einlegeböden), OCL-Material, Anleimer, Tags, `JT_Schrank`, Kurzhilfe; im Plugin-Test Export und Frontfarbe mit dem neuen Schrank.
5. Pull Request, du prüfst und mergst. In echtem SketchUp ist er dann wie die anderen noch nicht getestet.

## Fragen an Jürgen

- [ ] Ausführung: beide als Option (Vorschlag), nur Hochauszug oder nur Tür? hochauszug
- [ ] Welchen Handtuchauszug bzw. Handtuchhalter verwendest du (Hersteller, Artikelnummer)? Davon hängen Bauraum, Mindestbreite und Schienenbohrungen ab. Ohne Angabe baue ich einen Platzhalter und die Bohrungen kommen später. -
- [ ] Breite: Standard 150 mm, Bereich 150–300 mm passt? siehe anleitung
- [ ] Bei der Tür: Handtuchhalter oben seitlich ausziehbar, oder lieber eine Stange an der Türinnenseite? auszihebar siehe anleitung
