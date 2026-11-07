# Test ohne SketchUp: freier Schrank (Jürgen 2026-11-07), Schritt 1 – Teile zuweisen und prüfen.
# 1. Nachbau: fertige Schränke (Oberschrank, Unterschrank Schubladen) verlieren alle Kennzeichen,
#    Anleimer und Materialien und werden mit „Teil zuweisen“ wieder gekennzeichnet. Der TCN-Export
#    muss dieselben Bearbeitungen liefern wie beim Original.
# 2. Frei modelliert: Korpus mit Mittelwand aus einfachen Quadern; Lochreihen wählbar,
#    Mittelwand beidseitig, Prüfen meldet fehlende Rollen, Überschneidungen, Schubladen ohne Front.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
komp = File.expand_path('../../Komponenten', __dir__)
%w[oberschrank unterschrank_schubladen].each { |k| load File.join(komp, k, 'src', k, 'main.rb') }
load File.expand_path('../src/jt_schrank_cnc/main.rb', __dir__)

S = JTools::SchrankCnc
F = S::FreierSchrank
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

# Bearbeitungen aller sichtbaren Teile, ohne Namen (Tags und Titel unterscheiden sich)
def bearbeitungen(model)
  ws = []
  S::Export.erzeugen(model, alle_ws: ws)
  ws.map do |w|
    ops = w.ops.map { |o| [o.art, o.seite, o.p0.map { |v| v.round(2) }, o.p1&.map { |v| v.round(2) }, o.d, o.tiefe, o.raster, o.verteilt] }
    [w.rolle, w.lo.map { |v| v.round(2) }, w.hi.map { |v| v.round(2) }, w.kanten.sort, ops.sort_by(&:inspect)]
  end.sort_by(&:inspect)
end

ART = F::TEILE.to_h { |art, (basis, _, _)| [basis, art] }

def nachbauen(model, schrank)
  kat = S::Schraenke.definition(schrank).get_attribute(S::JT_DICT, 'kategorie')
  alt = F.teile(schrank).select { |p| p.last.get_attribute(S::JT_DICT, 'teil') }.map do |p|
    i = p.last
    [i, i.get_attribute(S::JT_DICT, 'teil'), i.get_attribute(S::JT_DICT, 'bereich'), F.kanten_von(p), i.material]
  end
  # alles Kennzeichnende entfernen (wie frei modelliert)
  d = S::Schraenke.definition(schrank)
  %w[schrank typ kategorie].each { |k| d.delete_attribute(S::JT_DICT, k) }
  alt.each do |i, *_|
    i.dicts.delete(S::JT_DICT)
    i.layer = nil
    i.material = nil
    i.definition.entities.grep(Sketchup::Face).each { |f| f.material = nil }
  end
  check(F.teile(schrank).none? { |p| p.last.get_attribute(S::JT_DICT, 'teil') }, 'Kennzeichen entfernt')
  F.kennzeichnen(model, schrank, kategorie: kat)
  alt.each do |i, teil, bereich, kanten, mat|
    art = ART[teil] || ART[teil.sub(/\d+\z/, '')]
    check(art, "Teil #{teil} im Dialog wählbar")
    next unless art
    F.zuweisen(model, schrank, i, art: art, bereich: bereich, material: mat, kanten: kanten)
  end
end

# --- 1. Nachbau Oberschrank (zwei Türen in Haltern, Einlegeböden, Rückwand in Nut) ---
model = Sketchup.active_model = Sketchup::Model.new
Oberschrank.erstellen({})
soll = bearbeitungen(model)
os = model.entities.grep(Sketchup::ComponentInstance).first
nachbauen(model, os)
ist = bearbeitungen(model)
check(soll.size == ist.size && soll.size > 5, "Oberschrank: gleich viele Teile (#{soll.size}/#{ist.size})")
check(soll == ist, 'Oberschrank: gleiche Bearbeitungen wie das Original')
(soll - ist).first(3).each { |x| puts "  soll: #{x.inspect[0, 300]}" }
(ist - soll).first(3).each { |x| puts "  ist:  #{x.inspect[0, 300]}" }
check(S::Schraenke.definition(os).get_attribute(S::JT_DICT, 'schrank') == 'FS1', 'Kürzel FS1')
check(S::Schraenke.definition(os).get_attribute(S::JT_DICT, 'typ') == 'Frei', 'Typ Frei')
tags = S::Schraenke.teile(model).map(&:name)
check(tags.all? { |t| t.start_with?('FS1_') }, "Tags FS1_…: #{tags.first(4)}")
check(tags.include?('FS1_Einlegeboden') && tags.include?('FS1_Einlegeboden2'), "Einlegeböden durchnummeriert: #{tags.grep(/Einl/)}")
check(F.pruefen(model, os).empty?, "Oberschrank geprüft ohne Meldung: #{F.pruefen(model, os)}")

