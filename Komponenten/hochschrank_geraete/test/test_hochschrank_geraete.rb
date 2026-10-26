# Test ohne SketchUp: Mock-API + kleiner DC-Formel-Auswerter.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
load File.expand_path('../src/hochschrank_geraete/main.rb', __dir__)

H = HochschrankGeraete
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

  def name = inst&.get_attribute(H::DICT, '_name') || defn.get_attribute(H::DICT, '_name')

  def roh(attr)
    k = attr.downcase
    return @werte[k] if @werte.key?(k)
    v = inst&.get_attribute(H::DICT, k)
    v = defn.get_attribute(H::DICT, k) if v.nil?
    v = inst.transformation.origin[%w[x y z].index(k)] if v.nil? && inst && %w[x y z].include?(k)
    raise "Attribut #{attr} fehlt an #{name}" if v.nil?
    fu = defn.get_attribute(H::DICT, "_#{k}_formulaunits")
    %w[x y z lenx leny lenz].include?(k) || fu == 'CENTIMETERS' ? v * 2.54 : v
  end

  def formel(k) = inst&.get_attribute(H::DICT, "_#{k}_formula") || defn.get_attribute(H::DICT, "_#{k}_formula")

  def ref(n, attr)
    ziel = parent && parent.name == n ? parent : (parent ? parent.kinder : []).find { |s| s.name == n }
    raise "Referenz #{n}!#{attr} von #{name} nicht auflösbar" unless ziel
    ziel.roh(attr)
  end

  def IF(c, a, b) = c ? a : b
  def AND(*a) = a.all?
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
    keys = (defn.attribute_dictionary(H::DICT)&.keys || []) + (inst&.attribute_dictionary(H::DICT)&.keys || [])
    keys.grep(/\A_(.+)_formula\z/) { $1 }.uniq.sort
  end

  def redraw
    schluessel.each { |k| @werte[k] = auswerten(formel(k)) }
    kinder.each(&:redraw)
  end

  def wert(k) = roh(k)
  def finde(n) = kinder.find { |c| c.name == n } || raise("#{n} fehlt")
  def hidden? = (defn.get_attribute(H::DICT, '_hidden_formula') ? wert('hidden') > 0.5 : false)
  def pos(ax) = (formel(ax) ? wert(ax) : inst.transformation.origin[%w[x y z].index(ax)] * 2.54)
end

# Absolute Quader [x0,x1,y0,y1,z0,z1] aller Blatt-Teile, mit Sichtbarkeit
def teile(k, off = [0, 0, 0], versteckt = false, out = [])
  k.kinder.each do |c|
    o = off.each_with_index.map { |v, i| v + c.pos(%w[x y z][i]) }
    vs = versteckt || c.hidden?
    if c.kinder.empty?
      l = %w[lenx leny lenz].map { |a| c.formel(a) ? c.wert(a) : c.defn.box[%w[lenx leny lenz].index(a)] * 2.54 }
      out << { name: c.name, pfad: "#{k.name}/#{c.name}", q: [o[0], o[0] + l[0], o[1], o[1] + l[1], o[2], o[2] + l[2]], hidden: vs }
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

GERAET = %w[GeraetN1 GeraetN2].freeze
LICHT = { 1 => 59.0, 2 => 45.0, 3 => 38.0, 4 => 14.0, 5 => 0.0 }.freeze

def nische_soll(p, n) = LICHT[p["Geraet_N#{n}"].to_i] || p["H_N#{n}_frei"]

