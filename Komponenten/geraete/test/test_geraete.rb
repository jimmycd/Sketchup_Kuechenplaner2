# Test ohne SketchUp: Geräte aus den Nischen der echten Schrank-Generatoren
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
komp = File.expand_path('../..', __dir__)
$VERBOSE = nil
%w[unterschrank_geschirrspueler unterschrank_kuehlschrank unterschrank_kochfeld unterschrank_spuele hochschrank_geraete unterschrank_backofen oberschrank_dunstabzug hochschrank_kuehlschrank].each do |k|
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
kf = G.berechne('geraet' => 'Kochfeld60', 'breite' => 562.0, 'hoehe' => 0.0, 'tiefe' => 520.0, 'x' => 19.0, 'y' => 19.0, 'z' => 700.0, 'arbeitsplatte' => 40.0)
glas = kf[:teile].find { |t| t[0] == 'Kochfeld' }
check(nah(glas[2][2], 40) && nah(glas[3][0], 590) && nah(glas[2][0], -14), "Kochfeld 60 ohne Abzug: 590 breit mittig auf der Arbeitsplatte: #{glas}")
check(kf[:teile].none? { |t| t[0] == 'Abzug' } && kf[:text] == 'Kochfeld 60 · Nische 562 mm', "Kochfeld ohne Abzug: #{kf[:text]}")
check(G.art('frei').nil? && G.art('keine').nil? && G.art('Toaster12').nil?, 'frei/keine/unbekannt -> kein Gerät')

ofen = G.berechne('geraet' => 'Backofen60', 'breite' => 562.0, 'hoehe' => 590.0, 'tiefe' => 800.0, 'x' => 19.0, 'y' => 19.0, 'z' => 0.0)
rahmen = ofen[:teile].find { |t| t[0] == 'Rahmen' }
check(nah(rahmen[3][0], 595) && nah(rahmen[3][2], 595), "Backofen-Front 595 × 595: #{rahmen[3]}")
check(nah(rahmen[2][1], -21) && nah(rahmen[2][0], -16.5), "Front mittig, 2 mm vor der Korpusfront bündig mit den Möbelfronten: #{rahmen[2]}")
check(ofen[:text] == 'Backofen 60 · Nische 562 × 590 mm', "Beschriftung: #{ofen[:text]}")
check(G.berechne('geraet' => 'frei', 'breite' => 562.0, 'hoehe' => 300.0).nil?, 'freie Nische bleibt leer')

%w[Geschirrspueler60 Geschirrspueler45 KochfeldAbzug60 KochfeldAbzug80 KochfeldAbzug90 Kochfeld60 Kochfeld80 Spuele
   Backofen60 Kompakt45 Mikrowelle38 Waermeschublade14 Flachschirmhaube60 Flachschirmhaube90 Kuehlschrank60 KuehlschrankFrei60 Weinkuehler30 Weinkuehler60 Kuehlgeraet178].each do |k|
  r = G.berechne('geraet' => k, 'breite' => k.end_with?('45') ? 448.0 : 562.0, 'hoehe' => 590.0, 'tiefe' => 800.0,
                 'x' => 19.0, 'y' => 19.0, 'z' => 700.0)
  check(r && r[:teile].size >= 2, "#{k}: Teile")
  next unless r
  check(r[:teile].all? { |t| t[3].all?(&:positive?) }, "#{k}: alle Teile haben positive Maße #{r[:teile].reject { |t| t[3].all?(&:positive?) }}")
  check(r[:teile].all? { |t| G::MATERIALIEN.key?(t[1]) }, "#{k}: bekannte Materialien")
  if k == 'Spuele'
    check(r[:plan].nil? && r[:text_pos], "#{k}: kein Planblock (kein Kasten um die Spüle), Beschriftung am Modell")
  else
    check(r[:plan][3..].all?(&:positive?), "#{k}: Planblock")
  end
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
usb = schrank.(UnterschrankBackofen.erzeuge(model, {}))
hk  = schrank.(HochschrankKuehlschrank.erzeuge(model, {}))

def geraete(inst) = inst.definition.entities.grep(Sketchup::ComponentInstance).select { |i| Geraete.geraet?(i) }

anzahl = G.in_schraenke_setzen(model)
check(anzahl == 12, "12 Geräte gesetzt (Spüler, 2 Kühlgeräte, Kochfeld, Spüle, 2 + 1 im Hochschrank, Kochfeld + Backofen im Herdumbau, Haube, Hochschrank Kühlschrank): #{anzahl}")
erwartet = { usg => ['Geschirrspueler60'], uks => ['Kuehlschrank60'], ukw => ['Weinkuehler30'], usk => ['KochfeldAbzug80'], usp => ['Spuele'],
             hg => G.nischen(hg.definition).map { |n| n['geraet'] }, hg1 => [G.nischen(hg1.definition).first['geraet']],
             usb => %w[Kochfeld60 Backofen60], osd => ['Flachschirmhaube90'], hk => ['Kuehlgeraet178'] }
