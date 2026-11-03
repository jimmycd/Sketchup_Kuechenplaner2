# Test ohne SketchUp: Mock-API + kleiner DC-Formel-Auswerter.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
load File.expand_path('../src/hochschrank_kuehlschrank/main.rb', __dir__)

H = HochschrankKuehlschrank
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

LICHT = { 1 => 88.0, 2 => 102.0, 3 => 122.0, 4 => 140.0, 5 => 158.0, 6 => 178.0, 7 => 194.0 }.freeze

def nische_soll(p) = LICHT[p['Geraet'].to_i] || p['H_N_frei']

def pruefe(w, p, label)
  b, h, t = p['Breite'], p['Hoehe'], p['Tiefe']
  mk, sp, rw, nut = 1.9, 0.2, 0.8, 0.9
  n_u = p['Anz_Schubladen_Unten'].to_i
  hu = p['H_Unten']
  schacht = p['Lueftung'].to_i == 1
  kombi = p['Art_Geraet'].to_i == 3
  hn = nische_soll(p)
  zn = n_u.zero? ? mk : hu
  zo = zn + hn + mk
  ti = schacht ? t - p['Schacht'] - rw : t
  alle = teile(w)
  sichtbar = alle.reject { |t2| t2[:hidden] }
  by = ->(n) { sichtbar.find { |t2| t2[:name] == n } }

  # alle Teile (auch versteckte) innerhalb des Schranks
  alle.each do |t2|
    q = t2[:q]
    check(q[0] >= -EPS && q[1] <= b + EPS && q[4] >= -EPS && q[5] <= h + EPS && q[2] >= -sp - EPS && q[3] <= t + mk + rw + EPS,
          "#{label}: #{t2[:pfad]} außerhalb #{q.map { |v| v.round(2) }}")
  end
  sichtbar.combination(2).each do |a, c|
    # Rückwände bei Lüftungsschacht stecken in einer Nut der Seiten
    next if [a, c].map { |x| x[:name][/\ASeite|\ARueckwand(Oben|Unten)\z/] ? x[:name][0] : "-" }.sort == %w[R S]
    check(!ueberlapp?(a[:q], c[:q]), "#{label}: Kollision #{a[:pfad]} / #{c[:pfad]}")
  end

  # Nische: lichte Höhe zwischen dem Boden darunter und dem Zwischenboden oben
  unter = n_u.zero? ? by.('Boden') : by.('ZwischenbodenUnten')
  check(!!by.('ZwischenbodenUnten') == (n_u > 0), "#{label}: Zwischenboden unten sichtbar nur mit Schubladen")
  zob = by.('ZwischenbodenOben')
  check((unter[:q][5] - zn).abs < EPS && (zob[:q][4] - unter[:q][5] - hn).abs < EPS,
        "#{label}: Nische #{unter[:q][5].round(2)}..#{zob[:q][4].round(2)} statt #{zn}+#{hn}")
  check((zob[:q][5] - zo).abs < EPS, "#{label}: Oberkante Zwischenboden oben")
  check((w.wert('H_N') - hn).abs < EPS && (w.wert('Lichte_Breite') - (b - 2 * mk)).abs < EPS, "#{label}: H_N/Lichte Breite angezeigt")
  check((w.wert('H_Oben') - (h - zo)).abs < EPS, "#{label}: H_Oben")

  # Böden, Deckel und Einlegeböden enden bei Lüftungsschacht vor Schacht und Rückwand
  sichtbar.select { |t2| %w[Boden Deckel ZwischenbodenUnten ZwischenbodenOben].include?(t2[:name]) }.each do |bo|
    check((bo[:q][2] - mk).abs < EPS && (bo[:q][3] - (mk + ti)).abs < EPS, "#{label}: #{bo[:name]} Tiefe #{bo[:q][3] - bo[:q][2]} statt #{ti}")
  end
  sichtbar.select { |t2| t2[:name].start_with?('Einlegeboden') }.each do |eb|
    check((eb[:q][3] - (mk + ti)).abs < EPS, "#{label}: #{eb[:name]} hinten")
    check(eb[:q][4] > zo - EPS, "#{label}: #{eb[:name]} im oberen Fach")
  end
  ganz, ob, un = by.('Rückwand'), by.('RueckwandOben'), by.('RueckwandUnten')
  if schacht
    check(ganz.nil? && ob && (!!un == (n_u > 0)), "#{label}: Rückwände bei Schacht")
    [ob, un].compact.each do |r|
      q = r[:q]
      check((q[0] - (mk - nut)).abs < EPS && (q[1] - (b - mk + nut)).abs < EPS, "#{label}: #{r[:name]} in der Nut der Seiten")
      check((q[3] - (t + mk - p['Schacht'])).abs < EPS && (q[3] - q[2] - rw).abs < EPS, "#{label}: #{r[:name]} vor dem Schacht")
    end
    check((ob[:q][4] - (zo - mk)).abs < EPS && (ob[:q][5] - h).abs < EPS, "#{label}: Rückwand oben vom Zwischenboden bis oben")
    check(un[:q][4].abs < EPS && (un[:q][5] - hu).abs < EPS, "#{label}: Rückwand unten bis H_Unten") if un
    # in der Nische keine Rückwand
    check(sichtbar.none? { |t2| t2[:name].start_with?('R') && t2[:q][4] < zo - mk - EPS && t2[:q][5] > zn + EPS },
          "#{label}: Rückwand in der Nische")
  else
    check(ganz && ob.nil? && un.nil? && ganz[:q][4].abs < EPS && (ganz[:q][5] - h).abs < EPS, "#{label}: Rückwand durchgehend")
  end

  # Platzhalter füllt die Nische
  g = by.('GeraetN1')
  check((g[:q][4] - zn).abs < EPS && (g[:q][5] - g[:q][4] - hn).abs < EPS && (g[:q][3] - g[:q][2] - [p['Geraet_Tiefe'], t].min).abs < EPS,
        "#{label}: Platzhalter #{g[:q].map { |v| v.round(2) }}")

  # Fronten: Schubladen, Tür(en) der Nische, Tür oben; Fugen 2 mm, Türen 1 mm vom Rand
  fr = sichtbar.select { |t2| %w[Front Tuer TuerUnten TuerOben].include?(t2[:name]) }
  fr.each { |t2| check((t2[:q][0] - sp / 2).abs < EPS && (t2[:q][1] - (b - sp / 2)).abs < EPS, "#{label}: #{t2[:pfad]} Breite/Lage x") }
  fronten = fr.map { |t2| [t2[:q][4], t2[:q][5], t2[:name]] }.sort
  check(fronten.first[0].abs < EPS, "#{label}: unterste Front bei 0")
  soll_oben = p['Art_Oben'].to_i == 1 ? h : zo
  check((fronten.last[1] - soll_oben).abs < EPS, "#{label}: oberste Front #{fronten.last[1]} statt #{soll_oben}")
  fronten.each_cons(2) { |a, c| check((c[0] - a[1] - sp).abs < EPS, "#{label}: Fuge #{a[1].round(2)}..#{c[0].round(2)}") }
  namen = fronten.map { |f| f[2] }
  soll = ['Front'] * n_u + (kombi ? %w[TuerUnten TuerOben] : %w[Tuer]) + (p['Art_Oben'].to_i == 1 ? %w[Tuer] : [])
  check(namen == soll, "#{label}: Fronten #{namen.inspect} statt #{soll.inspect}")
  if kombi
    tu = fronten.find { |f| f[2] == 'TuerUnten' }
    check((tu[1] - tu[0] - p['H_Tuer_Unten']).abs < EPS, "#{label}: Höhe untere Tür")
  end
  # Drehpunkt am Anschlag
  sch = w.kinder.select { |k| k.name.start_with?('Scharnier') && !k.hidden? }
  x_soll = p['Anschlag'].to_i == 1 ? b - sp / 2 : sp / 2
  check(sch.all? { |k| (k.pos('x') - x_soll).abs < EPS && k.wert('winkel') == (p['Anschlag'].to_i == 1 ? 100 : -100) },
        "#{label}: Scharnier am Anschlag")

  # Schubkästen LEGRABOX, Nennlänge aus der lichten Tiefe bis zur Rückwand
  nl = ([35.0, 40.0, 45.0, 50.0, 55.0, 60.0, 65.0].select { |n| n + 0.3 <= ti + 1e-6 }.max || 35.0)
  check((w.wert('NL') - nl).abs < EPS, "#{label}: NL #{w.wert('NL')} statt #{nl}")
  boeden = sichtbar.select { |t2| t2[:name] == 'KastenBoden' }
  check(boeden.size == n_u, "#{label}: #{boeden.size} Kastenböden")
  boeden.each do |kb|
    q = kb[:q]
    loch = (q[4] + p['Hoehenoffset_Schiene'] - p['Lochraster_Start']) / p['Lochraster']
    check((loch - loch.round).abs < 1e-6, "#{label}: #{kb[:pfad]} nicht im Lochraster")
    check((q[3] - (mk + nl - 1.0)).abs < EPS && q[3] <= mk + ti + EPS, "#{label}: #{kb[:pfad]} Länge NL-10")
  end
  eb = sichtbar.count { |t2| t2[:name].start_with?('Einlegeboden') }
  check(eb == p['Anz_Einlegeboeden_Oben'].to_i, "#{label}: Einlegeböden #{eb}")
  fronten
