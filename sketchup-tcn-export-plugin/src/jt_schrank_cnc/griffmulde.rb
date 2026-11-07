# encoding: UTF-8
# Schrank-CNC – Griffmulde gefräst (grifflose Front, Jürgen 2026-11-07, Bild 1 im Plan „Grifflose Fronten“).
#
# Öffnung „Griffmulde gefräst“ (Katalogeintrag griffmulde, Beschlagart oeffnung: für die Küche in den
# Einstellungen, je Schrank im Dialog „Beschläge und Griffe…“): jede Front eines Unter- oder Oberschranks
# bekommt statt Griffbohrungen eine Ausklinkung durch die ganze Front an der Kante, an der man greift:
# Unterschrank oben (Eingriff von oben), Oberschrank unten (von unten). Hochschränke sind ausgenommen
# (Jürgen), sie behalten ihre Griffe.
#
# Lage: Tür mit Topfbändern an der Öffnungskante (rand vom Rand), kurze Falttür an ihrer freien Kante
# (die lange bekommt keine), Schubladen, Klappen und Türen ohne Topfband mittig. Oberschrank: nur die
# unterste Front (oberer Teil der Faltklappe und obere Tür nicht). Maße (Breite, Tiefe ab der Kante,
# Abstand zur Öffnungskante, Eckradius) aus dem Katalogeintrag, im Modell änderbar (Einstellungen).
# Die Innenecken haben mindestens den Radius des Konturfräsers 1004 (Ø 20), der die Mulde ganz durch
# fräst (TCN wie die Schrägkante des Abschlussregals: Bahn um den Fräserradius versetzt, Ein- und
# Auslauf außerhalb der Front, Bögen als kurze Geraden).
#
# Im Modell wird die Mulde in die Front geschnitten (Flächen der Frontdefinition neu, Maße der Front
# bleiben, die Schnittflächen ohne Material = Frontfarbe); ohne Mulde wieder der volle Quader.

require 'json'

