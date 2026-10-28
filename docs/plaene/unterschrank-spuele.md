> Quelle: [Plan: Spülen-Unterschrank](https://claude.ai/artifact/XkbAVxQBbLSnjwQEQ5jy8L) (Plan-Dokument aus dem Projekt-Thread, Stand 28.10.2026)  
> Status: umgesetzt in PR #11, `Komponenten/unterschrank_spuele/`

# Plan: Spülen-Unterschrank

Oct 25, 2026 · @Jürgen Späder

## Kurzfassung

Der Spülenschrank wird ein eigener Generator `Komponenten/unterschrank_spuele/` nach dem Muster von Oberschrank und Hochschrank: Korpus wie der Unterschrank mit Tür, aber mit Installationsfreiraum hinten, ohne Einlegeböden und wahlweise mit Türen oder Blende plus Auszug. Kürzel `USP1`, Kategorie Unterschrank, alle Regeln (OCL, Tags, JT\_Schrank, Kurzhilfe, Tests) wie bei den anderen Schränken. Gebaut wird erst nach deiner Freigabe.

**Bitte entscheiden (meine Empfehlung jeweils fett):**

1. Fronten: **Türen (eine oder zwei) und als zweite Variante „Blende oben + großer Auszug“** beide anbieten, oder nur Türen? - beides
2. Leitungen hinten: **Rückwand mit rechteckigem Ausschnitt unten (Standard 350 mm hoch, ganze lichte Breite)**, oder Rückwand ganz weglassen, oder Rückwand 50 mm nach vorn versetzt (Installationsebene)? - rechteckiger ausschnitt und installationsebene
3. Auszug unter der Spüle: **kürzere LEGRABOX-Nennlänge, damit hinten Platz für Siphon bleibt (mind. 200 mm frei)**, oder ein U-förmiger Auszug um den Siphon (braucht ein Blum-Sonderteil, Maße von dir)? - 200mm luft lassen nach unten damit syhon normal eingebaut werden kann, darunter die ebene für mulleimer schublade; diese hat eine front auf die gesamt höhe (minus blende).
4. Strebe vorn: **wie beim Unterschrank liegend 100 mm**, oder hochkant (stabiler bei großem Spülenausschnitt)? was ist standard?
5. Standardbreite: **800 mm** (Breite bleibt einstellbar, z. B. 600/900/1200)? ja standard plus einstellbar. bei grosser breite türen ermöglchen, bei 600 schublade für müllsystem
6. Abfallsammler (z. B. Blum/Hailo im Auszug): jetzt nur vormerken, oder schon Platz/Ausschnitt einplanen? ..> abfalleimer ist in der schublade wenn dann&#32;

## Aufbau und Varianten

Der Korpus ist identisch zum Unterschrank mit Tür (gleiche Attributnamen, 19 mm Korpus, 8 mm Rückwand, 2 mm Fugen, Korpus ab y = 19 mm), damit Spülenschrank und Nachbarschränke bündig stehen und der TCN-Export ihn ohne neue Regeln erkennt.

| Teil | Spülenschrank | Unterschied zum Unterschrank mit Tür |
| --- | --- | --- |
| SeiteL / SeiteR | volle Höhe und Tiefe | keiner (Seiten sind immer gleich) |
| Boden | zwischen den Seiten | keiner; Tropfschutzmatte nur als Hinweis, nicht modelliert |
| StrebeVorn / StrebeHinten | oben, 100 mm breit | Spülenausschnitt der Arbeitsplatte liegt zwischen den Streben |
| Rückwand | 8 mm, unten Ausschnitt für Wasser und Abfluss | neu: Attribute `Ausschnitt_Hoehe` (350 mm), `Ausschnitt_Breite` (0 = ganze lichte Breite) |
| Einlegeböden | keine | entfällt |
| Fronten Variante Tür | eine Tür (ab 600 mm Breite zwei), Option `Art_Tuer` 1/2 wie beim Oberschrank | gleich |
| Fronten Variante Auszug | oben feste Blende (Höhe Spülbecken, Standard 200 mm), darunter ein großer LEGRABOX-Auszug | neu |

**Auszug unter der Spüle (Variante 2):** Die Blende ist eine feste Front ohne Schubkasten (Rolle `Front`, Bereich `B`). Der Auszug nutzt den vorhandenen LEGRABOX-Aufbau des Schubladen-Generators (KastenBoden, KastenRueckwand, Schiene im Lochraster), aber die Nennlänge wird so gewählt, dass hinten mindestens `Siphon_Freiraum` (200 mm) frei bleibt. Bei der Standardtiefe 800 mm wäre das NL 550 statt 650, bei 560 mm Tiefe NL 350 statt 550.

**Komponentenoptionen:** Breite, Höhe, Tiefe, Frontvariante (Tür / Blende + Auszug), Anzahl Türen, Blendenhöhe, Ausschnitt-Höhe und -Breite der Rückwand, Siphon-Freiraum.

**Nicht Teil dieses Schranks:** Spülbecken und Armatur als Platzhalter kommen aus dem Thread „Geräte in Schränken darstellen“; die Arbeitsplatte mit Spülenausschnitt ist ein eigenes Thema.

## Regeln: OCL, Tags, TCN-Export, Blum

- **OCL:** Jede Platte „Melamin weiss“ (Plattenwerkstoff), Anleimer „Anleimer Melamin weiss“ nur als OCL-Zuweisung, gezeichnet im Endmaß. Anleimer wie beim Unterschrank: Seiten, Boden, Strebe vorn vorne; Rückwand, Strebe hinten, Kastenboden keiner; Türen, Blende und Auszugfront rundum; Kastenrückwand oben.
- **Tags und JT\_Schrank:** `<Kürzel>_<Bereich>_<Teil>`, z. B. `USP1_SeiteL`, `USP1_Rueckwand`, `USP1_Tuer`, `USP1_B_Front` (Blende), `USP1_A_Front`, `USP1_A_KastenBoden`. Dazu `JT_Schrank` mit schrank, typ = Spülenschrank, kategorie = Unterschrank, bereich, teil, rolle. Die ROLLEN-Tabelle bleibt identisch zu allen Komponenten (der bestehende Test prüft das). Kürzel USP1, USP2 … automatisch frei gewählt.
- **TCN-Export:** Kategorie Unterschrank bringt Sockelfüße, Dübel Boden/Streben–Seite, Schienen und Frontbefestigung ohne Änderung am Plugin. Neu nötig ist nur der Rückwand-Ausschnitt, falls die Rückwand gefräst wird: eine Kontur-Bahn (W#89/W#2201). Das kommt als kleine Ergänzung in `regeln.rb` mit eigenem Test.
- **Lochreihen:** Seiten sind immer gleich, also bekommt das Fach mit Türen die Lochreihe wie jeder Unterschrank, das Fach mit Auszug keine (bestehende Regel).
- **Blum:** Türen mit Blum-Topfbändern; die Bohrungen setzt der TCN-Export, sobald Schritt 8 (Türen und Griffe) umgesetzt ist. Auszug LEGRABOX wie im Schubladen-Generator (NL-Tabelle, Frontbefestigung, Bodenfalz).

## Umsetzung im Repo und Tests

Nach deiner Freigabe ein Branch von `main` und ein PR, den du mergst.

1. `Komponenten/unterschrank_spuele/spuelenschrank.rb`: Skript wie `oberschrank.rb`, einmal per `load` in der Ruby-Konsole, baut die Dynamic Component und speichert `Spuelenschrank.skp` neben das Skript.
2. Kurzhilfe (HILFE\_KURZ, HILFE, DOKU\_URL) in Summary/Description der Komponente, README.md als Kurzdoku.
3. `test/test_spuelenschrank.rb` mit der Mock-API und dem DC-Formel-Auswerter: Maße beider Varianten, Rückwand-Ausschnitt, Nennlänge mit Siphon-Freiraum, Material, Anleimer, Tags, JT\_Schrank, ROLLEN-Gleichheit. Läuft in `./run_tests.sh` und GitHub Actions.
4. Im Export-Plugin: Test, der einen Spülenschrank erzeugt und die TCN prüft, plus die Rückwand-Kontur.

Wie bei den anderen Komponenten ist das ohne echtes SketchUp getestet; den ersten Lauf in SketchUp machst du.