end

KANTEN_SOLL = {
  'SeiteL' => %i[ymin zmax], 'SeiteR' => %i[ymin zmax], 'Boden' => %i[ymin], 'Deckel' => %i[ymin],
  'ZwischenbodenUnten' => %i[ymin], 'ZwischenbodenOben' => %i[ymin],
  'Rückwand' => %i[xmin xmax zmax], 'RueckwandOben' => [], 'RueckwandUnten' => [],
  'Tuer' => %i[xmin xmax zmin zmax], 'TuerUnten' => %i[xmin xmax zmin zmax], 'TuerOben' => %i[xmin xmax zmin zmax],
  'Front' => %i[xmin xmax zmin zmax], 'KastenRueckwand' => %i[zmax], 'KastenBoden' => []
}.freeze

def blaetter(k, out = [])
  k.kinder.each { |c| c.kinder.empty? ? out << c : blaetter(c, out) }
  out
end

def pruefe_material(w, label)
  m = Sketchup.active_model.materials
  platte = m[H::MATERIAL]; kante = m[H::KANTE]
  check(platte.get_attribute(H::OCL_DICT, 'type') == 2 && kante.get_attribute(H::OCL_DICT, 'type') == 4 &&
        kante.get_attribute(H::OCL_DICT, 'thickness') == '2mm', "#{label}: Platten- und Kantenmaterial")
  tags = []
  blaetter(w).each do |b|
    if b.name == 'GeraetN1'
      check(b.inst.layer&.name == H::GERAET_TAG && b.inst.attribute_dictionary(H::JT_DICT).nil? &&
            b.inst.material.equal?(m[H::GERAET_MATERIAL]), "#{label}: Platzhalter kein Schrankteil")
      next
    end
    soll = b.name.start_with?('Einlegeboden') ? %i[ymin] : KANTEN_SOLL.fetch(b.name) { raise "kein Soll für #{b.name}" }
    check(b.inst.material.equal?(platte), "#{label}: #{b.name} ohne Plattenmaterial")
    tags << b.inst.layer.name
    jt = %w[schrank typ kategorie bereich teil rolle].to_h { |k| [k, b.inst.get_attribute(H::JT_DICT, k)] }
    check(jt['schrank'] == 'HK1' && jt['typ'] == 'Hochschrank_Kuehlgeraet' && jt['kategorie'] == 'Hochschrank',
          "#{label}: #{b.name} JT_Schrank #{jt.inspect}")
    check(b.inst.layer.name == ['HK1', (jt['bereich'] unless jt['bereich'].empty?), jt['teil']].compact.join('_'),
          "#{label}: Tag #{b.inst.layer.name} passt nicht zu JT_Schrank")
    check(H::ROLLEN.value?(jt['rolle']), "#{label}: #{b.name} Rolle #{jt['rolle'].inspect}")
    ist = b.defn.entities.faces.select { |f| f.material.equal?(kante) }.map do |f|
      H::SEITEN.find { |_, (ax, vz)| f.normal.to_a[ax] * vz > 0.5 }.first
    end
    check(ist.sort == soll.sort, "#{label}: #{b.name} Anleimer #{ist.inspect} statt #{soll.inspect}")
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
  n_tags = pruefe_material(w, label)
  # JT_Nische_N1 (Schnittstelle zu den Geräte-Komponenten), mm
  nd = inst.definition.attribute_dictionary('JT_Nische_N1')
  kenn = { 1 => 'Kuehlgeraet88', 2 => 'Kuehlgeraet102', 3 => 'Kuehlgeraet122', 4 => 'Kuehlgeraet140',
           5 => 'Kuehlgeraet158', 6 => 'Kuehlgeraet178', 7 => 'Kuehlgeraet194', 0 => 'Kuehlgeraet' }
  soll = { 'nische' => 'N1', 'geraet' => kenn[p['Geraet'].to_i], 'art' => %w[- Kuehlschrank Gefrierschrank KuehlGefrier][p['Art_Geraet'].to_i],
           'breite' => ((p['Breite'] - 3.8) * 10).round(1), 'hoehe' => (nische_soll(p) * 10).round(1),
           'tiefe' => (p['Tiefe'] * 10).round(1), 'x' => 19.0, 'y' => 19.0,
           'z' => ((p['Anz_Schubladen_Unten'].to_i.zero? ? 1.9 : p['H_Unten']) * 10).round(1) }
  check(nd == soll, "#{label}: JT_Nische_N1 #{nd.inspect} statt #{soll.inspect}")
  puts "#{label}: #{n_tags} Teile mit eigenem Tag, Fronten " + fr.map { |a, c, n| "#{n} #{a.round(1)}–#{c.round(1)}" }.join(', ')
  return unless umkonf
  d = inst.definition
  laengen = %w[Breite Hoehe Tiefe H_Unten H_N_frei H_Tuer_Unten Schacht]
  umkonf.each { |k, v| inst.set_attribute(H::DICT, k.downcase, laengen.include?(k) ? v / 2.54 : v.to_f) }
  w2 = Knoten.new(inst, d, nil)
  w2.redraw
  pruefe(w2, p.merge(umkonf), "#{label} -> umkonfiguriert")
