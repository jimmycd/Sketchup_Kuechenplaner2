# encoding: UTF-8
# Mock-Ergänzungen für Beschlagmodell-Tests (Gruppen mit Flächen, Beobachter) und Hilfen zum Auslesen
# der gezeichneten Körper (wie in test_beschlagmodell.rb).
require 'sketchup_mock'

# --- Ergänzungen zum Mock: Gruppen mit Flächen, Löschen, Beobachter ---
module Sketchup
  class ModelObserver; end
  class AppObserver; end
  def self.add_observer(o) = (@beobachter ||= []) << o

  class Group
    include Attr
    attr_accessor :name, :layer, :material
    attr_reader :entities, :parent
    def initialize(eltern) = (@parent, @entities = eltern, Entities.new(self))
    def transformation = Geom::Transformation.translation([0, 0, 0])
    def erase! = @parent.entities.instances.delete(self)
    def hidden? = false
    def hidden = false
  end

  class Entities
    def parent = definition
    def add_group = Group.new(definition).tap { |g| @list << g }
    def flaechen = (@flaechen ||= [])
    alias_method :add_face_alt, :add_face
    def add_face(*pts) = add_face_alt(*pts).tap { flaechen << pts.map(&:to_a) }
    def erase_entities(l) = l.each { |e| @list.delete(e) }
  end

  class Mat # die Tags des Mocks sind Mat-Objekte
    attr_writer :visible
    def visible = @visible.nil? ? true : @visible
  end

  class Model
    include Attr
    def valid? = true
    def beobachter = (@beobachter ||= [])
    def add_observer(o) = beobachter << o
    def remove_observer(o) = beobachter.delete(o)
  end
end
module UI
  def self.stop_timer(_id) = nil
  def self.messagebox(m) = ($meldungen ||= []) << m
end

# Alle Beschlag-Körper als { name, mat, pfad, pts (Welt, mm), layer, gruppe }
def koerper(model)
  out = []
  lauf = lambda do |ents, pfad|
    S::Schraenke.instanzen(ents).each do |i|
      if B.gruppe?(i)
        m = S::Geometrie.welt(pfad)
        i.entities.grep(Sketchup::Group).each do |k|
          pts = k.entities.flaechen.flatten(1).map { |p| S::Geometrie.punkt(m, p).map { |v| v * MM } }
          out << { name: k.name, mat: k.material&.name, pfad: pfad, pts: pts, layer: k.layer&.name, gruppe: i }
        end
        next
      end
      lauf.(S::Schraenke.definition(i).entities, pfad + [i])
    end
  end
  lauf.(model.entities, [])
  out
end

def grenzen(pts) = (0..2).map { |a| pts.map { |p| p[a] }.minmax }
