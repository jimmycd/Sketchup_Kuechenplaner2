# Test ohne SketchUp: Beschläge im Modell zeigen (Beschlagmodell) – LEGRABOX-Zargen, Korpusschienen,
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
%w[unterschrank_schubladen oberschrank oberschrank_klappe unterschrank_doppeltuer hochschrank].each do |k|
  load File.join(komp, "#{k}/src/#{k}/main.rb")
end
load File.expand_path('../src/jt_schrank_cnc/main.rb', __dir__)

S = JTools::SchrankCnc
B = S::Beschlagmodell
MM = 25.4
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

# Alle Beschlag-Körper als [Name, Pfad, Gruppe] mit Welt-Ecken (mm)
def koerper(model)
  out = []
  lauf = lambda do |ents, pfad|
    S::Schraenke.instanzen(ents).each do |i|
      if B.gruppe?(i)
        m = S::Geometrie.welt(pfad)
        i.entities.grep(Sketchup::Group).each do |k|
          pts = k.entities.flaechen.flatten(1).map { |p| S::Geometrie.punkt(m, p).map { |v| v * MM } }
          out << { name: k.name, mat: k.material&.name, pfad: pfad, pts: pts, layer: k.layer&.name, gruppe: i }
        end
        next
      end
      lauf.(S::Schraenke.definition(i).entities, pfad + [i])
    end
  end
  lauf.(model.entities, [])
  out
end

def grenzen(pts) = (0..2).map { |a| pts.map { |p| p[a] }.minmax }

model = Sketchup.active_model = Sketchup::Model.new
uss = UnterschrankSchubladen.erstellen({ 'Breite' => 60.0, 'Tiefe' => 52.0, 'Anz_Schubladen' => 3,
                                         'Anteil_1' => 1.0, 'Anteil_2' => 1.0, 'Anteil_3' => 2.0 })
os = Oberschrank.erstellen({})
kl = OberschrankKlappe.erstellen({})
usd = UnterschrankDoppeltuer.erstellen({})
hs = Hochschrank.erstellen({})

# Vorher: TCN, Stückliste, Beschlagliste
vorher_ws = []
vorher, = S::Export.erzeugen(model, alle_ws: vorher_ws)
vorher_bl = S::Beschlaege.liste(vorher_ws)

check(!B.an?(model), 'anfangs aus')
check(B.umschalten(model) == true && B.an?(model), 'eingeschaltet')
k = koerper(model)
check(!k.empty?, 'Beschläge gezeichnet')
check(k.all? { |x| x[:layer] == 'Beschlag' }, 'alle auf Tag Beschlag')
check(k.all? { |x| x[:mat].to_s.start_with?('Beschlag ') }, 'Beschlag-Materialien')

# --- Nichts davon in TCN, Stückliste, Beschlagliste ---
nachher_ws = []
nachher, = S::Export.erzeugen(model, alle_ws: nachher_ws)
check(vorher.map { |d| [d.name, d.text, d.anzahl] } == nachher.map { |d| [d.name, d.text, d.anzahl] }, 'TCN-Export unverändert')
check(S::Beschlaege.liste(nachher_ws).map(&:to_a) == vorher_bl.map(&:to_a), 'Beschlagliste unverändert')
check(S::Schraenke.teile(model).none? { |t| t.rolle.nil? }, 'keine Beschläge unter den Teilen')
check(S::Stueckliste.zeilen(nachher).size == S::Stueckliste.zeilen(vorher).size, 'Stückliste unverändert')

