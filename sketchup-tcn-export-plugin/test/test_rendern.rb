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
    def initialize = (@entities, @attr = Entities.new, {})
    def set_attribute(d, k, v) = @attr[[d, k]] = v
    def get_attribute(d, k, s = nil) = @attr.fetch([d, k], s)
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
    attr_accessor :camera, :shadow_info
    def initialize(versteckt) = @layers = versteckt
    def use_hidden_layers? = true
    def use_shadow_info? = !@shadow_info.nil?
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
    def shadow_info = (@si ||= { 'SunDirection' => Geom::Vector3d.new(0.4, -0.6, 0.7) })
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
  check(m.keys.sort == %w[Boden_Raum_Boden Front_Eiche_natur Glas_klar Melamin_weiss Standard] && m['Boden_Raum_Boden']['boden'] &&
        !m['Melamin_weiss']['boden'], "Materialien, Boden (Tag Raum-Boden) eigens gekennzeichnet: #{m.keys}")
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
  check(d['flaechen'] == 19 && !d['materialien'].key?('Boden_Raum_Boden'), "Szene Kunde: Boden versteckt, Gerätemodell sichtbar: #{d['flaechen']}")
  check(d['licht']['raumlicht'] == false, 'Raumlicht abschaltbar')
  check(d['licht']['sonne'] == [0.4, -0.6, 0.7], 'Szene ohne eigene Schatten: Sonne des Modells')
  kunde = model.pages['Kunde']
  kunde.shadow_info = { 'SunDirection' => Geom::Vector3d.new(0.1, -0.2, 0.9) }
  kunde.camera = Sketchup::Camera.new([0, -200, 50], [0, 0, 30], [0, 0, 1], 40.0)
  d = JSON.parse(File.read(R.exportieren(model, ordner, bild, breite: 640, samples: 16)))
  check(d['licht']['sonne'] == [0.1, -0.2, 0.9], 'Szene Kunde mit eigenen Schatten: deren Sonne')
  check(d['kamera']['fov'] == 35.0, 'Kamera standardmäßig aus der Ansicht')
  d = JSON.parse(File.read(R.exportieren(model, ordner, bild, breite: 640, samples: 16, kamera_kunde: true)))
  check(d['kamera']['fov'] == 40.0 && d['kamera']['auge'] == [0.0, -5.08, 1.27], 'wahlweise Kamera der Szene Kunde')

  # --- Fenster: Felder, Prüfung, Start -----------------------------------------------------------
  aufruf = nil
  gestartet = nil
  Kuechenplaner::Eingabe.define_singleton_method(:abfragen) { |*a, **o, &b| aufruf = [a, o, b] }
  R.define_singleton_method(:starten) { |*a| gestartet = a }
  model.path = File.join(tmp, 'Mueller.skp')
  R.dialog(model)
  prompts, werte, listen, titel = aufruf[0]
  check(titel == 'Küche rendern (Blender)' && aufruf[1][:ok] == 'Rendern', 'Fenster „Küche rendern“')
  check(listen == ['', 'Entwurf|Normal|Hoch', 'aktuelle Ansicht|Szene Kunde', 'ja|nein',
                   'Innenraum|Innenhof|Studio|Stadt|Wald|Sonnenuntergang|einfarbig hell', 'ja|nein', 'ja|nein',
                   'keine|wenig|mittel|viel', '1|2|3|4|5|6|7|8|9', 'ja|nein',
                   'wie Modell|Parkett Eiche|Fliesen hell|Fliesen anthrazit|Beton', 'ja|nein', ':speichern', ':programm'],
        "Felder: #{listen}")
  check(werte[12] == File.join(tmp, 'Mueller_Render.png') && werte.values_at(3, 4, 6, 7, 8, 9, 10, 11) ==
        %w[ja Innenraum ja mittel 1 ja wie\ Modell ja], "Vorschläge: #{werte.inspect}")
  rest = ['mittel', '1', 'ja', 'wie Modell', 'ja']
  begin
    aufruf[2].call(['1920', 'Hoch', 'Szene Kunde', 'ja', 'Innenraum', 'ja', 'ja', *rest, werte[12], File.join(tmp, 'gibtsnicht.exe')])
    check(false, 'fehlendes Blender wird gemeldet')
  rescue ArgumentError => e
    check(e.message.include?('blender.org'), 'Blender fehlt: Hinweis auf blender.org')
  end
  exe = File.join(tmp, 'blender.exe')
  File.write(exe, '')
  aufruf[2].call(['1920', 'Hoch', 'Szene Kunde', 'nein', 'Studio', 'nein', 'ja', 'viel', '7', 'nein', 'Parkett Eiche', 'nein',
                  File.join(tmp, 'bild'), exe])
  check(gestartet == [model, exe, File.join(tmp, 'bild.png'), 1920, 512,
                      { raumlicht: false, kamera_kunde: true, senkrecht: false, umgebung: 'Studio', led: true,
                        deko: 'viel', variante: 7, pendel: false, boden: 'Parkett Eiche', decke: false }],
        "Start mit den Eingaben: #{gestartet.inspect}")
  check(Sketchup.read_default('JT_Rendern', 'umgebung') == 'Studio' && Sketchup.read_default('JT_Rendern', 'senkrecht') == 'nein',
        'Auswahl für das nächste Mal gemerkt')
  check(Sketchup.read_default('JT_Rendern', 'blender') == exe, 'Blender-Pfad gemerkt')
  begin
    aufruf[2].call(['50', 'Hoch', 'Szene Kunde', 'ja', 'Innenraum', 'ja', 'ja', *rest, 'x.png', exe])
    check(false, 'zu kleine Breite')
  rescue ArgumentError
    check(true, 'zu kleine Breite wird abgelehnt')
  end
  v = $VERBOSE
  $VERBOSE = nil
  load File.join(__dir__, '../src/jt_schrank_cnc/rendern.rb') # starten wiederherstellen
  $VERBOSE = v

  # --- leeres Modell ---------------------------------------------------------------------------
  leer = Sketchup::Model.new
  leer.active_view.camera = model.active_view.camera
  begin
    R.exportieren(leer, File.join(tmp, 'leer'), bild, breite: 640, samples: 16)
    check(false, 'leeres Modell meldet Fehler')
  rescue ArgumentError => e
    check(e.message.include?('nichts Sichtbares'), 'leeres Modell: verständliche Meldung')
  end

  # --- Oberschrank: LED-Leiste an seiner Unterseite, Umgebung, Kanten, Zweipunktperspektive ----
  ober = Sketchup::Definition.new
  ober.set_attribute('JT_Schrank', 'kategorie', 'Oberschrank')
  innen = Sketchup::Definition.new # Teile liegen eine Ebene tiefer, wie bei den Komponenten
  quader(innen, 23.6, 13.8, 28.3)
  ober.entities << Sketchup::ComponentInstance.new(innen, Geom::Transformation.translation([0, 0, 0]))
  o_inst = Sketchup::ComponentInstance.new(ober, Geom::Transformation.translation([0, 6.7, 54.7]))
  o_inst.material = weiss
  model.entities << o_inst
  d = JSON.parse(File.read(R.exportieren(model, ordner, bild, breite: 640, samples: 16)))
  check(d['licht']['led'] == [[0.0, 0.1702, 0.5994, 0.5207, 1.3894]], "LED unter dem Oberschrank (m): #{d['licht']['led']}")
  check(d['licht']['umgebung'] == 'interior.exr' && d['kanten'] == 0.0015 && d['kamera']['senkrecht'] == true,
        'Standard: Innenraum-HDRI, Kanten gerundet, Senkrechte gerade')
  d = JSON.parse(File.read(R.exportieren(model, ordner, bild, breite: 640, samples: 16, led: false, umgebung: 'einfarbig hell',
                                                                   senkrecht: false)))
  check(d['licht']['led'] == [] && d['licht']['umgebung'].nil? && d['kamera']['senkrecht'] == false, 'alles abschaltbar')

  # --- echter Render mit Blender (bpy), falls vorhanden -----------------------------------------
  py = ENV['BPY_PYTHON'] || 'python3'
  if system(py, '-c', 'import bpy', out: File::NULL, err: File::NULL)
    model.pages.add('Kunde', Sketchup::Page.new([tag_plan])) # mit Boden, Kamera der Ansicht
    json = R.exportieren(model, ordner, bild, breite: 320, samples: 8)
    log = File.join(ordner, 'blender.log')
    ok = system(py, R.skript, '--', json, out: log, err: %i[child out])
    text = File.read(log)
    check(ok && R.ergebnis(text) == [:fertig, bild] && File.size(bild) > 1000, "Blender rendert das Bild (#{R.ergebnis(text).inspect})")
    check(File.exist?(File.join(ordner, 'szene.blend')), '.blend zum Weiterbearbeiten gespeichert')
    status = File.read(File.join(ordner, 'kp_status.txt'))
    check(R.ergebnis(status) == [:fertig, bild] && R.pids(status).size == 1 && status.include?('KP_SAMPLE 8/8'),
          "eigene Statusdatei mit PID, Samples und Fertig-Meldung (ohne Konsolenausgabe): #{status.lines.map(&:strip)}")
    FileUtils.cp(bild, ENV['RENDER_KOPIE']) if ENV['RENDER_KOPIE']
    pruef = <<~PY
      import bpy, json, math, sys
      from mathutils import Vector
      from bpy_extras.object_utils import world_to_camera_view
      bpy.ops.wm.open_mainfile(filepath=sys.argv[1])
      cam = bpy.data.objects["Kamera"]
      z = cam.matrix_world.to_3x3().col[2]
      leds = [o for o in bpy.data.objects if o.name.startswith("LED_")]
      env = [n for n in bpy.context.scene.world.node_tree.nodes if n.type == "TEX_ENVIRONMENT"]
      bevel = any(n.type == "BEVEL" for m in bpy.data.materials if m.node_tree for n in m.node_tree.nodes)
      print("PRUEF", round(abs(z.z), 6), round(cam.data.shift_y, 4), len(leds), len(env), bevel)
      ziel = json.load(open(sys.argv[2], encoding="utf-8"))["kamera"]["ziel"]
      p = world_to_camera_view(bpy.context.scene, cam, Vector(ziel))
      print("MITTE", round(p.x, 4), round(p.y, 4))
    PY
    out = IO.popen([py, '-c', pruef, File.join(ordner, 'szene.blend'), json], err: File::NULL, &:read)
    mitte = out[/^MITTE (.*)$/, 1].to_s.split.map(&:to_f)
    check(mitte.size == 2 && mitte.all? { |v| (v - 0.5).abs < 0.02 },
          "Zweipunktperspektive: Blickziel liegt in der Bildmitte, Küche nicht nach unten verschoben (#{mitte.inspect})")
    werte = out[/^PRUEF (.*)$/, 1].to_s.split
    check(werte[0] == '0.0' && werte[1].to_f < -0.05, "Zweipunktperspektive: Kamera waagrecht, Blick nach unten als Shift nach unten (#{werte.inspect})")
    check(werte[2] == '1' && werte[3] == '1' && werte[4] == 'True', "Blender-Szene mit LED, HDRI-Umgebung und Kantenradius (#{werte.inspect})")
  else
    puts 'Hinweis: Python-Modul bpy fehlt, echter Blender-Render übersprungen (BPY_PYTHON setzen).'
  end
