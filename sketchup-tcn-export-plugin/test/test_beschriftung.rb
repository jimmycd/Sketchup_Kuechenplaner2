# Test ohne SketchUp: Schrank-Beschriftung – jeder Schrank zeigt sein Kürzel (dieselbe Quelle
# wie die Etiketten), ein/aus in den Szenen Planung und Zuschnitt, nie in Kunde, folgt dem Modell.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'

# --- Ergänzungen zum Mock: Tags, Szenen, Gruppen, Texte, Beobachter ---
module Sketchup
  class ModelObserver; end
  class AppObserver; end
  def self.add_observer(o) = (@beobachter ||= []) << o
  def self.beobachter = (@beobachter ||= [])

  class Mat # die Tags des Mocks sind Mat-Objekte
    attr_writer :visible
    def visible = @visible.nil? ? true : @visible
  end

  class Text
    include Attr
    attr_accessor :text, :point, :vector, :layer, :leader_type
    def initialize(t, p, v) = (@text, @point, @vector = t, p, v)
  end

  class Group
    include Attr
    attr_accessor :name, :layer
    attr_reader :entities
    def initialize(eltern) = (@eltern, @entities = eltern, Entities.new(self))
    def transformation = Geom::Transformation.translation([0, 0, 0])
    def erase! = @eltern.instances.delete(self)
    def hidden? = false
  end

  class Entities
    def parent = definition
    def add_group = Group.new(self).tap { |g| @list << g }
    def add_text(t, p, v = nil) = Text.new(t, p.to_a, v&.to_a).tap { |x| @list << x }
  end

  class Page
    attr_reader :name, :sichtbar
    def initialize(n) = (@name, @sichtbar = n, {})
    def set_visibility(l, v) = @sichtbar[l.name] = v
  end

  class Pages
    include Enumerable
    attr_accessor :selected_page
    def initialize = @h = {}
    def [](n) = @h[n]
    def add(n) = @h[n] = Page.new(n)
    def each(&) = @h.values.each(&)
  end

  class Model
    include Attr
    def pages = (@pages ||= Pages.new)
    def valid? = true
    def beobachter = (@beobachter ||= [])
    def add_observer(o) = beobachter << o
    def remove_observer(o) = beobachter.delete(o)
    def operationen = (@operationen ||= [])
    def start_operation(*a) = operationen << a
  end
end
module UI
  def self.stop_timer(_id) = nil
  def self.messagebox(m) = ($meldungen ||= []) << m
end

komp = File.expand_path('../../Komponenten', __dir__)
load File.join(komp, 'hochschrank/src/hochschrank/main.rb')
load File.join(komp, 'unterschrank_schubladen/src/unterschrank_schubladen/main.rb')
load File.expand_path('../src/jt_schrank_cnc/main.rb', __dir__)

S = JTools::SchrankCnc
B = S::Beschriftung
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

def texte(model) = B.texte(B.gruppe(model))

check(Sketchup.beobachter.any? { |o| o.is_a?(B::AppBeobachter) }, 'neue/geöffnete Modelle werden beobachtet')
load File.expand_path('../src/jt_schrank_cnc/main.rb', __dir__) # Neuladen ohne Neustart
check(Sketchup.beobachter.count { |o| o.is_a?(B::AppBeobachter) } == 1, 'Neuladen: AppBeobachter nur einmal')

model = Sketchup.active_model = Sketchup::Model.new
%w[Planung Kunde Zuschnitt].each { |n| model.pages.add(n) }
model.pages.selected_page = model.pages['Planung']
hs = Hochschrank.erstellen({})
us = UnterschrankSchubladen.erstellen({ 'Breite' => 90.0, 'Tiefe' => 56.0 })
us.transformation.origin[0] = 100.0 # neben den Hochschrank

# --- dieselben Kürzel wie auf den Etiketten (Stückliste/Etiketten: Spalte Schrank) ---
zs, = S::Stueckliste.erzeugen(model)
etiketten = zs.map(&:schrank).uniq.sort
check(etiketten == %w[HS1 USS1], "Kürzel auf den Etiketten: #{etiketten}")
check(B.schraenke(model).map(&:first).sort == etiketten, "Beschriftung = Etiketten-Kürzel: #{B.schraenke(model).map(&:first)}")
check(zs.all? { |z| z.tag.start_with?("#{z.schrank}_") }, 'Kürzel steht auch vorne im Tag der Etiketten')

