# Test ohne SketchUp: Geräte aus den Nischen der echten Schrank-Generatoren
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
komp = File.expand_path('../..', __dir__)
$VERBOSE = nil
%w[unterschrank_geschirrspueler unterschrank_kochfeld unterschrank_spuele hochschrank_geraete].each do |k|
  load File.join(komp, k, 'src', k, 'main.rb')
end
load File.expand_path('../src/geraete/main.rb', __dir__)
load File.join(komp, '../sketchup-tcn-export-plugin/src/jt_schrank_cnc/schraenke.rb')

G = Geraete
EPS = 1e-6
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end
def nah(a, b) = (a - b).abs < EPS

# --- Reine Berechnung ---
check(G.art('Backofen60') == ['Backofen', 60] && G.art('Spuele') == ['Spuele', nil], 'Kennungen lesen')
check(G.art('frei').nil? && G.art('keine').nil? && G.art('Kuehlschrank178').nil?, 'frei/keine/unbekannt -> kein Gerät')

ofen = G.berechne('geraet' => 'Backofen60', 'breite' => 562.0, 'hoehe' => 590.0, 'tiefe' => 800.0, 'x' => 19.0, 'y' => 19.0, 'z' => 0.0)
rahmen = ofen[:teile].find { |t| t[0] == 'Rahmen' }
check(nah(rahmen[3][0], 595) && nah(rahmen[3][2], 595), "Backofen-Front 595 × 595: #{rahmen[3]}")
check(nah(rahmen[2][1], -21) && nah(rahmen[2][0], -16.5), "Front mittig, 2 mm vor der Korpusfront bündig mit den Möbelfronten: #{rahmen[2]}")
check(ofen[:text] == 'Backofen 60 · Nische 562 × 590 mm', "Beschriftung: #{ofen[:text]}")
check(G.berechne('geraet' => 'frei', 'breite' => 562.0, 'hoehe' => 300.0).nil?, 'freie Nische bleibt leer')

%w[Geschirrspueler60 Geschirrspueler45 KochfeldAbzug60 KochfeldAbzug80 KochfeldAbzug90 Spuele
   Backofen60 Kompakt45 Mikrowelle38 Waermeschublade14].each do |k|
  r = G.berechne('geraet' => k, 'breite' => k.end_with?('45') ? 448.0 : 562.0, 'hoehe' => 590.0, 'tiefe' => 800.0,
                 'x' => 19.0, 'y' => 19.0, 'z' => 700.0)
  check(r && r[:teile].size >= 2, "#{k}: Teile")
  next unless r
  check(r[:teile].all? { |t| t[3].all?(&:positive?) }, "#{k}: alle Teile haben positive Maße #{r[:teile].reject { |t| t[3].all?(&:positive?) }}")
  check(r[:teile].all? { |t| G::MATERIALIEN.key?(t[1]) }, "#{k}: bekannte Materialien")
  check(r[:plan][3..].all?(&:positive?), "#{k}: Planblock")
end

# --- Mit den echten Schränken ---
model = Sketchup::Model.new
Sketchup.active_model = model
schrank = lambda do |defn|
  i = model.entities.add_instance(defn, Geom::Transformation.translation([0, 0, 0]))
  i
end
usg = schrank.(UnterschrankGeschirrspueler.erzeuge(model, {}))
usk = schrank.(UnterschrankKochfeld.erzeuge(model, {}))
usp = schrank.(Spuelenschrank.erzeuge(model, {}))
hg  = schrank.(HochschrankGeraete.erzeuge(model, {}))
hg1 = schrank.(HochschrankGeraete.erzeuge(model, { 'Geraet_N2' => HochschrankGeraete::KEINE.to_f }))

def geraete(inst) = inst.definition.entities.grep(Sketchup::ComponentInstance).select { |i| Geraete.geraet?(i) }

anzahl = G.in_schraenke_setzen(model)
check(anzahl == 6, "6 Geräte gesetzt (Spüler, Kochfeld, Spüle, 2 + 1 im Hochschrank): #{anzahl}")
erwartet = { usg => ['Geschirrspueler60'], usk => ['KochfeldAbzug80'], usp => ['Spuele'],
             hg => G.nischen(hg.definition).map { |n| n['geraet'] }, hg1 => [G.nischen(hg1.definition).first['geraet']] }
erwartet.each do |s, soll|
  ist = geraete(s).map { |g| g.definition.get_attribute(G::GERAET_DICT, 'geraet') }
  check(ist == soll, "#{s.definition.name}: #{ist.inspect} statt #{soll.inspect}")
