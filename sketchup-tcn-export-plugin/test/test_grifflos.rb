# Test ohne SketchUp: Griffkante 45° und durchlaufende Griffmulde (grifflose Fronten, Schritt 2 Oberschränke):
# Katalog, Maße, Komponenten-Attribute setzen, Fase im TCN, Flächen im Modell, ältere Schränke, Unterschrank behält Griffe.
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
%w[unterschrank_schubladen oberschrank oberschrank_klappe oberschrank_dunstabzug eck_oberschrank hochschrank].each do |k|
  load File.join(komp, "#{k}/src/#{k}/main.rb")
end
load File.expand_path('../src/jt_schrank_cnc/main.rb', __dir__)

S = JTools::SchrankCnc
L = S::Grifflos
K = S::Beschlagkatalog
G = S::Griffkatalog
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end
dc = ->(s, k) { S::Schraenke.dc(s, k) && (S::Schraenke.dc(s, k) * 25.4).round(3) }

# --- Katalog und Maße ---
%w[griffkante griffmulde_durchlaufend].each do |k|
  e = K.eintrag(k)
  check(e && K.fehler(e).empty? && K.passt?(e, 'oeffnung'), "Katalogeintrag #{k} gültig (#{e && K.fehler(e)})")
  check(K.zur_art('oeffnung').map { |x| x['kennung'] }.include?(k), "#{k} wählbar unter Öffnung")
end
model = Sketchup.active_model = Sketchup::Model.new
Sketchup.defaults.delete(['Kuechenplaner_Einstellungen', 'grifflos'])
check(L.masse(model) == { 'fase' => 13.0, 'luft' => 25.0, 'oberschrank' => 30.0 }, "Standardmaße Fase 13, Luft 25, Boden 30 (#{L.masse(model)})")
check(L.fehler('fase' => 20.0, 'luft' => 25.0, 'oberschrank' => 30.0), 'Fase tiefer als die Platte abgelehnt')
check(L.fehler('fase' => 13.0, 'luft' => 0.0, 'oberschrank' => 30.0), 'Null abgelehnt')

# --- Küche mit Griffkante ---
G.waehlen('H2585', 'schwarz matt', model)
uss = UnterschrankSchubladen.erstellen({ 'Breite' => 60.0, 'Tiefe' => 52.0, 'Anz_Schubladen' => 2, 'Anteil_1' => 1.0, 'Anteil_2' => 1.0 })
os = Oberschrank.erstellen({ 'Art_Tuer' => 2.0, 'Breite' => 60.0 })
ok = OberschrankKlappe.erstellen({ 'Art_Klappe' => 2.0, 'Hoehe' => 72.0 })
od = OberschrankDunstabzug.erstellen({})
oe = EckOberschrank.erstellen({})
hs = Hochschrank.erstellen({})
ober = [os, ok, od, oe]
K.waehlen('oeffnung', 'griffkante', model)
check(K.nicht_angepasst.empty?, "alle Schränke passen sich an (#{K.nicht_angepasst})")
ober.each { |s| check(dc.(s, 'griff_front') == 25.0, "#{s.definition.name}: Griff_Front 25 mm (#{dc.(s, 'griff_front')})") }
[os, ok, oe].each { |s| check(dc.(s, 'griff_boden') == 0.0, "#{s.definition.name}: Griff_Boden 0 bei Griffkante") }
check(dc.(od, 'griff_boden').nil?, 'Dunstabzug hat keinen Boden zum Verschieben')
check(dc.(hs, 'griff_front').nil? && dc.(uss, 'griff_front').nil?, 'Hoch- und Unterschrank unverändert')

# Wahl durchlaufende Mulde: Boden 30 höher, Front wieder voll
K.waehlen('oeffnung', 'griffmulde_durchlaufend', model)
[os, ok, oe].each do |s|
  check(dc.(s, 'griff_boden') == 30.0 && dc.(s, 'griff_front') == 0.0, "#{s.definition.name}: Mulde durchlaufend Boden 30, Front voll")