erwartet.each do |s, soll|
  ist = geraete(s).map { |g| g.definition.get_attribute(G::GERAET_DICT, 'geraet') }
  check(ist == soll, "#{s.definition.name}: #{ist.inspect} statt #{soll.inspect}")
end
check(G.nischen(hg1.definition).size == 1, 'Hochschrank ohne Nische 2 hat nur JT_Nische_N1')

# Einfügepunkt = x/y/z der Nische
[usg, uks, ukw, usk, hg, usb, osd, hk].each do |s|
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
    render = kinder.find { |k| k.name == 'Render' }
    check(plan.definition.entities.grep(Sketchup::ComponentInstance).map(&:definition) == [render.definition] &&
          plan.definition.box.nil?, "#{g.definition.name}: Planung zeigt das Gerätemodell, keinen Kasten (sonst wirkt die Nische leer)")
    check(plan.definition.entities.texte.first&.first&.include?('Nische'), "#{g.definition.name}: Beschriftung")
    check(plan.definition.entities.texte.all? { |t| t.layer&.name == G::TAG_BESCHRIFTUNG }, "#{g.definition.name}: Beschriftung auf Tag Beschriftung (Schalter Symbolleiste)")
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

# --- Geräte entfernen ---
platzhalter = lambda do |s|
  s.definition.entities.grep(Sketchup::ComponentInstance).reject { |i| G.geraet?(i) }.select { |i| i.layer&.name == G::TAG_PLAN }
end
teile_vorher = JTools::SchrankCnc::Schraenke.teile(model).size
nischen_vorher = erwartet.keys.to_h { |s| [s, G.nischen(s.definition)] }
# einzeln: ein Gerät im geöffneten Hochschrank gewählt
model.selection.add(geraete(hg).first)
check(G.entfernen(model) == 1 && geraete(hg).size == 1, "einzelnes Gerät entfernt (#{geraete(hg).size} übrig)")
check(platzhalter.(hg).all?(&:hidden), 'Platzhalter bleiben aus, solange noch ein Gerät im Schrank steckt')
model.selection.clear
model.selection.add(geraete(hg).first)
check(G.entfernen(model) == 1 && geraete(hg).empty?, 'zweites Gerät entfernt')
check(platzhalter.(hg).any? && platzhalter.(hg).none?(&:hidden), 'letztes Gerät weg: Platzhalter wieder sichtbar')
model.selection.clear
# gewählter Schrank
model.selection.add(usb)
check(G.entfernen(model) == 2 && geraete(usb).empty? && geraete(usp).size == 1, 'mit Auswahl nur der gewählte Schrank (Kochfeld + Backofen)')
model.selection.clear
# ohne Auswahl: alle
rest = erwartet.keys.sum { |s| geraete(s).size }
check(G.entfernen(model) == rest && erwartet.keys.all? { |s| geraete(s).empty? }, "ohne Auswahl alle Geräte entfernt (#{rest})")
check(usg.definition.entities.grep(Sketchup::ComponentInstance).any? && platzhalter.(usg).none?(&:hidden), 'Spüler: Platzhalter wieder sichtbar')
check(erwartet.keys.all? { |s| G.nischen(s.definition) == nischen_vorher[s] }, 'Nischen bleiben erhalten')
check(JTools::SchrankCnc::Schraenke.teile(model).size == teile_vorher, 'TCN-Export: Schrankteile unverändert')
check(G.entfernen(model).zero? && $meldungen.last.include?('Keine eingesetzten Geräte'), 'Hinweis, wenn nichts zu entfernen ist')
check(G.in_schraenke_setzen(model) == anzahl && platzhalter.(usg).all?(&:hidden), 'danach wieder einsetzbar')

