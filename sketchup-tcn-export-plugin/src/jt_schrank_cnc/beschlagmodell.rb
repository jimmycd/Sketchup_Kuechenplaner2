# encoding: UTF-8
# Schrank-CNC – Beschläge im SketchUp-Modell zeigen (Jürgen, 2026-11-06: „komplette Schublade incl.
# der Teile, die nicht gefertigt werden, auch Topfbänder und alle anderen Beschläge“).
#
# Die Beschläge werden aus denselben Bohrbildern berechnet wie TCN-Export und Beschlagliste
# (Regeln.anwenden), passen also immer zu den Bohrungen:
#   Schubladen  Blum LEGRABOX free: Zargen C oder M (Regeln.zarge) links und rechts, Korpusschienen an den
#               Schienenbohrungen, Fronthalter an der Frontbefestigung, Rückwandhalter an der Holzrückwand.
#   Türen       Blum-Topfband: Topf Ø35 in der Tür, Arm zur Seite, Montageplatte an der Seite.
#   Klappen     Blum AVENTOS HK-top: Kraftspeicher an beiden Seiten, Frontbeschlag an der Klappe.
# Vereinfachte, aber maßhaltige Körper (Quader, Topf als Zylinder). Sie liegen in einer Gruppe
# „Beschläge“ auf dem Tag „Beschlag“ in dem Teil des Schranks, das sich mitbewegt (Schublade,
# Türhalter, sonst der Schrank), und haben kein JT_Schrank/teil: Stückliste, Etiketten, Zuschnitt
# und TCN-Export sehen sie nicht. Alles liegt innerhalb des Schranks (Komponentengrenzen).
# Ein/aus über Symbolleiste oder Menü; eingeschaltet folgen die Beschläge jeder Änderung am Schrank
# (Komponentenoptionen), wie die Schrank-Beschriftung.

