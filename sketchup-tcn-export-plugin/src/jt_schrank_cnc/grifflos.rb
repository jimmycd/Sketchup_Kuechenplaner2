# encoding: UTF-8
# Schrank-CNC – Griffkante und durchlaufende Griffmulde (grifflose Fronten, Jürgen 2026-11-07, Bild 2
# und 3 im Plan „Grifflose Fronten“, Schritt 2: Oberschränke).
#
# Öffnung „Griffkante 45°“ (Katalog griffkante): die unterste Front eines Oberschranks ist unten um
# „luft“ kürzer und hat auf der Rückseite an der Unterkante eine Fase 45° (Werkzeug 1400 Folding 45°,
# Tiefe „fase“, von innen wie die Griffbohrungen). Öffnung „Griffmulde durchlaufend“ (Katalog
# griffmulde_durchlaufend): der Boden des Oberschranks sitzt um „oberschrank“ höher, die Front steht
# unten über (Rückwand und Einlegeböden rücken mit). Unterschränke folgen mit Schritt 3 und behalten
# bis dahin ihre Griffe, Hochschränke sind ausgenommen (Jürgen).
#
# Die Komponenten haben dafür die Attribute Griff_Front (Front kürzer) und Griff_Boden (Boden höher,
# cm wie alle Längen); Schrank-CNC setzt sie nach der Öffnung der Küche oder des Schranks und zeichnet
# den Schrank neu (wie Beschlagkatalog.schrank_anpassen beim Schubladenauszug). Schränke ohne diese
# Attribute sind mit einer älteren Version angelegt und werden genannt.
# Die Fase zeichnet Griffmodell in die Front (wie die Griffmulde, Griffmulde.schrank_zeichnen).

require 'json'

