# Test ohne SketchUp: Mock-API + kleiner DC-Formel-Auswerter.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
load File.expand_path('../src/eckschrank/main.rb', __dir__)

E = Eckschrank
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

  def name = inst&.get_attribute(E::DICT, '_name') || defn.get_attribute(E::DICT, '_name')

  def roh(attr)
    k = attr.downcase
    return @werte[k] if @werte.key?(k)
    v = inst&.get_attribute(E::DICT, k)
    v = defn.get_attribute(E::DICT, k) if v.nil?
    v = inst.transformation.origin[%w[x y z].index(k)] if v.nil? && inst && %w[x y z].include?(k)
    raise "Attribut #{attr} fehlt an #{name}" if v.nil?
    fu = defn.get_attribute(E::DICT, "_#{k}_formulaunits")
    %w[x y z lenx leny lenz].include?(k) || fu == 'CENTIMETERS' ? v * 2.54 : v
  end

  def formel(k) = inst&.get_attribute(E::DICT, "_#{k}_formula") || defn.get_attribute(E::DICT, "_#{k}_formula")

  def ref(n, attr)
    ziel = parent && parent.name == n ? parent : (parent ? parent.kinder : []).find { |s| s.name == n }
    raise "Referenz #{n}!#{attr} von #{name} nicht auflösbar" unless ziel
    ziel.roh(attr)
  end

  def IF(c, a, b) = c ? a : b
  def AND(*a) = a.all?
  def OR(*a) = a.any?
  def MAX(*a) = a.max
  def MIN(*a) = a.min

  def auswerten(f)
    ruby = f.gsub(/(?<![<>=!])=(?!=)/, '==').gsub(/(\w+)!(\w+)|\b([A-Za-z_]\w*)\b(?!\s*\()/) do
      $1 ? "ref(#{$1.inspect},#{$2.inspect})" : "roh(#{$3.inspect})"
    end
    v = instance_eval(ruby)
    v == true ? 1.0 : (v == false ? 0.0 : v.to_f)
  end

  def schluessel
    keys = (defn.attribute_dictionary(E::DICT)&.keys || []) + (inst&.attribute_dictionary(E::DICT)&.keys || [])
    keys.grep(/\A_(.+)_formula\z/) { $1 }.uniq.sort
  end

  # Attribute in Abhängigkeitsreihenfolge (einfach: mehrfach auswerten)
  def redraw
    3.times { schluessel.each { |k| @werte[k] = auswerten(formel(k)) } }
    kinder.each(&:redraw)
  end

  def wert(k) = roh(k)
  def finde(n) = kinder.find { |c| c.name == n } || raise("#{n} fehlt")
  def hidden? = (defn.get_attribute(E::DICT, '_hidden_formula') ? wert('hidden') > 0.5 : false)
  def pos(ax) = (formel(ax) ? wert(ax) : inst.transformation.origin[%w[x y z].index(ax)] * 2.54)
end

# Absolute Quader [x0,x1,y0,y1,z0,z1] aller Blatt-Teile, mit Sichtbarkeit
def teile(k, off = [0, 0, 0], versteckt = false, out = [])
  k.kinder.each do |c|
    o = off.each_with_index.map { |v, i| v + c.pos(%w[x y z][i]) }
    vs = versteckt || c.hidden?
    if c.kinder.empty?
      l = %w[lenx leny lenz].map { |a| c.formel(a) ? c.wert(a) : c.defn.box[%w[lenx leny lenz].index(a)] * 2.54 }
      out << { name: c.name, knoten: c, pfad: "#{k.name}/#{c.name}", q: [o[0], o[0] + l[0], o[1], o[1] + l[1], o[2], o[2] + l[2]], hidden: vs }
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
def blaetter(k, out = [])
  k.kinder.each { |c| c.kinder.empty? ? out << c : blaetter(c, out) }
  out
end
def nahe(a, b) = (a - b).abs < EPS

MK, SP, RW, BS = 1.9, 0.2, 0.8, 10.0

# --- Blindeck -------------------------------------------------------------------
def pruefe(w, p, label)
  b, h, t = p['Breite'], p['Hoehe'], p['Tiefe']
  v = p['Variante'].to_i
  rechts = p['Blindseite'].to_i == 1 # Blindseite rechts, Tür links
  tb = v == 2 ? p['LeMans'].to_f : p['Tuerbreite']
  check(nahe(w.wert('tb'), tb), "#{label}: Türbereich #{w.wert('tb')} statt #{tb}")
  alle = teile(w)
  sichtbar = alle.reject { |t2| t2[:hidden] }
  q = ->(n) { (sichtbar.find { |t2| t2[:name] == n } || raise("#{label}: #{n} fehlt/ausgeblendet"))[:q] }
  # Lage bei Blindseite links -> gespiegelt
  sx = ->(a) { rechts ? [b - a[1], b - a[0]] : a }

  sichtbar.each do |t2|
    a = t2[:q]
    check(a[0] >= -EPS && a[1] <= b + EPS && a[4] >= -EPS && a[5] <= h + EPS && a[2] >= -SP - EPS && a[3] <= t + MK + RW + EPS,
          "#{label}: #{t2[:pfad]} außerhalb #{a.map { |x| x.round(2) }}")
  end
  sichtbar.combination(2).each do |a, c|
    check(!ueberlapp?(a[:q], c[:q]), "#{label}: Kollision #{a[:pfad]} / #{c[:pfad]}")
  end

  # Korpus wie Unterschrank mit Tür
  check(nahe(q.('SeiteL')[0], 0) && nahe(q.('SeiteR')[1], b) && nahe(q.('SeiteL')[2], MK) && nahe(q.('SeiteL')[3], MK + t), "#{label}: Seiten")
  check(nahe(q.('Boden')[5], MK) && nahe(q.('Boden')[1] - q.('Boden')[0], b - 2 * MK), "#{label}: Boden zwischen den Seiten")
  check(nahe(q.('StrebeVorn')[3], MK + BS) && nahe(q.('StrebeVorn')[5], h) && nahe(q.('StrebeHinten')[3], MK + t), "#{label}: Streben")
  check(nahe(q.('Rückwand')[2], MK + t) && nahe(q.('Rückwand')[1], b), "#{label}: Rückwand hinter dem Korpus")

  # Blende über dem Blindteil, Tür(en) im Türbereich an der offenen Seite, Fugen 1/2 mm
  bl = q.('Blende')
  check([bl[0], bl[1]].zip(sx.([SP / 2, b - tb - SP / 2])).all? { |x, y| nahe(x, y) } && nahe(bl[2], -SP) && nahe(bl[3], MK - SP) &&
        nahe(bl[4], 0) && nahe(bl[5], h), "#{label}: Blende #{bl}")
  tueren = sichtbar.select { |t2| t2[:name].start_with?('Tür') }.map { |t2| [t2[:name], t2[:q]] }.to_h
  if v == 1
    check(tueren.keys.sort == %w[TürL TürR], "#{label}: zwei Türen #{tueren.keys}")
    l, r = sx.([b - tb + SP / 2, b - tb / 2 - SP / 2]), sx.([b - tb / 2 + SP / 2, b - SP / 2])
    l, r = r, l if rechts
    check(nahe(tueren['TürL'][0], l[0]) && nahe(tueren['TürL'][1], l[1]) && nahe(tueren['TürR'][0], r[0]) && nahe(tueren['TürR'][1], r[1]),
          "#{label}: Lage der zwei Türen #{tueren}")
    check(nahe(w.finde('TuerRHalter').pos('x'), rechts ? tb - SP / 2 : b - SP / 2), "#{label}: rechte Tür dreht um ihre rechte Kante")
  else
    check(tueren.keys == ['Tür'], "#{label}: eine Tür #{tueren.keys}")
    soll = sx.([b - tb + SP / 2, b - SP / 2])
    check(nahe(tueren['Tür'][0], soll[0]) && nahe(tueren['Tür'][1], soll[1]), "#{label}: Tür #{tueren['Tür']} statt #{soll}")
    hn = w.finde('TuerHalter')
    check(nahe(hn.pos('x'), rechts ? SP / 2 : b - SP / 2) && nahe(hn.wert('winkel'), rechts ? -100 : 100),
          "#{label}: Tür dreht um die Außenkante an der offenen Seite")
  end
  check(tueren.values.all? { |a| nahe(a[2], -SP) && nahe(a[4], 0) && nahe(a[5], h) }, "#{label}: Türen vor dem Korpus, volle Höhe")

  # Einlegeböden: Anzahl, gleichmäßig; bei Le Mans keine
  eb = sichtbar.select { |t2| t2[:name].start_with?('Einlegeboden') }
  n = v == 2 ? 0 : p['Anz_Einlegeboeden'].to_i
  check(eb.size == n, "#{label}: #{eb.size} Einlegeböden statt #{n}")
  eb.each_with_index do |t2, i|
    z = MK + (h - 2 * MK) * (i + 1) / (n + 1) - MK / 2
    check(nahe(t2[:q][4], z) && nahe(t2[:q][2], MK + 1.0), "#{label}: #{t2[:name]} Lage #{t2[:q]}")
  end

  # Le Mans: Platzhalter von der Seite an der Tür bis zum Säulenlager (X), sonst ausgeblendet
  lm = alle.find { |t2| t2[:name] == 'LeMans' }
  check(lm[:hidden] == (v != 2), "#{label}: Le-Mans-Platzhalter sichtbar nur bei Le Mans")
  if v == 2
    x = { 40 => 42.6, 45 => 47.6, 50 => 52.6, 60 => 62.6 }.fetch(p['LeMans'].to_i)
    soll = sx.([b - MK - x, b - MK])
    check(nahe(lm[:q][0], soll[0]) && nahe(lm[:q][1], soll[1]) && nahe(lm[:q][4], MK) && nahe(lm[:q][5], h - MK) &&
          nahe(lm[:q][3] - lm[:q][2], [t, 50].min), "#{label}: Le-Mans-Platzhalter #{lm[:q]}")
  end

  # Abstand zur Wand: Nachbar (Wand bis Front) + Passleiste - Blindteil
  check(nahe(w.wert('abstand_wand'), [p['Tiefe_Nachbar'] + p['Passleiste'] - b + tb, 0].max), "#{label}: Abstand zur Wand #{w.wert('abstand_wand')}")
end

KANTEN_SOLL = {
  'SeiteL' => %i[ymin], 'SeiteR' => %i[ymin], 'Boden' => %i[ymin], 'StrebeVorn' => %i[ymin], 'StrebeHinten' => [],
  'Rückwand' => [], 'Einlegeboden1' => %i[ymin], 'Einlegeboden2' => %i[ymin], 'Blende' => %i[xmin xmax zmin zmax],
  'Tür' => %i[xmin xmax zmin zmax], 'TürL' => %i[xmin xmax zmin zmax], 'TürR' => %i[xmin xmax zmin zmax], 'LeMans' => []
}.freeze
KANTEN_SOLL_L = {
  'SeiteR' => %i[ymin], 'SeiteL' => %i[xmax], 'Boden' => [], 'StrebeVorn1' => %i[ymin], 'StrebeVorn2' => %i[xmax],
  'StrebeHinten' => [], 'Rückwand1' => [], 'Rückwand2' => [], 'Einlegeboden1' => [],
  'Einlegeboden2' => [], 'TürR' => %i[xmin xmax zmin zmax], 'TürL' => %i[ymin ymax zmin zmax]
}.freeze

def pruefe_ocl(w, label, kz, soll_kanten, soll_tags)
  m = Sketchup.active_model.materials
  platte = m[E::MATERIAL]; kante = m[E::KANTE]
  check(platte.get_attribute(E::OCL_DICT, 'type') == 2, "#{label}: Plattenmaterial OCL-Typ")
  check(kante.get_attribute(E::OCL_DICT, 'type') == 4 && kante.get_attribute(E::OCL_DICT, 'edge_decremented') == true,
        "#{label}: Anleimer OCL")
  tags = []
  blaetter(w).each do |b|
    soll = soll_kanten.fetch(b.name) { raise "kein Soll für #{b.name}" }
    ist = b.defn.entities.faces.select { |f| f.material.equal?(kante) }.map do |f|
      E::SEITEN.find { |_, (ax, vz)| f.normal.to_a[ax] * vz > 0.5 }.first
    end
    check(ist.sort == soll.sort, "#{label}: #{b.name} Anleimer #{ist.inspect} statt #{soll.inspect}")
    tags << b.inst.layer.name
    if b.name == 'LeMans'
      check(b.inst.material.equal?(m[E::BESCHLAG]) && m[E::BESCHLAG].get_attribute(E::OCL_DICT, 'type') == 5,
            "#{label}: Le Mans ist in OCL ein Beschlag (Typ 5)")
      check(b.inst.attribute_dictionary(E::JT_DICT).nil?, "#{label}: Beschlag ohne JT_Schrank (kein Werkstück)")
      next
    end
    check(b.inst.material.equal?(platte), "#{label}: #{b.name} ohne Plattenmaterial")
    jt = %w[schrank typ kategorie bereich teil rolle].to_h { |k| [k, b.inst.get_attribute(E::JT_DICT, k)] }
    check(jt['schrank'] == kz && jt['typ'] == 'Eckschrank' && jt['kategorie'] == 'Unterschrank' && jt['bereich'] == '',
          "#{label}: #{b.name} JT_Schrank #{jt.inspect}")
    check(b.inst.layer&.name == "#{kz}_#{jt['teil']}", "#{label}: #{b.name} Tag #{b.inst.layer&.name}")
    check(E::ROLLEN.value?(jt['rolle']), "#{label}: #{b.name} Rolle #{jt['rolle'].inspect}")
  end
  check(tags.uniq.size == tags.size, "#{label}: Tags eindeutig #{tags}")
  check(soll_tags.sort == tags.map { |n| n.delete_prefix("#{kz}_") }.sort, "#{label}: Tag-Liste #{tags.inspect}")
end

TAGS_B = %w[SeiteL SeiteR Boden StrebeVorn StrebeHinten Rueckwand Einlegeboden1 Einlegeboden2 Blende Tuer TuerL TuerR LeMans].freeze

def lauf(p, label, umkonf = [], kz = 'UES1')
  Sketchup.active_model = Sketchup::Model.new
  inst = E.erstellen(p)
  p = E::DEFAULTS.merge(p)
  w = Knoten.new(inst, inst.definition, nil)
  w.redraw
  pruefe(w, p, label)
  pruefe_geometrie(w, label)
  pruefe_ocl(w, label, kz, KANTEN_SOLL, TAGS_B)
  d = inst.definition
  check(d.get_attribute(E::JT_DICT, 'schrank') == kz && d.get_attribute(E::JT_DICT, 'typ') == 'Eckschrank' &&
        d.get_attribute(E::JT_DICT, 'beschlag') == 'Kesseboehmer LeMans II', "#{label}: JT_Schrank am Schrank")
  # Umkonfigurieren über die Komponentenoptionen (wie SketchUp: Werte an der Definition, dann neu zeichnen)
  umkonf.each_with_index do |u, i|
    u.each { |k, v| d.set_attribute(E::DICT, k.downcase, %w[Breite Hoehe Tiefe Tuerbreite Tiefe_Nachbar Passleiste].include?(k) ? v / 2.54 : v.to_f) }
    p = p.merge(u)
    w2 = Knoten.new(inst, d, nil)
    w2.redraw
    pruefe(w2, p, "#{label} -> umkonfiguriert #{i + 1}")
  end
end

lauf({}, 'Standard: eine Tür, Blindseite links',
     [{ 'Variante' => 1 }, { 'Blindseite' => 1, 'Anz_Einlegeboeden' => 2 }, { 'Variante' => 2, 'LeMans' => 45 },
      { 'Breite' => 120.0, 'Tuerbreite' => 60.0, 'Variante' => 0, 'Hoehe' => 72.0 }])
lauf({ 'Variante' => 1.0, 'Blindseite' => 1.0, 'Anz_Einlegeboeden' => 2.0 }, 'zwei Türen, Blindseite rechts',
     [{ 'Blindseite' => 0, 'Tuerbreite' => 60.0 }])
lauf({ 'Variante' => 2.0 }, 'Le Mans 50 links', [{ 'Blindseite' => 1 }, { 'LeMans' => 60, 'Breite' => 110.0 }])
lauf({ 'Variante' => 2.0, 'Blindseite' => 1.0, 'LeMans' => 40.0, 'Breite' => 80.0, 'Tiefe' => 50.0 }, 'Le Mans 40 rechts')
lauf({ 'Kuerzel' => 'UES7' }, 'eigenes Kürzel', [], 'UES7')
[{ 'LeMans' => 55.0 }, { 'Tuerbreite' => 100.0 }].each do |falsch|
  Sketchup.active_model = Sketchup::Model.new
  E.erstellen(falsch)
  check(false, "abgelehnt: #{falsch}")
rescue ArgumentError
end

# --- L-Form ----------------------------------------------------------------------
TAGS_L = %w[SeiteL SeiteR Boden StrebeVorn1 StrebeVorn2 StrebeHinten Rueckwand1 Rueckwand2
            Einlegeboden1 Einlegeboden2 TuerL TuerR].freeze

def pruefe_l(w, p, label)
  a, bb, h, t = p['Schenkel_A'], p['Schenkel_B'], p['Hoehe'], p['Tiefe']
  yw = MK + t + RW
  xk = RW + t
  ye = yw - bb + MK
  alle = teile(w)
  sichtbar = alle.reject { |t2| t2[:hidden] }
  q = ->(n) { (sichtbar.find { |t2| t2[:name] == n } || raise("#{label}: #{n} fehlt/ausgeblendet"))[:q] }

  # Außenmaße: Schenkel A entlang der Wand hinten (y = yw), Schenkel B entlang der Wand links (x = 0)
  sichtbar.each do |t2|
    q2 = t2[:q]
    check(q2[0] >= -EPS && q2[1] <= a + EPS && q2[2] >= yw - bb - EPS && q2[3] <= yw + EPS && q2[4] >= -EPS && q2[5] <= h + EPS,
          "#{label}: #{t2[:pfad]} außerhalb #{q2.map { |x| x.round(2) }}")
  end
  # Kollisionen; L-Platten nur außerhalb ihrer Innenecke
  ecke = ->(t2) { (e = t2[:knoten].defn.get_attribute(E::DICT, 'ecke_x')) && [t2[:q][0] + e * 2.54, t2[:q][1], t2[:q][2], t2[:q][2] + t2[:knoten].defn.get_attribute(E::DICT, 'ecke_y') * 2.54] }
  sichtbar.combination(2).each do |s1, s2|
    next unless ueberlapp?(s1[:q], s2[:q])
    frei = [[s1, s2], [s2, s1]].any? do |l, o|
      # Überlappung der Quader liegt ganz in der ausgefrästen Ecke
      (n = ecke.(l)) && [l[:q][0], o[:q][0]].max >= n[0] - EPS && [l[:q][1], o[:q][1]].min <= n[1] + EPS &&
        [l[:q][2], o[:q][2]].max >= n[2] - EPS && [l[:q][3], o[:q][3]].min <= n[3] + EPS
    end
    check(frei, "#{label}: Kollision #{s1[:pfad]} / #{s2[:pfad]}")
  end
  check(nahe(q.('Rückwand1')[3], yw) && nahe(q.('Rückwand1')[0], 0) && nahe(q.('Rückwand1')[1], a), "#{label}: Rückwand A über die ganze Länge")
  check(nahe(q.('Rückwand2')[0], 0) && nahe(q.('Rückwand2')[2], yw - bb) && nahe(q.('Rückwand2')[3], MK + t), "#{label}: Rückwand B stößt an A")
  check(nahe(q.('SeiteR')[1], a) && nahe(q.('SeiteR')[2], MK) && nahe(q.('SeiteR')[3], MK + t), "#{label}: Seite Ende A")
  check(nahe(q.('SeiteL')[2], yw - bb) && nahe(q.('SeiteL')[0], RW) && nahe(q.('SeiteL')[1], xk), "#{label}: Seite Ende B")
  bd = alle.find { |t2| t2[:name] == 'Boden' }
  n = ecke.(bd)
  check(nahe(bd[:q][0], RW) && nahe(bd[:q][1], a - MK) && nahe(bd[:q][2], ye) && nahe(bd[:q][3], MK + t) && nahe(bd[:q][5], MK),
        "#{label}: L-Boden zwischen den Seiten #{bd[:q]}")
  check(nahe(n[0], xk) && nahe(n[3], MK), "#{label}: Innenecke des Bodens an der Korpusvorderkante #{n}")
  # Streben (Jürgens Skizze): vorn A durch die Ecke bis an die Rückwand von B, vorn B stößt an
  # vorn A, hinten nur an A über die ganze Länge
  sva, svb, sh = q.('StrebeVorn1'), q.('StrebeVorn2'), q.('StrebeHinten')
  check(nahe(sva[0], RW) && nahe(sva[1], a - MK) && nahe(sva[2], MK) && nahe(sva[3], MK + BS),
        "#{label}: Strebe vorn A durch die Ecke bis an die Rückwand B #{sva}")
  check(nahe(svb[3], sva[2]) && nahe(svb[2], ye) && nahe(svb[1], xk), "#{label}: Strebe vorn B stößt an Strebe vorn A #{svb}")
  check(nahe(sh[0], RW) && nahe(sh[1], a - MK) && nahe(sh[3], MK + t), "#{label}: Strebe hinten über die ganze Länge von A #{sh}")
  check(alle.none? { |t2| t2[:name] == 'StrebeHinten2' }, "#{label}: keine Strebe hinten an B")
  check([sva, svb, sh].all? { |s| nahe(s[5], h) }, "#{label}: Streben oben")
  # Falttür: Tür A vor Schenkel A durch die Ecke, Tür B vor Schenkel B bis 1 mm vor Tür A
  ta, tbq = q.('TürR'), q.('TürL')
  check(nahe(ta[2], -SP) && nahe(ta[3], MK - SP) && nahe(ta[0], xk + SP) && nahe(ta[1], a - SP / 2), "#{label}: Tür A #{ta}")
  check(nahe(tbq[0], xk + SP) && nahe(tbq[1], xk + SP + MK) && nahe(tbq[2], yw - bb + SP / 2) && nahe(tbq[3], -1.5 * SP),
        "#{label}: Tür B #{tbq}")
  check([ta, tbq].all? { |x| nahe(x[4], 0) && nahe(x[5], h) }, "#{label}: Türen volle Höhe")
  eb = sichtbar.select { |t2| t2[:name].start_with?('Einlegeboden') }
  k = p['Anz_Einlegeboeden'].to_i
  check(eb.size == k, "#{label}: #{eb.size} Einlegeböden statt #{k}")
  eb.each_with_index do |t2, i|
    z = MK + (h - 2 * MK) * (i + 1) / (k + 1) - MK / 2
    ne = ecke.(t2)
    check(nahe(t2[:q][4], z) && nahe(ne[0], xk - 1.0) && nahe(ne[3], MK + 1.0), "#{label}: #{t2[:name]} #{t2[:q]} Ecke #{ne}")
  end
end

def lauf_l(p, label, umkonf = nil)
  Sketchup.active_model = Sketchup::Model.new
  inst = E.erstellen(p, l_form: true)
  p = E::DEFAULTS_L.merge(p)
  w = Knoten.new(inst, inst.definition, nil)
  w.redraw
  pruefe_l(w, p, label)
  pruefe_geometrie(w, label)
  pruefe_ocl(w, label, 'UES1', KANTEN_SOLL_L, TAGS_L)
  d = inst.definition
  check(%w[schenkel_a schenkel_b tiefe].all? { |k| d.get_attribute(E::DICT, "_#{k}_access") == 'VIEW' }, "#{label}: Schenkel und Tiefe fest")
  return unless umkonf
  umkonf.each { |k, v| d.set_attribute(E::DICT, k.downcase, k == 'Hoehe' ? v / 2.54 : v.to_f) }
  w2 = Knoten.new(inst, d, nil)
  w2.redraw
  pruefe_l(w2, p.merge(umkonf), "#{label} -> umkonfiguriert")
end

lauf_l({}, 'L-Form 900 x 900', { 'Hoehe' => 78.0, 'Anz_Einlegeboeden' => 2 })
lauf_l({ 'Schenkel_A' => 75.6, 'Schenkel_B' => 75.6, 'Tiefe' => 46.0 }, 'L-Form 756 x 756, Tiefe 460 (Jürgens Skizze)')
lauf_l({ 'Schenkel_A' => 120.0, 'Schenkel_B' => 100.0, 'Tiefe' => 60.0, 'Anz_Einlegeboeden' => 0.0 }, 'L-Form 1200 x 1000',
       { 'Anz_Einlegeboeden' => 1 })
begin
  Sketchup.active_model = Sketchup::Model.new
  E.erstellen({ 'Schenkel_B' => 65.0 }, l_form: true)
  check(false, 'L-Form: zu kurzer Schenkel abgelehnt')
rescue ArgumentError
end

# Zweiter Schrank im selben Modell bekommt UES2
Sketchup.active_model = Sketchup::Model.new
E.erstellen({})
E.erstellen({}, l_form: true)
check(Sketchup.active_model.layers['UES1_Blende'] && Sketchup.active_model.layers['UES2_TuerL'], 'zweiter Schrank UES2')

# --- Kurzhilfe in der Komponente ------------------------------------------
{ 'Eckschrank Blindeck' => [E::HILFE_KURZ, E::HILFE], 'Eckschrank L-Form' => [E::HILFE_KURZ_L, E::HILFE_L] }.each do |n, (kurz, lang)|
  hd = Sketchup.active_model.definitions[n]
  check(hd.description == kurz, "Hilfe #{n}: Beschreibung der Definition")
  check(hd.get_attribute(E::DICT, 'summary') == kurz && hd.get_attribute(E::DICT, 'description') == lang, "Hilfe #{n}: summary/description")
  check(%w[summary description].all? { |k| hd.get_attribute(E::DICT, "_#{k}_access") == 'VIEW' }, "Hilfe #{n}: nur anzeigen")
  check(lang.include?(E::DOKU_URL), "Hilfe #{n}: Link zur Doku")
end
check(File.exist?(File.expand_path('../README.md', __dir__)), 'README.md vorhanden')

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