end

lauf({}, 'Standard (1780, Schlepptür, Schacht, Tür oben)',
     { 'Art_Geraet' => 3, 'Anschlag' => 0, 'H_Tuer_Unten' => 70.0, 'Anz_Einlegeboeden_Oben' => 1 })
lauf({ 'Geraet' => 2.0, 'Anz_Schubladen_Unten' => 3.0, 'H_Unten' => 80.0, 'Anteil_U3' => 2.0, 'Anz_Einlegeboeden_Oben' => 2.0 },
     '1020 über Schubladen', { 'Lueftung' => 0, 'Anz_Schubladen_Unten' => 1, 'Art_Oben' => 0 })
lauf({ 'Geraet' => 7.0, 'Art_Geraet' => 3.0, 'Hoehe' => 230.0, 'Anschlag' => 0.0, 'Art_Oben' => 0.0 }, 'Kombi 1940, Anschlag links',
     { 'Geraet' => 5, 'Art_Geraet' => 2, 'Anschlag' => 1, 'Art_Oben' => 1 })
lauf({ 'Geraet' => 0.0, 'H_N_frei' => 120.0, 'Lueftung' => 0.0, 'Anz_Schubladen_Unten' => 2.0, 'Tiefe' => 60.0 },
     'freie Höhe, Frontlüftung', { 'Lueftung' => 1, 'Schacht' => 5.0, 'Tiefe' => 58.0, 'Anz_Schubladen_Unten' => 4 })
