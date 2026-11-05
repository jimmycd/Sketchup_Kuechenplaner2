# Test ohne SketchUp: Rendern mit Blender – Export (OBJ/MTL/JSON), Sichtbarkeit wie
# Szene Kunde, Kamera, Blender-Suche, Fortschritt aus dem Log.
# Ist Python mit dem Modul bpy vorhanden (Umgebungsvariable BPY_PYTHON oder python3 mit
# bpy), rendert der Test die Testküche zusätzlich echt mit Blender Cycles.
require 'json'
require 'tmpdir'
require 'fileutils'
require 'zlib'

$fehler = 0
def check(bed, text)
  if bed
    puts "OK: #{text}"
  else
    puts "FEHLER: #{text}"
    $fehler += 1
  end
end

# --- kleiner Ersatz für die SketchUp-API mit echten Transformationen -------------------
module Geom
  class Point3d
    attr_reader :x, :y, :z
    def initialize(x, y, z) = (@x, @y, @z = x.to_f, y.to_f, z.to_f)
    def to_a = [x, y, z]
    def transform(t) = t.punkt(self)
  end
  Vector3d = Point3d

  class Transformation
    attr_reader :m # 4×4, Zeilen
    def initialize(m = nil) = @m = m || [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]].map { |r| r.map(&:to_f) }
    def self.translation(v) = new([[1, 0, 0, v[0]], [0, 1, 0, v[1]], [0, 0, 1, v[2]], [0, 0, 0, 1]])
    def self.scaling(x, y, z) = new([[x, 0, 0, 0], [0, y, 0, 0], [0, 0, z, 0], [0, 0, 0, 1]])
    def *(o) = Transformation.new((0..3).map { |i| (0..3).map { |j| (0..3).sum { |k| @m[i][k] * o.m[k][j] } } })
    def punkt(p) = Point3d.new(*(0..2).map { |i| @m[i][0] * p.x + @m[i][1] * p.y + @m[i][2] * p.z + @m[i][3] })
    def to_a = (0..3).flat_map { |j| (0..3).map { |i| @m[i][j] } } # spaltenweise wie SketchUp
  end
end

