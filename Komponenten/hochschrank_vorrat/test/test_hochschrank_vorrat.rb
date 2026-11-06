# Test ohne SketchUp: Mock-API + kleiner DC-Formel-Auswerter.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
load File.expand_path('../src/hochschrank_vorrat/main.rb', __dir__)

A = HochschrankVorrat
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
  hu = p['H_Unten']
  n = p['Anz_Kaesten'].to_i
  fr = p['Freiraum_Scharnier']
  geteilt = p['Tueren'].to_i == 1
  zwei = p['Fluegel'].to_i == 2
  alle = teile(w)
  sichtbar = alle.reject { |t2| t2[:hidden] }

  alle.each do |t2|
    q = t2[:q]
    check(q[0] >= -EPS && q[1] <= b + EPS && q[4] >= -EPS && q[5] <= h + EPS && q[2] >= -sp - EPS && q[3] <= t + mk + 0.8 + EPS,
          "#{label}: #{t2[:pfad]} außerhalb #{q.map { |v| v.round(2) }}")
  end
  sichtbar.combination(2).each do |a, c|
    check(!ueberlapp?(a[:q], c[:q]), "#{label}: Kollision #{a[:pfad]} / #{c[:pfad]}")
  end

  # Türen: decken die Front ab (Fugen 2 mm), Flächen ohne Lücke außer den Fugen
  tueren = sichtbar.select { |t2| t2[:name].start_with?('Tuer') }
  soll_namen = (geteilt ? %w[U O] : %w[U]).flat_map { |ber| zwei ? ["#{ber}/TuerL", "#{ber}/TuerR"] : ["#{ber}/Tuer"] }.sort
  check(tueren.map { |t2| "#{t2[:bereich]}/#{t2[:name]}" }.sort == soll_namen, "#{label}: Türen #{tueren.map { |t2| t2[:pfad] }}")
  zonen = geteilt ? { 'U' => [0, hu - sp], 'O' => [hu, h] } : { 'U' => [0, h] }
  tueren.each do |t2|
    q = t2[:q]
    z0, z1 = zonen[t2[:bereich]]
    check((q[4] - z0).abs < EPS && (q[5] - z1).abs < EPS, "#{label}: #{t2[:pfad]} Höhe #{q[4]}–#{q[5]} statt #{z0}–#{z1}")
    check((q[2] + sp).abs < EPS && (q[3] - (mk - sp)).abs < EPS, "#{label}: #{t2[:pfad]} Lage y")
  end
  breite = tueren.group_by { |t2| t2[:bereich] }.transform_values { |l| l.sum { |t2| t2[:q][1] - t2[:q][0] } }
  breite.each { |ber, s| check((s - (b - (zwei ? 2 : 1) * sp)).abs < EPS, "#{label}: Türbreite #{ber} #{s}") }
  if zwei
    check(tueren.all? { |t2| (t2[:q][0] - sp / 2).abs < EPS || (t2[:q][1] - (b - sp / 2)).abs < EPS }, "#{label}: Flügel außen bündig")
  else
    check(tueren.all? { |t2| (t2[:q][0] - sp / 2).abs < EPS && (t2[:q][1] - (b - sp / 2)).abs < EPS }, "#{label}: ein Flügel")
  end
  # Anschlag: der Halter (Drehpunkt) sitzt an der Scharnierseite
  tueren.each do |t2|
    halter = t2[:knoten].parent
    hx = halter.pos('x')
    links = t2[:name] == 'TuerL' || (t2[:name] == 'Tuer' && p['Anschlag'].to_i == 0)
    check((hx - (links ? sp / 2 : b - sp / 2)).abs < EPS, "#{label}: #{t2[:pfad]} Drehpunkt #{hx}")
    check((halter.wert('Winkel') - (links ? -100 : 100)).abs < EPS, "#{label}: #{t2[:pfad]} öffnet nach außen")
  end

  # Zwischenboden
  zb = sichtbar.find { |t2| t2[:name] == 'Zwischenboden' }
  check(zb && (zb[:q][5] - hu).abs < EPS, "#{label}: Zwischenboden Oberkante bei H_Unten")

  # Kästen
  nl = ([35.0, 40.0, 45.0, 50.0, 55.0, 60.0, 65.0].select { |x| x + 0.3 <= t - 1.7 + 1e-6 }.max || 35.0)
  check((w.wert('NL') - nl).abs < EPS, "#{label}: NL #{w.wert('NL')} statt #{nl}")
  r = A.berechne(p)
  kb = sichtbar.select { |t2| t2[:name] == 'KastenBoden' }.sort_by { |t2| -t2[:q][4] }
  check(kb.map { |t2| t2[:bereich] } == (1..n).map { |j| "U#{j}" }, "#{label}: Kästen #{kb.map { |t2| t2[:bereich] }}")
  innen = []
  kb.each_with_index do |k, idx|
    i = idx + 1
    q = k[:q]
    fach = r[:faecher][idx]
    check((q[4] - fach[:z] - [p['Kasten_Abstand_unten'], 3.8].max).abs < EPS, "#{label}: #{k[:pfad]} genau am Mindestabstand im Fach, kein Lochraster")
    check(q[4] >= fach[:z] + p['Kasten_Abstand_unten'] - EPS, "#{label}: #{k[:pfad]} zu tief im Fach")
    check((q[0] - (mk + 1.75)).abs < EPS && (q[1] - (b - mk - 1.75)).abs < EPS, "#{label}: #{k[:pfad]} Breite LW-35")
    check((q[2] - (mk + 1.7)).abs < EPS && (q[3] - (mk + 1.7 + nl - 1.0)).abs < EPS, "#{label}: #{k[:pfad]} Länge NL-10 hinter der Innenfront")
    teile_k = sichtbar.select { |t2| t2[:bereich] == "U#{i}" }
    check(teile_k.map { |t2| t2[:name] }.sort == %w[Innenfront KastenBoden KastenRueckwand], "#{label}: Kasten #{i} Teile")
    inf = teile_k.find { |t2| t2[:name] == 'Innenfront' }
    iq = inf[:q]
    check((iq[3] - iq[2] - 1.2).abs < EPS && (iq[2] - (mk + 0.3)).abs < EPS, "#{label}: Innenfront 12 mm, 3 mm hinter Vorderkante")
    check((iq[0] - (mk + 0.2)).abs < EPS && (iq[1] - (b - mk - 0.2)).abs < EPS, "#{label}: Innenfront Breite")
    check((iq[4] - q[4]).abs < EPS && (iq[5] - (fach[:top] - fr)).abs < EPS, "#{label}: Innenfront Höhe #{iq[4]}–#{iq[5]}")
    kr = teile_k.find { |t2| t2[:name] == 'KastenRueckwand' }
    check(kr[:q][5] <= iq[5] + EPS, "#{label}: Kastenrückwand nicht höher als Innenfront")
    innen.concat(teile_k)
  end

  # Scharniere: Höhen wie berechnet, jede Lücke frei von Kästen, Böden; jede Tür hat ihre Scharniere
  s = (1..6).map { |i| w.wert("Scharnier_#{i}") }
  check(s.zip(r[:scharniere]).all? { |x, y| (x - y).abs < EPS }, "#{label}: Scharniere DC #{s.map { |x| x.round(2) }} vs Ruby #{r[:scharniere].map { |x| x.round(2) }}")
  hindernisse = innen + sichtbar.select { |t2| %w[Boden Deckel Zwischenboden].include?(t2[:name]) || t2[:name].start_with?('Einlegeboden') }
  aktiv = s.reject(&:zero?)
  aktiv.each do |z|
    hindernisse.each do |x|
      check(x[:q][5] <= z - fr / 2 + EPS || x[:q][4] >= z + fr / 2 - EPS,
            "#{label}: Scharnier bei #{z.round(1)} trifft #{x[:pfad]} (#{x[:q][4].round(1)}–#{x[:q][5].round(1)})")
    end
  end
  zonen.each do |ber, (z0, z1)|
    in_tuer = aktiv.select { |z| z > z0 && z < z1 }
    soll = ber == 'O' ? 3 : (geteilt ? 2 : (s[1].zero? ? 4 : 5))
    check(in_tuer.size == soll, "#{label}: Tür #{ber}: #{in_tuer.size} Scharniere statt #{soll}")
    check(in_tuer.all? { |z| z - z0 >= 4 && z1 - z >= 4 }, "#{label}: Tür #{ber}: Scharnier zu nah am Rand #{in_tuer}")
  end
  check(s[1].zero? == (geteilt || h <= 200 || n < 3), "#{label}: Scharnier 2 nur bei ganzer Tür über 2 m")

  # Einlegeböden
  eb = sichtbar.count { |t2| t2[:name].start_with?('Einlegeboden') }
  check(eb == p['Anz_Einlegeboeden'].to_i, "#{label}: #{eb} Einlegeböden")
  [aktiv.map { |z| z.round(1) }, kb.map { |k| k[:q][4].round(1) }]