end
check(dc.(od, 'griff_front') == 0.0, 'Dunstabzug: durchlaufende Mulde ändert nichts')
# geänderte Maße
L.setzen({ 'fase' => 10.0, 'luft' => 20.0, 'oberschrank' => 40.0 }, model)
L.kueche_anpassen(model)
check(dc.(os, 'griff_boden') == 40.0, "geändertes Maß: Boden 40 höher (#{dc.(os, 'griff_boden')})")
L.setzen(L.standard, model)
L.kueche_anpassen(model)
# je Schrank abweichend: Oberschrank mit Griffen
r = K.schrank_waehlen(os, "oeffnung", "griffe", model)
check(r, "Schrank-Wahl Griffe")
check(dc.(os, 'griff_boden') == 0.0 && dc.(ok, 'griff_boden') == 30.0, 'eigene Wahl des Schranks: Boden wieder unten, andere bleiben')
K.schrank_waehlen(os, 'oeffnung', nil, model)
check(dc.(os, 'griff_boden') == 30.0, 'wieder wie Küche')
# zurück auf Griffe: alles auf 0
K.waehlen('oeffnung', 'griffe', model)
check(ober.all? { |s| [dc.(s, 'griff_boden'), dc.(s, 'griff_front')].compact.all?(&:zero?) }, 'Griffe: alles zurück')

# ältere Schränke ohne Griff_* werden genannt
alt = Oberschrank.erstellen({})
%w[griff_boden griff_front].each { |k| alt.definition.attribute_dictionary('dynamic_attributes').delete(k) rescue alt.definition.delete_attribute('dynamic_attributes', k) }
K.waehlen('oeffnung', 'griffkante', model)
check(K.nicht_angepasst == [S::Schraenke.definition(alt).get_attribute('JT_Schrank', 'schrank')], "ältere Version genannt (#{K.nicht_angepasst})")
model.entities.instances.delete(alt) if model.entities.respond_to?(:instances)

# neuer Schrank in einer Küche mit Griffkante bekommt sie gleich
neu = Oberschrank.erstellen({})
check(dc.(neu, 'griff_front') == 25.0, 'neuer Schrank: Griffkante sofort')
model.entities.instances.delete(neu)

# --- Regeln und TCN (Schränke wie nach dem Neuzeichnen, die Attrappe rechnet keine Formeln) ---
model = Sketchup.active_model = Sketchup::Model.new
G.waehlen('H2585', 'schwarz matt', model)
K.waehlen('oeffnung', 'griffkante', model)
uss = UnterschrankSchubladen.erstellen({ 'Breite' => 60.0, 'Tiefe' => 52.0, 'Anz_Schubladen' => 2, 'Anteil_1' => 1.0, 'Anteil_2' => 1.0 })
os = Oberschrank.erstellen({ 'Art_Tuer' => 2.0, 'Breite' => 60.0, 'Griff_Front' => 2.5 })
ok = OberschrankKlappe.erstellen({ 'Art_Klappe' => 2.0, 'Hoehe' => 72.0, 'Griff_Front' => 2.5 })
hs = Hochschrank.erstellen({})
ws = []
dateien, meld = S::Export.erzeugen(model, alle_ws: ws)
bl = S::Beschlaege.liste(ws).map(&:to_a)
kz = ->(i) { S::Schraenke.definition(i).get_attribute('JT_Schrank', 'schrank').to_s }
fronten = ->(s) { ws.select { |w| w.teil.jt('schrank').to_s == kz.(s) && S::Griffmulde.front?(w) } }
fase = ->(w) { w.ops.find { |o| o.art == :fase } }
griff = ->(w) { w.ops.any? { |o| o.titel == 'Griff' } }
tf = fronten.(os)
check(tf.size == 2 && tf.all? { |w| fase.(w) && !griff.(w) }, "Oberschrank: beide Türen mit Fase, ohne Griff (#{tf.map { |w| [w.name, !fase.(w).nil?, griff.(w)] }})")
check(tf.all? { |w| (w.lo[2] - (os.transformation.origin.to_a[2] * 25.4 + 26.0)).abs < 0.01 }, "Türen unten 25 kürzer (#{tf.map { |w| w.lo[2].round(1) }})")
kf = fronten.(ok)
check(kf.size == 2 && kf.count { |w| fase.(w) } == 1 && fase.(kf.min_by { |w| w.lo[2] }), "Faltklappe: nur das untere Teil mit Fase (#{kf.map { |w| [w.name, !fase.(w).nil?] }})")
check(fronten.(uss).all? { |w| griff.(w) && !fase.(w) }, 'Unterschrank behält Griffe (Schritt 3)')
check(fronten.(hs).all? { |w| griff.(w) && !fase.(w) }, 'Hochschrank ausgenommen')
check(bl.select { |p| p[0] == 'Griffe' }.none? { |p| p[5].to_s.include?(kz.(os)) }, 'Beschlagliste: keine Griffe am Oberschrank')