# Szenen (mit Raum: dessen Tags nur in Planung und Kunde sichtbar)
%w[Raum-Wand Raum-Fenster].each { |t| model.layers.add(t) }
G.szenen_anlegen(model)
{ 'Planung' => [true, false], 'Kunde' => [false, true], 'Zuschnitt' => [false, false] }.each do |n, (p, r)|
  s = model.pages[n]
  check(s && s.sichtbar[G::TAG_PLAN] == p && s.sichtbar[G::TAG_RENDER] == r, "Szene #{n}: #{s&.sichtbar}")
  check(s.sichtbar.all? { |k, v| [G::TAG_PLAN, G::TAG_RENDER, G::TAG_BESCHRIFTUNG].include?(k) || k.start_with?('Raum-') || v }, "Szene #{n}: Schrank-Tags sichtbar")
  check(s.sichtbar['Raum-Wand'] == (n != 'Zuschnitt') && s.sichtbar['Raum-Fenster'] == (n != 'Zuschnitt'), "Szene #{n}: Raum-Tags")
end
G.szenen_anlegen(model)
check(model.pages.size == 3, 'Szenen werden beim zweiten Mal aktualisiert, nicht verdoppelt')

# Kundensicht: Szene Kunde mit eigenem Stil, Schatten und Perspektive; Planung/Zuschnitt unverändert
K = G::Kundensicht
kunde, planung, zuschnitt = model.pages['Kunde'], model.pages['Planung'], model.pages['Zuschnitt']
ro = kunde.rendering_options
check(ro['Texture'] == true && ro['DrawSilhouettes'] == false && ro['DrawProfilesOnly'] == false &&
      ro['DisplayText'] == false && ro['DisplayDims'] == false && ro['DrawGround'] == true && ro['DrawHorizon'] == true,
      "Kunde: Stil (Texturen, keine Profile, kein Text, Himmel/Boden): #{ro.to_h}")
check(ro['BackgroundColor'].rgb == K.stil['BackgroundColor'] && ro['ForegroundColor'].rgb == K.stil['ForegroundColor'], 'Kunde: Hintergrund und dezente Kantenfarbe')
check(kunde.shadow_info['DisplayShadows'] == true && kunde.shadow_info['ShadowTime'].month == 6, 'Kunde: Schatten an, Sommersonne')
check(kunde.camera.perspective? && kunde.camera.fov == K.fov, 'Kunde: Perspektive')
check(kunde.use_rendering_options && kunde.use_shadow_info && kunde.use_camera, 'Kunde: Szene speichert Stil, Schatten, Kamera')
[planung, zuschnitt].each do |s|
  check(s.shadow_info['DisplayShadows'] == false && s.rendering_options['DrawSilhouettes'] == true &&
        s.rendering_options['DisplayText'] == true, "#{s.name}: erbt den Kundenstil nicht")
end
check(model.shadow_info['DisplayShadows'] == false && model.rendering_options['DisplayText'] == true, 'laufende Ansicht wieder wie vorher')
check(model.pages.selected_page == planung, 'danach Szene Planung gewählt')

# erneut anlegen, während Kunde gewählt ist: Kamera der Szene Kunde bleibt, keine Duplikate
model.pages.selected_page = kunde
K.setzen(model.rendering_options, K.stil)
K.setzen(model.shadow_info, K.schatten)
auge = kunde.camera.eye
model.active_view.camera = Sketchup::Camera.new([999, 999, 999], [0, 0, 0], [0, 0, 1], false)
G.szenen_anlegen(model)
check(model.pages.size == 3, 'Kundensicht: keine zweite Kunden-Szene')
check(model.pages['Kunde'].camera.eye == auge && model.pages['Kunde'].camera.perspective?, 'Kunde: gespeicherte Kamera bleibt')
check(model.shadow_info['DisplayShadows'] == false && model.rendering_options['DisplayText'] == true, 'aus Kunde heraus angelegt: Ansicht wieder im Planungsstil')

# Kundenbild speichern: wechselt ohne Überblendung in die Szene Kunde, PNG in gewählter Auflösung
pfad = K.bild_speichern(model, '/tmp/kueche_kunde', K.aufloesungen['4K 3840 × 2160'])
bild = model.active_view.bilder.last
check(pfad == '/tmp/kueche_kunde.png' && bild[:filename] == pfad && bild[:width] == 3840 && bild[:height] == 2160 && bild[:antialias],
      "Kundenbild: 4K-PNG (#{bild})")
check(model.pages.selected_page.name == 'Kunde' && model.active_view.camera.eye == auge, 'Kundenbild: aus Szene Kunde')
check(model.options['PageOptions']['ShowTransition'] == true, 'Kundenbild: Überblendung wieder wie vorher')
K.bild_speichern(model, '/tmp/fenster.PNG', nil, false)
check(!model.active_view.bilder.last.key?(:width) && model.active_view.bilder.last[:filename] == '/tmp/fenster.PNG', 'Kundenbild: Fenstergröße')
neu_model = Sketchup::Model.new
K.bild_speichern(neu_model, '/tmp/neu', [1920, 1080])
check(neu_model.pages.size == 3 && neu_model.pages.selected_page.name == 'Kunde', 'Kundenbild ohne Szenen: Szenen werden angelegt')