module Sketchup
  class Color
    attr_reader :red, :green, :blue
    def initialize(r, g, b) = (@red, @green, @blue = r, g, b)
  end

  class Texture
    attr_reader :filename, :width, :height
    def initialize(f, w, h) = (@filename, @width, @height = f, w, h)
    def write(pfad, _farbig = false)
      File.binwrite(pfad, Sketchup.png_streifen)
      true
    end
  end

  class Material
    attr_reader :name, :color, :texture
    attr_accessor :alpha
    def initialize(name, rgb, texture = nil) = (@name, @color, @texture, @alpha = name, Color.new(*rgb), texture, 1.0)
    def display_name = @name
  end

  class Layer
    attr_reader :name
    attr_writer :visible
    def initialize(n, v = true) = (@name, @visible = n, v)
    def visible? = @visible
  end

  class Mesh
    def initialize(pts, polys, uvs) = (@pts, @polys, @uvs = pts, polys, uvs)
    def count_points = @pts.size
    def point_at(i) = Geom::Point3d.new(*@pts[i - 1])
    def uv_at(i, _vorne) = Geom::Point3d.new(*@uvs[i - 1], 1.0)
    attr_reader :polys
    alias polygons polys
  end

  class Face
    attr_accessor :material, :back_material, :layer, :hidden
    # Rechteck in der Ebene z (Punkte in Zoll), zwei Dreiecke
    def initialize(pts, layer = nil) = (@pts, @layer = pts, layer)
    def hidden? = @hidden ? true : false
    def mesh(_flags) = Mesh.new(@pts, [[1, 2, -3], [1, -3, 4]], @pts.map { |p| [p[0], p[1]] })
  end

  class Entities
    include Enumerable
    def initialize = @l = []
    def <<(e) = (@l << e; self)
    def each(&) = @l.each(&)
  end

  class Definition
    attr_reader :entities
    def initialize = @entities = Entities.new
  end

  class ComponentInstance
    attr_accessor :material, :layer, :hidden
    attr_reader :definition, :transformation
    def initialize(d, t, layer = nil) = (@definition, @transformation, @layer = d, t, layer)
    def hidden? = @hidden ? true : false
  end

  class Group
    attr_accessor :material, :layer
    attr_reader :entities, :transformation
    def initialize(t) = (@entities, @transformation = Entities.new, t)
    def hidden? = false
  end

  class Page
    attr_reader :layers
    def initialize(versteckt) = @layers = versteckt
    def use_hidden_layers? = true
  end

  class Pages
    def initialize = @h = {}
    def [](n) = @h[n]
    def add(n, p) = @h[n] = p
  end

  class Camera
    attr_reader :eye, :target, :up, :fov
    def initialize(e, t, u, fov) = (@eye, @target, @up, @fov = Geom::Point3d.new(*e), Geom::Point3d.new(*t), Geom::Point3d.new(*u), fov)
    def perspective? = true
    def fov_is_height? = true
  end

  class View
    attr_accessor :camera
    def vpwidth = 1600
    def vpheight = 900
  end

  class Model
    attr_reader :entities, :pages, :active_view
    attr_accessor :path
    def initialize = (@entities, @pages, @active_view, @path = Entities.new, Pages.new, View.new, '')
    def shadow_info = { 'SunDirection' => Geom::Vector3d.new(0.4, -0.6, 0.7) }
  end

  # 8×8-PNG mit Holzstreifen (hell/dunkel) als Textur
  def self.png_streifen
    chunk = ->(t, d) { [d.bytesize].pack('N') + t + d + [Zlib.crc32(t + d)].pack('N') }
    zeilen = (0...8).map { |y| "\x00".b + (0...8).map { |_x| y.even? ? [200, 160, 110].pack('C3') : [150, 110, 70].pack('C3') }.join }
    "\x89PNG\r\n\x1a\n".b + chunk.call('IHDR', [8, 8, 8, 2, 0, 0, 0].pack('NNC5')) +
      chunk.call('IDAT', Zlib::Deflate.deflate(zeilen.join)) + chunk.call('IEND', '')
  end

  def self.defaults = (@defaults ||= {})
  def self.read_default(s, k, d = nil) = defaults.fetch([s, k], d)
  def self.write_default(s, k, v) = defaults[[s, k]] = v
end

module Kuechenplaner
  module Eingabe
    def self.css = ':root{}'
  end
end

load File.join(__dir__, '../src/jt_schrank_cnc/rendern.rb')
R = JTools::SchrankCnc::Rendern

# --- Testküche: Boden, Korpus, Front (Holztextur, gespiegelt), Glas, Plan-Platzhalter ----
def rechteck(x0, y0, x1, y1, z) = [[x0, y0, z], [x1, y0, z], [x1, y1, z], [x0, y1, z]]

def quader(defn, b, t, h)
  e = defn.entities
  e << Sketchup::Face.new(rechteck(0, 0, b, t, 0)) << Sketchup::Face.new(rechteck(0, 0, b, t, h))
  # Seiten als senkrechte Flächen
  e << Sketchup::Face.new([[0, 0, 0], [b, 0, 0], [b, 0, h], [0, 0, h]])
  e << Sketchup::Face.new([[0, t, 0], [b, t, 0], [b, t, h], [0, t, h]])
  e << Sketchup::Face.new([[0, 0, 0], [0, t, 0], [0, t, h], [0, 0, h]])
  e << Sketchup::Face.new([[b, 0, 0], [b, t, 0], [b, t, h], [b, 0, h]])
end

model = Sketchup::Model.new
weiss = Sketchup::Material.new('Melamin weiss', [245, 245, 240])
eiche = Sketchup::Material.new('Front Eiche natur', [180, 140, 90], Sketchup::Texture.new('eiche.jpg', 20.0, 10.0))
glas = Sketchup::Material.new('Glas klar', [200, 220, 230])
glas.alpha = 0.3
boden_mat = Sketchup::Material.new('Raum Boden', [120, 110, 100])
tag_raum = Sketchup::Layer.new('Raum-Boden')
tag_plan = Sketchup::Layer.new('Geraete_Plan')
tag_render = Sketchup::Layer.new('Geraete_Render', false)
tag_text = Sketchup::Layer.new('Beschriftung')

