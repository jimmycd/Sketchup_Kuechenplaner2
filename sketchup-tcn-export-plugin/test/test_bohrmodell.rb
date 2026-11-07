# Test ohne SketchUp: Bohrungen, Dübel und Schrauben im Modell (Bohrmodell, Jürgen 2026-11-07) und
# Röntgen-Schalter: gleiche Bohrungen wie im TCN, ganz in der Platte, nicht in Stückliste/TCN, ein/aus.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'

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

# Darstellung und Bearbeitungsebene für das Röntgen
module Sketchup
  class Model
    def rendering_options = (@ro ||= { 'ModelTransparency' => false, 'InactiveHidden' => false })
    attr_reader :active_path
    def active_path=(p)
      raise ArgumentError, 'ungültiger Pfad' if p && p.any? { |e| !e.respond_to?(:definition) && !e.is_a?(Group) }
      @active_path = p
    end
  end
  class ComponentInstance
    def valid? = true
  end
end

komp = File.expand_path('../../Komponenten', __dir__)
%w[unterschrank_schubladen oberschrank unterschrank_doppeltuer oberschrank_klappe blenden].each do |k|
  load File.join(komp, "#{k}/src/#{k}/main.rb")
end
load File.expand_path('../src/jt_schrank_cnc/main.rb', __dir__)

S = JTools::SchrankCnc
BM = S::Bohrmodell
R = S::Roentgen
MM = 25.4
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

# Untergruppen der Bohrungs-Gruppen: { art:, pfad:, n: Zylinder, pts: Welt-Ecken je Zylinder }
def koerper(model)
  out = []
  lauf = lambda do |ents, pfad|
    S::Schraenke.instanzen(ents).each do |i|
      if BM.gruppe?(i)
        m = S::Geometrie.welt(pfad)
        i.entities.grep(Sketchup::Group).each do |k|
          fl = k.entities.flaechen.map { |f| f.map { |p| S::Geometrie.punkt(m, p).map { |v| v * MM } } }
          # Zylinder: 2 Deckel + 16 Mantelflächen, Quader: 6 Flächen
          je = k.name == 'Fräsungen' ? 6 : 18
          zyl = fl.each_slice(je).map { |s| s.flatten(1) }
          out << { art: k.name, pfad: pfad, n: zyl.size, zyl: zyl, layer: k.layer&.name, mat: k.material&.name }
        end
        next
      end
      next if S::Beschlagmodell.gruppe?(i)
      lauf.(S::Schraenke.definition(i).entities, pfad + [i])
    end
  end
  lauf.(model.entities, [])
  out
end

def grenzen(pts) = (0..2).map { |a| pts.map { |p| p[a] }.minmax }
def innen?(g, lo, hi, tol = 0.01) = (0..2).all? { |a| g[a][0] >= lo[a] - tol && g[a][1] <= hi[a] + tol }

model = Sketchup.active_model = Sketchup::Model.new
uss = UnterschrankSchubladen.erstellen({ 'Breite' => 60.0, 'Tiefe' => 52.0, 'Anz_Schubladen' => 3,
                                         'Anteil_1' => 1.0, 'Anteil_2' => 1.0, 'Anteil_3' => 2.0 })
os = Oberschrank.erstellen({})
usd = UnterschrankDoppeltuer.erstellen({})
kl = OberschrankKlappe.erstellen({})

vorher, = S::Export.erzeugen(model)

check(!BM.an?(model), 'anfangs aus')
check(BM.umschalten(model) == true && BM.an?(model), 'eingeschaltet')
k = koerper(model)
check(!k.empty?, 'Bohrungen gezeichnet')
check(k.all? { |x| x[:layer] == 'Bohrungen' }, 'alle auf Tag Bohrungen')
check(%w[Bohrungen Dübel Schrauben].all? { |a| k.any? { |x| x[:art] == a } }, "Bohrungen, Dübel und Schrauben da (#{k.map { |x| x[:art] }.uniq})")

# --- Nichts davon in TCN und Stückliste ---
ws = []
nachher, = S::Export.erzeugen(model, alle_ws: ws)
check(vorher.map { |d| [d.name, d.text, d.anzahl] } == nachher.map { |d| [d.name, d.text, d.anzahl] }, 'TCN-Export unverändert')
check(S::Schraenke.teile(model).none? { |t| t.rolle.nil? }, 'keine Bohrungen unter den Teilen')
check(S::Stueckliste.zeilen(nachher).size == S::Stueckliste.zeilen(vorher).size, 'Stückliste unverändert')

