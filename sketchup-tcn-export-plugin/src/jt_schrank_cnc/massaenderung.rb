# encoding: UTF-8
# Schrank-CNC – Maßänderung an angedockten Schränken (Jürgen, 2026-11-05):
#   * Breite geändert: die angedockte Seite bleibt stehen, die freie Seite wandert.
#     Angedockt heißt: an der Seite liegt ein anderer Schrank oder eine Wand (mit ihrer
#     Wandabstand-Zone) an. Nur rechts angedockt → rechte Seite bleibt, der Schrank wächst
#     nach links; sonst bleibt die linke Seite (wie die Komponenten selbst wachsen).
#     Links und rechts angedockt: linke Seite bleibt, stößt der Schrank danach an, kommt
#     eine Meldung (der Nachbar muss von Hand verschoben werden).
#   * Tiefe geändert: die Rückseite bleibt (an der Wand), die Front wandert.
# Erkannt wird die Änderung am Bezugskasten (Andocken.bezug: Seiten, Wangen, Rückwand),
# der nach jedem Vorgang an der Instanz gemerkt wird (JT_Masse/kasten). Ändert er sich,
# wird die Instanz so verschoben, dass die feste Seite bzw. die Rückseite dort bleibt,
# wo sie war. Die Verschiebung hängt sich an den Vorgang davor (Rückgängig nimmt beides).

module JTools
  module SchrankCnc
    module Massaenderung
      DICT = 'JT_Masse'.freeze
      SCHLUESSEL = 'kasten'.freeze
      EPS = 0.01 / 25.4 # 0,01 mm

      module Rechnung
        module_function

        # Hat sich der Grundriss (x, y) geändert? Höhe zählt nicht (wächst nach oben).
        def geaendert?(alt, neu, eps = EPS)
          return false unless alt && neu && alt.size == 6
          (0..3).any? { |i| (alt[i].to_f - neu[i].to_f).abs > eps }
        end

        # Liegt an der Seite (:links = x0, :rechts = x1) des Kastens k in Lage l ein
        # Hindernis an (Schrank oder Wandzone)? Geprüft mit einem schmalen Streifen
        # über die Seitenfläche (innerhalb der Tiefe und Höhe des Schranks).
        def anliegend?(k, l, hindernisse, seite, tol = Andocken::TOLERANZ)
          x = seite == :links ? k[0] : k[1]
          streifen = [x - tol, x + tol, k[2] + tol, k[3] - tol, k[4] + tol, k[5] - tol]
          !Andocken::Rechnung.platz?(streifen, l, hindernisse, 0)
        end

        # Verschiebung im Schranksystem [dx, dy], damit nach der Änderung alt → neu die
        # feste Seite und die Rückseite (y1) stehen bleiben.
        def verschiebung(alt, neu, links, rechts)
          dx = rechts && !links ? alt[1] - neu[1] : alt[0] - neu[0]
          dy = alt[3] - neu[3]
          [dx, dy]
        end

        # Lage l um (dx, dy) im Schranksystem verschoben
        def verschoben(l, dx, dy)
          wx, wy = Andocken::Rechnung.drehe(l[0], dx, dy)
          [l[0], l[1] + wx, l[2] + wy, l[3]]
        end

        # Ganze Rechnung: alt/neu = Bezugskästen, l = Lage, hindernisse wie Andocken.
        # Liefert { lage:, links:, rechts:, kollision: } (kollision nur, wenn der Schrank
        # vorher frei stand und jetzt etwas überlappt).
        def anpassen(alt, neu, l, hindernisse)
          links = anliegend?(alt, l, hindernisse, :links)
          rechts = anliegend?(alt, l, hindernisse, :rechts)
          dx, dy = verschiebung(alt, neu, links, rechts)
          nl = verschoben(l, dx, dy)
          vorher = Andocken::Rechnung.platz?(alt, l, hindernisse)
          { lage: nl, links: links, rechts: rechts,
            kollision: vorher && !Andocken::Rechnung.platz?(neu, nl, hindernisse) }
        end
      end

      # ---------------------------------------------------------------------
      # SketchUp
      # ---------------------------------------------------------------------
      def self.gemerkt(inst)
        k = inst.get_attribute(DICT, SCHLUESSEL)
        k.is_a?(Array) && k.size == 6 ? k.map(&:to_f) : nil
      end

      def self.merken(inst, k)
        inst.set_attribute(DICT, SCHLUESSEL, k.map(&:to_f))
      end

      def self.betroffen?(e)
        Andocken.schrank?(e) && !Andocken::KEINE_ZEILE.include?(Andocken.kategorie(e))
      end

      def self.name(inst)
        Schraenke.definition(inst).get_attribute(JT_DICT, 'schrank') || inst.name.to_s
      end

      # Alle Schränke prüfen: gemerkten Kasten mit dem aktuellen vergleichen, bei einer
      # Änderung verschieben. Liefert die Meldungen (Kollisionen).
      def self.pruefen(model)
        meldungen = []
        Schraenke.instanzen(model.entities).each do |e|
          next unless betroffen?(e)
          neu = Andocken.bezug(e)
          alt = gemerkt(e)
          if Rechnung.geaendert?(alt, neu)
            r = Rechnung.anpassen(alt, neu, Andocken.lage(e.transformation), Andocken.hindernisse(model, e))
            e.transformation = Andocken.transformation(r[:lage])
            if r[:kollision]
              meldungen << "Schrank #{name(e)}: nach der Maßänderung stößt er an einen Nachbarn oder an die Wand" \
                           "#{r[:links] && r[:rechts] ? ' (links und rechts angedockt, linke Seite bleibt)' : ''}. " \
                           'Bitte den Nachbarn verschieben.'
            end
          end
          merken(e, neu) unless alt && !Rechnung.geaendert?(alt, neu)
        end
        meldungen
      end

      # Nach jedem Vorgang: nur wenn sich etwas geändert hat, einen Vorgang öffnen
      # (transparent, hängt am Vorgang davor).
      def self.nachziehen(model)
        return unless model && model.valid?
        offen = Schraenke.instanzen(model.entities).select do |e|
          betroffen?(e) && (gemerkt(e).nil? || Rechnung.geaendert?(gemerkt(e), Andocken.bezug(e)))
        end
        return if offen.empty?
        model.start_operation('Schrank-Maße', true, false, true)
        meldungen = pruefen(model)
        model.commit_operation
        UI.messagebox(meldungen.join("\n\n")) unless meldungen.empty?
      rescue StandardError => e
        model.abort_operation if model
        puts "Maßänderung: #{e.message}"
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
                Massaenderung.nachziehen(model)
              ensure
                @laeuft = false
              end
            end
          end
        end

        class AppBeobachter < Sketchup::AppObserver
          def onNewModel(model)
            Massaenderung.beobachten(model)
          end

          def onOpenModel(model)
            Massaenderung.beobachten(model)
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
      end
    end
  end
end
