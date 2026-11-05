# encoding: UTF-8
# Schrank-CNC – Schrank-Beschriftung in den Szenen „Planung“ und „Zuschnitt“.
#
# Jeder Schrank bekommt einen Text mit seinem Kürzel (z. B. US1, HS2, USM1) – dieselbe
# Quelle wie Stückliste und Etiketten: JT_Schrank/schrank (die Komponenten schreiben das
# Kürzel gleichlautend an den Schrank und an jedes Teil, die Etiketten drucken es als
# „<Kürzel> · <Teil>“ und im Tag „<Kürzel>_…“).
#
# Der Text steht wie bei den Geräten vorn auf der größten sichtbaren Front, ohne Front
# schwebt er 100 mm vor dem Schrank (Jürgen 2026-11-05: mitten im Schrank sah man ihn nur
# bei offener Tür). Die Texte stehen in einer Gruppe „Schrank-Beschriftung“ auf dem Tag
# „Beschriftung“ (oberste Ebene, nicht im Schrank: der TCN-Export, die Stückliste und das Andocken sehen
# sie nicht). Ein-/Ausschalten (Symbolleiste oder Menü) zeigt den Tag in den Szenen
# „Planung“ und „Zuschnitt“ bzw. blendet ihn dort aus; in „Kunde“ ist er nie zu sehen.
# Solange die Beschriftung an ist, folgt sie nach jedem Vorgang dem Modell (Schrank
# verschoben, neues Kürzel, Schrank neu oder gelöscht); die Anpassung hängt sich an den
# Vorgang davor, ein Rückgängig nimmt beides zurück.