end

KANTEN_SOLL = {
  'SeiteL' => %i[ymin zmax], 'SeiteR' => %i[ymin zmax], 'Boden' => %i[ymin], 'Deckel' => %i[ymin],
  'Zwischenboden' => %i[ymin], 'Rückwand' => %i[xmin xmax zmax], 'Tuer' => %i[xmin xmax zmin zmax],
  'TuerL' => %i[xmin xmax zmin zmax], 'TuerR' => %i[xmin xmax zmin zmax], 'Innenfront' => %i[xmin xmax zmin zmax],
  'KastenRueckwand' => %i[zmax], 'KastenBoden' => []
}.merge((1..6).to_h { |k| ["Einlegeboden#{k}", %i[ymin]] }).freeze

def blaetter(k, out = [])
  k.kinder.each { |c| c.kinder.empty? ? out << c : blaetter(c, out) }
  out
end

def pruefe_material(w, label)
  m = Sketchup.active_model.materials
  platte = m[A::MATERIAL]; kante = m[A::KANTE]
  check(platte.get_attribute(A::OCL_DICT, 'type') == 2, "#{label}: Plattenmaterial Typ")
  check(platte.get_attribute(A::OCL_DICT, 'std_thicknesses').include?('12mm'), "#{label}: 12 mm als Stärke")
  check(kante.get_attribute(A::OCL_DICT, 'type') == 4, "#{label}: Anleimer Typ")
  tags = []
  blaetter(w).each do |b|
    soll = KANTEN_SOLL.fetch(b.name) { raise "kein Soll für #{b.name}" }
    check(b.inst.material.equal?(platte), "#{label}: #{b.name} ohne Plattenmaterial")
    check(b.inst.layer && b.inst.layer.name.start_with?('HV1_'), "#{label}: #{b.name} ohne Tag")
    tags << b.inst.layer.name
    jt = %w[schrank typ kategorie bereich teil rolle].to_h { |k| [k, b.inst.get_attribute(A::JT_DICT, k)] }
    check(jt['schrank'] == 'HV1' && jt['typ'] == 'Hochschrank Vorrat' && jt['kategorie'] == 'Hochschrank',
          "#{label}: #{b.name} JT_Schrank #{jt.inspect}")
    check(b.inst.layer.name == ['HV1', (jt['bereich'] unless jt['bereich'].empty?), jt['teil']].compact.join('_'),
          "#{label}: Tag #{b.inst.layer.name} passt nicht zu JT_Schrank")
    check(A::ROLLEN.value?(jt['rolle']), "#{label}: #{b.name} Rolle #{jt['rolle'].inspect}")
    ist = b.defn.entities.faces.select { |f| f.material.equal?(kante) }.map do |f|
      A::SEITEN.find { |_, (ax, vz)| f.normal.to_a[ax] * vz > 0.5 }.first
    end
    check(ist.sort == soll.sort, "#{label}: #{b.name} Anleimer #{ist.inspect} statt #{soll.inspect}")
  end
  dop = tags.tally.select { |_, k| k > 1 }
  check(dop.empty?, "#{label}: Tags nicht eindeutig: #{dop.keys.inspect}")
  tags.size
