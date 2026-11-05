# Test ohne SketchUp: Material-Konfigurator (Materialien, Fenster „Materialien…“,
# Korpusmaterial ändern, Maserrichtung) an echten Schränken aus Komponenten/.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
require_relative '../../test/eingabe_helfer'
komp = File.expand_path('../../Komponenten', __dir__)
load File.join(komp, 'oberschrank/src/oberschrank/main.rb')
load File.join(komp, 'unterschrank_schubladen/src/unterschrank_schubladen/main.rb')

# HtmlDialog-Attrappe (wie in test/test_eingabe.rb)
module UI
  class HtmlDialog
    STYLE_DIALOG = 0
    attr_reader :html, :callbacks, :optionen
    def initialize(opt) = (@optionen, @callbacks = opt, {})
    def set_html(h) = @html = h
    def add_action_callback(n, &blk) = @callbacks[n] = blk
    def center = nil
    def show = @offen = true
    def visible? = @offen
    def close = @offen = false
    def execute_script(js) = (@skripte ||= []) << js
    def skripte = @skripte || []
  end
  class << self
    attr_accessor :meldungen, :antwort_messagebox
    def messagebox(m, *_) = ((self.meldungen ||= []) << m) && (antwort_messagebox || IDOK)
  end
end
load File.expand_path('../src/jt_schrank_cnc/main.rb', __dir__)

S = JTools::SchrankCnc
M = S::Materialien
D = S::Materialdialog
K = S::Korpusmaterial
E = Kuechenplaner::Eingabe
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

def letzter_dialog = E.dialog
def ok(aendern = {}) = EingabeHelfer.ok(E.dialog, aendern)

model = Sketchup.active_model = Sketchup::Model.new
Sketchup.defaults.clear
os1 = Oberschrank.erstellen({})
os2 = model.entities.add_instance(os1.definition, Geom::Transformation.translation([100, 0, 0])) # Kopie
uss = UnterschrankSchubladen.erstellen({ 'Breite' => 90.0, 'Anz_Schubladen' => 3, 'Anteil_1' => 1.0, 'Anteil_2' => 1.0, 'Anteil_3' => 1.0 })
mel = model.materials['Melamin weiss']

# --- Lesen: Materialien der Komponenten (OCL-Format) ---
check(M.platte?(mel) && M.staerke(mel) == 8.0 && M.plattenformat(mel) == [2800.0, 2070.0] && !M.maserung?(mel),
      "Melamin weiss lesen: #{M.staerke(mel)} #{M.plattenformat(mel)}")
check(M.verwendung(mel) == 'Korpus', 'Verwendung ohne Angabe: Korpus')
ka = model.materials['Anleimer Melamin weiss']
check(M.kante?(ka) && M.kantendicke(ka) == 2.0, 'Anleimer der Komponenten: Kante 2 mm')
check(M.mm('1,9 cm') == 19.0 && M.mm('19mm') == 19.0 && M.mm('2 mm') == 2.0, 'mm lesen')

# --- Farbe ---
check(M.farbe('#ff8000').rgb == [255, 128, 0] && M.farbe('10, 20,30').rgb == [10, 20, 30] && M.farbe('').nil?, 'Farbe lesen')
begin
  M.farbe('blau')
  check(false, 'ungültige Farbe muss Fehler geben')
rescue ArgumentError => e
  check(e.message.include?('nicht lesbar'), 'Fehlertext Farbe')
end

# --- Neue Platte und Kante über das Fenster ---
liste = D.dialog(model)
check(liste.html.include?('Melamin weiss') && liste.html.include?('Anleimer Melamin weiss'), 'Liste zeigt Materialien des Modells')
check(!liste.html.include?('UI.inputbox'), 'kein UI.inputbox')
liste.callbacks['neu'].call(nil, 'kante')
felder = EingabeHelfer.felder(letzter_dialog.html).to_h
check(felder['Dicke'] == '2' && felder['Breite'] == '23', "Vorgaben Kante: #{felder}")
ok('Name' => 'Anleimer Eiche', 'Farbe' => '#A0784B', 'Dicke' => '1,5')
eiche_k = model.materials['Anleimer Eiche']
check(M.kante?(eiche_k) && M.kantendicke(eiche_k) == 1.5 && eiche_k.get_attribute('ladb_opencutlist', 'edge_decremented') == true,
      'Kante angelegt (1,5 mm, wird abgezogen)')
check(liste.html.include?('Anleimer Eiche'), 'Liste nach dem Speichern aktualisiert')

