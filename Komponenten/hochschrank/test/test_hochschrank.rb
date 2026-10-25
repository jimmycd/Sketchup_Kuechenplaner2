# Test ohne SketchUp: Mock-API + kleiner DC-Formel-Auswerter.
$LOAD_PATH.unshift(__dir__)
$HOCHSCHRANK_TEST = true
require 'sketchup_mock'
load File.expand_path('../hochschrank.rb', __dir__)

H = Hochschrank
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

def pruefe(w, p, label)
  b, h, t = p['Breite'], p['Hoehe'], p['Tiefe']
  mk, sp, luft = 1.9, 0.2, p['Luft_Auszug'] || 1.3
  hu, hm = p['H_Unten'], p['H_Mitte']
  zo = hu + hm + mk
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

  # Fronten lückenlos mit Fugen
  fronten = sichtbar.select { |t2| %w[Front Tür].include?(t2[:name]) }.map { |t2| [t2[:q][4], t2[:q][5]] }.sort
  soll_oben = p['Art_Oben'] == 1 ? h : (p['Art_Mitte'] == 1 ? zo - sp : hu - sp)
  check(fronten.first[0].abs < EPS, "#{label}: unterste Front bei 0")
  check((fronten.last[1] - soll_oben).abs < EPS, "#{label}: oberste Front #{fronten.last[1]} statt #{soll_oben}")
  fronten.each_cons(2) do |a, c|
    gap = c[0] - a[1]
    erlaubt = (gap - sp).abs < EPS || (p['Art_Mitte'] != 1 && (a[1] - (hu - sp)).abs < EPS && (c[0] - zo).abs < EPS)
    check(erlaubt, "#{label}: Fuge #{a[1].round(2)}..#{c[0].round(2)}")
  end
  anz_soll = p['Anz_Schubladen_Unten'] + (p['Art_Mitte'] == 1 ? p['Anz_Schubladen_Mitte'] : 0) + p['Art_Oben']
  check(fronten.size == anz_soll, "#{label}: #{fronten.size} Fronten statt #{anz_soll}")

  # Schubkasten-Außenbreite = Innenbreite - 2*Luft
  sichtbar.select { |t2| t2[:name] == 'KastenSeiteL' }.each do |kl|
    kr = sichtbar.find { |t2| t2[:name] == 'KastenSeiteR' && t2[:pfad].split('/').first == kl[:pfad].split('/').first }
    check(((kr[:q][1] - kl[:q][0]) - (b - 2 * mk - 2 * luft)).abs < EPS, "#{label}: Kastenbreite #{kl[:pfad]}")
    check((kl[:q][0] - mk - luft).abs < EPS, "#{label}: Luft links #{kl[:pfad]}")
  end
  # Schubkasten: Schienenbohrung (Unterkante Kasten + Höhenoffset) im Lochraster 35 + n * 32 mm ab Unterkante Seite,
  # tragender Boden über die volle Kastenbreite
  off = p['Hoehenoffset_Schiene']
  sichtbar.select { |t2| t2[:name] == 'KastenBoden' }.each do |kb|
    loch = (kb[:q][4] + off - p['Lochraster_Start']) / p['Lochraster']
    check((loch - loch.round).abs < 1e-6, "#{label}: #{kb[:pfad]} nicht im Lochraster (#{kb[:q][4].round(3)})")
    kl = sichtbar.find { |t2| t2[:name] == 'KastenSeiteL' && t2[:pfad].split('/').first == kb[:pfad].split('/').first }
    if p['Kastenboden_tragend'] == 1
      check((kb[:q][0] - kl[:q][0]).abs < EPS && (kl[:q][4] - kb[:q][5]).abs < EPS, "#{label}: #{kb[:pfad]} tragend")
    else
      check((kb[:q][0] - kl[:q][1]).abs < EPS && (kl[:q][4] - kb[:q][4]).abs < EPS, "#{label}: #{kb[:pfad]} zwischen den Seiten")
    end
  end
  eb = sichtbar.count { |t2| t2[:name].start_with?('Einlegeboden') }
  check(eb == p['Anz_Einlegeboeden_Oben'], "#{label}: Einlegeböden #{eb}")
  check((w.wert('H_Oben') - (h - zo)).abs < EPS, "#{label}: H_Oben")
  fronten
end