end

LAENGEN = %w[Breite Hoehe Tiefe H_Unten Hoehenoffset_Schiene].freeze

def lauf(p, label, umkonf = nil)
  Sketchup.active_model = Sketchup::Model.new
  inst = A.erstellen(p)
  p = A::DEFAULTS.merge(p)
  p['Fluegel'] = inst.definition.get_attribute(A::DICT, 'fluegel')
  w = Knoten.new(inst, inst.definition, nil)
  w.redraw
  erg = pruefe(w, p, label)
  pruefe_geometrie(w, label)
  n_tags = pruefe_material(w, label)
  puts "#{label}: #{n_tags} Teile; Scharniere bei #{erg[0].join(', ')} cm; Kästen bei #{erg[1].join(', ')} cm"
  return unless umkonf
  d = inst.definition
  umkonf.each { |k, v| d.set_attribute(A::DICT, k.downcase, LAENGEN.include?(k) ? v / 2.54 : v.to_f) }
  w2 = Knoten.new(inst, d, nil)
  w2.redraw
  pruefe(w2, p.merge(umkonf), "#{label} -> umkonfiguriert")
end

lauf({}, 'Standard (eine Tür, 4 Kästen, 3 Einlegeböden)',
     { 'Tueren' => 1, 'Anz_Kaesten' => 6, 'Anz_Einlegeboeden' => 6, 'Anschlag' => 1 })