boden = Sketchup::Face.new(rechteck(-40, -40, 120, 80, 0), tag_raum)
boden.material = boden_mat
model.entities << boden
korpus = Sketchup::Definition.new
quader(korpus, 23.6, 20.5, 28.3)
schrank = Sketchup::ComponentInstance.new(korpus, Geom::Transformation.translation([0, 0, 3.94]))
schrank.material = weiss
model.entities << schrank
# Front: Material an der Instanz (geerbt), gespiegelt eingesetzt
front = Sketchup::Definition.new
quader(front, 23.6, 0.75, 28.3)
f_inst = Sketchup::ComponentInstance.new(front, Geom::Transformation.translation([23.6, -0.75, 3.94]) * Geom::Transformation.scaling(-1, 1, 1))
f_inst.material = eiche
model.entities << f_inst
# Glasscheibe direkt am Gesicht
g = Sketchup::Group.new(Geom::Transformation.translation([30, 0, 0]))
scheibe = Sketchup::Face.new([[0, 0, 0], [10, 0, 0], [10, 0, 20], [0, 0, 20]])
scheibe.material = glas
g.entities << scheibe
model.entities << g
# Platzhalter (Planung) und Modell (Kunde), versteckter virtueller Korpus, Beschriftung
plan = Sketchup::ComponentInstance.new(korpus, Geom::Transformation.translation([60, 0, 0]), tag_plan)
render = Sketchup::ComponentInstance.new(korpus, Geom::Transformation.translation([90, 0, 0]), tag_render)
versteckt = Sketchup::ComponentInstance.new(korpus, Geom::Transformation.translation([0, 0, 50]))
versteckt.hidden = true
text = Sketchup::Face.new(rechteck(0, 0, 1, 1, 40), tag_text)
[plan, render, versteckt, text].each { |e| model.entities << e }
model.active_view.camera = Sketchup::Camera.new([-60, -110, 60], [20, 10, 18], [0, 0, 1], 35.0)

# --- Materialart am Namen ---------------------------------------------------------------
check(R.materialart('Melamin weiss') == 'standard', 'Melamin: Standard')
check(R.materialart('Front Eiche natur') == 'holz', 'Eiche: Holz')
check(R.materialart('Geraet Edelstahl') == 'metall' && R.materialart('Griff Bügel') == 'metall', 'Edelstahl und Griff: Metall')
check(R.materialart('Geraet Schwarzglas') == 'schwarzglas' && R.materialart('Glas klar') == 'glas', 'Schwarzglas vor Glas')
check(R.materialart('Front Hochglanz rot') == 'hochglanz', 'Hochglanz')
check(R.materialart('Raum Wand') == 'matt', 'Wand: matt')
check(R.materialart('irgendwas', 0.4) == 'glas', 'durchsichtig ohne Namen: Glas')
check(R.ascii('Kühlschrank Front / Weiß') == 'Kuehlschrank_Front_Weiss', "Namen nur ASCII: #{R.ascii('Kühlschrank Front / Weiß')}")

