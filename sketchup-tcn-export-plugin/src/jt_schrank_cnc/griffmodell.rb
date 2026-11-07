# encoding: UTF-8
# Schrank-CNC – Griffe im SketchUp-Modell (Griffkatalog, Jürgen 2026-11-07: „stelle sicher, dass die
# Griffe auch gerendert werden“).
#
# Griffe sind sichtbare Teile der Küche und werden deshalb immer gezeichnet, nicht nur bei
# „Beschläge ein/aus“: an jeder Front mit Griffbohrungen (Regeln.griffe, gleiche Lage wie im TCN) ein
# vereinfachter Körper in den Maßen des Katalogs (Länge × Höhe = Ausladung): Griff = Stange über die
# Länge mit zwei Stützen an den Bohrungen, Knopf = Scheibe (Ø = Länge) auf einem Stiel. Material nach der
# Oberfläche („Griff schwarz matt“ …; Rendern erkennt „Griff“ als Metall, Eiche als Holz).
# Die Gruppe „Griffe“ (Tag „Griffe“, Wörterbuch JT_Griff) liegt im Elternteil der Front (Schublade,
# Türhalter oder Schrank), nicht in der Front selbst: sonst wüchse die Front um den Griff (Maße der Front
# kommen aus ihrer Definition, TCN und Stückliste). Kein JT_Schrank/teil: Stückliste und TCN sehen sie nicht.
# Ein von Hand gesetzter Griff ohne Serie bekommt einen Körper „Griff frei“ (Lochmaß + 16 × 30).
# Öffnung „Griffmulde gefräst“: statt Griffen schneidet Griffmulde.schrank_zeichnen die Mulde in die Fronten.