# --- 1b. Nachbau Unterschrank mit Schubladen (Schienen, Frontbefestigung, Bodenfalz) ---
model = Sketchup.active_model = Sketchup::Model.new
d = UnterschrankSchubladen.erzeuge(model, UnterschrankSchubladen::DEFAULTS.dup)
uss = model.entities.add_instance(d, Geom::Transformation.new)
soll = bearbeitungen(model)
nachbauen(model, uss)
ist = bearbeitungen(model)
check(soll.size == ist.size && soll.size > 5, "Schubladen: gleich viele Teile (#{soll.size}/#{ist.size})")
check(soll == ist, 'Schubladen: gleiche Bearbeitungen wie das Original')
(soll - ist).first(3).each { |x| puts "  soll: #{x.inspect[0, 300]}" }
(ist - soll).first(3).each { |x| puts "  ist:  #{x.inspect[0, 300]}" }
check(soll.flatten.include?(:reihe), 'Schubladen: Bohrreihen vorhanden')

# --- 2. frei modelliert: 1000 breit, zwei Fächer mit Mittelwand ---
model = Sketchup.active_model = Sketchup::Model.new
schrank_def = model.definitions.add('Mein Schrank')
schrank = model.entities.add_instance(schrank_def, Geom::Transformation.new)
def platte(model, ents, name, pos, gr)
  d = model.definitions.add(name)
  f = d.entities.add_face([0, 0, 0], [gr[0].to_f / 25.4, 0, 0], [gr[0].to_f / 25.4, gr[1].to_f / 25.4, 0], [0, gr[1].to_f / 25.4, 0])
  f.reverse! if f.normal.z < 0
  f.pushpull(gr[2].to_f / 25.4)
  i = ents.add_instance(d, Geom::Transformation.translation(Geom::Vector3d.new(*pos.map { |v| v / 25.4 })))
  i.name = name
  i
end
e = schrank_def.entities
sl = platte(model, e, 'links', [0, 0, 0], [19, 560, 720])
sr = platte(model, e, 'rechts', [981, 0, 0], [19, 560, 720])
mw = platte(model, e, 'mitte', [490.5, 0, 19], [19, 560, 682])
bo = platte(model, e, 'boden', [19, 0, 0], [962, 560, 19])
de = platte(model, e, 'deckel', [19, 0, 701], [962, 560, 19])
eb = platte(model, e, 'einlegeboden', [19, 0, 300], [471.5, 540, 19])
lose = platte(model, e, 'klotz', [100, 100, 100], [50, 50, 50])

check(F.freies_kuerzel(model) == 'FS1', 'erstes Kürzel FS1')
F.kennzeichnen(model, schrank, kategorie: 'Unterschrank', name: 'Regal')
check(F.frei?(schrank), 'Schrank ist frei')
begin
  F.zuweisen(model, schrank, sl, art: 'Gibt es nicht')
  check(false, 'unbekanntes Teil abgelehnt')
rescue ArgumentError
  check(true, '')
end
F.zuweisen(model, schrank, sl, art: 'Seite links')
F.zuweisen(model, schrank, sr, art: 'Seite rechts', lochreihe: false)
F.zuweisen(model, schrank, mw, art: 'Mittelwand')
F.zuweisen(model, schrank, bo, art: 'Boden')
F.zuweisen(model, schrank, de, art: 'Deckel')
F.zuweisen(model, schrank, eb, art: 'Einlegeboden')