# --- Export ohne Szene Kunde: aktuelle Tags, Geräte als Modell, nie Plan/Beschriftung --------
Dir.mktmpdir do |tmp|
  ordner = File.join(tmp, 'Kueche_Render_blender')
  bild = File.join(tmp, 'Kueche_Render.png')
  json = R.exportieren(model, ordner, bild, breite: 640, samples: 16)
  d = JSON.parse(File.read(json))
  obj = File.read(File.join(ordner, 'szene.obj'))
  mtl = File.read(File.join(ordner, 'szene.mtl'))
  # Boden 1 + Korpus 6 + Front 6 + Scheibe 1 + Gerät (Render-Tag) 6 = 20; ohne Plan, versteckt, Beschriftung
  check(d['flaechen'] == 20, "ohne Szene Kunde: 20 Flächen (Plan, Ausgeblendetes, Beschriftung fehlen): #{d['flaechen']}")
  check(obj.start_with?("mtllib szene.mtl\n") && obj.scan(/^v /).size == 80 && obj.scan(/^f /).size == 40, 'OBJ: 80 Punkte, 40 Dreiecke')
  check(d['bild'] == { 'datei' => bild, 'breite' => 640, 'hoehe' => 360, 'samples' => 16 }, "Bildgröße wie Ansicht 16:9: #{d['bild']}")
  check(d['kamera']['auge'] == [-1.524, -2.794, 1.524] && d['kamera']['fov'] == 35.0 && d['kamera']['fov_hoehe'],
        "Kamera in Metern: #{d['kamera']}")
  check(d['licht']['sonne'] == [0.4, -0.6, 0.7] && d['licht']['raumlicht'] == true, 'Sonne aus den Schatten-Einstellungen')
  check(d['box'][0][2].zero? && (d['box'][1][2] - (3.94 + 28.3) * 0.0254).abs < 1e-3, "Begrenzung in Metern: #{d['box']}")
  m = d['materialien']
  check(m.keys.sort == %w[Front_Eiche_natur Glas_klar Melamin_weiss Raum_Boden Standard], "Materialien: #{m.keys}")
  check(m['Front_Eiche_natur']['art'] == 'holz' && m['Front_Eiche_natur']['textur'] == 'textur_Front_Eiche_natur.jpg' &&
        File.exist?(File.join(ordner, 'textur_Front_Eiche_natur.jpg')), 'Holztextur geschrieben und verknüpft')
  check(mtl.include?("newmtl Glas_klar\nKd 0.7843 0.8627 0.9020\nd 0.300") && m['Glas_klar']['art'] == 'glas', 'Glas mit Transparenz')
  check(mtl.include?('map_Kd textur_Front_Eiche_natur.jpg'), 'MTL verweist auf die Textur')
  # Front: geerbtes Texturmaterial -> UV durch Texturgröße (20 × 10 Zoll), gespiegelt -> Reihenfolge umgekehrt
  front_teil = obj.split('usemtl Front_Eiche_natur').first.lines.grep(/^vt /)
  check(front_teil.size == 4 && front_teil[1].strip == 'vt 1.18000 0.00000', "UV der Front in Texturkacheln: #{front_teil[1]}")
  faces = obj.lines.each_cons(2).select { |a, _| a.start_with?('usemtl Front') }.map { |_, b| b.strip }
  check(faces.first =~ %r{\Af (\d+)/\d+ (\d+)/\d+ (\d+)/\d+\z} && Regexp.last_match(1).to_i > Regexp.last_match(3).to_i,
        "gespiegelte Front: Ecken umgedreht (#{faces.first})")
  # x der Front: gespiegelt von 23.6 nach 0 Zoll
  xs = obj.split('usemtl Front_Eiche_natur').first.lines.grep(/^v /).last(4).map { |l| l.split[1].to_f }
  check(xs.minmax.map { |v| v.round(4) } == [0.0, 0.5994], "Front an der richtigen Stelle (gespiegelt): #{xs.minmax}")

  # --- mit Szene Kunde: deren versteckte Tags zählen ------------------------------------------
  model.pages.add('Kunde', Sketchup::Page.new([tag_raum, tag_plan]))
  tag_render.visible = false # aktuell aus, in Kunde aber an (nicht in der Liste der versteckten)
  json = R.exportieren(model, ordner, bild, breite: 640, samples: 16, raumlicht: false)
  d = JSON.parse(File.read(json))
  check(d['flaechen'] == 19 && !d['materialien'].key?('Raum_Boden'), "Szene Kunde: Boden versteckt, Gerätemodell sichtbar: #{d['flaechen']}")
  check(d['licht']['raumlicht'] == false, 'Raumlicht abschaltbar')

  # --- leeres Modell ---------------------------------------------------------------------------
  leer = Sketchup::Model.new
  leer.active_view.camera = model.active_view.camera
  begin
    R.exportieren(leer, File.join(tmp, 'leer'), bild, breite: 640, samples: 16)
    check(false, 'leeres Modell meldet Fehler')
  rescue ArgumentError => e
    check(e.message.include?('nichts Sichtbares'), 'leeres Modell: verständliche Meldung')
  end

  # --- echter Render mit Blender (bpy), falls vorhanden -----------------------------------------
  py = ENV['BPY_PYTHON'] || 'python3'
  if system(py, '-c', 'import bpy', out: File::NULL, err: File::NULL)
    model.pages.add('Kunde', Sketchup::Page.new([tag_plan])) # mit Boden
    json = R.exportieren(model, ordner, bild, breite: 320, samples: 8)
    log = File.join(ordner, 'blender.log')
    ok = system(py, R.skript, '--', json, out: log, err: %i[child out])
    text = File.read(log)
    check(ok && R.ergebnis(text) == [:fertig, bild] && File.size(bild) > 1000, "Blender rendert das Bild (#{R.ergebnis(text).inspect})")
    check(File.exist?(File.join(ordner, 'szene.blend')), '.blend zum Weiterbearbeiten gespeichert')
    FileUtils.cp(bild, ENV['RENDER_KOPIE']) if ENV['RENDER_KOPIE']
  else
    puts 'Hinweis: Python-Modul bpy fehlt, echter Blender-Render übersprungen (BPY_PYTHON setzen).'
  end