# Schrank-Beschriftung (Tag Beschriftung): in Planung/Zuschnitt nur, wenn eingeschaltet; in Kunde nie
model.layers.add(G::TAG_BESCHRIFTUNG)
[false, true].each do |an|
  model.set_attribute(G::BESCHRIFTUNG, 'an', an)
  G.szenen_anlegen(model)
  { 'Planung' => an, 'Kunde' => false, 'Zuschnitt' => an }.each do |n, soll|
    check(model.pages[n].sichtbar[G::TAG_BESCHRIFTUNG] == soll, "Beschriftung #{an ? 'ein' : 'aus'}: Szene #{n} zeigt sie #{soll ? '' : 'nicht'}")
  end
end

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

# --- Spüle und Kochfeld sitzen im Ausschnitt der Arbeitsplatte ---
# Ohne Arbeitsplatte im Modell: Richtwerte, gerechnet wie die Arbeitsplatte selbst (Front des Schranks bei y = -Spalt)
%w[erkennung ausschnitte layout].each { |f| load File.join(komp, 'arbeitsplatte', 'src', 'arbeitsplatte', "#{f}.rb") }
ap_o = Arbeitsplatte::Layout::OPTIONEN
check(nah(G::AP_UEBERSTAND, ap_o[:ueberstand_vorn]) && nah(G::AUSSCHNITT_SPUELE[:abstand_vorn], ap_o[:spuele_abstand_vorn]) &&
      nah(G::AUSSCHNITT_SPUELE[:tiefe], ap_o[:spuele_tiefe]) && nah(G::AUSSCHNITT_SPUELE[:max], ap_o[:spuele_max]) &&
      nah(G::AUSSCHNITT_SPUELE[:rand], ap_o[:spuele_rand]) && nah(G::AUSSCHNITT_KOCHFELD[:abstand_vorn], ap_o[:kochfeld_abstand_vorn]) &&
      G::AUSSCHNITT_KOCHFELD[:breiten] == Arbeitsplatte::Ausschnitte::KOCHFELD.transform_values(&:first) &&
      nah(G::ARBEITSPLATTE, Arbeitsplatte::Layout::STAERKE[:schichtstoff]), 'Richtwerte gleich wie in der Arbeitsplatte')
ap_rechteck = lambda do |typ, breite|
  z = { nr: 1, front: :ny, achse: 0, front_linie: -2.0, elemente: [{ kz: 'X1', typ: typ, s0: 0.0, s1: breite }] }
  Arbeitsplatte::Ausschnitte.fuer_zeile(z, ap_o.merge(ausschnitte: {})).first[:rechteck]
end
[[usp, 'Spuelenschrank', :spuele, 800.0], [usk, 'Unterschrank_Kochfeld', :kochfeld, 800.0], [usb, 'Unterschrank_Backofen', :kochfeld, 600.0]].each do |s, typ, art, breite|
  n = G.nischen(s.definition, s).find { |x| x['z'].to_f > 600 }
  welt = ap_rechteck.(typ, breite)
  soll = [welt[0] - n['x'], welt[1] - n['y'], welt[2] - n['x'], welt[3] - n['y']]
  ist = G.ausschnitt(n, art)
  check(ist.zip(soll).all? { |a, b| nah(a, b) }, "#{typ}: Ausschnitt #{ist} wie Arbeitsplatte #{soll}")
end
teil_von = ->(r, name) { r[:teile].find { |t| t[0] == name } }
sp_n = G.nischen(usp.definition, usp).first
ax0, ay0, ax1, ay1 = G.ausschnitt(sp_n, :spuele)
r = G.berechne(sp_n)
rv, rh, rl, rr, boden = %w[RandVorn RandHinten RandL RandR Beckenboden].map { |k| teil_von.(r, k) }
check(nah(rv[2][0], ax0 - 10) && nah(rv[2][1], ay0 - 10) && nah(rv[2][0] + rv[3][0], ax1 + 10) &&
      nah(rh[2][1] + rh[3][1], ay1 + 10), "Spülenrand liegt rundum 10 mm auf der Platte: #{rv} #{rh}")
check(boden[2][0] > ax0 && boden[2][1] > ay0 && boden[2][0] + boden[3][0] < ax1 && boden[2][1] + boden[3][1] < ay1,
      "Becken hängt im Ausschnitt: #{boden}")