# --- Schubladen: je sichtbarer Schublade 2 Zargen, 2 Fronthalter, 2 Rückwandhalter in der Schublade ---
uss_k = k.select { |x| x[:pfad].first == uss }
(1..3).each do |i|
  sk = uss_k.select { |x| x[:name].end_with?(" S#{i}") && !x[:name].start_with?('Korpusschiene') }
  check(sk.count { |x| x[:name].start_with?('Zarge') } == 2, "S#{i}: 2 Zargen (#{sk.map { |x| x[:name] }})")
  check(sk.count { |x| x[:name].start_with?('Fronthalter') } == 2, "S#{i}: 2 Fronthalter")
  check(sk.count { |x| x[:name].start_with?('Rückwandhalter') } == 2, "S#{i}: 2 Rückwandhalter")
  check(sk.all? { |x| x[:pfad].last.name == "Schublade#{i}" }, "S#{i}: Beschläge bewegen sich mit der Schublade")
  schienen = uss_k.select { |x| x[:name].start_with?('Korpusschiene') && x[:name].end_with?("S#{i}") }
  check(schienen.size == 2 && schienen.all? { |x| x[:pfad] == [uss] }, "S#{i}: 2 Korpusschienen fest im Schrank")
end
check(uss_k.none? { |x| x[:name].end_with?(' S4') }, 'ausgeblendete Schublade ohne Beschläge')

# Zargenhöhe wie Regeln.zarge, Unterkante = Kastenunterkante, Zarge neben dem Boden, Länge NL − 1
kaesten = S::Regeln.kaesten(nachher_ws.select { |w| w.teil.pfad.first == uss })
kaesten.each do |kasten|
  boden = kasten.find { |w| w.rolle == 'KastenBoden' }
  b = boden.teil.jt('bereich')
  m = S::Regeln.zarge(kasten)
  z = uss_k.find { |x| x[:name] == "Zarge #{m} links #{b}" }
  check(z, "#{b}: Zarge #{m} links")
  next unless z
  g = grenzen(z[:pts])
  check((g[2][1] - g[2][0] - S::Regeln::ZARGEN[m][:hoehe]).abs < 0.01, "#{b}: Zarge #{S::Regeln::ZARGEN[m][:hoehe]} hoch (#{g[2]})")
  check((g[2][0] - kasten.map { |w| w.lo[2] }.min).abs < 0.01, "#{b}: Zarge ab Kastenunterkante")
  check(g[0][1] <= boden.lo[0] + 0.01 && (g[0][1] - g[0][0] - 12.8).abs < 0.01, "#{b}: Zarge 12,8 neben dem Boden (#{g[0]})")
  nl = S::Schraenke.dc(uss, 'nl').to_f * MM
  check((g[1][1] - g[1][0] - (nl - 1)).abs < 0.01, "#{b}: Zarge NL − 1 lang (#{g[1]}, NL #{nl})")
  sch = uss_k.find { |x| x[:name].start_with?('Korpusschiene') && x[:name].end_with?(b) }
  zs = nachher_ws.flat_map(&:ops).select { |o| o.titel == "Schiene #{b}" }.map { |o| o.p0[2] }.uniq
  check(sch && zs.size == 1 && (grenzen(sch[:pts])[2].sum / 2.0 - zs[0]).abs < 0.01, "#{b}: Schiene auf Höhe der Bohrungen")
end

# --- Alles innerhalb des Schranks (Komponentengrenzen) ---
[uss, os, kl, usd, hs].each do |s|
  teile = nachher_ws.select { |w| w.teil.pfad.first == s }
  lo = (0..2).map { |a| teile.map { |w| w.lo[a] }.min }
  hi = (0..2).map { |a| teile.map { |w| w.hi[a] }.max }
  k.select { |x| x[:pfad].first == s }.each do |x|
    g = grenzen(x[:pts])
    check((0..2).all? { |a| g[a][0] >= lo[a] - 0.01 && g[a][1] <= hi[a] + 0.01 },
          "#{S::Schraenke.definition(s).get_attribute('JT_Schrank', 'schrank')} #{x[:name]} innerhalb des Schranks (#{g} / #{lo} #{hi})")
  end
end

