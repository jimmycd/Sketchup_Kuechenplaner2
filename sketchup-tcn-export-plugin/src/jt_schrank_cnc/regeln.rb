# encoding: UTF-8
# Schrank-CNC – Bearbeitungsregeln aus Jürgens Beispiel-TCN (beispiele/).
#
# Stöße werden geometrisch gefunden: liegt die Stirnseite eines Bodens, Deckels,
# Zwischenbodens oder einer Strebe (Teil A) an der Fläche einer Seite (Teil B),
# bekommt A eine Dübelreihe in die Stirnseite und B die passende Reihe in die
# Fläche. Dazu (Schritt 6): Nut für eine Rückwand, die in Seiten und Boden
# steckt (Oberschrank), Schrauben Deckel–Rückwand, Lochreihen für Einlegeböden
# und Bohrungen für Sockelfüße; der Ausschnitt in der Rückwand des Spülenschranks;
# Schienen und Front des Hochauszugs Häfele HU Slim Base; beim Eckschrank die Innenecke
# der L-Platten, die Streben in der Ecke und die Bohrungen für Kesseböhmer LeMans II.
# Die Bearbeitungen entstehen zuerst in
# Weltkoordinaten (mm) und werden erst beim Schreiben in die
# Werkstückkoordinaten (Fräsmaß) umgerechnet.

