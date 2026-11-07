# encoding: UTF-8
# Schrank-CNC – Bohrungen, Dübel und Schrauben im SketchUp-Modell zeigen (Jürgen, 2026-11-07:
# „Rendere alle Bohrungen, Schrauben und Dübel“).
#
# Alles kommt aus denselben Bearbeitungen wie der TCN-Export (Regeln.anwenden über das ganze Modell,
# damit auch die Sockelklemmen der Blenden passen, die von den Füßen der Nachbarschränke abhängen):
#   Bohrungen   jede Einzelbohrung und jedes Loch einer Reihe (Lochreihen, Dübel, Schienen, Fronthalter,
#               Montageplatten, Klappenbeschläge, Griffe, Sockelfüße, Sockelklemmen …) als Zylinder in
#               Durchmesser × Tiefe, Topfband: Topf und die beiden Dübellöcher (inge100: Abstand, Versatz
#               von der Kante weg)
#   Fräsungen   Nuten und Taschen (Quader in Breite × Tiefe)
#   Dübel       in jeder Dübelbohrung der Stirnseite (Boden, Deckel, Zwischenboden, Strebe, Mittelwand):
#               Holzdübel Ø8 × 35, 21 im Teil, 14 in der Seite
#   Schrauben   an den Schraubenbohrungen („Schraube …“: Strebe und Boden in der Seite, Rückwand–Deckel):
#               Schraube Ø4 von der Außenseite des gebohrten Teils durch das Teil und 30 mm in das
#               anstoßende Teil, mit Senkkopf (Länge und Ø ANGENOMMEN, nicht aus einer Vorlage)
# Bohrungen in Türen, Klappen und Fronten liegen im Teil selbst (drehen sich mit), alle anderen im
# Elternteil (Schrank, Schublade): linke und rechte Seite teilen sich eine Definition, die Löcher liegen
# aber spiegelbildlich. Bohrungen und Fräsungen bleiben ganz innerhalb der Plattenstärke (Deckel
# EINTAUCHEN unter der Oberfläche), Dübel und Schrauben innerhalb der beiden verbundenen Teile.
# Ohne Röntgen sieht man nur, was durch die Oberfläche durchscheint; zum Prüfen den Röntgen-Knopf nehmen.
# Gruppe „Bohrungen“ auf dem Tag „Bohrungen“, ohne JT_Schrank/teil: Stückliste, Etiketten, Zuschnitt und TCN
# sehen sie nicht, Rendern lässt den Tag weg. Eigener Schalter (nicht mit „Beschläge ein/aus“), weil eine
# Küche einige tausend Löcher hat und das Modell sonst immer schwer wäre. Eingeschaltet folgen die
# Bohrungen jeder Änderung an einem Schrank (wie die Beschläge).

require 'digest/md5'