end

# --- Fortschritt und Ergebnis aus dem Log -----------------------------------------------------
check(R.fortschritt('') == [nil, 'Blender startet …'], 'Fortschritt: Start')
check(R.fortschritt("KP_STATUS Szene aufbauen\n") == [nil, 'Szene aufbauen'], 'Fortschritt: Schritt aus dem Skript')
log = "KP_STATUS Rendern mit CPU\nFra:1 Mem:12M | Sample 16/128\nFra:1 Mem:12M | Sample 64/128\n"
check(R.fortschritt(log) == [0.5, 'Rendern: Sample 64 von 128'], "Fortschritt: Samples #{R.fortschritt(log).inspect}")
check(R.ergebnis(log).nil?, 'läuft noch')
check(R.ergebnis(log + "KP_FERTIG C:/x/k.png\n") == [:fertig, 'C:/x/k.png'], 'fertig mit Bilddatei')
check(R.ergebnis("KP_FEHLER Datei fehlt\n") == [:fehler, 'Datei fehlt'], 'Fehler aus dem Skript')

# --- Blender suchen ---------------------------------------------------------------------------
Dir.mktmpdir do |pf|
  %w[4.2 3.6 4.10].each do |v|
    FileUtils.mkdir_p(File.join(pf, 'Blender Foundation', "Blender #{v}"))
    File.write(File.join(pf, 'Blender Foundation', "Blender #{v}", 'blender.exe'), '')
  end
  k = R.blender_kandidaten('ProgramFiles' => pf)
  check(k.first.end_with?('Blender 4.10/blender.exe') && k[1].end_with?('Blender 4.2/blender.exe'), "neueste Version zuerst: #{k.first(2)}")
  check(R.blender_suchen('ProgramFiles' => pf) == k.first, 'ohne gemerkten Pfad: neueste')
  gemerkt = File.join(pf, 'Blender Foundation', 'Blender 3.6', 'blender.exe')
  R.merken('blender', gemerkt)
  check(R.blender_suchen('ProgramFiles' => pf) == gemerkt, 'gemerkter Pfad hat Vorrang')
  R.merken('blender', File.join(pf, 'weg', 'blender.exe'))
  check(R.blender_suchen('ProgramFiles' => pf) == k.first, 'gemerkter Pfad fehlt: wieder suchen')
end
check(R.befehl('C:/B/blender.exe', 'C:/x/szene.json')[0, 5] == ['C:/B/blender.exe', '-b', '--factory-startup', '-P', R.skript] &&
      R.befehl('b', 'j').last(2) == ['--', 'j'], 'Aufruf: blender -b --factory-startup -P rendern.py -- szene.json')
check(File.exist?(R.skript), 'rendern.py liegt neben rendern.rb')
check(system('python3', '-m', 'py_compile', R.skript), 'rendern.py ist gültiges Python')

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
