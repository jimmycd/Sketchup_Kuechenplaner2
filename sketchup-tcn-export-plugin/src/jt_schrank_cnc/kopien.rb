# encoding: UTF-8
# Schrank-CNC – kopierte Schränke öffnen unabhängig (Jürgen, 2026-11-06):
#   Kopiert man einen Schrank (Verschieben mit Strg, Kopieren/Einfügen), teilen sich
#   Original und Kopie dieselbe Komponentendefinition. Schubladen, Türen, Klappen und
#   Falttüren sind Instanzen IN dieser Definition; das Interagieren-Werkzeug (DC-onClick,
#   ANIMATE) bewegt so eine Instanz, also bewegt sie sich in allen Kopien mit.
#   Abhilfe: nach jedem Vorgang bekommt jede Kopie eines Schranks eine eigene Definition
#   (make_unique), ebenso jede Zwischenebene über einem beweglichen Teil (z. B. Türhalter).
#   Die beweglichen Teile selbst und alle starren Teile (Seiten, Böden …) dürfen
#   geteilt bleiben, ihre Lage steht an der eigenen Instanz.
#   Der Vorgang hängt sich an den davor (Rückgängig nimmt Kopieren und Trennen zusammen).

module JTools
  module SchrankCnc
    module Kopien
      DC_DICT = 'dynamic_attributes'.freeze

      # Hat die Instanz (oder ihre Definition) ein DC-onClick (Schublade, Tür, Klappe …)?
      def self.beweglich?(inst)
        [inst, Schraenke.definition(inst)].any? do |e|
          v = e.get_attribute(DC_DICT, 'onclick')
          v && !v.to_s.strip.empty?
        end
      end

      # Liegt unter der Definition d (in beliebiger Tiefe) ein bewegliches Teil?
      def self.bewegliches_darunter?(d, merk = {})
        return merk[d] if merk.key?(d)
        merk[d] = false # gegen Zyklen
        merk[d] = Schraenke.instanzen(d.entities).any? do |c|
          beweglich?(c) || bewegliches_darunter?(Schraenke.definition(c), merk)
        end
      end

      def self.geteilt?(inst)
        inst.is_a?(Sketchup::ComponentInstance) && inst.definition.instances.length > 1
      end

      # Instanz und alle Zwischenebenen darunter, über denen ein bewegliches Teil liegt,
      # bekommen eine eigene Definition. Liefert die Zahl der neuen Definitionen.
      def self.trennen(inst, merk = {})
        return 0 unless bewegliches_darunter?(Schraenke.definition(inst), merk)
        n = 0
        if geteilt?(inst)
          inst.make_unique
          n += 1
        end
        Schraenke.instanzen(Schraenke.definition(inst).entities).each { |c| n += trennen(c, merk) }
        n
      end

      # Alle Schränke im Modell, deren Definition mehrfach benutzt wird (Kopien).
      def self.kopien(model)
        Schraenke.instanzen(model.entities).select { |e| Andocken.schrank?(e) && geteilt?(e) }
      end

      # Jeder kopierte Schrank mit beweglichen Teilen bekommt eigene Definitionen.
      def self.eindeutig_machen(model)
        merk = {}
        kopien(model).sum { |e| trennen(e, merk) }
      end

      # Nach jedem Vorgang: nur wenn es Kopien gibt, einen Vorgang öffnen
      # (transparent, hängt am Vorgang davor).
      def self.nachziehen(model)
        return unless model && model.valid?
        return if kopien(model).empty?
        model.start_operation('Schrank-Kopie trennen', true, false, true)
        eindeutig_machen(model)
        model.commit_operation
      rescue StandardError => e
        model.abort_operation if model
        puts "Kopien: #{e.message}"
      end

      if defined?(Sketchup::ModelObserver)
        # verzögert, weil das Modell im Beobachter nicht geändert werden soll
        class Beobachter < Sketchup::ModelObserver
          def onTransactionCommit(model)
            return if @laeuft
            @laeuft = true
            id = UI.start_timer(0, false) do
              UI.stop_timer(id)
              begin
                Kopien.nachziehen(model)
              ensure
                @laeuft = false
              end
            end
          end
        end

        class AppBeobachter < Sketchup::AppObserver
          def onNewModel(model)
            Kopien.beobachten(model)
          end

          def onOpenModel(model)
            Kopien.beobachten(model)
            Kopien.spaeter(model) # alte Modelle mit Kopien gleich beim Öffnen trennen
          end
        end
      end

      def self.beobachten(model)
        return unless model && defined?(Beobachter)
        @beobachter ||= Beobachter.new
        model.remove_observer(@beobachter) # nicht doppelt
        model.add_observer(@beobachter)
      end

      def self.app_beobachten
        return if @app || !defined?(AppBeobachter)
        @app = AppBeobachter.new
        Sketchup.add_observer(@app)
        beobachten(Sketchup.active_model)
        spaeter(Sketchup.active_model)
      end

      def self.spaeter(model)
        id = UI.start_timer(0, false) do
          UI.stop_timer(id)
          nachziehen(model)
        end
      end
    end
  end
end
