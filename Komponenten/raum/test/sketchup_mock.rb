# Minimaler Ersatz für die SketchUp-Ruby-API, nur was der Raum nutzt.
require 'set'
$loaded = {}
def file_loaded?(f) = $loaded[f]
def file_loaded(f) = $loaded[f] = true
GL_LINE_LOOP = 2

module UI
  class Menu
    attr_reader :eintraege
    def initialize = @eintraege = []
    def add_item(t, &blk) = @eintraege << [t, blk]
    def add_separator = nil
    def add_submenu(_) = Menu.new.tap { |m| (@unter ||= []) << m }
  end
  def self.menu(_) = (@menu ||= Menu.new)
  def self.messagebox(m) = ($meldungen ||= []) << m
  def self.beep = ($meldungen ||= []) << :beep
  # Antworten der Dialoge der Reihe nach aus $antworten (nil = Abbrechen)
  def self.inputbox(prompts, defaults, *rest)
    ($dialoge ||= []) << [prompts, defaults, rest]
    a = ($antworten ||= []).shift
    a == :std ? defaults : a
  end
end

module Geom
  class Vector3d
    attr_reader :x, :y, :z
    def initialize(x = 0, y = 0, z = 0) = (@x, @y, @z = x.to_f, y.to_f, z.to_f)
    def to_a = [x, y, z]
    def %(o) = x * o.x + y * o.y + z * o.z
    def transform(t) = t.anwenden(self)
    def length = Math.sqrt(self % self)
  end
  Point3d = Vector3d

  # Drehung (Spalten = Achsen) und Verschiebung
  class Transformation
    attr_reader :m, :o
    def initialize(m = [[1, 0, 0], [0, 1, 0], [0, 0, 1]], o = [0, 0, 0]) = (@m, @o = m, o)
    def self.axes(o, x, y, z) = new([x.to_a, y.to_a, z.to_a].transpose, o.to_a)
    def self.translation(v) = new([[1, 0, 0], [0, 1, 0], [0, 0, 1]], v.to_a)
    def origin = Geom::Point3d.new(*@o)
    def xaxis = Geom::Vector3d.new(*@m.map(&:first))
    def anwenden(p)
      v = p.to_a
      Geom::Point3d.new(*(0..2).map { |i| (0..2).sum { |j| @m[i][j] * v[j] } + @o[i] })
    end
    def *(t)
      m = (0..2).map { |i| (0..2).map { |j| (0..2).sum { |k| @m[i][k] * t.m[k][j] } } }
      Transformation.new(m, anwenden(Geom::Point3d.new(*t.o)).to_a)
    end
    def inverse
      mt = @m.transpose
      Transformation.new(mt, (0..2).map { |i| -(0..2).sum { |j| mt[i][j] * @o[j] } })
    end
  end
end

module Sketchup
  class Color
    attr_reader :rgb
    def initialize(*rgb) = @rgb = rgb
  end

  module Attr
    def dicts = (@dicts ||= {})
    def set_attribute(d, k, v) = (dicts[d] ||= {})[k] = v
    def get_attribute(d, k, default = nil) = dicts.dig(d, k).nil? ? default : dicts.dig(d, k)
  end

  class Face
    attr_reader :pts, :normal, :entities
    attr_accessor :geloescht, :hub
    def initialize(ents, pts)
      @entities, @pts = ents, pts
      n = [0.0, 0.0, 0.0]
      pts.each_with_index do |p, i|
        q = pts[(i + 1) % pts.size]
        n[0] += (p.y - q.y) * (p.z + q.z)
        n[1] += (p.z - q.z) * (p.x + q.x)
        n[2] += (p.x - q.x) * (p.y + q.y)
      end
      l = Math.sqrt(n.sum { |v| v * v })
      raise 'Fläche ohne Ausdehnung' if l < 1e-9
      @normal = Geom::Vector3d.new(*n.map { |v| v / l })
    end
    def reverse! = @normal = Geom::Vector3d.new(-@normal.x, -@normal.y, -@normal.z)
    def erase! = (@geloescht = true; @entities.entfernen(self))
    def pushpull(d)
      raise 'pushpull nach unten' unless @normal.z > 0 && d > 0
      @hub = d
    end
  end

  class Edge
    Ende = Struct.new(:position)
    attr_reader :start, :end
    def initialize(a, b) = (@start, @end = Ende.new(a), Ende.new(b))
  end

  class Entities
    include Enumerable
    attr_reader :parent
    def initialize(parent) = (@parent, @list = parent, [])
    def add_face(*pts)
      f = Face.new(self, pts.flatten)
      @list << f
      f
    end
    def add_group
      g = Group.new(@parent.respond_to?(:model) ? @parent.model : $model)
      @list << g
      g
    end
    def add_instance(d, tr)
      i = ComponentInstance.new(d, tr, @parent)
      d.instances << i
      @list << i
      i
    end
    def entfernen(e) = @list.delete(e)
    def clear!
      @list.grep(ComponentInstance).each { |i| i.definition.instances.delete(i) }
      @list.clear
    end
    def each(&) = @list.each(&)
    def grep(k) = @list.grep(k)
    def to_a = @list.dup
  end

  class ComponentDefinition
    include Attr
    attr_accessor :name, :description
    attr_reader :entities, :instances, :model
    def initialize(n, model) = (@name, @model, @entities, @instances = n, model, Entities.new(self), [])
  end

  # Gruppe: eigene Definition wie in SketchUp
  class Group
    include Attr
    attr_accessor :name, :material, :layer, :transformation
    attr_reader :definition, :model
    def initialize(model)
      @model = model
      @definition = ComponentDefinition.new('Gruppe', model)
      @definition.instances << self
      @transformation = Geom::Transformation.new
    end
    def entities = @definition.entities
  end

  class ComponentInstance
    include Attr
    attr_accessor :name, :material, :layer, :transformation
    attr_reader :definition, :parent
    def initialize(d, tr, parent) = (@definition, @transformation, @parent = d, tr, parent)
  end

  class Mat
    attr_accessor :color, :name, :alpha
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

  class Definitions
    attr_reader :h
    def initialize(model) = (@model, @h = model, {})
    def add(n)
      name = n
      k = 0
      name = "#{n}##{k += 1}" while @h.key?(name)
      @h[name] = ComponentDefinition.new(name, @model)
    end
    def remove(d) = @h.delete(d.name)
    def size = @h.size
  end

  class Model
    attr_reader :definitions, :materials, :layers, :active_entities, :selection, :werkzeug, :operationen
    attr_accessor :active_path, :active_view
    def initialize
      @definitions, @materials, @layers = Definitions.new(self), Named.new(Mat), Named.new(Layer)
      @active_entities = Entities.new(self)
      @selection = Set.new
      @operationen = []
    end
    def model = self
    def entities = @active_entities
    def start_operation(t, *) = @operationen << [:start, t]
    def commit_operation = @operationen << [:commit]
    def abort_operation = @operationen << [:abort]
    def select_tool(t) = @werkzeug = t
  end

  class InputPoint; end

  class << self
    attr_accessor :active_model, :status_text, :vcb_label, :vcb_value
  end
end