lauf({ 'Geraet' => 1.0, 'Anz_Schubladen_Unten' => 4.0, 'H_Unten' => 90.0 }, '880 über 4 Schubladen',
     { 'Anz_Schubladen_Unten' => 0, 'Geraet' => 2, 'Tuertechnik' => 2 })

# --- Tag-Schema ---------------------------------------------------------------
Sketchup.active_model = Sketchup::Model.new
H.erstellen({ 'Art_Geraet' => 3.0 })
H.erstellen({})
H.erstellen({ 'Kuerzel' => 'HK7' })
ly = Sketchup.active_model.layers
check(%w[HK1_SeiteL HK1_Deckel HK1_ZwischenbodenOben HK1_RueckwandOben HK1_N_Tuer HK1_N_TuerUnten HK1_N_TuerOben HK1_O_Tuer
         HK1_U1_Front HK1_O_Einlegeboden2 HK2_SeiteL HK7_Boden Geraete_Plan].all? { |n| ly[n] }, 'Tag-Namen <Kürzel>_<Bereich>_<Teil>')
hd = Sketchup.active_model.definitions[H::NAME]
nb = hd.entities.instances.to_h { |i| [i.name, i.get_attribute(H::JT_DICT, 'nische')] }
check(nb['Boden'] == 'N1' && nb['ZwischenbodenUnten'] == 'N1' && nb['ZwischenbodenOben'].nil?, "Nischen-Markierung: #{nb.compact}")
quellen = Dir[File.expand_path('../../*/{*.rb,src/*/main.rb}', __dir__)].map { |f| File.read(f, encoding: 'UTF-8') }
rollen = quellen.map { |q| q[/  ROLLEN = \{.*?\}\.freeze/m] }.compact
check(rollen.size >= 5 && rollen.uniq.size == 1, "ROLLEN-Tabelle in allen Komponenten gleich (#{rollen.size} gefunden)")