end

# --- Testküche: Raum, Zeile mit Arbeitsplatte und Spüle, Oberschränke, Insel -----------------
def mm(*v) = v.map { |x| x / 25.4 }
def kasten(defn, x, y, z, b, t, h)
  e = defn.entities
  x0, y0, z0 = mm(x, y, z)
  x1, y1, z1 = mm(x + b, y + t, z + h)
  e << Sketchup::Face.new(rechteck(x0, y0, x1, y1, z0)) << Sketchup::Face.new(rechteck(x0, y0, x1, y1, z1))
  e << Sketchup::Face.new([[x0, y0, z0], [x1, y0, z0], [x1, y0, z1], [x0, y0, z1]])
  e << Sketchup::Face.new([[x0, y1, z0], [x1, y1, z0], [x1, y1, z1], [x0, y1, z1]])
  e << Sketchup::Face.new([[x0, y0, z0], [x0, y1, z0], [x0, y1, z1], [x0, y0, z1]])
  e << Sketchup::Face.new([[x1, y0, z0], [x1, y1, z0], [x1, y1, z1], [x1, y0, z1]])
end

def instanz(model, kategorie: nil, insel: false, geraet: nil, tag: nil, mat: nil)
  d = Sketchup::Definition.new
  d.set_attribute('JT_Schrank', 'kategorie', kategorie) if kategorie
  d.set_attribute('JT_Schrank', 'insel', true) if insel
  d.set_attribute('JT_Geraet', 'geraet', geraet) if geraet
  yield d
  i = Sketchup::ComponentInstance.new(d, Geom::Transformation.new, tag)
  i.material = mat
  model.entities << i
  i