liste.callbacks['neu'].call(nil, 'platte')
felder = EingabeHelfer.felder(letzter_dialog.html).to_h
check(felder['Stärke'] == '19' && felder['Format Länge'] == '2800' && felder['Verwendung'] == 'Korpus', "Vorgaben Platte: #{felder}")
ok('Name' => 'Front Eiche 19mm', 'Verwendung' => 'Front', 'Farbe' => '#B08850', 'Maserung' => 'Ja',
   'Anleimer' => 'Anleimer Eiche', 'Format Länge' => '2070', 'Format Breite' => '2800')
eiche = model.materials['Front Eiche 19mm']
check(M.platte?(eiche) && M.verwendung(eiche) == 'Front' && M.maserung?(eiche) && M.staerke(eiche) == 19.0,
      'Platte angelegt: Front, Maserung, 19 mm')
check(M.plattenformat(eiche) == [2800.0, 2070.0], 'Format: Länge ist die längere Seite')
check(M.kante_zu(model, eiche).equal?(eiche_k) && M.anleimer(model, eiche).equal?(eiche_k), 'Anleimer zugeordnet')
check(S::Frontfarbe.frontmaterialien(model) == [eiche], 'Frontfarbe sieht das neue Frontmaterial')

# ungültige Eingabe: Fenster bleibt offen, Meldung
liste.callbacks['neu'].call(nil, 'platte')
ok('Name' => 'Test', 'Stärke' => 'abc')
check(letzter_dialog.visible? && letzter_dialog.skripte.last.to_s.include?('keine Zahl') && model.materials['Test'].nil?,
      'ungültige Stärke: Fenster bleibt offen')
ok('Name' => 'Melamin weiss', 'Stärke' => '19')
check(letzter_dialog.skripte.last.to_s.include?('gibt es schon'), 'doppelter Name abgelehnt')
letzter_dialog.close

# --- Bibliothek: steht in einem neuen Modell bereit ---
check(M.in_bibliothek?('Front Eiche 19mm') && M.in_bibliothek?('Anleimer Eiche'), 'in der Bibliothek gespeichert')
m2 = Sketchup::Model.new
check(M.plattennamen(m2, 'Front') == ['Front Eiche 19mm'], 'neues Modell: Bibliotheksmaterial in der Auswahl')
check(D.zeilen(m2).any? { |e| e['name'] == 'Front Eiche 19mm' && e['ort'] == 'Bibliothek' }, 'Liste: nur in der Bibliothek')
e2 = M.holen(m2, 'Front Eiche 19mm')
check(e2 && M.maserung?(e2) && M.verwendung(e2) == 'Front' && M.kante_zu(m2, e2)&.name == 'Anleimer Eiche' &&
      M.kantendicke(m2.materials['Anleimer Eiche']) == 1.5, 'holen: Platte mit Anleimer ins Modell übernommen')

# --- Bearbeiten: Kante umbenennen, Zuordnung folgt ---
liste.callbacks['bearbeiten'].call(nil, 'Anleimer Eiche')
check(EingabeHelfer.felder(letzter_dialog.html).to_h['Dicke'] == '1,5', 'Bearbeiten zeigt die Werte')
ok('Name' => 'Anleimer Eiche hell')
check(model.materials['Anleimer Eiche'].nil? && model.materials['Anleimer Eiche hell'].equal?(eiche_k), 'umbenannt')
check(eiche.get_attribute('JT_Material', 'kante') == 'Anleimer Eiche hell', 'Zuordnung umgestellt')
check(M.bibliothek.none? { |e| e['name'] == 'Anleimer Eiche' } &&
      M.bibliothek.find { |e| e['name'] == 'Front Eiche 19mm' }['kante'] == 'Anleimer Eiche hell', 'Bibliothek umgestellt')

# --- Löschen ---
liste.callbacks['neu'].call(nil, 'platte')
ok('Name' => 'Weg damit')
liste.callbacks['loeschen'].call(nil, 'Weg damit')
check(model.materials['Weg damit'].nil? && !M.in_bibliothek?('Weg damit') && !liste.html.include?('Weg damit'), 'gelöscht')

# --- Frontfarbe mit dem neuen Material ---
S::Frontfarbe.anwenden(model, S::Frontfarbe.fronten(model), eiche)
check(S::Frontfarbe.fronten(model).all? { |t| t.inst.material.equal?(eiche) }, 'Fronten Eiche')