check(sl.material&.name == 'Melamin weiss', 'Standardmaterial Melamin weiss')
check(S::Materialien.platte?(sl.material), 'Melamin weiss ist Plattenmaterial')
check(sl.layer.name == 'FS1_SeiteL' && mw.layer.name == 'FS1_Mittelwand', "Tags #{sl.layer.name}, #{mw.layer.name}")
check(F.kanten_von([sl]) == [:vorn], "Seite: Anleimer vorn (#{F.kanten_von([sl])})")
check(F.kanten_von([eb]) == [:vorn], 'Einlegeboden: Anleimer vorn')
F.zuweisen(model, schrank, eb, art: 'Einlegeboden', kanten: %i[vorn hinten links])
check(F.kanten_von([eb]).sort == %i[hinten links vorn], "Einlegeboden: Kanten frei wählbar (#{F.kanten_von([eb])})")
check(eb.layer.name == 'FS1_Einlegeboden', 'erneut zuweisen behält den Namen')
F.zuweisen(model, schrank, sl, art: 'Seite links', kanten: %i[vorn links])
check(F.kanten_von([sl]) == [:vorn], 'Hauptfläche (Stärke) bekommt keinen Anleimer')

meld = F.pruefen(model, schrank)
check(meld.any? { |m| m.include?('klotz') && m.include?('keine Rolle') }, "Teil ohne Rolle gemeldet: #{meld}")
ws = []
dateien, export_meld = S::Export.erzeugen(model, alle_ws: ws)
check(export_meld.any? { |m| m.include?('klotz') }, 'Export zeigt die Prüf-Meldungen')
# Mittelwand mit Bohrungen auf beiden Flächen, Boden mit Sockelfüßen unten und Mittelwand-Dübeln oben:
# je ein zweites Programm fürs gewendete Werkstück (_Rueckseite), keine Bohrung fällt weg
check(dateien.map(&:name).sort == %w[FS1_Boden FS1_Boden_Rueckseite FS1_Deckel FS1_Einlegeboden FS1_Mittelwand FS1_Mittelwand_Rueckseite FS1_SeiteL FS1_SeiteR],
      "Dateien: #{dateien.map(&:name)}")
check(export_meld.none? { |m| m.include?('fehlt in der TCN') }, "keine Bohrung fehlt in der TCN: #{export_meld}")

w = ws.to_h { |x| [x.name, x] }
reihen = ->(n) { w[n].ops.select { |o| o.titel == 'Lochreihe' } }
check(reihen.('FS1_SeiteL').size == 2, "Seite links: Lochreihe (2 Reihen) – #{reihen.('FS1_SeiteL').size}")
check(reihen.('FS1_SeiteR').empty?, 'Seite rechts: Lochreihe abgewählt')
check(reihen.('FS1_Mittelwand').map(&:seite).uniq.sort == %i[xmax xmin], "Mittelwand: Lochreihen auf beiden Flächen (#{reihen.('FS1_Mittelwand').map(&:seite).uniq})")
check(w['FS1_Boden'].ops.any? { |o| o.titel.to_s.start_with?('Duebel') || o.art == :bohrung || o.art == :reihe }, 'Boden: Dübel an den Seiten')
mw.set_attribute(S::JT_DICT, 'lochreihe', false)
ws = []
S::Export.erzeugen(model, alle_ws: ws)
check(ws.find { |x| x.name == 'FS1_Mittelwand' }.ops.none? { |o| o.titel == 'Lochreihe' }, 'Mittelwand: Lochreihe abwählbar')

# Überschneidung und Schublade ohne Front
F.zuweisen(model, schrank, lose, art: 'Kastenboden', bereich: 'S1')
lose2 = platte(model, e, 'klotz2', [120, 120, 120], [50, 50, 50])
F.zuweisen(model, schrank, lose2, art: 'Leiste')
meld = F.pruefen(model, schrank)
check(meld.any? { |m| m.include?('überschneiden') }, "Überschneidung gemeldet: #{meld}")
check(meld.any? { |m| m.include?('FS1_S1') && m.include?('ohne Front') }, 'Schublade ohne Front gemeldet')
check(meld.any? { |m| m.include?('Kastenrückwand fehlt') }, 'fehlende Kastenrückwand gemeldet')
check(lose.layer.name == 'FS1_S1_KastenBoden', "Tag mit Bereich: #{lose.layer.name}")

