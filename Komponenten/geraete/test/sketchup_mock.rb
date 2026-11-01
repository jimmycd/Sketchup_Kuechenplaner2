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
    attr_accessor :name, :material, :layer, :hidden
    attr_reader :definition, :transformation
    def initialize(d, tr) = (@definition, @transformation = d, tr)
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

  class Page
    attr_reader :name, :sichtbar
    def initialize(n, model) = (@name, @model = n, model; update(32))
    def update(_) = @sichtbar = @model.layers.to_a.to_h { |l| [l.name, l.visible] }
  end

  class Pages
    attr_accessor :selected_page
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
    attr_reader :definitions, :materials, :layers, :entities, :selection, :pages
    def initialize
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
