# Test ohne SketchUp: Griffmulde gefräst (grifflose Fronten, Öffnung „griffmulde“): Regeln, TCN-Kontur,
# Maße änderbar, je Schrank abweichend, Hochschrank ausgenommen, Falttür, Flächen im Modell.
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
%w[unterschrank_schubladen oberschrank oberschrank_klappe unterschrank_doppeltuer hochschrank eckschrank].each do |k|
  load File.join(komp, "#{k}/src/#{k}/main.rb")
end
load File.expand_path('../src/jt_schrank_cnc/main.rb', __dir__)

S = JTools::SchrankCnc
M = S::Griffmulde
K = S::Beschlagkatalog
G = S::Griffkatalog
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

# --- Katalog und Maße ---
e = K.eintrag('griffmulde')
check(e && K.fehler(e).empty? && K.passt?(e, 'oeffnung'), "Katalogeintrag griffmulde gültig (#{e && K.fehler(e)})")
check(K.zur_art('oeffnung').map { |x| x['kennung'] }.include?('griffmulde'), 'wählbar unter Öffnung (Küche und Schrank)')
model = Sketchup.active_model = Sketchup::Model.new
Sketchup.defaults.delete(['Kuechenplaner_Einstellungen', 'griffmulde'])
check(M.masse(model) == { 'breite' => 160.0, 'hoehe' => 30.0, 'rand' => 40.0, 'radius' => 10.0 }, "Standardmaße 160 × 30, Rand 40, R 10 (#{M.masse(model)})")
check(M.fehler('breite' => 160.0, 'hoehe' => 30.0, 'rand' => 40.0, 'radius' => 5.0).to_s.include?('mindestens 10'), 'Radius unter Fräserradius abgelehnt')
check(M.fehler('breite' => 18.0, 'hoehe' => 30.0, 'rand' => 40.0, 'radius' => 10.0), 'Breite kleiner als zwei Radien abgelehnt')

# --- Küche mit Griffmulde (Griffserie gewählt: Hochschrank behält Griffe) ---
uss = UnterschrankSchubladen.erstellen({ 'Breite' => 60.0, 'Tiefe' => 52.0, 'Anz_Schubladen' => 3,
                                         'Anteil_1' => 1.0, 'Anteil_2' => 1.0, 'Anteil_3' => 2.0 })
usd = UnterschrankDoppeltuer.erstellen({ 'Breite' => 80.0 })
os = Oberschrank.erstellen({ 'Art_Tuer' => 1.0, 'Breite' => 50.0 })
ok = OberschrankKlappe.erstellen({})
hs = Hochschrank.erstellen({})
G.waehlen('H2585', 'schwarz matt', model)
K.waehlen('oeffnung', 'griffmulde', model)
lauf = lambda do
  ws = []
  dateien, = S::Export.erzeugen(model, alle_ws: ws)
  [ws, dateien, S::Beschlaege.liste(ws).map(&:to_a)]
end
ws, dateien, bl = lauf.()
kz = ->(i) { S::Schraenke.definition(i).get_attribute('JT_Schrank', 'schrank').to_s }
von = ->(s) { ws.select { |w| w.teil.jt('schrank').to_s == kz.(s) } }
fronten = ->(s) { von.(s).select { |w| M.front?(w) } }
mulde = ->(w) { w.ops.find { |o| o.titel == 'Griffmulde' } }
griff = ->(w) { w.ops.any? { |o| o.titel == 'Griff' } }
[uss, usd, os].each do |s|
  f = fronten.(s)
  check(!f.empty? && f.all? { |w| mulde.(w) && !griff.(w) }, "#{kz.(s)}: alle Fronten mit Mulde, ohne Griffbohrung (#{f.map { |w| [w.name, !mulde.(w).nil?, griff.(w)] }})")
end
check(fronten.(hs).all? { |w| griff.(w) && !mulde.(w) }, 'Hochschrank ausgenommen: Griffe, keine Mulde')
check(bl.none? { |p| p[0] == 'Griffe' && p[5].to_s.include?(kz.(uss)) }, 'Beschlagliste: keine Griffe für Schränke mit Mulde')
check(bl.any? { |p| p[0] == 'Griffe' }, 'Beschlagliste: Griffe des Hochschranks bleiben')