module JTools
  module SchrankCnc
    module Beschlagmodell
      module_function

      DICT = 'JT_Beschlag'.freeze
      TAG = 'Beschlag'.freeze
      GRUPPE = 'Beschläge'.freeze
      # Neue Fassung der Körper: zählt zum Fingerabdruck, vorhandene Beschläge werden neu gezeichnet
      VERSION = 2
      # Materialnamen: Rendern erkennt „Alu“/„Stahl“ als Metall
      MATERIALIEN = {
        alu: ['Beschlag Alu grau', [150, 152, 156]],
        stahl: ['Beschlag Stahl vernickelt', [196, 198, 202]],
        kunststoff: ['Beschlag Kunststoff grau', [110, 112, 116]]
      }.freeze

      # LEGRABOX free (vereinfacht): Zarge 12,8 mm stark, Korpusschiene 4 mm an der Seite,
      # Zarge davor; Schiene 4 mm hinter der Vorderkante der Seite, NL − 10 lang.
      LEGRABOX = { schiene: 4.0, schiene_h: 20.0, zarge: 12.8, fronthalter: 12.0, rueckwandhalter: 2.2 }.freeze
      # Blum-Topfband (vereinfacht): Topf Ø35 × 13 in der Tür, Arm 16 hoch, 16 breit, endet 25 mm
      # hinter den Löchern der Montageplatte; Montageplatte 48 × 20 × 4.
      TOPFBAND = { topf_tiefe: 13.0, arm_h: 16.0, arm_b: 16.0, arm_ueber: 25.0,
                   platte: [48.0, 20.0, 4.0] }.freeze
      # AVENTOS HK-top (vereinfacht): Kraftspeicher 30 stark, 20 vor dem ersten bis 60 hinter dem
      # letzten Loch, 60 unter bis 15 über der Lochreihe; Frontbeschlag 20 × 52 × 10; Hebelarm 8 × 8
      # schräg vom Kraftspeicher (40 hinter seinem vorderen Ende) zur Mitte des Frontbeschlags.
      AVENTOS = { dicke: 30.0, vor: 20.0, hinter: 60.0, unter: 60.0, ueber: 15.0, front: [20.0, 10.0],
                  arm: 8.0, arm_ein: 40.0 }.freeze

      def an?(model = Sketchup.active_model)
        model ? model.get_attribute(DICT, 'an') == true : false
      end

      # ---------------------------------------------------------------------
      # Körper in Weltkoordinaten (mm): Quader [lo, hi] oder Zylinder (Achse, Mitte, r, von–bis)
      # ---------------------------------------------------------------------
      # Stab: a, b = Endpunkte der Mittellinie, achse = Querachse (Breite 2r), r = halbe Breite;
      # Quader: a = lo, b = hi; Zylinder: a = Mitte der Grundfläche (Wert auf der Achse = von),
      # b = Wert auf der Achse am anderen Ende
      Koerper = Struct.new(:name, :mat, :form, :a, :b, :achse, :r)

      def quader(name, mat, p, q)
        lo = (0..2).map { |i| [p[i], q[i]].min }
        hi = (0..2).map { |i| [p[i], q[i]].max }
        return nil if (0..2).any? { |i| hi[i] - lo[i] < 0.05 }
        Koerper.new(name, mat, :quader, lo, hi)
      end

      def zylinder(name, mat, mitte, achse, von, bis, r)
        a = mitte.dup
        a[achse] = von
        Koerper.new(name, mat, :zylinder, a, bis, achse, r)
      end

      def p3(werte)
        Regeln.punkt(werte)
      end

      # ---------------------------------------------------------------------
      # Beschläge eines Schranks: { Werkstück-Pfad des Behälters => [Körper] }
      # Behälter = Instanz, in deren Definition die Gruppe kommt (Elternteil des Werkstücks).
      # ---------------------------------------------------------------------
      def koerper(teile)
        out = Hash.new { |h, k| h[k] = [] }
        # selbst: Körper kommt in das Teil selbst (Topf in die Tür), sonst in sein Elternteil
        add = lambda do |w, k, selbst = false|
          pfad = selbst ? w.teil.pfad : w.teil.pfad[0..-2]
          out[pfad] << k if k && pfad.size >= 1 && (selbst || w.teil.pfad.size >= 2)
        end
        schubladen(teile, add)
        topfbaender(teile, add)
        aventos(teile, add)
        out
      end

      def mitte(w, i)
        (w.lo[i] + w.hi[i]) / 2.0
      end

      def schubladen(teile, add)
        alu = MATERIALIEN[:alu][0]
        lg = LEGRABOX
        # Korpusschienen: je Seite und Schublade an den Schienenbohrungen (fest im Schrank)
        teile.select { |w| w.rolle == 'Seite' }.each do |s|
          s.ops.select { |o| o.titel.to_s.start_with?('Schiene ') && o.daten }.group_by(&:titel).each do |titel, ops|
            k = Geometrie.achse(ops[0].seite)
            innen = Geometrie.max?(ops[0].seite) ? 1 : -1
            t = ([0, 1] - [k]).first
            fl = ops[0].p0[k]
            z = ops[0].p0[2]
            nl = ops[0].daten[:nl].to_f
            ys = ops.map { |o| o.p0[t] }
            # vorn = Seite der beiden vorderen Löcher (37/69); Schiene 4 mm hinter der Vorderkante
            vorn_min = (ys.min - s.lo[t]) <= (s.hi[t] - ys.max)
            y0 = vorn_min ? ys.min - (Regeln::SCHIENE[:vorn][0] - 4) : ys.max + (Regeln::SCHIENE[:vorn][0] - 4)
            y1 = y0 + (vorn_min ? 1 : -1) * (nl - 10)
            add.(s, quader("Korpusschiene NL #{nl.round} #{titel.sub('Schiene ', '')}", alu,
                           p3(k => fl, t => y0, 2 => z - lg[:schiene_h] / 2.0),
                           p3(k => fl + innen * lg[:schiene], t => y1, 2 => z + lg[:schiene_h] / 2.0)))
          end
        end

        Regeln.kaesten(teile).each do |kasten|
          boden = kasten.find { |w| w.rolle == 'KastenBoden' } or next
          rw = kasten.find { |w| w.rolle == 'KastenRueckwand' }
          m = Regeln.zarge(kasten)
          zh = Regeln::ZARGEN[m][:hoehe]
          wa = Regeln.breite_achse(kasten)
          ta = (boden.flaechen_achsen - [wa]).first
          next unless ta
          unten = kasten.map { |w| w.lo[2] }.min
          seiten = teile.select { |w| w.rolle == 'Seite' && w.dicke_achse == wa }
          links = seiten.map { |s| s.hi[wa] }.select { |v| v <= boden.lo[wa] + Regeln::TOL }.max || boden.lo[wa] - 17.5
          rechts = seiten.map { |s| s.lo[wa] }.select { |v| v >= boden.hi[wa] - Regeln::TOL }.min || boden.hi[wa] + 17.5
          f = Regeln.front_zu(kasten, teile)
          # vorn: Seite des Bodens zur Front (ohne Front: zur Rückwand gegenüber)
          vorn_min = if f then mitte(f, ta) < mitte(boden, ta)
                     elsif rw then mitte(rw, ta) > mitte(boden, ta)
                     else true
                     end
          vorn = vorn_min ? boden.lo[ta] : boden.hi[ta]
          dir = vorn_min ? 1 : -1
          nl = boden.mass(ta) + 10.0 # Boden NL − 10
          bez = boden.teil.jt('bereich')
          [[links, 1, 'links'], [rechts, -1, 'rechts']].each do |aussen, innen, lr|
            x0 = aussen + innen * lg[:schiene]
            x1 = x0 + innen * lg[:zarge]
            add.(boden, quader("Zarge #{m} #{lr} #{bez}", alu, p3(wa => x0, ta => vorn, 2 => unten),
                               p3(wa => x1, ta => vorn + dir * (nl - 1), 2 => unten + zh)))
            # Rückwandhalter: zwischen Zarge und Holzrückwand, auf deren Höhe
            next unless rw
            add.(boden, quader("Rückwandhalter #{m} #{lr} #{bez}", alu,
                               p3(wa => x1, ta => rw.lo[ta] - 5, 2 => rw.lo[2] + 5),
                               p3(wa => x1 + innen * lg[:rueckwandhalter], ta => rw.hi[ta] + 5, 2 => rw.hi[2] - 5)))
          end
          # Fronthalter: an den Löchern der Frontbefestigung, hinter der Front vor der Zarge
          next unless f
          fb = f.ops.select { |o| o.titel == 'Frontbefestigung' }
          next if fb.empty?
          da = f.dicke_achse
          hinten = Geometrie.max?(fb[0].seite) ? 1 : -1
          fl = fb[0].p0[da]
          zs = fb.map { |o| o.p0[2] }
          [[links, 1, 'links'], [rechts, -1, 'rechts']].each do |aussen, innen, lr|
            x0 = aussen + innen * lg[:schiene]
            add.(f, quader("Fronthalter #{m} #{lr} #{bez}", alu, p3(wa => x0, da => fl, 2 => zs.min - 10),
                           p3(wa => x0 + innen * lg[:zarge], da => fl + hinten * lg[:fronthalter], 2 => zs.max + 10)))
          end
        end
      end

      def topfbaender(teile, add)
        stahl = MATERIALIEN[:stahl][0]
        tb = TOPFBAND
        r = Regeln::TOPFBAND[:d] / 2.0
        teile.select { |w| w.rolle == 'Tuer' }.each do |t|
          t.ops.select { |o| o.art == :topfband }.each_with_index do |o, i|
            da = Geometrie.achse(o.seite)
            rein = Geometrie.max?(o.seite) ? 1 : -1 # aus der Innenseite der Tür zum Korpus
            tfl = o.p0[da]
            kante = o.daten && o.daten[:kante]
            wa = kante ? Geometrie.achse(kante) : (t.flaechen_achsen - [2]).first
            z = o.p0[2]
            n = i + 1
            # Topf in der Tür selbst (dreht sich mit, egal ob Tür oder Türhalter animiert ist);
            # ganz innerhalb der Türstärke, damit die Maße der Tür (TCN, Stückliste) gleich bleiben
            add.(t, zylinder("Topfband #{n} Topf", stahl, o.p0, da, tfl - rein * tb[:topf_tiefe], tfl, r), true)
            s = kante && Regeln.seite_am_anschlag(t, kante, teile)
            next unless s # Falttür am Eckscharnier: nur der Topf
            max = Geometrie.max?(kante)
            _, sfl = Regeln.flaeche_innen(s, wa, !max)
            innen = max ? -1 : 1 # von der Innenseite der Seite in den Korpus
            y = rein > 0 ? s.lo_f(da) + Regeln::LOCHREIHE[:rand] : s.hi_f(da) - Regeln::LOCHREIHE[:rand]
            vorne = rein > 0 ? s.lo[da] : s.hi[da] # Vorderkante der Seite
            pl = tb[:platte]
            # Montageplatte und Arm fest an der Seite (wie beim echten Band bleibt der Arm auf der
            # Platte, nur der Topf geht mit der Tür auf)
            add.(s, quader("Montageplatte #{n}", stahl, p3(wa => sfl, da => y - pl[1] / 2.0, 2 => z - pl[0] / 2.0),
                           p3(wa => sfl + innen * pl[2], da => y + pl[1] / 2.0, 2 => z + pl[0] / 2.0)))
            add.(s, quader("Topfband #{n} Arm", stahl,
                           p3(wa => sfl + innen * pl[2], da => vorne, 2 => z - tb[:arm_h] / 2.0),
                           p3(wa => sfl + innen * (pl[2] + tb[:arm_b]), da => y + rein * tb[:arm_ueber], 2 => z + tb[:arm_h] / 2.0)))
          end
        end
      end

      def aventos(teile, add)
        kst = MATERIALIEN[:kunststoff][0]
        stahl = MATERIALIEN[:stahl][0]
        av = AVENTOS
        teile.select { |w| w.rolle == 'Seite' }.each do |s|
          ops = s.ops.select { |o| o.titel == 'Kraftspeicher AVENTOS HK-top' }
          next if ops.empty?
          k = Geometrie.achse(ops[0].seite)
          innen = Geometrie.max?(ops[0].seite) ? 1 : -1
          t = ([0, 1] - [k]).first
          ys = ops.map { |o| o.p0[t] }
          vorn_min = (ys.min - s.lo[t]) <= (s.hi[t] - ys.max)
          y0, y1 = vorn_min ? [ys.min - av[:vor], ys.max + av[:hinter]] : [ys.max + av[:vor], ys.min - av[:hinter]]
          z = ops[0].p0[2]
          add.(s, quader('Kraftspeicher AVENTOS HK-top', kst, p3(k => ops[0].p0[k], t => y0, 2 => z - av[:unter]),
                         p3(k => ops[0].p0[k] + innen * av[:dicke], t => y1, 2 => z + av[:ueber])))
          # Hebelarm (Stange) vom Kraftspeicher zum Frontbeschlag dieser Seite, fest im Schrank
          # (Lage bei geschlossener Klappe)
          fb = teile.flat_map(&:ops).select { |o| o.titel == 'Frontbeschlag AVENTOS HK-top' }
          next if fb.empty?
          naechst = fb.min_by { |o| (o.p0[k] - ops[0].p0[k]).abs }
          paar = fb.select { |o| (o.p0[k] - naechst.p0[k]).abs < 0.5 }
          xm = naechst.p0[k]
          start = p3(k => xm, t => y0 + (vorn_min ? 1 : -1) * av[:arm_ein], 2 => z - av[:unter] / 2.0)
          ende = p3(k => xm, t => naechst.p0[t] + (vorn_min ? 1 : -1) * av[:front][1] / 2.0, 2 => paar.sum { |o| o.p0[2] } / paar.size)
          add.(s, Koerper.new('Hebelarm AVENTOS HK-top', stahl, :stab, start, ende, k, av[:arm] / 2.0))
        end
        teile.select { |w| w.ops.any? { |o| o.titel == 'Frontbeschlag AVENTOS HK-top' } }.each do |kl|
          ops = kl.ops.select { |o| o.titel == 'Frontbeschlag AVENTOS HK-top' }
          da = Geometrie.achse(ops[0].seite)
          rein = Geometrie.max?(ops[0].seite) ? 1 : -1
          wa = (kl.flaechen_achsen - [2]).first
          fl = ops[0].p0[da]
          ops.group_by { |o| o.p0[wa].round(1) }.each_value do |paar|
            x = paar[0].p0[wa]
            zs = paar.map { |o| o.p0[2] }
            add.(kl, quader('Frontbeschlag AVENTOS HK-top', stahl, p3(wa => x - av[:front][0] / 2.0, da => fl, 2 => zs.min - 10),
                            p3(wa => x + av[:front][0] / 2.0, da => fl + rein * av[:front][1], 2 => zs.max + 10)))
          end
        end
      end

      # ---------------------------------------------------------------------
      # Umrechnung Welt (mm) -> Behälter (Zoll)
      # ---------------------------------------------------------------------
      # Inverse einer affinen 4x4-Matrix in Spaltenform (Drehung, Spiegelung, Skalierung, Verschiebung)
      def invers(m)
        a = [[m[0], m[4], m[8]], [m[1], m[5], m[9]], [m[2], m[6], m[10]]]
        det = a[0][0] * (a[1][1] * a[2][2] - a[1][2] * a[2][1]) - a[0][1] * (a[1][0] * a[2][2] - a[1][2] * a[2][0]) +
              a[0][2] * (a[1][0] * a[2][1] - a[1][1] * a[2][0])
        raise ArgumentError, 'Transformation nicht umkehrbar' if det.abs < 1e-12
        inv = [
          [a[1][1] * a[2][2] - a[1][2] * a[2][1], a[0][2] * a[2][1] - a[0][1] * a[2][2], a[0][1] * a[1][2] - a[0][2] * a[1][1]],
          [a[1][2] * a[2][0] - a[1][0] * a[2][2], a[0][0] * a[2][2] - a[0][2] * a[2][0], a[0][2] * a[1][0] - a[0][0] * a[1][2]],
          [a[1][0] * a[2][1] - a[1][1] * a[2][0], a[0][1] * a[2][0] - a[0][0] * a[2][1], a[0][0] * a[1][1] - a[0][1] * a[1][0]]
        ].map { |z| z.map { |v| v / det } }
        t = [m[12], m[13], m[14]]
        ti = (0..2).map { |r| -(0..2).sum { |c| inv[r][c] * t[c] } }
        [inv[0][0], inv[1][0], inv[2][0], 0.0, inv[0][1], inv[1][1], inv[2][1], 0.0,
         inv[0][2], inv[1][2], inv[2][2], 0.0, ti[0], ti[1], ti[2], 1.0]
      end

      # Flächen (Punktlisten, Zoll, im Behälter) eines Körpers
      def flaechen(k, inv)
        lokal = ->(p) { Geometrie.punkt(inv, p.map { |v| v / Geometrie::MM }).map { |v| v.round(5) } }
        if k.form == :stab
          q = k.achse
          d = (0..2).map { |i| k.b[i] - k.a[i] }
          d[q] = 0.0
          l = Math.sqrt(d.sum { |v| v * v })
          # senkrecht zur Stange in ihrer Ebene (quer zur Achse q)
          n = [0.0, 0.0, 0.0]
          i1, i2 = ([0, 1, 2] - [q])
          n[i1], n[i2] = -d[i2] / l, d[i1] / l
          e = [k.a, k.b].flat_map do |p|
            [[-1, -1], [-1, 1], [1, -1], [1, 1]].map do |sq, sn|
              pt = p.dup
              pt[q] += sq * k.r
              (0..2).each { |i| pt[i] += sn * k.r * n[i] }
              pt
            end
          end.map(&lokal)
          # Ecke a: 0..3, b: 4..7 (je Querrichtung -, -/+ …)
          [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]].map { |f| f.map { |i| e[i] } }
        elsif k.form == :quader
          e = [0, 1].product([0, 1], [0, 1]).map { |i, j, l| [[k.a, k.b][i][0], [k.a, k.b][j][1], [k.a, k.b][l][2]] }
          e = e.map(&lokal)
          # Ecken-Index i*4 + j*2 + l (x, y, z)
          [[0, 2, 6, 4], [1, 5, 7, 3], [0, 4, 5, 1], [2, 3, 7, 6], [0, 1, 3, 2], [4, 6, 7, 5]].map { |f| f.map { |i| e[i] } }
        else
          n = 16
          q = ([0, 1, 2] - [k.achse])
          ring = lambda do |h|
            (0...n).map do |i|
              w = 2 * Math::PI * i / n
              p = k.a.dup
              p[k.achse] = h
              p[q[0]] += k.r * Math.cos(w)
              p[q[1]] += k.r * Math.sin(w)
              lokal.(p)
            end
          end
          u = ring.(k.a[k.achse])
          o = ring.(k.b)
          [u, o.reverse] + (0...n).map { |i| [u[i], u[(i + 1) % n], o[(i + 1) % n], o[i]] }
        end
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

      # Alle Beschlag-Gruppen im Modell (auch in Schubladen, Türhaltern …)
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

      def schraenke(model)
        Schraenke.instanzen(model.entities).select { |i| Schraenke.definition(i).get_attribute(JT_DICT, 'schrank') }
      end

      # Fingerabdruck eines Schranks: DC-Attribute (Instanz und Definition) und Definition.
      # Ändern sich Maße oder Optionen, ändert er sich; Verschieben und Öffnen (Interagieren) nicht.
      def fingerabdruck(s)
        d = Schraenke.definition(s)
        werte = [s, d].map do |e|
          dict = e.attribute_dictionary(DC_DICT)
          next '' unless dict
          dict.to_a.reject { |k, _| k.to_s.start_with?('_') }.map { |k, v| "#{k}=#{v.is_a?(Float) ? v.round(4) : v}" }.sort.join(';')
        end
        "v#{VERSION}|#{d.object_id}|#{d.respond_to?(:name) ? d.name : ''}|#{werte.join('|')}"
      end

      # Werkstücke eines Schranks mit Bearbeitungen (wie im TCN-Export)
      def werkstuecke(model, s)
        teile = Schraenke.teile(model, Schraenke.definition(s).entities, [s], s)
        ws = teile.select { |t| t.sichtbar? && t.rolle != 'Arbeitsplatte' }.map { |t| Geometrie.werkstueck(t) }
        Regeln.anwenden(ws)
        ws
      end

      # Soll-Gruppen eines Schranks: { Behälter-Definition => [[Pfad, [Körper]], …] }
      # (mehrere Pfade, wenn sich Teile eine Definition teilen, z. B. zwei gleiche Türen)
      def soll(model, s, ws = werkstuecke(model, s))
        out = {}
        koerper(ws).each do |pfad, liste|
          next if liste.empty?
          (out[Schraenke.definition(pfad.last)] ||= []) << [pfad, liste]
        end
        out
      end

      # Körper als Flächenlisten im Behälter, dazu eine Signatur zum Vergleich
      def lokal(pfad, liste)
        inv = invers(Geometrie.welt(pfad))
        fl = liste.map { |k| [k, flaechen(k, inv)] }
        sig = fl.map { |k, f| "#{k.name}/#{k.mat}:#{f.flatten.map { |v| v.round(3) }.join(',')}" }.join('|')
        [fl, sig]
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
          kg.material = material(model, MATERIALIEN.values.find { |n, _| n == k.mat })
          flaechen.each do |pts|
            kg.entities.add_face(*pts.map { |p| Geom::Point3d.new(*p) })
          rescue ArgumentError
            next # entartete Fläche (z. B. sehr flacher Körper nach Skalierung)
          end
        end
        g
      end

      # Türen und Klappen geschlossen? Offen (Interagieren) stimmen die Bohrbilder nicht
      # (die Tür steht schräg oder quer), dann bleiben die Beschläge, wie sie sind.
      def geschlossen?(ws)
        seiten = ws.select { |w| w.rolle == 'Seite' && w.dicke_achse != 2 }
        return true if seiten.empty?
        tiefe = 1 - seiten.first.dicke_achse
        ws.select { |w| w.rolle == 'Tuer' || w.teil.jt('teil').to_s.start_with?('Klappe') }.all? do |w|
          w.dicke_achse == tiefe && w.mass(tiefe) < 40
        end
      end

      # Beschläge eines Schranks auf Stand bringen; liefert die Anzahl der Körper
      # (nil, wenn eine Tür oder Klappe offen steht: dann bleibt alles, wie es ist)
      def schrank_aktualisieren(model, s)
        anzahl = 0
        behaelter = {}
        ws = werkstuecke(model, s)
        return nil unless geschlossen?(ws)
        soll(model, s, ws).each do |d, eintraege|
          lok = eintraege.map { |pfad, liste| lokal(pfad, liste) }
          # geteilte Definition, aber verschiedene Lage (z. B. Tür links/rechts in einer Definition):
          # dort keine Beschläge, sonst säßen sie bei einer der Türen falsch
          next unless lok.map(&:last).uniq.size == 1
          fl, sig = lok.first
          behaelter[d] = true
          anzahl += eintraege.first.last.size
          alt = gruppen_in(d.entities)
          next if alt.size == 1 && alt[0].get_attribute(DICT, 'signatur') == sig
          d.entities.erase_entities(alt) unless alt.empty?
          zeichnen(model, d.entities, fl, sig)
        end
        # Beschläge in Behältern, die keine mehr haben sollen (z. B. Schublade ausgeblendet)
        alle_gruppen(Schraenke.definition(s).entities).each do |g|
          d = g.parent
          g.erase! unless behaelter[d]
        end
        s.set_attribute(DICT, 'fingerabdruck', fingerabdruck(s))
        anzahl
      end

      # Alle Schränke; alle: auch unveränderte (Fingerabdruck gleich)
      def aktualisieren(model, alle: true)
        schraenke(model).sum do |s|
          next 0 unless alle || s.get_attribute(DICT, 'fingerabdruck') != fingerabdruck(s)
          schrank_aktualisieren(model, s).to_i
        end
      end

      def entfernen(model)
        g = alle_gruppen(model.entities)
        g.each(&:erase!)
        schraenke(model).each { |s| s.delete_attribute(DICT, 'fingerabdruck') }
        g.size
      end

      def setzen(model, an)
        model.start_operation(an ? 'Beschläge zeigen' : 'Beschläge ausblenden', true)
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
        UI.messagebox('Keine Beschläge gefunden (keine Schubladen, Türen oder Klappen im Modell).') if an && n.to_i.zero?
        an
      end

      # Nach jedem Vorgang: Schränke mit geändertem Fingerabdruck neu bestücken (transparent,
      # hängt am Vorgang davor, Rückgängig nimmt beides)
      def nachziehen(model)
        return unless model && model.valid? && an?(model)
        offen = schraenke(model).select { |s| s.get_attribute(DICT, 'fingerabdruck') != fingerabdruck(s) }
        return if offen.empty?
        model.start_operation('Beschläge', true, false, true)
        offen.each { |s| schrank_aktualisieren(model, s) }
        model.commit_operation
      rescue StandardError => e
        model.abort_operation if model
        puts "Beschläge: #{e.message}"
      end

      if defined?(Sketchup::ModelObserver)
        # verzögert, weil das Modell im Beobachter nicht geändert werden soll
        class Beobachter < Sketchup::ModelObserver
          def onTransactionCommit(model)
            return if @laeuft || !Beschlagmodell.an?(model)
            @laeuft = true
            id = UI.start_timer(0, false) do
              UI.stop_timer(id)
              begin
                Beschlagmodell.nachziehen(model)
              ensure
                @laeuft = false
              end
            end
          end
        end

        class AppBeobachter < Sketchup::AppObserver
          def onNewModel(model)
            Beschlagmodell.beobachten(model)
          end

          def onOpenModel(model)
            Beschlagmodell.beobachten(model)
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
