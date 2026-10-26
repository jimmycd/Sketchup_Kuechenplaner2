# Test ohne SketchUp: Mock-API + kleiner DC-Formel-Auswerter.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
load File.expand_path('../src/apothekerschrank/main.rb', __dir__)

A = Apothekerschrank
EPS = 1e-6
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

class Knoten
  attr_reader :inst, :defn, :parent, :kinder
  def initialize(inst, defn, parent)
    @inst, @defn, @parent = inst, defn, parent
    @werte = {}
    @kinder = defn.entities.instances.map { |ci| Knoten.new(ci, ci.definition, self) }
  end

  def name = inst&.get_attribute(A::DICT, '_name') || defn.get_attribute(A::DICT, '_name')

  def roh(attr)
    k = attr.downcase
    return @werte[k] if @werte.key?(k)
    v = inst&.get_attribute(A::DICT, k)
    v = defn.get_attribute(A::DICT, k) if v.nil?
    v = inst.transformation.origin[%w[x y z].index(k)] if v.nil? && inst && %w[x y z].include?(k)
    raise "Attribut #{attr} fehlt an #{name}" if v.nil?
    fu = defn.get_attribute(A::DICT, "_#{k}_formulaunits")
    %w[x y z lenx leny lenz].include?(k) || fu == 'CENTIMETERS' ? v * 2.54 : v
  end

  def formel(k) = inst&.get_attribute(A::DICT, "_#{k}_formula") || defn.get_attribute(A::DICT, "_#{k}_formula")

  def ref(n, attr)
    ziel = parent && parent.name == n ? parent : (parent ? parent.kinder : []).find { |s| s.name == n }
    raise "Referenz #{n}!#{attr} von #{name} nicht auflösbar" unless ziel
    ziel.roh(attr)
  end

  def IF(c, a, b) = c ? a : b
  def AND(*a) = a.all?
  def OR(*a) = a.any?
  def INT(x) = x.floor.to_f
  def MIN(*a) = a.min
  def MAX(*a) = a.max

  def auswerten(f)
    ruby = f.gsub(/(?<![<>=!])=(?!=)/, '==').gsub(/(\w+)!(\w+)|\b([A-Za-z_]\w*)\b(?!\s*\()/) do
      $1 ? "ref(#{$1.inspect},#{$2.inspect})" : "roh(#{$3.inspect})"
    end
    v = instance_eval(ruby)
    v == true ? 1.0 : (v == false ? 0.0 : v.to_f)
  end

  def schluessel
    keys = (defn.attribute_dictionary(A::DICT)&.keys || []) + (inst&.attribute_dictionary(A::DICT)&.keys || [])
    keys.grep(/\A_(.+)_formula\z/) { $1 }.uniq.sort
  end

  def redraw
    schluessel.each { |k| @werte[k] = auswerten(formel(k)) }
    kinder.each(&:redraw)
  end

  def wert(k) = roh(k)
  def hidden? = (defn.get_attribute(A::DICT, '_hidden_formula') ? wert('hidden') > 0.5 : false)
  def pos(ax) = (formel(ax) ? wert(ax) : inst.transformation.origin[%w[x y z].index(ax)] * 2.54)
end

# Absolute Quader [x0,x1,y0,y1,z0,z1] aller Blatt-Teile, mit Sichtbarkeit
def teile(k, off = [0, 0, 0], versteckt = false, out = [])
  k.kinder.each do |c|
    o = off.each_with_index.map { |v, i| v + c.pos(%w[x y z][i]) }
    vs = versteckt || c.hidden?
    if c.kinder.empty?
      l = %w[lenx leny lenz].map { |a| c.formel(a) ? c.wert(a) : c.defn.box[%w[lenx leny lenz].index(a)] * 2.54 }
      out << { name: c.name, knoten: c, pfad: "#{k.name}/#{c.name}", q: [o[0], o[0] + l[0], o[1], o[1] + l[1], o[2], o[2] + l[2]],
               hidden: vs, bereich: c.inst.get_attribute(A::JT_DICT, 'bereich') }
    else
      teile(c, o, vs, out)
    end
  end
  out
end

def pruefe_geometrie(k, label)
  if k.inst && k.parent
    o = k.inst.transformation.origin.map { |v| v * 2.54 }
    %w[x y z].each_with_index do |ax, i|
      next unless k.formel(ax)
      check((o[i] - k.wert(ax)).abs < EPS, "#{label}: #{k.name}.#{ax} gezeichnet #{o[i]} vs Formel #{k.wert(ax)}")
    end
    %w[lenx leny lenz].each_with_index do |ax, i|
      next unless k.defn.box && k.formel(ax)
      check((k.defn.box[i] * 2.54 - k.wert(ax)).abs < EPS, "#{label}: #{k.name}.#{ax} gezeichnet vs Formel")
    end
    check(!!k.inst.hidden == k.hidden?, "#{label}: #{k.name} hidden gezeichnet vs Formel")
  end
  k.kinder.each { |c| pruefe_geometrie(c, label) }
end

def ueberlapp?(a, b) = (0..2).all? { |i| a[2 * i] < b[2 * i + 1] - EPS && b[2 * i] < a[2 * i + 1] - EPS }

def pruefe(w, p, label)
  b, h, t = p['Breite'], p['Hoehe'], p['Tiefe']
  mk, sp = 1.9, 0.2
  nf = p['Anz_Fronten'].to_i
  ht = p['H_Teilung']
  au, ao = p['Kasten_Abstand_unten'], p['Kasten_Abstand_oben']
  alle = teile(w)
  sichtbar = alle.reject { |t2| t2[:hidden] }

  # Auswahlrahmen: alle Teile (auch versteckte) innerhalb des Schranks
  alle.each do |t2|
    q = t2[:q]
    check(q[0] >= -EPS && q[1] <= b + EPS && q[4] >= -EPS && q[5] <= h + EPS && q[2] >= -sp - EPS && q[3] <= t + mk + 0.8 + EPS,
          "#{label}: #{t2[:pfad]} außerhalb #{q.map { |v| v.round(2) }}")
  end
  # keine Kollisionen zwischen sichtbaren Teilen
  sichtbar.combination(2).each do |a, c|
    check(!ueberlapp?(a[:q], c[:q]), "#{label}: Kollision #{a[:pfad]} / #{c[:pfad]}")
  end

  # Fronten: eine über die volle Höhe oder zwei mit Fuge an der Teilung
  fronten = sichtbar.select { |t2| t2[:name] == 'Front' }.sort_by { |t2| t2[:q][4] }
  check(fronten.size == nf, "#{label}: #{fronten.size} Fronten statt #{nf}")
  fq = fronten.map { |t2| [t2[:q][4], t2[:q][5]] }
  soll = nf == 2 ? [[0, ht - sp], [ht, h]] : [[0, h]]
  check(fq.flatten.zip(soll.flatten).all? { |x, y| (x - y).abs < EPS }, "#{label}: Fronten #{fq} statt #{soll}")
  check(fronten.map { |t2| t2[:bereich] } == %w[A B].first(nf), "#{label}: Bereiche der Fronten")
  fronten.each do |t2|
    q = t2[:q]
    check((q[0] - sp / 2).abs < EPS && (q[1] - (b - sp / 2)).abs < EPS && (q[2] + sp).abs < EPS, "#{label}: #{t2[:pfad]} Lage")
  end

  # Mittelboden
  mb = alle.find { |t2| t2[:name] == 'Mittelboden' }
  mb_an = nf == 2 || p['Mittelboden'].to_i == 1
  check(mb[:hidden] == !mb_an, "#{label}: Mittelboden sichtbar #{!mb[:hidden]}")
  check((mb[:q][5] - ht).abs < EPS, "#{label}: Mittelboden an der Teilung") if nf == 2

  # Kästen je Front (LEGRABOX free): im Lochraster, gleichmäßig, im Raum zwischen den festen Böden
  nl = [65.0, ((t - 0.3) / 5 + 0.000001).floor * 5.0].min
  check((w.wert('NL') - nl).abs < EPS, "#{label}: NL #{w.wert('NL')} statt #{nl}")
  off = p['Hoehenoffset_Schiene']
  mbd, mrw = p['Materialstaerke_Kastenboden'], p['Materialstaerke_Kastenrueckwand']
  boeden_fest = sichtbar.select { |t2| %w[Boden Deckel Mittelboden].include?(t2[:name]) }
  %w[A B].first(nf).each do |f|
    n = p["Anz_Kaesten_#{f}"].to_i
    kb = sichtbar.select { |t2| t2[:name] == 'KastenBoden' && t2[:bereich].start_with?(f) }.sort_by { |t2| -t2[:q][4] }
    check(kb.size == n, "#{label}: Front #{f}: #{kb.size} Kästen statt #{n}")
    check(kb.map { |t2| t2[:bereich] } == (1..n).map { |j| "#{f}#{j}" }, "#{label}: Kasten 1 = oben (#{kb.map { |t2| t2[:bereich] }})")
    zb = f == 'A' ? mk : ht
    zt = f == 'A' && nf == 1 ? h - mk : (f == 'A' ? ht - mk : h - mk)
    abst = kb.each_cons(2).map { |x, y| x[:q][4] - y[:q][4] }
    check(abst.all? { |d| (d - abst.first).abs < EPS }, "#{label}: Front #{f}: Kästen nicht gleichmäßig #{abst}")
    check(abst.empty? || ((abst.first / 3.2) - (abst.first / 3.2).round).abs < 1e-6, "#{label}: Teilung kein Vielfaches des Rasters")
    kb.each do |k|
      q = k[:q]
      loch = (q[4] + off - p['Lochraster_Start']) / p['Lochraster']
      check((loch - loch.round).abs < 1e-6, "#{label}: #{k[:pfad]} nicht im Lochraster (#{q[4].round(3)})")
      check(q[4] >= zb + au - EPS, "#{label}: #{k[:pfad]} zu tief")
      # über jedem festen Boden darunter mindestens Kasten_Abstand_unten
      darunter = boeden_fest.map { |x| x[:q][5] }.select { |z| z <= q[4] + EPS }.max
      check(q[4] - darunter >= au - EPS, "#{label}: #{k[:pfad]} zu nah über festem Boden")
      check((q[0] - (mk + 1.75)).abs < EPS && (q[1] - (b - mk - 1.75)).abs < EPS, "#{label}: #{k[:pfad]} Breite LW-35")
      check((q[2] - mk).abs < EPS && (q[3] - (mk + nl - 1.0)).abs < EPS, "#{label}: #{k[:pfad]} Länge NL-10")
      check((q[5] - q[4] - mbd).abs < EPS, "#{label}: #{k[:pfad]} Stärke")
      kr = sichtbar.find { |t2| t2[:name] == 'KastenRueckwand' && t2[:bereich] == k[:bereich] }
      r = kr[:q]
      check((r[0] - (mk + 1.9)).abs < EPS && (r[1] - (b - mk - 1.9)).abs < EPS, "#{label}: #{kr[:pfad]} Breite LW-38")
      check((r[3] - q[3]).abs < EPS && (r[3] - r[2] - mrw).abs < EPS, "#{label}: #{kr[:pfad]} hinten am Boden")
      check((r[4] - q[5]).abs < EPS && r[5] - r[4] <= p['Hoehe_Kastenrueckwand'] + EPS, "#{label}: #{kr[:pfad]} auf dem Boden")
      check(r[5] <= zt - ao + EPS, "#{label}: #{kr[:pfad]} zu hoch")
      darueber = (boeden_fest.map { |x| x[:q][4] } + kb.map { |x| x[:q][4] }).select { |z| z > q[4] + EPS }.min
      check(darueber - r[5] >= ao - EPS, "#{label}: #{kr[:pfad]} zu nah unter dem nächsten Teil")
      [k, kr].each do |x|
        check(x[:knoten].inst.get_attribute(A::JT_DICT, 'front') == f, "#{label}: #{x[:pfad]} JT_Schrank front")
      end
    end
    # Rückwand so hoch wie möglich, höchstens Hoehe_Kastenrueckwand
    check(sichtbar.select { |t2| t2[:name] == 'KastenRueckwand' && t2[:bereich].start_with?(f) }
                  .all? { |x| (x[:q][5] - x[:q][4] - [p['Hoehe_Kastenrueckwand'], abst.first - ao - (f == 'A' && nf == 1 && p['Mittelboden'].to_i == 1 ? au + mk : 0) - mbd].min).abs < EPS },
          "#{label}: Front #{f}: Höhe Kastenrückwand")
  end
  check(sichtbar.count { |t2| t2[:name] == 'KastenBoden' } == %w[A B].first(nf).sum { |f| p["Anz_Kaesten_#{f}"].to_i },
        "#{label}: keine Kästen an versteckter Front")
  fronten.map { |t2| t2[:q][4..5] } + [sichtbar.select { |t2| t2[:name] == 'KastenBoden' }.map { |t2| t2[:q][4].round(1) }.sort]
end

KANTEN_SOLL = {
  'SeiteL' => %i[ymin zmax], 'SeiteR' => %i[ymin zmax], 'Boden' => %i[ymin], 'Deckel' => %i[ymin],
  'Mittelboden' => %i[ymin], 'Rückwand' => %i[xmin xmax zmax], 'Front' => %i[xmin xmax zmin zmax],
  'KastenRueckwand' => %i[zmax], 'KastenBoden' => []
}.freeze

def blaetter(k, out = [])
  k.kinder.each { |c| c.kinder.empty? ? out << c : blaetter(c, out) }
  out
end

def pruefe_ocl(w, label)
  m = Sketchup.active_model.materials
  platte = m[A::MATERIAL]; kante = m[A::KANTE]
  check(platte.get_attribute(A::OCL_DICT, 'type') == 2, "#{label}: Plattenmaterial OCL-Typ")
  check(kante.get_attribute(A::OCL_DICT, 'type') == 4, "#{label}: Anleimer OCL-Typ")
  check(kante.get_attribute(A::OCL_DICT, 'thickness') == '2mm', "#{label}: Anleimer 2mm")
  check(kante.get_attribute(A::OCL_DICT, 'edge_decremented') == true, "#{label}: Anleimer wird in OCL abgezogen")
  tags = []
  blaetter(w).each do |b|
    soll = KANTEN_SOLL.fetch(b.name) { raise "kein Soll für #{b.name}" }
    check(b.inst.material.equal?(platte), "#{label}: #{b.name} ohne Plattenmaterial")
    check(b.inst.layer && b.inst.layer.name.start_with?('AP1_'), "#{label}: #{b.name} ohne Tag")
    tags << b.inst.layer.name
    jt = %w[schrank typ kategorie bereich teil rolle].to_h { |k| [k, b.inst.get_attribute(A::JT_DICT, k)] }
    check(jt['schrank'] == 'AP1' && jt['typ'] == 'Apothekerschrank' && jt['kategorie'] == 'Hochschrank',
          "#{label}: #{b.name} JT_Schrank #{jt.inspect}")
    check(b.inst.layer.name == ['AP1', (jt['bereich'] unless jt['bereich'].empty?), jt['teil']].compact.join('_'),
          "#{label}: Tag #{b.inst.layer.name} passt nicht zu JT_Schrank #{jt.inspect}")
    check(A::ROLLEN.value?(jt['rolle']), "#{label}: #{b.name} Rolle #{jt['rolle'].inspect}")
    ist = b.defn.entities.faces.select { |f| f.material.equal?(kante) }.map do |f|
      A::SEITEN.find { |_, (ax, vz)| f.normal.to_a[ax] * vz > 0.5 }.first
    end
    check(ist.sort == soll.sort, "#{label}: #{b.name} Anleimer #{ist.inspect} statt #{soll.inspect}")
    check(b.defn.entities.faces.size == 6, "#{label}: #{b.name} keine Geometrie")
  end
  dop = tags.tally.select { |_, n| n > 1 }
  check(dop.empty?, "#{label}: Tags nicht eindeutig: #{dop.keys.inspect}")
  tags.size
end

LAENGEN = %w[Breite Hoehe Tiefe H_Teilung Hoehe_Kastenrueckwand Hoehenoffset_Schiene].freeze

def lauf(p, label, umkonf = nil)
  Sketchup.active_model = Sketchup::Model.new
  inst = A.erstellen(p)
  p = A::DEFAULTS.merge(p)
  w = Knoten.new(inst, inst.definition, nil)
  w.redraw
  erg = pruefe(w, p, label)
  pruefe_geometrie(w, label)
  n_tags = pruefe_ocl(w, label)
  puts "#{label}: #{n_tags} Teile mit eigenem Tag" if label.start_with?('Standard')
  puts "#{label}: Fronten #{erg[0..-2].map { |a, c| "#{a.round(1)}–#{c.round(1)}" }.join(', ')}; Kästen bei #{erg.last.join(', ')}"
  return unless umkonf
  d = inst.definition
  umkonf.each { |k, v| d.set_attribute(A::DICT, k.downcase, LAENGEN.include?(k) ? v / 2.54 : v.to_f) }
  w2 = Knoten.new(inst, d, nil)
  w2.redraw
  q = p.merge(umkonf)
  pruefe(w2, q, "#{label} -> umkonfiguriert")
end

lauf({}, 'Standard (eine Hochfront, 5 Kästen, Mittelboden)',
     { 'Anz_Fronten' => 2, 'Anz_Kaesten_A' => 2, 'Anz_Kaesten_B' => 4, 'H_Teilung' => 80.0 })
lauf({ 'Mittelboden' => 0.0, 'Anz_Kaesten_A' => 6.0 }, 'ohne Mittelboden, 6 Kästen',
     { 'Mittelboden' => 1, 'Anz_Kaesten_A' => 2, 'Breite' => 30.0, 'Tiefe' => 56.0 })
lauf({ 'Anz_Fronten' => 2.0, 'Anz_Kaesten_A' => 2.0, 'Anz_Kaesten_B' => 3.0 }, 'zwei Fronten',
     { 'Anz_Fronten' => 1, 'Anz_Kaesten_A' => 4, 'Hoehe' => 220.0 })
lauf({ 'Anz_Kaesten_A' => 3.0, 'Hoehe_Kastenrueckwand' => 9.0, 'Hoehenoffset_Schiene' => 0.7, 'Tiefe' => 55.2,
       'Breite' => 45.0 }, 'flache Kästen, Offset, NL 500')
# viele Kästen in wenig Höhe: Rückwände werden niedriger, nichts kollidiert
lauf({ 'Anz_Fronten' => 2.0, 'Anz_Kaesten_A' => 4.0, 'Anz_Kaesten_B' => 6.0, 'H_Teilung' => 60.0, 'Hoehe' => 180.0 },
     'eng (4 + 6 Kästen)')
lauf({ 'Anz_Kaesten_A' => 6.0, 'Hoehe' => 120.0 }, 'eng mit Mittelboden (6 Kästen in 1200 mm)')

# Rechnung in Ruby = DC-Formeln (Standard): Kästen bei 70,1 / 108,5 … mm-genau aus berechne
r = A.berechne(A::DEFAULTS)
check((r['A'][:teilung] - 38.4).abs < EPS && (r['A'][:z][4] - 6.7 - 3.2).abs < EPS, "berechne: Teilung #{r['A'][:teilung]}, unten #{r['A'][:z][4]}")

# --- Tag-Schema ---------------------------------------------------------------
Sketchup.active_model = Sketchup::Model.new
A.erstellen({})
A.erstellen({})
A.erstellen({ 'Kuerzel' => 'AP7' })
ly = Sketchup.active_model.layers
check(%w[AP1_SeiteL AP1_Deckel AP1_Mittelboden AP1_A_Front AP1_B_Front AP1_A3_KastenBoden AP1_B6_KastenRueckwand
         AP2_SeiteL AP7_Boden].all? { |n| ly[n] }, 'Tag-Namen <Kürzel>_<Bereich>_<Teil>')
ad = Sketchup.active_model.definitions[A::NAME]
check(ad.get_attribute(A::JT_DICT, 'kategorie') == 'Hochschrank' && ad.get_attribute(A::JT_DICT, 'typ') == 'Apothekerschrank',
      'JT_Schrank am Schrank')
# Tag-Schema in allen Komponenten gleich
quellen = Dir[File.expand_path('../../*/{*.rb,src/*/main.rb}', __dir__)].map { |f| File.read(f, encoding: 'UTF-8') }
rollen = quellen.map { |q| q[/  ROLLEN = \{.*?\}\.freeze/m] }.compact
check(rollen.size >= 4 && rollen.uniq.size == 1, "ROLLEN-Tabelle in allen Komponenten gleich (#{rollen.size} gefunden)")

# --- Kurzhilfe in der Komponente ------------------------------------------
Sketchup.active_model = Sketchup::Model.new
ad = A.erstellen({}).definition
check(ad.description == A::HILFE_KURZ, 'Hilfe: Beschreibung der Definition')
check(ad.get_attribute(A::DICT, 'summary') == A::HILFE_KURZ, 'Hilfe: summary')
check(ad.get_attribute(A::DICT, 'description') == A::HILFE, 'Hilfe: description')
check(%w[summary description].all? { |k| ad.get_attribute(A::DICT, "_#{k}_access") == 'VIEW' }, 'Hilfe: nur anzeigen')
check(A::HILFE.include?(A::DOKU_URL), 'Hilfe: Link zur Doku')
check(File.exist?(File.expand_path('../README.md', __dir__)), 'README.md vorhanden')

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