module JTools
  module SchrankCnc
    module Regeln
      TOL = 0.1 # mm

      # Bearbeitung auf einer Weltseite: :reihe (p0 -> p1, Raster, verteilt), :bohrung (p0),
      # :nut (Mittellinie p0 -> p1 auf der Oberfläche, d = Nutbreite) oder
      # :tasche (Rechteck mit den Ecken p0 und p1 auf der Oberfläche)
      Op = Struct.new(:art, :seite, :p0, :p1, :d, :tiefe, :raster, :verteilt, :titel)

      # Dübelreihen je Rolle von A (Abstand vom Rand, Raster; verteilt = #8508/#8509 1/1).
      # Böden und Deckel (Jürgen 2026-10-28): erster und letzter Dübel 30 mm von der fertigen Kante
      # (mit Anleimer; im Fräsmaß der TCN also 28 an einer Kante mit 2-mm-Anleimer), Abstand höchstens
      # 160 mm; der Schritt ST (#8512) wird errechnet, "gerade Anzahl" aus (#8508/#8509 0/0).
      # Lagen kommen aus Weltkoordinaten, Boden und Seite passen daher nach dem Anleimen zusammen.
      VERBINDUNGEN = {
        'Boden'         => { rand: 30, max_abstand: 160, fertig: true },
        'Deckel'        => { rand: 30, max_abstand: 160, fertig: true },
        'Zwischenboden' => { rand: 30, max_abstand: 160, fertig: true },
        # Strebe.tcn: 20 … x-20, Raster 60; verteilt, damit es auch bei 98 mm (Anleimer) zwei Dübel bleiben
        'Strebe'        => { rand: 20, raster: 60, verteilt: true, schraube: true }
      }.freeze
      DUEBEL = { d: 8, tiefe_kante: 22, tiefe_flaeche: 14 }.freeze # Seite 14 tief (Seiten_SK, Jürgen: das tiefere)
      SCHRAUBE = { d: 3, tiefe: 21 }.freeze # Seite.tcn: Ø3, 21 tief in der Mitte der Strebe
      # Deckel–Rückwand (Oberschrank): 3 Schrauben, 50 mm von den Seiten und in der Mitte;
      # Ø4 durch die Rückwand (1 mm tiefer als ihre Stärke), Ø3 × 15 in die Deckelkante (Annahme)
      RUECKWAND_SCHRAUBE = { rand: 50, d_rueckwand: 4, d_deckel: 3, tiefe_deckel: 15, durch: 1 }.freeze
      # Seite.tcn: Lochreihe Ø5, 12 tief, Raster 32, 35 mm von vorn und hinten,
      # 55 … x-50 im Fräsmaß der Seite = 38 über dem Boden und 33 unter dem Deckel.
      # Jede Seite bekommt sie in jedem Fach ohne Schubladen (Seiten sind immer gleich).
      LOCHREIHE = { d: 5, tiefe: 12, raster: 32, rand: 35, ueber: 38, unter: 33 }.freeze
      # Korpusschiene Blum LEGRABOX (Montageanleitung MD-015/4, S. 3): Ø5, 14 tief (Seiten_SK_L/R),
      # 37 und 37+32 mm ab Vorderkante Seite, hinten je Nennlänge NL 37 + a/b; NL ist die größte,
      # für die die lichte Tiefe (Vorderkante Seite bis Rückwand) >= NL + 3 ist.
      # Höhe = Kastenunterkante + Höhenoffset Schiene
      SCHIENE = { d: 5, tiefe: 14, vorn: [37, 69], abstand_nl: 3,
                  hinten: { 350 => [192, 224], 400 => [224, 256], 450 => [224, 256], 500 => [224, 256],
                            550 => [256, 320], 600 => [256, 320], 650 => [320, 416] } }.freeze
      KASTEN = %w[KastenBoden KastenRueckwand].freeze
      # Frontbefestigung LEGRABOX (MD-015/4, S. 4): Löcher 14 mm von der Innenseite der Seite
      # (= 14 + FA vom Frontrand), 0/32/96/128 mm übereinander, unterstes mind. 51 über Unterkante Front.
      # Höhe abgeleitet aus SK_Vorderstueck_Frontbef.tcn: unterstes 36 mm über Unterkante Kasten;
      # obere Löcher nur, solange sie nicht über dem Kasten liegen. Ø3 × 5 wie in der Vorlage.
      FRONT_BEF = { d: 3, tiefe: 5, innen: 14, ueber_kasten: 36, min_unten: 51, abstaende: [0, 32, 96, 128] }.freeze
      # Schubkastenboden.tcn: Falz unten an beiden Enden quer zur Breite für die Zargen,
      # 38 breit über die ganze Tiefe + 20 Überlauf und ein zweites Rechteck 20 breit, beide 8 tief
      BODEN_FALZ = [{ breite: 38, ueberlauf: 20 }, { breite: 20, ueberlauf: 0 }].freeze
      BODEN_FALZ_TIEFE = 8
      # Boden.tcn: je Sockelfuß 2 × 2 Bohrungen Ø3, 3 tief, Raster 64; 20 mm vom Rand in x, 60 mm in y
      SOCKELFUSS = { d: 3, tiefe: 3, raster: 64, rand_x: 20, rand_y: 60 }.freeze
      SOCKEL_KATEGORIEN = %w[Unterschrank Hochschrank].freeze
      DURCH = 1 # mm: Durchbruch = Stärke + 1 mm (wie Durchgangsbohrung Rückwand, von Jürgen bestätigt)
      FESTE_BOEDEN = %w[Boden Deckel Zwischenboden Strebe].freeze

      def self.anwenden(werkstuecke)
        werkstuecke.each { |w| w.ops.clear }
        meldungen = []
        werkstuecke.group_by { |w| w.teil.pfad.first }.each_value do |teile|
          teile.each do |a|
            regel = VERBINDUNGEN[a.rolle] or next
            teile.each do |b|
              next unless b.rolle == 'Seite'
              stoss(a, b, regel, meldungen)
            end
          end
          eckschrank_streben(teile, meldungen)
          teile.select { |w| w.rolle == 'Rueckwand' }.each do |rw|
            ausschnitt(rw)
            teile.each { |b| nut(rw, b) if %w[Seite Boden Deckel].include?(b.rolle) }
            teile.each { |b| rueckwand_schrauben(rw, b) if b.rolle == 'Deckel' && Schraenke.kategorie(b.teil) == 'Oberschrank' }
          end
          hu = hu_slim_base?(teile)
          lm = lemans?(teile)
          lochreihen(teile) unless hu || lm # Seiten mit Hochauszug oder Le Mans: keine Lochreihe (wie bei Schubladen)
          hu_slim_base(teile, meldungen) if hu
          lemans(teile, meldungen) if lm
          schienen(teile, meldungen)
          kaesten(teile).each { |k| frontbefestigung(k, teile); bodenfalz(k) }
          teile.each { |w| sockelfuesse(w) if w.rolle == 'Boden' && SOCKEL_KATEGORIEN.include?(Schraenke.kategorie(w.teil)) }
          teile.each { |w| kanalausschnitt(w, teile) if w.rolle == 'Boden' }
          teile.each { |w| ecke(w) }
        end
        meldungen
      end

      def self.ueberlapp(a, b, i)
        [a.hi[i], b.hi[i]].min - [a.lo[i], b.lo[i]].max
      end

      def self.punkt(werte)
        p = [0.0, 0.0, 0.0]
        werte.each { |i, v| p[i] = v }
        p
      end

      # Rückwand A steckt in B: Nut in die Fläche von B, auf der A herausragt
      def self.nut(a, b)
        k = b.dicke_achse
        ca = a.dicke_achse
        return if k == ca || (0..2).any? { |i| ueberlapp(a, b, i) < TOL }
        ax = Geometrie::ACHSEN[k]
        if a.lo[k] < b.lo[k] - TOL then seite, flaeche = :"#{ax}min", b.lo[k]
        elsif a.hi[k] > b.hi[k] + TOL then seite, flaeche = :"#{ax}max", b.hi[k]
        else return
        end
        la = ([0, 1, 2] - [k, ca]).first
        mitte = ([a.lo[ca], b.lo[ca]].max + [a.hi[ca], b.hi[ca]].min) / 2.0
        lo = [a.lo[la], b.lo[la]].max
        hi = [a.hi[la], b.hi[la]].min
        # bis zum Rand der Platte: ein Fräserradius darüber hinaus, damit die Nut offen ist
        lo -= NUT[:ueberlauf] if lo <= b.lo_f(la) + TOL
        hi += NUT[:ueberlauf] if hi >= b.hi_f(la) - TOL
        p0 = punkt(k => flaeche, ca => mitte, la => lo)
        p1 = punkt(k => flaeche, ca => mitte, la => hi)
        b.ops << Op.new(:nut, seite, p0, p1, ueberlapp(a, b, ca), ueberlapp(a, b, k), nil, nil, "Nut #{a.teil.jt('teil')}")
      end
      NUT = { werkzeug: 2200, d_werkzeug: 8.03, ueberlauf: 5 }.freeze # Treppenbau: 2200 = Ø 8,03 mm

      # Rückwand-Ausschnitt (Spülenschrank): Lage in der Rückwand steht als DC-Attribut an ihr
      # (Ausschnitt_X/_Z ab links unten, Ausschnitt_B/_H, Zoll). Kontur durch die Platte,
      # Fräser innen an der Kante entlang (Ecken mit Fräserradius).
      AUSSCHNITT = { durch: 1 }.freeze # 1 mm tiefer als die Stärke, wie Durchgangsbohrungen

      def self.ausschnitt(a)
        inst = a.teil.inst
        d = Schraenke.definition(inst)
        x, z, b, h = %w[ausschnitt_x ausschnitt_z ausschnitt_b ausschnitt_h].map do |k|
          (inst.get_attribute(DC_DICT, k) || d.get_attribute(DC_DICT, k)).to_f
        end
        return if b <= NUT[:d_werkzeug] || h <= NUT[:d_werkzeug]
        m = Geometrie.welt(a.teil.pfad)
        p0 = Geometrie.punkt(m, [x, 0, z]).map { |v| v * Geometrie::MM }
        p1 = Geometrie.punkt(m, [x + b, 0, z + h]).map { |v| v * Geometrie::MM }
        seite = Geometrie.seite(Geometrie.richtung(m, [0, -1, 0]))
        k = a.dicke_achse
        p0[k] = p1[k] = Geometrie.max?(seite) ? a.hi[k] : a.lo[k]
        a.ops << Op.new(:ausschnitt, seite, p0, p1, NUT[:d_werkzeug], a.mass(k) + AUSSCHNITT[:durch], nil, nil, 'Ausschnitt')
      end

      # Oberschrank: Deckel B endet vor der Rückwand A und wird durch sie verschraubt
      def self.rueckwand_schrauben(a, b)
        ca = a.dicke_achse
        kb = b.dicke_achse
        return if kb == ca
        if (b.hi[ca] - a.lo[ca]).abs < TOL then sa, sb, kp = :"#{Geometrie::ACHSEN[ca]}min", :"#{Geometrie::ACHSEN[ca]}max", a.lo[ca]
        elsif (b.lo[ca] - a.hi[ca]).abs < TOL then sa, sb, kp = :"#{Geometrie::ACHSEN[ca]}max", :"#{Geometrie::ACHSEN[ca]}min", a.hi[ca]
        else return
        end
        la = ([0, 1, 2] - [ca, kb]).first
        return unless ueberlapp(a, b, la) > 1.0 && ueberlapp(a, b, kb) > 1.0
        r = RUECKWAND_SCHRAUBE
        lo = b.lo[la] + r[:rand]
        hi = b.hi[la] - r[:rand]
        return if hi - lo < 1.0
        m = (b.lo[kb] + b.hi[kb]) / 2.0
        p0 = punkt(ca => kp, kb => m, la => lo)
        p1 = punkt(ca => kp, kb => m, la => hi)
        raster = (hi - lo) / 2.0
        a.ops << Op.new(:reihe, sa, p0, p1, r[:d_rueckwand], a.mass(ca) + r[:durch], raster, false, "Schraube #{b.teil.jt('teil')}")
        b.ops << Op.new(:reihe, sb, p0, p1, r[:d_deckel], r[:tiefe_deckel], raster, false, "Schraube #{a.teil.jt('teil')}")
      end

      def self.flaeche_innen(s, k, nach_max)
        nach_max ? [:"#{Geometrie::ACHSEN[k]}max", s.hi[k]] : [:"#{Geometrie::ACHSEN[k]}min", s.lo[k]]
      end

      # feste Böden (und Streben), die an der Seite stoßen, nach Höhe; Seite der Seite, an der sie liegen
      def self.boeden_an(s, teile)
        k = s.dicke_achse
        teile.select do |f|
          FESTE_BOEDEN.include?(f.rolle) && f.dicke_achse != k &&
            [(f.lo[k] - s.hi[k]).abs, (s.lo[k] - f.hi[k]).abs].min < TOL
        end
      end

      # Lochreihen in jeder Seite je Fach ohne Schubladen zwischen zwei festen Böden: vorn 35 mm,
      # hinten 35 mm vor Hinterkante bzw. Rückwandnut. Keine Lochreihe in Gerätenischen (Fach über
      # einem Boden mit JT_Schrank/nische, z. B. Hochschrank Geräte).
      def self.lochreihen(teile)
        teile.select { |w| w.rolle == 'Seite' }.each do |s|
          k = s.dicke_achse
          boeden = boeden_an(s, teile)
          next if boeden.empty?
          v = boeden.first.dicke_achse
          t = ([0, 1, 2] - [k, v]).first
          nach_max = (boeden.first.lo[k] - s.hi[k]).abs < TOL
          seite, flaeche = flaeche_innen(s, k, nach_max)
          l = LOCHREIHE
          nuten = s.ops.select { |o| o.art == :nut && o.seite == seite && o.p0[t] > s.lo_f(t) + l[:rand] }
          hinten = ([s.hi_f(t)] + nuten.map { |o| o.p0[t] - o.d / 2.0 }).min
          lagen = boeden.map { |f| [f.lo[v], f.hi[v]] }.uniq.sort
          schubladen = kaesten(teile).map { |k| k.map { |w| w.lo[v] }.min }
          nischen = boeden.select { |f| f.teil.jt('nische') }.map { |f| f.hi[v] }
          lagen.each_cons(2) do |(_, unten), (oben, _)|
            # Fach mit Schubladen: keine Lochreihe (das Raster dient nur zum Ausrichten der Schienen)
            next if schubladen.any? { |z| z.between?(unten - TOL, oben) }
            next if nischen.any? { |z| (z - unten).abs < TOL }
            lo = unten + l[:ueber]
            hi = oben - l[:unter]
            next if hi - lo < l[:raster]
            [s.lo_f(t) + l[:rand], hinten - l[:rand]].each do |y|
              s.ops << Op.new(:reihe, seite, punkt(k => flaeche, t => y, v => lo), punkt(k => flaeche, t => y, v => hi),
                              l[:d], l[:tiefe], l[:raster], false, 'Lochreihe')
            end
          end
        end
      end

      # Nennlänge der Schiene aus der lichten Tiefe der Seite (bis zur Rückwand, sonst bis Hinterkante)
      def self.nennlaenge(s, teile)
        t = 1 - s.dicke_achse
        hinten = teile.select { |w| w.rolle == 'Rueckwand' && w.lo[t] > s.lo[t] }.map { |w| w.lo[t] }.min || s.hi[t]
        lt = [hinten, s.hi[t]].min - s.lo[t]
        SCHIENE[:hinten].keys.select { |nl| nl + SCHIENE[:abstand_nl] <= lt + TOL }.max
      end

      # Nennlänge aus dem Attribut NL am Schrank (cm), wenn es eine LEGRABOX-Nennlänge ist;
      # nötig, wenn hinter den Kästen Platz frei bleibt (Unterschrank Kochfeld: Installationsraum)
      def self.nennlaenge_schrank(schrank)
        v = schrank.get_attribute(DC_DICT, 'nl') or return
        nl = (v.to_f * Geometrie::MM).round
        SCHIENE[:hinten].key?(nl) ? nl : nil
      end

      # sichtbare Schubladen: Kastenteile je Bereich
      def self.kaesten(teile)
        teile.select { |w| KASTEN.include?(w.rolle) }.group_by { |w| w.teil.jt('bereich') }.values
      end

      # Schienenbohrungen je sichtbarer Schublade in beiden Seiten
      def self.schienen(teile, meldungen)
        kaesten(teile).each do |kasten|
          unten = kasten.map { |w| w.lo[2] }.min
          schrank = Schraenke.definition(kasten.first.teil.schrank)
          z = unten + schrank.get_attribute(DC_DICT, 'hoehenoffset_schiene').to_f * Geometrie::MM
          lo = (0..1).map { |i| kasten.map { |w| w.lo[i] }.min }
          hi = (0..1).map { |i| kasten.map { |w| w.hi[i] }.max }
          teile.select { |w| w.rolle == 'Seite' && w.dicke_achse != 2 }.each do |s|
            k = s.dicke_achse
            t = 1 - k
            next unless z.between?(s.lo[2], s.hi[2]) && [s.hi[t], hi[t]].min - [s.lo[t], lo[t]].max > 1.0
            nach_max = if (lo[k] - s.hi[k]).between?(-TOL, 60) then true
                       elsif (s.lo[k] - hi[k]).between?(-TOL, 60) then false
                       end
            next if nach_max.nil?
            seite, flaeche = flaeche_innen(s, k, nach_max)
            nl = nennlaenge_schrank(schrank) || nennlaenge(s, teile)
            unless nl
              meldungen << "#{s.name}: zu wenig Tiefe für eine LEGRABOX-Schiene (NL 350 braucht 353 mm)"
              next
            end
            (SCHIENE[:vorn] + SCHIENE[:hinten][nl].map { |a| SCHIENE[:vorn][0] + a }).each do |d|
              y = s.lo[t] + d
              p = punkt(k => flaeche, t => y, 2 => z)
              s.ops << Op.new(:bohrung, seite, p, nil, SCHIENE[:d], SCHIENE[:tiefe], nil, nil, "Schiene #{kasten.first.teil.jt('bereich')}")
            end
          end
        end
      end

      # Breitenrichtung einer Schublade: in der Bodenebene quer zur Rückwand
      def self.breite_achse(kasten)
        boden = kasten.find { |w| w.rolle == 'KastenBoden' }
        rw = kasten.find { |w| w.rolle == 'KastenRueckwand' }
        return 0 unless boden
        (boden.flaechen_achsen - [rw ? rw.dicke_achse : 1]).first
      end

      # Front der Schublade: gleicher Schrank und Bereich wie der Kasten; hängen mehrere Kästen an
      # einer Front (Apothekerschrank), steht deren Bereich im Attribut front des Kastens
      def self.front_zu(kasten, teile)
        b = kasten.first.teil.jt('front') || kasten.first.teil.jt('bereich')
        teile.find { |w| w.rolle == 'Front' && w.teil.jt('bereich') == b }
      end

      def self.frontbefestigung(kasten, teile)
        f = front_zu(kasten, teile) or return
        boden = kasten.find { |w| w.rolle == 'KastenBoden' } or return
        wa = breite_achse(kasten)
        da = f.dicke_achse
        return if da == 2 || wa == da
        # Innenseiten der Korpusseiten neben dem Kasten, sonst aus dem Boden (LW - 35)
        seiten = teile.select { |w| w.rolle == 'Seite' && w.dicke_achse == wa }
        links = seiten.map { |s| s.hi[wa] }.select { |v| v <= boden.lo[wa] + TOL }.max || boden.lo[wa] - 17.5
        rechts = seiten.map { |s| s.lo[wa] }.select { |v| v >= boden.hi[wa] - TOL }.min || boden.hi[wa] + 17.5
        hinten = (boden.lo[da] + boden.hi[da]) / 2.0 > f.hi[da]
        seite = :"#{Geometrie::ACHSEN[da]}#{hinten ? 'max' : 'min'}"
        flaeche = hinten ? f.hi[da] : f.lo[da]
        fb = FRONT_BEF
        unten = kasten.map { |w| w.lo[2] }.min
        oben = kasten.map { |w| w.hi[2] }.max
        z0 = [unten + fb[:ueber_kasten], f.lo[2] + fb[:min_unten]].max
        fb[:abstaende].map { |a| z0 + a }.select { |z| z <= [oben, f.hi[2]].min + TOL }.each do |z|
          [links + fb[:innen], rechts - fb[:innen]].each do |x|
            f.ops << Op.new(:bohrung, seite, punkt(da => flaeche, wa => x, 2 => z), nil, fb[:d], fb[:tiefe], nil, nil,
                            'Frontbefestigung')
          end
        end
      end

      # Falz in der Unterseite des Kastenbodens an beiden Enden der Breite (Zargen)
      def self.bodenfalz(kasten)
        boden = kasten.find { |w| w.rolle == 'KastenBoden' } or return
        k = boden.dicke_achse
        wa = breite_achse(kasten)
        ta = (boden.flaechen_achsen - [wa]).first
        BODEN_FALZ.each do |r|
          t0 = boden.lo_f(ta) - r[:ueberlauf] / 2.0
          t1 = boden.hi_f(ta) + r[:ueberlauf] / 2.0
          [boden.lo_f(wa) + BODEN_FALZ[0][:breite] / 2.0, boden.hi_f(wa) - BODEN_FALZ[0][:breite] / 2.0].each do |m|
            p0 = punkt(k => boden.lo[k], wa => m - r[:breite] / 2.0, ta => t0)
            p1 = punkt(k => boden.lo[k], wa => m + r[:breite] / 2.0, ta => t1)
            boden.ops << Op.new(:tasche, :"#{Geometrie::ACHSEN[k]}min", p0, p1, nil, BODEN_FALZ_TIEFE, nil, nil, 'Falz Zarge')
          end
        end
      end

      # Hochauszug Häfele UTENSIO Matrix HU Slim Base (Montageanleitung 4004110659MKT, "Dimensions
      # for CNC", S. 4 und 6), Schrank mit JT_Schrank/beschlag = "Haefele HU Slim Base".
      # Zwei Schienen an einer Seite (DC-Attribut Seite_Beschlag: 0 = links/LH, 1 = rechts/RH):
      # je 3 Schrauben bei 56, 280 und 330 mm ab Vorderkante Seite, 52 und 52 + 384 = 436 mm über
      # der Oberkante Boden. Front: 2 Halter mit je 2 Schrauben, X = 84 (M150) / 134 (M200) = lichte
      # Weite - 28, also 14 mm von der Innenseite der Seiten, 103 und 103 + 384 = 487 mm über der
      # Oberkante Boden. Mitgeliefert sind Schrauben Ø4 × 16: vorgebohrt Ø3, Schiene 10 tief (Annahme),
      # Front 5 tief (Jürgen: Frontbohrungen immer 5 tief).
      HU_SLIM_BASE = {
        name: 'Haefele HU Slim Base',
        schiene: { d: 3, tiefe: 10, vorn: [56, 280, 330], hoehen: [52, 436] },
        front: { d: 3, tiefe: 5, innen: 14, hoehen: [103, 487] },
        bauraum: { weite: 112, tiefe: 485, hoehe: 565 } # Mindestmaße (S. 2)
      }.freeze

      def self.hu_slim_base?(teile)
        Schraenke.definition(teile.first.teil.schrank).get_attribute(JT_DICT, 'beschlag') == HU_SLIM_BASE[:name]
      end

      def self.hu_slim_base(teile, meldungen)
        sd = Schraenke.definition(teile.first.teil.schrank)
        rechts = sd.get_attribute(DC_DICT, 'seite_beschlag').to_f > 0.5
        s = teile.find { |w| w.teil.jt('teil') == (rechts ? 'SeiteR' : 'SeiteL') } or return
        andere = teile.find { |w| w.rolle == 'Seite' && !w.equal?(s) } or return
        boden = teile.find { |w| w.rolle == 'Boden' } or return
        k = s.dicke_achse
        t = ([0, 1, 2] - [k, 2]).first
        mitte = ->(w, i) { (w.lo[i] + w.hi[i]) / 2.0 }
        nach_max = mitte.(andere, k) > mitte.(s, k)
        seite, flaeche = flaeche_innen(s, k, nach_max)
        f = teile.find { |w| w.rolle == 'Front' }
        # vorne ist, wo die Front liegt (ohne Front: kleinere Koordinate)
        vorn_max = f && mitte.(f, t) > mitte.(s, t)
        vorne, dir = vorn_max ? [s.hi[t], -1] : [s.lo[t], 1]
        z0 = boden.hi[2]
        c = HU_SLIM_BASE[:schiene]
        c[:hoehen].each do |hz|
          c[:vorn].each do |d|
            s.ops << Op.new(:bohrung, seite, punkt(k => flaeche, t => vorne + dir * d, 2 => z0 + hz), nil, c[:d], c[:tiefe],
                            nil, nil, 'Schiene HU Slim Base')
          end
        end

        # Einbauraum prüfen: lichte Weite, Höhe bis unter die Streben, Tiefe bis zur Rückwand
        innen = [[s.hi[k], andere.hi[k]].min, [s.lo[k], andere.lo[k]].max]
        lw = innen[1] - innen[0]
        oben = teile.select { |w| w.rolle == 'Strebe' && w.lo[2] > z0 }.map { |w| w.lo[2] }.min || s.hi[2]
        rw = teile.select { |w| w.rolle == 'Rueckwand' }.map { |w| vorn_max ? vorne - w.hi[t] : w.lo[t] - vorne }.select(&:positive?).min
        lt = rw || (s.hi[t] - s.lo[t])
        b = HU_SLIM_BASE[:bauraum]
        { 'lichte Weite' => [lw, b[:weite]], 'lichte Höhe' => [oben - z0, b[:hoehe]], 'Tiefe' => [lt, b[:tiefe]] }.each do |was, (ist, min)|
          meldungen << "#{s.name}: #{was} #{ist.round(1)} mm, HU Slim Base braucht mindestens #{min} mm" if ist < min - TOL
        end

        return unless f
        da = f.dicke_achse
        hinten = mitte.(boden, da) > mitte.(f, da)
        fseite = :"#{Geometrie::ACHSEN[da]}#{hinten ? 'max' : 'min'}"
        fl = hinten ? f.hi[da] : f.lo[da]
        fc = HU_SLIM_BASE[:front]
        fc[:hoehen].each do |hz|
          [innen[0] + fc[:innen], innen[1] - fc[:innen]].each do |x|
            f.ops << Op.new(:bohrung, fseite, punkt(da => fl, k => x, 2 => z0 + hz), nil, fc[:d], fc[:tiefe], nil, nil,
                            'Front HU Slim Base')
          end
        end
      end

      # Kanalausschnitt im Boden (Unterschrank Kochfeld mit Abzug): durchgehende Rechtecktasche von unten.
      # Lage aus den DC-Attributen des Schranks: Ausschnitt_Links ab dem Rand bei SeiteL,
      # Ausschnitt_Hinten ab dem Rand bei der Rückwand, dazu Breite und Tiefe (cm).
      def self.kanalausschnitt(w, teile)
        sd = Schraenke.definition(w.teil.schrank)
        wert = ->(k) { sd.get_attribute(DC_DICT, k)&.to_f&.*(Geometrie::MM) }
        links, breite, hinten, tiefe = %w[ausschnitt_links ausschnitt_breite ausschnitt_hinten ausschnitt_tiefe].map(&wert)
        return unless links && breite && hinten && tiefe && breite > 0 && tiefe > 0
        k = w.dicke_achse
        rw = teile.find { |t| t.rolle == 'Rueckwand' } or return
        ta = rw.dicke_achse
        wa = (w.flaechen_achsen - [ta]).first or return
        sl = teile.find { |t| t.teil.jt('teil') == 'SeiteL' }
        w0 = sl && sl.lo[wa] > w.lo[wa] ? w.hi[wa] - links - breite : w.lo[wa] + links
        t0 = rw.lo[ta] >= w.hi[ta] - TOL ? w.hi[ta] - hinten - tiefe : w.lo[ta] + hinten
        p0 = punkt(k => w.lo[k], wa => w0, ta => t0)
        p1 = punkt(k => w.lo[k], wa => w0 + breite, ta => t0 + tiefe)
        w.ops << Op.new(:tasche, :"#{Geometrie::ACHSEN[k]}min", p0, p1, nil, w.mass(k) + DURCH, nil, nil, 'Kanalausschnitt')
      end

      # --- Eckschrank ---------------------------------------------------------------------
      ECKSCHRANK = 'Eckschrank'.freeze
      # Innenecke einer L-Platte: die Kanten bekommen Anleimer (OCL erkennt ihn dort nicht),
      # also 2 mm zurückfräsen; nach außen fährt die Kontur einen Fräserdurchmesser über die Platte.
      ECKE = { anleimer: 2.0, ueberlauf: NUT[:d_werkzeug] }.freeze

      def self.eckschrank?(teile)
        teile.first.teil.jt('typ') == ECKSCHRANK
      end

      # Ausgefräste Ecke einer L-Platte in Weltkoordinaten (mm): Fräsmaß-Grenzen der Ecke je Achse,
      # dazu je Plattenachse, an welchem Ende (:lo/:hi) die Ecke liegt und wo ihre Innenkante ist.
      # Die Ecke steht als ecke_x/ecke_y (Zoll, lokal) an der Definition; sie reicht von ecke_x
      # bis zum Ende in x und von 0 bis ecke_y in y.
      def self.ecke_rechteck(w)
        d = Schraenke.definition(w.teil.inst)
        ex, ey = d.get_attribute(DC_DICT, 'ecke_x'), d.get_attribute(DC_DICT, 'ecke_y')
        return unless ex && ey
        m = Geometrie.welt(w.teil.pfad)
        mx = d.bounds.max.to_a.map(&:to_f)
        p0 = Geometrie.punkt(m, [ex.to_f, 0.0, 0.0]).map { |v| v * Geometrie::MM }
        p1 = Geometrie.punkt(m, [mx[0], ey.to_f, 0.0]).map { |v| v * Geometrie::MM }
        aussen = {}
        innen = {}
        w.flaechen_achsen.each do |a|
          lo, hi = [p0[a], p1[a]].minmax
          if (lo - w.lo[a]).abs < TOL then aussen[a], innen[a] = :lo, hi + ECKE[:anleimer]
          else aussen[a], innen[a] = :hi, lo - ECKE[:anleimer]
          end
        end
        { aussen: aussen, innen: innen }
      end

      def self.ecke(w)
        e = ecke_rechteck(w) or return
        k = w.dicke_achse
        p0 = [0.0, 0.0, 0.0]
        p1 = [0.0, 0.0, 0.0]
        p0[k] = p1[k] = w.lo[k]
        e[:aussen].each do |a, ende|
          if ende == :lo then p0[a], p1[a] = w.lo[a] - ECKE[:ueberlauf], e[:innen][a]
          else p0[a], p1[a] = e[:innen][a], w.hi[a] + ECKE[:ueberlauf]
          end
        end
        w.ops << Op.new(:ausschnitt, :"#{Geometrie::ACHSEN[k]}min", p0, p1, NUT[:d_werkzeug], w.mass(k) + DURCH, nil, nil,
                        'Ausschnitt Innenecke')
      end

      # L-Form: in der Ecke stößt eine Strebe mit dem Ende an die Längskante der anderen (Dübel)
      def self.eckschrank_streben(teile, meldungen)
        return unless eckschrank?(teile)
        streben = teile.select { |w| w.rolle == 'Strebe' }
        streben.permutation(2).each do |a, b|
          next unless a.dicke_achse == b.dicke_achse
          lang = a.flaechen_achsen.max_by { |x| a.mass(x) }
          next unless lang == (b.flaechen_achsen - [b.flaechen_achsen.max_by { |x| b.mass(x) }]).first
          stoss(a, b, VERBINDUNGEN['Strebe'].merge(schraube: false), meldungen, lang, DUEBEL[:tiefe_kante])
        end
      end

      # Kesseböhmer LeMans II (Montageanleitung MA 406954 0000, S. 3 und 11) im Eckschrank
      # Blindeck mit Variante 2. Säulenlager in Boden und Strebe vorn: Ø5 für die Systemschraube
      # Ø6,3 × 13 bei X ab der Innenseite der Seite an der Tür und 69 mm ab Vorderkante, zwei
      # Ø4,5-Schrauben 16 mm daneben auf 37 mm (vorgebohrt Ø3, Annahme). Der Boden wird von unten
      # durchgebohrt (oben liegen die Sockelfüße nicht, Fläche 1 ist die Unterseite).
      # Seitenprofil 500 an der Seite der Tür: 8 Löcher Ø5 (Systemschraube) im Raster 64,
      # 52 mm ab Vorderkante, das unterste 28 mm über dem Boden.
      LEMANS = {
        name: 'Kesseboehmer LeMans II',
        x: { 40 => 426, 45 => 476, 50 => 526, 60 => 626 },
        korpus_min: { 40 => 764, 45 => 800, 50 => 910, 60 => 960 },
        lager: { d: 5, tiefe: 13, vorn: 69 },
        lager_schraube: { d: 3, tiefe: 10, vorn: 37, seitlich: 16 },
        profil: { d: 5, tiefe: 13, vorn: 52, unten: 28, raster: 64, anzahl: 8 },
        tiefe_min: 500, strebe_min: 60
      }.freeze

      def self.lemans?(teile)
        sd = Schraenke.definition(teile.first.teil.schrank)
        eckschrank?(teile) && sd.get_attribute(JT_DICT, 'beschlag') == LEMANS[:name] &&
          sd.get_attribute(DC_DICT, 'variante').to_f.round == 2
      end

      def self.lemans(teile, meldungen)
        sd = Schraenke.definition(teile.first.teil.schrank)
        groesse = sd.get_attribute(DC_DICT, 'lemans').to_f.round
        x = LEMANS[:x][groesse]
        unless x
          meldungen << "LeMans #{groesse} gibt es nicht (40, 45, 50, 60)"
          return
        end
        # Blindseite links (0) -> Tür und Beschlag rechts
        tuerseite = sd.get_attribute(DC_DICT, 'blindseite').to_f > 0.5 ? 'SeiteL' : 'SeiteR'
        s = teile.find { |w| w.teil.jt('teil') == tuerseite } or return
        andere = teile.find { |w| w.rolle == 'Seite' && !w.equal?(s) } or return
        boden = teile.find { |w| w.rolle == 'Boden' } or return
        strebe = teile.find { |w| w.teil.jt('teil') == 'StrebeVorn' }
        k = s.dicke_achse
        t = ([0, 1, 2] - [k, 2]).first
        mitte = ->(w, i) { (w.lo[i] + w.hi[i]) / 2.0 }
        nach_max = mitte.(andere, k) > mitte.(s, k)
        seite, flaeche = flaeche_innen(s, k, nach_max)
        richtung = nach_max ? 1 : -1
        f = teile.find { |w| %w[Front Tuer].include?(w.rolle) }
        vorn_max = f && mitte.(f, t) > mitte.(s, t)
        vorne, dir = vorn_max ? [s.hi[t], -1] : [s.lo[t], 1]

        # Seitenprofil
        pr = LEMANS[:profil]
        pr[:anzahl].times do |i|
          p = punkt(k => flaeche, t => vorne + dir * pr[:vorn], 2 => boden.hi[2] + pr[:unten] + i * pr[:raster])
          s.ops << Op.new(:bohrung, seite, p, nil, pr[:d], pr[:tiefe], nil, nil, 'Profil LeMans')
        end

        # Säulenlager unten (durch den Boden, von unten) und oben (Unterseite Strebe vorn)
        sx = flaeche + richtung * x
        la, ls = LEMANS[:lager], LEMANS[:lager_schraube]
        [[boden, :durch], [strebe, :unten]].each do |w, art|
          next unless w
          z = w.lo[2]
          tief = ->(normal) { art == :durch ? w.mass(2) + DURCH : normal }
          w.ops << Op.new(:bohrung, :zmin, punkt(k => sx, t => vorne + dir * la[:vorn], 2 => z), nil, la[:d], tief.(la[:tiefe]),
                          nil, nil, 'Lager LeMans')
          [-1, 1].each do |sg|
            w.ops << Op.new(:bohrung, :zmin, punkt(k => sx + sg * ls[:seitlich], t => vorne + dir * ls[:vorn], 2 => z), nil,
                            ls[:d], tief.(ls[:tiefe]), nil, nil, 'Lager LeMans Schraube')
          end
        end

        # Mindestmaße laut Montageanleitung
        breite = [s.hi[k], andere.hi[k]].max - [s.lo[k], andere.lo[k]].min
        rw = teile.select { |w| w.rolle == 'Rueckwand' }.map { |w| vorn_max ? vorne - w.hi[t] : w.lo[t] - vorne }.select(&:positive?).min
        tiefe = rw || (s.hi[t] - s.lo[t])
        { "Korpusbreite für LeMans #{groesse}" => [breite, LEMANS[:korpus_min][groesse]], 'Tiefe' => [tiefe, LEMANS[:tiefe_min]],
          'Strebe vorn' => [strebe ? strebe.hi[t] - strebe.lo[t] : 0, LEMANS[:strebe_min]] }.each do |was, (ist, min)|
          meldungen << "#{s.name}: #{was} #{ist.round(1)} mm, LeMans II braucht mindestens #{min} mm" if ist < min - TOL
        end
      end

      # Sockelfüße: Bohrbild aus Boden.tcn in der Unterseite des Bodens,
      # x entlang der längeren Plattenrichtung (wie DL). L-Boden (Eckschrank): je Schenkel
      # ein Rechteck, so stehen Füße an beiden Enden und an der Innenecke
      def self.sockelfuesse(w)
        lo = (0..2).map { |a| w.lo_f(a) }
        hi = (0..2).map { |a| w.hi_f(a) }
        e = ecke_rechteck(w)
        return sockelfuesse_rechteck(w, lo, hi) unless e
        a, b = w.flaechen_achsen
        # Schenkel 1: ganze Länge in a, in b neben der Ecke
        l1, h1 = lo.dup, hi.dup
        e[:aussen][b] == :lo ? l1[b] = e[:innen][b] : h1[b] = e[:innen][b]
        # Schenkel 2: in b auf Höhe der Ecke, in a neben ihr
        l2, h2 = lo.dup, hi.dup
        e[:aussen][b] == :lo ? h2[b] = e[:innen][b] : l2[b] = e[:innen][b]
        e[:aussen][a] == :lo ? l2[a] = e[:innen][a] : h2[a] = e[:innen][a]
        sockelfuesse_rechteck(w, l1, h1)
        sockelfuesse_rechteck(w, l2, h2)
      end

      def self.sockelfuesse_rechteck(w, lo, hi)
        k = w.dicke_achse
        ax = w.flaechen_achsen.max_by { |a| [hi[a] - lo[a], -a] }
        ay = (w.flaechen_achsen - [ax]).first
        f = SOCKELFUSS
        xs = [[lo[ax] + f[:rand_x], lo[ax] + f[:rand_x] + f[:raster]],
              [hi[ax] - f[:rand_x] - f[:raster], hi[ax] - f[:rand_x]]]
        ys = [lo[ay] + f[:rand_y], lo[ay] + f[:rand_y] + f[:raster],
              hi[ay] - f[:rand_y], hi[ay] - f[:rand_y] - f[:raster]]
        # schmaler Boden (z. B. 112 mm beim Handtuchschrank): nur ein Fuß je Ende, mittig
        if hi[ay] - lo[ay] < 2 * (f[:rand_y] + f[:raster])
          m = (lo[ay] + hi[ay]) / 2.0
          ys = [m - f[:raster] / 2.0, m + f[:raster] / 2.0]
        end
        xs.each do |x0, x1|
          ys.each do |y|
            w.ops << Op.new(:reihe, :"#{Geometrie::ACHSEN[k]}min", punkt(k => w.lo[k], ax => x0, ay => y),
                            punkt(k => w.lo[k], ax => x1, ay => y), f[:d], f[:tiefe], f[:raster], false, 'Sockelfuss')
          end
        end
      end

      # Schritt für eine Reihe über die Länge l mit höchstens max Abstand: n = ceil(l / max) + 1 Dübel,
      # ST = l / (n - 1), auf 4 Stellen abgerundet, damit der letzte Dübel nicht hinter das Ende rutscht
      def self.schritt(l, max)
        return l if l < TOL
        l = l.to_f
        st = l / ((l / max - 1e-9).ceil)
        (st * 10_000 + 1e-6).floor / 10_000.0
      end

      # k: Achse, entlang der A an B stößt (Standard: auf die Fläche von B; beim Eckschrank auch
      # an eine Kante von B), tiefe_b: Dübeltiefe in B
      def self.stoss(a, b, regel, meldungen, k = b.dicke_achse, tiefe_b = DUEBEL[:tiefe_flaeche])
        return if k == a.dicke_achse
        if (a.lo[k] - b.hi[k]).abs < TOL
          sa, sb, kp = :"#{Geometrie::ACHSEN[k]}min", :"#{Geometrie::ACHSEN[k]}max", b.hi[k]
        elsif (a.hi[k] - b.lo[k]).abs < TOL
          sa, sb, kp = :"#{Geometrie::ACHSEN[k]}max", :"#{Geometrie::ACHSEN[k]}min", b.lo[k]
        else
          return
        end
        andere = (0..2).reject { |i| i == k }
        return unless andere.all? { |i| [a.hi[i], b.hi[i]].min - [a.lo[i], b.lo[i]].max > 1.0 }

        ca = a.dicke_achse
        la = (andere - [ca]).first
        # Böden/Deckel: Rand ab der fertigen Kante (mit Anleimer), sonst ab dem Fräsmaß wie in den Vorlagen
        lo = regel[:fertig] ? [a.lo[la], b.lo[la]].max : [a.lo_f(la), b.lo_f(la)].max
        hi = regel[:fertig] ? [a.hi[la], b.hi[la]].min : [a.hi_f(la), b.hi_f(la)].min
        if hi - lo < 2 * regel[:rand]
          meldungen << "#{a.name} an #{b.name}: Stoß nur #{(hi - lo).round(1)} mm lang, keine Dübel"
          return
        end
        pt = lambda do |l|
          p = [0.0, 0.0, 0.0]
          p[k] = kp
          p[ca] = (a.lo[ca] + a.hi[ca]) / 2.0
          p[la] = l
          p
        end
        p0 = pt.(lo + regel[:rand])
        p1 = pt.(hi - regel[:rand])
        raster, verteilt = regel[:max_abstand] ? [schritt(hi - lo - 2 * regel[:rand], regel[:max_abstand]), false] : regel.values_at(:raster, :verteilt)
        titel = "Duebel #{b.teil.jt('teil')}"
        a.ops << Op.new(:reihe, sa, p0, p1, DUEBEL[:d], DUEBEL[:tiefe_kante], raster, verteilt, titel)
        b.ops << Op.new(:reihe, sb, p0, p1, DUEBEL[:d], tiefe_b, raster, verteilt,
                        "Duebel #{a.teil.jt('teil')}")
        return unless regel[:schraube]
        b.ops << Op.new(:bohrung, sb, pt.((lo + hi) / 2.0), nil, SCHRAUBE[:d], SCHRAUBE[:tiefe], nil, nil,
                        "Schraube #{a.teil.jt('teil')}")
      end

      # Fläche 1 (oben auf der Maschine): die große Fläche mit den meisten Bohrungen,
      # bei Gleichstand die obere bzw. die Seite zur größeren Koordinate
      def self.flaeche1(w)
        a = w.dicke_achse
        mn, mx = :"#{Geometrie::ACHSEN[a]}min", :"#{Geometrie::ACHSEN[a]}max"
        w.ops.count { |o| o.seite == mn } > w.ops.count { |o| o.seite == mx } ? mn : mx
      end
    end
  end
end