def pruefe(w, p, label)
  b, h, t = p['Breite'], p['Hoehe'], p['Tiefe']
  mk, sp = 1.9, 0.2
  hu = p['H_Unten']
  zwei = p['Geraet_N2'].to_i != 5
  h1, h2 = nische_soll(p, 1), nische_soll(p, 2)
  zo = hu + h1 + mk + (zwei ? h2 + mk : 0)
  alle = teile(w)
  sichtbar = alle.reject { |t2| t2[:hidden] }
  by = ->(n) { sichtbar.find { |t2| t2[:name] == n } }

  # Auswahlrahmen: alle Teile (auch versteckte) innerhalb des Schranks
  alle.each do |t2|
    q = t2[:q]
    check(q[0] >= -EPS && q[1] <= b + EPS && q[4] >= -EPS && q[5] <= h + EPS && q[2] >= -sp - EPS && q[3] <= t + mk + 0.8 + EPS,
          "#{label}: #{t2[:pfad]} außerhalb #{q.map { |v| v.round(2) }}")
  end
  # keine Kollisionen zwischen sichtbaren Teilen (Platzhalter eingeschlossen)
  sichtbar.combination(2).each do |a, c|
    check(!ueberlapp?(a[:q], c[:q]), "#{label}: Kollision #{a[:pfad]} / #{c[:pfad]}")
  end

  # Nischen: lichte Höhe zwischen den Zwischenböden, lichte Breite zwischen den Seiten
  zu, zm, zob = %w[ZwischenbodenUnten ZwischenbodenMitte ZwischenbodenOben].map { |n| by.(n) }
  check(zu && (zu[:q][5] - hu).abs < EPS, "#{label}: Zwischenboden unten Oberkante #{zu && zu[:q][5]}")
  check(!!zm == zwei, "#{label}: Zwischenboden Mitte sichtbar = #{!!zm}")
  ueber_n1 = zwei ? zm : zob
  check((ueber_n1[:q][4] - zu[:q][5] - h1).abs < EPS, "#{label}: Nische 1 lichte Höhe #{ueber_n1[:q][4] - zu[:q][5]} statt #{h1}")
  check((zob[:q][4] - zm[:q][5] - h2).abs < EPS, "#{label}: Nische 2 lichte Höhe") if zwei
  check((zob[:q][5] - zo).abs < EPS, "#{label}: Oberkante Zwischenboden oben #{zob[:q][5]} statt #{zo}")
  check((w.wert('H_N1') - h1).abs < EPS && (!zwei || (w.wert('H_N2') - h2).abs < EPS), "#{label}: H_N1/H_N2 angezeigt")
  check((w.wert('Lichte_Breite') - (b - 2 * mk)).abs < EPS, "#{label}: lichte Breite")
  rw = by.('Rückwand')
  check(rw && rw[:q][4].abs < EPS && (rw[:q][5] - h).abs < EPS, "#{label}: Rückwand durchgehend")

  # Geräte-Platzhalter füllen die Nischen
  [[1, zu, h1], [2, zm, h2]].each do |n, unter, hn|
    g = by.("GeraetN#{n}")
    if n == 2 && !zwei
      check(g.nil?, "#{label}: Platzhalter N2 bei keine ausgeblendet")
      next
    end
    q = g[:q]
    check((q[4] - unter[:q][5]).abs < EPS && (q[5] - q[4] - hn).abs < EPS, "#{label}: Platzhalter N#{n} Höhe/Lage")
    check((q[0] - mk).abs < EPS && (q[1] - (b - mk)).abs < EPS && (q[2] - mk).abs < EPS &&
          (q[3] - q[2] - [p['Geraet_Tiefe'], t].min).abs < EPS, "#{label}: Platzhalter N#{n} Breite/Tiefe")
  end

  # Fronten: Schubladen von 0 bis H_Unten - Fuge, Tür ab Oberkante Zwischenboden oben
  fronten = sichtbar.select { |t2| %w[Front Tür].include?(t2[:name]) }.map { |t2| [t2[:q][4], t2[:q][5]] }.sort
  check(fronten.first[0].abs < EPS, "#{label}: unterste Front bei 0")
  soll_oben = p['Art_Oben'] == 1 ? h : hu - sp
  check((fronten.last[1] - soll_oben).abs < EPS, "#{label}: oberste Front #{fronten.last[1]} statt #{soll_oben}")
  fronten.each_cons(2) do |a, c|
    gap = c[0] - a[1]
    erlaubt = (gap - sp).abs < EPS || ((a[1] - (hu - sp)).abs < EPS && (c[0] - zo).abs < EPS)
    check(erlaubt, "#{label}: Fuge #{a[1].round(2)}..#{c[0].round(2)}")
  end
  anz_soll = p['Anz_Schubladen_Unten'] + p['Art_Oben']
  check(fronten.size == anz_soll, "#{label}: #{fronten.size} Fronten statt #{anz_soll}")

  # Schubkasten LEGRABOX free wie beim Hochschrank, Schienenbohrung im Lochraster
  nl = [65.0, ((t - 0.3) / 5 + 0.000001).floor * 5.0].min
  check((w.wert('NL') - nl).abs < EPS, "#{label}: NL #{w.wert('NL')} statt #{nl}")
  off = p['Hoehenoffset_Schiene']
  mb, mrw = p['Materialstaerke_Kastenboden'], p['Materialstaerke_Kastenrueckwand']
  boeden = sichtbar.select { |t2| t2[:name] == 'KastenBoden' }
  check(boeden.size == p['Anz_Schubladen_Unten'], "#{label}: #{boeden.size} Kastenböden")
  boeden.each do |kb|
    q = kb[:q]
    loch = (q[4] + off - p['Lochraster_Start']) / p['Lochraster']
    check((loch - loch.round).abs < 1e-6, "#{label}: #{kb[:pfad]} nicht im Lochraster (#{q[4].round(3)})")
    check((q[0] - (mk + 1.75)).abs < EPS && (q[1] - (b - mk - 1.75)).abs < EPS, "#{label}: #{kb[:pfad]} Breite LW-35")
    check((q[2] - mk).abs < EPS && (q[3] - (mk + nl - 1.0)).abs < EPS, "#{label}: #{kb[:pfad]} Länge NL-10")
    check((q[5] - q[4] - mb).abs < EPS, "#{label}: #{kb[:pfad]} Stärke")
    kr = sichtbar.find { |t2| t2[:name] == 'KastenRueckwand' && t2[:pfad].split('/').first == kb[:pfad].split('/').first }
    r = kr[:q]
    check((r[0] - (mk + 1.9)).abs < EPS && (r[1] - (b - mk - 1.9)).abs < EPS, "#{label}: #{kr[:pfad]} Breite LW-38")
    check((r[3] - q[3]).abs < EPS && (r[3] - r[2] - mrw).abs < EPS, "#{label}: #{kr[:pfad]} hinten am Boden")
    check((r[4] - q[5]).abs < EPS && r[5] - r[4] <= p['Hoehe_Kastenrueckwand'] + EPS, "#{label}: #{kr[:pfad]} auf dem Boden")
  end
  eb = sichtbar.count { |t2| t2[:name].start_with?('Einlegeboden') }
  check(eb == p['Anz_Einlegeboeden_Oben'], "#{label}: Einlegeböden #{eb}")
  check((w.wert('H_Oben') - (h - zo)).abs < EPS, "#{label}: H_Oben")
  fronten