# --- Topfbänder: je Topfband-Bohrung ein Topf und ein Arm, an der Seite eine Montageplatte ---
[os, usd, hs].each do |s|
  tueren = nachher_ws.select { |w| w.teil.pfad.first == s && w.rolle == 'Tuer' }
  n = tueren.sum { |t| t.ops.count { |o| o.art == :topfband } }
  sk = k.select { |x| x[:pfad].first == s }
  check(n >= 2, "#{s.name}: Topfbänder gebohrt (#{n})")
  check(sk.count { |x| x[:name].end_with?('Topf') } == n, "#{s.name}: #{n} Töpfe")
  check(sk.count { |x| x[:name].end_with?('Arm') } == n, "#{s.name}: #{n} Arme")
  check(sk.select { |x| x[:name].end_with?('Arm') || x[:name].start_with?('Montageplatte') }.all? { |x| x[:pfad] == [s] },
        "#{s.name}: Arm und Montageplatte fest im Schrank (bleiben beim Öffnen an der Seite)")
  check(sk.count { |x| x[:name].start_with?('Montageplatte') } == n, "#{s.name}: #{n} Montageplatten")
  # Topf: Ø35 um die Topfmitte, 13 tief in der Tür
  tueren.each do |t|
    t.ops.select { |o| o.art == :topfband }.each do |o|
      topf = sk.select { |x| x[:name].end_with?('Topf') }.find do |x|
        g = grenzen(x[:pts])
        (0..2).all? { |a| o.p0[a].between?(g[a][0] - 0.01, g[a][1] + 0.01) }
      end
      check(topf, "#{t.name}: Topf an der Bohrung #{o.p0}")
      next unless topf
      g = grenzen(topf[:pts])
      da = S::Geometrie.achse(o.seite)
      check((g[da][1] - g[da][0] - 13).abs < 0.01 && g.each_with_index.reject { |_, a| a == da }.all? { |(a0, a1), _| (a1 - a0 - 35).abs < 0.01 },
            "#{t.name}: Topf Ø35 × 13 (#{g})")
      check((0..2).all? { |a| g[a][0] >= t.lo[a] - 0.01 && g[a][1] <= t.hi[a] + 0.01 }, "#{t.name}: Topf ganz in der Tür (Maße der Tür bleiben)")
      check(topf[:pfad].last.equal?(t.teil.inst), "#{t.name}: Topf steckt in der Tür (dreht sich mit)")
    end
  end
  # Montageplatte: liegt an der Innenseite der Seite, um die beiden Löcher Ø5
  platten = nachher_ws.select { |w| w.teil.pfad.first == s && w.rolle == 'Seite' }.flat_map(&:ops)
                      .select { |o| o.titel == 'Montageplatte Topfband' }
  platten.each do |o|
    check(sk.any? do |x|
      x[:name].start_with?('Montageplatte') && (g = grenzen(x[:pts])) && (0..2).all? { |a| o.p0[a].between?(g[a][0] - 0.01, g[a][1] + 0.01) }
    end, "Montageplatte über dem Loch #{o.p0}")
  end
end

# --- AVENTOS HK-top: Kraftspeicher an beiden Seiten, 2 Frontbeschläge ---
kk = k.select { |x| x[:pfad].first == kl }
check(kk.count { |x| x[:name] == 'Kraftspeicher AVENTOS HK-top' } == 2, "Klappe: 2 Kraftspeicher (#{kk.map { |x| x[:name] }})")
check(kk.count { |x| x[:name] == 'Frontbeschlag AVENTOS HK-top' } == 2, 'Klappe: 2 Frontbeschläge')
arme = kk.select { |x| x[:name] == 'Hebelarm AVENTOS HK-top' }
check(arme.size == 2, "Klappe: 2 Hebelarme (#{arme.size})")
kraft = kk.select { |x| x[:name] == 'Kraftspeicher AVENTOS HK-top' }.map { |x| grenzen(x[:pts]) }
front = kk.select { |x| x[:name] == 'Frontbeschlag AVENTOS HK-top' }.map { |x| grenzen(x[:pts]) }
beruehrt = ->(g, h) { (0..2).all? { |a| g[a][0] <= h[a][1] + 0.01 && h[a][0] <= g[a][1] + 0.01 } }
arme.each do |a|
  g = grenzen(a[:pts])
  check(kraft.any? { |h| beruehrt.(g, h) } && front.any? { |h| beruehrt.(g, h) }, "Hebelarm verbindet Kraftspeicher und Frontbeschlag (#{g})")