# zweiter freier Schrank bekommt FS2; kennzeichnen ist wiederholbar
d2 = model.definitions.add('Zweiter')
s2 = model.entities.add_instance(d2, Geom::Transformation.new)
F.kennzeichnen(model, s2)
check(S::Schraenke.definition(s2).get_attribute(S::JT_DICT, 'schrank') == 'FS2', 'zweiter Schrank FS2')
F.kennzeichnen(model, schrank, kategorie: 'Hochschrank')
check(S::Schraenke.definition(schrank).get_attribute(S::JT_DICT, 'schrank') == 'FS1', 'erneut kennzeichnen behält FS1')
check(sl.get_attribute(S::JT_DICT, 'kategorie') == 'Hochschrank', 'Kategorie an den Teilen nachgezogen')

# --- 3. Schritt 2a: Korpus anlegen, Mittelwand, Einlegeboden, Zwischenboden ---
model = Sketchup.active_model = Sketchup::Model.new
us = F.anlegen(model, kategorie: 'Unterschrank', breite: 900, hoehe: 720, tiefe: 560, name: 'Regal')
tags = ->(m) { S::Schraenke.teile(m).map(&:name).sort }
check(tags.(model) == %w[FS1_Boden FS1_Rueckwand FS1_SeiteL FS1_SeiteR FS1_StrebeHinten FS1_StrebeVorn], "Unterschrank-Korpus: #{tags.(model)}")
check(F.pruefen(model, us).empty?, "Korpus ohne Meldung: #{F.pruefen(model, us)}")
f = F.faecher(us)
check(f.size == 1 && f[0][:x].map(&:round) == [19, 881] && f[0][:z].map(&:round) == [19, 701], "ein Fach 862 × 682: #{f}")
check(f[0][:y].map(&:round) == [19, 579], "Fach-Tiefe bis zur aufgesetzten Rückwand: #{f[0][:y]}")
F.mittelwand(model, us) # Mitte
f = F.faecher(us)
check(f.size == 2 && f.map { |x| (x[:x][1] - x[:x][0]).round(1) } == [421.5, 421.5], "Mittelwand teilt in 2 Fächer: #{f.map { |x| x[:x] }}")
F.einlegeboden(model, us, fach: 1, hoehe: 300)
F.zwischenboden(model, us, fach: 2)
check(F.pruefen(model, us).empty?, "mit Mittelwand, Einlege- und Zwischenboden ohne Meldung: #{F.pruefen(model, us)}")
ws = []
dat, meld = S::Export.erzeugen(model, alle_ws: ws)
w = ws.to_h { |x| [x.name, x] }
mw = w['FS1_Mittelwand']
check(mw && mw.ops.count { |o| o.titel.to_s.start_with?('Duebel') } >= 2, "Mittelwand: Dübel zu Boden und Streben (#{mw&.ops&.map(&:titel)})")
check(w['FS1_Boden'].ops.any? { |o| o.titel == 'Duebel Mittelwand' && o.seite == :zmax }, 'Boden: Dübel von oben für die Mittelwand')
check(meld.none? { |m| m.include?('fehlt in der TCN') }, "keine Bearbeitung fehlt in der TCN: #{meld.grep(/fehlt/)}")
%w[FS1_Boden FS1_Mittelwand].each do |n|
  r = dat.find { |x| x.name == "#{n}_Rueckseite" }
  v = dat.find { |x| x.name == n }
  check(r && v && r.wende && r.nr == v.nr, "#{n}: Programm für die Rückseite mit derselben Nummer")