# --- Je Teil: so viele Löcher wie im TCN, alle ganz in der Platte (Deckel unter der Oberfläche) ---
loecher = k.select { |x| x[:art] == 'Bohrungen' }.flat_map { |x| x[:zyl].map { |pts| grenzen(pts) } }
gesamt = 0
ws.each do |w|
  soll = w.ops.sum do |o|
    case o.art
    when :bohrung, :reihe then BM.punkte(o).size
    when :topfband then o.daten && o.daten[:schraub] ? 3 : 1
    else 0
    end
  end
  gesamt += soll
  next if soll.zero?
  n = k.select { |x| x[:art] == 'Bohrungen' && x[:pfad].first == w.teil.pfad.first }
       .sum { |x| x[:zyl].count { |pts| innen?(grenzen(pts), w.lo, w.hi, -0.1) } }
  check(n == soll, "#{w.name}: #{soll} Löcher ganz in der Platte (#{n})")
end
check(loecher.size == gesamt, "keine Löcher außerhalb der Platten (#{loecher.size} / #{gesamt})")
# Seiten (gemeinsame Definition links/rechts) im Schrank, Fronten in sich selbst
front = ws.find { |w| w.teil.pfad.first == uss && w.rolle == 'Front' && w.ops.any? }
check(k.any? { |x| x[:art] == 'Bohrungen' && x[:pfad] == front.teil.pfad }, "Front: Löcher in der Front (#{front.teil.pfad.map(&:name)})")
check(k.any? { |x| x[:art] == 'Bohrungen' && x[:pfad] == [uss] }, 'Seiten: Löcher im Schrank')

# Lochreihe: Ø5 × 12 an der ersten Bohrung der Reihe, 0,2 unter der Oberfläche
seite = ws.find { |w| w.teil.pfad.first == os && w.rolle == 'Seite' && w.ops.any? { |o| o.art == :reihe && o.d == 5 } }
o = seite.ops.find { |x| x.art == :reihe && x.d == 5 }
ax = S::Geometrie.achse(o.seite)
g = loecher.find { |h| (0..2).all? { |a| a == ax || o.p0[a].between?(h[a][0], h[a][1]) } && innen?(h, seite.lo, seite.hi) }
check(g && (g[ax][1] - g[ax][0] - 11.8).abs < 0.01, "Lochreihe 12 tief (0,2 unter der Oberfläche) #{g}")
quer = ([0, 1, 2] - [ax])
check(g && quer.all? { |a| (g[a][1] - g[a][0] - 5.1).abs < 0.01 }, "Lochreihe Ø5 (#{g})")

# --- Dübel: je Dübelbohrung in der Stirnseite einer, 35 lang, halb im Boden, halb in der Seite ---
duebel_soll = ws.sum { |w| w.ops.select { |x| x.titel.to_s.start_with?('Duebel ') && S::Geometrie.achse(x.seite) != w.dicke_achse }.sum { |x| BM.punkte(x).size } }
dk = k.select { |x| x[:art] == 'Dübel' }
check(dk.sum { |x| x[:n] } == duebel_soll && duebel_soll > 0, "#{duebel_soll} Dübel (#{dk.sum { |x| x[:n] }})")
dk.flat_map { |x| x[:zyl] }.each do |pts|
  g = grenzen(pts)
  l = g.map { |a, c| c - a }.max
  check((l - 34.4).abs < 0.01, "Dübel 35 lang (#{l})")
end

# --- Schrauben: Strebe (Seite) und Schraubenreihe Boden; im Schrank, nicht über die Außenfläche ---
[uss, os, usd].each do |s|
  teile = ws.select { |w| w.teil.pfad.first == s }
  lo = (0..2).map { |a| teile.map { |w| w.lo[a] }.min }
  hi = (0..2).map { |a| teile.map { |w| w.hi[a] }.max }
  k.select { |x| x[:pfad].first == s }.each do |x|
    x[:zyl].each { |pts| check(innen?(grenzen(pts), lo, hi), "#{s.name} #{x[:art]} innerhalb des Schranks") }
  end
end
sk = k.select { |x| x[:art] == 'Schrauben' }
sch_soll = ws.sum { |w| w.ops.select { |x| x.titel.to_s.start_with?('Schraube ') }.sum { |x| BM.punkte(x).size } }
check(sk.sum { |x| x[:n] } == 2 * sch_soll && sch_soll > 0, "#{sch_soll} Schrauben mit Kopf (#{sk.sum { |x| x[:n] }} Körper)")