wa = ->(w) { (w.flaechen_achsen - [2]).first }
mitte = ->(w) { (w.lo[wa.(w)] + w.hi[wa.(w)]) / 2.0 }
# Schubladen: mittig an der Oberkante, 160 breit, 30 tief
fronten.(uss).each do |w|
  m = mulde.(w).daten[:mulde]
  z = mulde.(w).daten[:segmente].flat_map { |s| s[1..2].map { |p| p[2] } }
  check(((m[:x0] + m[:x1]) / 2 - mitte.(w)).abs < 0.01 && (m[:x1] - m[:x0] - 160).abs < 0.01 && m[:oben] &&
        (z.max - w.hi[2]).abs < 0.01 && (z.min - (w.hi[2] - 30)).abs < 0.01, "#{w.name}: Mulde mittig oben 160 × 30 (#{m})")
end
# Doppeltür: je Tür an der Öffnungskante (Türmitte), 40 vom Rand
td = fronten.(usd)
check(td.size == 2 && td.all? do |w|
  m = mulde.(w).daten[:mulde]
  innen = mitte.(w) < td.sum { |x| mitte.(x) } / 2 ? w.hi[wa.(w)] : w.lo[wa.(w)]
  [(m[:x1] - innen).abs, (m[:x0] - innen).abs].min.round(2) == 40.0
end, "Doppeltür: Mulde an der Öffnungskante, 40 vom Rand (#{td.map { |w| [mulde.(w).daten[:mulde].values_at(:x0, :x1).map(&:round), w.lo[wa.(w)].round, w.hi[wa.(w)].round] }})")
# Oberschrank: Mulde unten (Eingriff von unten), Klappe mittig unten
fo = fronten.(os).first
mo = mulde.(fo)
zo = mo.daten[:segmente].flat_map { |s| s[1..2].map { |p| p[2] } }
check(!mo.daten[:mulde][:oben] && (zo.min - fo.lo[2]).abs < 0.01 && (zo.max - (fo.lo[2] + 30)).abs < 0.01, "Oberschrank: Mulde an der Unterkante (#{zo.minmax.map(&:round)} bei #{fo.lo[2].round})")
kl = fronten.(ok)
check(kl.size == 1 && ((mulde.(kl[0]).daten[:mulde][:x0] + mulde.(kl[0]).daten[:mulde][:x1]) / 2 - mitte.(kl[0])).abs < 0.01 &&
      !mulde.(kl[0]).daten[:mulde][:oben], "Klappe: Mulde mittig unten (#{kl.map(&:name)})")

# --- TCN: Kontur mit 1004 ganz durch, Start und Ende außerhalb der Front, nur Geraden ---
w = fronten.(uss).first
d = dateien.find { |x| x.ws.equal?(w) }
zeilen = d.text.lines.select { |l| l.include?('W#89{') || l.include?('W#2201{') }
start = zeilen.find { |l| l.include?('#205=1004 ') }
check(start && start.include?("#3=-#{S::Tcn.n(w.mass(w.dicke_achse) + 1)} ") && d.text.scan('W#2201').size >= 10 && !d.text.include?('W#2125'),
      "Front #{w.name}: Mulde mit 1004 ganz durch, Bögen als Geraden (#{start})")
