# encoding: UTF-8
# Schrank-CNC – Beschläge im SketchUp-Modell zeigen (Jürgen, 2026-11-06: „komplette Schublade incl.
# der Teile, die nicht gefertigt werden, auch Topfbänder und alle anderen Beschläge“).
#
# Die Beschläge werden aus denselben Bohrbildern berechnet wie TCN-Export und Beschlagliste
# (Regeln.anwenden), passen also immer zu den Bohrungen:
#   Schubladen  Blum LEGRABOX free: Zargen C oder M (Regeln.zarge) links und rechts, Korpusschienen an den
#               Schienenbohrungen, Fronthalter an der Frontbefestigung, Rückwandhalter an der Holzrückwand.
#   Türen       Blum-Topfband: Topf Ø35 in der Tür, Arm zur Seite, Montageplatte an der Seite.
#   Klappen     gewähltes Modell aus dem Beschlag-Katalog (AVENTOS HK-top, Free Slim): Kraftspeicher bzw.
#               Mechanismus an beiden Seiten, Arm zum Frontbeschlag an der Klappe.
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
      VERSION = 5
      # Materialnamen: Rendern erkennt „Alu“/„Stahl“ als Metall
      MATERIALIEN = {
        alu: ['Beschlag Alu grau', [150, 152, 156]],
        stahl: ['Beschlag Stahl vernickelt', [196, 198, 202]],
        kunststoff: ['Beschlag Kunststoff grau', [110, 112, 116]],
        glas: ['Beschlag Glas klar', [205, 225, 230], 0.35],
        chrom: ['Beschlag Chrom', [215, 218, 222]]
      }.freeze
      # LeMans II (vereinfacht): Säule Ø30, Tablar 6 mm Boden mit 50 mm Rand (Ecken R120) im Einbauraum
      # von der Seite bis 40 mm hinter das Säulenlager, Tiefe bis 490; Seitenprofil 30 × 10.
      LEMANS = { saeule_r: 15.0, tablar: 6.0, rand_h: 50.0, rand_d: 3.0, radius: 120.0, ueber_saeule: 40.0,
                 tiefe_max: 490.0, abstand: 10.0, profil: [30.0, 10.0] }.freeze
      # Häfele HU Slim Base (vereinfacht): 2 Schienen 12 × 30 an der Seite (Bauraumtiefe − 30 lang),
      # Gestell mit 2 Körben (80 hoch) auf Höhe der Fronthalter, Fronthalter 20 × 40 × 10.
      HU = { schiene: [12.0, 30.0], korb_h: 80.0, korb_d: 3.0, halter: [20.0, 40.0, 10.0], gestell: 10.0 }.freeze
      # LEGRABOX-Zarge mit Seiteneinsatz: Einsatz 10 mm (Glas) im Fenster NL − 112 lang, Obergurt 8 mm
      ZARGE_FENSTER = { obergurt: 8.0, einsatz: 10.0 }.freeze

      # LEGRABOX free (vereinfacht): Zarge 12,8 mm stark, Korpusschiene 4 mm an der Seite,
      # Zarge davor; Schiene 4 mm hinter der Vorderkante der Seite, NL − 10 lang.
      LEGRABOX = { schiene: 4.0, schiene_h: 20.0, zarge: 12.8, fronthalter: 12.0, rueckwandhalter: 2.2 }.freeze
      # Blum-Topfband (vereinfacht): Topf Ø35 × 13 in der Tür, Arm 16 hoch, 16 breit, endet 25 mm
      # hinter den Löchern der Montageplatte; Montageplatte 48 × 20 × 4.
      TOPFBAND = { topf_tiefe: 13.0, arm_h: 16.0, arm_b: 16.0, arm_ueber: 25.0,
                   platte: [48.0, 20.0, 4.0] }.freeze
      # Klappen: Körper aus dem Beschlag-Katalog (koerper.seite/arm/front, siehe klappen)

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
        klappen(teile, add)
        lemans(teile, add)
        hu_slim_base(teile, add)
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
            zarge(boden, add, "Zarge #{m} #{lr} #{bez}", m, wa, ta, x0, x1, vorn, dir, nl, unten, zh)
            # Rückwandhalter: zwischen Zarge und Holzrückwand, auf deren Höhe
            next unless rw
            add.(boden, quader("Rückwandhalter #{m} #{lr} #{bez}", alu,
                               p3(wa => x1, ta => rw.lo[ta] - 5, 2 => rw.lo[2] + 5),
                               p3(wa => x1 + innen * lg[:rueckwandhalter], ta => rw.hi[ta] + 5, 2 => rw.hi[2] - 5)))
          end
          # Seitenstabilisierung (ab Korpusbreite 600, wie die Beschlagliste): Stange quer zwischen den
          # Zargen oben vor der Holzrückwand
          kb = rechts - links + 2 * (seiten.first ? seiten.first.mass(wa) : 19.0)
          if rw && kb >= Beschlaege::KB_STABILISIERUNG - Regeln::TOL
            yr = (vorn_min ? rw.lo[ta] : rw.hi[ta]) - dir * 15
            add.(boden, quader("Seitenstabilisierung #{bez}", alu,
                               p3(wa => links + lg[:schiene] + lg[:zarge], ta => yr - 4, 2 => unten + zh - 20),
                               p3(wa => rechts - lg[:schiene] - lg[:zarge], ta => yr + 4, 2 => unten + zh - 12)))
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

      # Zarge: mit Seiteneinsatz (Zargenhöhe mit einsatz) als Rahmen mit Glas im Fenster NL − 112,
      # sonst (N) voll
      def zarge(boden, add, name, m, wa, ta, x0, x1, vorn, dir, nl, unten, zh)
        alu = MATERIALIEN[:alu][0]
        ein = Regeln::ZARGEN[m][:einsatz]
        y1 = vorn + dir * (nl - 1)
        unless ein && ein < zh
          add.(boden, quader(name, alu, p3(wa => x0, ta => vorn, 2 => unten), p3(wa => x1, ta => y1, 2 => unten + zh)))
          return
        end
        zf = ZARGE_FENSTER
        oben = unten + zh
        f_oben = oben - zf[:obergurt]
        f_unten = f_oben - ein
        rand = ((nl - 1) - (nl - 112)) / 2.0
        fv = vorn + dir * rand
        fh = y1 - dir * rand
        rahmen = [quader(name, alu, p3(wa => x0, ta => vorn, 2 => unten), p3(wa => x1, ta => y1, 2 => f_unten)),
                  quader(name, alu, p3(wa => x0, ta => vorn, 2 => f_oben), p3(wa => x1, ta => y1, 2 => oben)),
                  quader(name, alu, p3(wa => x0, ta => vorn, 2 => f_unten), p3(wa => x1, ta => fv, 2 => f_oben)),
                  quader(name, alu, p3(wa => x0, ta => fh, 2 => f_unten), p3(wa => x1, ta => y1, 2 => f_oben))]
        add.(boden, Koerper.new(name, alu, :mehrere, rahmen.compact))
        xm = (x0 + x1) / 2.0
        add.(boden, quader("Seiteneinsatz #{name.sub('Zarge ', '')}", MATERIALIEN[:glas][0],
                           p3(wa => xm - zf[:einsatz] / 2.0, ta => fv, 2 => f_unten), p3(wa => xm + zf[:einsatz] / 2.0, ta => fh, 2 => f_oben)))
      end

      # Wanne (Korb, Tablar): Boden und Rand als Prismen über einem Umriss (Punkte in der xy-Ebene)
      def wanne(name, mat, umriss, z, boden_d, rand_h, rand_d)
        out = [Koerper.new("#{name} Boden", mat, :prisma, umriss.map { |x, y| [x, y, z] }, z + boden_d)]
        innen = versetzt(umriss, rand_d)
        n = umriss.size
        n.times do |i|
          j = (i + 1) % n
          ring = [umriss[i], umriss[j], innen[j], innen[i]].map { |x, y| [x, y, z] }
          out << Koerper.new("#{name} Rand", mat, :prisma, ring, z + rand_h)
        end
        out
      end

      # Umriss nach innen versetzt (konvex, gegen oder im Uhrzeigersinn): Punkt zum Schwerpunkt hin
      def versetzt(pts, d)
        cx = pts.sum { |x, _| x } / pts.size
        cy = pts.sum { |_, y| y } / pts.size
        pts.map do |x, y|
          l = Math.hypot(cx - x, cy - y)
          l < d ? [x, y] : [x + (cx - x) * d / l, y + (cy - y) * d / l]
        end
      end

      # Rechteck mit runden Ecken (Radius r, je Ecke 4 Segmente) in den Achsen a (x) und b (y)
      def rund_rechteck(a0, a1, b0, b1, r)
        r = [r, (a1 - a0) / 2.0, (b1 - b0) / 2.0].min
        ecken = [[a1 - r, b1 - r, 0], [a0 + r, b1 - r, 90], [a0 + r, b0 + r, 180], [a1 - r, b0 + r, 270]]
        ecken.flat_map do |cx, cy, w0|
          (0..4).map { |i| w = (w0 + i * 22.5) * Math::PI / 180; [cx + r * Math.cos(w), cy + r * Math.sin(w)] }
        end
      end

      # Kesseböhmer LeMans II (Eckschrank Variante Le Mans): Säule zwischen den Lagern, Seitenprofil,
      # 2 Tablare im Einbauraum von der Seite an der Tür bis hinter die Säule
      def lemans(teile, add)
        return if teile.empty? || !Regeln.lemans?(teile)
        lg = Regeln::LEMANS
        le = LEMANS
        chrom = MATERIALIEN[:chrom][0]
        s = teile.find { |w| w.ops.any? { |o| o.titel == 'Profil LeMans' } } or return
        boden = teile.find { |w| w.rolle == 'Boden' } or return
        lager = boden.ops.find { |o| o.titel == 'Lager LeMans' } or return
        strebe = teile.find { |w| w.teil.jt('teil') == 'StrebeVorn' }
        profil = s.ops.select { |o| o.titel == 'Profil LeMans' }
        k = Geometrie.achse(profil[0].seite)
        innen = Geometrie.max?(profil[0].seite) ? 1 : -1
        t = ([0, 1] - [k]).first
        fl = profil[0].p0[k]
        sx = lager.p0[k]
        sy = lager.p0[t]
        yp = profil[0].p0[t]
        dir = (sy - yp) / (lg[:lager][:vorn] - lg[:profil][:vorn]) > 0 ? 1 : -1
        vorne = yp - dir * lg[:profil][:vorn]
        oben = strebe ? strebe.lo[2] : s.hi[2] - 19
        unten = boden.hi[2]
        zs = profil.map { |o| o.p0[2] }
        add.(s, quader('Seitenprofil LeMans', chrom, p3(k => fl, t => yp - le[:profil][0] / 2.0, 2 => zs.min - 20),
                       p3(k => fl + innen * le[:profil][1], t => yp + le[:profil][0] / 2.0, 2 => zs.max + 20)))
        add.(s, zylinder('Säule LeMans', chrom, p3(k => sx, t => sy, 2 => unten), 2, unten, oben, le[:saeule_r]))
        # Tablare: in k von der Seite (+ Abstand) bis hinter die Säule, in t ab vorne bis Tiefe max
        rw = teile.select { |w| w.rolle == 'Rueckwand' }.map { |w| dir > 0 ? w.lo[t] : w.hi[t] }
        hinten = rw.min_by { |v| (v - vorne).abs } || (dir > 0 ? s.hi[t] : s.lo[t])
        tiefe = [(hinten - vorne).abs - 2 * le[:abstand], le[:tiefe_max]].min
        a0, a1 = [fl + innen * le[:abstand], sx + innen * le[:ueber_saeule]].minmax
        b0, b1 = [vorne + dir * le[:abstand], vorne + dir * (le[:abstand] + tiefe)].minmax
        umriss = rund_rechteck(a0, a1, b0, b1, le[:radius]).map { |u, v| k.zero? ? [u, v] : [v, u] }
        h = oben - unten
        [unten + 100, unten + h / 2.0 + 60].each_with_index do |z, i|
          wanne("Tablar LeMans #{i + 1}", MATERIALIEN[:kunststoff][0], umriss, z, le[:tablar], le[:rand_h], le[:rand_d]).each { |kp| add.(s, kp) }
        end
      end

      # Häfele HU Slim Base (Unterschrank Handtuchauszug): Schienen an der Seite, Gestell mit 2 Körben
      # und Fronthaltern im Auszug (fährt mit der Front heraus)
      def hu_slim_base(teile, add)
        return if teile.empty? || !Regeln.hu_slim_base?(teile)
        hu = HU
        stahl = MATERIALIEN[:stahl][0]
        s = teile.find { |w| w.ops.any? { |o| o.titel == 'Schiene HU Slim Base' } } or return
        boden = teile.find { |w| w.rolle == 'Boden' } or return
        sch = s.ops.select { |o| o.titel == 'Schiene HU Slim Base' }
        k = Geometrie.achse(sch[0].seite)
        innen = Geometrie.max?(sch[0].seite) ? 1 : -1
        t = ([0, 1] - [k]).first
        fl = sch[0].p0[k]
        ys = sch.map { |o| o.p0[t] }
        c = Regeln::HU_SLIM_BASE
        dir = (s.hi[t] - ys.max) > (ys.min - s.lo[t]) ? 1 : -1
        vorne = dir > 0 ? ys.min - c[:schiene][:vorn][0] : ys.max + c[:schiene][:vorn][0]
        laenge = c[:bauraum][:tiefe] - 30
        sch.map { |o| o.p0[2] }.uniq.each_with_index do |z, i|
          add.(s, quader("Schiene HU Slim Base #{i + 1}", stahl, p3(k => fl, t => vorne + dir * 10, 2 => z - hu[:schiene][1] / 2.0),
                         p3(k => fl + innen * hu[:schiene][0], t => vorne + dir * (10 + laenge), 2 => z + hu[:schiene][1] / 2.0)))
        end
        f = teile.find { |w| w.ops.any? { |o| o.titel == 'Front HU Slim Base' } } or return
        fo = f.ops.select { |o| o.titel == 'Front HU Slim Base' }
        da = Geometrie.achse(fo[0].seite)
        rein = Geometrie.max?(fo[0].seite) ? 1 : -1
        ff = fo[0].p0[da]
        hl = hu[:halter]
        fo.each_with_index do |o, i|
          add.(f, quader("Fronthalter HU Slim Base #{i + 1}", stahl,
                         p3(k => o.p0[k] - hl[0] / 2.0, da => ff, 2 => o.p0[2] - hl[1] / 2.0),
                         p3(k => o.p0[k] + hl[0] / 2.0, da => ff + rein * hl[2], 2 => o.p0[2] + hl[1] / 2.0)))
        end
        # Gestell und Körbe zwischen Schiene und anderer Seite, ab Fronthalter bis Bauraumtiefe
        x0 = fl + innen * hu[:schiene][0]
        xs = fo.map { |o| o.p0[k] }
        x1 = (innen > 0 ? xs.max + hl[0] / 2.0 : xs.min - hl[0] / 2.0)
        a0, a1 = [x0, x1].minmax
        b0, b1 = [ff + rein * hl[2], ff + rein * (hl[2] + laenge - 20)].minmax
        zs = fo.map { |o| o.p0[2] }.uniq.sort
        add.(f, quader('Gestell HU Slim Base hinten', stahl, p3(k => a0, t => (rein > 0 ? b1 - hu[:gestell] : b0), 2 => zs.first - 60),
                       p3(k => a0 + hu[:gestell], t => (rein > 0 ? b1 : b0 + hu[:gestell]), 2 => zs.last + hu[:korb_h])))
        zs.each_with_index do |z, i|
          rechteck = [[a0, b0], [a1, b0], [a1, b1], [a0, b1]].map { |u, v| k.zero? ? [u, v] : [v, u] }
          wanne("Korb HU Slim Base #{i + 1}", MATERIALIEN[:chrom][0], rechteck, z - 30, hu[:korb_d], hu[:korb_h], hu[:korb_d]).each { |kp| add.(f, kp) }
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

      # Klappenbeschlag der Bauart klappe_seite (Katalog, koerper):
      #   seite  Kraftspeicher/Mechanismus an der Seite: dicke, vor/hinter = über das vorderste/hinterste
      #          Loch hinaus, unter/ueber = unter das unterste / über das oberste Loch hinaus
      #   arm    Stab vom Körper an der Seite (ein = hinter seiner Vorderkante, hoehe = über seiner
      #          Unterkante) zur Mitte des Frontbeschlags dieser Seite, fest im Schrank (geschlossene Klappe)
      #   front  Frontbeschlag an der Klappe: breite, dicke, ueber = über das oberste/unterste Loch hinaus
      def klappen(teile, add)
        katalog = Beschlagkatalog.eintraege.select { |e| e['bauart'] == 'klappe_seite' && e['koerper'] }
        ops_alle = teile.flat_map(&:ops)
        katalog.each do |e|
          kp = e['koerper']
          ks, ka, kf = kp['seite'], kp['arm'], kp['front']
          mat = ->(k) { MATERIALIEN.fetch(k['material'].to_sym)[0] }
          fb = ops_alle.select { |o| o.titel == e['front']['titel'] }
          teile.select { |w| w.rolle == 'Seite' }.each do |s|
            ops = s.ops.select { |o| o.titel == e['seite']['titel'] }
            next if ops.empty?
            k = Geometrie.achse(ops[0].seite)
            innen = Geometrie.max?(ops[0].seite) ? 1 : -1
            t = ([0, 1] - [k]).first
            ys = ops.map { |o| o.p0[t] }
            zs = ops.map { |o| o.p0[2] }
            vorn_min = (ys.min - s.lo[t]) <= (s.hi[t] - ys.max)
            dir = vorn_min ? 1 : -1
            y0, y1 = vorn_min ? [ys.min - ks['vor'], ys.max + ks['hinter']] : [ys.max + ks['vor'], ys.min - ks['hinter']]
            fl = ops[0].p0[k]
            unten = zs.min - ks['unter']
            add.(s, quader(ks['titel'], mat.(ks), p3(k => fl, t => y0, 2 => unten),
                           p3(k => fl + innen * ks['dicke'], t => y1, 2 => zs.max + ks['ueber'])))
            next if fb.empty? || ka.nil?
            naechst = fb.min_by { |o| (o.p0[k] - fl).abs }
            reihe = fb.select { |o| (o.p0[k] - naechst.p0[k]).abs < 0.5 }
            xm = naechst.p0[k]
            start = p3(k => xm, t => y0 + dir * ka['ein'], 2 => unten + ka['hoehe'])
            ende = p3(k => xm, t => naechst.p0[t] + dir * kf['dicke'] / 2.0, 2 => reihe.sum { |o| o.p0[2] } / reihe.size)
            add.(s, Koerper.new(ka['titel'], mat.(ka), :stab, start, ende, k, ka['staerke'] / 2.0))
          end
          teile.select { |w| w.ops.any? { |o| o.titel == e['front']['titel'] } }.each do |kl|
            ops = kl.ops.select { |o| o.titel == e['front']['titel'] }
            da = Geometrie.achse(ops[0].seite)
            rein = Geometrie.max?(ops[0].seite) ? 1 : -1
            wa = (kl.flaechen_achsen - [2]).first
            fl = ops[0].p0[da]
            ops.group_by { |o| o.p0[wa].round(1) }.each_value do |reihe|
              x = reihe[0].p0[wa]
              zs = reihe.map { |o| o.p0[2] }
              add.(kl, quader(kf['titel'], mat.(kf), p3(wa => x - kf['breite'] / 2.0, da => fl, 2 => zs.min - kf['ueber']),
                              p3(wa => x + kf['breite'] / 2.0, da => fl + rein * kf['dicke'], 2 => zs.max + kf['ueber'])))
            end
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
        return k.a.flat_map { |x| flaechen(x, inv) } if k.form == :mehrere
        if k.form == :prisma
          u = k.a.map(&lokal)
          o = k.a.map { |p| q = p.dup; q[2] = k.b; lokal.(q) }
          n = u.size
          return [u, o.reverse] + (0...n).map { |i| [u[i], u[(i + 1) % n], o[(i + 1) % n], o[i]] }
        end
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
        alpha = MATERIALIEN.values.find { |n, _| n == name }&.at(2)
        m.alpha = alpha if alpha && m.respond_to?(:alpha=)
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
        "v#{VERSION}|#{Beschlagkatalog.fingerabdruck(s.respond_to?(:model) ? s.model : nil)}|#{d.object_id}|#{d.respond_to?(:name) ? d.name : ''}|#{werte.join('|')}"
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

      # Platzhalter der Komponenten für zugekaufte Beschläge (LeMans-Einbauraum, HU-Slim-Base-Gestell:
      # DC-Name „Beschlag“, eigener Tag <Kürzel>_LeMans bzw. <Kürzel>_Beschlag): ausblenden, solange die
      # Beschläge gezeigt werden (über ihren Tag, die DC steuert die Sichtbarkeit der Instanz selbst)
      def platzhalter(model, sichtbar, ents = model.entities, gesehen = {})
        Schraenke.instanzen(ents).each do |i|
          next if gruppe?(i)
          d = Schraenke.definition(i)
          if d.get_attribute(DC_DICT, '_name') == 'Beschlag' && i.layer && i.layer.name != TAG && i.layer.respond_to?(:visible=)
            i.layer.visible = sichtbar
            next
          end
          next if gesehen[d.object_id]
          gesehen[d.object_id] = true
          platzhalter(model, sichtbar, d.entities, gesehen)
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
        platzhalter(model, !an)
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
        platzhalter(model, false)
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