module JTools
  module SchrankCnc
    module Beschriftung
      TAG = 'Beschriftung'.freeze
      DICT = 'JT_Beschriftung'.freeze
      GRUPPE = 'Schrank-Beschriftung'.freeze
      SZENEN = %w[Planung Zuschnitt].freeze # hier zeigt „ein“ die Beschriftung
      NIE = %w[Kunde].freeze                # hier nie
      TOL = 0.01 # Zoll

      module_function

      def an?(model = Sketchup.active_model)
        model ? model.get_attribute(DICT, 'an') == true : false
      end

      # Alle Schränke als [Kürzel, Instanz, Weltmatrix]; Schränke in Gruppen werden
      # mitgefunden, Teile in einem Schrank nicht (der äußerste Schrank zählt)
      def schraenke(model, ents = model.entities, m = Andocken::EINS, out = [])
        Schraenke.instanzen(ents).each do |inst|
          next if beschriftung?(inst)
          w = Andocken::Rechnung.matmul(m, inst.transformation.to_a.map(&:to_f))
          kz = Schraenke.definition(inst).get_attribute(JT_DICT, 'schrank')
          if kz
            out << [kz.to_s, inst, w]
          else
            schraenke(model, Schraenke.definition(inst).entities, w, out)
          end
        end
        out
      end

      VOR_FRONT = 1.0 / 25.4   # Text 1 mm vor der Front, damit die Front ihn nicht verdeckt
      SCHWEBEN = 100.0 / 25.4  # ohne Front: 100 mm vor dem Schrank

      # Sichtbare Fronten/Türen des Schranks als Kasten [x0, x1, y0, y1, z0, z1] im Schranksystem
      def fronten(model, inst)
        Schraenke.teile(model, Schraenke.definition(inst).entities, [], inst).select { |t| t.front? && t.sichtbar? }.map do |t|
          m = t.pfad.reduce(Andocken::EINS) { |a, i| Andocken::Rechnung.matmul(a, i.transformation.to_a.map(&:to_f)) }
          b = Schraenke.definition(t.inst).bounds
          Andocken::Rechnung.box_trafo(m, b.min.to_a.map(&:to_f), b.max.to_a.map(&:to_f))
        end
      end

      # Punkt des Texts (Weltkoordinaten): wie bei den Geräten vorn auf der Front – mittig auf der
      # größten sichtbaren Front (Tür, Klappe, Schubkasten), knapp davor. Ohne Front schwebt er
      # vor dem Schrank, mittig in Breite und Höhe. Vorn ist im Schranksystem die kleine y-Seite.
      def punkt(model, inst, w)
        f = fronten(model, inst).max_by { |b| [(b[1] - b[0]) * (b[5] - b[4]), b[5]] }
        p = if f
              [(f[0] + f[1]) / 2.0, f[2] - VOR_FRONT, (f[4] + f[5]) / 2.0]
            else
              k = Andocken.kasten(inst)
              [(k[0] + k[1]) / 2.0, k[2] - SCHWEBEN, (k[4] + k[5]) / 2.0]
            end
        (0..2).map { |r| w[r] * p[0] + w[4 + r] * p[1] + w[8 + r] * p[2] + w[12 + r] }
      end

      # Soll-Beschriftung: [[Kürzel, [x, y, z]], …] sortiert
      def soll(model)
        schraenke(model).map { |kz, inst, w| [kz, punkt(model, inst, w)] }.sort_by { |kz, p| [kz, p] }
      end

      def beschriftung?(e)
        e.is_a?(Sketchup::Group) && e.get_attribute(DICT, 'gruppe') == true
      end

      def gruppe(model)
        model.entities.grep(Sketchup::Group).find { |g| beschriftung?(g) }
      end

      def tag(model)
        model.layers[TAG] || model.layers.add(TAG)
      end

      def texte(g)
        g ? g.entities.grep(Sketchup::Text) : []
      end

      # Ist-Beschriftung im selben Format wie #soll
      def ist(model)
        texte(gruppe(model)).map { |t| [t.text.to_s, t.point.to_a.map(&:to_f)] }.sort_by { |kz, p| [kz, p] }
      end

      def gleich?(a, b)
        a.size == b.size && a.zip(b).all? do |(ka, pa), (kb, pb)|
          ka == kb && pa.zip(pb).all? { |x, y| (x - y).abs < TOL }
        end
      end

      # Gruppe mit den Texten neu aufbauen, wenn sie nicht zum Modell passt.
      # Gibt die Anzahl der Texte zurück; ändert nichts, wenn alles stimmt.
      def aktualisieren(model)
        s = soll(model)
        g = gruppe(model)
        return s.size if g && gleich?(s, ist(model))
        t = tag(model)
        g.erase! if g
        return 0 if s.empty?
        g = model.entities.add_group
        g.name = GRUPPE
        g.layer = t
        g.set_attribute(DICT, 'gruppe', true)
        s.each do |kz, p|
          tx = g.entities.add_text(kz, Geom::Point3d.new(*p))
          tx.layer = t
        end
        s.size
      end

      # Tag in den Szenen Planung/Zuschnitt zeigen bzw. ausblenden, in Kunde immer aus;
      # in der aktuellen Ansicht wie die gewählte Szene (ohne Szene: wie „an“)
      def szenen(model, an)
        t = tag(model)
        model.pages.each do |seite|
          if SZENEN.include?(seite.name) then seite.set_visibility(t, an)
          elsif NIE.include?(seite.name) then seite.set_visibility(t, false)
          end
        end
        aktuell = model.pages.selected_page
        t.visible = an && !(aktuell && NIE.include?(aktuell.name))
      end

      def setzen(model, an)
        model.start_operation(an ? 'Schrank-Beschriftung ein' : 'Schrank-Beschriftung aus', true)
        model.set_attribute(DICT, 'an', an)
        n = an ? aktualisieren(model) : nil
        szenen(model, an)
        model.commit_operation
        beobachten(model) if an
        n
      rescue StandardError
        model.abort_operation
        raise
      end

      # Symbolleiste/Menü: ein ↔ aus
      def umschalten(model = Sketchup.active_model)
        an = !an?(model)
        n = setzen(model, an)
        if an
          hinweise = []
          hinweise << 'Keine Schränke im Modell.' if n.to_i.zero?
          fehlt = SZENEN.reject { |name| model.pages[name] }
          hinweise << "Szene #{fehlt.join(' und ')} fehlt noch (Geräte › Szenen Planung/Kunde/Zuschnitt anlegen)." unless fehlt.empty?
          UI.messagebox(hinweise.join("\n\n")) unless hinweise.empty?
        end
        an
      end

      # Nach jedem Vorgang: passt die Beschriftung nicht mehr, wird sie neu aufgebaut.
      # Die Änderung hängt sich an den Vorgang davor (transparent), Rückgängig nimmt beides.
      def nachziehen(model)
        return unless model && model.valid? && an?(model)
        s = soll(model)
        return if gruppe(model) && gleich?(s, ist(model))
        model.start_operation('Schrank-Beschriftung', true, false, true)
        aktualisieren(model)
        model.commit_operation
      rescue StandardError => e
        model.abort_operation if model
        puts "Schrank-Beschriftung: #{e.message}"
      end

      if defined?(Sketchup::ModelObserver)
        # verzögert, weil das Modell im Beobachter nicht geändert werden soll
        class Beobachter < Sketchup::ModelObserver
          def onTransactionCommit(model)
            return if @laeuft || !Beschriftung.an?(model)
            @laeuft = true
            id = UI.start_timer(0, false) do
              UI.stop_timer(id)
              begin
                Beschriftung.nachziehen(model)
              ensure
                @laeuft = false
              end
            end
          end
        end

        class AppBeobachter < Sketchup::AppObserver
          def onNewModel(model)
            Beschriftung.beobachten(model)
          end

          def onOpenModel(model)
            Beschriftung.beobachten(model)
          end
        end
      end

      def beobachten(model)
        return unless model && defined?(Beobachter)
        @beobachter ||= Beobachter.new
        model.remove_observer(@beobachter) # nicht doppelt
        model.add_observer(@beobachter)
      end

      def app_beobachten
        return if @app || !defined?(AppBeobachter)
        @app = AppBeobachter.new
        Sketchup.add_observer(@app)
        beobachten(Sketchup.active_model)
      end
    end
  end
end
