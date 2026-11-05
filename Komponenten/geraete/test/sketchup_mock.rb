# Minimaler Ersatz für die SketchUp-Ruby-API, nur was die Geräte nutzen.
require "set"
$loaded = {}
def file_loaded?(f) = $loaded[f]
def file_loaded(f) = $loaded[f] = true

module UI
  def self.menu(_) = Menu.new
  class Menu
    def add_item(_) = nil
    def add_separator = nil
    def add_submenu(_) = self
  end
  def self.messagebox(m) = ($meldungen ||= []) << m
end

module Geom
  class Vector3d
    attr_reader :a
    def initialize(*a) = @a = a.map(&:to_f)
    def to_a = @a.dup
    def x = @a[0]
    def y = @a[1]
    def z = @a[2]
  end
  Point3d = Vector3d
  class Transformation
    attr_reader :origin
    def self.translation(v)
      t = new
      t.instance_variable_set(:@origin, v.is_a?(Vector3d) ? v.a : v.map(&:to_f))
      t
    end
    def to_a = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, *origin, 1].map(&:to_f)
  end
end

module Sketchup
  class Color
    attr_reader :rgb
    def initialize(*rgb) = @rgb = rgb
  end

  class Dict < Hash
    attr_reader :name
    def initialize(name) = (super(); @name = name)
  end

  module Attr
    def dicts = (@dicts ||= {})
    def set_attribute(d, k, v) = (dicts[d] ||= Dict.new(d))[k] = v
    def get_attribute(d, k, default = nil) = dicts.dig(d, k) || default
    def delete_attribute(d, k) = dicts[d]&.delete(k)
    def attribute_dictionary(d) = dicts[d]
    def attribute_dictionaries = dicts.empty? ? nil : dicts.values
  end

  class Face
    attr_reader :normal
    def initialize(ents, pts, normal = [0, 0, -1.0])
      @ents, @pts = ents, pts
      @normal = Geom::Vector3d.new(*normal)
    end
    def reverse! = @normal = Geom::Vector3d.new(*@normal.to_a.map(&:-@))
    def pushpull(d)
      raise 'pushpull falsche Richtung' unless @normal.z > 0 && d > 0
      raise 'Quader mit Maß <= 0' unless @pts[1][0] > 0 && @pts[2][1] > 0
      @ents.definition.box = [@pts[1][0], @pts[2][1], d]
    end
  end

  class Entities
    include Enumerable
    attr_reader :definition, :texte
    def initialize(defn) = (@definition, @list, @texte = defn, [], [])
    def grep(k) = @list.grep(k)
    def add_face(*pts) = Face.new(self, pts)
    def add_line(*) = nil
    def add_text(t, p) = @texte << [t, p]
    def add_instance(d, tr)
      i = ComponentInstance.new(d, tr)
      i.parent_entities = self
      @list << i
      i
    end
    def erase_entities(l) = @list -= l
    def length = @list.size
    def each(&) = @list.each(&)
    def to_a = @list.dup
  end

  class ComponentDefinition
    include Attr
    attr_accessor :name, :description, :box
    attr_reader :entities
    def initialize(n) = (@name, @entities = n, Entities.new(self))
  end

  class Group; end

  class ComponentInstance
    include Attr
    attr_accessor :name, :material, :layer, :hidden, :parent_entities
    attr_reader :definition, :transformation
    def initialize(d, tr) = (@definition, @transformation = d, tr)
    def erase! = (parent_entities&.erase_entities([self]); nil)
    def parent = parent_entities&.definition
    def hidden? = !!hidden
  end

  class Mat
    include Attr
    attr_accessor :color, :name, :alpha
    def texture = nil
    def initialize(n) = (@name, @alpha = n, 1.0)
  end

  class Layer
    attr_accessor :name, :visible
    def initialize(n) = (@name, @visible = n, true)
  end

  class Named
    def initialize(k) = (@k, @h = k, {})
    def [](n) = @h[n]
    def add(n) = @h[n] = @k.new(n)
    def to_a = @h.values
  end

  # Optionen wie RenderingOptions/ShadowInfo: feste Schlüsselliste
  class Optionen
    def initialize(werte) = @h = werte.dup
    def keys = @h.keys
    def [](k) = @h[k]
    def []=(k, v)
      raise ArgumentError, "unbekannt: #{k}" unless @h.key?(k)
      @h[k] = v
    end
    def to_h = @h.dup
  end

  class Camera
    attr_accessor :eye, :target, :up, :fov, :height
    def initialize(eye, target, up, persp = true, fov = 30.0) = (@eye, @target, @up, @persp, @fov = eye, target, up, persp, fov)
    def perspective? = @persp
    def perspective=(v)
      @persp = v
    end
  end

  class View
    attr_accessor :camera, :bilder
    def initialize = (@camera, @bilder = Camera.new([0, -100, 50], [0, 0, 0], [0, 0, 1], false, 30.0), [])
    def write_image(opts) = (@bilder << opts; true)
  end

  class Page
    include Attr
    attr_reader :name, :sichtbar, :rendering_options, :shadow_info, :camera, :flags
    attr_accessor :use_camera, :use_rendering_options, :use_shadow_info
    def initialize(n, model) = (@name, @model, @flags = n, model, []; update(-1))
    def update(f = -1)
      @flags << f
      @sichtbar = @model.layers.to_a.to_h { |l| [l.name, l.visible] } if f & 32 != 0
      @rendering_options = Optionen.new(@model.rendering_options.to_h) if f & 2 != 0
      @shadow_info = Optionen.new(@model.shadow_info.to_h) if f & 4 != 0
      v = @model.active_view.camera
      @camera = Camera.new(v.eye, v.target, v.up, v.perspective?, v.fov) if f & 1 != 0
      true
    end
  end

  class Pages
    attr_reader :selected_page
    def selected_page=(p)
      @selected_page = p
      @model.active_view.camera = p.camera
    end
    def initialize(model) = (@model, @h = model, {})
    def [](n) = @h[n]
    def add(n) = @h[n] = Page.new(n, @model)
    def size = @h.size
  end

  class Definitions
    def initialize = @h = {}
    def add(n)
      name = n
      k = 0
      name = "#{n}##{k += 1}" while @h.key?(name)
      @h[name] = ComponentDefinition.new(name)
    end
    def size = @h.size
  end

  class Model
    RO = { 'RenderMode' => 2, 'Texture' => true, 'DrawSilhouettes' => true, 'DrawProfilesOnly' => false,
           'EdgeColorMode' => 1, 'ForegroundColor' => Color.new(0, 0, 0), 'DisplayText' => true,
           'DisplayDims' => true, 'DisplaySketchAxes' => true, 'DrawHorizon' => true, 'DrawGround' => false,
           'BackgroundColor' => Color.new(255, 255, 255), 'SkyColor' => Color.new(1, 2, 3),
           'GroundColor' => Color.new(4, 5, 6), 'DisplayColorByLayer' => false }.freeze
    SI = { 'DisplayShadows' => false, 'Light' => 80, 'Dark' => 45, 'ShadowTime' => Time.utc(2020, 11, 8, 13, 30),
           'UseSunForAllShading' => false, 'DisplayOnAllFaces' => true, 'DisplayOnGroundPlane' => true }.freeze
    attr_reader :definitions, :materials, :layers, :entities, :selection, :pages,
                :rendering_options, :shadow_info, :active_view, :options
    attr_accessor :path
    def initialize
      @rendering_options, @shadow_info = Optionen.new(RO), Optionen.new(SI)
      @active_view, @path = View.new, ''
      @options = { 'PageOptions' => { 'ShowTransition' => true } }
      @definitions, @materials, @layers = Definitions.new, Named.new(Mat), Named.new(Layer)
      @entities = Entities.new(nil)
      @selection = Set.new
      @pages = Pages.new(self)
    end
    def start_operation(*) = nil
    def commit_operation = nil
    def abort_operation = nil
  end

  class << self
    attr_accessor :active_model
  end
end
