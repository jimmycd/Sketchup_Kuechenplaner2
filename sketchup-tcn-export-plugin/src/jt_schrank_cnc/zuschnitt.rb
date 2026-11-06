# encoding: UTF-8
# Schrank-CNC – Zuschnittplan für die Formatsäge.
#
# Je Material und Stärke verteilt der Guillotine-Optimierer (guillotine.rb) die Rohmaße
# der Stückliste auf Platten: nur durchgehende Schnitte in 2 oder 3 Stufen, wie an der
# Formatsäge. Optionen: Faserrichtung, Plattenreste,
# Abstand (Schnittbreite), Randabfall, erster Schnitt, Schnitttyp, Anzahl Stufen,
# Mindestgröße für Reste. Plattenformat und Plattenreste je Material und Stärke (am Material
# gespeichert je Stärke, Wörterbuch JT_Zuschnitt; sonst std_sizes im Material-Wörterbuch, sonst
# 2800 × 2070). Arbeitsplatten bleiben draußen (Zuschnitt von Hand).
# Ausgabe: Zuschnitt.pdf, A4 quer: Übersicht, dann je Platte eine Seite mit großer
# maßstäblicher Grafik (Tag, Nummer und Maß auf jedem Teil, Schnitte nummeriert,
# Reste schraffiert), Schnitt- und Teileliste nur auf Wunsch auf einer eigenen Seite.

