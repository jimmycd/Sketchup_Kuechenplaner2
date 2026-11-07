
# Front-/Rückwandhalter, Topfbänder mit Montageplatte, AVENTOS HK-top; nicht in Stückliste/TCN,
# innerhalb des Schranks, ein/aus, folgt Änderungen.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'

# --- Ergänzungen zum Mock: Gruppen mit Flächen, Löschen, Beobachter ---
module Sketchup
  class ModelObserver; end
  class AppObserver; end
  def self.add_observer(o) = (@beobachter ||= []) << o

  class Group
    include Attr
    attr_accessor :name, :layer, :material
    attr_reader :entities, :parent
    def initialize(eltern) = (@parent, @entities = eltern, Entities.new(self))
    def transformation = Geom::Transformation.translation([0, 0, 0])
    def erase! = @parent.entities.instances.delete(self)
    def hidden? = false
    def hidden = false
  end

  class Entities
    def parent = definition
    def add_group = Group.new(definition).tap { |g| @list << g }
    def flaechen = (@flaechen ||= [])
    alias_method :add_face_alt, :add_face
    def add_face(*pts) = add_face_alt(*pts).tap { flaechen << pts.map(&:to_a) }
    def erase_entities(l) = l.each { |e| @list.delete(e) }
  end

  class Mat # die Tags des Mocks sind Mat-Objekte
    attr_writer :visible
    def visible = @visible.nil? ? true : @visible
  end

  class Model
    include Attr
    def valid? = true
    def beobachter = (@beobachter ||= [])
    def add_observer(o) = beobachter << o
    def remove_observer(o) = beobachter.delete(o)
  end
end
module UI
  def self.stop_timer(_id) = nil
  def self.messagebox(m) = ($meldungen ||= []) << m
end

komp = File.expand_path('../../Komponenten', __dir__)
%w[unterschrank_schubladen oberschrank oberschrank_klappe unterschrank_doppeltuer hochschrank eckschrank unterschrank_handtuch].each do |k|
  load File.join(komp, "#{k}/src/#{k}/main.rb")
end
load File.expand_path('../src/jt_schrank_cnc/main.rb', __dir__)

S = JTools::SchrankCnc
B = S::Beschlagmodell
G = S::Griffkatalog
GM = S::Griffmodell
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

# --- Katalog (Häfele DÉCO Kollektion 2025, Jürgens Blätterkatalog) ---
check(G.fehler.empty?, "Katalogdaten: #{G.fehler.first(5)}")
check(G.serien.size == 81, "81 Serien (#{G.serien.size})")
check(G.serien.all? { |s| File.size?(G.bild(s)).to_i > 5000 }, 'jede Serie hat ein Bild')
h2510 = G.serie('H2510')
check(G.lochabstaende(h2510) == [128.0, 160.0, 320.0] && G.oberflaechen(h2510).first == 'schwarz matt' &&
      G.groesse(h2510, 160, 'kupferrot')['artikel'] == '106.71.041', 'H2510: Lochabstände, Oberflächen, Artikel-Nr.')
check(G.serie('H2515')['bauart'] == 'knopf' && G.lochabstaende(G.serie('H2515')) == [0.0], 'H2515 ist ein Knopf')
check(G.lochabstaende(G.serie('H1910')) == [128.0, 160.0], 'H1910: Griff für 128 und 160')
check(G.groesse(G.serie('H2110'), 192, 'bronzefarben hell')['artikel'] == '106.70.202', 'H2110: Artikel-Nr. nicht fortlaufend')

# --- Vorschlag nach Frontbreite (20 %, nächstliegender Lochabstand, Griff muss passen) ---
h2585 = G.serie('H2585') # 96/128/160/192/320
vs = { 300 => 96, 450 => 96, 600 => 128, 900 => 192, 1200 => 192, 150 => 96 }
vs.each { |b, l| check(G.vorschlag(h2585, b) == l, "Vorschlag #{b} → #{l} (#{G.vorschlag(h2585, b)})") }
check(G.vorschlag(G.serie('H2510'), 300) == 128, 'kleinster Lochabstand, wenn nichts näher liegt')
check(G.vorschlag(G.serie('H2515'), 600) == 0, 'Knopf: Lochabstand 0')

