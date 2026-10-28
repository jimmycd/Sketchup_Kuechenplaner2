# Minimaler Ersatz für die SketchUp-Ruby-API, nur was der Generator nutzt.
require "set"
$loaded = {}
def file_loaded?(f)
  $loaded[f]
end
def file_loaded(f)
  $loaded[f] = true
end

class Numeric
  def cm
    self / 2.54
  end
end

module UI
  def self.menu(_)
    Menu.new
  end
  class Menu
    def add_item(_)
      nil
    end
    def add_separator
      nil
    end
    def add_submenu(_)
      self
    end
  end
  def self.start_timer(_s, _r = false)
    yield
  end
  def self.messagebox(m)
    puts("MSG: #{m}")
  end
end

module Geom
  class Vector3d
    attr_reader :a
    def initialize(*a)
      @a = a.map(&:to_f)
    end
    def to_a
      @a.dup
    end
    def x
      @a[0]
    end
    def y
      @a[1]
    end
    def z
      @a[2]
    end
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
    def dicts
      (@dicts ||= {})
    end
    def set_attribute(d, k, v)
      (dicts[d] ||= {})[k] = v
    end
    def get_attribute(d, k, default = nil)
      dicts.dig(d, k) || default
    end
    def attribute_dictionary(d)
      dicts[d]
    end
  end

  class Face
    include Attr
    attr_accessor :material
    attr_reader :normal
    def initialize(ents, pts, normal = [0, 0, -1.0])
      @ents, @pts = ents, pts
      @normal = Geom::Vector3d.new(*normal)
    end
    def reverse!
      @normal = Geom::Vector3d.new(*@normal.to_a.map(&:-@))
    end
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
    def initialize(defn)
      (@definition, @list, @faces = defn, [], [])
    end
    attr_reader :faces
    def grep(k)
      k == Face ? @faces.dup : @list.grep(k)
    end
    def add_face(*pts)
      Face.new(self, pts)
    end
    def add_instance(d, tr)
      i = ComponentInstance.new(d, tr)
      @list << i
      i
    end
    def instances
      @list
    end
    def length
      @list.size
    end
    def each(&blk)
      @list.each(&blk)
    end
  end

  class ComponentDefinition
    include Attr
    attr_accessor :name, :description, :box
    attr_reader :entities
    def initialize(n)
      (@name, @entities = n, Entities.new(self))
    end
  end

  class ComponentInstance
    include Attr
    attr_accessor :name, :material, :layer, :hidden
    attr_reader :definition, :transformation
    def initialize(d, tr)
      (@definition, @transformation = d, tr)
    end
  end

  class Mat
    include Attr
    attr_accessor :color, :name
    def initialize(n)
      @name = n
    end
    def texture
      nil
    end
  end

  class Named
    def initialize
      @h = {}
    end
    def [](n)
      @h[n]
    end
    def add(n)
      @h[n] = Mat.new(n)
    end
    def to_h
      @h
    end
    def to_a
      @h.values
    end
  end

  class Definitions
    def initialize
      @h = {}
    end
    def add(n)
      name = n
      k = 0
      name = "#{n}##{k += 1}" while @h.key?(name)
      @h[name] = ComponentDefinition.new(name)
    end
    def size
      @h.size
    end
    def [](n)
      @h[n]
    end
  end

  class Model
    attr_reader :definitions, :materials, :layers, :entities, :selection
    def initialize
      @definitions, @materials, @layers = Definitions.new, Named.new, Named.new
      @entities = Entities.new(nil)
      @selection = Set.new
    end
    def start_operation(*)
      nil
    end
    def commit_operation
      nil
    end
    def abort_operation
      nil
    end
    def bounds
      Struct.new(:max).new(Struct.new(:x).new(0))
    end
  end

  class << self
    attr_accessor :active_model
  end
end

# --- Erweiterungen für das Plugin: Instanzlisten, make_unique, Gruppen, Menüs ---
module UI
  class Menu
    def add_submenu(_)
      Menu.new
    end
    def add_item(*)
      nil
    end
  end
end
MB_OKCANCEL = 1 unless defined?(MB_OKCANCEL)
IDOK = 1 unless defined?(IDOK)

module Sketchup
  module Attr
    def delete_attribute(d, k)
      dicts[d]&.delete(k)
    end
    def kopiere_attribute_von(o)
      @dicts = Marshal.load(Marshal.dump(o.dicts))
    end
  end

  class Color
    attr_reader :rgb
    def initialize(*a)
      @rgb = a
    end
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
    def instances
      (@instances ||= [])
    end
    def model
      Sketchup.active_model
    end
  end

  class ComponentInstance
    def hidden?
      !!hidden
    end
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
    def to_a
      super
    end
  end
end

# --- für den TCN-Export: Matrix und Bounds (die Komponenten nutzen nur Verschiebungen) ---
module Geom
  class Transformation
    def origin
      (@origin ||= [0.0, 0.0, 0.0])
    end
    def to_a
      [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, *origin, 1].map(&:to_f)
    end
  end
end

module Sketchup
  class ComponentDefinition
    def bounds
      Struct.new(:min, :max).new([0.0, 0.0, 0.0], (box || [0, 0, 0]).map(&:to_f))
    end
  end
end

# --- Kanten ohne Fläche (Umriss Rückwand-Ausschnitt im Spülenschrank) ---
module Sketchup
  class Entities
    def edges
      (@edges ||= [])
    end
    def add_line(a, b)
      edges << [a, b]
      bx = definition.box || [0, 0, 0]
      definition.box = (0..2).map { |i| [bx[i], a[i], b[i]].max }
      [a, b]
    end
  end
end
