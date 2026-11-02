# Test ohne SketchUp: Geräte aus den Nischen der echten Schrank-Generatoren
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
komp = File.expand_path('../..', __dir__)
$VERBOSE = nil
%w[unterschrank_geschirrspueler unterschrank_kuehlschrank unterschrank_kochfeld unterschrank_spuele hochschrank_geraete oberschrank_dunstabzug].each do |k|
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
check(G.art('KuehlschrankFrei60') == ['KuehlschrankFrei', 60] && G.art('Weinkuehler30') == ['Weinkuehler', 30], 'Kühlgeräte lesen')
check(G.art('Backofen60') == ['Backofen', 60] && G.art('Spuele') == ['Spuele', nil], 'Kennungen lesen')
check(G.art('frei').nil? && G.art('keine').nil? && G.art('Toaster12').nil?, 'frei/keine/unbekannt -> kein Gerät')

ofen = G.berechne('geraet' => 'Backofen60', 'breite' => 562.0, 'hoehe' => 590.0, 'tiefe' => 800.0, 'x' => 19.0, 'y' => 19.0, 'z' => 0.0)
rahmen = ofen[:teile].find { |t| t[0] == 'Rahmen' }
check(nah(rahmen[3][0], 595) && nah(rahmen[3][2], 595), "Backofen-Front 595 × 595: #{rahmen[3]}")
check(nah(rahmen[2][1], -21) && nah(rahmen[2][0], -16.5), "Front mittig, 2 mm vor der Korpusfront bündig mit den Möbelfronten: #{rahmen[2]}")
check(ofen[:text] == 'Backofen 60 · Nische 562 × 590 mm', "Beschriftung: #{ofen[:text]}")
check(G.berechne('geraet' => 'frei', 'breite' => 562.0, 'hoehe' => 300.0).nil?, 'freie Nische bleibt leer')

%w[Geschirrspueler60 Geschirrspueler45 KochfeldAbzug60 KochfeldAbzug80 KochfeldAbzug90 Spuele
   Backofen60 Kompakt45 Mikrowelle38 Waermeschublade14 Flachschirmhaube60 Flachschirmhaube90 Kuehlschrank60 KuehlschrankFrei60 Weinkuehler30 Weinkuehler60].each do |k|
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
uks = schrank.(UnterschrankKuehlschrank.erzeuge(model, {}))
ukw = schrank.(UnterschrankKuehlschrank.erzeuge(model, { 'Geraet_Art' => 1.0, 'Breite' => 30.0, 'Art_Wange' => 1.0 }))
usk = schrank.(UnterschrankKochfeld.erzeuge(model, {}))
usp = schrank.(Spuelenschrank.erzeuge(model, {}))
hg  = schrank.(HochschrankGeraete.erzeuge(model, {}))
hg1 = schrank.(HochschrankGeraete.erzeuge(model, { 'Geraet_N2' => HochschrankGeraete::KEINE.to_f }))
osd = schrank.(OberschrankDunstabzug.erzeuge(model, { 'Breite' => 90.0 }))

def geraete(inst) = inst.definition.entities.grep(Sketchup::ComponentInstance).select { |i| Geraete.geraet?(i) }

anzahl = G.in_schraenke_setzen(model)
check(anzahl == 9, "9 Geräte gesetzt (Spüler, 2 Kühlgeräte, Kochfeld, Spüle, 2 + 1 im Hochschrank, Haube): #{anzahl}")
erwartet = { usg => ['Geschirrspueler60'], uks => ['Kuehlschrank60'], ukw => ['Weinkuehler30'], usk => ['KochfeldAbzug80'], usp => ['Spuele'],
             hg => G.nischen(hg.definition).map { |n| n['geraet'] }, hg1 => [G.nischen(hg1.definition).first['geraet']],
             osd => ['Flachschirmhaube90'] }
erwartet.each do |s, soll|
  ist = geraete(s).map { |g| g.definition.get_attribute(G::GERAET_DICT, 'geraet') }
  check(ist == soll, "#{s.definition.name}: #{ist.inspect} statt #{soll.inspect}")
end
check(G.nischen(hg1.definition).size == 1, 'Hochschrank ohne Nische 2 hat nur JT_Nische_N1')

# Einfügepunkt = x/y/z der Nische
[usg, uks, ukw, usk, hg, osd].each do |s|
  G.nischen(s.definition).zip(geraete(s)).each do |n, g|
    soll = %w[x y z].map { |k| n[k].to_f / 25.4 }
    check(g.transformation.origin.zip(soll).all? { |a, b| nah(a, b) }, "#{s.definition.name} #{n['nische']}: Lage #{g.transformation.origin}")
    check(g.name == "Geraet_#{n['nische']}", "Name #{g.name}")
  end
end
# Haube: unten bündig im Haubenraum (862 × 380), Rohr durch den Ausschnitt bis zur Oberkante (700)
rd = geraete(osd).first.definition.entities.grep(Sketchup::ComponentInstance).find { |k| k.name == 'Render' }.definition
rohr = rd.entities.grep(Sketchup::ComponentInstance).find { |k| k.name == 'Rohr' }
check(rohr && nah(rohr.transformation.origin[0] * 25.4, 346 + 10) && nah(rohr.transformation.origin[1] * 25.4, 177 + 10) &&
      nah((rohr.transformation.origin[2] + rohr.definition.box[2]) * 25.4, 700), "Haube: Rohr im Ausschnitt bis oben #{rohr&.transformation&.origin}")