end

KANTEN_SOLL = {
  'SeiteL' => %i[ymin zmax], 'SeiteR' => %i[ymin zmax], 'Boden' => %i[ymin], 'Deckel' => %i[ymin],
  'ZwischenbodenUnten' => %i[ymin], 'ZwischenbodenMitte' => %i[ymin], 'ZwischenbodenOben' => %i[ymin],
  'Rückwand' => %i[xmin xmax zmax], 'Tür' => %i[xmin xmax zmin zmax], 'Front' => %i[xmin xmax zmin zmax],
  'KastenRueckwand' => %i[zmax], 'KastenBoden' => []
}.freeze

def blaetter(k, out = [])
  k.kinder.each { |c| c.kinder.empty? ? out << c : blaetter(c, out) }
  out
end

def pruefe_ocl(w, label)
  m = Sketchup.active_model.materials
  platte = m[H::MATERIAL]; kante = m[H::KANTE]
  check(platte.get_attribute(H::OCL_DICT, 'type') == 2, "#{label}: Plattenmaterial OCL-Typ")
  check(kante.get_attribute(H::OCL_DICT, 'type') == 4, "#{label}: Anleimer OCL-Typ")
  check(kante.get_attribute(H::OCL_DICT, 'thickness') == '2mm', "#{label}: Anleimer 2mm")
  check(kante.get_attribute(H::OCL_DICT, 'edge_decremented') == true, "#{label}: Anleimer wird in OCL abgezogen")
  tags = []
  blaetter(w).each do |b|
    if GERAET.include?(b.name)
      # Platzhalter: kein Schrankteil
      check(b.inst.layer&.name == H::GERAET_TAG, "#{label}: #{b.name} auf Tag #{H::GERAET_TAG}")
      check(b.inst.material.equal?(m[H::GERAET_MATERIAL]) && m[H::GERAET_MATERIAL].get_attribute(H::OCL_DICT, 'type').nil?,
            "#{label}: #{b.name} ohne Plattenmaterial")
      check(b.inst.attribute_dictionary(H::JT_DICT).nil?, "#{label}: #{b.name} ohne JT_Schrank")
      next
    end
    soll = b.name.start_with?('Einlegeboden') ? %i[ymin] : KANTEN_SOLL.fetch(b.name) { raise "kein Soll für #{b.name}" }
    check(b.inst.material.equal?(platte), "#{label}: #{b.name} ohne Plattenmaterial")
    check(b.inst.layer && b.inst.layer.name.start_with?('HG1_'), "#{label}: #{b.name} ohne Tag")
    tags << b.inst.layer.name
    jt = %w[schrank typ kategorie bereich teil rolle].to_h { |k| [k, b.inst.get_attribute(H::JT_DICT, k)] }
    check(jt['schrank'] == 'HG1' && jt['typ'] == 'Hochschrank_Geraete' && jt['kategorie'] == 'Hochschrank',
          "#{label}: #{b.name} JT_Schrank #{jt.inspect}")
    check(b.inst.layer.name == ['HG1', (jt['bereich'] unless jt['bereich'].empty?), jt['teil']].compact.join('_'),
          "#{label}: Tag #{b.inst.layer.name} passt nicht zu JT_Schrank #{jt.inspect}")
    check(H::ROLLEN.value?(jt['rolle']), "#{label}: #{b.name} Rolle #{jt['rolle'].inspect}")
    ist = b.defn.entities.faces.select { |f| f.material.equal?(kante) }.map do |f|
      H::SEITEN.find { |_, (ax, vz)| f.normal.to_a[ax] * vz > 0.5 }.first
    end
    check(ist.sort == soll.sort, "#{label}: #{b.name} Anleimer #{ist.inspect} statt #{soll.inspect}")
    check(b.defn.entities.faces.size == 6, "#{label}: #{b.name} keine Geometrie")
  end
  dop = tags.tally.select { |_, n| n > 1 }
  check(dop.empty?, "#{label}: Tags nicht eindeutig: #{dop.keys.inspect}")
  tags.size
