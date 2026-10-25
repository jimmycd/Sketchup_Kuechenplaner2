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
    def to_a = @a.dup
    def x = @a[0]
    def y = @a[1]
    def z = @a[2]
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
    def initialize(ents, pts, normal = [0, 0, -1.0])
      @ents, @pts = ents, pts
      @normal = Geom::Vector3d.new(*normal)
    end
    def reverse! = @normal = Geom::Vector3d.new(*@normal.to_a.map(&:-@))
    def pushpull(d)
      raise 'pushpull falsche Richtung' unless @normal.z > 0 && d > 0
      @ents.definition.box = [@pts[1][0], @pts[2][1], d]
      @ents.faces.clear
      [[-1, 0, 0], [1, 0, 0], [0, -1, 0], [0, 1, 0], [0, 0, -1], [0, 0, 1]].each do |n|
        @ents.faces << Face.new(@ents, @pts, n)
      end
    end
  end

  class Entities
    include Enumerable
    attr_reader :definition
    def initialize(defn) = (@definition, @list, @faces = defn, [], [])
    attr_reader :faces
    def grep(k) = k == Face ? @faces.dup : @list.grep(k)
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

  class Mat
    include Attr
    attr_accessor :color, :name
    def initialize(n) = @name = n
    def texture = nil
  end

  class Named
    def initialize = @h = {}
    def [](n) = @h[n]
    def add(n) = @h[n] = Mat.new(n)
    def to_h = @h
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
    def [](n) = @h[n]
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

# --- Erweiterungen für das Plugin: Instanzlisten, make_unique, Gruppen, Menüs ---
module UI
  class Menu
    def add_submenu(_) = Menu.new
    def add_item(*) = nil
  end
end
MB_OKCANCEL = 1 unless defined?(MB_OKCANCEL)
IDOK = 1 unless defined?(IDOK)

module Sketchup
  module Attr
    def delete_attribute(d, k) = dicts[d]&.delete(k)
    def kopiere_attribute_von(o) = @dicts = Marshal.load(Marshal.dump(o.dicts))
  end

  class Color
    attr_reader :rgb
    def initialize(*a) = @rgb = a
  end

  class Mat
    attr_accessor :color
  end

  class Group; end

  class Entities
    alias_method :add_instance_alt, :add_instance
    def add_instance(d, tr)
      i = add_instance_alt(d, tr)
      d.instances << i
      i
    end
  end

  class ComponentDefinition
    def instances = (@instances ||= [])
    def model = Sketchup.active_model
  end

  class ComponentInstance
    def hidden? = !!hidden
    attr_writer :definition

    # wie SketchUp: Kopie der Definition (Flächen, Kind-Instanzen, Attribute), nur für diese Instanz
    def make_unique
      alt = definition
      neu = Sketchup.active_model.definitions.add(alt.name)
      neu.kopiere_attribute_von(alt)
      neu.box = alt.box
      neu.description = alt.description
      alt.entities.faces.each do |f|
        nf = Face.new(neu.entities, f.instance_variable_get(:@pts), f.normal.to_a)
        nf.material = f.material
        neu.entities.faces << nf
      end
      alt.entities.instances.each do |c|
        nc = neu.entities.add_instance(c.definition, c.transformation)
        nc.kopiere_attribute_von(c)
        nc.name, nc.material, nc.layer, nc.hidden = c.name, c.material, c.layer, c.hidden
      end
      alt.instances.delete(self)
      neu.instances << self
      @definition = neu
      self
    end
  end

  class Selection < Set
    def to_a = super
  end
end