module JTools
  module SchrankCnc
    module Bohrmodell
      module_function

      DICT = 'JT_Bohrung'.freeze
      TAG = 'Bohrungen'.freeze
      GRUPPE = 'Bohrungen'.freeze
      VERSION = 1
      EINTAUCHEN = 0.2 # mm: Bohrungsdeckel unter der Oberfläche (sonst flimmert er mit der Plattenfläche)
      MATERIALIEN = {
        bohrung: ['Bohrung', [25, 25, 28]],
        fraesung: ['Fräsung', [70, 60, 50]],
        duebel: ['Dübel Buche', [214, 176, 120]],
        schraube: ['Schraube verzinkt', [176, 180, 186]]
      }.freeze
      ARTEN = { bohrung: 'Bohrungen', fraesung: 'Fräsungen', duebel: 'Dübel', schraube: 'Schrauben' }.freeze
      DUEBEL = { d: 8.0, in_teil: 21.0, in_seite: 14.0 }.freeze # Holzdübel 8 × 35
      SCHRAUBE = { d: 4.0, einschraub: 30.0, kopf_d: 8.0, kopf_t: 3.0 }.freeze # angenommen
      Koerper = Beschlagmodell::Koerper

      def an?(model = Sketchup.active_model)
        model ? model.get_attribute(DICT, 'an') == true : false
      end

      # ---------------------------------------------------------------------
      # Körper in Weltkoordinaten (mm): { Pfad des Behälters => [[Art, Körper], …] }
      # ---------------------------------------------------------------------
      def koerper(ws)
        out = Hash.new { |h, k| h[k] = [] }
        ws.each do |w|
          next if w.teil.pfad.size < 2
          eltern = out[w.teil.pfad[0..-2]]
          ziel = selbst?(w) ? out[w.teil.pfad] : eltern
          w.ops.each do |o|
            case o.art
            when :bohrung, :reihe
              punkte(o).each { |p| ziel << [:bohrung, loch(w, o.seite, p, o.d, o.tiefe)] }
              eltern.concat(verbinder(w, o))
            when :topfband
              topfband(w, o).each { |k| ziel << [:bohrung, k] }
            when :nut, :tasche
              ziel << [:fraesung, fraesung(w, o)]
            end
          end
        end
        out.each_value { |l| l.reject! { |_, k| k.nil? } }
        out
      end

      # Türen, Klappen und Fronten: Löcher ins Teil selbst (die Tür dreht sich ohne Halter, siehe Oberschrank)
      def selbst?(w)
        w.teil.front? || w.teil.jt('teil').to_s.start_with?('Klappe')
      end

      # Löcher einer Reihe (wie die Bohrmakros fittingx/fittingy): ab p0 im Raster ST bis p1;
      # verteilt (#8508/#8509 = 1): gleichmäßig über die Länge mit höchstens ST Abstand
      def punkte(o)
        return [o.p0] if o.art == :bohrung || o.p1.nil?
        d = (0..2).map { |i| o.p1[i] - o.p0[i] }
        l = Math.sqrt(d.sum { |v| v * v })
        return [o.p0] if l < Regeln::TOL || o.raster.to_f < Regeln::TOL
        n = if o.verteilt then (l / o.raster.to_f - 1e-6).ceil
            else (l / o.raster.to_f + 1e-6).floor
            end
        st = o.verteilt ? l / n : o.raster.to_f
        (0..n).map { |i| (0..2).map { |a| o.p0[a] + d[a] / l * st * i } }
      end

      # Richtung in das Teil hinein (Weltachse, ±1) für eine Bearbeitung auf der Weltseite seite
      def hinein(seite)
        [Geometrie.achse(seite), Geometrie.max?(seite) ? -1 : 1]
      end

      # Zylinder in der Stärke des Teils: Deckel EINTAUCHEN unter der Oberfläche, höchstens bis
      # EINTAUCHEN vor der Gegenseite (Durchgangsbohrung)
      def loch(w, seite, p, d, tiefe, r_plus = 0.05)
        ax, dir = hinein(seite)
        fl = dir < 0 ? w.hi[ax] : w.lo[ax]
        t = [tiefe.to_f, w.mass(ax)].min - EINTAUCHEN
        t = [t, w.mass(ax) - 2 * EINTAUCHEN].min
        return nil if t < 0.1 || d.to_f < 0.1
        m = p.dup
        Beschlagmodell.zylinder("Bohrung Ø#{zahl(d)} × #{zahl(tiefe)}", MATERIALIEN[:bohrung][0], m, ax,
                                fl + dir * EINTAUCHEN, fl + dir * (EINTAUCHEN + t), d.to_f / 2.0 + r_plus)
      end

      # Topfband: Topf und die beiden Dübellöcher der Scharnierplatte (inge100: Abstand längs der Kante,
      # Versatz von der Topfmitte weg von der Kante)
      def topfband(w, o)
        out = [loch(w, o.seite, o.p0, o.d, o.tiefe)]
        sc = o.daten && o.daten[:schraub]
        kante = o.daten && o.daten[:kante]
        return out unless sc && kante
        ax, = hinein(o.seite)
        wa = Geometrie.achse(kante)
        laengs = ([0, 1, 2] - [ax, wa]).first
        return out unless laengs
        weg = Geometrie.max?(kante) ? -1 : 1
        [-1, 1].each do |s|
          p = o.p0.dup
          p[laengs] += s * sc[:abstand].to_f / 2.0
          p[wa] += weg * sc[:versatz].to_f
          # Dübellöcher wie im Makro (#8505 = 14 tief)
          out << loch(w, o.seite, p, sc[:d], 14)
        end
        out
      end

      # Dübel in der Stirnseite (Teil A) mit Gegenbohrung in der Seite; Schraube von der Außenseite des
      # gebohrten Teils durch das Teil ins anstoßende
      def verbinder(w, o)
        titel = o.titel.to_s
        ax, dir = hinein(o.seite)
        fl = dir < 0 ? w.hi[ax] : w.lo[ax]
        if titel.start_with?('Duebel ') && ax != w.dicke_achse
          r = DUEBEL[:d] / 2.0 - 0.15
          return punkte(o).map do |p|
            [:duebel, Beschlagmodell.zylinder('Dübel 8 × 35', MATERIALIEN[:duebel][0], p, ax,
                                              fl - dir * (DUEBEL[:in_seite] - 0.3), fl + dir * (DUEBEL[:in_teil] - 0.3), r)]
          end
        end
        return [] unless titel.start_with?('Schraube ')
        s = SCHRAUBE
        aussen = fl + dir * w.mass(ax) # Gegenseite des gebohrten Teils: dort wird geschraubt
        laenge = w.mass(ax) + s[:einschraub]
        name = "Schraube #{zahl(s[:d])} × #{(laenge / 5.0).ceil * 5} (angenommen)"
        punkte(o).flat_map do |p|
          [[:schraube, Beschlagmodell.zylinder(name, MATERIALIEN[:schraube][0], p, ax, aussen - dir * EINTAUCHEN,
                                               fl - dir * s[:einschraub], s[:d] / 2.0 - 0.1)],
           [:schraube, Beschlagmodell.zylinder("#{name} Kopf", MATERIALIEN[:schraube][0], p, ax, aussen - dir * EINTAUCHEN,
                                               aussen - dir * (EINTAUCHEN + s[:kopf_t]), s[:kopf_d] / 2.0)]]
        end
      end

      # Nut (Mittellinie p0 → p1, Breite d) und Tasche (Rechteck p0/p1) als Quader in der Tiefe
      def fraesung(w, o)
        ax, dir = hinein(o.seite)
        fl = dir < 0 ? w.hi[ax] : w.lo[ax]
        t = [o.tiefe.to_f, w.mass(ax) - 2 * EINTAUCHEN].min
        lo = o.p0.dup
        hi = o.p1.dup
        if o.art == :nut
          quer = (0..2).find { |i| i != ax && (o.p0[i] - o.p1[i]).abs < Regeln::TOL }
          return nil unless quer
          lo[quer] -= o.d.to_f / 2.0
          hi[quer] += o.d.to_f / 2.0
        end
        lo[ax] = fl + dir * EINTAUCHEN
        hi[ax] = fl + dir * t
        # nicht über das Teil hinaus (Nut mit Überlauf)
        (0..2).each do |i|
          next if i == ax
          a, b = [lo[i], hi[i]].minmax
          lo[i] = [a, w.lo[i] + EINTAUCHEN].max
          hi[i] = [b, w.hi[i] - EINTAUCHEN].min
        end
        Beschlagmodell.quader("#{o.art == :nut ? 'Nut' : 'Tasche'} #{o.titel}", MATERIALIEN[:fraesung][0], lo, hi)
      end

      def zahl(v)
        v = v.to_f
        (v - v.round).abs < 0.01 ? v.round.to_s : format('%.1f', v).tr('.', ',')
      end

      # ---------------------------------------------------------------------
      # SketchUp
      # ---------------------------------------------------------------------
      def tag(model)
        model.layers[TAG] || model.layers.add(TAG)
      end

      def material(model, (name, rgb))
        m = model.materials[name]
        return m if m
        m = model.materials.add(name)
        m.color = Sketchup::Color.new(*rgb)
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
          next if Beschlagmodell.gruppe?(i)
          d = Schraenke.definition(i)
          next if gesehen[d.object_id]
          gesehen[d.object_id] = true
          alle_gruppen(d.entities, out, gesehen)
        end
        out
      end

      def fingerabdruck(s)
        "b#{VERSION}|#{Beschlagmodell.fingerabdruck(s)}"
      end

      # Flächen im Behälter je Art und eine kurze Signatur (MD5) zum Vergleich
      def lokal(pfad, liste)
        inv = Beschlagmodell.invers(Geometrie.welt(pfad))
        fl = liste.group_by(&:first).map { |art, l| [art, l.flat_map { |_, k| Beschlagmodell.flaechen(k, inv) }] }.sort_by { |a, _| a.to_s }
        sig = Digest::MD5.hexdigest(fl.map { |art, f| "#{art}:#{f.flatten.map { |v| v.round(3) }.join(',')}" }.join('|'))
        [fl, sig]
      end

      # Je Art eine Untergruppe mit allen Flächen (leichter als eine Gruppe je Loch)
      def zeichnen(model, ents, fl, sig)
        g = ents.add_group
        g.name = GRUPPE
        g.layer = tag(model)
        g.set_attribute(DICT, 'gruppe', true)
        g.set_attribute(DICT, 'signatur', sig)
        fl.each do |art, flaechen|
          kg = g.entities.add_group
          kg.name = ARTEN[art]
          kg.layer = tag(model)
          kg.material = material(model, MATERIALIEN[art])
          flaechen.each do |pts|
            kg.entities.add_face(*pts.map { |p| Geom::Point3d.new(*p) })
          rescue ArgumentError
            next
          end
        end
        g
      end

      # Werkstücke des ganzen Modells mit Bearbeitungen (wie der TCN-Export)
      def werkstuecke(model)
        ws = Export.werkstuecke(model)
        Regeln.anwenden(ws)
        ws
      end

      # Alle Bohrungen auf Stand bringen; Schränke mit offener Tür oder Klappe bleiben, wie sie sind.
      # Liefert die Anzahl der Körper.
      def aktualisieren(model)
        ws = werkstuecke(model)
        offen = []
        gezeigt = []
        ws.group_by { |w| w.teil.schrank }.each do |s, teile|
          (Beschlagmodell.geschlossen?(teile) ? gezeigt : offen) << [s, teile]
        end
        soll = {}
        koerper(gezeigt.flat_map(&:last)).each do |pfad, liste|
          next if liste.empty? || pfad.empty?
          (soll[Schraenke.definition(pfad.last)] ||= []) << [pfad, liste]
        end
        behalten = {}
        offen.each { |s, _| alle_gruppen(Schraenke.definition(s).entities).each { |g| behalten[g] = true } }
        behaelter = {}
        anzahl = 0
        soll.each do |d, eintraege|
          lok = eintraege.map { |pfad, liste| lokal(pfad, liste) }
          # geteilte Definition mit verschiedener Lage (z. B. gespiegelt): dort nichts, sonst säße es falsch
          next unless lok.map(&:last).uniq.size == 1
          fl, sig = lok.first
          behaelter[d] = true
          anzahl += eintraege.first.last.size
          alt = gruppen_in(d.entities)
          next if alt.size == 1 && alt[0].get_attribute(DICT, 'signatur') == sig
          d.entities.erase_entities(alt) unless alt.empty?
          zeichnen(model, d.entities, fl, sig)
        end
        alle_gruppen(model.entities).each { |g| g.erase! unless behaelter[g.parent] || behalten[g] }
        offen_s = offen.map(&:first)
        Beschlagmodell.schraenke(model).each do |s|
          s.set_attribute(DICT, 'fingerabdruck', fingerabdruck(s)) unless offen_s.include?(s)
        end
        anzahl
      end

      def entfernen(model)
        g = alle_gruppen(model.entities)
        g.each(&:erase!)
        Beschlagmodell.schraenke(model).each { |s| s.delete_attribute(DICT, 'fingerabdruck') }
        g.size
      end

      def setzen(model, an)
        model.start_operation(an ? 'Bohrungen zeigen' : 'Bohrungen ausblenden', true)
        model.set_attribute(DICT, 'an', an)
        n = an ? aktualisieren(model) : entfernen(model)
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
        UI.messagebox('Keine Bohrungen gefunden (keine Schränke im Modell).') if an && n.to_i.zero?
        an
      end

      # Nach jedem Vorgang: hat sich ein Schrank geändert, alles neu rechnen (Sockelklemmen hängen an den
      # Nachbarn); gezeichnet wird nur, wo sich die Signatur ändert
      def nachziehen(model)
        return unless model && model.valid? && an?(model)
        return if defined?(Roentgen) && Roentgen.isoliert?(model) # Schrank zum Röntgen geöffnet: Lage der Teile anders
        return if Beschlagmodell.schraenke(model).all? { |s| s.get_attribute(DICT, 'fingerabdruck') == fingerabdruck(s) }
        model.start_operation('Bohrungen', true, false, true)
        aktualisieren(model)
        model.commit_operation
      rescue StandardError => e
        model.abort_operation if model
        puts "Bohrungen: #{e.message}"
      end

      if defined?(Sketchup::ModelObserver)
        class Beobachter < Sketchup::ModelObserver
          def onTransactionCommit(model)
            return if @laeuft || !Bohrmodell.an?(model)
            @laeuft = true
            id = UI.start_timer(0, false) do
              UI.stop_timer(id)
              begin
                Bohrmodell.nachziehen(model)
              ensure
                @laeuft = false
              end
            end
          end
        end

        class AppBeobachter < Sketchup::AppObserver
          def onNewModel(model)
            Bohrmodell.beobachten(model)
          end

          def onOpenModel(model)
            Bohrmodell.beobachten(model)
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