end

def testkueche
  k = Sketchup::Model.new
  weiss = Sketchup::Material.new('Melamin weiss', [240, 240, 236])
  front = Sketchup::Material.new('Front Eiche natur', [176, 132, 86])
  ap = Sketchup::Material.new('Arbeitsplatte Quarz grau', [120, 120, 118])
  stahl = Sketchup::Material.new('Geraet Edelstahl', [200, 200, 200])
  wand = Sketchup::Material.new('Raum Wand', [235, 232, 225])
  boden = Sketchup::Material.new('Raum Boden', [150, 140, 125])
  t_wand = Sketchup::Layer.new('Raum-Wand')
  t_boden = Sketchup::Layer.new('Raum-Boden')
  instanz(k, tag: t_boden, mat: boden) { |d| kasten(d, -500, -3500, -20, 5000, 4100, 20) }
  instanz(k, tag: t_wand, mat: wand) do |d|
    kasten(d, -500, 600, 0, 5000, 100, 2500)  # Wand hinter der Zeile
    kasten(d, -600, -3500, 0, 100, 4200, 2500) # Wand links
  end
  # Zeile: 3 Unterschränke 600 breit, 560 tief, Sockel 100, Korpus 720 (Front davor)
  3.times do |i|
    instanz(k, kategorie: 'Unterschrank', mat: weiss) do |d|
      kasten(d, i * 600, 0, 100, 600, 560, 720)
      f = Sketchup::Definition.new
      kasten(f, i * 600 + 2, -19, 102, 596, 19, 716)
      fi = Sketchup::ComponentInstance.new(f, Geom::Transformation.new)
      fi.material = front
      d.entities << fi
    end
  end
  instanz(k, kategorie: 'Arbeitsplatte', mat: ap) { |d| kasten(d, 0, -30, 820, 1800, 630, 40) }
  instanz(k, geraet: 'Spuele', tag: Sketchup::Layer.new('Geraete_Render'), mat: stahl) { |d| kasten(d, 700, 60, 790, 500, 420, 75) }
  2.times do |i|
    instanz(k, kategorie: 'Oberschrank', mat: weiss) do |d|
      kasten(d, i * 900, 250, 1450, 900, 350, 720)
    end
  end
  # Insel 1800 × 900 mit eigener Platte
  instanz(k, kategorie: 'Unterschrank', insel: true, mat: weiss) { |d| kasten(d, 300, -2200, 100, 1800, 900, 720) }
  instanz(k, kategorie: 'Arbeitsplatte', mat: ap) { |d| kasten(d, 280, -2220, 820, 1840, 940, 40) }
  k.active_view.camera = Sketchup::Camera.new(mm(3800, -3300, 1650), mm(900, 100, 900), [0, 0, 1], 45.0)
  k.shadow_info['SunDirection'] = Geom::Vector3d.new(-0.3, -0.5, 0.8)
  k