module JTools
  module SchrankCnc
    module Grifflos
      module_function

      KANTE = 'griffkante'.freeze
      DURCHLAUFEND = 'griffmulde_durchlaufend'.freeze
      DICT = 'Kuechenplaner_Einstellungen'.freeze
      SCHLUESSEL = 'grifflos'.freeze
      DC_DICT = 'dynamic_attributes'.freeze
      JT_DICT = 'JT_Schrank'.freeze
      TITEL = 'Griffkante'.freeze
      KATEGORIEN = %w[Oberschrank].freeze # Unterschränke folgen (Schritt 3)
      ATTRIBUTE = %w[griff_boden griff_front].freeze
      # Bezeichnungen im Einstellungsfenster
      FELDER = {
        'fase' => 'Griffkante: Fase 45° auf der Rückseite (mm)',
        'luft' => 'Griffkante: Front kürzer um (mm)',
        'oberschrank' => 'Griffmulde durchlaufend: Oberschrank-Boden höher um (mm)'
      }.freeze
      FASE = { werkzeug: 1400, ueberlauf: 20.0 }.freeze

      def kante_eintrag
        Beschlagkatalog.eintrag(KANTE)
      end

      def mulde_eintrag
        Beschlagkatalog.eintrag(DURCHLAUFEND)
      end

      def standard
        kante_eintrag['kante'].merge(mulde_eintrag['durchlaufend']).transform_values(&:to_f)
      end

      # Maße (mm): im Modell gespeichert, sonst zuletzt auf diesem Rechner, sonst Katalog
      def masse(model = nil)
        m = Beschlagkatalog.modell(model)
        roh = m.get_attribute(DICT, SCHLUESSEL) if m.respond_to?(:get_attribute)
        roh ||= Sketchup.read_default(DICT, SCHLUESSEL, nil) if defined?(Sketchup) && Sketchup.respond_to?(:read_default)
        w = (JSON.parse(roh) rescue nil) if roh.is_a?(String)
        standard.merge((w.is_a?(Hash) ? w : {}).select { |k, v| FELDER.key?(k) && v.is_a?(Numeric) }.transform_values(&:to_f))
      end

      # Fehlertext oder nil (Front dick genug für die Fase prüft die Regel je Front)
      def fehler(w)
        return 'Griffkante/Griffmulde: bitte nur Zahlen größer 0 eingeben.' unless FELDER.keys.all? { |k| w[k].is_a?(Numeric) && w[k] > 0 }
        return 'Griffkante: die Fase ist höchstens 18 mm tief (Plattenstärke).' if w['fase'] > 18
        return 'Griffkante: die Front höchstens 100 mm kürzer.' if w['luft'] > 100
        return 'Griffmulde durchlaufend: den Boden höchstens 100 mm höher.' if w['oberschrank'] > 100
        nil
      end

      def setzen(w, model = nil)
        w = FELDER.keys.to_h { |k| [k, w[k].to_f] }
        f = fehler(w) and raise ArgumentError, f
        roh = JSON.generate(w)
        m = Beschlagkatalog.modell(model)
        m.set_attribute(DICT, SCHLUESSEL, roh) if m.respond_to?(:set_attribute)
        Sketchup.write_default(DICT, SCHLUESSEL, roh) if defined?(Sketchup) && Sketchup.respond_to?(:write_default)
        w
      end

      def fingerabdruck(model = nil)
        "k=#{masse(model).sort.map { |k, v| "#{k}=#{v}" }.join(',')}"
      end

      # :kante, :durchlaufend oder nil (Eintrag der Küche oder des Schranks aus mit_schrank)
      def art(e = Beschlagkatalog.gewaehlt('oeffnung'))
        return nil unless e
        return :kante if e['kante']
        e['durchlaufend'] ? :durchlaufend : nil
      end

      def kategorie_von(s)
        d = Schraenke.definition(s)
        (d && d.get_attribute(JT_DICT, 'kategorie')) || s.get_attribute(JT_DICT, 'kategorie')
      end

      # Schrank mit grifflosen Fronten statt Griffen (Regeln.griffe)
      def schrank?(teile)
        art && !teile.empty? && KATEGORIEN.include?(Schraenke.kategorie(teile.first.teil)) ? true : false
      end

      # Sollwerte der Komponenten-Attribute (mm) für einen Schrank
      def soll(s, model = nil)
        a = art(Beschlagkatalog.gewaehlt('oeffnung', model, schrank: s))
        m = masse(model)
        ober = KATEGORIEN.include?(kategorie_von(s).to_s)
        { 'griff_boden' => ober && a == :durchlaufend ? m['oberschrank'] : 0.0,
          'griff_front' => ober && a == :kante ? m['luft'] : 0.0 }
      end

      # Einen Schrank anpassen: :alt (ältere Version ohne Griff_*, braucht aber welche), :gleich, :neu
      def schrank_anpassen(s, model = nil)
        d = Schraenke.definition(s) or return :gleich
        w = soll(s, model)
        da = ATTRIBUTE.select { |k| !Schraenke.dc(s, k).nil? }
        return(w.values.any?(&:positive?) ? :alt : :gleich) if da.empty?
        return :gleich if da.all? { |k| (Schraenke.dc(s, k).to_f * 25.4 - w[k]).abs < 0.01 }
        [s, d].uniq.each do |ent|
          da.each { |k| ent.set_attribute(DC_DICT, k, w[k] / 25.4) if ent == d || !ent.get_attribute(DC_DICT, k).nil? }
        end
        $dc_observers.get_latest_class.redraw_with_undo(s) if defined?($dc_observers) && $dc_observers
        :neu
      end

      # Alle Schränke der Küche anpassen; Rückgabe: Kürzel der Schränke, die es nicht können
      def kueche_anpassen(model)
        return [] unless model.respond_to?(:entities)
        Schraenke.instanzen(model.entities).each_with_object([]) do |s, nicht|
          next unless Schraenke.definition(s)&.get_attribute(JT_DICT, 'schrank')
          nicht << Schraenke.definition(s).get_attribute(JT_DICT, 'schrank') if schrank_anpassen(s, model) == :alt
        end
      end

      # ---------------------------------------------------------------------
      # Regel: Fase „Griffkante“ an der untersten Front (Regeln.schrank_anwenden)
      # ---------------------------------------------------------------------
      def regeln(teile, meldungen)
        return unless art == :kante && schrank?(teile)
        m = masse
        korpus = teile.reject { |w| %w[Tuer Front].include?(w.rolle) }
        fronten = teile.select { |w| Griffmulde.front?(w) }
        fronten.each do |w|
          next if fronten.any? { |u| !u.equal?(w) && Griffmulde.darunter?(u, w) }
          dicke = w.mass(w.dicke_achse)
          if dicke < m['fase'] + 3
            meldungen << "#{w.name}: Front zu dünn für die Griffkante (#{Tcn.n(dicke)} mm)"
            next
          end
          w.ops << op(w, korpus, m['fase'])
        end
      end

      # Fase an der Unterkante auf der Seite zum Korpus, Bahn über die ganze Breite und darüber hinaus
      def op(w, korpus, fase)
        da = w.dicke_achse
        wa = Griffmulde.quer_achse(w)
        korpus = [w] if korpus.empty?
        km = korpus.sum { |k| k.lo[da] + k.hi[da] } / (2.0 * korpus.size)
        hinten = km > (w.lo[da] + w.hi[da]) / 2.0
        fl = hinten ? w.hi[da] : w.lo[da]
        z = w.lo_f(2) # Spitze auf der Kante der gefrästen Platte (ohne Anleimer, falls einer da ist)
        u = FASE[:ueberlauf]
        p0 = Regeln.punkt(da => fl, wa => w.lo[wa] - u, 2 => z)
        p1 = Regeln.punkt(da => fl, wa => w.hi[wa] + u, 2 => z)
        Regeln::Op.new(:fase, :"#{Geometrie::ACHSEN[da]}#{hinten ? 'max' : 'min'}", p0, p1, nil, fase, nil, nil, TITEL,
                       { werkzeug: FASE[:werkzeug], quer: wa, innen: hinten ? -1 : 1 })
      end

      # ---------------------------------------------------------------------
      # Modell: Querschnitt der Front mit Fase, über die Breite gezogen (Griffmulde.lokal)
      # ---------------------------------------------------------------------
      def fase_op(w)
        w.ops.find { |o| o.art == :fase }
      end

      # Flächen der Front in lokalen Koordinaten (Zoll) wie Griffmulde.lokal: [[Punkte, ohne Kante?], …]
      def lokal(w, o)
        da = w.dicke_achse
        wa = o.daten[:quer]
        f = o.tiefe
        innen = o.daten[:innen] # Richtung von der Innenseite in die Front
        fl = o.p0[da]
        # Querschnitt (Dicke, z): Rechteck mit abgeschrägter Ecke innen unten
        aussen = fl + innen * w.mass(da)
        q = [[aussen, w.lo[2]], [fl + innen * f, w.lo[2]], [fl, w.lo[2] + f], [fl, w.hi[2]], [aussen, w.hi[2]]]
        inv = Beschlagmodell.invers(Geometrie.welt(w.teil.pfad))
        lok = lambda do |(t, z), x|
          Geometrie.punkt(inv, Regeln.punkt(da => t, wa => x, 2 => z).map { |v| v / Geometrie::MM }).map { |v| v.round(5) }
        end
        a = q.map { |p| lok.(p, w.lo[wa]) }
        b = q.map { |p| lok.(p, w.hi[wa]) }
        n = q.size
        # Seitenflächen: Kante 0 unten (Anleimer), 1 Fase (ohne), 2 innen (Fläche), 3 oben, 4 außen (Fläche)
        art = [:kante, :fase, :seite, :kante, :seite]
        fl = [[a, :kante], [b.reverse, :kante]] + (0...n).map { |i| [[a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]], art[i]] }
        sig = 'fase|' + fl.map { |pts, _| pts.flatten.map { |v| v.round(3) }.join(',') }.join('|')
        [fl, sig]
      end
    end
  end
end
