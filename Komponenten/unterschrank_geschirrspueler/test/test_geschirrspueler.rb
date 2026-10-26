# Test ohne SketchUp: Mock-API + kleiner DC-Formel-Auswerter.
$LOAD_PATH.unshift(__dir__)
$GESCHIRRSPUELER_TEST = true
require 'sketchup_mock'
load File.expand_path('../geschirrspueler.rb', __dir__)

H = UnterschrankGeschirrspueler
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
  def OR(*a) = a.any?

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
def blaetter(k, out = [])
  k.kinder.each { |c| c.kinder.empty? ? out << c : blaetter(c, out) }
  out
end
def nahe(a, b) = (a - b).abs < EPS

KANTEN_SOLL = { 'Front' => %i[xmin xmax zmin zmax], 'WangeL' => %i[ymin zmax], 'WangeR' => %i[ymin zmax] }.freeze

def pruefe(w, p, label)
  b, h, t, fh, so = p['Breite'], p['Hoehe'], p['Tiefe'], p['Fronthoehe'], p['Sockelhoehe']
  mk, sp, rw = 1.9, 0.2, 0.8
  art = p['Art_Wange'].to_i
  links, rechts = [1, 3].include?(art), [2, 3].include?(art)
  xn = links ? mk : 0
  alle = teile(w)
  sichtbar = alle.reject { |t2| t2[:hidden] }
  q = ->(n) { (sichtbar.find { |t2| t2[:name] == n } || raise("#{label}: #{n} fehlt"))[:q] }

  # Front: Nischenbreite - 2 mm, 1 mm Fuge je Seite, Oberkante = Korpusoberkante, 2 mm vor dem Korpus
  f = q.('Front')
  check(nahe(f[0], xn + sp / 2) && nahe(f[1], xn + b - sp / 2), "#{label}: Front x #{f[0..1]}")
  check(nahe(f[5], h) && nahe(f[5] - f[4], fh), "#{label}: Front Höhe #{f[4..5]}")
  check(nahe(f[2], -sp) && nahe(f[3] - f[2], mk), "#{label}: Front y #{f[2..3]}")

  # Wangen außerhalb der Nische, Tiefe wie Korpus + Rückwand, bis zum Boden
  namen = sichtbar.map { |t2| t2[:name] }
  check(namen.include?('WangeL') == links && namen.include?('WangeR') == rechts, "#{label}: Wangen #{namen}")
  if links
    wl = q.('WangeL')
    check(nahe(wl[0], 0) && nahe(wl[1], mk), "#{label}: WangeL x #{wl[0..1]}")
  end
  if rechts
    wr = q.('WangeR')
    check(nahe(wr[0], xn + b) && nahe(wr[1], xn + b + mk), "#{label}: WangeR x #{wr[0..1]}")
  end
  sichtbar.select { |t2| t2[:name].start_with?('Wange') }.each do |t2|
    a = t2[:q]
    check(nahe(a[2], mk) && nahe(a[3], mk + t + rw) && nahe(a[4], -so) && nahe(a[5], h), "#{label}: #{t2[:name]} #{a}")
  end

  # Gerät: in der Nische, 1 mm Luft je Seite, vom Boden bis Oberkante Korpus, hinter der Front
  g = q.('Geraet')
  check(nahe(g[0], xn + 0.1) && nahe(g[1], xn + b - 0.1) && nahe(g[4], -so) && nahe(g[5], h) && nahe(g[2], mk) &&
        nahe(g[3] - g[2], 55.0), "#{label}: Gerät #{g}")
  check(sichtbar.combination(2).none? { |a, c| ueberlapp?(a[:q], c[:q]) }, "#{label}: Kollision")
end