KANTEN_SOLL = {
  'SeiteL' => %i[ymin zmax], 'SeiteR' => %i[ymin zmax], 'Boden' => %i[ymin], 'Deckel' => %i[ymin],
  'ZwischenbodenUnten' => %i[ymin], 'ZwischenbodenOben' => %i[ymin], 'Rückwand' => %i[xmin xmax zmax],
  'Tür' => %i[xmin xmax zmin zmax], 'Front' => %i[xmin xmax zmin zmax],
  'KastenSeiteL' => %i[zmax], 'KastenSeiteR' => %i[zmax], 'KastenVorne' => %i[zmax], 'KastenHinten' => %i[zmax],
  'KastenBoden' => []
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
    nm = b.name.start_with?('Einlegeboden') ? 'Boden' : b.name
    nm = 'Boden' if nm.start_with?('Einlegeboden')
    soll = b.name.start_with?('Einlegeboden') ? %i[ymin] : KANTEN_SOLL.fetch(nm) { raise "kein Soll für #{b.name}" }
    check(b.inst.material.equal?(platte), "#{label}: #{b.name} ohne Plattenmaterial")
    check(b.inst.layer && b.inst.layer.name.start_with?('HS1_'), "#{label}: #{b.name} ohne Tag")
    tags << b.inst.layer.name
    jt = %w[schrank typ kategorie bereich teil rolle].to_h { |k| [k, b.inst.get_attribute(H::JT_DICT, k)] }
    check(jt['schrank'] == 'HS1' && jt['typ'] == 'Hochschrank' && jt['kategorie'] == 'Hochschrank',
          "#{label}: #{b.name} JT_Schrank #{jt.inspect}")
    check(b.inst.layer.name == ['HS1', (jt['bereich'] unless jt['bereich'].empty?), jt['teil']].compact.join('_'),
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

def lauf(p, label, umkonf = nil)
  Sketchup.active_model = Sketchup::Model.new
  inst = H.erstellen(p)
  p = H::DEFAULTS.merge(p)
  w = Knoten.new(inst, inst.definition, nil)
  w.redraw
  fr = pruefe(w, p, label)
  pruefe_geometrie(w, label)
  n_tags = pruefe_ocl(w, label)
  puts "#{label}: #{n_tags} Teile mit eigenem Tag" if label.start_with?('Standard')
  puts "#{label}: Fronten " + fr.map { |a, c| "#{a.round(1)}–#{c.round(1)}" }.join(', ')
  return unless umkonf
  d = inst.definition
  umkonf.each { |k, v| d.set_attribute(H::DICT, k.downcase, %w[Breite Hoehe Tiefe H_Unten H_Mitte Luft_Auszug].include?(k) ? v / 2.54 : v.to_f) }
  w2 = Knoten.new(inst, d, nil)
  w2.redraw
  q = p.merge(umkonf)
  pruefe(w2, q, "#{label} -> umkonfiguriert")
end

lauf({}, 'Standard (Ofenfach, Tür)',
     { 'Art_Mitte' => 1, 'Anz_Schubladen_Mitte' => 3, 'Art_Oben' => 0, 'Anz_Einlegeboeden_Oben' => 3,
       'Hoehe' => 220.0, 'H_Unten' => 80.0, 'Breite' => 45.0, 'Luft_Auszug' => 2.1 })
lauf({ 'Art_Mitte' => 1.0, 'Anz_Schubladen_Mitte' => 2.0, 'Anteil_M1' => 1.0, 'Anteil_M2' => 2.0 }, 'Mitte Schubladen',
     { 'Art_Mitte' => 0, 'Anz_Schubladen_Unten' => 6, 'Anz_Einlegeboeden_Oben' => 0 })
lauf({ 'Art_Oben' => 0.0, 'Anz_Einlegeboeden_Oben' => 2.0, 'Anz_Schubladen_Unten' => 1.0 }, 'oben offen, 1 Schublade',
     { 'Art_Oben' => 1, 'Anz_Schubladen_Unten' => 2, 'Anteil_U1' => 1, 'Anteil_U2' => 3 })
lauf({ 'Anz_Schubladen_Unten' => 4.0, 'Anteil_U4' => 2.0, 'Art_Mitte' => 1.0, 'Anz_Schubladen_Mitte' => 4.0,
       'H_Mitte' => 45.0, 'Luft_Auszug' => 0.5 }, '4+4 Schubladen')
lauf({ 'Art_Mitte' => 1.0, 'Kastenboden_tragend' => 0.0, 'Materialstaerke_Kastenboden' => 0.8, 'Hoehenoffset_Schiene' => 0.7 },
     'Boden zwischen den Seiten, Offset', { 'Kastenboden_tragend' => 1, 'Anz_Schubladen_Unten' => 5 })

# --- Tag-Schema ---------------------------------------------------------------
Sketchup.active_model = Sketchup::Model.new
H.erstellen({})
H.erstellen({})
H.erstellen({ 'Kuerzel' => 'HS7' })
ly = Sketchup.active_model.layers
check(%w[HS1_SeiteL HS1_Deckel HS1_O_Einlegeboden2 HS1_O_Tuer HS1_U1_Front HS1_M2_KastenSeiteR
         HS2_SeiteL HS7_Boden].all? { |n| ly[n] }, 'Tag-Namen <Kürzel>_<Bereich>_<Teil>')
check(ly.to_a.none? { |l| l.name.start_with?('Hochschrank-') }, 'keine alten Tags Hochschrank-…')
hd = Sketchup.active_model.definitions[H::NAME]
check(hd.get_attribute(H::JT_DICT, 'kategorie') == 'Hochschrank', 'JT_Schrank am Schrank')
# Tag-Schema in allen Komponenten gleich
quellen = Dir[File.expand_path('../../*/{*.rb,src/*/main.rb}', __dir__)].map { |f| File.read(f, encoding: 'UTF-8') }
rollen = quellen.map { |q| q[/  ROLLEN = \{.*?\}\.freeze/m] }.compact
check(rollen.size >= 3 && rollen.uniq.size == 1, "ROLLEN-Tabelle in allen Komponenten gleich (#{rollen.size} gefunden)")

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