end

# --- Nachziehen: unverändert -> nichts neu; Option geändert -> neu ---
gruppen = B.alle_gruppen(model.entities)
B.nachziehen(model)
check(B.alle_gruppen(model.entities).map(&:object_id).sort == gruppen.map(&:object_id).sort, 'unverändert: Gruppen bleiben')
uss.set_attribute('dynamic_attributes', 'anz_schubladen', 2.0)
B.nachziehen(model)
neu = B.alle_gruppen(model.entities)
check(neu.size == gruppen.size && B.alle_gruppen(S::Schraenke.definition(uss).entities).size == 4, 'geänderter Schrank neu bestückt (1 Schrank + 3 Schubladen)')
check(neu.count { |g| !gruppen.include?(g) } == 0, 'Geometrie gleich -> Gruppen bleiben (Signatur)')
# andere Lage einer Schublade (DC hat neu gerechnet) -> neue Gruppe
sl = S::Schraenke.definition(uss).entities.instances.find { |i| i.name == 'Schublade1' }
sl.transformation.origin[2] -= 1.0
uss.set_attribute('dynamic_attributes', 'anz_schubladen', 3.0)
B.nachziehen(model)
check(B.alle_gruppen(model.entities).count { |g| !gruppen.include?(g) } >= 1, 'verschobene Schublade: Beschläge neu')
# keine doppelten Gruppen je Behälter
beh = B.alle_gruppen(model.entities).group_by(&:parent)
check(beh.values.all? { |l| l.size == 1 }, 'je Behälter eine Beschlag-Gruppe')

# --- Offene Tür (Interagieren): Beschläge bleiben, wie sie sind ---
os_gr = B.alle_gruppen(S::Schraenke.definition(os).entities).map(&:object_id).sort
halter = S::Schraenke.definition(os).entities.instances.find { |i| i.name.to_s.include?('Halter') && !i.hidden }
check(halter, 'Oberschrank: Türhalter gefunden')
if halter
  halter.instance_variable_set(:@transformation, Geom::Transformation.axes(halter.transformation.origin, [0, 1, 0], [-1, 0, 0], [0, 0, 1]))
  check(!B.geschlossen?(B.werkstuecke(model, os)), 'gedrehte Tür erkannt')
  check(B.schrank_aktualisieren(model, os).nil?, 'offene Tür: nicht neu berechnet')
  check(B.alle_gruppen(S::Schraenke.definition(os).entities).map(&:object_id).sort == os_gr, 'offene Tür: Beschläge unverändert')
  halter.instance_variable_set(:@transformation, Geom::Transformation.translation(halter.transformation.origin))
end
check(B.geschlossen?(B.werkstuecke(model, os)), 'geschlossene Tür erkannt')

# --- Inverse ---
m = [0.0, 1, 0, 0, -2, 0, 0, 0, 0, 0, 1, 0, 5, 6, 7, 1]
inv = B.invers(m)
p = [1.0, 2.0, 3.0]
q = S::Geometrie.punkt(inv, S::Geometrie.punkt(m, p))
check(q.zip(p).all? { |a, b| (a - b).abs < 1e-9 }, "Inverse (#{q})")

# --- Aus: alles weg ---
check(B.umschalten(model) == false && !B.an?(model), 'ausgeschaltet')
check(B.alle_gruppen(model.entities).empty?, 'alle Beschläge entfernt')

if $fehler.zero?
  puts 'Beschlagmodell: alle Tests OK'
else
  puts "Beschlagmodell: #{$fehler} Fehler"
  exit 1
end
