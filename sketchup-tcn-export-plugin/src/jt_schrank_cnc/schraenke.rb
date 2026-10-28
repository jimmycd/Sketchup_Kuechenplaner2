# encoding: UTF-8
# Schrank-CNC – Schränke und ihre Teile im Modell finden.
#
# Die Komponenten unter Komponenten/ kennzeichnen jedes Teil mit dem Tag
# <Kürzel>_<Bereich>_<Teil> und dem Wörterbuch JT_Schrank (schrank, typ,
# kategorie, bereich, teil, rolle). Der Schrank selbst trägt schrank, typ und
# kategorie an seiner Definition.

module JTools
  module SchrankCnc
    JT_DICT = 'JT_Schrank'.freeze
    DC_DICT = 'dynamic_attributes'.freeze
    KATEGORIEN = %w[Unterschrank Oberschrank Hochschrank].freeze

    # Ein Teil mit dem Pfad der Instanzen von der obersten Ebene bis zu ihm.
    # schrank ist die äußerste Instanz, deren Definition JT_Schrank/schrank trägt.
    Teil = Struct.new(:inst, :pfad, :schrank) do
      def jt(k)
        inst.get_attribute(JT_DICT, k)
      end
      def rolle
        jt('rolle')
      end
      def kategorie
        jt('kategorie')
      end
      def name
        inst.layer ? inst.layer.name : jt('teil')
      end
      def front?
        %w[Front Tuer].include?(rolle)
      end
      # sichtbar nur, wenn weder das Teil noch eine Ebene darüber ausgeblendet ist
      def sichtbar?
        pfad.none? { |i| i.hidden? }
      end
    end

    module Schraenke
      def self.instanzen(ents)
        ents.grep(Sketchup::ComponentInstance) + ents.grep(Sketchup::Group)
      end

      def self.definition(inst)
        inst.respond_to?(:definition) ? inst.definition : inst.entities.parent
      end

      # Alle Teile mit JT_Schrank/teil im Modell (auch ausgeblendete)
      def self.teile(model, ents = model.entities, pfad = [], schrank = nil, out = [])
        instanzen(ents).each do |inst|
          p = pfad + [inst]
          s = schrank || (definition(inst).get_attribute(JT_DICT, 'schrank') ? inst : nil)
          if inst.get_attribute(JT_DICT, 'teil')
            out << Teil.new(inst, p, s || inst)
          else
            teile(model, definition(inst).entities, p, s, out)
          end
        end
        out
      end

      # Kategorie eines Teils: am Teil, sonst am Schrank
      def self.kategorie(teil)
        teil.kategorie || definition(teil.schrank).get_attribute(JT_DICT, 'kategorie')
      end
    end
  end
end