# --- Küche ohne Serie: keine automatischen Griffe ---
model = Sketchup.active_model = Sketchup::Model.new
uss = UnterschrankSchubladen.erstellen({ 'Breite' => 60.0, 'Tiefe' => 52.0, 'Anz_Schubladen' => 3,
                                         'Anteil_1' => 1.0, 'Anteil_2' => 1.0, 'Anteil_3' => 2.0 })
usd = UnterschrankDoppeltuer.erstellen({ 'Breite' => 80.0 })
os = Oberschrank.erstellen({ 'Art_Tuer' => 1.0, 'Breite' => 50.0 })
griffe = lambda do
  ws = []
  S::Export.erzeugen(model, alle_ws: ws)
  [ws, ws.select { |w| w.ops.any? { |o| o.titel == 'Griff' } }, S::Beschlaege.liste(ws).map(&:to_a)]
end
ws, mit, bl = griffe.()
check(mit.empty? && bl.none? { |p| p[0] == 'Griffe' }, 'ohne Griffserie: keine Griffbohrungen, keine Griffe in der Liste')
check(GM.aktualisieren(model).zero?, 'ohne Griffserie: nichts zu zeichnen')

# --- Serie H2585 schwarz matt für die Küche: alle Fronten bekommen Griffe nach Vorschlag ---
G.waehlen('H2585', 'schwarz matt', model)
check(G.kueche(model)['kennung'] == 'H2585' && G.oberflaeche(model) == 'schwarz matt', 'Serie und Oberfläche gespeichert')
ws, mit, bl = griffe.()
fronten = ws.select { |w| %w[Front Tuer].include?(w.rolle) && w.teil.jt('teil') != 'Blende' && w.teil.sichtbar? }
check(!fronten.empty? && fronten.all? { |w| mit.include?(w) }, "alle Fronten mit Griff (#{fronten.size}, mit #{mit.size})")
breite = ->(w) { w.mass(w.dicke_achse.zero? ? 1 : 0) }
abst = ->(w) { xs = w.ops.select { |o| o.titel == 'Griff' }.map { |o| o.p0[w.dicke_achse.zero? ? 1 : 0] }.sort; (xs.last - xs.first).round(1) }
mit.each do |w|
  check(abst.(w) == G.vorschlag(h2585, breite.(w)), "#{w.name}: Lochabstand #{abst.(w)} = Vorschlag für #{breite.(w).round}")
end
# Unterschrank: Griff oben (35 unter Oberkante), Oberschrank: unten (35 über Unterkante)
w_os = mit.find { |w| w.teil.pfad.first.equal?(os) }
w_us = mit.select { |w| w.teil.pfad.first.equal?(uss) }.max_by { |w| w.lo[2] }
z = ->(w) { w.ops.find { |o| o.titel == 'Griff' }.p0[2] }
check(w_os && (z.(w_os) - (w_os.lo[2] + 35)).abs < 0.01, "Oberschrank: Griff 35 über Unterkante (#{w_os && (z.(w_os) - w_os.lo[2]).round(1)})")
check(w_us && (w_us.hi[2] - z.(w_us) - 35).abs < 0.01, "Unterschrank: Griff 35 unter Oberkante (#{w_us && (w_us.hi[2] - z.(w_us)).round(1)})")
gl = bl.select { |p| p[0] == 'Griffe' }
check(gl.sum { |p| p[3] } == mit.size && gl.all? { |p| p[1].start_with?('Häfele H2585 Griff') && p[1].include?('schwarz matt') && p[2] =~ /Art\.-Nr\. 106\.71\.43\d/ },
      "Beschlagliste: Griffe mit Artikel-Nr. (#{gl.map { |p| [p[1], p[2], p[3]] }})")

