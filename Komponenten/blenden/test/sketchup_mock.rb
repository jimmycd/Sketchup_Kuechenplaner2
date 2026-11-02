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
  class Point3d
    attr_reader :x, :y, :z
    def initialize(x = 0, y = 0, z = 0) = (@x, @y, @z = x.to_f, y.to_f, z.to_f)
    def to_a = [x, y, z]
    def [](i) = to_a[i]
  end

  # Drehung um z (Winkel w) und Verschiebung – mehr brauchen Schränke nicht
  class Transformation
    attr_reader :w, :o
    def initialize(w = 0.0, o = [0.0, 0.0, 0.0]) = (@w, @o = w.to_f, o.map(&:to_f))
    def self.translation(v) = new(0.0, v.is_a?(Vector3d) ? v.a : v.to_a.map(&:to_f))
    def self.drehung(grad, o) = new(grad * Math::PI / 180, o)
    def origin = @o.dup
    def xaxis = Vector3d.new(Math.cos(@w), Math.sin(@w), 0)
    def anwenden(p)
      x, y, z = p.to_a
      [@o[0] + x * Math.cos(@w) - y * Math.sin(@w), @o[1] + x * Math.sin(@w) + y * Math.cos(@w), @o[2] + z]
    end
    def *(other)
      return Point3d.new(*anwenden(other)) unless other.is_a?(Transformation)
      Transformation.new(@w + other.w, anwenden(other.o))
    end
    def inverse
      c, s = Math.cos(-@w), Math.sin(-@w)
      Transformation.new(-@w, [-(@o[0] * c - @o[1] * s), -(@o[0] * s + @o[1] * c), -@o[2]])
    end
  end

  class BoundingBox
    attr_reader :min, :max
    def add(*ps)
      ps.flatten.each do |b|
        [b.min, b.max].each do |p|
          a = p.to_a
          @lo = @lo ? @lo.zip(a).map(&:min) : a
          @hi = @hi ? @hi.zip(a).map(&:max) : a
        end
      end
      @min, @max = Point3d.new(*@lo), Point3d.new(*@hi)
      self
    end
    def empty? = @lo.nil?
  end
end

module Sketchup
  class Color; def initialize(*); end; end
  class Group; end

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
    def bounds
      unless entities.instances.empty?
        bb = Geom::BoundingBox.new
        entities.instances.each { |i| bb.add(i.bounds) }
        return bb
      end
      Struct.new(:min, :max).new(Geom::Point3d.new, Geom::Point3d.new(*(box || [0, 0, 0])))
    end
    def instances = []
  end

  class ComponentInstance
    include Attr
    attr_accessor :name, :material, :layer, :hidden, :transformation
    attr_reader :definition
    def initialize(d, tr) = (@definition, @transformation = d, tr)
    def hidden? = !!hidden
    # Bounds im Eltern-System (nur Verschiebung, wie die Teile in den Komponenten)
    def bounds
      o = transformation.origin
      b = definition.bounds
      bb = Geom::BoundingBox.new
      bb.add(Struct.new(:min, :max).new(Geom::Point3d.new(*o.zip(b.min.to_a).map(&:sum)), Geom::Point3d.new(*o.zip(b.max.to_a).map(&:sum))))
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
    def add_layer(n) = @h[n] = Struct.new(:name).new(n)
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
      @selection = Selection.new
    end
    def start_operation(*) = nil
    def commit_operation = nil
    def abort_operation = nil
    def bounds = Struct.new(:max).new(Struct.new(:x).new(0))
  end

  class Selection < Set
    def to_a = super
    def add(*e) = (e.flatten.each { |x| super(x) }; self)
  end

  class << self
    attr_accessor :active_model
  end
end