# --- einschalten: Texte auf Tag Beschriftung, Szenen Planung/Zuschnitt zeigen ihn, Kunde nie ---
check(!B.an?(model), 'anfangs aus')
check(B.umschalten(model) == true && B.an?(model), 'Umschalten: ein')
check($meldungen.nil?, "keine Meldung, wenn Schränke und Szenen da sind: #{$meldungen}")
g = B.gruppe(model)
check(g && g.layer.name == 'Beschriftung' && g.name == 'Schrank-Beschriftung', 'Gruppe Schrank-Beschriftung auf Tag Beschriftung')
check(texte(model).map(&:text).sort == %w[HS1 USS1], "ein Text je Schrank: #{texte(model).map(&:text)}")
check(texte(model).all? { |t| t.layer.name == 'Beschriftung' }, 'Texte auf Tag Beschriftung')
t_us = texte(model).find { |t| t.text == 'USS1' }
k = S::Andocken.kasten(us)
o = us.transformation.origin
# ohne sichtbare Front (im Mock sind die Schubkästen ausgeblendet): 100 mm vor dem Schrank, mittig
mitte = [(k[0] + k[1]) / 2 + o[0], k[2] - 1 / 25.4 + o[1], (k[4] + k[5]) / 2 + o[2]]
check(t_us.point.zip(mitte).all? { |a, b| (a - b).abs < 1e-6 }, "ohne Front: Pfeil vorn mittig am Schrank: #{t_us.point} statt #{mitte}")
# Text mit Pfeil wie das Werkzeug „Text“ (immer lesbar): Pin, Text rechts, vorn, oben vom Pfeil
check(texte(model).all? { |t| t.leader_type == 2 && t.vector }, 'alle Texte mit Pfeil (Pin)')
check(t_us.vector.zip([100, -200, 150]).all? { |a, b| (a - b / 25.4).abs < 1e-6 }, "Pfeil: Text 100 rechts, 200 vor, 150 über der Spitze (#{t_us.vector})")
# mit Front: wie bei den Geräten vorn mittig auf der größten sichtbaren Front, 1 mm davor
t_hs = texte(model).find { |t| t.text == 'HS1' }
fr = B.fronten(model, hs)
check(!fr.empty? && fr.size == S::Schraenke.teile(model).count { |t| t.schrank == hs && t.front? && t.sichtbar? }, "Hochschrank: sichtbare Fronten #{fr.size}")
gr = fr.max_by { |b| (b[1] - b[0]) * (b[5] - b[4]) }
ho = hs.transformation.origin
soll_hs = [(gr[0] + gr[1]) / 2 + ho[0], gr[2] - 1 / 25.4 + ho[1], (gr[4] + gr[5]) / 2 + ho[2]]
check(t_hs.point.zip(soll_hs).all? { |a, b| (a - b).abs < 1e-6 }, "mit Front: Text vorn auf der größten Front: #{t_hs.point} statt #{soll_hs}")
check(t_hs.point[1] < S::Andocken.kasten(hs)[2] + ho[1], 'Text liegt vor der Front, nicht im Schrank')
check(model.pages['Planung'].sichtbar['Beschriftung'] == true && model.pages['Zuschnitt'].sichtbar['Beschriftung'] == true,
      'ein: Planung und Zuschnitt zeigen die Beschriftung')
check(model.pages['Kunde'].sichtbar['Beschriftung'] == false, 'Kunde zeigt die Beschriftung nie')
check(model.layers['Beschriftung'].visible, 'aktuelle Ansicht (Planung): sichtbar')
check(model.beobachter.size == 1, 'Modell wird beobachtet')

# --- TCN-Export, Stückliste und Andocken sehen die Beschriftung nicht ---
check(S::Stueckliste.erzeugen(model).first.size == zs.size, 'Stückliste unverändert')
check(S::Schraenke.teile(model).none? { |t| t.inst.is_a?(Sketchup::Text) }, 'keine Teile aus der Beschriftung')
check(model.entities.grep(Sketchup::Group).none? { |e| S::Andocken.schrank?(e) }, 'Beschriftung ist kein Schrank (Andocken)')