# Fase auf der Innenseite an der Unterkante, über die ganze Breite und darüber hinaus
w = tf.first
o = fase.(w)
da = w.dicke_achse
wa = (w.flaechen_achsen - [2]).first
check(o.tiefe == 13.0 && (o.p0[2] - w.lo_f(2)).abs < 0.001 && (o.p0[da] - w.hi[da]).abs < 0.001 &&
      [o.p0[wa], o.p1[wa]].min < w.lo[wa] - 10 && [o.p0[wa], o.p1[wa]].max > w.hi[wa] + 10, "Fase innen unten, 13 tief, Bahn über die Breite (#{o.p0.map(&:round)}–#{o.p1.map(&:round)})")
d = dateien.find { |x| x.ws.equal?(w) }
z = d.text.lines.find { |l| l.include?('#205=1400 ') }
check(z && z.include?('#3=-13 ') && z.include?('W#89{'), "TCN: Fase mit 1400, 13 tief (#{z})")
nach = d.text.lines[d.text.lines.index(z) + 1]
check(nach.start_with?('W#2201{'), 'TCN: Gerade nach dem Start')
xy = z[/#1=(\S+) #2=(\S+)/, 0].scan(/=(\S+)/).flatten.map(&:to_f)
dxy = nach[/#1=(\S+) #2=(\S+)/, 0].scan(/=(\S+)/).flatten.map(&:to_f)
ende = [xy[0] + dxy[0], xy[1] + dxy[1]]
quer = dxy[0].abs > dxy[1].abs ? 0 : 1 # Richtung der Bahn
lang = quer.zero? ? d.lage.dl : d.lage.dh
kurz = quer.zero? ? d.lage.dh : d.lage.dl
check([xy[quer], ende[quer]].min < -10 && [xy[quer], ende[quer]].max > lang + 10, "Fase beginnt und endet außerhalb der Front (#{xy} → #{ende}, #{d.lage.dl} × #{d.lage.dh})")
check((xy[1 - quer] - ende[1 - quer]).abs < 0.001 && (xy[1 - quer].abs < 0.001 || (xy[1 - quer] - kurz).abs < 0.001), "Fase entlang der Unterkante (#{xy[1 - quer]})")
check(d.text.include?('SIDE#1{') && d.text.split('SIDE#3{').first.include?('#205=1400'), 'Fase auf Fläche 1 (Innenseite)')
check(meld.none? { |m| m.include?('Griffkante') }, "keine Meldung (#{meld.grep(/Griffkante/)})")

# --- Modell: Querschnitt mit Fase ---
fl, sig = S::Griffmulde.lokal(w)
check(sig.to_s.start_with?('fase') && fl.size == 7 && fl.count { |_, a| a == :fase } == 1 &&
      fl.count { |_, a| a == :seite } == 2 && fl.count { |_, a| a == :kante } == 4, "Flächen: 2 Seiten, 4 Kanten, 1 Fase (#{fl.map(&:last)})")
fase_fl = fl.find { |_, a| a == :fase }[0]
# Fase-Fläche: 13 mm in der Dicke und 13 mm in der Höhe (lokal Zoll)
ab = (0..2).map { |i| fase_fl.map { |p| p[i] }.minmax.then { |a, b| ((b - a) * 25.4).round(2) } }
check(ab.sort[0..1] == [13.0, 13.0] || ab.count(13.0) == 2, "Fase 13 × 13 (#{ab})")
# ohne Griffkante wieder Quader
K.waehlen('oeffnung', 'griffe', model)
ws2 = []
S::Export.erzeugen(model, alle_ws: ws2)
w2 = ws2.find { |x| x.teil.jt('schrank').to_s == kz.(os) && S::Griffmulde.front?(x) }
check(S::Griffmulde.lokal(w2)[1].nil?, 'Griffe: Front ohne Fase')

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
