# encoding: UTF-8
# Schrank-CNC – Beschläge im SketchUp-Modell zeigen (Jürgen, 2026-11-06: „komplette Schublade incl.
# der Teile, die nicht gefertigt werden, auch Topfbänder und alle anderen Beschläge“).
#
# Die Beschläge werden aus denselben Bohrbildern berechnet wie TCN-Export und Beschlagliste
# (Regeln.anwenden), passen also immer zu den Bohrungen:
#   Schubladen  Blum LEGRABOX free: Zargen C oder M (Regeln.zarge) links und rechts, Korpusschienen an den
#               Schienenbohrungen, Fronthalter an der Frontbefestigung, Rückwandhalter an der Holzrückwand.
#   Türen       Blum-Topfband: Topf Ø35 in der Tür, Arm zur Seite, Montageplatte an der Seite.
#   Klappen     gewähltes Modell aus dem Beschlag-Katalog (AVENTOS HK/HS/HL top, Free Slim): Kraftspeicher bzw.
#               Mechanismus an beiden Seiten, Arm zum Frontbeschlag an der Klappe.
#   Faltklappe  AVENTOS HF top: Kraftspeicher, Hebel zur unteren Klappe, Scharniere (Töpfe, Montageplatten, Arme).
#   SERVO-DRIVE Schubladen: Trägerprofil senkrecht vor der Rückwand, Antriebseinheit je Auszug, Distanzpuffer.
# Jedes Modell im Beschlag-Katalog muss hier gezeichnet werden (test_beschlagmodell_alle.rb).
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
      VERSION = 9
      # Materialnamen: Rendern erkennt „Alu“/„Stahl“ als Metall
      MATERIALIEN = {
        alu: ['Beschlag Alu grau', [150, 152, 156]],
        stahl: ['Beschlag Stahl vernickelt', [196, 198, 202]],
        kunststoff: ['Beschlag Kunststoff grau', [110, 112, 116]],
        glas: ['Beschlag Glas klar', [205, 225, 230], 0.35],
        chrom: ['Beschlag Chrom', [215, 218, 222]]
      }.freeze
      # LeMans II und HU Slim Base (vereinfacht): Maße unter koerper im Katalogeintrag (Eckauszug bzw.
      # Hochauszug der Küche): LeMans Säule, Tablare mit Rand im Einbauraum von der Seite bis hinter das
      # Säulenlager, Seitenprofil; HU Schienen an der Seite (Bauraumtiefe − schiene_kuerzer lang),
      # Gestell mit 2 Körben auf Höhe der Fronthalter, Fronthalter.

      # LEGRABOX free (vereinfacht): Zarge 12,8 mm stark, Korpusschiene 4 mm an der Seite,
      # Zarge davor; Schiene 4 mm hinter der Vorderkante der Seite, NL − 10 lang.
      # Maße: Katalogeintrag des Schubladenauszugs, koerper (schiene, schiene_h, zarge, fronthalter,
      # rueckwandhalter; Zarge mit Seiteneinsatz: obergurt, einsatz im Fenster NL − kasten.einsatz_abzug)
      def auszug_koerper
        Beschlagkatalog.gewaehlt('schubladen')['koerper'].map { |k, v| [k.to_sym, v.to_f] }.to_h
      end
      # Topfband: Körper aus dem Beschlag-Katalog (koerper: topf_tiefe, arm_h, arm_b, arm_ueber, platte)
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
        falttuer(teile, add)
        klappen(teile, add)
        faltklappe_scharniere(teile, add)
        servo_drive(teile, add)
        lemans(teile, add)
        hu_slim_base(teile, add)
        tip_on(teile, add)
        out
      end

      def mitte(w, i)
        (w.lo[i] + w.hi[i]) / 2.0
      end

      def schubladen(teile, add)
        alu = MATERIALIEN[:alu][0]
        lg = auszug_koerper
        ax = Regeln.auszug
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
            y0 = vorn_min ? ys.min - (ax[:schiene][:vorn][0] - lg[:schiene]) : ys.max + (ax[:schiene][:vorn][0] - lg[:schiene])
            y1 = y0 + (vorn_min ? 1 : -1) * (nl - ax[:kasten][:boden_t])
            add.(s, quader("Korpusschiene NL #{nl.round} #{titel.sub('Schiene ', '')}", alu,
                           p3(k => fl, t => y0, 2 => z - lg[:schiene_h] / 2.0),
                           p3(k => fl + innen * lg[:schiene], t => y1, 2 => z + lg[:schiene_h] / 2.0)))
          end
        end

        Regeln.kaesten(teile).each do |kasten|
          boden = kasten.find { |w| w.rolle == 'KastenBoden' } or next
          rw = kasten.find { |w| w.rolle == 'KastenRueckwand' }
          m = Regeln.zarge(kasten)
          zh = ax[:zargen][m][:hoehe]
          wa = Regeln.breite_achse(kasten)
          ta = (boden.flaechen_achsen - [wa]).first
          next unless ta
          unten = kasten.map { |w| w.lo[2] }.min
          seiten = teile.select { |w| w.rolle == 'Seite' && w.dicke_achse == wa }
          links = seiten.map { |s| s.hi[wa] }.select { |v| v <= boden.lo[wa] + Regeln::TOL }.max || boden.lo[wa] - ax[:kasten][:boden_b] / 2.0
          rechts = seiten.map { |s| s.lo[wa] }.select { |v| v >= boden.hi[wa] - Regeln::TOL }.min || boden.hi[wa] + ax[:kasten][:boden_b] / 2.0
          f = Regeln.front_zu(kasten, teile)
          # vorn: Seite des Bodens zur Front (ohne Front: zur Rückwand gegenüber)
          vorn_min = if f then mitte(f, ta) < mitte(boden, ta)
                     elsif rw then mitte(rw, ta) > mitte(boden, ta)
                     else true
                     end
          vorn = vorn_min ? boden.lo[ta] : boden.hi[ta]
          dir = vorn_min ? 1 : -1
          nl = boden.mass(ta) + ax[:kasten][:boden_t] # Boden NL − boden_t
          bez = boden.teil.jt('bereich')
          [[links, 1, 'links'], [rechts, -1, 'rechts']].each do |aussen, innen, lr|
            x0 = aussen + innen * lg[:schiene]
            x1 = x0 + innen * lg[:zarge]
            zarge(boden, add, "Zarge #{m} #{lr} #{bez}", m, wa, ta, x0, x1, vorn, dir, nl, unten, zh, lg, ax)
            # Rückwandhalter: zwischen Zarge und Holzrückwand, auf deren Höhe
            next unless rw
            add.(boden, quader("Rückwandhalter #{m} #{lr} #{bez}", alu,
                               p3(wa => x1, ta => rw.lo[ta] - 5, 2 => rw.lo[2] + 5),
                               p3(wa => x1 + innen * lg[:rueckwandhalter], ta => rw.hi[ta] + 5, 2 => rw.hi[2] - 5)))
          end
          # Seitenstabilisierung (ab Korpusbreite 600, wie die Beschlagliste): Stange quer zwischen den
          # Zargen oben vor der Holzrückwand
          kb = rechts - links + 2 * (seiten.first ? seiten.first.mass(wa) : 19.0)
          if rw && kb >= ax[:stabilisierung_ab] - Regeln::TOL
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
      def zarge(boden, add, name, m, wa, ta, x0, x1, vorn, dir, nl, unten, zh, zf, ax)
        alu = MATERIALIEN[:alu][0]
        ein = ax[:zargen][m][:einsatz]
        y1 = vorn + dir * (nl - 1)
        unless ein && ein < zh
          add.(boden, quader(name, alu, p3(wa => x0, ta => vorn, 2 => unten), p3(wa => x1, ta => y1, 2 => unten + zh)))
          return
        end
        oben = unten + zh
        f_oben = oben - zf[:obergurt]
        f_unten = f_oben - ein
        rand = ((nl - 1) - (nl - ax[:kasten][:einsatz_abzug])) / 2.0
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
        lg = Regeln.lemans_werte
        le = lg[:koerper]
        chrom = MATERIALIEN[:chrom][0]
        s = teile.find { |w| w.ops.any? { |o| o.titel == lg[:profil][:titel] } } or return
        boden = teile.find { |w| w.rolle == 'Boden' } or return
        lager = boden.ops.find { |o| o.titel == lg[:lager][:titel] } or return
        strebe = teile.find { |w| w.teil.jt('teil') == 'StrebeVorn' }
        profil = s.ops.select { |o| o.titel == lg[:profil][:titel] }
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
        c = Regeln.hu
        hu = c[:koerper]
        stahl = MATERIALIEN[:stahl][0]
        s = teile.find { |w| w.ops.any? { |o| o.titel == c[:schiene][:titel] } } or return
        boden = teile.find { |w| w.rolle == 'Boden' } or return
        sch = s.ops.select { |o| o.titel == c[:schiene][:titel] }
        k = Geometrie.achse(sch[0].seite)
        innen = Geometrie.max?(sch[0].seite) ? 1 : -1
        t = ([0, 1] - [k]).first
        fl = sch[0].p0[k]
        ys = sch.map { |o| o.p0[t] }
        dir = (s.hi[t] - ys.max) > (ys.min - s.lo[t]) ? 1 : -1
        vorne = dir > 0 ? ys.min - c[:schiene][:vorn][0] : ys.max + c[:schiene][:vorn][0]
        laenge = c[:bauraum][:tiefe] - hu[:schiene_kuerzer]
        sch.map { |o| o.p0[2] }.uniq.each_with_index do |z, i|
          add.(s, quader("Schiene HU Slim Base #{i + 1}", stahl, p3(k => fl, t => vorne + dir * 10, 2 => z - hu[:schiene][1] / 2.0),
                         p3(k => fl + innen * hu[:schiene][0], t => vorne + dir * (10 + laenge), 2 => z + hu[:schiene][1] / 2.0)))
        end
        f = teile.find { |w| w.ops.any? { |o| o.titel == c[:front][:titel] } } or return
        fo = f.ops.select { |o| o.titel == c[:front][:titel] }
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
        teile.select { |w| w.rolle == 'Tuer' }.each do |t|
          t.ops.select { |o| o.art == :topfband }.each_with_index do |o, i|
            e = (o.daten && Beschlagkatalog.eintrag(o.daten[:modell])) || Beschlagkatalog.gewaehlt('topfband')
            kp = e['koerper']
            tb = { topf_tiefe: kp['topf_tiefe'], arm_h: kp['arm_h'], arm_b: kp['arm_b'], arm_ueber: kp['arm_ueber'], platte: kp['platte'] }
            r = o.d / 2.0
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

      # Grifflos (Beschlagart „oeffnung“ der Küche oder des Schranks), vereinfacht:
      # * TIP-ON an der Tür (Blum TIP-ON und SERVO-DRIVE, Block „tuer“): Adapterplatte (20 hoch, 12 stark)
      #   innen an der Seite bzw. Kreuzadapterplatte (37 breit) im Boden an den TIP-ON-Bohrungen, darin der
      #   Stößel Ø10 (Kurzversion 50 lang, Langversion 76, Katalog 2024/2025 S. 192), 1,5 mm vor der
      #   Korpuskante (Frontspalt); fest im Schrank
      # * AVENTOS-Klappe mit TIP-ON (liste.klappe nennt TIP-ON): Kurzversion mit gerader Adapterplatte innen an
      #   der rechten Seite, 50 über der Klappenunterkante (Lage abgeleitet, Katalog S. 50 „von Hand setzen“)
      # * Schubladen TIP-ON BLUMOTION: Einheit als Block (120 × 15 × 12) unter dem hinteren Ende jeder
      #   Korpusschiene einer grifflosen Schublade (S. 396 f.; SERVO-DRIVE an Schubladen zeichnet servo_drive)
      TIP_ON = { kurz: 50.0, lang: 76.0, r: 5.0, platte_h: 20.0, platte_d: 12.0, kreuz_b: 37.0, spalt: 1.5,
                 klappe_rand: 50.0, einheit: [120.0, 15.0, 12.0] }.freeze

      def tip_on(teile, add)
        e = Beschlagkatalog.gewaehlt('oeffnung')
        return unless e && e['tuer']
        tip_on_tueren(teile, add, e)
        tip_on_klappen(teile, add) if (e['liste']['klappe'] || []).any? { |x| x[0].to_s.include?('TIP-ON') }
        tip_on_blumotion(teile, add) if e['schublade'] == 'tip_on_blumotion'
      end

      # Stößel mit Adapterplatte: fa/fl/innen = Fläche, auf der die Platte sitzt; da/vorne/rein = Tiefe
      # (Korpuskante, Richtung nach hinten); qa/q/b = Lage und Breite quer
      def tip_on_koerper(w, add, name, fa, fl, innen, da, vorne, rein, qa, q, b, l)
        ks = MATERIALIEN[:kunststoff][0]
        c = TIP_ON
        add.(w, quader("#{name} Adapterplatte", ks, p3(fa => fl, da => vorne, qa => q - b / 2.0),
                       p3(fa => fl + innen * c[:platte_d], da => vorne + rein * l, qa => q + b / 2.0)))
        add.(w, zylinder("#{name} #{l > c[:kurz] ? 'Langversion' : 'Kurzversion'}", ks,
                         p3(fa => fl + innen * c[:platte_d] / 2.0, da => 0, qa => q), da,
                         vorne - rein * c[:spalt], vorne + rein * l, c[:r]))
      end

      def tip_on_klappen(teile, add)
        kl = Beschlagkatalog.eintraege.select { |x| x['bauart'] == 'klappe_seite' }
        teile.each do |k|
          next unless kl.any? { |x| k.ops.any? { |o| o.titel == x['front']['titel'] } }
          da = k.dicke_achse
          next if da == 2
          wa = da.zero? ? 1 : 0
          s = teile.select { |w| w.rolle == 'Seite' && w.dicke_achse == wa }.max_by { |w| w.hi[wa] } or next
          km = mitte(k, da)
          vorne, rein = (s.lo[da] - km).abs < (s.hi[da] - km).abs ? [s.lo[da], 1] : [s.hi[da], -1]
          # rechte Seite: Innenfläche zur Klappenmitte hin
          innen = mitte(s, wa) > mitte(k, wa) ? -1 : 1
          fl = innen.negative? ? s.lo[wa] : s.hi[wa]
          tip_on_koerper(s, add, "TIP-ON #{k.name}", wa, fl, innen, da, vorne, rein, 2,
                         k.lo[2] + TIP_ON[:klappe_rand], TIP_ON[:platte_h], TIP_ON[:kurz])
        end
      end

      def tip_on_tueren(teile, add, e)
        tu = e['tuer']
        c = TIP_ON
        teile.each do |w|
          w.ops.select { |o| o.titel == tu['titel'] && o.daten }.group_by { |o| o.daten[:tuer] }.each do |tname, ops|
            t = teile.find { |x| x.name == tname && x.rolle == 'Tuer' } or next
            kreuz = ops.any? { |o| o.daten[:kreuz] }
            fa = Geometrie.achse(ops[0].seite) # Achse der Fläche, auf der die Platte sitzt
            innen = Geometrie.max?(ops[0].seite) ? 1 : -1
            fl = ops[0].p0[fa]
            da = t.dicke_achse
            tm = mitte(t, da)
            vorne, rein = (w.lo[da] - tm).abs < (w.hi[da] - tm).abs ? [w.lo[da], 1] : [w.hi[da], -1]
            lang = kreuz || Regeln.tip_on_version(e, t)['name'].to_s.include?('Lang')
            l = lang ? c[:lang] : c[:kurz]
            # Lage quer zur Tiefe: Höhe (Seite) bzw. Mitte der beiden Löcher (Boden)
            qa = ([0, 1, 2] - [fa, da]).first
            q = ops.sum { |o| o.p0[qa] } / ops.size
            b = kreuz ? c[:kreuz_b] : c[:platte_h]
            tip_on_koerper(w, add, "TIP-ON #{tname}", fa, fl, innen, da, vorne, rein, qa, q, b, l)
          end
        end
      end

      def tip_on_blumotion(teile, add)
        ks = MATERIALIEN[:kunststoff][0]
        name = 'TIP-ON BLUMOTION-Einheit'
        bereiche = Regeln.kaesten(teile).select { |k| Beschlaege.grifflos?(k, teile) }.map do |k|
          b = k.find { |w| w.rolle == 'KastenBoden' }
          b && b.teil.jt('bereich')
        end.compact
        lg, hh, dd = TIP_ON[:einheit]
        sh = auszug_koerper[:schiene_h]
        teile.select { |w| w.rolle == 'Seite' }.each do |s|
          s.ops.select { |o| o.titel.to_s.start_with?('Schiene ') && o.daten }.group_by(&:titel).each do |titel, ops|
            next unless bereiche.include?(titel.sub('Schiene ', ''))
            k = Geometrie.achse(ops[0].seite)
            innen = Geometrie.max?(ops[0].seite) ? 1 : -1
            t = ([0, 1] - [k]).first
            fl = ops[0].p0[k]
            z = ops[0].p0[2] - sh / 2.0
            ys = ops.map { |o| o.p0[t] }
            vorn_min = (ys.min - s.lo[t]) <= (s.hi[t] - ys.max)
            hinten = vorn_min ? ys.max : ys.min
            dir = vorn_min ? -1 : 1 # nach vorn
            add.(s, quader("#{name} #{titel.sub('Schiene ', '')}", ks, p3(k => fl, t => hinten, 2 => z - dd),
                           p3(k => fl + innen * hh, t => hinten + dir * lg, 2 => z)))
          end
        end
      end

      # Blum Eckschrank-Falttürscharnier (Eckschrank L): Topf in der langen Tür an der Ecke (als Quader bis
      # an die Türkante, der Topf läuft über die Kante; in der Tür, damit ihre Maße gleich bleiben),
      # Montageplatte auf der kurzen Tür (fährt mit ihr, liegt in ihrem Halter)
      def falttuer(teile, add)
        stahl = MATERIALIEN[:stahl][0]
        teile.select { |w| w.rolle == 'Tuer' }.each do |t|
          t.ops.select { |o| o.titel == 'Falttürscharnier Topf' }.each_with_index do |o, i|
            kp = (Beschlagkatalog.eintrag(o.daten[:modell]) || Beschlagkatalog.gewaehlt('falttuer'))['koerper']
            da = Geometrie.achse(o.seite)
            rein = Geometrie.max?(o.seite) ? 1 : -1
            wa = Geometrie.achse(o.daten[:kante])
            rand = Geometrie.max?(o.daten[:kante]) ? t.hi[wa] : t.lo[wa]
            innen = o.p0[wa] + (o.p0[wa] - rand <=> 0) * o.d / 2.0
            add.(t, quader("Falttürscharnier #{i + 1} Topf", stahl, p3(wa => rand, da => o.p0[da] - rein * kp['topf_tiefe'], 2 => o.p0[2] - o.d / 2.0),
                           p3(wa => innen, da => o.p0[da], 2 => o.p0[2] + o.d / 2.0)), true)
          end
          t.ops.select { |o| o.titel == 'Montageplatte Falttürscharnier' }.group_by { |o| o.daten[:z] }.each_with_index do |(z, ops), i|
            kp = (Beschlagkatalog.eintrag(ops[0].daten[:modell]) || Beschlagkatalog.gewaehlt('falttuer'))['koerper']
            pl = kp['platte']
            da = Geometrie.achse(ops[0].seite)
            rein = Geometrie.max?(ops[0].seite) ? 1 : -1
            ka = ([0, 1] - [da]).first
            y, fl = ops[0].p0[ka], ops[0].p0[da]
            add.(t, quader("Falttürscharnier #{i + 1} Montageplatte", stahl, p3(ka => y - pl[1] / 2.0, da => fl, 2 => z - pl[0] / 2.0),
                           p3(ka => y + pl[1] / 2.0, da => fl + rein * pl[2], 2 => z + pl[0] / 2.0)))
          end
        end
      end

      # Klappenbeschlag der Bauart klappe_seite (Katalog, koerper):
      #   seite  Kraftspeicher/Mechanismus an der Seite: dicke, vor/hinter = über das vorderste/hinterste
      #          Loch hinaus, unter/ueber = unter das unterste / über das oberste Loch hinaus
      #   arm    Stab vom Körper an der Seite (ein = hinter seiner Vorderkante, hoehe = über seiner
      #          Unterkante) zur Mitte des Frontbeschlags dieser Seite, fest im Schrank (geschlossene Klappe)
      #   front  Frontbeschlag an der Klappe: breite, dicke, ueber = über das oberste/unterste Loch hinaus
      KLAPPEN_BAUARTEN = %w[klappe_seite faltklappe_seite].freeze

      def klappen(teile, add)
        katalog = Beschlagkatalog.eintraege.select { |e| KLAPPEN_BAUARTEN.include?(e['bauart']) && e['koerper'] }
        ops_alle = teile.flat_map(&:ops)
        katalog.each do |e|
          kp = e['koerper']
          ks, ka, kf = kp['seite'], kp['arm'], kp['front']
          mat = ->(k) { MATERIALIEN.fetch(k['material'].to_sym)[0] }
          fb = ops_alle.select { |o| o.titel == e['front']['titel'] }
          teile.select { |w| w.rolle == 'Seite' }.each do |s|
            ops = s.ops.select { |o| o.titel == e['seite']['titel'] }
            next if ops.empty?
            # Körper je nach Korpushöhe (stufen, z. B. AVENTOS HF top), sonst fest
            ks = Beschlagkatalog.stufe(kp['seite'], s.mass(2))
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

      # Scharniere der Faltklappe (Bauart faltklappe_seite, AVENTOS HF top; koerper.scharnier):
      #   Topf Ø35 an jeder Scharnier-Bohrung (in der Klappe selbst, ganz in ihrer Stärke)
      #   Montageplatte über je zwei Plattenlöchern (unter dem Oberboden/Deckel bzw. auf der oberen Klappe),
      #   Arm von der Platte zum nächsten Topf (geschlossene Klappe)
      def faltklappe_scharniere(teile, add)
        stahl = MATERIALIEN[:stahl][0]
        Beschlagkatalog.eintraege.select { |e| e['bauart'] == 'faltklappe_seite' && e['koerper'] && e['koerper']['scharnier'] }.each do |e|
          ks = e['koerper']['scharnier']
          toepfe = []
          teile.each do |w|
            w.ops.select { |o| o.titel == e['scharnier']['titel'] }.each_with_index do |o, i|
              da = Geometrie.achse(o.seite)
              rein = Geometrie.max?(o.seite) ? 1 : -1
              fl = o.p0[da]
              add.(w, zylinder("Scharnier AVENTOS HF top #{toepfe.size + 1} Topf", stahl, o.p0, da, fl - rein * ks['topf_tiefe'], fl, o.d / 2.0), true)
              toepfe << o
            end
          end
          n = 0
          teile.each do |w|
            ops = w.ops.select { |o| o.titel == e['platte']['titel'] }
            next if ops.empty?
            fa = Geometrie.achse(ops[0].seite)
            raus = Geometrie.max?(ops[0].seite) ? 1 : -1
            fl = ops[0].p0[fa]
            # Plattenachse: die Richtung, in der die Löcher auseinanderliegen
            la = ([0, 1, 2] - [fa]).max_by { |a| ops.map { |o| o.p0[a] }.minmax.then { |lo, hi| hi - lo } }
            qa = ([0, 1, 2] - [fa, la]).first
            pl = ks['platte']
            ops.sort_by { |o| o.p0[la] }.each_slice(2) do |paar|
              n += 1
              m = paar.map { |o| o.p0 }.transpose.map { |v| v.sum / v.size }
              add.(w, quader("Scharnier AVENTOS HF top #{n} Montageplatte", stahl,
                             p3(la => m[la] - pl[0] / 2.0, qa => m[qa] - pl[1] / 2.0, fa => fl),
                             p3(la => m[la] + pl[0] / 2.0, qa => m[qa] + pl[1] / 2.0, fa => fl + raus * pl[2])))
              topf = toepfe.min_by { |o| (0..2).sum { |a| (o.p0[a] - m[a])**2 } } or next
              start = m.dup
              start[fa] = fl + raus * pl[2]
              ende = topf.p0.dup
              ende[Geometrie.achse(topf.seite)] += (Geometrie.max?(topf.seite) ? 1 : -1) * ks['arm'] / 2.0
              add.(w, Koerper.new("Scharnier AVENTOS HF top #{n} Arm", stahl, :stab, start, ende, la, ks['arm'] / 2.0))
            end
          end
        end
      end

      # Blum SERVO-DRIVE an Schubladen (Öffnung der Küche oder des Schranks, Eintrag mit servo.koerper,
      # Katalog S. 364–366): Trägerprofil senkrecht in der Mitte vor der Rückwand (Länge PL = LH − 10,
      # auf 10 abgerundet, mittig zwischen Boden und nächstem festen Boden), je grifflosem Auszug eine
      # Antriebseinheit A über der Unterkante der Korpusschiene, Distanzpuffer an der Front (FH bis 300 und
      # unter 70 kg: 2 in halber Höhe, sonst 4 je 20 vom Rand; seitlich FA/2 = Mitte des Aufschlags auf der Seite)
      def servo_drive(teile, add)
        o = Beschlagkatalog.gewaehlt('oeffnung')
        return unless o && o['schublade'] == 'servo_drive' && o['servo'] && o['servo']['koerper']
        kp = o['servo']['koerper']
        kaesten = Regeln.kaesten(teile).select { |k| k.any? { |w| w.rolle == 'KastenBoden' } && Beschlaege.grifflos?(k, teile) }
        return if kaesten.empty?
        kunst = MATERIALIEN[:kunststoff][0]
        alu = MATERIALIEN[:alu][0]
        ax = Regeln.auszug
        lg = auszug_koerper
        boden0 = kaesten[0].find { |w| w.rolle == 'KastenBoden' }
        wa = Regeln.breite_achse(kaesten[0])
        ta = (boden0.flaechen_achsen - [wa]).first
        seiten = teile.select { |w| w.rolle == 'Seite' && w.dicke_achse == wa }
        rw = teile.select { |w| w.rolle == 'Rueckwand' }.min_by { |w| (w.lo[2] + w.hi[2]) / 2.0 - (boden0.lo[2] + boden0.hi[2]) / 2.0 }
        return if seiten.size < 2 || rw.nil?
        x_m = (seiten.map { |s| s.hi[wa] }.min + seiten.map { |s| s.lo[wa] }.max) / 2.0
        # vorne: Seite des Kastenbodens zur Front, hinten die Rückwand
        hinten_max = mitte(rw, ta) > mitte(boden0, ta)
        dir = hinten_max ? -1 : 1 # von der Rückwand nach vorn
        y_rw = hinten_max ? rw.lo[ta] : rw.hi[ta]
        kasten_hinten = kaesten.flat_map { |k| k.map { |w| hinten_max ? w.hi[ta] : w.lo[ta] } }.send(hinten_max ? :max : :min)
        luft = (kasten_hinten - y_rw).abs - 1
        pb, pt = kp['profil']
        ab, ah, at = kp['antrieb']
        at = [[at, luft - pt].min, kp['antrieb_min']].max
        unten = teile.select { |w| w.rolle == 'Boden' }.map { |w| w.hi[2] }.max || seiten.map { |s| s.lo[2] }.min
        oben = teile.select { |w| Regeln::FESTE_BOEDEN.include?(w.rolle) && w.lo[2] > unten + Regeln::TOL }.map { |w| w.lo[2] }.min ||
               seiten.map { |s| s.hi[2] }.max
        pl = (((oben - unten) - o['servo']['abzug_lh']) / 10.0).floor * 10
        z0 = unten + ((oben - unten) - pl) / 2.0
        s0 = seiten.first
        add.(s0, quader("SERVO-DRIVE Trägerprofil #{pl}", alu, p3(wa => x_m - pb / 2.0, ta => y_rw, 2 => z0),
                        p3(wa => x_m + pb / 2.0, ta => y_rw + dir * pt, 2 => z0 + pl)))
        a = kp['a'][Beschlagkatalog.gewaehlt('schubladen')['kennung']] || kp['a']['standard']
        kaesten.each do |kasten|
          boden = kasten.find { |w| w.rolle == 'KastenBoden' }
          bez = boden.teil.jt('bereich')
          sch = teile.flat_map(&:ops).select { |x| x.titel == "Schiene #{bez}" }
          zu = sch.empty? ? kasten.map { |w| w.lo[2] }.min : sch.map { |x| x.p0[2] }.min - lg[:schiene_h] / 2.0
          add.(s0, quader("SERVO-DRIVE Antriebseinheit #{bez}", kunst, p3(wa => x_m - ab / 2.0, ta => y_rw + dir * pt, 2 => zu + a),
                          p3(wa => x_m + ab / 2.0, ta => y_rw + dir * (pt + at), 2 => zu + a + ah)))
          f = Regeln.front_zu(kasten, teile) or next
          nl = sch.map { |x| x.daten && x.daten[:nl] }.compact.max
          kg = (nl && ax[:schiene][:kg_nl][nl]) || ax[:schiene][:kg]
          fh = f.mass(2)
          zs = fh <= 300 + Regeln::TOL && kg < 70 ? [(f.lo[2] + f.hi[2]) / 2.0] : [f.lo[2] + kp['puffer']['rand'], f.hi[2] - kp['puffer']['rand']]
          da = f.dicke_achse
          rein = mitte(s0, da) > mitte(f, da) ? 1 : -1
          ff = rein > 0 ? f.hi[da] : f.lo[da]
          seiten.each do |s|
            lo = [s.lo[wa], f.lo[wa]].max
            hi = [s.hi[wa], f.hi[wa]].min
            next if hi <= lo
            zs.each do |z|
              add.(f, zylinder("SERVO-DRIVE Distanzpuffer #{bez}", kunst, p3(wa => (lo + hi) / 2.0, da => ff, 2 => z), da, ff,
                               ff + rein * kp['puffer']['h'], kp['puffer']['d'] / 2.0))
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
        "v#{VERSION}|#{Beschlagkatalog.fingerabdruck(s.respond_to?(:model) ? s.model : nil, s)}|#{d.object_id}|#{d.respond_to?(:name) ? d.name : ''}|#{werte.join('|')}"
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
      # Offen heißt: eine Instanz zwischen Schrank und Tür (Tür, Türhalter, Falttür-Halter) ist gedreht.
      # Früher wurde die Dickenrichtung der Tür mit der Tiefe der ersten Seite verglichen; beim
      # Eckschrank L zeigen die Türen aber in zwei Richtungen: geschlossen galt er als offen (keine
      # Beschläge), nach dem Falten (kurze Tür vor der langen) als geschlossen, und die Bänder wurden
      # an der gefalteten Tür quer durch den Schrank gezeichnet (Jürgen 2026-11-07).
      def geschlossen?(ws)
        ws.select { |w| w.rolle == 'Tuer' || w.teil.jt('teil').to_s.start_with?('Klappe') }.all? do |w|
          w.dicke_achse != 2 && w.mass(w.dicke_achse) < 40 && ungedreht?(w.teil)
        end
      end

      # Keine Instanz unterhalb des Schranks gedreht (gespiegelt zählt nicht als gedreht). Die
      # Animationen enden bei ±0,01/0,02° (siehe Eckschrank), das gilt noch als zu.
      def ungedreht?(teil)
        i0 = teil.pfad.index(teil.schrank) || 0
        teil.pfad[(i0 + 1)..].all? do |inst|
          m = Geometrie.matrix(inst.transformation)
          (0..2).all? do |c|
            spalte = m[c * 4, 3]
            l = Math.sqrt(spalte.sum { |v| v * v })
            l < 1e-9 || spalte.each_with_index.all? { |v, r| r == c || v.abs / l < 0.01 }
          end
        end
      end

      # Beschläge eines Schranks auf Stand bringen; liefert die Anzahl der Körper
      # (nil, wenn eine Tür oder Klappe offen steht: dann bleibt alles, wie es ist)
      def schrank_aktualisieren(model, s)
        Beschlagkatalog.mit_schrank(s) { schrank_zeichnen(model, s) }
      end

      # (mit der Beschlagwahl dieses Schranks, siehe schrank_aktualisieren)
      def schrank_zeichnen(model, s)
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