check(nah(rv[2][2], 38), "Spülenrand auf der Schichtstoffplatte (38 mm): #{rv[2]}")
check(nah(ay0 + 19, 38) && nah(ax1 - ax0, 700), "Spülenausschnitt 60 mm hinter der Plattenvorderkante (Korpus y 38), 700 breit: #{[ax0, ay0, ax1, ay1]}")
kf_n = G.nischen(usk.definition, usk).first
k0, k1, k2, k3 = G.ausschnitt(kf_n, :kochfeld)
glas = teil_von.(G.berechne(kf_n), 'Kochfeld')
check(nah(glas[2][0] + glas[3][0] / 2, (k0 + k2) / 2) && nah(glas[2][1] + glas[3][1] / 2, (k1 + k3) / 2) &&
      glas[2][0] < k0 && glas[2][1] < k1 && glas[2][0] + glas[3][0] > k2 && glas[2][1] + glas[3][1] > k3,
      "Kochfeld mittig über dem Ausschnitt und deckt ihn: #{glas} / #{[k0, k1, k2, k3]}")

# Mit Arbeitsplatte im Modell: deren Ausschnitt gilt (hier absichtlich anders als die Richtwerte)
m2 = Sketchup::Model.new
Sketchup.active_model = m2
usp2 = m2.entities.add_instance(Spuelenschrank.erzeuge(m2, {}), Geom::Transformation.translation([1000 / 25.4, 500 / 25.4, 0]))
kz2 = usp2.definition.get_attribute(G::JT_DICT, 'schrank')
apd = m2.definitions.add('Arbeitsplatte APL1')
apd.set_attribute(G::JT_DICT, 'typ', 'Arbeitsplatte')
platte = apd.entities.add_instance(m2.definitions.add('APL1_Platte1'), Geom::Transformation.translation([0, 0, 700 / 25.4]))
platte.set_attribute(G::AP_DICT, 'staerke', 40.0)
platte.set_attribute(G::AP_DICT, 'ausschnitte', JSON.generate([{ 'schrank' => 'ANDERS', 'rechteck' => [0, 0, 1, 1] },
                                                               { 'schrank' => kz2, 'rechteck' => [1070.0, 545.0, 1730.0, 1025.0] }]))
m2.entities.add_instance(apd, Geom::Transformation.translation([0, 0, 0]))
nn = G.nischen(usp2.definition, usp2).first
aus = G.ausschnitt_aus_modell(m2, usp2, nn, kz2)
check(aus['ausschnitt'] == [70.0 - 19, 45.0 - 19, 730.0 - 19, 525.0 - 19] && nah(aus['arbeitsplatte'], 40), "Ausschnitt aus dem Modell: #{aus}")
check(G.ausschnitt_aus_modell(m2, usp2, nn, 'FREMD') == {}, 'anderer Schrank: kein Ausschnitt')
G.einsetzen(m2, usp2)
rd2 = geraete(usp2).first.definition.entities.grep(Sketchup::ComponentInstance).find { |k| k.name == 'Render' }.definition
rv2 = rd2.entities.grep(Sketchup::ComponentInstance).find { |k| k.name == 'RandVorn' }
check(rv2.transformation.origin.map { |v| (v * 25.4).round(3) } == [41.0, 16.0, 40.0], "Spüle im Ausschnitt der Arbeitsplatte: #{rv2.transformation.origin.map { |v| v * 25.4 }}")
# gedrehter Schrank: Welt -> Schrank zurückrechnen
dreh = [0, 1, 0, 0, -1, 0, 0, 0, 0, 0, 1, 0, 10, 20, 0, 1].map(&:to_f) # 90° um z, verschoben
check(G.lokal(dreh, G.punkt(dreh, [3.0, 4.0, 5.0])).zip([3, 4, 5]).all? { |a, b| nah(a, b) }, 'Welt -> Schrank bei gedrehtem Schrank')
# Arbeitsplatte neu erzeugt: vorhandene Spüle wird neu ausgerichtet
platte.set_attribute(G::AP_DICT, 'ausschnitte', JSON.generate([{ 'schrank' => kz2, 'rechteck' => [1080.0, 545.0, 1720.0, 1025.0] }]))
check(G.an_arbeitsplatte_ausrichten(m2) == 1, 'Arbeitsplatte neu: Schrank mit Spüle ausgerichtet')
rd3 = geraete(usp2).first.definition.entities.grep(Sketchup::ComponentInstance).find { |k| k.name == 'Render' }.definition
check(nah(rd3.entities.grep(Sketchup::ComponentInstance).find { |k| k.name == 'RandVorn' }.transformation.origin[0] * 25.4, 51.0),
      'Spüle folgt dem neuen Ausschnitt')

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