end

# Wörterbuch JT_Nische_N1/N2 am Schrank (Schnittstelle zu den Geräte-Komponenten), Werte in mm
def pruefe_nischen(d, p, label)
  mk = 1.9
  h1 = nische_soll(p, 1)
  { 1 => p['H_Unten'], 2 => p['H_Unten'] + h1 + mk }.each do |n, z|
    nd = d.attribute_dictionary("JT_Nische_N#{n}")
    if n == 2 && p['Geraet_N2'].to_i == 5
      check(nd.nil?, "#{label}: keine JT_Nische_N2 bei keine")
      next
    end
    kennung = { 1 => 'Backofen60', 2 => 'Kompakt45', 3 => 'Mikrowelle38', 4 => 'Waermeschublade14', 0 => 'frei' }
    soll = { 'nische' => "N#{n}", 'geraet' => kennung[p["Geraet_N#{n}"].to_i],
             'breite' => ((p['Breite'] - 2 * mk) * 10).round(1), 'hoehe' => (nische_soll(p, n) * 10).round(1),
             'tiefe' => (p['Tiefe'] * 10).round(1), 'x' => 19.0, 'y' => 19.0, 'z' => (z * 10).round(1) }
    check(nd == soll, "#{label}: JT_Nische_N#{n} #{nd.inspect} statt #{soll.inspect}")
  end
end

def lauf(p, label, umkonf = nil)
  Sketchup.active_model = Sketchup::Model.new
  inst = H.erstellen(p)
  p = H::DEFAULTS.merge(p)
  w = Knoten.new(inst, inst.definition, nil)
  w.redraw
  fr = pruefe(w, p, label)
  pruefe_geometrie(w, label)
  n_tags = pruefe_ocl(w, label)
  pruefe_nischen(inst.definition, p, label)
  puts "#{label}: #{n_tags} Teile mit eigenem Tag" if label.start_with?('Standard')
  puts "#{label}: Fronten " + fr.map { |a, c| "#{a.round(1)}–#{c.round(1)}" }.join(', ')
  return unless umkonf
  d = inst.definition
  laengen = %w[Breite Hoehe Tiefe H_Unten H_N1_frei H_N2_frei]
  umkonf.each { |k, v| d.set_attribute(H::DICT, k.downcase, laengen.include?(k) ? v / 2.54 : v.to_f) }
  w2 = Knoten.new(inst, d, nil)
  w2.redraw
  q = p.merge(umkonf)
  pruefe(w2, q, "#{label} -> umkonfiguriert")
end

lauf({}, 'Standard (Backofen + Kompaktgerät, Tür)',
     { 'Geraet_N1' => 2, 'Geraet_N2' => 1, 'Art_Oben' => 0, 'Anz_Einlegeboeden_Oben' => 2,
       'Hoehe' => 220.0, 'H_Unten' => 80.0, 'Breite' => 60.0, 'Tiefe' => 56.0 })
lauf({ 'Geraet_N1' => 3.0, 'Geraet_N2' => 4.0, 'Anz_Schubladen_Unten' => 2.0, 'Anteil_U2' => 2.0 }, 'Mikrowelle + Wärmeschublade',
     { 'Geraet_N2' => 5, 'Anz_Schubladen_Unten' => 4 })
