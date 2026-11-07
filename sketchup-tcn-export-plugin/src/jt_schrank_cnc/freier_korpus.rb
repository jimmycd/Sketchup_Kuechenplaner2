# encoding: UTF-8
# Schrank-CNC – freier Schrank, Schritt 2a (Jürgen, 2026-11-07): Korpus anlegen und Teile
# einsetzen (Mittelwand, Einlegeboden, Zwischenboden). Alle Teile sind gleich zugewiesen
# (FreierSchrank.zuweisen): Rolle, Tag, Material, Anleimer.
#
# Korpus wie bei den Komponenten: Seiten außen, Boden zwischen den Seiten, Korpus beginnt bei
# y = Korpusstärke (davor sitzt die Front), Front zeigt nach -y.
#   Unterschrank: oben Strebe vorn und hinten (Breite 100 mm)
#   Ober-/Hochschrank: Deckel
#   Rückwand genutet (8 mm in 9 mm tiefer Nut in Seiten, Boden, 25 mm von hinten; Deckel bzw.
#   hintere Strebe enden davor), aufgesetzt (hinter dem Korpus) oder keine.

module JTools
  module SchrankCnc
    module FreierSchrank
      module_function

      RUECKWAENDE = %w[genutet aufgesetzt keine].freeze
      KORPUS = { staerke: 19.0, rueckwand: 8.0, nut: 9.0, versatz: 25.0, strebe: 100.0, rueckversatz: 10.0 }.freeze

      def zoll(mm)
        mm.to_f / Geometrie::MM
      end

      # Quader-Komponente name mit Größe [x, y, z] (mm) an pos (mm) in ents
      def platte(model, ents, name, pos, groesse)
        d = model.definitions.add(name)
        lx, ly, lz = groesse.map { |v| zoll(v) }
        f = d.entities.add_face([0, 0, 0], [lx, 0, 0], [lx, ly, 0], [0, ly, 0])
        f.reverse! if f.normal.z < 0
        f.pushpull(lz)
        inst = ents.add_instance(d, Geom::Transformation.translation(Geom::Vector3d.new(*pos.map { |v| zoll(v) })))
        inst.name = name
        inst
      end

      # Neuer freier Schrank (Maße mm); liefert die Instanz (noch nicht angedockt)
      def anlegen(model, kategorie: 'Unterschrank', breite: 600.0, hoehe: 720.0, tiefe: 560.0, name: '',
                  rueckwand: nil, material: nil, staerke: KORPUS[:staerke], ort: nil)
        raise ArgumentError, "Kategorie „#{kategorie}“ unbekannt" unless KATEGORIEN.include?(kategorie)
        rueckwand ||= kategorie == 'Unterschrank' ? 'aufgesetzt' : 'genutet'
        raise ArgumentError, "Rückwand „#{rueckwand}“ unbekannt" unless RUECKWAENDE.include?(rueckwand)
        b, h, t, mk = [breite, hoehe, tiefe, staerke].map(&:to_f)
        raise ArgumentError, 'Breite, Höhe und Tiefe müssen größer als 3 × Korpusstärke sein' if [b, h, t].min <= 3 * mk
        k = KORPUS
        rw, nut = k[:rueckwand], k[:nut]
        genutet = rueckwand == 'genutet'
        t_innen = genutet ? t - k[:versatz] - rw : t
        raise ArgumentError, 'Tiefe zu klein für eine Strebe' if kategorie == 'Unterschrank' && t_innen < 2 * k[:strebe]

        d = model.definitions.add(name.to_s.strip.empty? ? 'Freier Schrank' : name.to_s)
        x = ort || (model.entities.length > 0 ? model.bounds.max.x + zoll(100) : 0)
        inst = model.entities.add_instance(d, Geom::Transformation.translation(Geom::Vector3d.new(x, 0, 0)))
        kennzeichnen(model, inst, kategorie: kategorie, name: name)
        e = d.entities
        y0 = mk
        teile = []
        teile << [platte(model, e, 'SeiteL', [0, y0, 0], [mk, t, h]), 'Seite links']
        teile << [platte(model, e, 'SeiteR', [b - mk, y0, 0], [mk, t, h]), 'Seite rechts']
        teile << [platte(model, e, 'Boden', [mk, y0, 0], [b - 2 * mk, t, mk]), 'Boden']
        if kategorie == 'Unterschrank'
          teile << [platte(model, e, 'StrebeVorn', [mk, y0, h - mk], [b - 2 * mk, k[:strebe], mk]), 'Strebe vorn']
          teile << [platte(model, e, 'StrebeHinten', [mk, y0 + t_innen - k[:strebe], h - mk], [b - 2 * mk, k[:strebe], mk]), 'Strebe hinten']
        else
          teile << [platte(model, e, 'Deckel', [mk, y0, h - mk], [b - 2 * mk, t_innen, mk]), 'Deckel']
        end
        case rueckwand
        when 'genutet'
          teile << [platte(model, e, 'Rueckwand', [mk - nut, y0 + t_innen, mk - nut], [b - 2 * mk + 2 * nut, rw, h - mk + nut]), 'Rückwand']
        when 'aufgesetzt'
          teile << [platte(model, e, 'Rueckwand', [0, y0 + t, 0], [b, rw, h]), 'Rückwand']
        end
        mat = material || standard_material(model)
        teile.each { |i, art| zuweisen(model, inst, i, art: art, material: art == 'Rückwand' ? nil : mat) }
        inst
      end

      # Werkstücke im Schrank (mm, Koordinaten des Schranks)
      def werkstuecke_im(schrank)
        teile(schrank).select { |p| p.last.get_attribute(JT_DICT, 'teil') && p.none?(&:hidden?) }
                      .map { |p| Geometrie.werkstueck(Teil.new(p.last, p, schrank)) }
      end

      # Fächer von links nach rechts zwischen Seiten/Mittelwänden:
      # { x: [links, rechts], z: [Oberkante Boden, Unterkante Deckel/Strebe], y: [vorn, hinten] }
      def faecher(schrank)
        ws = werkstuecke_im(schrank)
        wand = ws.select { |w| w.rolle == 'Seite' && w.dicke_achse.zero? }.sort_by { |w| w.lo[0] }
        rw = ws.select { |w| w.rolle == 'Rueckwand' }
        wand.each_cons(2).map do |l, r|
          x0, x1 = l.hi[0], r.lo[0]
          ueber = ->(w) { w.lo[0] < x1 - TOL && w.hi[0] > x0 + TOL }
          boden = ws.select { |w| w.rolle == 'Boden' && ueber.(w) }.map { |w| w.hi[2] }.max || [l.lo[2], r.lo[2]].max
          oben = ws.select { |w| %w[Deckel Strebe].include?(w.rolle) && ueber.(w) }.map { |w| w.lo[2] }.min || [l.hi[2], r.hi[2]].min
          y0 = [l.lo[1], r.lo[1]].max
          hinten = rw.select { |w| ueber.(w) && w.lo[1] > y0 }.map { |w| w.lo[1] }.min
          y1 = [hinten, l.hi[1], r.hi[1]].compact.min
          { x: [x0, x1], z: [boden, oben], y: [y0, y1] }
        end
      end

      def fach(schrank, nr)
        f = faecher(schrank)
        raise ArgumentError, 'Der Schrank hat keine Fächer (zwei Seiten fehlen).' if f.empty?
        f[nr.to_i - 1] or raise ArgumentError, "Fach #{nr} gibt es nicht (1 bis #{f.size})."
      end

      # Mittelwand im Fach nr, abstand = lichtes Maß von der linken Wand des Fachs (mm)
      def mittelwand(model, schrank, fach: 1, abstand: nil, staerke: KORPUS[:staerke], material: nil)
        f = fach(schrank, fach)
        breite = f[:x][1] - f[:x][0]
        abstand = abstand.nil? ? (breite - staerke) / 2.0 : abstand.to_f
        raise ArgumentError, "Abstand muss zwischen 0 und #{(breite - staerke).round(1)} mm liegen" unless abstand.between?(0, breite - staerke)
        i = platte(model, Schraenke.definition(schrank).entities, 'Mittelwand', [f[:x][0] + abstand, f[:y][0], f[:z][0]],
                   [staerke, f[:y][1] - f[:y][0], f[:z][1] - f[:z][0]])
        zuweisen(model, schrank, i, art: 'Mittelwand', material: material)
      end

      # Einlegeboden (vorn 10 mm zurück) bzw. Zwischenboden (volle Tiefe, gedübelt) im Fach nr;
      # hoehe = Abstand Oberkante Boden bis Unterseite des neuen Bodens (mm)
      def boden_einsetzen(model, schrank, art, fach: 1, hoehe: nil, staerke: KORPUS[:staerke], material: nil)
        f = fach(schrank, fach)
        licht = f[:z][1] - f[:z][0]
        hoehe = hoehe.nil? ? (licht - staerke) / 2.0 : hoehe.to_f
        raise ArgumentError, "Höhe muss zwischen 0 und #{(licht - staerke).round(1)} mm liegen" unless hoehe.between?(0, licht - staerke)
        rv = art == 'Einlegeboden' ? KORPUS[:rueckversatz] : 0.0
        i = platte(model, Schraenke.definition(schrank).entities, art, [f[:x][0], f[:y][0] + rv, f[:z][0] + hoehe],
                   [f[:x][1] - f[:x][0], f[:y][1] - f[:y][0] - rv, staerke])
        zuweisen(model, schrank, i, art: art, material: material)
      end

      def einlegeboden(model, schrank, **opt)
        boden_einsetzen(model, schrank, 'Einlegeboden', **opt)
      end

      def zwischenboden(model, schrank, **opt)
        boden_einsetzen(model, schrank, 'Zwischenboden', **opt)
      end

      # ------------------------------------------------------------------
      # Fronten: Tür, Schublade, Blende (Schritt 2b)
      # ------------------------------------------------------------------
      SPALT = 2.0 # mm, wie Spaltbreite der Komponenten

      # Wände (Seiten, Mittelwände) von links nach rechts und der Korpus (Seiten) außen
      def waende(schrank)
        werkstuecke_im(schrank).select { |w| w.rolle == 'Seite' && w.dicke_achse.zero? }.sort_by { |w| w.lo[0] }
      end

      # Frontbereich eines Fachs: x von/bis (außen voller Aufschlag, an Mittelwänden halber),
      # z von/bis Korpus mit halbem Spalt, y Vorderseite des Korpus
      def front_bereich(schrank, nr)
        f = fach(schrank, nr)
        w = waende(schrank)
        l, r = w[nr.to_i - 1], w[nr.to_i]
        x0 = l.equal?(w.first) ? l.lo[0] + SPALT / 2 : (l.lo[0] + l.hi[0]) / 2 + SPALT / 2
        x1 = r.equal?(w.last) ? r.hi[0] - SPALT / 2 : (r.lo[0] + r.hi[0]) / 2 - SPALT / 2
        z0 = w.map { |x| x.lo[2] }.min
        z1 = w.map { |x| x.hi[2] }.max
        { x: [x0, x1], z: [z0 + SPALT / 2, z1 - SPALT / 2], vorn: f[:y][0], fach: f }
      end

      def behaelter(model, ents, name, pos)
        d = model.definitions.add(name)
        i = ents.add_instance(d, Geom::Transformation.translation(Geom::Vector3d.new(*pos.map { |v| zoll(v) })))
        i.name = name
        d.set_attribute(DC_DICT, '_name', name)
        i.set_attribute(DC_DICT, '_name', name)
        i
      end

      # Tür(en) vor Fach nr: anschlag 'links', 'rechts' oder 'doppelt'; z/hoehe (mm, Schrank) wahlweise
      # Jede Tür steckt in einem Halter am Drehpunkt (Topfbänder an der Anschlagseite, Öffnen mit Interagieren)
      def tuer(model, schrank, fach: 1, anschlag: 'links', z: nil, hoehe: nil, material: nil)
        raise ArgumentError, "Anschlag „#{anschlag}“ unbekannt" unless %w[links rechts doppelt].include?(anschlag)
        fb = front_bereich(schrank, fach)
        z0 = z.nil? ? fb[:z][0] : z.to_f
        h = hoehe.nil? ? fb[:z][1] - z0 : hoehe.to_f
        raise ArgumentError, 'Türhöhe zu klein' if h < 50
        mk = KORPUS[:staerke]
        y = fb[:vorn] - SPALT - mk
        x0, x1 = fb[:x]
        e = Schraenke.definition(schrank).entities
        stuecke = if anschlag == 'doppelt'
                    m = (x0 + x1) / 2
                    [['links', x0, m - SPALT / 2, 'Tür links'], ['rechts', m + SPALT / 2, x1, 'Tür rechts']]
                  else
                    [[anschlag, x0, x1, 'Tür']]
                  end
        stuecke.map do |seite, a, b, art|
          rechts = seite == 'rechts'
          halter = behaelter(model, e, rechts ? 'TuerRHalter' : 'TuerHalter', [rechts ? b : a, y, z0])
          hd = halter.definition
          hd.set_attribute(DC_DICT, 'rotz', 0.0)
          hd.set_attribute(DC_DICT, 'onclick', "ANIMATE(\"ROTZ\",0,#{rechts ? 100 : -100})")
          hd.set_attribute(DC_DICT, '_onclick_label', 'onClick')
          t = platte(model, hd.entities, art.delete(' '), [rechts ? -(b - a) : 0, 0, 0], [b - a, mk, h])
          zuweisen(model, schrank, t, art: art, material: material)
        end
      end

      # Blende (feste Front) vor Fach nr, Unterkante z (mm, Schrank), Höhe hoehe
      def blende(model, schrank, fach: 1, z: nil, hoehe: 100.0, material: nil)
        fb = front_bereich(schrank, fach)
        z0 = z.nil? ? fb[:z][1] - hoehe.to_f : z.to_f
        mk = KORPUS[:staerke]
        i = platte(model, Schraenke.definition(schrank).entities, 'Blende', [fb[:x][0], fb[:vorn] - SPALT - mk, z0],
                   [fb[:x][1] - fb[:x][0], mk, hoehe.to_f])
        zuweisen(model, schrank, i, art: 'Blende', material: material)
      end

      # nächster freier Schubladen-Bereich S1, S2 …
      def freier_bereich(schrank)
        belegt = teile(schrank).map { |p| p.last.get_attribute(JT_DICT, 'bereich').to_s }
        n = 1
        n += 1 while belegt.include?("S#{n}")
        "S#{n}"
      end

      # Schublade vor Fach nr: Front (Unterkante z, Höhe hoehe, mm im Schrank), Kastenboden und
      # Holzrückwand nach dem gewählten Schubladenauszug der Küche (Kuechenplaner::Schubkasten):
      # Kasten 30 mm über Unterkante Front, Schiene mindestens ueber_boden über dem Boden,
      # Kasten 30 mm unter Oberkante Front (oberste Schublade), Zarge die höchste, die passt.
      def schublade(model, schrank, fach: 1, z: nil, hoehe: 200.0, material: nil)
        sk = Kuechenplaner::Schubkasten
        w = sk.werte(model)
        a = sk.attribute(w)
        fb = front_bereich(schrank, fach)
        f = fb[:fach]
        hf = hoehe.to_f
        z0 = z.nil? ? fb[:z][1] - hf : z.to_f
        raise ArgumentError, 'Front liegt außerhalb des Schranks' if z0 < fb[:z][0] - TOL || z0 + hf > fb[:z][1] + TOL
        lw = f[:x][1] - f[:x][0]
        tiefe = f[:y][1] - f[:y][0]
        raise ArgumentError, "Fach zu wenig tief für eine Schublade (#{tiefe.round} mm)" if tiefe < sk.nl_min(a) * 10
        nl = sk.nl(tiefe / 10.0, a) * 10
        abstand = 30.0
        mb = 16.0
        ab = [z0 + abstand, f[:z][0] + w['ueber_boden'].to_f * 10].max # Unterkante Kasten
        oben = (z0 + hf - fb[:z][1]).abs < 2 * SPALT # oberste Schublade: Zarge bleibt unter der Strebe
        kc = z0 + hf - ab - (oben ? abstand : 0)
        raise ArgumentError, 'Front zu niedrig für einen Kasten' if kc < 40
        hrw = [sk.hrw(kc / 10.0, w['std'].to_f, a) * 10, kc - mb].min
        bereich = freier_bereich(schrank)
        kz = Schraenke.definition(schrank).get_attribute(JT_DICT, 'schrank')
        e = Schraenke.definition(schrank).entities
        kasten = behaelter(model, e, "Schublade#{bereich.delete('S')}", [0, 0, 0])
        kasten.layer = model.layers["#{kz}_#{bereich}_Schublade"] || model.layers.add("#{kz}_#{bereich}_Schublade")
        kd = kasten.definition
        kd.set_attribute(DC_DICT, '_lengthunits', 'CENTIMETERS')
        kd.set_attribute(DC_DICT, 'onclick', "ANIMATE(\"Y\",0,-#{(nl * 0.08).round(1)})")
        kd.set_attribute(DC_DICT, '_onclick_label', 'onClick')
        ke = kd.entities
        mk = KORPUS[:staerke]
        fr = platte(model, ke, 'Front', [fb[:x][0], fb[:vorn] - SPALT - mk, z0], [fb[:x][1] - fb[:x][0], mk, hf])
        bb, bt, rb = w['boden_b'].to_f * 10, w['boden_t'].to_f * 10, w['rw_b'].to_f * 10
        kb = platte(model, ke, 'KastenBoden', [f[:x][0] + bb / 2, f[:y][0], ab], [lw - bb, nl - bt, mb])
        kr = platte(model, ke, 'KastenRueckwand', [f[:x][0] + rb / 2, f[:y][0] + nl - bt - mb, ab + mb], [lw - rb, mb, hrw])
        zuweisen(model, schrank, fr, art: 'Front', bereich: bereich, material: material)
        zuweisen(model, schrank, kb, art: 'Kastenboden', bereich: bereich)
        zuweisen(model, schrank, kr, art: 'Kastenrückwand', bereich: bereich)
        kasten
      end

      # ------------------------------------------------------------------
      # Bedienung
      # ------------------------------------------------------------------
      def zahl(text)
        Float(text.to_s.strip.tr(',', '.'))
      rescue ArgumentError
        raise ArgumentError, "„#{text}“ ist keine Zahl"
      end

      def anlegen_dialog(model = Sketchup.active_model)
        prompts = ['Kategorie', 'Name', 'Breite (mm)', 'Höhe (mm)', 'Tiefe (mm)', 'Korpusstärke (mm)', 'Rückwand']
        defaults = ['Unterschrank', '', '600', '720', '560', '19', 'Standard']
        listen = [KATEGORIEN.join('|'), '', '', '', '', '', (['Standard'] + RUECKWAENDE).join('|')]
        Kuechenplaner::Eingabe.abfragen(prompts, defaults, listen, 'Freier Schrank anlegen', untertitel: 'Neuer Schrank', ok: 'Anlegen') do |w|
          b, h, t, mk = w[2..5].map { |v| zahl(v) }
          model.start_operation('Freier Schrank', true)
          begin
            inst = anlegen(model, kategorie: w[0], name: w[1], breite: b, hoehe: h, tiefe: t, staerke: mk,
                                  rueckwand: w[6] == 'Standard' ? nil : w[6])
            model.commit_operation
          rescue StandardError
            model.abort_operation
            raise
          end
          Kuechenplaner.neuer_schrank(inst) if Kuechenplaner.respond_to?(:neuer_schrank)
          model.selection.clear
          model.selection.add(inst)
        end
      end

      def front_dialog(art, model = Sketchup.active_model)
        schrank = schrank_zur_auswahl(model)
        unless schrank && frei?(schrank)
          UI.messagebox('Bitte zuerst einen freien Schrank wählen.')
          return
        end
        f = faecher(schrank)
        if f.empty?
          UI.messagebox('Der Schrank hat keine Fächer (zwei Seiten fehlen).')
          return
        end
        faecher_text = f.each_with_index.map { |x, i| "#{i + 1}: #{(x[:x][1] - x[:x][0]).round} × #{(x[:z][1] - x[:z][0]).round} mm" }
        prompts = ['Fach', 'Unterkante über Schrankunterkante (mm, leer = automatisch)']
        defaults = [faecher_text.first, '']
        listen = [faecher_text.join('|'), '']
        if art == 'Tür'
          prompts += ['Anschlag', 'Höhe (mm, leer = bis oben)']
          defaults += %w[links] + ['']
          listen += ['links|rechts|doppelt', '']
        else
          prompts << 'Höhe der Front (mm)'
          defaults << (art == 'Schublade' ? '200' : '100')
          listen << ''
        end
        Kuechenplaner::Eingabe.abfragen(prompts, defaults, listen, "#{art} einsetzen", ok: 'Einsetzen') do |w|
          nr = w[0].to_i
          z = w[1].to_s.strip.empty? ? nil : zahl(w[1])
          model.start_operation("#{art} einsetzen", true)
          begin
            case art
            when 'Tür' then tuer(model, schrank, fach: nr, z: z, anschlag: w[2], hoehe: w[3].to_s.strip.empty? ? nil : zahl(w[3]))
            when 'Schublade' then schublade(model, schrank, fach: nr, z: z, hoehe: zahl(w[2]))
            else blende(model, schrank, fach: nr, z: z, hoehe: zahl(w[2]))
            end
            model.commit_operation
          rescue StandardError
            model.abort_operation
            raise
          end
        end
      end

      # Mittelwand, Einlegeboden, Zwischenboden in den gewählten (oder geöffneten) freien Schrank
      def einsetzen_dialog(art, model = Sketchup.active_model)
        schrank = schrank_zur_auswahl(model)
        unless schrank && frei?(schrank)
          UI.messagebox('Bitte zuerst einen freien Schrank wählen.')
          return
        end
        f = faecher(schrank)
        if f.empty?
          UI.messagebox('Der Schrank hat keine Fächer (zwei Seiten fehlen).')
          return
        end
        faecher_text = f.each_with_index.map { |x, i| "#{i + 1}: #{(x[:x][1] - x[:x][0]).round} × #{(x[:z][1] - x[:z][0]).round} mm" }
        mass = art == 'Mittelwand' ? 'Abstand von links (mm, leer = Mitte)' : 'Höhe über Boden (mm, leer = Mitte)'
        Kuechenplaner::Eingabe.abfragen(['Fach', mass], [faecher_text.first, ''], [faecher_text.join('|'), ''],
                                        "#{art} einsetzen", ok: 'Einsetzen') do |w|
          nr = w[0].to_i
          wert = w[1].to_s.strip.empty? ? nil : zahl(w[1])
          model.start_operation("#{art} einsetzen", true)
          begin
            case art
            when 'Mittelwand' then mittelwand(model, schrank, fach: nr, abstand: wert)
            when 'Einlegeboden' then einlegeboden(model, schrank, fach: nr, hoehe: wert)
            else zwischenboden(model, schrank, fach: nr, hoehe: wert)
            end
            model.commit_operation
          rescue StandardError
            model.abort_operation
            raise
          end
        end
      end
    end
  end
end