module JTools
  module SchrankCnc
    module Griffmulde
      module_function

      KENNUNG = 'griffmulde'.freeze
      DICT = 'Kuechenplaner_Einstellungen'.freeze
      SCHLUESSEL = 'griffmulde'.freeze
      FRONT_DICT = 'JT_Griffmulde'.freeze
      TITEL = 'Griffmulde'.freeze
      KATEGORIEN = %w[Unterschrank Oberschrank].freeze
      # Bezeichnungen im Einstellungsfenster
      FELDER = {
        'breite' => 'Griffmulde Breite (mm)',
        'hoehe' => 'Griffmulde Tiefe ab Frontkante (mm)',
        'rand' => 'Griffmulde Abstand zur Öffnungskante der Tür (mm)',
        'radius' => 'Griffmulde Eckradius (mm, mindestens 10)'
      }.freeze
      MIN_STEG = 20.0 # mm: so viel Front bleibt mindestens neben der Mulde
      BOGEN_TEILE = 8 # Umriss: Viertelbogen in so viele Geraden

      def eintrag
        Beschlagkatalog.eintrag(KENNUNG)
      end

      def min_radius
        Regeln::KONTUR[:d] / 2.0
      end

      def standard
        eintrag['mulde'].transform_values(&:to_f)
      end

      def modell(model)
        Beschlagkatalog.modell(model)
      end

      # Maße der Mulde (mm): im Modell gespeichert, sonst zuletzt auf diesem Rechner, sonst Katalog
      def masse(model = nil)
        m = modell(model)
        roh = m.get_attribute(DICT, SCHLUESSEL) if m.respond_to?(:get_attribute)
        roh ||= Sketchup.read_default(DICT, SCHLUESSEL, nil) if defined?(Sketchup) && Sketchup.respond_to?(:read_default)
        w = (JSON.parse(roh) rescue nil) if roh.is_a?(String)
        w = standard.merge((w.is_a?(Hash) ? w : {}).select { |k, v| FELDER.key?(k) && v.is_a?(Numeric) }.transform_values(&:to_f))
        w['radius'] = [w['radius'], min_radius].max
        w
      end

      # Fehlertext oder nil
      def fehler(w)
        return 'Griffmulde: bitte nur Zahlen größer 0 eingeben.' unless FELDER.keys.all? { |k| w[k].is_a?(Numeric) && w[k] > 0 }
        r = [w['radius'], min_radius].max
        return "Griffmulde: Eckradius mindestens #{Tcn.n(min_radius)} mm (Fräser Ø #{Tcn.n(Regeln::KONTUR[:d])})." if w['radius'] < min_radius - 1e-9
        return 'Griffmulde: die Breite muss größer als zwei Eckradien sein.' if w['breite'] <= 2 * r
        return 'Griffmulde: die Tiefe muss größer als der Eckradius sein.' if w['hoehe'] <= r
        nil
      end

      def setzen(w, model = nil)
        w = FELDER.keys.to_h { |k| [k, w[k].to_f] }
        f = fehler(w) and raise ArgumentError, f
        roh = JSON.generate(w)
        m = modell(model)
        m.set_attribute(DICT, SCHLUESSEL, roh) if m.respond_to?(:set_attribute)
        Sketchup.write_default(DICT, SCHLUESSEL, roh) if defined?(Sketchup) && Sketchup.respond_to?(:write_default)
        w
      end

      # Öffnung mit Mulde (Eintrag der Küche oder des Schranks aus mit_schrank)
      def aktiv?(e = Beschlagkatalog.gewaehlt('oeffnung'))
        e && e['mulde'] ? true : false
      end

      # Schrank mit Mulde statt Griffen (Öffnung Mulde, Unter- oder Oberschrank)
      def schrank?(teile)
        aktiv? && !teile.empty? && KATEGORIEN.include?(Schraenke.kategorie(teile.first.teil))
      end

      def fingerabdruck(model = nil)
        "m=#{Beschlagkatalog.gespeichert('oeffnung', model)}|#{masse(model).sort.map { |k, v| "#{k}=#{v}" }.join(',')}"
      end

      # ---------------------------------------------------------------------
      # Regel: Op :kontur „Griffmulde“ an den Fronten eines Schranks (Regeln.schrank_anwenden)
      # ---------------------------------------------------------------------
      def front?(w)
        %w[Front Tuer].include?(w.rolle) && w.teil.jt('teil') != 'Blende' && !w.teil.jt('griff_aus') &&
          w.dicke_achse != 2 && w.teil.sichtbar?
      end

      def quer_achse(w)
        (w.flaechen_achsen - [2]).first
      end

      def regeln(teile, meldungen)
        return unless schrank?(teile)
        m = masse
        ober = Schraenke.kategorie(teile.first.teil) == 'Oberschrank'
        fronten = teile.select { |w| front?(w) }
        lang, kurz = Regeln.falt_paar(fronten.select { |w| w.rolle == 'Tuer' })
        fronten.each do |w|
          next if lang && w.equal?(lang)
          next if ober && fronten.any? { |u| !u.equal?(w) && darunter?(u, w) }
          wa = quer_achse(w)
          x0, x1 = lage(w, wa, m, kurz && w.equal?(kurz) ? lang : nil)
          if x0.nil?
            meldungen << "#{w.name}: Front zu schmal für die Griffmulde (#{Tcn.n(w.mass(wa))} mm)"
            next
          end
          if w.mass(2) < m['hoehe'] + MIN_STEG
            meldungen << "#{w.name}: Front zu niedrig für die Griffmulde (#{Tcn.n(w.mass(2))} mm)"
            next
          end
          w.ops << op(w, wa, x0, x1, ober, m)
        end
      end

      # u liegt unter w und überdeckt es in der Breite (Faltklappe, übereinander liegende Türen)
      def darunter?(u, w)
        wa = quer_achse(w)
        u.hi[2] <= w.lo[2] + 5 && Regeln.ueberlapp(u, w, wa) > 20
      end

      # Mulde von x0 bis x1 (Welt, Querachse): Öffnungskante der Tür, freie Kante der kurzen Falttür, sonst Mitte
      def lage(w, wa, m, lang = nil)
        b = m['breite']
        lo, hi = w.lo[wa], w.hi[wa]
        breite = hi - lo
        r = m['radius']
        b = [b, breite - 2 * MIN_STEG].min
        return nil if b <= 2 * r
        seite = nil
        if lang
          seite = (lo + hi) / 2.0 > (lang.lo[wa] + lang.hi[wa]) / 2.0 ? :hi : :lo
        elsif (t = w.ops.find { |o| o.art == :topfband && o.daten && o.daten[:kante] }) && Geometrie.achse(t.daten[:kante]) == wa
          seite = Geometrie.max?(t.daten[:kante]) ? :lo : :hi
        end
        rand = m['rand']
        seite = nil if seite && breite < b + rand + MIN_STEG
        case seite
        when :lo then [lo + rand, lo + rand + b]
        when :hi then [hi - rand - b, hi - rand]
        else [(lo + hi - b) / 2.0, (lo + hi + b) / 2.0]
        end
      end

      # Umriss der Front mit Mulde und die Segmente der Muldenkante (Weltpunkte mm, Ebene w.lo[da])
      def umriss(w, wa, x0, x1, ober, m)
        da = w.dicke_achse
        r = m['radius']
        s = ober ? 1.0 : -1.0 # von der Kante in die Front
        zk = ober ? w.lo[2] : w.hi[2]
        zf = ober ? w.hi[2] : w.lo[2]
        zt = zk + s * m['hoehe']
        p = ->(x, z) { Regeln.punkt(da => w.lo[da], wa => x, 2 => z) }
        bogen = lambda do |cx, cz, von, bis|
          (0..BOGEN_TEILE).map do |i|
            a = von + (bis - von) * i / BOGEN_TEILE.to_f
            p.(cx + r * Math.cos(a), cz + r * Math.sin(a))
          end
        end
        # Winkel in der Ebene (Querachse, z): Mittelpunkte der Eckbögen liegen in der Mulde, sohle =
        # Richtung vom Mittelpunkt zur Muldensohle; b1 rechts von (x1, cz) zur Sohle, b0 links von der
        # Sohle nach (x0, cz) (Reihenfolge des Umrisses)
        cz = zt - s * r
        sohle = s.positive? ? Math::PI / 2 : -Math::PI / 2
        b1 = bogen.(x1 - r, cz, 0.0, sohle)
        b0 = bogen.(x0 + r, cz, sohle, s.positive? ? Math::PI : -Math::PI)
        segmente = [[:linie, p.(x0, zk), p.(x0, cz)],
                    [:bogen, p.(x0, cz), p.(x0 + r, zt), p.(x0 + r, cz)]]
        segmente << [:linie, p.(x0 + r, zt), p.(x1 - r, zt)] if x1 - x0 > 2 * r + 0.01
        segmente += [[:bogen, p.(x1 - r, zt), p.(x1, cz), p.(x1 - r, cz)],
                     [:linie, p.(x1, cz), p.(x1, zk)]]
        lo, hi = w.lo[wa], w.hi[wa]
        poly = [p.(lo, zf), p.(hi, zf), p.(hi, zk), p.(x1, zk)] + b1 + b0 + [p.(x0, zk), p.(lo, zk)]
        [poly, segmente]
      end

      def op(w, wa, x0, x1, ober, m)
        poly, segmente = umriss(w, wa, x0, x1, ober, m)
        Regeln::Op.new(:kontur, nil, nil, nil, Regeln::KONTUR[:d], w.mass(w.dicke_achse) + Regeln::DURCH, nil, nil, TITEL,
                       { umriss: poly, segmente: segmente, anleimer: 0.0,
                         mulde: { x0: x0, x1: x1, quer: wa, oben: !ober, breite: x1 - x0, hoehe: m['hoehe'], r: m['radius'] } })
      end

      # ---------------------------------------------------------------------
      # Modell: Mulde in die Front schneiden (Griffmodell.schrank_zeichnen)
      # ---------------------------------------------------------------------
      def zeichnen_moeglich?(ents)
        ents.respond_to?(:erase_entities) && ents.respond_to?(:add_face)
      end

      # Umriss der Front (Welt, Ebene w.lo[da]): mit Mulde aus der Op, sonst Rechteck; dazu je Umrisskante,
      # ob sie Muldenkante ist (ohne Kantenmaterial)
      def front_umriss(w)
        o = w.ops.find { |x| x.titel == TITEL && x.daten && x.daten[:umriss] }
        return [o.daten[:umriss], mulden_kanten(o.daten[:umriss], w, o.daten[:mulde])] if o
        da = w.dicke_achse
        wa = quer_achse(w)
        p = ->(x, z) { Regeln.punkt(da => w.lo[da], wa => x, 2 => z) }
        poly = [p.(w.lo[wa], w.lo[2]), p.(w.hi[wa], w.lo[2]), p.(w.hi[wa], w.hi[2]), p.(w.lo[wa], w.hi[2])]
        [poly, [false] * 4]
      end

      # Kante i (von Punkt i zu i+1) gehört zur Mulde, wenn sie nicht auf dem Rand der Front liegt
      # oder auf der Kante zwischen x0 und x1 (gibt es nicht, dort ist die Mulde offen)
      def mulden_kanten(poly, w, mu)
        wa = mu[:quer]
        rand = ->(q) { [(q[wa] - w.lo[wa]).abs, (q[wa] - w.hi[wa]).abs, (q[2] - w.lo[2]).abs, (q[2] - w.hi[2]).abs].min < 0.01 }
        poly.each_index.map do |i|
          a, b = poly[i], poly[(i + 1) % poly.size]
          !(rand.(a) && rand.(b) && (a[wa] - b[wa]).abs + (a[2] - b[2]).abs > 0 &&
            ((a[wa] - b[wa]).abs < 0.01 || (a[2] - b[2]).abs < 0.01))
        end
      end

      # Flächen der Front in ihren lokalen Koordinaten (Zoll): [[Punkte, mulde?], …] und Signatur
      def lokal(w)
        poly, mk = front_umriss(w)
        da = w.dicke_achse
        inv = Beschlagmodell.invers(Geometrie.welt(w.teil.pfad))
        lok = ->(q) { Geometrie.punkt(inv, q.map { |v| v / Geometrie::MM }).map { |v| v.round(5) } }
        unten = poly.map { |q| lok.(q) }
        oben = poly.map { |q| x = q.dup; x[da] = w.hi[da]; lok.(x) }
        n = poly.size
        fl = [[unten, false], [oben.reverse, false]] +
             (0...n).map { |i| [[unten[i], unten[(i + 1) % n], oben[(i + 1) % n], oben[i]], mk[i]] }
        sig = mk.any? ? fl.map { |f, _| f.flatten.map { |v| v.round(3) }.join(',') }.join('|') : nil
        [fl, sig]
      end

      # Fronten eines Schranks auf Stand bringen (nur Fronten mit Mulde oder mit früherer Mulde)
      def schrank_zeichnen(ws)
        fronten = ws.select { |w| %w[Front Tuer].include?(w.rolle) && w.dicke_achse != 2 }
        soll = fronten.map { |w| [w, *lokal(w)] }
        # gleiche Definition, verschiedene Mulde (Kopien teilen Fronten): eigene Definition
        soll.group_by { |w, _, _| Schraenke.definition(w.teil.inst) }.each_value do |gr|
          next if gr.map(&:last).uniq.size == 1
          gr[1..].each { |w, _, _| w.teil.inst.make_unique if w.teil.inst.respond_to?(:make_unique) }
        end
        soll.count do |w, fl, sig|
          d = Schraenke.definition(w.teil.inst)
          next false unless zeichnen_moeglich?(d.entities)
          alt = d.get_attribute(FRONT_DICT, 'signatur')
          next false if alt == sig # unverändert (auch: nie eine Mulde gehabt)
          schneiden(d, fl)
          sig ? d.set_attribute(FRONT_DICT, 'signatur', sig) : d.delete_attribute(FRONT_DICT, 'signatur')
          true
        end
      end

      # Flächen der Definition ersetzen; Kantenmaterial (Anleimer) bleibt an den Außenkanten
      def schneiden(d, fl)
        ents = d.entities
        flaechen = ents.grep(Sketchup::Face)
        dicke = (0..2).min_by { |i| d.bounds.max.to_a[i].to_f - d.bounds.min.to_a[i].to_f }
        kante = flaechen.find { |f| f.material && f.normal.to_a[dicke].abs < 0.5 }&.material
        seite = flaechen.find { |f| f.normal.to_a[dicke].abs > 0.5 }&.material
        ents.erase_entities(flaechen + ents.grep(Sketchup::Edge))
        fl.each_with_index do |(pts, mulde), i|
          f = ents.add_face(*pts.map { |q| Geom::Point3d.new(*q) })
          next unless f
          f.material = i < 2 ? seite : (mulde ? nil : kante)
        rescue ArgumentError
          next
        end
      end
    end
  end
end