# --- Griffe im Modell (immer, auch ohne „Beschläge ein“), außerhalb der Front ---
check(!B.an?(model), 'Beschläge aus')
check(GM.aktualisieren(model) > 0, 'Griffe gezeichnet')
gruppen = GM.alle_gruppen(model.entities)
check(!gruppen.empty? && gruppen.all? { |g| g.layer.name == 'Griffe' && g.parent.get_attribute('JT_Schrank', 'teil').nil? },
      'Gruppen „Griffe“ auf Tag Griffe, nicht in einem Werkstück')
ws2, mit2, = griffe.()
check(mit2.map { |w| [w.name, w.lo.map { |v| v.round(2) }, w.hi.map { |v| v.round(2) }] } ==
      mit.map { |w| [w.name, w.lo.map { |v| v.round(2) }, w.hi.map { |v| v.round(2) }] }, 'Fronten behalten ihre Maße')
k = GM.koerper(mit)
w = w_os
kw = k.values.flatten.select { |x| x.name == 'Griff' }
check(kw.size == mit.size && kw.all? { |x| x.mat == 'Griff schwarz matt' }, "je Front eine Griffstange (#{kw.size}/#{mit.size})")
stange = k[w.teil.pfad[0..-2]].find { |x| x.name == 'Griff' }
check(stange && (stange.a[1] - (w.lo[1] - 32)).abs < 0.01 && (stange.b[1] - (w.lo[1] - 22)).abs < 0.01 &&
      (stange.b[0] - stange.a[0] - G.groesse(h2585, abst.(w))['laenge']).abs < 0.01, "Stange vor der Front: Ausladung 32, Länge aus dem Katalog (#{stange && [stange.a, stange.b]})")
check(S::Rendern.materialart('Griff schwarz matt') == 'metall' && S::Rendern.materialart(GM.materialname('Eiche natur lackiert')) == 'holz',
      'Rendern: Griff aus Metall, Eiche aus Holz')
lam = S::Rendern.sichtbarkeit(model)
tag = Struct.new(:name, :visible?).new('Griffe', false)
check(lam.call(tag), 'Rendern: Tag Griffe immer im Bild')

# --- Je Schrank änderbar: feste Größe, kein Griff, Lage/Höhe ---
check(S::Schrankbeschlag.groessen(model).keys.include?('H2585 Lochabstand 320 mm (332 lang)'), 'Schrank-Dialog bietet die Größen der Serie')
vt = S::Schrankbeschlag.vorschlag_text(model, [usd])
check(vt.to_s.include?('→ 96 mm'), "Vorschlag im Dialog: #{vt}")
wahl = S::Schrankbeschlag.griff_wahl(model, ['H2585 Lochabstand 320 mm (332 lang)', '', 'links', '100'])
S::Schrankbeschlag.anwenden(model, [usd], {}, griff: wahl)
wahl_os = S::Schrankbeschlag.griff_wahl(model, [S::Schrankbeschlag::KEIN, '', S::Schrankbeschlag::UNVERAENDERT, ''])
S::Schrankbeschlag.anwenden(model, [os], {}, griff: wahl_os)
kz = ->(x) { S::Schraenke.definition(x).get_attribute('JT_Schrank', 'schrank') }
usd_k, os_k = kz.(usd), kz.(os)
usd, os = [usd_k, os_k].map { |c| S::Schraenke.instanzen(model.entities).find { |i| kz.(i) == c } } # nach dem Eindeutigmachen
ws, mit, = griffe.()
d_usd = mit.select { |w| w.teil.jt('schrank').to_s == S::Schraenke.definition(usd).get_attribute('JT_Schrank', 'schrank').to_s }
check(d_usd.size == 2 && d_usd.all? { |w| abst.(w) == 320 && (z.(w) - w.lo[2] - 100).abs < 0.01 }, "Doppeltür: 320 fest, 100 hoch (#{d_usd.map { |w| [abst.(w), (z.(w) - w.lo[2]).round] }})")
check(mit.none? { |w| w.teil.jt('schrank').to_s == S::Schraenke.definition(os).get_attribute('JT_Schrank', 'schrank').to_s }, 'Oberschrank: kein Griff')
zur = S::Schrankbeschlag.griff_wahl(model, [S::Schrankbeschlag::VORSCHLAG, '', S::Schrankbeschlag::LAGE_AUTO, 'auto'])
S::Schrankbeschlag.anwenden(model, [usd, os], {}, griff: zur)
ws, mit, = griffe.()
check(mit.size == fronten.size && mit.all? { |w| abst.(w) == G.vorschlag(h2585, breite.(w)) }, 'zurück auf Vorschlag')
check(S::Schrankbeschlag.griff_wahl(model, [S::Schrankbeschlag::UNVERAENDERT, '', S::Schrankbeschlag::UNVERAENDERT, '']).nil?, 'unverändert = nichts')

