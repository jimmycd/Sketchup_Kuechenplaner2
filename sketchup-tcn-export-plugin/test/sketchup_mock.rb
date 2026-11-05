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
    def defaults = (@defaults ||= {})
    def read_default(s, k, d = nil) = defaults.fetch([s, k], d)
    def write_default(s, k, v) = defaults[[s, k]] = v
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

# --- für den TCN-Export: Matrix und Bounds (die Komponenten nutzen nur Verschiebungen) ---
module Geom
  class Transformation
    def origin = (@origin ||= [0.0, 0.0, 0.0])
    def to_a = [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, *origin, 1].map(&:to_f)
  end
end

module Sketchup
  class ComponentDefinition
    def bounds = Struct.new(:min, :max).new([0.0, 0.0, 0.0], (box || [0, 0, 0]).map(&:to_f))
  end
end

# --- Kanten ohne Fläche (Umriss Rückwand-Ausschnitt im Spülenschrank) ---
module Sketchup
  class Entities
    def edges = (@edges ||= [])
    def add_line(a, b)
      edges << [a, b]
      bx = definition.box || [0, 0, 0]
      definition.box = (0..2).map { |i| [bx[i], a[i], b[i]].max }
      [a, b]
    end
  end
end

# --- Andock-Werkzeug: Drehung, Punkte, BoundingBox, Werkzeuge ---
module Geom
  class Point3d
    attr_reader :x, :y, :z
    def initialize(x = 0, y = 0, z = 0) = (@x, @y, @z = x.to_f, y.to_f, z.to_f)
    def to_a = [x, y, z]
  end
  class BoundingBox
    attr_reader :min, :max
    def add(*ps)
      ps = ps.flat_map { |p| p.is_a?(BoundingBox) ? [p.min, p.max] : [p] }
      ps.each do |p|
        p = p.to_a
        @min = @min ? @min.zip(p).map(&:min) : p.dup
        @max = @max ? @max.zip(p).map(&:max) : p.dup
      end
      self
    end
    def empty? = @min.nil?
  end
  class Transformation
    attr_reader :achsen
    def self.axes(o, x, y, z)
      t = translation(o.to_a)
      t.instance_variable_set(:@achsen, [x.to_a, y.to_a, z.to_a])
      t
    end
    def xaxis = Vector3d.new(*(achsen ? achsen[0] : [1, 0, 0]))
    # Matrix spaltenweise wie SketchUp, mit Drehung, wenn über axes gebaut
    def to_a
      return [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, *origin, 1].map(&:to_f) unless achsen
      [*achsen[0], 0, *achsen[1], 0, *achsen[2], 0, *origin, 1].map(&:to_f)
    end
  end
end

module Sketchup
  class ComponentInstance
    def model = Sketchup.active_model
    attr_writer :transformation
  end
  class Model
    include Attr # Modell-Attribute (z. B. Schrank-Beschriftung ein/aus)
    attr_reader :werkzeug
    def select_tool(t) = @werkzeug = t
  end
end

module Sketchup
  class ComponentInstance
    # Grenzen im Elternsystem (nur Verschiebung, wie bei den Teilen der Komponenten)
    def bounds
      b = definition.bounds
      o = transformation.origin
      Geom::BoundingBox.new.add(b.min.zip(o).map(&:sum), b.max.zip(o).map(&:sum))
    end
  end
end

# Symbolleiste (kuechenplaner-symbolleiste): Befehle und Symbolleisten aufzeichnen
MF_ENABLED = 0 unless defined?(MF_ENABLED)
MF_GRAYED = 1 unless defined?(MF_GRAYED)
MF_CHECKED = 8 unless defined?(MF_CHECKED)
TB_NEVER_SHOWN = -1 unless defined?(TB_NEVER_SHOWN)
module Sketchup
  def self.platform = :platform_win
end
module UI
  class Command
    attr_accessor :small_icon, :large_icon, :tooltip, :status_bar_text
    attr_reader :titel, :aktion, :validation
    def initialize(titel, &aktion) = (@titel, @aktion = titel, aktion)
    def set_validation_proc(&blk) = @validation = blk
  end
  class Toolbar
    attr_reader :name, :befehle, :sichtbar
    def self.alle = (@alle ||= [])
    def initialize(name) = (@name, @befehle = name, []).tap { Toolbar.alle << self }
    def add_item(c) = @befehle << c
    def get_last_state = TB_NEVER_SHOWN
    def show = @sichtbar = true
    def restore = nil
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
      return pushpull_yz(pts, d) if pts.all? { |q| q[0].abs < 1e-9 } && d > 0
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

# --- Umriss in der yz-Ebene, entlang x hochgezogen (Wange mit Sockelausklinkung) ---
module Sketchup
  class Face
    attr_reader :pts
    def bounds
      q = @pts.map { |x| x.to_a.map(&:to_f) + [0.0] * (3 - x.to_a.size) }
      Geom::BoundingBox.new.add(*q)
    end
    def pushpull_yz(pts, d)
      oben = pts.map { |q| [d, q[1], q[2]] }
      @ents.definition.box = [d, pts.map { |q| q[1] }.max, pts.map { |q| q[2] }.max]
      @ents.faces.clear
      @ents.faces << Face.new(@ents, pts, [-1.0, 0.0, 0.0]) << Face.new(@ents, oben, [1.0, 0.0, 0.0])
      flaeche = (pts + [pts[0]]).each_cons(2).sum { |a, b| a[1] * b[2] - b[1] * a[2] }
      s = flaeche > 0 ? 1 : -1
      (pts + [pts[0]]).each_cons(2).with_index do |(a, b), i|
        dy, dz = b[1] - a[1], b[2] - a[2]
        l = Math.hypot(dy, dz)
        next if l < 1e-9
        f = Face.new(@ents, [a, b, [d, b[1], b[2]], [d, a[1], a[2]]], [0.0, s * dz / l, -s * dy / l])
        f.area = l * d
        @ents.faces << f
      end
    end
  end
end

# --- Materialien (Konfigurator): Farbanteile, Material löschen, Suche nach aktuellem Namen ---
module Sketchup
  class Color
    def red = rgb[0].to_i
    def green = rgb[1].to_i
    def blue = rgb[2].to_i
  end
  class Named
    def [](n) = @h[n] && @h[n].name == n ? @h[n] : @h.values.find { |m| m.name == n }
    def remove(m) = @h.delete(@h.key(m))
  end
end