module JTools
  module SchrankCnc
    module Zuschnitt
      module_function

      G = Guillotine
      OCL_DICT = 'ladb_opencutlist'.freeze
      DICT = 'JT_Zuschnitt'.freeze
      STANDARD_PLATTE = [2800.0, 2070.0].freeze
      FASER = ['wie Material', 'beachten', 'ignorieren'].freeze
      SEITE = [297.0, 210.0].freeze # A4 quer

      # Schlüssel => [Beschriftung im Fenster, Standard, Auswahl]
      OPTIONEN = {
        'zs_faser' => ['Optimierung: Faserrichtung', 'wie Material', FASER.join('|')],
        'schnittbreite' => ['Optimierung: Abstand / Schnittbreite (mm)', 3.0, nil],
        'besaeumen' => ['Optimierung: Randabfall je Plattenkante (mm)', 10.0, nil],
        'zs_erster' => ['Optimierung: Erster Schnitt', 'beliebig', G::ERSTER.join('|')],
        'zs_typ' => ['Optimierung: Schnitttyp', 'nicht exakt', G::TYPEN.join('|')],
        'zs_stufen' => ['Optimierung: Anzahl Stufen', '3', '2|3'],
        'zs_rest_l' => ['Optimierung: Reste behalten ab Länge (mm)', 300.0, nil],
        'zs_rest_b' => ['Optimierung: Reste behalten ab Breite (mm)', 100.0, nil],
        'zs_gleiche' => ['Darstellung: Gleiche Platten zusammenfassen', 'ja', 'ja|nein'],
        'zs_tabelle' => ['Darstellung: Schnitt- und Teileliste', 'keine', 'keine|eigene Seite je Platte'],
        'zs_nummern' => ['Darstellung: Schnittnummern in der Grafik', 'ja', 'ja|nein'],
        'zs_farbe' => ['Darstellung: Teile einfärben (je Schrank)', 'nein', 'ja|nein'],
        'zs_kanten' => ['Darstellung: Anleimer anzeigen', 'nein', 'ja|nein']
      }.freeze

      Gruppe = Struct.new(:material, :ds, :format, :reste, :maserung, :platten, :nicht_platziert, :fehler)

      # --- Optionen ---

      def optionen_lesen
        OPTIONEN.each_with_object({}) do |(k, (_, std, _)), h|
          if Einstellungen::WERTE.key?(k)
            h[k] = Einstellungen.wert(k)
            next
          end
          v = Sketchup.read_default(Einstellungen::SEKTION, k, nil)
          h[k] = if v.nil? then std
                 elsif std.is_a?(Float) then v.to_s.tr(',', '.').to_f
                 else v.to_s
                 end
        end
      end

      def optionen_speichern(o)
        o.each do |k, v|
          next unless OPTIONEN.key?(k)
          if Einstellungen::WERTE.key?(k)
            Einstellungen.setzen(k, v)
          else
            Sketchup.write_default(Einstellungen::SEKTION, k, v)
          end
        end
      end

      def ja?(v)
        v.to_s.strip.downcase.start_with?('j')
      end

      def guillotine_optionen(o)
        G::Optionen.new(o['schnittbreite'].to_f, o['besaeumen'].to_f, o['zs_erster'], o['zs_typ'],
                        o['zs_stufen'].to_i == 2 ? 2 : 3, o['zs_rest_l'].to_f, o['zs_rest_b'].to_f)
      end

      # --- Plattenformat und Plattenreste je Material ---

      # "2800 x 2070" oder "2800mm x 2070mm" → [2800.0, 2070.0] (längere Seite zuerst), sonst nil
      def format_lesen(s)
        teile = s.to_s.split(/[x×*]/i).map { |t| Fraesliste.mm(t.strip) }
        teile.size == 2 && teile.all? { |v| v > 0 } ? teile.sort.reverse : nil
      end

      # "1200 x 600 x 2; 800 x 400" → [[1200, 600, 2], [800, 400, 1]]; Fehler → ArgumentError
      def reste_lesen(s)
        s.to_s.split(/[;\n]/).map(&:strip).reject(&:empty?).map do |e|
          t = e.split(/[x×*]/i).map(&:strip)
          zahlen = t.map { |v| v.tr(',', '.').sub(/\s*mm\z/, '') }
          unless [2, 3].include?(t.size) && zahlen.all? { |v| v =~ /\A\d+(\.\d+)?\z/ }
            raise ArgumentError, "Plattenrest „#{e}“: bitte L x B oder L x B x Anzahl"
          end
          l, b = zahlen[0, 2].map(&:to_f).sort.reverse
          [l, b, (zahlen[2] || 1).to_i]
        end
      end

      def reste_text(reste)
        reste.map { |l, b, n| "#{Tcn.n(l)} x #{Tcn.n(b)}#{n == 1 ? '' : " x #{n}"}" }.join('; ')
      end

      # Plattenformat: eigenes Attribut, sonst std_sizes im Material-Wörterbuch (erstes Format ohne Anzahl), sonst Standard
      # Schlüssel am Material: je Stärke eigener Eintrag (platte_19 / reste_19), sonst allgemein
      def attr(mat, k, ds)
        v = ds && mat.get_attribute(DICT, "#{k}_#{Tcn.n(ds)}")
        v.nil? ? mat.get_attribute(DICT, k) : v
      end

      def plattenformat(mat, ds = nil)
        eigen = mat && format_lesen(attr(mat, 'platte', ds))
        return eigen if eigen
        std = mat ? mat.get_attribute(OCL_DICT, 'std_sizes').to_s.split(';') : []
        std.each do |s|
          next if s.split(/x/i).size > 2
          f = format_lesen(s)
          return f if f
        end
        STANDARD_PLATTE.dup
      end

      # Plattenreste: eigenes Attribut, sonst Einträge mit Anzahl aus std_sizes
      def plattenreste(mat, ds = nil)
        return [] unless mat
        eigen = attr(mat, 'reste', ds)
        return (reste_lesen(eigen) rescue []) unless eigen.nil?
        mat.get_attribute(OCL_DICT, 'std_sizes').to_s.split(';').select { |s| s.split(/x/i).size == 3 }.map do |s|
          l, b, n = s.split(/x/i).map(&:strip)
          [*[Fraesliste.mm(l), Fraesliste.mm(b)].sort.reverse, n.to_i]
        end.select { |l, b, n| l > 0 && b > 0 && n > 0 }
      end

      def material(model, name)
        model.materials.to_a.find { |m| m.name.to_s == name }
      end

      # --- Berechnung ---

      def maserung?(z, o)
        case o['zs_faser']
        when 'beachten' then true
        when 'ignorieren' then false
        else z.maserung
        end
      end

      def gruppe(zs, material, ds, mat, o, format: nil, reste: nil)
        format ||= plattenformat(mat, ds)
        reste ||= plattenreste(mat, ds)
        maserung = zs.any? { |z| maserung?(z, o) }
        g = Gruppe.new(material, ds, format, reste, maserung, [], [], nil)
        stuecke = zs.flat_map do |z|
          (1..z.anzahl).map { |i| G::Stueck.new(z.roh[0].to_f, z.roh[1].to_f, !maserung?(z, o), z.nr, [z, i, z.anzahl]) }
        end
        lager = reste.map { |l, b, n| G::Lager.new(l, b, n, true) } + [G::Lager.new(format[0], format[1], nil, false)]
        platten, offen = G.packen(stuecke, lager, guillotine_optionen(o))
        g.platten = platten
        g.nicht_platziert = offen.map(&:daten)
        g.fehler = 'kein Teil passt auf die Platte' if platten.empty? && !offen.empty?
        g
      end

      # Gruppen je [Material, Stärke], ohne Arbeitsplatten und Teile ohne Material.
      # formate: { [material, ds] => [format, reste] } überschreibt die Werte am Material
      def berechnen(model, zs, o = optionen_lesen, formate = {})
        zs.reject { |z| z.hinweis == 'Arbeitsplatte' || z.material.empty? }
          .group_by { |z| [z.material, z.ds] }
          .map do |(m, ds), g|
            f, r = formate[[m, ds]]
            gruppe(g, m, ds, material(model, m), o, format: f, reste: r)
          end
      end

      def meldungen_zu(gruppen, zs)
        m = gruppen.reject { |g| g.nicht_platziert.empty? }.map do |g|
          "#{g.material} #{zahl(g.ds)} mm: #{g.nicht_platziert.size} Teile passen nicht auf die Platte#{g.fehler ? " (#{g.fehler})" : ''}"
        end
        n = zs.count { |z| z.hinweis == 'Arbeitsplatte' }
        m << "#{n} Arbeitsplatte(n) nicht im Zuschnittplan (von Hand)" if n > 0
        m
      end

      def erzeugen(model, auswahl: nil, optionen: optionen_lesen, formate: {})
        zs, meldungen = Stueckliste.erzeugen(model, auswahl: auswahl)
        gruppen = berechnen(model, zs, optionen, formate)
        [gruppen, meldungen + meldungen_zu(gruppen, zs)]
      end

      # Platten einer Gruppe für die Ausgabe: [[Platte, [Nummern]], …]; gleiche zusammengefasst
      def layouts(g, zusammen)
        nrn = g.platten.each_with_index.map { |p, i| [p, i + 1] }
        return nrn.map { |p, n| [p, [n]] } unless zusammen
        nrn.group_by { |p, _| [p.rest, p.signatur] }.values.map { |l| [l.first[0], l.map(&:last)] }
      end

      # --- Texte ---

      def zahl(v)
        Stueckliste.zahl(v)
      end

      def stueck_text(z, i, n)
        "Nr #{z.nr}#{n > 1 ? " (#{i}/#{n})" : ''}"
      end

      def stufe_text(s)
        s.stufe.zero? ? 'Besäumen' : "Stufe #{s.stufe}"
      end

      def nummern_text(nrn)
        nrn.size == 1 ? nrn[0].to_s : (nrn.each_cons(2).all? { |a, b| b == a + 1 } ? "#{nrn.first}–#{nrn.last}" : nrn.join(', '))
      end

      def optionen_text(o)
        "Erster Schnitt #{o['zs_erster']}, #{o['zs_stufen'].to_i == 2 ? 2 : 3} Stufen, #{o['zs_typ']} · " \
          "Schnittbreite #{zahl(o['schnittbreite'])} mm · Randabfall #{zahl(o['besaeumen'])} mm · " \
          "Faserrichtung #{o['zs_faser']} · Reste ab #{zahl(o['zs_rest_l'])} × #{zahl(o['zs_rest_b'])} mm"
      end

      # --- PDF ---

      HELL = [[0.80, 0.90, 1.00], [1.00, 0.88, 0.75], [0.82, 0.95, 0.80], [0.98, 0.82, 0.88], [0.90, 0.85, 1.00],
              [1.00, 0.97, 0.75], [0.78, 0.95, 0.95], [0.93, 0.90, 0.82]].freeze
      ROT = [0.8, 0.0, 0.0].freeze

      def pdf(gruppen, o = optionen_lesen, titel: 'Zuschnittplan', meldungen: [])
        doc = Pdf.new(titel: titel)
        uebersicht(doc, gruppen, o, titel, meldungen)
        farben = {}
        gruppen.each do |g|
          ls = layouts(g, ja?(o['zs_gleiche']))
          ls.each do |p, nrn|
            platte_seite(doc, g, p, nrn, o, farben)
            listen_seiten(doc, g, p, nrn) if o['zs_tabelle'].to_s.start_with?('eigen')
          end
        end
        doc
      end

      def uebersicht(doc, gruppen, o, titel, meldungen)
        doc.seite(*SEITE)
        doc.text(10, 16, titel, groesse: 6, fett: true)
        doc.text(10, 23, optionen_text(o), groesse: 2.8, max: 277)
        doc.text(10, 28, 'Maße = Rohmaß (Fräsmaß + Übermaß). Ursprung links oben, Länge waagrecht. Nummern und Tags wie in Stückliste und Etiketten.', groesse: 2.8, max: 277)
        spalten = [['Material', 62, :links], ['Stärke', 16, :rechts], ['Platte', 30, :rechts], ['Faser', 18, :links],
                   ['Platten', 16, :rechts], ['davon Reste', 22, :rechts], ['Teile', 14, :rechts], ['Ausnutzung', 22, :rechts],
                   ['passt nicht', 77, :links]]
        zeilen = gruppen.map do |g|
          aus = g.platten.empty? ? '' : "#{zahl(g.platten.sum(&:belegt) * 100.0 / g.platten.sum(&:flaeche))} %"
          [g.material, zahl(g.ds), "#{zahl(g.format[0])} × #{zahl(g.format[1])}", g.maserung ? 'längs' : 'drehbar',
           g.platten.size.to_s, g.platten.count(&:rest).to_s, g.platten.sum { |p| p.teile.size }.to_s, aus,
           g.nicht_platziert.map { |z, i, n| stueck_text(z, i, n) }.join(', ')]
        end
        y = tabelle(doc, 10, 36, spalten, zeilen, 200)
        behalten = gruppen.flat_map { |g| g.platten.flat_map { |p| p.reste.select(&:behalten).map { |r| [g, r] } } }
        unless behalten.empty?
          y += 6
          doc.text(10, y, 'Reste zum Behalten', groesse: 3.4, fett: true)
          y += 5
          behalten.group_by { |g, r| [g.material, g.ds] }.each do |(m, ds), l|
            t = l.map { |_, r| "#{zahl([r.l, r.b].max)} × #{zahl([r.l, r.b].min)}" }.tally.map { |s, n| n > 1 ? "#{n}× #{s}" : s }.join(', ')
            doc.text(10, y, "#{m} #{zahl(ds)} mm: #{t}", groesse: 2.8, max: 277)
            y += 4.2
            break if y > 195
          end
        end
        return if meldungen.empty?
        y += 6
        meldungen.first(12).each do |m|
          break if y > 204
          doc.text(10, y, m, groesse: 2.8, farbe: [0.7, 0, 0], max: 277)
          y += 4.2
        end
      end

      # Einfache Tabelle (Pdf#tabelle); gibt die y-Position unter der letzten Zeile zurück
      def tabelle(doc, x, y, spalten, zeilen, y_max)
        doc.tabelle(x, y, spalten, zeilen, y_max).first
      end

      def kopf(doc, g, p, nrn, zusatz = nil)
        art = p.rest ? 'Plattenrest' : 'Platte'
        t = "#{g.material} #{zahl(g.ds)} mm – #{art} #{nummern_text(nrn)} von #{g.platten.size}"
        t += " (#{nrn.size}× gleich)" if nrn.size > 1
        t += " – #{zusatz}" if zusatz
        doc.text(8, 11, t, groesse: 4.6, fett: true, max: 200)
        doc.text(289, 11, "#{zahl(p.l)} × #{zahl(p.b)} mm · Ausnutzung #{zahl(p.ausnutzung)} % · #{p.teile.size} Teile",
                 groesse: 3.2, ausrichtung: :rechts)
      end

      # Eine Platte als große Grafik mit Tag, Nummer und Maß auf jedem Teil
      def platte_seite(doc, g, p, nrn, o, farben)
        doc.seite(*SEITE)
        kopf(doc, g, p, nrn)
        doc.text(8, 16, optionen_text(o), groesse: 2.4, farbe: [0.35, 0.35, 0.35], max: 281)
        # Zeichenfläche
        x0 = 14.0
        y0 = 25.0
        m = [(289.0 - x0) / p.l, (205.0 - y0) / p.b].min
        px = ->(v) { x0 + v * m }
        py = ->(v) { y0 + v * m }
        kerf = o['schnittbreite'].to_f
        rd = o['besaeumen'].to_f
        # Maße der Platte
        doc.text(px.(p.l / 2.0), y0 - 1.5, "#{zahl(p.l)}", groesse: 3, ausrichtung: :mitte)
        doc.text(x0 - 1.5, py.(p.b / 2.0), "#{zahl(p.b)}", groesse: 3, ausrichtung: :mitte, drehung: 90)
        doc.rechteck(x0, y0, p.l * m, p.b * m, fuellung: [0.85, 0.85, 0.85], rand: nil)
        doc.rechteck(px.(rd), py.(rd), (p.l - 2 * rd) * m, (p.b - 2 * rd) * m, fuellung: [1, 1, 1], rand: nil) if rd > 0
        # Reste
        p.reste.each do |r|
          rx = px.(r.x)
          ry = py.(r.y)
          rw = r.l * m
          rh = r.b * m
          if r.behalten
            doc.rechteck(rx, ry, rw, rh, fuellung: [0.88, 0.96, 0.88], rand: [0.3, 0.6, 0.3], staerke: 0.15)
            doc.schraffur(rx, ry, rw, rh, abstand: 2.5, farbe: [0.55, 0.75, 0.55])
            gs = [[rh * 0.3, 2.6].min, 1.4].max
            if rw > 14 && rh > 4
              doc.text(rx + rw / 2.0, ry + rh / 2.0 + gs * 0.35, "Rest #{zahl(r.l)} × #{zahl(r.b)}", groesse: gs, fett: true,
                                                                                                       ausrichtung: :mitte, farbe: [0.15, 0.4, 0.15], max: rw - 1)
            elsif rh > 14 && rw > 4
              doc.text(rx + rw / 2.0 + gs * 0.35, ry + rh / 2.0, "Rest #{zahl(r.l)} × #{zahl(r.b)}", groesse: gs, fett: true,
                                                                                                       ausrichtung: :mitte, farbe: [0.15, 0.4, 0.15], drehung: 90, max: rh - 1)
            end
          else
            doc.schraffur(rx, ry, rw, rh, abstand: 2.0)
          end
        end
        # Teile
        p.teile.each do |t|
          z, i, n = t.stueck.daten
          tx = px.(t.x)
          ty = py.(t.y)
          tw = t.l * m
          th = t.b * m
          fuell = ja?(o['zs_farbe']) ? (farben[z.schrank.to_s] ||= HELL[farben.size % HELL.size]) : [1, 1, 1]
          doc.rechteck(tx, ty, tw, th, fuellung: fuell, rand: [0, 0, 0], staerke: 0.3)
          anleimer(doc, z, t, tx, ty, tw, th) if ja?(o['zs_kanten'])
          beschriften(doc, z, i, n, t, tx, ty, tw, th)
        end
        # Schnitte (Linie in der Mitte der Schnittfuge)
        p.schnitte.each do |s|
          x1 = s.horizontal ? s.x : s.x + kerf / 2.0
          y1 = s.horizontal ? s.y + kerf / 2.0 : s.y
          x2 = s.horizontal ? x1 + s.laenge : x1
          y2 = s.horizontal ? y1 : y1 + s.laenge
          if s.stufe.zero?
            x1, y1 = s.horizontal ? [0.0, s.y] : [s.x, 0.0]
            x2, y2 = s.horizontal ? [p.l, s.y] : [s.x, p.b]
          end
          st = { 0 => 0.15, 1 => 0.5, 2 => 0.35 }.fetch(s.stufe, 0.2)
          doc.linie(px.(x1), py.(y1), px.(x2), py.(y2), staerke: st, farbe: ROT, strich: s.stufe.zero? ? [1, 1] : nil)
        end
        return unless ja?(o['zs_nummern'])
        p.schnitte.each do |s|
          next if s.stufe.zero?
          cx = s.horizontal ? px.(s.x) + 2.2 : px.(s.x + kerf / 2.0)
          cy = s.horizontal ? py.(s.y + kerf / 2.0) : py.(s.y) + 2.2
          doc.kreis(cx, cy, 1.7, fuellung: ROT)
          doc.text(cx, cy + 0.75, s.nr.to_s, groesse: s.nr > 99 ? 1.6 : 2.1, fett: true, ausrichtung: :mitte, farbe: [1, 1, 1])
        end
      end

      # Tag groß, darunter Nummer und Maß; bei hohen, schmalen Teilen gedreht
      def beschriften(doc, z, i, n, t, tx, ty, tw, th)
        tag = z.tag.to_s
        zeile2 = "Nr #{z.nr}#{n > 1 ? " · #{i}/#{n}" : ''} · #{zahl(z.roh[0])} × #{zahl(z.roh[1])}"
        tb = Pdf.textbreite(tag, 1, true)
        groesse = lambda do |w, h|
          [(w - 1.5) / [tb, 1e-3].max, h * 0.42, 5.5].min
        end
        gw = groesse.(tw, th)
        gh = groesse.(th, tw)
        gedreht = gh > gw * 1.15 && th > tw
        g = [gedreht ? gh : gw, 1.3].max
        g2 = [g * 0.62, 1.2].max
        breit = gedreht ? th : tw
        hoch = gedreht ? tw : th
        return if hoch < 1.6 || breit < 3
        zwei = hoch >= g * 1.15 + g2 * 1.2
        if gedreht
          cx = tx + tw / 2.0
          cy = ty + th / 2.0
          if zwei
            doc.text(cx - g2 * 0.35, cy, tag, groesse: g, fett: true, ausrichtung: :mitte, drehung: 90, max: breit - 1)
            doc.text(cx + g2 * 1.05, cy, zeile2, groesse: g2, ausrichtung: :mitte, drehung: 90, max: breit - 1)
          else
            doc.text(cx + g * 0.35, cy, tag, groesse: g, fett: true, ausrichtung: :mitte, drehung: 90, max: breit - 1)
          end
        else
          cx = tx + tw / 2.0
          cy = ty + th / 2.0
          if zwei
            doc.text(cx, cy - g2 * 0.35, tag, groesse: g, fett: true, ausrichtung: :mitte, max: breit - 1)
            doc.text(cx, cy + g2 * 1.05, zeile2, groesse: g2, ausrichtung: :mitte, max: breit - 1)
          else
            doc.text(cx, cy + g * 0.35, tag, groesse: g, fett: true, ausrichtung: :mitte, max: breit - 1)
          end
        end
      end

      # Anleimer als dicke Linie innen an der Kante. Nicht gedreht: L waagrecht,
      # L1 unten, L2 oben, B1 links, B2 rechts; gedreht: L1 links, L2 rechts, B1 oben, B2 unten
      def anleimer(doc, z, t, tx, ty, tw, th)
        d = 0.5
        kanten = if t.gedreht
                   { l1: [tx + d, ty, tx + d, ty + th], l2: [tx + tw - d, ty, tx + tw - d, ty + th],
                     b1: [tx, ty + d, tx + tw, ty + d], b2: [tx, ty + th - d, tx + tw, ty + th - d] }
                 else
                   { l1: [tx, ty + th - d, tx + tw, ty + th - d], l2: [tx, ty + d, tx + tw, ty + d],
                     b1: [tx + d, ty, tx + d, ty + th], b2: [tx + tw - d, ty, tx + tw - d, ty + th] }
                 end
        kanten.each do |k, (x1, y1, x2, y2)|
          doc.linie(x1, y1, x2, y2, staerke: 0.7, farbe: [0.15, 0.3, 0.75]) if z.kanten[k]
        end
      end

      # Schnittliste und Teileliste der Platte auf eigener Seite (bei Bedarf mehrere)
      def listen_seiten(doc, g, p, nrn)
        schnitte = p.schnitte.map do |s|
          bei = s.horizontal ? "y = #{zahl(s.y)}" : "x = #{zahl(s.x)}"
          ab = s.horizontal ? "x = #{zahl(s.x)}" : "y = #{zahl(s.y)}"
          [s.nr.to_s, stufe_text(s), s.horizontal ? 'längs' : 'quer', bei, ab, zahl(s.laenge)]
        end
        teile = p.teile.sort_by { |t| [t.stueck.daten[0].nr, t.stueck.daten[1]] }.map do |t|
          z, i, n = t.stueck.daten
          [stueck_text(z, i, n).sub('Nr ', ''), z.tag.to_s, "#{zahl(z.roh[0])} × #{zahl(z.roh[1])}", t.gedreht ? 'ja' : '']
        end
        sp_s = [['Nr', 10, :rechts], ['Stufe', 20, :links], ['Richtung', 16, :links], ['bei', 24, :rechts], ['ab', 24, :rechts], ['Länge', 18, :rechts]]
        sp_t = [['Nr', 14, :rechts], ['Tag', 60, :links], ['Rohmaß L × B', 32, :rechts], ['gedreht', 14, :links]]
        pro_seite = 39
        seiten = [(schnitte.size / pro_seite.to_f).ceil, (teile.size / pro_seite.to_f).ceil, 1].max
        seiten.times do |k|
          doc.seite(*SEITE)
          kopf(doc, g, p, nrn, "Schnitt- und Teileliste#{seiten > 1 ? " #{k + 1}/#{seiten}" : ''}")
          tabelle(doc, 8, 18, sp_s, schnitte[k * pro_seite, pro_seite] || [], 205)
          tabelle(doc, 130, 18, sp_t, teile[k * pro_seite, pro_seite] || [], 205)
        end
      end

      def schreiben(ordner, gruppen, o = optionen_lesen, meldungen = [])
        p = File.join(ordner, 'Zuschnitt.pdf')
        pdf(gruppen, o, titel: "Zuschnittplan #{File.basename(ordner.to_s.tr('\\', '/'))}", meldungen: meldungen).schreiben(p)
      end

      # --- Fenster ---

      # Optionen und je Material Plattenformat und Plattenreste abfragen. Ruft den Block
      # mit Optionen und Formaten { [material, ds] => [format, reste] } auf.
      def abfragen(model, zs)
        o = optionen_lesen
        keys = OPTIONEN.keys
        labels = keys.map { |k| OPTIONEN[k][0] }
        werte = keys.map { |k| o[k].is_a?(Float) ? Tcn.n(o[k]) : o[k].to_s }
        listen = keys.map { |k| OPTIONEN[k][2] || '' }
        gruppen = zs.reject { |z| z.hinweis == 'Arbeitsplatte' || z.material.empty? }.map { |z| [z.material, z.ds] }.uniq
        gruppen.each do |m, ds|
          mat = material(model, m)
          f = plattenformat(mat, ds)
          kurz = "#{m.tr(':()', '   ').strip[0, 30]} #{zahl(ds)} mm"
          labels << "#{kurz}: Plattenformat (mm, L x B)" << "#{kurz}: Plattenreste (mm, L x B x Anzahl; … leer = keine)"
          werte << "#{Tcn.n(f[0])} x #{Tcn.n(f[1])}" << reste_text(plattenreste(mat, ds))
          listen << '' << ''
        end
        Kuechenplaner::Eingabe.abfragen(labels, werte, listen, 'Zuschnittplan', untertitel: 'Guillotine für die Formatsäge',
                                                                              ok: 'Plan erstellen') do |antwort|
          neu = {}
          keys.each_with_index do |k, i|
            s = antwort[i].to_s.strip
            if OPTIONEN[k][1].is_a?(Float)
              raise ArgumentError, "#{OPTIONEN[k][0].sub(/\A.*?: /, '')}: bitte eine Zahl ≥ 0" unless s.tr(',', '.') =~ /\A\d+(\.\d+)?\z/
              neu[k] = s.tr(',', '.').to_f
            else
              neu[k] = s
            end
          end
          formate = {}
          gruppen.each_with_index do |(m, ds), j|
            fs = antwort[keys.size + 2 * j].to_s
            f = format_lesen(fs)
            raise ArgumentError, "#{m} #{zahl(ds)} mm: Plattenformat „#{fs}“, bitte L x B" unless f
            r = reste_lesen(antwort[keys.size + 2 * j + 1])
            formate[[m, ds]] = [f, r]
          end
          optionen_speichern(neu)
          formate.each do |(m, ds), (f, r)|
            mat = material(model, m)
            next unless mat
            mat.set_attribute(DICT, "platte_#{Tcn.n(ds)}", "#{Tcn.n(f[0])} x #{Tcn.n(f[1])}")
            mat.set_attribute(DICT, "reste_#{Tcn.n(ds)}", reste_text(r))
          end
          yield neu, formate
        end
      end
    end
  end
end