# --- Grifflos (TIP-ON): keine Griffe, auch nicht automatisch ---
S::Beschlagkatalog.waehlen('oeffnung', 'blum-tip-on', model)
ws, mit, bl = griffe.()
check(mit.empty? && bl.none? { |p| p[0] == 'Griffe' }, 'TIP-ON: keine Griffe')
S::Beschlagkatalog.waehlen('oeffnung', 'griffe', model)
Sketchup.defaults.delete(['Kuechenplaner_Einstellungen', 'beschlag_oeffnung']) if Sketchup.respond_to?(:defaults)

# --- Knopf-Serie: eine Bohrung in der Frontmitte, Knopf in der Liste ---
G.waehlen('H2515', 'ozeanblau', model)
ws, mit, bl = griffe.()
check(!mit.empty? && mit.all? { |w| w.ops.count { |o| o.titel == 'Griff' } == 1 }, 'Knopf: eine Bohrung')
check(bl.any? { |p| p[1] == 'Häfele H2515 Knopf, ozeanblau' && p[2].include?('106.71.075') }, "Knopf in der Beschlagliste: #{bl.select { |p| p[0] == 'Griffe' }}")
check(GM.koerper(mit).values.flatten.map(&:name).include?('Knopf'), 'Knopf gezeichnet')

# --- Eckschrank L (Falttür, Jürgen 2026-11-07 „Griffbelegung falsch“): nur die kurze Tür, an ihrer freien Kante ---
em = Sketchup.active_model = Sketchup::Model.new
Eckschrank.erstellen({}, l_form: true)
G.waehlen('H2585', 'schwarz matt', em)
ews = []
S::Export.erzeugen(em, alle_ws: ews)
lang = ews.find { |w| w.rolle == 'Tuer' && w.ops.any? { |o| o.titel == 'Falttürscharnier Topf' } }
kurz = ews.find { |w| w.rolle == 'Tuer' && w.ops.any? { |o| o.titel == 'Montageplatte Falttürscharnier' } }
kl = kurz && kurz.ops.select { |o| o.titel == 'Griff' }
wa = kurz && (kurz.dicke_achse.zero? ? 1 : 0)
frei = kurz && ((kurz.lo[wa] + kurz.hi[wa]) / 2 > (lang.lo[wa] + lang.hi[wa]) / 2 ? kurz.hi[wa] : kurz.lo[wa])
check(lang && lang.ops.none? { |o| o.titel == 'Griff' }, 'Falttür: lange Tür ohne Griff')
check(kl && kl.size == 2 && kl.map { |o| (o.p0[wa] - frei).abs.round(1) }.min == 35.0,
      "Falttür: Griff an der kurzen Tür, äußeres Loch 35 von der freien Kante (#{kl && kl.map { |o| o.p0.map(&:round) }})")

# --- Fenster Griffkatalog: alle Serien mit Bild ---
html = S::Griffdialog.html(model, bild_url: ->(s) { "bild/#{s['kennung']}.jpg" })
check(html.scan('<div class="karte').size == 81 && html.include?('bild/H2510.jpg') && html.include?('106.71.075'), 'Fenster: 81 Karten mit Bild und Artikel-Nr.')
check(html.include?('karte gewaehlt" data-k="H2515"'), 'Fenster: gewählte Serie markiert')
G.waehlen(nil, nil, model)
check(G.kueche(model).nil?, 'Keine Serie')

if $fehler.zero?
  puts 'Griffkatalog: alle Tests OK'
else
  puts "#{$fehler} FEHLER"
  exit 1
end
