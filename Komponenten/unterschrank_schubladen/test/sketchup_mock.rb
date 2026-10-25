# Minimaler Ersatz für die SketchUp-Ruby-API, nur was der Generator nutzt.
require "set"
$loaded = {}
def file_loaded?(f) = $loaded[f]
def file_loaded(f) = $loaded[f] = true

class Numeric
  def cm = self / 2.54
end

module UI
  def self.menu(_) = Menu.new
  class Menu; def add_item(_) = nil; end
  def self.messagebox(m) = puts("MSG: #{m}")
end

module Geom
  class Vector3d
    attr_reader :a
    def initialize(*a) = @a = a.map(&:to_f)
  end
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
  class Color; def initialize(*); end; end

  module Attr
    def dicts = (@dicts ||= {})
    def set_attribute(d, k, v) = (dicts[d] ||= {})[k] = v
    def get_attribute(d, k, default = nil) = dicts.dig(d, k) || default
    def attribute_dictionary(d) = dicts[d]
  end

  class Face
    include Attr
    attr_accessor :material
    attr_reader :normal
    def initialize(ents, pts)
      @ents, @pts = ents, pts
      @normal = Struct.new(:z).new(-1.0)
    end
    def reverse! = @normal = Struct.new(:z).new(-@normal.z)
    def pushpull(d)
      raise 'pushpull falsche Richtung' unless @normal.z > 0 && d > 0
      @ents.definition.box = [@pts[1][0], @pts[2][1], d]
      # Quader mit 6 Außenflächen erzeugen
      [[-1, 0, 0], [1, 0, 0], [0, -1, 0], [0, 1, 0], [0, 0, -1], [0, 0, 1]].each do |x, y, z|
        f = Face.new(@ents, @pts)
        f.instance_variable_set(:@normal, Struct.new(:x, :y, :z).new(x.to_f, y.to_f, z.to_f))
        @ents.faces << f
      end
    end
  end

  class Entities
    include Enumerable
    attr_reader :definition
    attr_reader :faces
    def initialize(defn) = (@definition, @list, @faces = defn, [], [])
    def grep(k) = (k == Face ? @faces : @list.grep(k))
    def add_face(*pts) = Face.new(self, pts)
    def add_instance(d, tr)
      i = ComponentInstance.new(d, tr)
      @list << i
      i
    end
    def instances = @list
    def length = @list.size
    def each(&) = @list.each(&)
  end

  class ComponentDefinition
    include Attr
    attr_accessor :name, :description, :box
    attr_reader :entities
    def initialize(n) = (@name, @entities = n, Entities.new(self))
  end

  class ComponentInstance
    include Attr
    attr_accessor :name, :material, :layer, :hidden
    attr_reader :definition, :transformation
    def initialize(d, tr) = (@definition, @transformation = d, tr)
  end

  class Benannt
    include Attr
    attr_accessor :color
    attr_reader :name
    def initialize(n) = @name = n
  end

  class Named
    def initialize = @h = {}
    def [](n) = @h[n]
    def add(n) = @h[n] = Benannt.new(n)
    def to_a = @h.values
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
    attr_reader :definitions, :materials, :layers, :entities, :selection
    def initialize
      @definitions, @materials, @layers = Definitions.new, Named.new, Named.new
      @entities = Entities.new(nil)
      @selection = Set.new
    end
    def start_operation(*) = nil
    def commit_operation = nil
    def abort_operation = nil
    def bounds = Struct.new(:max).new(Struct.new(:x).new(0))
  end

  class << self
    attr_accessor :active_model
  end
end