# --- Topfband: Topf Ø35 und 2 Dübellöcher in der Tür, in der Tür selbst (dreht sich mit) ---
tuer = ws.find { |w| w.teil.pfad.first == os && w.rolle == 'Tuer' }
tb = tuer.ops.select { |x| x.art == :topfband }
toepfe = k.select { |x| x[:art] == 'Bohrungen' && x[:pfad] == tuer.teil.pfad }.flat_map { |x| x[:zyl].map { |pts| grenzen(pts) } }.select { |h| innen?(h, tuer.lo, tuer.hi) && h.count { |a, c| (c - a - 35.1).abs < 0.01 } == 2 }
check(tb.size >= 2 && toepfe.size == tb.size, "Tür: Topf Ø35 je Band (#{toepfe.size} / #{tb.size})")
tws = ws.select { |w| w.teil.pfad.first == os && w.rolle == 'Tuer' }
check(tws.all? { |t| k.any? { |x| x[:art] == 'Bohrungen' && x[:pfad] == t.teil.pfad } }, 'Topfbohrungen in der Tür selbst')

# --- Nachziehen: unverändert -> Gruppen bleiben; je Behälter eine Gruppe ---
gruppen = BM.alle_gruppen(model.entities)
BM.nachziehen(model)
check(BM.alle_gruppen(model.entities).map(&:object_id).sort == gruppen.map(&:object_id).sort, 'unverändert: Gruppen bleiben')
uss.set_attribute('dynamic_attributes', 'anz_schubladen', 2.0)
BM.nachziehen(model)
check(BM.alle_gruppen(model.entities).group_by(&:parent).values.all? { |l| l.size == 1 }, 'je Behälter eine Bohrungs-Gruppe')
check(BM.alle_gruppen(model.entities).size == gruppen.size, 'gleiche Geometrie: nicht neu gezeichnet')
check(uss.get_attribute(BM::DICT, 'fingerabdruck') == BM.fingerabdruck(uss), 'Fingerabdruck nachgeführt')

# --- Rendern lässt den Tag weg ---
check(S::Rendern::NIE.include?('Bohrungen'), 'Rendern: Tag Bohrungen nie im Bild')

# --- Aus: alles weg ---
check(BM.umschalten(model) == false && !BM.an?(model), 'ausgeschaltet')
check(koerper(model).empty?, 'Bohrungen entfernt')

# --- Röntgen ---
ro = model.rendering_options
check(!R.an?(model), 'Röntgen anfangs aus')
model.selection.clear
model.selection << os
check(R.umschalten(model) == true && R.an?(model), 'Röntgen an')
check(ro['ModelTransparency'] == true && ro['InactiveHidden'] == true, 'Röntgen: Transparenz und Rest ausgeblendet')
check(model.active_path == [os] && R.isoliert?(model), 'Röntgen: gewählter Schrank geöffnet')
# solange geöffnet: Bohrungen/Beschläge rechnen nicht
BM.setzen(model, true)
n = BM.alle_gruppen(model.entities).size
os.set_attribute('dynamic_attributes', 'breite', 99.0)
BM.nachziehen(model)
check(os.get_attribute(BM::DICT, 'fingerabdruck') != BM.fingerabdruck(os), 'Röntgen: kein Nachrechnen im geöffneten Schrank')
check(R.umschalten(model) == false && !R.an?(model), 'Röntgen aus')
check(ro['ModelTransparency'] == false && ro['InactiveHidden'] == false && model.active_path.nil?, 'Röntgen aus: Ansicht wie vorher')
check(os.get_attribute(BM::DICT, 'fingerabdruck') == BM.fingerabdruck(os), 'Röntgen aus: liegen gebliebenes nachgerechnet')
check(BM.alle_gruppen(model.entities).size >= n - 1, 'Bohrungen nach dem Röntgen noch da')
# vorher eingeschaltete Darstellung bleibt nach dem Ausschalten
ro['InactiveHidden'] = true
model.selection.clear
model.selection << os
model.selection << usd
R.umschalten(model)
check(ro['ModelTransparency'] == true && model.active_path.nil? && !R.isoliert?(model), 'mehrere gewählt: ganzes Modell geröntgt')
R.umschalten(model)
check(ro['ModelTransparency'] == false && ro['InactiveHidden'] == true, 'Röntgen aus: vorherige Einstellung zurück')
# Export schaltet Röntgen aus
model.selection.clear
model.selection << os
R.umschalten(model)
R.zuruecksetzen(model)
check(!R.an?(model) && model.active_path.nil?, 'zurücksetzen (Export/Rendern): Röntgen aus')

puts $fehler.zero? ? 'test_bohrmodell: alles OK' : "test_bohrmodell: #{$fehler} Fehler"
exit($fehler.zero? ? 0 : 1)