# --- Auswahllisten und Hinweise -----------------------------------------------
check(H.nischen_liste.start_with?('&880%20mm=1&1020%20mm=2&') && H.nischen_liste.include?('1940%20mm=7') &&
      H.nischen_liste.ascii_only?, "Nischenliste: #{H.nischen_liste}")
check(H.hinweise({}).empty?, "keine Hinweise beim Standard: #{H.hinweise({})}")
check(H.hinweise({ 'Tiefe' => 52.0 }).first.to_s.include?('550'), 'Hinweis Tiefe unter 550 mm')
check(H.hinweise({ 'Breite' => 55.0 }).any? { |x| x.include?('560') }, 'Hinweis lichte Breite')
check(H.hinweise({ 'Hoehe' => 180.0 }).any? { |x| x.include?('Höhe') }, 'Hinweis Höhe')

# --- Kurzhilfe in der Komponente ------------------------------------------
Sketchup.active_model = Sketchup::Model.new
hd = H.erstellen({}).definition
check(hd.description == H::HILFE_KURZ && hd.get_attribute(H::DICT, 'summary') == H::HILFE_KURZ &&
      hd.get_attribute(H::DICT, 'description').nil?, 'Hilfe: Beschreibung, summary, description')
check(%w[summary description].none? { |k| hd.get_attribute(H::DICT, "_#{k}_access") }, 'Hilfe: keine eigenen Zeilen in den Optionen')
check(File.exist?(File.expand_path('../README.md', __dir__)), 'README.md vorhanden')

# --- Tiefe nachträglich ändern (Komponentenoptionen) = gleich mit dieser Tiefe erzeugt ---
require_relative '../../../test/tiefe_helfer'
[{}, { 'Anz_Schubladen_Unten' => 3.0 }, { 'Lueftung' => 0.0, 'Anz_Schubladen_Unten' => 2.0 }].each do |e|
  TiefeHelfer.pruefen(Knoten, H::DICT, ->(x) { H.erstellen(x) },
                      [[56.0, 52.0], [52.0, 60.0], [60.0, 45.0]], e).each do |was, abw|
    check(abw.empty?, "Tiefe #{was} #{e}: " + abw.first(8).join('; '))
  end
end

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