def pruefe_ocl(w, inst, p, label, kz)
  m = Sketchup.active_model.materials
  platte = m[H::MATERIAL]; kante = m[H::KANTE]
  check(platte.get_attribute(H::OCL_DICT, 'type') == 2, "#{label}: Plattenmaterial OCL-Typ")
  check(kante.get_attribute(H::OCL_DICT, 'type') == 4 && kante.get_attribute(H::OCL_DICT, 'edge_decremented') == true,
        "#{label}: Anleimer OCL")
  tags = []
  blaetter(w).each do |b|
    if b.name == 'Geraet'
      check(b.inst.layer&.name == H::GERAET_TAG, "#{label}: Gerät auf Tag Geraete_Plan")
      check(b.inst.attribute_dictionary(H::JT_DICT).nil?, "#{label}: Gerät ohne JT_Schrank")
      check(b.inst.material && b.inst.material.get_attribute(H::OCL_DICT, 'type').nil?, "#{label}: Gerät ohne OCL-Material")
      next
    end
    soll = KANTEN_SOLL.fetch(b.name) { raise "kein Soll für #{b.name}" }
    check(b.inst.material.equal?(platte), "#{label}: #{b.name} ohne Plattenmaterial")
    ist = b.defn.entities.faces.select { |f| f.material.equal?(kante) }.map do |f|
      H::SEITEN.find { |_, (ax, vz)| f.normal.to_a[ax] * vz > 0.5 }.first
    end
    check(ist.sort == soll.sort, "#{label}: #{b.name} Anleimer #{ist.inspect} statt #{soll.inspect}")
    jt = %w[schrank typ kategorie bereich teil rolle].to_h { |k| [k, b.inst.get_attribute(H::JT_DICT, k)] }
    check(jt['schrank'] == kz && jt['typ'] == H::TYP && jt['kategorie'] == 'Unterschrank' && jt['bereich'] == '',
          "#{label}: #{b.name} JT_Schrank #{jt.inspect}")
    check(b.inst.layer&.name == "#{kz}_#{jt['teil']}", "#{label}: #{b.name} Tag #{b.inst.layer&.name}")
    check(jt['rolle'] == (b.name == 'Front' ? 'Front' : 'Wange'), "#{label}: #{b.name} Rolle #{jt['rolle'].inspect}")
    tags << b.inst.layer.name
  end
  check(tags.sort == %W[#{kz}_Front #{kz}_WangeL #{kz}_WangeR].sort, "#{label}: Tag-Liste #{tags.inspect}")

  # Nische für die Geräte-Komponenten
  n = inst.definition.attribute_dictionary(H::NISCHE_DICT)
  xn = [1, 3].include?(p['Art_Wange'].to_i) ? 19.0 : 0.0
  soll = { 'nische' => 'N1', 'geraet' => "Geschirrspueler#{p['Breite'].round}", 'breite' => p['Breite'] * 10 - 2,
           'hoehe' => (p['Hoehe'] + p['Sockelhoehe']) * 10, 'tiefe' => p['Tiefe'] * 10, 'x' => xn, 'y' => 19.0,
           'z' => -p['Sockelhoehe'] * 10 }
  check(soll.all? { |k, v| v.is_a?(String) ? n[k] == v : nahe(n[k], v) }, "#{label}: JT_Nische #{n.inspect}")
end

def lauf(p, label, umkonf = nil, kz = 'USG1')
  Sketchup.active_model = Sketchup::Model.new
  inst = H.erstellen(p)
  p = H::DEFAULTS.merge(p)
  w = Knoten.new(inst, inst.definition, nil)
  w.redraw
  pruefe(w, p, label)
  pruefe_geometrie(w, label)
  pruefe_ocl(w, inst, p, label, kz)
  return unless umkonf
  d = inst.definition
  laengen = %w[Breite Hoehe Tiefe Fronthoehe Sockelhoehe]
  umkonf.each { |k, v| d.set_attribute(H::DICT, k.downcase, laengen.include?(k) ? v / 2.54 : v.to_f) }
  w2 = Knoten.new(inst, d, nil)
  w2.redraw
  pruefe(w2, p.merge(umkonf), "#{label} -> umkonfiguriert")
end

lauf({}, 'Standard 60', { 'Breite' => 45.0, 'Art_Wange' => 3, 'Fronthoehe' => 72.0 })
lauf({ 'Breite' => 45.0, 'Art_Wange' => 1.0 }, '45 mit Wange links', { 'Art_Wange' => 2, 'Sockelhoehe' => 15.0, 'Hoehe' => 72.0 })
lauf({ 'Art_Wange' => 3.0, 'Fronthoehe' => 68.0, 'Sockelhoehe' => 12.0 }, 'beide Wangen, kürzere Front', { 'Art_Wange' => 0 })
lauf({ 'Art_Wange' => 2.0, 'Tiefe' => 56.0 }, 'Wange rechts', { 'Breite' => 60.0, 'Tiefe' => 60.0 })
lauf({ 'Kuerzel' => 'USG7' }, 'eigenes Kürzel', nil, 'USG7')

# Zweiter Schrank im selben Modell bekommt USG2
Sketchup.active_model = Sketchup::Model.new
H.erstellen({})
H.erstellen({})
check(Sketchup.active_model.layers['USG2_Front'], 'zweiter Schrank USG2')
check(Sketchup.active_model.definitions[H::NAME].get_attribute(H::JT_DICT, 'kategorie') == 'Unterschrank', 'JT_Schrank am Schrank')
fd = Sketchup.active_model.definitions['Front']
check(fd.get_attribute(H::DICT, 'onclick') == 'ANIMATE("ROTX",0,90)', 'Front klappt auf')

# --- Kurzhilfe in der Komponente ------------------------------------------
hd = Sketchup.active_model.definitions[H::NAME]
check(hd.description == H::HILFE_KURZ, 'Hilfe: Beschreibung der Definition')
check(hd.get_attribute(H::DICT, 'summary') == H::HILFE_KURZ, 'Hilfe: summary')
check(hd.get_attribute(H::DICT, 'description') == H::HILFE, 'Hilfe: description')
check(H::HILFE.include?(H::DOKU_URL) && H::HILFE.include?('Fronthöhe zum Gerät'), 'Hilfe: Link zur Doku, Hinweis Fronthöhe')
check(File.exist?(File.expand_path('../README.md', __dir__)), 'README.md vorhanden')

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