# --- folgt dem Modell nach jedem Vorgang ---
ops = model.operationen.size
model.beobachter.first.onTransactionCommit(model)
check(model.operationen.size == ops, 'nichts geändert: kein Vorgang')
us.transformation.origin[0] = 300.0 # verschoben
model.beobachter.first.onTransactionCommit(model)
t_us = texte(model).find { |t| t.text == 'USS1' }
check((t_us.point[0] - (mitte[0] + 200.0)).abs < 1e-6, "verschoben: Text folgt (#{t_us.point[0]})")
check(model.operationen.last[3] == true, 'Anpassung hängt sich an den Vorgang davor (transparent)')
us.definition.set_attribute(S::JT_DICT, 'schrank', 'USS7') # neues Kürzel
model.beobachter.first.onTransactionCommit(model)
check(texte(model).map(&:text).sort == %w[HS1 USS7], "neues Kürzel: #{texte(model).map(&:text)}")
us2 = UnterschrankSchubladen.erstellen({})
model.beobachter.first.onTransactionCommit(model)
check(texte(model).size == 3, 'neuer Schrank bekommt einen Text')
model.entities.instances.delete(us2)
model.beobachter.first.onTransactionCommit(model)
check(texte(model).size == 2 && model.entities.grep(Sketchup::Group).size == 1, 'gelöschter Schrank: Text weg, eine Gruppe')

# --- Schrank in einer Gruppe: Weltkoordinaten ---
huelle = model.entities.add_group
def huelle.transformation = Geom::Transformation.translation([0, 1000.0, 0])
innen = huelle.entities.add_instance(us.definition, Geom::Transformation.translation([0, 0, 0]))
model.beobachter.first.onTransactionCommit(model)
t_in = texte(model).select { |t| t.text == 'USS7' }.map(&:point).find { |p| p[1] > 900 }
check(t_in && (t_in[1] - (1000.0 + mitte[1])).abs < 1e-6, "Schrank in Gruppe: Text an Weltposition (#{t_in})")
huelle.entities.instances.delete(innen)
model.entities.instances.delete(huelle)
model.beobachter.first.onTransactionCommit(model)

# --- gedrehter Schrank (Rückwand nach -y): Text vor der Front auf der anderen Seite ---
gedreht = model.entities.add_instance(hs.definition, Geom::Transformation.axes(Geom::Point3d.new(0, 2000.0, 0), [-1, 0, 0], [0, -1, 0], [0, 0, 1]))
model.beobachter.first.onTransactionCommit(model)
t_g = texte(model).map(&:point).find { |p| p[1] > 1500 }
check(t_g && (t_g[1] - (2000.0 - soll_hs[1] + ho[1])).abs < 1e-6 && (t_g[0] + (soll_hs[0] - ho[0])).abs < 1e-6,
      "gedrehter Schrank: Text vor seiner Front (#{t_g})")
v_g = texte(model).find { |t| t.point[1] > 1500 }.vector
check(v_g.zip([-100, 200, 150]).all? { |a, b| (a - b / 25.4).abs < 1e-6 }, "gedrehter Schrank: Pfeil dreht mit (#{v_g})")
model.entities.instances.delete(gedreht)
model.beobachter.first.onTransactionCommit(model)

# --- ausschalten: Szenen blenden aus, nichts mehr nachziehen ---
check(B.umschalten(model) == false && !B.an?(model), 'Umschalten: aus')
check(model.pages['Planung'].sichtbar['Beschriftung'] == false && model.pages['Zuschnitt'].sichtbar['Beschriftung'] == false,
      'aus: Planung und Zuschnitt blenden aus')
check(!model.layers['Beschriftung'].visible, 'aus: aktuelle Ansicht blendet aus')
ops = model.operationen.size
us.transformation.origin[0] = 500.0
model.beobachter.first.onTransactionCommit(model)
check(model.operationen.size == ops, 'aus: Beschriftung zieht nicht nach')
B.umschalten(model)
check((texte(model).find { |t| t.text == 'USS7' }.point[0] - (mitte[0] + 400.0)).abs < 1e-6, 'wieder ein: neu aufgebaut')

# --- aktuelle Szene Kunde: Tag bleibt dort ausgeblendet ---
B.umschalten(model)
model.pages.selected_page = model.pages['Kunde']
B.umschalten(model)
check(!model.layers['Beschriftung'].visible && model.pages['Planung'].sichtbar['Beschriftung'], 'in Szene Kunde eingeschaltet: dort unsichtbar, Planung zeigt sie')

# --- ohne Szenen und ohne Schränke: Hinweis ---
leer = Sketchup.active_model = Sketchup::Model.new
B.umschalten(leer)
check($meldungen&.last.to_s.include?('Keine Schränke') && $meldungen.last.include?('Planung und Zuschnitt fehlt'),
      "Hinweis ohne Schränke und Szenen: #{$meldungen&.last}")
check(B.gruppe(leer).nil?, 'ohne Schränke keine Gruppe')

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
