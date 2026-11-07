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

puts $fehler.zero? ? 'test_freier_schrank: alles OK' : "test_freier_schrank: #{$fehler} Fehler"
exit($fehler.zero? ? 0 : 1)