end
check(G.nischen(hg1.definition).size == 1, 'Hochschrank ohne Nische 2 hat nur JT_Nische_N1')

# Einfügepunkt = x/y/z der Nische
[usg, usk, hg].each do |s|
  G.nischen(s.definition).zip(geraete(s)).each do |n, g|
    soll = %w[x y z].map { |k| n[k].to_f / 25.4 }
    check(g.transformation.origin.zip(soll).all? { |a, b| nah(a, b) }, "#{s.definition.name} #{n['nische']}: Lage #{g.transformation.origin}")
    check(g.name == "Geraet_#{n['nische']}", "Name #{g.name}")
  end
end
sp = G.nischen(usp.definition).first
check(nah(sp['breite'], 800 - 2 * 19) && nah(sp['z'], 700), "Spülenschrank-Nische aus den Schrankmaßen: #{sp}")

# Keine Schrankteile: kein JT_Schrank, kein OCL-Material, Tags Plan/Render
alle = lambda do |inst, out = []|
  out << inst
  inst.definition.entities.grep(Sketchup::ComponentInstance).each { |c| alle.(c, out) }
  out
end
erwartet.each_key do |s|
  geraete(s).each do |g|
    teile = alle.(g)
    check(teile.none? { |t| t.get_attribute(G::JT_DICT, 'teil') || t.definition.get_attribute(G::JT_DICT, 'schrank') },
          "#{g.definition.name}: kein JT_Schrank")
    check(teile.map(&:material).compact.none? { |m| m.attribute_dictionary('ladb_opencutlist') }, "#{g.definition.name}: kein OCL-Material")
    kinder = g.definition.entities.grep(Sketchup::ComponentInstance)
    check(kinder.map { |k| k.layer&.name }.sort == [G::TAG_PLAN, G::TAG_RENDER], "#{g.definition.name}: Tags #{kinder.map { |k| k.layer&.name }}")
    check(g.layer.nil?, "#{g.definition.name}: Gerät selbst ohne Tag")
    plan = kinder.find { |k| k.name == 'Plan' }
    check(plan.material.alpha < 1, "#{g.definition.name}: Planblock halbtransparent")
    check(plan.definition.entities.texte.first&.first&.include?('Nische'), "#{g.definition.name}: Beschriftung")
  end
  platzhalter = s.definition.entities.grep(Sketchup::ComponentInstance).reject { |i| G.geraet?(i) }
                 .select { |i| i.layer&.name == G::TAG_PLAN }
  check(platzhalter.all?(&:hidden), "#{s.definition.name}: alte Platzhalter ausgeblendet")
end
check(model.materials['Melamin weiss'].get_attribute('ladb_opencutlist', 'type') == 2, 'Schrankmaterial unverändert')

# TCN-Export findet dieselben Schrankteile wie vorher, kein Geräteteil
teile = JTools::SchrankCnc::Schraenke.teile(model)
check(teile.any? && teile.none? { |t| t.pfad.any? { |i| G.geraet?(i) } }, "TCN-Export übergeht die Geräte (#{teile.size} Teile)")

# Zweiter Lauf ersetzt die Geräte statt sie zu verdoppeln
G.in_schraenke_setzen(model)
check(erwartet.all? { |s, soll| geraete(s).size == soll.size }, 'zweiter Lauf ersetzt die Geräte')

# Nur Auswahl
model.selection.clear
model.selection.add(usg)
check(G.in_schraenke_setzen(model) == 1, 'mit Auswahl nur der gewählte Schrank')
model.selection.clear

# Szenen
G.szenen_anlegen(model)
{ 'Planung' => [true, false], 'Kunde' => [false, true], 'Zuschnitt' => [false, false] }.each do |n, (p, r)|
  s = model.pages[n]
  check(s && s.sichtbar[G::TAG_PLAN] == p && s.sichtbar[G::TAG_RENDER] == r, "Szene #{n}: #{s&.sichtbar}")
  check(s.sichtbar.all? { |k, v| [G::TAG_PLAN, G::TAG_RENDER].include?(k) || v }, "Szene #{n}: Schrank-Tags sichtbar")
end
G.szenen_anlegen(model)
check(model.pages.size == 3, 'Szenen werden beim zweiten Mal aktualisiert, nicht verdoppelt')

# Ohne Schränke: Hinweis, nichts passiert
leer = Sketchup::Model.new
check(G.in_schraenke_setzen(leer) == 0 && $meldungen.last.include?('Keine Schränke'), 'Hinweis ohne Schränke')

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