end
zs = S::Stueckliste.zeilen(dat)
z = zs.find { |x| x.tag == 'FS1_Mittelwand' }
check(zs.count { |x| x.tag == 'FS1_Mittelwand' } == 1 && z.datei.include?('_Rueckseite.tcn'), "Stückliste: eine Zeile, beide TCN (#{z&.datei})")
check(w['FS1_StrebeVorn'].ops.any? { |o| o.titel == 'Duebel Mittelwand' && o.seite == :zmin }, 'Strebe: Dübel von unten für die Mittelwand')
check(mw.ops.select { |o| o.titel == 'Lochreihe' }.map(&:seite).uniq.sort == %i[xmax xmin], 'Mittelwand: Lochreihen beidseitig')
zb = w['FS1_Zwischenboden']
check(zb && zb.ops.count { |o| o.titel.to_s.start_with?('Duebel') } == 2, "Zwischenboden: Dübel zu Mittelwand und Seite (#{zb&.ops&.map(&:titel)})")
eb = w['FS1_Einlegeboden']
check(eb && (eb.lo[1] - w['FS1_SeiteL'].lo[1]).round == 10, 'Einlegeboden vorn 10 mm zurück')
check(eb.kanten.keys == [:ymin], "Einlegeboden: Anleimer vorn (#{eb.kanten})")
check(dat.reject(&:wende).size == ws.size, 'alle Teile exportiert')
begin
  F.einlegeboden(model, us, fach: 3)
  check(false, 'Fach 3 abgelehnt')
rescue ArgumentError => ex
  check(ex.message.include?('Fach 3'), ex.message)
end
begin
  F.mittelwand(model, us, fach: 1, abstand: 500)
  check(false, 'Mittelwand außerhalb abgelehnt')
rescue ArgumentError
  check(true, '')
end

# Oberschrank: Deckel, Rückwand genutet (Nut in Seiten, Boden), Deckel-Schrauben
os = F.anlegen(model, kategorie: 'Oberschrank', breite: 600, hoehe: 720, tiefe: 350)
check(S::Schraenke.definition(os).get_attribute(S::JT_DICT, 'schrank') == 'FS2', 'zweiter Schrank FS2')
ws = []
S::Export.erzeugen(model, alle_ws: ws)
w = ws.to_h { |x| [x.name, x] }
check(w['FS2_Deckel'] && !w['FS2_StrebeVorn'], 'Oberschrank mit Deckel')
%w[FS2_SeiteL FS2_SeiteR FS2_Boden].each { |n| check(w[n].ops.any? { |o| o.art == :nut }, "#{n}: Rückwandnut") }
check(w['FS2_Rueckwand'].ops.any? { |o| o.titel.to_s.include?('Schraube') }, 'Oberschrank: Rückwand an den Deckel geschraubt')
check(F.pruefen(model, os).empty?, "Oberschrank-Korpus ohne Meldung: #{F.pruefen(model, os)}")
check(F.faecher(os).first[:y][1].round == 350 + 19 - 25 - 8, "Fach endet vor der genuteten Rückwand: #{F.faecher(os).first[:y]}")
begin
  F.anlegen(model, breite: 40)
  check(false, 'zu klein abgelehnt')
rescue ArgumentError
  check(true, '')
end