# --- Maserrichtung: Schubladenfronten (900 breit, niedrig) mit Faser senkrecht ---
zs, = S::Stueckliste.erzeugen(model)
fr = zs.select { |z| z.rolle == 'Front' && z.schrank.to_s.start_with?('US') }
check(!fr.empty? && fr.all? { |z| z.maserung && z.fertig[0] < z.fertig[1] }, "Schubladenfront: L = Höhe (Faser senkrecht) #{fr.map(&:fertig)}")
mel.set_attribute('ladb_opencutlist', 'grained', true)
zs, = S::Stueckliste.erzeugen(model)
seite = zs.find { |z| z.rolle == 'Seite' }
check(seite.fertig[0] >= seite.fertig[1], 'Korpusteil: L = längere Seite')
# Übersteuern: ausgewählte Schubladenfronten waagrecht
model.selection.clear
model.selection.add(uss)
D.maserung_dialog(model)
ok('Maserrichtung' => 'waagrecht')
zs, = S::Stueckliste.erzeugen(model)
fr = zs.select { |z| z.rolle == 'Front' && z.schrank.to_s.start_with?('US') }
check(fr.all? { |z| z.fertig[0] > z.fertig[1] }, 'waagrecht: L = Breite der Front')
check(S::Schraenke.teile(model).select { |t| t.pfad.first.equal?(uss) }.all? { |t| t.jt('maserung') == 'waagrecht' }, 'Maserung am Teil gemerkt')
D.maserung_dialog(model)
ok('Maserrichtung' => 'automatisch')
check(S::Schraenke.teile(model).none? { |t| t.jt('maserung') }, 'automatisch entfernt die Angabe')
model.selection.clear
UI.meldungen = []
D.maserung_dialog(model)
check(UI.meldungen.last.to_s.include?('auswählen'), 'ohne Auswahl: Hinweis')
mel.set_attribute('ladb_opencutlist', 'grained', false)

# --- Korpusmaterial ändern: nur die Kopie, Fronten bleiben ---
grau = M.platte_setzen(model, name: 'Anthrazit', farbe: '#333333', staerke: 19, verwendung: 'Korpus')
korpus_os2 = K.teile(model, auswahl: [os2])
check(!korpus_os2.empty? && korpus_os2.none?(&:front?) && korpus_os2.none? { |t| t.rolle == 'Rueckwand' }, 'Korpusteile ohne Fronten und Rückwand')
K.anwenden(model, korpus_os2, grau)
neu_os2 = K.teile(model, auswahl: [os2])
check(neu_os2.all? { |t| t.inst.material.equal?(grau) }, 'Kopie: Korpus Anthrazit')
check(K.teile(model, auswahl: [os1]).all? { |t| t.inst.material.equal?(mel) }, 'Original bleibt Melamin weiss')
kanten = ->(t) { t.inst.definition.entities.faces.map(&:material).compact.map(&:name).uniq }
check(neu_os2.select { |t| %w[Boden Einlegeboden].include?(t.rolle) }.all? { |t| kanten.call(t) == ['Anleimer Anthrazit'] },
      'Kopie: Anleimer Anthrazit')
check(K.teile(model, auswahl: [os1]).select { |t| t.rolle == 'Boden' }.all? { |t| kanten.call(t) == ['Anleimer Melamin weiss'] },
      'Original: Anleimer unverändert')
check(S::Frontfarbe.fronten(model).all? { |t| t.inst.material.equal?(eiche) }, 'Fronten bleiben Eiche')

# Dialog: Rückwände aller Unterschränke, Material aus der Bibliothek
M.platte_setzen(Sketchup::Model.new, name: 'HDF weiss 8mm', staerke: 8, verwendung: 'Rückwand') # nur Bibliothek
K.dialog(model, art: 'Rückwände')
f = EingabeHelfer.felder(letzter_dialog.html).to_h
check(f['Material'] == 'HDF weiss 8mm', "Rückwand-Material vorgeschlagen: #{f}")
ok('Bereich' => 'Nur Unterschränke')
hdf = model.materials['HDF weiss 8mm']
rw = K.teile(model, rollen: ['Rueckwand'])
check(hdf && rw.select { |t| S::Schraenke.kategorie(t) == 'Unterschrank' }.all? { |t| t.inst.material.equal?(hdf) } &&
      rw.select { |t| S::Schraenke.kategorie(t) == 'Oberschrank' }.none? { |t| t.inst.material.equal?(hdf) },
      'Dialog: Rückwände der Unterschränke HDF, aus der Bibliothek übernommen')
check(UI.meldungen.last.to_s.include?('bekommen „HDF weiss 8mm“'), "Rückfrage: #{UI.meldungen.last}")

puts $fehler.zero? ? 'OK: Materialien' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