end

Dir.mktmpdir do |tmp|
  k = testkueche
  ordner = File.join(tmp, 'K_blender')
  bild = File.join(tmp, 'K.png')
  d = JSON.parse(File.read(R.exportieren(k, ordner, bild, breite: 480, samples: 16, boden: 'Parkett Eiche')))
  deko = d['deko']
  zs = deko['arbeitsflaechen'].map { |t| t.map { |p| p[2] }.uniq }
  check(deko['arbeitsflaechen'].size == 4 && zs.all? { |z| z == [0.86] }, "nur die Oberseiten der Arbeitsplatten (4 Dreiecke): #{zs.inspect}")
  check(deko['geraete'].size == 1 && deko['geraete'][0][2] == 'Spuele', "Spüle als Sperrfläche: #{deko['geraete'].inspect}")
  check(deko['inseln'] == [[[0.3, -2.2, 0.1], [2.1, -1.3, 0.82]]], "Insel erkannt: #{deko['inseln'].inspect}")
  check(deko['anzahl'] == 6 && deko['variante'] == 1 && deko['pendel'], 'Standard: mittel viel Deko, Pendelleuchten')
  check(d['raum']['boden'] == 'parkett' && d['raum']['decke'] == [[-0.6, -3.5, 0.0], [4.5, 0.7, 2.5]], "Boden und Decke: #{d['raum']}")
  check(d['licht']['led'].size == 2, 'zwei LED-Leisten')
  aus = JSON.parse(File.read(R.exportieren(k, ordner, bild, breite: 480, samples: 16, deko: 'keine', decke: false)))
  check(aus['deko']['anzahl'].zero? && aus['raum']['decke'].nil? && aus['raum']['boden'].nil?, 'Deko, Decke, Belag abschaltbar')

  py = ENV['BPY_PYTHON'] || 'python3'
  if system(py, '-c', 'import bpy', out: File::NULL, err: File::NULL)
    json = R.exportieren(k, ordner, bild, breite: 640, samples: 24, boden: 'Parkett Eiche', deko: 'viel', variante: 2)
    ok = system(py, R.skript, '--', json, out: File.join(ordner, 'blender.log'), err: %i[child out])
    status = File.read(File.join(ordner, 'kp_status.txt'))
    aus = status[/^KP_STATUS Ausstattung: (.*)$/, 1].to_s
    check(ok && R.ergebnis(status) == [:fertig, bild], "Testküche gerendert: #{status.lines.last(2).join.strip}")
    check(aus.split(', ').size >= 7 && aus.include?('3 Pendelleuchten') && aus.include?('Decke'),
          "Deko auf der Arbeitsplatte, 3 Pendelleuchten über der 1,8 m langen Insel, Decke: #{aus}")
    pruef = <<~PY
      import bpy, sys
      bpy.ops.wm.open_mainfile(filepath=sys.argv[1])
      sys.dont_write_bytecode = True
      sys.path.insert(0, sys.argv[2])
      import rendern_ausstattung as A, json
      d = json.load(open(sys.argv[3]))
      deko = d["deko"]
      schlecht = []
      for o in bpy.data.objects:
          if o.name.startswith("Deko_") and o.parent is None and o.type == "EMPTY":
              x, y, z = o.location
              r = dict((n, r) for n, r, _ in A.DEKO)[o.name[5:].split(".")[0]]
              if not A.platz_frei(x, y, z, r - 0.001, deko["arbeitsflaechen"], deko["geraete"], []):
                  schlecht.append(o.name)
      print("SCHLECHT", schlecht)
    PY
    out = IO.popen([py, '-c', pruef, File.join(ordner, 'szene.blend'), File.dirname(R.skript), json], err: File::NULL, &:read)
    check(out.include?('SCHLECHT []'), "keine Deko über der Kante oder auf der Spüle: #{out[/SCHLECHT.*/]}")
    FileUtils.cp(bild, ENV['KUECHE_KOPIE']) if ENV['KUECHE_KOPIE']
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
check(R.fortschritt("KP_STATUS Rendern mit OPTIX\nKP_SAMPLE 32/128\n") == [0.25, 'Rendern: Sample 32 von 128'], 'Fortschritt aus der Statusdatei')
check(R.pids("KP_PID 4711\nKP_STATUS x\nKP_PID 4712\n") == [4711, 4712], 'Prozessnummern zum Abbrechen')
t0 = Time.now
check(!R.abgebrochen?(true, t0 - 5, t0) && R.abgebrochen?(true, t0 - 31, t0) && !R.abgebrochen?(false, t0 - 999, t0),
      'beendet erst, wenn der Prozess weg ist und 30 s nichts mehr kommt')