# --- 4. Schritt 2b: Türen, Schubladen, Blende ---
model = Sketchup.active_model = Sketchup::Model.new
us = F.anlegen(model, kategorie: 'Unterschrank', breite: 900, hoehe: 720, tiefe: 560)
F.mittelwand(model, us)
F.einlegeboden(model, us, fach: 1, hoehe: 300)
F.tuer(model, us, fach: 1, anschlag: 'links')
F.blende(model, us, fach: 2, hoehe: 100)
s1 = F.schublade(model, us, fach: 2, z: 1, hoehe: 300)
s2 = F.schublade(model, us, fach: 2, z: 303, hoehe: 314)
check(F.pruefen(model, us).empty?, "Tür, Blende, 2 Schubladen ohne Meldung: #{F.pruefen(model, us)}")
ws = []
dat, meld = S::Export.erzeugen(model, alle_ws: ws)
w = ws.to_h { |x| [x.name, x] }
check(w.key?('FS1_Tuer') && w.key?('FS1_Blende') && w.key?('FS1_S1_Front') && w.key?('FS1_S2_KastenBoden'), "Teile: #{w.keys.sort}")
tuer = w['FS1_Tuer']
check(tuer.lo[0].round(1) == 1.0 && tuer.hi[0].round(1) == 449.0, "Tür links: außen voller, an der Mittelwand halber Aufschlag (#{tuer.lo[0]}..#{tuer.hi[0]})")
check(tuer.hi[1].round(1) == 17.0, "Tür 2 mm vor dem Korpus (#{tuer.hi[1]})")
check(tuer.kanten.size == 4, 'Tür: Anleimer rundum')
topf = tuer.ops.select { |o| o.titel.to_s =~ /Topf/i }
check(!topf.empty? && topf.all? { |o| o.p0[0] < 100 }, "Tür: Topfbohrungen an der linken Anschlagseite (#{tuer.ops.map(&:titel).uniq})")
check(w['FS1_SeiteL'].ops.any? { |o| o.titel == 'Lochreihe' }, 'Seite links: Lochreihe im Türfach (Montageplatten in die Lochreihe)')
check(w['FS1_Mittelwand'].ops.any? { |o| o.titel == 'Lochreihe' && o.seite == :xmin }, 'Mittelwand: Lochreihe zum Türfach, Schienen zum Schubladenfach')
mw = w['FS1_Mittelwand']
check(mw.ops.any? { |o| o.titel.to_s =~ /Schiene/i && o.seite == :xmax }, "Mittelwand: Schienenbohrungen zum Schubladenfach (#{mw.ops.map(&:titel).uniq})")
check(w['FS1_SeiteR'].ops.any? { |o| o.titel.to_s =~ /Schiene/i }, 'Seite rechts: Schienenbohrungen')
check(w['FS1_S1_Front'].ops.any? { |o| o.titel.to_s =~ /Front/i }, "Front S1: Frontbefestigung (#{w['FS1_S1_Front'].ops.map(&:titel).uniq})")
kb = w['FS1_S1_KastenBoden']
check((kb.hi[0] - kb.lo[0]).round(1) == (421.5 - 35).round(1), "Kastenboden = lichte Weite − 35 (#{kb.hi[0] - kb.lo[0]})")
check(meld.none? { |m| m.include?('Zarge') && m.include?('FS1') }, "Zargen passen: #{meld.grep(/Zarge/)}")
check(s1.definition.get_attribute('dynamic_attributes', 'onclick').to_s.include?('ANIMATE'), 'Schublade fährt mit Interagieren aus')
check(s1.layer.name == 'FS1_S1_Schublade' && s2.layer.name == 'FS1_S2_Schublade', 'Schubladen-Tags S1, S2')
check(dat.reject(&:wende).size == ws.size, 'alle Teile exportiert')
# Doppeltür, Anschlag rechts
model = Sketchup.active_model = Sketchup::Model.new
os = F.anlegen(model, kategorie: 'Oberschrank', breite: 800, hoehe: 720, tiefe: 350)
F.tuer(model, os, anschlag: 'doppelt')
ws = []
S::Export.erzeugen(model, alle_ws: ws)
w = ws.to_h { |x| [x.name, x] }
l, r = w['FS1_TuerL'], w['FS1_TuerR']
check(l && r && (r.lo[0] - l.hi[0]).round(1) == 2.0, 'Doppeltür mit 2 mm Mittelspalt')
check(r.ops.select { |o| o.titel.to_s =~ /Topf/i }.all? { |o| o.p0[0] > 700 }, 'rechte Tür: Topfbänder rechts')
check(F.pruefen(model, os).empty?, "Doppeltür ohne Meldung: #{F.pruefen(model, os)}")
begin
  F.schublade(model, os, hoehe: 900)
  check(false, 'zu hohe Schublade abgelehnt')
rescue ArgumentError
  check(true, '')
end

# --- 5. Schritt 3: Bibliothek (speichern, Versionen, einfügen) und Schrank lösen ---
require 'tmpdir'
$gespeichert = {}
module Sketchup
  class ComponentDefinition
    def save_as(pfad)
      File.write(pfad, 'skp')
      $gespeichert[pfad] = self
      true
    end
  end
  class Definitions
    def load(pfad) = $gespeichert.fetch(pfad) # wie SketchUp bei schon geladener Datei: dieselbe Definition
  end