lauf({ 'Breite' => 90.0 }, 'breit (zwei Flügel automatisch)',
     { 'Fluegel' => 1, 'Anschlag' => 1, 'Anz_Kaesten' => 2, 'Breite' => 45.0, 'Tiefe' => 56.0 })
lauf({ 'Tueren' => 1.0, 'Anz_Kaesten' => 3.0, 'Anteil_3' => 2.0, 'H_Unten' => 90.0 }, 'geteilt, unterster doppelt',
     { 'Tueren' => 0, 'Fluegel' => 2, 'Anz_Einlegeboeden' => 0, 'Hoehe' => 195.0 })
lauf({ 'Anz_Kaesten' => 5.0, 'Hoehe' => 230.0, 'H_Unten' => 120.0, 'Hoehenoffset_Schiene' => 0.7, 'Tiefe' => 56.0,
       'Anz_Einlegeboeden' => 5.0 }, 'hoch, 5 Kästen, Offset')
lauf({ 'Anz_Kaesten' => 2.0, 'Anz_Einlegeboeden' => 1.0, 'Hoehe' => 180.0, 'H_Unten' => 70.0 }, 'niedrig, 2 Kästen')
check(Sketchup.active_model.definitions[A::NAME].get_attribute(A::DICT, 'fluegel') == 1.0, 'Breite 600: ein Flügel')

# --- Tag-Schema ---------------------------------------------------------------
Sketchup.active_model = Sketchup::Model.new
A.erstellen({})
A.erstellen({})
A.erstellen({ 'Kuerzel' => 'HV7' })
ly = Sketchup.active_model.layers
check(%w[HV1_SeiteL HV1_Deckel HV1_ZwischenbodenUnten HV1_U_Tuer HV1_O_TuerR HV1_U1_Innenfront HV1_U6_KastenRueckwand
         HV1_O_Einlegeboden6 HV2_SeiteL HV7_Boden].all? { |x| ly[x] }, 'Tag-Namen <Kürzel>_<Bereich>_<Teil>')
quellen = Dir[File.expand_path('../../*/src/*/main.rb', __dir__)].map { |f| File.read(f, encoding: 'UTF-8') }
rollen = quellen.map { |q| q[/  ROLLEN = \{.*?\}\.freeze/m] }.compact
check(rollen.size >= 4 && rollen.uniq.size == 1, "ROLLEN-Tabelle in allen Komponenten gleich (#{rollen.size} gefunden)")

# --- Kurzhilfe ------------------------------------------------------------------
Sketchup.active_model = Sketchup::Model.new
ad = A.erstellen({}).definition
check(ad.description == A::HILFE_KURZ, 'Hilfe: Beschreibung der Definition')
check(ad.get_attribute(A::DICT, 'summary') == A::HILFE_KURZ && ad.get_attribute(A::DICT, 'description').nil?, 'Hilfe: summary/description')
check(File.exist?(File.expand_path('../README.md', __dir__)), 'README.md vorhanden')
check((1..6).all? { |i| ad.get_attribute(A::DICT, "_scharnier_#{i}_access") == 'VIEW' }, 'Scharnierhöhen in den Optionen sichtbar')

# --- Tiefe nachträglich ändern = gleich mit dieser Tiefe erzeugt ---
require_relative '../../../test/tiefe_helfer'
TiefeHelfer.pruefen(Knoten, A::DICT, ->(e) { A.erstellen(e) },
                    [[80.0, 52.0], [52.0, 40.0], [52.0, 65.0], [56.0, 47.3]]).each do |was, abw|
  check(abw.empty?, "Tiefe #{was}: " + abw.first(8).join('; '))
end

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