xy = start && start[/#1=(\S+) #2=(\S+)/, 0].scan(/=(\S+)/).flatten.map(&:to_f)
lage = d.lage
check(xy && (xy[0] < -5 || xy[0] > lage.dl + 5 || xy[1] < -5 || xy[1] > lage.dh + 5), "Mulde beginnt außerhalb der Front (#{xy}, #{lage.dl.round} × #{lage.dh.round})")

# --- Modell: Flächen der Front mit Mulde (lokal), ohne Mulde Quader ---
fl, sig = M.lokal(w)
check(sig && fl.size == mulde.(w).daten[:umriss].size + 2 && fl.count { |_, m| m } >= 5, "Front mit Mulde: #{fl.size} Flächen, davon #{fl.count { |_, m| m }} in der Mulde")
fh = fronten.(hs).first
fl2, sig2 = M.lokal(fh)
check(sig2.nil? && fl2.size == 6, 'Front ohne Mulde: Quader, keine Signatur')
ber = M.op(w, wa.(w), mitte.(w) - 80, mitte.(w) + 80, false, M.masse(model)).daten[:umriss]
check(ber.all? { |p| p[wa.(w)].between?(w.lo[wa.(w)] - 0.01, w.hi[wa.(w)] + 0.01) && p[2].between?(w.lo[2] - 0.01, w.hi[2] + 0.01) },
      'Umriss bleibt in der Front (Maße der Front unverändert)')

# --- Maße änderbar (Einstellungen), je Schrank wieder Griffe ---
M.setzen({ 'breite' => 200, 'hoehe' => 40, 'rand' => 50, 'radius' => 12 }, model)
ws, = lauf.()
m = mulde.(fronten.(uss).first).daten[:mulde]
check((m[:x1] - m[:x0] - 200).abs < 0.01 && m[:hoehe] == 40.0 && m[:r] == 12.0, "geänderte Maße 200 × 40, R 12 (#{m})")
check(fronten.(usd).all? { |x| md = mulde.(x).daten[:mulde]; innen = mitte.(x) < fronten.(usd).sum { |y| mitte.(y) } / 2 ? x.hi[wa.(x)] : x.lo[wa.(x)]; [(md[:x1] - innen).abs, (md[:x0] - innen).abs].min.round(2) == 50.0 },
      'Rand 50 an der Doppeltür')
K.schrank_waehlen(uss, 'oeffnung', 'griffe', model)
ws, = lauf.()
check(fronten.(uss).all? { |x| griff.(x) && !mulde.(x) } && fronten.(usd).all? { |x| mulde.(x) }, 'Schrank auf Griffe: dort Griffe, die anderen behalten die Mulde')
K.schrank_waehlen(uss, 'oeffnung', nil, model)

# --- schmale Front: Mulde schmaler (20 mm Steg je Seite), zu schmal: Meldung ---
schmal = UnterschrankSchubladen.erstellen({ 'Breite' => 20.0, 'Anz_Schubladen' => 1, 'Anteil_1' => 1.0 })
sw = []
S::Export.erzeugen(model, auswahl: [schmal], alle_ws: sw)
f20 = sw.find { |x| M.front?(x) }
m20 = f20 && mulde.(f20) && mulde.(f20).daten[:mulde]
check(m20 && (m20[:breite] - (f20.mass(wa.(f20)) - 40)).abs < 0.01, "20er Schrank: Mulde = Frontbreite − 2 × 20 (#{m20 && m20[:breite]})")
M.setzen({ 'breite' => 200, 'hoehe' => 100, 'rand' => 50, 'radius' => 90 }, model)
meld = []
S::Beschlagkatalog.mit_schrank(schmal) { M.regeln([f20.tap { |x| x.ops.clear }], meld) } if f20
check(meld.any? { |x| x.include?('zu schmal für die Griffmulde') }, "Radius 90 an 198 breiter Front: Meldung (#{meld})")

# --- Eckschrank L: nur die kurze Falttür, an der freien Kante ---
em = Sketchup.active_model = Sketchup::Model.new
Eckschrank.erstellen({}, l_form: true)
K.waehlen('oeffnung', 'griffmulde', em)
M.setzen({ 'breite' => 160, 'hoehe' => 30, 'rand' => 40, 'radius' => 10 }, em)
ews = []
S::Export.erzeugen(em, alle_ws: ews)
lang = ews.find { |x| x.rolle == 'Tuer' && x.ops.any? { |o| o.titel == 'Falttürscharnier Topf' } }
kurz = ews.find { |x| x.rolle == 'Tuer' && x.ops.any? { |o| o.titel == 'Montageplatte Falttürscharnier' } }
check(lang && !mulde.(lang), 'Falttür: lange Tür ohne Mulde')
if kurz && mulde.(kurz)
  km = mulde.(kurz).daten[:mulde]
  a = km[:quer]
  frei = (kurz.lo[a] + kurz.hi[a]) / 2 > (lang.lo[a] + lang.hi[a]) / 2 ? kurz.hi[a] : kurz.lo[a]
  check([(km[:x0] - frei).abs, (km[:x1] - frei).abs].min.round(2) == 40.0, "Falttür: Mulde 40 von der freien Kante (#{km})")
else
  check(false, 'Falttür: kurze Tür mit Mulde')
end
K.waehlen('oeffnung', 'griffe', em)
Sketchup.defaults.delete(['Kuechenplaner_Einstellungen', 'beschlag_oeffnung'])
Sketchup.defaults.delete(['Kuechenplaner_Einstellungen', 'griffmulde'])

if $fehler.zero?
  puts 'Griffmulde: alle Tests OK'
else
  puts "#{$fehler} FEHLER"
  exit 1
end