# --- Blender 5 unter Windows: Start-Prozess endet sofort, gerendert wird weiter ----------------
module UI
  class HtmlDialog
    STYLE_DIALOG = 0
    attr_reader :skripte
    def initialize(*) = @skripte = []
    def set_html(_) = nil
    def add_action_callback(*) = nil
    def set_on_closed(&) = nil
    def center = nil
    def show = nil
    def visible? = true
    def execute_script(js) = @skripte << js
  end
  def self.timer = (@timer ||= [])
  def self.start_timer(_s, _r = false, &b) = (timer << b; timer.size)
  def self.stop_timer(_id) = nil
end
Dir.mktmpdir do |tmp|
  bild = File.join(tmp, 'k.png')
  status = File.join(tmp, 'kp_status.txt')
  pid = Process.spawn(RbConfig.ruby, '-e', 'exit')
  sleep 0.3
  f = R::Fortschritt.new(pid, File.join(tmp, 'blender.log'), bild, tmp, status)
  f.zeigen
  UI.timer.shift.call
  d = f.instance_variable_get(:@d)
  check(d.skripte.last.start_with?('KP.stand(') && f.instance_variable_get(:@beendet), "Prozess weg, aber kein Fehler: #{d.skripte.last}")
  File.write(status, "KP_PID 1\nKP_STATUS Rendern mit OPTIX\nKP_SAMPLE 64/128\n")
  UI.timer.shift.call
  check(d.skripte.last == 'KP.stand(50, "Rendern: Sample 64 von 128")', "Fortschritt läuft weiter: #{d.skripte.last}")
  File.binwrite(bild, Sketchup.png_streifen)
  File.write(status, "KP_FERTIG #{bild}\n", mode: 'a')
  UI.timer.shift.call
  check(d.skripte.last.start_with?("KP.bild('data:image/png;base64,"), 'Bild wird angezeigt statt „ohne Bild beendet“')
  check(UI.timer.empty?, 'danach kein Timer mehr')
end

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
# nur prüfen, nichts schreiben (kein __pycache__ in src/, sonst passt die .rbz nicht mehr)
check(system('python3', '-c', 'import ast, sys; ast.parse(open(sys.argv[1], encoding="utf-8").read())', R.skript), 'rendern.py ist gültiges Python')

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