lauf({ 'Geraet_N2' => 5.0, 'Art_Oben' => 0.0, 'Anz_Einlegeboeden_Oben' => 3.0 }, 'nur ein Gerät',
     { 'Geraet_N2' => 0, 'H_N2_frei' => 40.0, 'Art_Oben' => 1 })
lauf({ 'Geraet_N1' => 0.0, 'H_N1_frei' => 58.5, 'Geraet_N2' => 0.0, 'H_N2_frei' => 45.5, 'H_Unten' => 60.0,
       'Tiefe' => 47.0, 'Geraet_Tiefe' => 55.0, 'Anz_Schubladen_Unten' => 1.0 }, 'freie Höhen, flacher Korpus',
     { 'H_N1_frei' => 60.0, 'Geraet_N2' => 2, 'Anz_Schubladen_Unten' => 2 })
lauf({ 'Materialstaerke_Kastenboden' => 1.9, 'Hoehenoffset_Schiene' => 0.7, 'Tiefe' => 55.2 },
     'Boden 19 mm, Offset, NL 500', { 'Tiefe' => 40.0, 'H_Unten' => 90.0, 'Anz_Schubladen_Unten' => 5 })

# --- Tag-Schema ---------------------------------------------------------------
Sketchup.active_model = Sketchup::Model.new
H.erstellen({})
H.erstellen({})
H.erstellen({ 'Kuerzel' => 'HG7' })
ly = Sketchup.active_model.layers
check(%w[HG1_SeiteL HG1_Deckel HG1_ZwischenbodenMitte HG1_O_Einlegeboden2 HG1_O_Tuer HG1_U1_Front
         HG1_U3_KastenRueckwand HG2_SeiteL HG7_Boden Geraete_Plan].all? { |n| ly[n] }, 'Tag-Namen <Kürzel>_<Bereich>_<Teil>')
hd = Sketchup.active_model.definitions[H::NAME]
check(hd.get_attribute(H::JT_DICT, 'kategorie') == 'Hochschrank', 'JT_Schrank am Schrank')
# Böden unter den Geräten markiert (Schrank-CNC bohrt in den Nischen keine Lochreihe)
nb = hd.entities.instances.to_h { |i| [i.name, i.get_attribute(H::JT_DICT, 'nische')] }
check(nb['ZwischenbodenUnten'] == 'N1' && nb['ZwischenbodenMitte'] == 'N2' && nb['ZwischenbodenOben'].nil?,
      "Nischen-Markierung an den Zwischenböden: #{nb.compact}")
# Tag-Schema in allen Komponenten gleich
quellen = Dir[File.expand_path('../../*/{*.rb,src/*/main.rb}', __dir__)].map { |f| File.read(f, encoding: 'UTF-8') }
rollen = quellen.map { |q| q[/  ROLLEN = \{.*?\}\.freeze/m] }.compact
check(rollen.size >= 5 && rollen.uniq.size == 1, "ROLLEN-Tabelle in allen Komponenten gleich (#{rollen.size} gefunden)")

# --- Auswahllisten ------------------------------------------------------------
check(H.geraete_liste(1).start_with?('&Backofen%2060%20%28590%20mm%29=1&Kompaktger%C3%A4t%2045%20%28450%20mm%29=2&') &&
      H.geraete_liste(1).count('=') == 5, "Geräteliste Nische 1: #{H.geraete_liste(1)}")
check(H.geraete_liste(2).end_with?('&keine=5&') && !H.geraete_liste(1).include?('keine'), 'nur Nische 2 kann leer sein')
check(H.geraete_liste(2).ascii_only?, "Geräteliste URL-kodiert: #{H.geraete_liste(2)}")

# --- Kurzhilfe in der Komponente ------------------------------------------
Sketchup.active_model = Sketchup::Model.new
hd = H.erstellen({}).definition
check(hd.description == H::HILFE_KURZ, 'Hilfe: Beschreibung der Definition')
check(hd.get_attribute(H::DICT, 'summary') == H::HILFE_KURZ, 'Hilfe: summary')
check(hd.get_attribute(H::DICT, 'description') == H::HILFE, 'Hilfe: description')
check(%w[summary description].all? { |k| hd.get_attribute(H::DICT, "_#{k}_access") == 'VIEW' }, 'Hilfe: nur anzeigen')
check(H::HILFE.include?(H::DOKU_URL), 'Hilfe: Link zur Doku')
check(File.exist?(File.expand_path('../README.md', __dir__)), 'README.md vorhanden')

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