module JTools
  module SchrankCnc
    module Griffmodell
      module_function

      DICT = 'JT_Griff'.freeze
      TAG = 'Griffe'.freeze
      GRUPPE = 'Griffe'.freeze
      VERSION = 2 # 2: Vorschlag 20 %, Falttür nur kurze Tür (alte Griffe neu zeichnen)
      STANGE = 10.0 # Stärke der Stange (mm)
      STUETZE_R = 4.5
      FREI = { ueber: 16.0, hoehe: 30.0 }.freeze

      # Farbe nach der Oberfläche (Stichwort im Namen, erste passende Regel)
      FARBEN = [
        [/eiche.*schwarz/i, [45, 36, 30]], [/eiche/i, [190, 150, 100]],
        [/schwarz|oil rubbed/i, [32, 32, 34]], [/kupfer/i, [184, 115, 75]], [/bronze/i, [140, 104, 64]],
        [/gold|messing/i, [196, 162, 92]], [/weiß|perl/i, [236, 235, 230]], [/blau/i, [40, 62, 96]],
        [/rot/i, [150, 62, 46]], [/champagner|beige/i, [212, 196, 160]],
        [/anthrazit|graphit|schiefer|titan|zinn|blei|oliv|moos|grau|eisen/i, [86, 88, 92]]
      ].freeze
      STANDARD = [200, 202, 206].freeze # vernickelt, verchromt, edelstahl, silber, alu

      def materialname(oberflaeche)
        o = oberflaeche.to_s.empty? ? 'frei' : oberflaeche.to_s
        # Holz ohne „lackiert“ (Rendern läse „lack“ als Hochglanz)
        o =~ /eiche/i ? "Holz #{o.sub(/\s*lackiert/i, '')} (Beschlag)" : "Griff #{o}"
      end

      def farbe(oberflaeche)
        (FARBEN.find { |re, _| oberflaeche.to_s =~ re } || [nil, STANDARD])[1]
      end

      # --- Körper (Weltkoordinaten mm, Beschlagmodell::Koerper) ---------------------------------
      def koerper(teile)
        out = Hash.new { |h, k| h[k] = [] }
        teile.each do |w|
          ops = w.ops.select { |o| o.titel == 'Griff' && o.daten }
          next if ops.empty? || w.teil.pfad.size < 2
          out[w.teil.pfad[0..-2]].concat(griff_koerper(w, ops))
        end
        out
      end

      def griff_koerper(w, ops)
        d = ops[0].daten
        g = d[:griff]
        da = w.dicke_achse
        wa = d[:quer]
        aus = d[:aussen]
        fl = aus > 0 ? w.hi[da] : w.lo[da] # Außenseite der Front
        xs = ops.map { |o| o.p0[wa] }
        z = ops[0].p0[2]
        xm = xs.sum / xs.size
        gr = g[:groesse]
        s = g[:serie]
        mat = materialname(gr && gr['oberflaeche'])
        bm = Beschlagmodell
        if s && Griffkatalog.knopf?(s)
          r = gr['laenge'].to_f / 2.0
          h = gr['hoehe'].to_f
          scheibe = [STANGE, h / 3.0].min
          stiel = [r * 0.45, 4.0].max
          mitte = bm.p3(wa => xm, da => fl, 2 => z)
          return [bm.zylinder('Knopf Stiel', mat, mitte, da, fl, fl + aus * (h - scheibe), stiel),
                  bm.zylinder('Knopf', mat, mitte, da, fl + aus * (h - scheibe), fl + aus * h, r)]
        end
        laenge = gr ? gr['laenge'].to_f : g[:lochmass] + FREI[:ueber]
        h = gr ? gr['hoehe'].to_f : FREI[:hoehe]
        k = []
        xs.each_with_index do |x, i|
          k << bm.zylinder("Griff Stütze #{i + 1}", mat, bm.p3(wa => x, da => fl, 2 => z), da, fl, fl + aus * (h - STANGE), STUETZE_R)
        end
        k << bm.quader('Griff', mat, bm.p3(wa => xm - laenge / 2.0, da => fl + aus * (h - STANGE), 2 => z - STANGE / 2.0),
                       bm.p3(wa => xm + laenge / 2.0, da => fl + aus * h, 2 => z + STANGE / 2.0))
        k.compact
      end

      # --- SketchUp ------------------------------------------------------------------------
      def tag(model)
        model.layers[TAG] || model.layers.add(TAG)
      end

      def material(model, name)
        m = model.materials[name]
        return m if m
        m = model.materials.add(name)
        m.color = Sketchup::Color.new(*farbe(name))
        m
      end

      def gruppe?(e)
        e.is_a?(Sketchup::Group) && e.get_attribute(DICT, 'gruppe') == true
      end

      def gruppen_in(ents)
        ents.grep(Sketchup::Group).select { |g| gruppe?(g) }
      end

      def alle_gruppen(ents, out = [], gesehen = {})
        Schraenke.instanzen(ents).each do |i|
          if gruppe?(i)
            out << i
            next
          end
          d = Schraenke.definition(i)
          next if gesehen[d.object_id]
          gesehen[d.object_id] = true
          alle_gruppen(d.entities, out, gesehen)
        end
        out
      end

      def zeichnen(model, ents, fl, sig)
        g = ents.add_group
        g.name = GRUPPE
        g.layer = tag(model)
        g.set_attribute(DICT, 'gruppe', true)
        g.set_attribute(DICT, 'signatur', sig)
        fl.each do |k, flaechen|
          kg = g.entities.add_group
          kg.name = k.name
          kg.layer = tag(model)
          kg.material = material(model, k.mat)
          flaechen.each do |pts|
            kg.entities.add_face(*pts.map { |p| Geom::Point3d.new(*p) })
          rescue ArgumentError
            next
          end
        end
        g
      end

      def fingerabdruck(s)
        m = s.respond_to?(:model) ? s.model : nil
        "g#{VERSION}|#{Griffkatalog.fingerabdruck(m)}|#{Griffmulde.fingerabdruck(m)}|#{Beschlagmodell.fingerabdruck(s)}"
      end

      # Griffe eines Schranks auf Stand bringen; Anzahl Körper, nil wenn eine Tür offen steht
      def schrank_aktualisieren(model, s)
        Beschlagkatalog.mit_schrank(s) { schrank_zeichnen(model, s) }
      end

      def schrank_zeichnen(model, s)
        ws = Beschlagmodell.werkstuecke(model, s)
        return nil unless Beschlagmodell.geschlossen?(ws)
        model.set_attribute(DICT, 'an', true) if Griffmulde.schrank_zeichnen(ws) > 0 && model.respond_to?(:set_attribute)
        anzahl = 0
        behaelter = {}
        soll = {}
        koerper(ws).each do |pfad, liste|
          (soll[Schraenke.definition(pfad.last)] ||= []) << [pfad, liste] unless liste.empty?
        end
        soll.each do |d, eintraege|
          lok = eintraege.map { |pfad, liste| Beschlagmodell.lokal(pfad, liste) }
          next unless lok.map(&:last).uniq.size == 1 # geteilte Definition, verschiedene Lage
          fl, sig = lok.first
          behaelter[d] = true
          anzahl += eintraege.first.last.size
          alt = gruppen_in(d.entities)
          next if alt.size == 1 && alt[0].get_attribute(DICT, 'signatur') == sig
          d.entities.erase_entities(alt) unless alt.empty?
          zeichnen(model, d.entities, fl, sig)
        end
        alle_gruppen(Schraenke.definition(s).entities).each { |g| g.erase! unless behaelter[g.parent] }
        s.set_attribute(DICT, 'fingerabdruck', fingerabdruck(s))
        anzahl
      end

      # Gezeichnet wird, sobald die Küche eine Griffserie hat oder schon Griffe gezeichnet sind
      def aktiv?(model)
        return false unless model
        Griffkatalog.kueche(model) || model.get_attribute(DICT, 'an') == true ||
          Griffmulde.aktiv?(Beschlagkatalog.kueche('oeffnung', model)) ? true : false
      end

      # Alle Schränke neu (nach einer Wahl in Griffkatalog, Einstellungen oder Schrank-Dialog)
      def aktualisieren(model = Sketchup.active_model)
        return 0 unless model.entities.respond_to?(:add_group) # Test-Attrappe ohne Geometrie
        model.set_attribute(DICT, 'an', true)
        Beschlagmodell.schraenke(model).sum { |s| schrank_aktualisieren(model, s).to_i }
      end

      # Nach jedem Vorgang: Schränke mit geändertem Fingerabdruck (transparent am Vorgang davor)
      def nachziehen(model)
        return unless model && model.valid? && aktiv?(model)
        offen = Beschlagmodell.schraenke(model).select { |s| s.get_attribute(DICT, 'fingerabdruck') != fingerabdruck(s) }
        return if offen.empty?
        model.start_operation('Griffe', true, false, true)
        offen.each { |s| schrank_aktualisieren(model, s) }
        model.commit_operation
      rescue StandardError => e
        model.abort_operation if model
        puts "Griffe: #{e.message}"
      end

      if defined?(Sketchup::ModelObserver)
        class Beobachter < Sketchup::ModelObserver
          def onTransactionCommit(model)
            return if @laeuft || !Griffmodell.aktiv?(model)
            @laeuft = true
            id = UI.start_timer(0, false) do
              UI.stop_timer(id)
              begin
                Griffmodell.nachziehen(model)
              ensure
                @laeuft = false
              end
            end
          end
        end

        class AppBeobachter < Sketchup::AppObserver
          def onNewModel(model)
            Griffmodell.beobachten(model)
          end

          def onOpenModel(model)
            Griffmodell.beobachten(model)
          end
        end
      end

      def beobachten(model)
        return unless model && defined?(Beobachter)
        @beobachter ||= Beobachter.new
        model.remove_observer(@beobachter)
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
