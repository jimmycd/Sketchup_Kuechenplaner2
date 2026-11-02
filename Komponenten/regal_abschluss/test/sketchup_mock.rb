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
  class Menu
    def add_item(_) = nil
    def add_separator = nil
    def add_submenu(_) = self
  end
  def self.start_timer(_s, _r = false) = yield
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
      d.instances << i
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
    def instances = (@instances ||= [])
  end

  class ComponentInstance
    include Attr
    attr_accessor :name, :material, :layer, :hidden
    attr_reader :definition, :transformation
    def initialize(d, tr) = (@definition, @transformation = d, tr)
    def definition=(d)
      @definition.instances.delete(self)
      d.instances << self
      @definition = d
    end
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
    def to_a = @h.values
    def remove(d) = @h.delete(@h.key(d))
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

# --- Platten mit beliebigem Umriss (Abschlussregal: Schräge, Bogen): je Umrisskante eine
# Seitenfläche mit Normale und Fläche (area, Zoll²), Rechtecke wie bisher ---
module Sketchup
  class Face
    attr_writer :area
    def area = (@area || 0.0)
    alias_method :pushpull_rechteck, :pushpull
    def pushpull(d)
      pts = @pts.map { |q| q.to_a.map(&:to_f) }
      rechteck = pts.size == 4 && pts[0][0].abs < 1e-9 && pts[0][1].abs < 1e-9 &&
                 (pts[1][1]).abs < 1e-9 && (pts[2][0] - pts[1][0]).abs < 1e-9 && pts[3][0].abs < 1e-9
      return pushpull_rechteck(d) if rechteck
      raise 'pushpull falsche Richtung' unless @normal.z > 0 && d > 0
      @ents.definition.box = [pts.map { |q| q[0] }.max, pts.map { |q| q[1] }.max, d]
      @ents.faces.clear
      [[0, 0, -1], [0, 0, 1]].each { |n| @ents.faces << Face.new(@ents, @pts, n) }
      # gegen den Uhrzeigersinn: außen liegt rechts der Kante
      flaeche = pts.each_cons(2).sum { |a, b| a[0] * b[1] - b[0] * a[1] } + pts[-1][0] * pts[0][1] - pts[0][0] * pts[-1][1]
      s = flaeche > 0 ? 1 : -1
      (pts + [pts[0]]).each_cons(2) do |a, b|
        dx, dy = b[0] - a[0], b[1] - a[1]
        l = Math.hypot(dx, dy)
        next if l < 1e-9
        f = Face.new(@ents, [a, b], [s * dy / l, -s * dx / l, 0.0])
        f.area = l * d
        @ents.faces << f
      end
    end
  end
end