hb = G.berechne(G.nischen(osd.definition).first.merge('abluft' => 0))
check(hb[:teile].none? { |t| t[0] == 'Rohr' } && hb[:teile].all? { |t| t[2][2] + t[3][2] <= 380 + EPS }, 'Umluft: kein Rohr, alles im Haubenraum')
# Haube: Breite, Haubenraum und Abluft in den Komponentenoptionen geändert (an der Instanz) -> Nische folgt
nd = G.nischen(osd.definition, osd).first
check(nd['geraet'] == 'Flachschirmhaube90' && nah(nd['breite'], 862) && nah(nd['hoehe'], 380) && nah(nd['rohr_y'], 177), "Haube Nische: #{nd}")
{ 'breite' => 60.0 / 2.54, 'haube_hoehe' => 30.0 / 2.54, 'abluft' => 0.0 }.each { |k, v| osd.set_attribute(G::DICT, k, v) }
nd = G.nischen(osd.definition, osd).first
check(nd['geraet'] == 'Flachschirmhaube60' && nah(nd['breite'], 562) && nah(nd['hoehe'], 300) && nd['abluft'] == 0, "Haube umgestellt: #{nd}")
G.einsetzen(model, osd)
check(geraete(osd).map { |g| g.definition.get_attribute(G::GERAET_DICT, 'geraet') } == ['Flachschirmhaube60'], 'Haube umgestellt: Gerät')
kw = G.nischen(ukw.definition).first
check(nah(kw['breite'], 296) && nah(kw['x'], 19) && nah(kw['z'], -100) && nah(kw['hoehe'], 800), "Weinkühler-Nische: #{kw}")

# Kühlschrank: Gerät und Breite in den Komponentenoptionen geändert (an der Instanz) -> neues Gerät
uks.set_attribute(G::DICT, 'geraet_art', 2.0)
uks.set_attribute(G::DICT, 'breite', 45.0 / 2.54)
uks.set_attribute(G::DICT, 'art_wange', 3.0)
n = G.nischen(uks.definition, uks).first
check(n['geraet'] == 'KuehlschrankFrei45' && nah(n['breite'], 446) && nah(n['x'], 19), "Kühlschrank umgestellt: #{n}")
G.einsetzen(model, uks)
check(geraete(uks).map { |g| g.definition.get_attribute(G::GERAET_DICT, 'geraet') } == ['KuehlschrankFrei45'], 'Kühlschrank umgestellt: Gerät')
{ 'geraet_art' => 0.0, 'breite' => 60.0 / 2.54, 'art_wange' => 0.0 }.each { |k, v| uks.set_attribute(G::DICT, k, v) }
G.einsetzen(model, uks)
check(geraete(uks).map { |g| g.definition.get_attribute(G::GERAET_DICT, 'geraet') } == ['Kuehlschrank60'], 'Kühlschrank zurückgestellt')
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

# Szenen (mit Raum: dessen Tags nur in Planung und Kunde sichtbar)
%w[Raum-Wand Raum-Fenster].each { |t| model.layers.add(t) }
G.szenen_anlegen(model)
{ 'Planung' => [true, false], 'Kunde' => [false, true], 'Zuschnitt' => [false, false] }.each do |n, (p, r)|
  s = model.pages[n]
  check(s && s.sichtbar[G::TAG_PLAN] == p && s.sichtbar[G::TAG_RENDER] == r, "Szene #{n}: #{s&.sichtbar}")
  check(s.sichtbar.all? { |k, v| [G::TAG_PLAN, G::TAG_RENDER].include?(k) || k.start_with?('Raum-') || v }, "Szene #{n}: Schrank-Tags sichtbar")
  check(s.sichtbar['Raum-Wand'] == (n != 'Zuschnitt') && s.sichtbar['Raum-Fenster'] == (n != 'Zuschnitt'), "Szene #{n}: Raum-Tags")
end
G.szenen_anlegen(model)
check(model.pages.size == 3, 'Szenen werden beim zweiten Mal aktualisiert, nicht verdoppelt')

# Ohne Schränke: Hinweis, nichts passiert
leer = Sketchup::Model.new
check(G.in_schraenke_setzen(leer) == 0 && $meldungen.last.include?('Keine Schränke'), 'Hinweis ohne Schränke')


# --- Tiefe nachträglich geändert (Komponentenoptionen schreiben an die Instanz) ---
[usg, usk, usp, hg].each do |i|
  alt = G.nischen(i.definition).map { |n| n['tiefe'] }
  i.set_attribute(G::DICT, 'tiefe', 52.0 / 2.54)
  neu = G.nischen(i.definition, i).map { |n| n['tiefe'] }
  check(alt.all? { |t| t > 520 } && neu.all? { |t| nah(t, 520.0) }, "#{i.definition.name}: Nische mit aktueller Tiefe 520 statt #{alt} (#{neu})")
end

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