end
Dir.mktmpdir do |bib|
  model = Sketchup.active_model = Sketchup::Model.new
  us = F.anlegen(model, kategorie: 'Unterschrank', breite: 800, hoehe: 720, tiefe: 560, name: 'Regal')
  F.mittelwand(model, us)
  F.schublade(model, us, fach: 2, hoehe: 300)
  e = F.speichern(model, us, name: 'Mein Regal', beschreibung: 'Test', ordner: bib)
  check(File.exist?(File.join(bib, 'Mein Regal.skp')) && File.exist?(File.join(bib, 'Mein Regal.json')), 'Bibliothek: .skp und .json geschrieben')
  check(e['version'] == 1 && e['kategorie'] == 'Unterschrank' && [e['breite'], e['hoehe']] == [800, 720], "Eintrag: #{e}")
  e2 = F.speichern(model, us, name: 'Mein Regal', ordner: bib)
  check(e2['version'] == 2 && File.exist?(File.join(bib, 'alt', 'Mein Regal_v1.skp')), 'erneut gespeichert: Version 2, alte Fassung in alt/')
  liste = F.bibliothek(bib)
  check(liste.size == 1 && liste.first['version'] == 2, "Bibliothek listet einen Schrank in Version 2 (#{liste})")
  neu = F.einfuegen(model, liste.first['datei'])
  kz = S::Schraenke.definition(neu).get_attribute(S::JT_DICT, 'schrank')
  check(kz == 'FS2' && !neu.definition.equal?(us.definition), "eingefügt mit neuem Kürzel FS2 und eigener Definition (#{kz})")
  tags_neu = S::Schraenke.teile(model).select { |t| t.schrank.equal?(neu) }.map(&:name)
  tags_alt = S::Schraenke.teile(model).select { |t| t.schrank.equal?(us) }.map(&:name)
  check(tags_neu.sort == tags_alt.map { |t| t.sub('FS1_', 'FS2_') }.sort && tags_neu.all? { |t| t.start_with?('FS2_') }, "Tags umbenannt: #{tags_neu.first(3)}")
  check(tags_alt.all? { |t| t.start_with?('FS1_') }, 'Original behält FS1')
  check(F.pruefen(model, neu).empty?, "eingefügter Schrank ohne Meldung: #{F.pruefen(model, neu)}")
  check(neu.definition.entities.instances.any? { |i| i.layer&.name == 'FS2_S1_Schublade' }, 'Schubladen-Tag umbenannt')
  dat, = S::Export.erzeugen(model)
  check(dat.any? { |x| x.name == 'FS2_Mittelwand' } && dat.any? { |x| x.name == 'FS1_Mittelwand' }, 'beide Schränke im Export')
  begin
    F.speichern(model, us, name: '  ', ordner: bib)
    check(false, 'leerer Name abgelehnt')
  rescue ArgumentError
    check(true, '')
  end
end

# Schrank lösen: Unterschrank mit Schubladen wird frei bearbeitbar, Export bleibt gleich
model = Sketchup.active_model = Sketchup::Model.new
d = UnterschrankSchubladen.erzeuge(model, UnterschrankSchubladen::DEFAULTS.dup)
uss = model.entities.add_instance(d, Geom::Transformation.new)
vorher = bearbeitungen(model)
check(!F.frei?(uss), 'Komponente ist nicht frei')
F.loesen(model, uss)
check(F.frei?(uss), 'gelöst: frei')
formeln = F.alle_instanzen(uss.definition.entities).flat_map { |i| [i, i.definition] }.uniq.sum do |x|
  (x.attribute_dictionary('dynamic_attributes') || {}).keys.count { |k| k.to_s.end_with?('_formula') }
end
check(formeln.zero?, "keine DC-Formeln mehr (#{formeln})")
check(bearbeitungen(model) == vorher, 'gelöster Schrank: gleiche Bearbeitungen')
F.einlegeboden(model, uss) rescue nil
check(F.pruefen(model, uss).none? { |m| m.include?('keine Rolle') }, "gelöster Schrank: Prüfen geht (#{F.pruefen(model, uss)})")

# Freier Schrank im Menü der Schrankgruppen: Dialog mit Tiefe Korpus, Maße am Schrank
model = Sketchup.active_model = Sketchup::Model.new
F.anlegen(model, kategorie: 'Oberschrank', breite: 600, hoehe: 720, tiefe: 400)
t = model.entities.grep(Sketchup::ComponentInstance).last.definition.get_attribute('dynamic_attributes', 'tiefe')
check(t && (t * 25.4 - 400).abs < 1e-6, "Tiefe am Schrank (#{t})")

puts $fehler.zero? ? 'test_freier_schrank: alles OK' : "test_freier_schrank: #{$fehler} Fehler"
exit($fehler.zero? ? 0 : 1)
