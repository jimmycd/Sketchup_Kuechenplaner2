# encoding: UTF-8
# Schrank-CNC – Röntgen (Jürgen, 2026-11-07: „Button, um einen Schrank bzw. eine Auswahl im Röntgenmodus
# anzuzeigen, um versteckte Elemente zu überprüfen“).
#
# Ein Klick: Röntgen (Darstellung „X-Ray“) an. Ist genau ein Schrank (oder ein Teil, eine Gruppe) gewählt,
# wird er allein gezeigt: SketchUp öffnet ihn wie zum Bearbeiten und blendet den Rest des Modells aus
# (Ansicht > Komponentenbearbeitung > Rest des Modells ausblenden). Sonst wird das ganze Modell geröntgt,
# die Auswahl bleibt markiert. Noch ein Klick: alles wie vorher (Darstellung, Bearbeitungsebene).
# Zusammen mit „Bohrungen ein/aus“ und „Beschläge ein/aus“ sieht man so Dübel, Schrauben, Bohrungen,
# ausgeblendete Teile und Beschläge im Inneren der Platten.
# Solange ein Schrank geöffnet ist, rechnen Beschläge, Bohrungen und Griffe nicht nach (die Lage der Teile
# im geöffneten Schrank meldet SketchUp dann anders); Export und Rendern schalten das Röntgen vorher aus.

module JTools
  module SchrankCnc
    module Roentgen
      module_function

      DICT = 'JT_Roentgen'.freeze
      OPTIONEN = %w[ModelTransparency InactiveHidden].freeze

      def an?(model = Sketchup.active_model)
        model ? model.get_attribute(DICT, 'an') == true : false
      end

      # Ein Schrank ist zum Röntgen geöffnet (Bearbeitungsebene gesetzt)
      def isoliert?(model = Sketchup.active_model)
        return false unless an?(model) && model.get_attribute(DICT, 'isoliert') == true
        model.respond_to?(:active_path) && !model.active_path.to_a.empty?
      end

      def zustand
        @zustand ||= {}
      end

      def einschalten(model)
        ro = model.rendering_options
        vorher = OPTIONEN.to_h { |k| [k, ro[k]] }
        pfad_vorher = model.respond_to?(:active_path) ? model.active_path.to_a : []
        sel = model.selection.to_a
        isoliert = false
        if sel.size == 1 && (sel[0].is_a?(Sketchup::ComponentInstance) || sel[0].is_a?(Sketchup::Group)) &&
           model.respond_to?(:active_path=)
          begin
            model.active_path = pfad_vorher + [sel[0]]
            ro['InactiveHidden'] = true
            isoliert = true
          rescue ArgumentError, TypeError
            isoliert = false
          end
        end
        ro['ModelTransparency'] = true
        zustand[model.object_id] = { optionen: vorher, pfad: pfad_vorher }
        model.set_attribute(DICT, 'an', true)
        model.set_attribute(DICT, 'isoliert', isoliert)
        # für den Fall eines Neustarts mitten im Röntgen: Darstellung von vorher
        vorher.each { |k, v| model.set_attribute(DICT, k, v) unless v.nil? }
        isoliert
      end

      def ausschalten(model)
        z = zustand.delete(model.object_id)
        ro = model.rendering_options
        OPTIONEN.each do |k|
          v = z ? z[:optionen][k] : model.get_attribute(DICT, k)
          ro[k] = v.nil? ? false : v
        end
        if model.get_attribute(DICT, 'isoliert') == true && model.respond_to?(:active_path=)
          begin
            pfad = z ? z[:pfad].select(&:valid?) : []
            model.active_path = pfad.empty? ? nil : pfad
          rescue ArgumentError, TypeError
            model.active_path = nil
          end
        end
        model.set_attribute(DICT, 'an', false)
        model.set_attribute(DICT, 'isoliert', false)
        # was während des Röntgens liegen blieb, jetzt nachrechnen
        [Beschlagmodell, Bohrmodell, Griffmodell].each { |m| m.nachziehen(model) if m.respond_to?(:nachziehen) }
        false
      end

      # Symbolleiste/Menü: an ↔ aus; liefert den neuen Zustand
      def umschalten(model = Sketchup.active_model)
        return false unless model
        if an?(model)
          ausschalten(model)
        else
          einschalten(model)
          true
        end
      end

      # vor Export und Rendern: Röntgen aus, damit alle Teile in Modell-Lage gerechnet werden
      def zuruecksetzen(model = Sketchup.active_model)
        ausschalten(model) if model && an?(model)
      end
    end
  end
end
