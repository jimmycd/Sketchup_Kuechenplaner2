# encoding: UTF-8
# Schrank-CNC – Andock-Werkzeug: neue Schränke an vorhandene Schränke oder an
# eine Wand setzen, statt sie von Hand zu verschieben und zu drehen.
#
# Nach dem Erzeugen hängt der Schrank als Vorschau (Kasten, Front rot) an der Maus:
#   * über einem Schrank: rastet links oder rechts bündig an dessen Seite ein,
#     übernimmt Drehung und Höhe (Rückwände bündig, Pfeil hoch/runter: Fronten bündig);
#   * über der Front eines Schranks: stellt sich quer davor, bündig mit dessen
#     linker oder rechter Seite (Ecke einer L- oder U-Küche, z. B. vor ein Blindeck);
#   * über einer Wand des Raums (Erweiterung Raum): Rückseite mit Wandabstand an die Wand, rastet an
#     Wandenden und Tür-/Durchgangslaibungen ein (Fang 100 mm); Unter- und Hochschränke
#     stehen auf Fußboden + Sockelhöhe, Oberschränke auf fester Höhe (Einstellungen);
#   * über einer anderen senkrechten Fläche: Rückseite daran, Mitte unter der Maus;
#   * Oberschrank über einem Unterschrank: darüber, links oder rechts bündig;
#   * sonst: folgt der Maus auf seiner Höhe (Oberschrank: nicht erlaubt).
#   Tab oder Pfeil rechts/links drehen um 90°, Klick setzt ab, Esc lässt ihn stehen.
# Beim Einfügen kommt der neue Schrank ohne Maus an das freie (rechte) Ende seiner Zeile:
# ausgehend vom ausgewählten Schrank, sonst vom zuletzt eingefügten der gleichen Art.
# Erst wenn es noch keine Zeile gibt, hängt er als Vorschau an der Maus.
#
# Regeln (Jürgen, 2026-11-02):
#   * Nachbarn berühren sich immer an der oberen Außenecke der Seiten (Seitenaußenfläche,
#     Seitenoberkante). Gemessen wird am Bezugskasten aus den Seiten (Rolle Seite, dazu
#     sichtbare Wangen); Geräteschränke ohne eigene Seite (Geschirrspüler, Unterbau-
#     Kühlschrank) bekommen eine virtuelle Seite aus Nischenbreite × Korpushöhe × Tiefe.
#     Fronten, Geräte, Arbeitsplatten zählen nicht mit.
#   * Hochschrank: gleiche Unterkante wie der Nachbar (steht auf dem Sockel).
#   * Oberschrank: nur an der Wand bzw. über einem Unterschrank, Höhe immer fest =
#     Seitenoberkante Unterschrank + Arbeitsplatte + Abstand Arbeitsplatte/Oberschrank
#     (Kuechenplaner::Einstellungen); keine freie Lage im Raum.
#   * an einer Raumwand: Unter-/Hochschränke auf Fußboden + Sockelhöhe, Rückseite mit
#     Wandabstand.
#
# Die Rechnung (Modul Rechnung) braucht kein SketchUp und ist getestet.
# Lage = [winkel, x, y, z]: Drehung um die senkrechte Achse (Bogenmaß), dann
# Verschiebung. Kasten = [x0, x1, y0, y1, z0, z1] in Schrank-Koordinaten:
# x = Breite (links → rechts), y = Tiefe (Front bei y0, Rückwand bei y1), z = Höhe.

module JTools
  module SchrankCnc
    module Andocken
      VIERTEL = Math::PI / 2
      MM = 1 / 25.4            # SketchUp rechnet in Zoll
      FANG = 100 * MM          # Einrasten an Wandenden und Laibungen

      TOLERANZ = 2 * MM        # gilt beim Suchen der Zeile noch als „berührt“
      # Rückfall, solange Kuechenplaner::Einstellungen fehlt (mm)
      VORGABEN = { sockelhoehe: 100.0, wandabstand: 0.0, abstand_oberschrank: 550.0,
                   arbeitsplatte_staerke: 40.0, unterschrank_hoehe: 700.0 }.freeze
      RAUM_DICT = 'JT_Raum'.freeze

      module Rechnung
        module_function

        # Winkel nahe einem Vielfachen von 90° genau darauf setzen
        def winkel(w)
          v = w / VIERTEL
          w = v.round * VIERTEL if (v - v.round).abs < 1e-6
          w % (2 * Math::PI)
        end

        def cs(w)
          w = winkel(w)
          v = w / VIERTEL
          return [[1, 0], [0, 1], [-1, 0], [0, -1]][v.round % 4] if (v - v.round).abs < 1e-9
          [Math.cos(w), Math.sin(w)]
        end

        def drehe(w, x, y)
          c, s = cs(w)
          [x * c - y * s, x * s + y * c]
        end

        # Schrankpunkt (lx, ly) → Welt (x, y)
        def welt(lage, lx, ly)
          dx, dy = drehe(lage[0], lx, ly)
          [lage[1] + dx, lage[2] + dy]
        end

        # Weltpunkt → Schrankkoordinaten
        def lokal(lage, x, y)
          drehe(-lage[0], x - lage[1], y - lage[2])
        end

        # Grundriss des Kastens, um rel gedreht: [x0, x1, y0, y1]
        def rechteck(kasten, rel)
          ecken = [[kasten[0], kasten[2]], [kasten[1], kasten[2]], [kasten[0], kasten[3]], [kasten[1], kasten[3]]]
                  .map { |x, y| drehe(rel, x, y) }
          xs = ecken.map(&:first)
          ys = ecken.map(&:last)
          [xs.min, xs.max, ys.min, ys.max]
        end

        # Welche Seite des Nachbarn ist gemeint? lx = Mauspunkt in dessen Koordinaten,
        # vorne = Maus steht auf seiner Front.
        def seite(lx, nkasten, vorne)
          rechts = lx > (nkasten[0] + nkasten[1]) / 2.0
          if vorne
            rechts ? :vorne_rechts : :vorne_links
          else
            rechts ? :rechts : :links
          end
        end

        # Drehung gegenüber dem Nachbarn in Vierteln (0..3). Vor einer Front steht der
        # neue Schrank immer quer (Rückseite in der Flucht der Nachbarseite).
        def viertel(seite, drehung)
          d = drehung % 4
          return d unless [:vorne_links, :vorne_rechts].include?(seite)
          return d if d.odd?
          seite == :vorne_rechts ? 3 : 1
        end

        # Lage des neuen Schranks (Kasten k) am Nachbarn (Kasten n, Lage nl).
        # buendig :hinten = Rückwände in einer Flucht, :vorne = Fronten.
        # Liefert [winkel, x, y]; die Höhe kommt aus #hoehe.
        def an_nachbar(k, n, nl, seite, viertel, buendig = :hinten)
          rel = viertel * VIERTEL
          r = rechteck(k, rel)
          case seite
          when :rechts, :links
            ox = seite == :rechts ? n[1] - r[0] : n[0] - r[1]
            oy = buendig == :vorne ? n[2] - r[2] : n[3] - r[3]
          else
            # quer vor der Front: hinten an die Front, seitlich bündig mit dem Nachbarn
            oy = n[2] - r[3]
            ox = seite == :vorne_rechts ? n[1] - r[1] : n[0] - r[0]
          end
          x, y = welt(nl, ox, oy)
          [winkel(nl[0] + rel), x, y]
        end

        # Höhe (z der Lage) am Nachbarn, k/n = Bezugskästen. v = Vorgaben in Zoll:
        # sockel, aufbau (Arbeitsplatte + Abstand bis Oberschrank), ober (Fußboden bis
        # Unterkante Oberschrank), boden (Fußboden), decke (Decke oder nil).
        #   Unter-/Hochschrank: immer auf Fußboden + Sockel (Jürgen 2026-11-03: Sockelhöhe fest,
        #     keine andere Höhe), egal neben welchem Schrank
        #   Oberschrank: Unterkante fest – neben Oberschrank gleiche Unterkante,
        #     neben Hochschrank Fußboden + ober, über/neben Unterschrank Seitenoberkante + aufbau;
        #     höchstens bis unter die Decke
        def hoehe(k, kat, n, nz, nkat, eigene_z, v = nil)
          v ||= vorgaben_zoll(VORGABEN)
          return sockel_z(k, v) unless kat == 'Oberschrank'
          z = if nkat == 'Oberschrank' then nz + n[4] - k[4]
              elsif nkat == 'Hochschrank' then (v[:boden] || 0) + v[:ober] - k[4]
              else nz + n[5] + v[:aufbau] - k[4]
              end
          unter_decke(z, k, v)
        end

        # Unter-/Hochschrank: Seitenunterkante auf Fußboden + Sockel
        def sockel_z(k, v)
          (v[:boden] || 0) + v[:sockel] - k[4]
        end

        # Oberschrank höchstens bis zur Decke
        def unter_decke(z, k, v)
          v[:decke] ? [z, v[:decke] - k[5]].min : z
        end

        # Vorgaben (mm, Schlüssel wie VORGABEN) → Zoll für #hoehe
        def vorgaben_zoll(m)
          platte = m[:arbeitsplatte_staerke].to_f + m[:abstand_oberschrank].to_f
          { sockel: m[:sockelhoehe].to_f * MM, aufbau: platte * MM, wand: m[:wandabstand].to_f * MM,
            ober: (m[:sockelhoehe].to_f + m[:unterschrank_hoehe].to_f + platte) * MM, boden: 0.0, decke: nil }
        end

        # Oberschrank über einem Unterschrank (Bezug n, Lage nl): Rückseiten in einer Flucht,
        # linke bzw. rechte Seite bündig, Unterkante = Seitenoberkante + aufbau.
        # Liefert die ganze Lage [winkel, x, y, z].
        def ueber_unterschrank(k, n, nl, rechts, aufbau)
          ox = rechts ? n[1] - k[1] : n[0] - k[0]
          x, y = welt(nl, ox, n[3] - k[3])
          [winkel(nl[0]), x, y, nl[3] + n[5] + aufbau - k[4]]
        end

        # --- freier Platz ------------------------------------------------------------
        # hindernisse = [[lage, [x0, x1, y0, y1]], …] (Wände, andere Schränke) im Grundriss.
        # Platz, wenn der Grundriss des Kastens k in Lage l keines davon um mehr als tol
        # überlappt (Berühren ist erlaubt). Gerechnet im System des Hindernisses.
        def platz?(k, l, hindernisse, tol = TOLERANZ)
          ecken = [[k[0], k[2]], [k[1], k[2]], [k[1], k[3]], [k[0], k[3]]].map { |x, y| welt(l, x, y) }
          hindernisse.none? do |hl, hb|
            pts = ecken.map { |x, y| lokal(hl, x, y) }
            xs = pts.map(&:first)
            ys = pts.map(&:last)
            xs.max > hb[0] + tol && xs.min < hb[1] - tol && ys.max > hb[2] + tol && ys.min < hb[3] - tol
          end
        end

        # --- Bezugskasten -------------------------------------------------------------
        # seiten/wangen: Kästen der sichtbaren Seiten bzw. Wangen im Schranksystem,
        # virtuell: Kasten aus den Maßen (Schränke ohne eigene Seite), rest: alle sichtbaren Teile.
        # x und Höhe kommen von den Seiten (sonst virtuell), Wangen verbreitern nur in x und
        # verlängern nach hinten (sie reichen bis zum Fußboden und zählen in z nicht).
        # hinten: Kästen der Rückwände, sie verlängern nur nach hinten (Rückseite an der Wand).
        def bezug(seiten, wangen, virtuell, rest, hinten = [])
          b = seiten.empty? ? virtuell : vereinigen(seiten)
          return rest if b.nil?
          b = b.dup
          hinten.each { |r| b[3] = [b[3], r[3]].max }
          wangen.each do |w|
            b[0] = [b[0], w[0]].min
            b[1] = [b[1], w[1]].max
            b[3] = [b[3], w[3]].max
          end
          b
        end

        def vereinigen(kaesten)
          (0..5).map { |i| kaesten.map { |q| q[i] }.send(i.even? ? :min : :max) }
        end

        # virtuelle Seite eines Geräteschranks: Nische ab x_nische, Breite × Korpushöhe,
        # Tiefe wie die Wangen (ab Materialstärke bis hinter die Rückwand)
        def virtuelle_seite(breite, hoehe, tiefe, x_nische = 0, mk = 0, rw = 0)
          [x_nische, x_nische + breite, mk, mk + tiefe + rw, 0.0, hoehe].map(&:to_f)
        end

        # 4×4-Matrizen wie Geom::Transformation#to_a (spaltenweise)
        def matmul(a, b)
          (0..15).map { |i| (0..3).sum { |j| a[j * 4 + i % 4] * b[(i / 4) * 4 + j] } }
        end

        def box_trafo(m, mn, mx)
          pts = [mn[0], mx[0]].product([mn[1], mx[1]], [mn[2], mx[2]]).map do |x, y, z|
            (0..2).map { |r| m[r] * x + m[4 + r] * y + m[8 + r] * z + m[12 + r] }
          end
          (0..2).flat_map { |i| [pts.map { |q| q[i] }.min, pts.map { |q| q[i] }.max] }
        end

        # --- Zeile -------------------------------------------------------------------
        # Steht Schrank b (Bezug kb, Lage lb) rechts an Schrank a? Gleiche Richtung, linke
        # Seite von b an der rechten Seite von a, Tiefe und Höhe überlappen.
        def rechts_an?(ka, la, kb, lb, tol = TOLERANZ)
          d = (winkel(lb[0]) - winkel(la[0])).abs
          return false unless d < 1e-6 || (d - 2 * Math::PI).abs < 1e-6
          bx, by = welt(lb, kb[0], kb[3])
          lx, ly = lokal(la, bx, by)
          return false unless (lx - ka[1]).abs <= tol
          return false unless ly > ka[2] - tol && ly - (kb[3] - kb[2]) < ka[3] + tol
          za = [la[3] + ka[4], la[3] + ka[5]]
          zb = [lb[3] + kb[4], lb[3] + kb[5]]
          zb[0] < za[1] - tol && zb[1] > za[0] + tol
        end

        # Ende der Zeile ab start (Index): schraenke = [[kasten, lage], …];
        # richtung :rechts oder :links. Liefert den Index des letzten Schranks.
        def zeilenende(schraenke, start, richtung = :rechts)
          i = start
          besucht = [i]
          loop do
            ka, la = schraenke[i]
            j = schraenke.each_index.find do |m|
              next false if besucht.include?(m)
              kb, lb = schraenke[m]
              richtung == :rechts ? rechts_an?(ka, la, kb, lb) : rechts_an?(kb, lb, ka, la)
            end
            return i unless j
            besucht << j
            i = j
          end
        end

        # Rückseite an eine Wand: punkt = Mauspunkt auf der Wand, normale = zeigt in den Raum.
        def an_wand(k, punkt, normale, abstand = 0)
          nx, ny = normale
          l = Math.sqrt(nx * nx + ny * ny)
          nx /= l
          ny /= l
          w = winkel(Math.atan2(nx, -ny)) # x-Achse des Schranks entlang der Wand
          mitte = (k[0] + k[1]) / 2.0
          dx, dy = drehe(w, mitte, k[3] + abstand)
          [w, punkt[0] - dx, punkt[1] - dy]
        end

        # Rückseite an eine Wand des Raums. wl = Lage der Wand (x entlang der Wand von links
        # nach rechts aus dem Raum gesehen, y in die Wand hinein, wie bei einem Schrank),
        # lx = Maus entlang der Wand, links/rechts = Kanten, an denen die linke bzw. rechte
        # Schrankseite einrastet. abstand = Wandabstand: hinten und an den Wandenden
        # (Kante 0 bzw. laenge) auch seitlich zur Nachbarwand. ecke = :links/:rechts setzt den
        # Schrank immer in diese Ecke (Eckschrank: an beiden Wänden).
        # Liefert [winkel, x, y, linke Schrankkante entlang der Wand].
        def an_raumwand(k, wl, lx, links, rechts, fang, abstand = 0, laenge = nil, ecke = nil)
          breite = k[1] - k[0]
          links = links.map { |s| s.abs < 1e-6 ? s + abstand : s }
          rechts = rechts.map { |s| laenge && (s - laenge).abs < 1e-6 ? s - abstand : s }
          xs = lx - breite / 2.0
          if ecke == :links
            xs = links.min
          elsif ecke == :rechts
            xs = rechts.max - breite
          else
            dl = links.map { |s| [(xs - s).abs, s] }.min
            dr = rechts.map { |s| [(xs + breite - s).abs, s - breite] }.min
            beste = [dl, dr].compact.select { |d, _| d <= fang }.min
            xs = beste[1] if beste
          end
          x, y = welt(wl, xs - k[0], -k[3] - abstand)
          [winkel(wl[0]), x, y, xs]
        end

        # Höhe an einer Wand (boden_z = Fußboden): Unter- und Hochschränke stehen mit der
        # Seitenunterkante auf Fußboden + Sockel, Oberschränke auf der festen Höhe (v wie #hoehe).
        def raum_hoehe(kat, boden_z, k, v)
          return unter_decke(boden_z + v[:ober] - k[4], k, v) if kat == 'Oberschrank'
          boden_z + v[:sockel] - k[4]
        end

        # Sockelhöhe geändert um d (Zoll): neue z eines Schranks. Unter-, Hochschränke,
        # Arbeitsplatte, Sockelblenden um d; Oberschränke auch, aber höchstens bis unter die
        # Decke (stehen sie schon höher, bleiben sie).
        def sockel_neu_z(kat, z, k, d, decke)
          return z + d unless kat == 'Oberschrank' && decke && d > 0
          grenze = decke - k[5]
          z >= grenze ? z : [z + d, grenze].min
        end

        # frei: Mitte des Grundrisses unter der Maus
        def frei(k, punkt, w)
          dx, dy = drehe(w, (k[0] + k[1]) / 2.0, (k[2] + k[3]) / 2.0)
          [winkel(w), punkt[0] - dx, punkt[1] - dy]
        end

        # die 8 Ecken des Kastens in Welt-Koordinaten (für die Vorschau)
        def ecken(k, lage)
          [k[4], k[5]].flat_map do |z|
            [[k[0], k[2]], [k[1], k[2]], [k[1], k[3]], [k[0], k[3]]].map do |x, y|
              wx, wy = welt(lage, x, y)
              [wx, wy, lage[3] + z]
            end
          end
        end
      end

      # ---------------------------------------------------------------------
      # SketchUp
      # ---------------------------------------------------------------------
      def self.schrank?(e)
        (e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)) &&
          !!Schraenke.definition(e).get_attribute(JT_DICT, 'schrank')
      end

      def self.kategorie(inst)
        Schraenke.definition(inst).get_attribute(JT_DICT, 'kategorie')
      end

      def self.insel?(inst)
        d = Schraenke.definition(inst)
        !!d.get_attribute(JT_DICT, 'insel') || d.get_attribute(JT_DICT, 'typ') == 'Unterschrank_Insel'
      end

      # globale Werte (mm) aus Kuechenplaner::Einstellungen, sonst VORGABEN
      def self.vorgabe(name)
        e = defined?(::Kuechenplaner::Einstellungen) ? ::Kuechenplaner::Einstellungen : nil
        v = e.public_send(name) if e.respond_to?(name)
        v.nil? ? VORGABEN.fetch(name) : v.to_f
      rescue StandardError
        VORGABEN.fetch(name)
      end

      # Vorgaben in Zoll (siehe Rechnung.hoehe), mit Fußboden und Decke des Raums
      def self.vorgaben(model = nil)
        v = Rechnung.vorgaben_zoll(VORGABEN.keys.map { |k| [k, vorgabe(k)] }.to_h)
        r = model && raum(model)
        if r
          z = r.transformation.origin.to_a[2].to_f
          h = raum_daten(r)['hoehe']
          v[:boden] = z
          v[:decke] = h ? z + h.to_f * MM : nil
        end
        v
      end

      # --- Raum (Erweiterung Raum) ---------------------------------------------------
      def self.raum(model)
        Schraenke.instanzen(model.entities).find { |e| e.get_attribute(RAUM_DICT, 'typ') == 'Raum' }
      end

      def self.raum_daten(r)
        require 'json'
        JSON.parse(r.get_attribute(RAUM_DICT, 'daten', '{}').to_s)
      rescue StandardError
        {}
      end

      # Wände als Hindernisse [[lage, [0, laenge, 0, dicke]], …] (Wandsystem: y in die Wand)
      def self.waende(model)
        r = raum(model)
        return [] unless r
        dicke = (raum_daten(r)['dicke'] || 240).to_f * MM
        m = r.transformation.to_a.map(&:to_f)
        Schraenke.instanzen(Schraenke.definition(r).entities).select { |w| w.get_attribute(RAUM_DICT, 'typ') == 'Wand' }.map do |w|
          mm = Rechnung.matmul(m, w.transformation.to_a.map(&:to_f))
          [[Rechnung.winkel(Math.atan2(mm[1], mm[0])), mm[12], mm[13], mm[14]],
           [0.0, w.get_attribute(RAUM_DICT, 'laenge').to_f * MM, 0.0, dicke]]
        end
      end

      # Schränke, die nicht in einer Zeile stehen (Arbeitsplatte, Sockelblende)
      KEINE_ZEILE = %w[Arbeitsplatte Sockel].freeze

      # Hindernisse für einen Schrank der Kategorie kat: Wände und die anderen Schränke
      # derselben Ebene (Oberschränke: Ober- und Hochschränke; sonst Unter- und Hochschränke)
      def self.hindernisse(model, inst, kat)
        andere = Schraenke.instanzen(model.entities).select do |e|
          next false if e == inst || !schrank?(e)
          ek = kategorie(e)
          next false if KEINE_ZEILE.include?(ek)
          kat == 'Oberschrank' ? ek != 'Unterschrank' : ek != 'Oberschrank'
        end
        waende(model) + andere.map do |e|
          b = bezug(e)
          [lage(e.transformation), [b[0], b[1], b[2], b[3]]]
        end
      end

      # Eckschrank: in welche Ecke einer Wand er gehört (L-Form: Schenkel B an der linken
      # Wand; Blindeck: zur Blindseite), sonst nil
      def self.ecke(inst)
        return nil unless Schraenke.definition(inst).get_attribute(JT_DICT, 'typ') == 'Eckschrank'
        return :links if Schraenke.dc(inst, 'schenkel_a')
        Schraenke.dc(inst, 'blindseite').to_i == 1 ? :rechts : :links
      end

      KORPUS_DICT = 'JT_Korpus'.freeze

      # Virtueller Korpus einer Komponente ohne eigenen Korpus (Geschirrspüler-, Kühlschrank-Nische):
      # unsichtbarer Kasten, markiert mit JT_Korpus/virtuell an seiner Definition
      def self.virtueller_korpus(d)
        d.entities.find do |e|
          e.respond_to?(:definition) && !(e.respond_to?(:hidden?) && e.hidden?) &&
            e.definition.get_attribute(KORPUS_DICT, 'virtuell')
        end
      end

      # Kasten = virtueller Korpus, falls vorhanden (Geräte-Platzhalter und bis zum Boden reichende
      # Wangen zählen dann nicht), sonst die sichtbaren Teile (ausgeblendete Schubladen, Wangen … zählen nicht)
      def self.kasten(inst)
        d = Schraenke.definition(inst)
        bb = Geom::BoundingBox.new
        korpus = virtueller_korpus(d)
        teile = korpus ? [korpus] : d.entities.to_a
        teile.each { |e| bb.add(e.bounds) if e.respond_to?(:bounds) && !(e.respond_to?(:hidden?) && e.hidden?) }
        bb = d.bounds if bb.empty?
        mn = bb.min.to_a
        mx = bb.max.to_a
        # Wangen reichen bis zum Boden: als Unterkante zählt die Korpusunterkante (z = 0)
        mn[2] = [mn[2].to_f, 0.0].max if d.get_attribute(JT_DICT, 'sockel_unter_korpus')
        [mn[0], mx[0], mn[1], mx[1], mn[2], mx[2]].map(&:to_f)
      end

      EINS = [1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 1.0].freeze

      # Bezugskasten [x0, x1, y0, y1, z0, z1] im Schranksystem: aus den sichtbaren Seiten
      # (und Wangen), ohne Seiten die virtuelle Seite aus den DC-Maßen, sonst #kasten.
      def self.bezug(inst)
        seiten = []
        wangen = []
        hinten = []
        sammeln(Schraenke.definition(inst).entities, EINS, seiten, wangen, hinten)
        Rechnung.bezug(seiten, wangen, seiten.empty? ? virtuelle_seite(inst) : nil, kasten(inst), hinten)
      end

      def self.sammeln(ents, m, seiten, wangen, hinten)
        Schraenke.instanzen(ents).each do |e|
          next if e.respond_to?(:hidden?) && e.hidden?
          mm = Rechnung.matmul(m, e.transformation.to_a.map(&:to_f))
          rolle = e.get_attribute(JT_DICT, 'rolle')
          if %w[Seite Wange].include?(rolle)
            bb = Schraenke.definition(e).bounds
            (rolle == 'Seite' ? seiten : wangen) << Rechnung.box_trafo(mm, bb.min.to_a.map(&:to_f), bb.max.to_a.map(&:to_f))
          elsif rolle == 'Rueckwand'
            bb = Schraenke.definition(e).bounds
            hinten << Rechnung.box_trafo(mm, bb.min.to_a.map(&:to_f), bb.max.to_a.map(&:to_f))
          elsif !e.get_attribute(JT_DICT, 'teil')
            sammeln(Schraenke.definition(e).entities, mm, seiten, wangen, hinten)
          end
        end
      end

      # DC-Maße (Zoll, Instanz vor Definition) eines Schranks ohne eigene Seiten
      def self.virtuelle_seite(inst)
        b, h, t = %w[breite hoehe tiefe].map { |k| Schraenke.dc(inst, k) }
        return nil unless b && h && t
        Rechnung.virtuelle_seite(b.to_f, h.to_f, t.to_f, *%w[x_nische materialstaerke_korpus materialstarke_rueckwand]
                                   .map { |k| Schraenke.dc(inst, k).to_f })
      end

      def self.lage(tr)
        o = tr.origin.to_a.map(&:to_f)
        [Rechnung.winkel(Math.atan2(tr.xaxis.y, tr.xaxis.x)), o[0], o[1], o[2]]
      end

      def self.transformation(lage)
        c, s = Rechnung.cs(lage[0])
        Geom::Transformation.axes(Geom::Point3d.new(lage[1], lage[2], lage[3]),
                                  Geom::Vector3d.new(c, s, 0), Geom::Vector3d.new(-s, c, 0), Geom::Vector3d.new(0, 0, 1))
      end

      # Aufruf aus den Komponenten direkt nach dem Erzeugen (vor dem Ändern der Auswahl)
      def self.neuer_schrank(inst)
        model = inst.model
        sockel_angleichen(inst, vorgabe(:sockelhoehe))
        auswahl = model.selection.to_a.select { |e| e != inst && schrank?(e) }
        ziel = freies_ende(inst, auswahl.size == 1 ? auswahl.first : nil)
        if ziel
          setzen(inst, ziel, 'Schrank anreihen')
        else
          model.select_tool(Werkzeug.new(inst))
        end
      rescue StandardError => e
        puts "Andocken: #{e.message}"
      end

      # Komponenten mit eigenem Parameter Sockelhöhe (Geschirrspüler, Kühlschrank-Nische,
      # Wangen, Sockelblende): auf die Sockelhöhe der Küche setzen, damit Gerät und Wangen
      # auf dem Fußboden stehen
      def self.sockel_angleichen(inst, sockel_mm)
        alt = Schraenke.dc(inst, 'sockelhoehe')
        return false if alt.nil? || kategorie(inst) == 'Oberschrank'
        neu = sockel_mm.to_f * MM
        return false if (alt.to_f - neu).abs < 1e-6
        inst.set_attribute(DC_DICT, 'sockelhoehe', neu)
        $dc_observers.get_latest_class.redraw_with_undo(inst) if defined?($dc_observers) && $dc_observers
        true
      end

      # Gehört schrank s in dieselbe Zeile wie ein neuer Schrank der Kategorie kat?
      # Oberschränke: Ober- und Hochschränke; sonst Unter- und Hochschränke; Insel für sich.
      def self.zeile?(kat, insel, s)
        sk = kategorie(s)
        return false if insel != insel?(s) || KEINE_ZEILE.include?(sk)
        kat == 'Oberschrank' ? %w[Oberschrank Hochschrank].include?(sk) : sk != 'Oberschrank'
      end

      # Lage für einen neuen Schrank oder nil (dann Werkzeug). start = ausgewählter Schrank.
      # Reihenfolge der Plätze: rechts bzw. links neben dem ausgewählten Schrank, dann am
      # rechten bzw. linken Ende seiner Zeile (ohne Auswahl: Zeile des zuletzt eingefügten).
      # Genommen wird der erste Platz, an dem keine Wand und kein anderer Schrank im Weg ist.
      def self.freies_ende(inst, start = nil)
        model = inst.model
        gewaehlt = !start.nil?
        kat = kategorie(inst)
        insel = insel?(inst)
        alle = Schraenke.instanzen(model.entities).select { |e| e != inst && schrank?(e) }
        zeile = alle.select { |e| zeile?(kat, insel, e) }
        k = bezug(inst)
        v = vorgaben(model)
        hind = hindernisse(model, inst, kat)
        start = nil if start && !zeile.include?(start) && !(kat == 'Oberschrank' && kategorie(start) == 'Unterschrank')
        start ||= zeile.reverse.find { |e| kategorie(e) == kat } || zeile.last
        if start.nil? && kat == 'Oberschrank'
          # erster Oberschrank: über den Anfang (links) der zuletzt gebauten Unterschrank-Zeile
          start = alle.reverse.find { |e| kategorie(e) == 'Unterschrank' && !insel?(e) }
        end
        return nil unless start
        if kat == 'Oberschrank' && kategorie(start) == 'Unterschrank'
          unten = alle.select { |e| %w[Unterschrank Hochschrank].include?(kategorie(e)) && insel?(e) == insel }
          liste = unten.map { |e| [bezug(e), lage(e.transformation)] }
          plaetze = [[Rechnung.zeilenende(liste, unten.index(start), :links), false],
                     [Rechnung.zeilenende(liste, unten.index(start), :rechts), true]].map do |i, rechts|
            n, nl = liste[i]
            l = Rechnung.ueber_unterschrank(k, n, nl, rechts, v[:aufbau])
            l[3] = Rechnung.unter_decke(l[3], k, v)
            l
          end
          return plaetze.find { |l| Rechnung.platz?(k, l, hind) }
        end
        liste = zeile.map { |e| [bezug(e), lage(e.transformation)] }
        s = zeile.index(start)
        plaetze = []
        plaetze << [s, :rechts] << [s, :links] if gewaehlt && zeile[s] == start
        plaetze << [Rechnung.zeilenende(liste, s, :rechts), :rechts] << [Rechnung.zeilenende(liste, s, :links), :links]
        plaetze.uniq.each do |i, seite|
          n, nl = liste[i]
          w, x, y = Rechnung.an_nachbar(k, n, nl, seite, 0)
          z = Rechnung.hoehe(k, kat, n, nl[3], kategorie(zeile[i]), inst.transformation.origin.to_a[2].to_f, v)
          return [w, x, y, z] if Rechnung.platz?(k, [w, x, y, z], hind)
        end
        nil
      end

      # Sockelhöhe in den Einstellungen geändert (mm): alle Schränke mitnehmen
      # (Unter-, Hochschränke, Arbeitsplatten, Sockelblenden; Oberschränke höchstens bis
      # zur Decke) und den Parameter Sockelhöhe der Komponenten angleichen.
      def self.sockel_geaendert(model, alt_mm, neu_mm)
        d = (neu_mm.to_f - alt_mm.to_f) * MM
        return 0 if d.abs < 1e-9
        v = vorgaben(model)
        n = 0
        Schraenke.instanzen(model.entities).each do |e|
          next unless schrank?(e)
          kat = kategorie(e)
          l = lage(e.transformation)
          z = Rechnung.sockel_neu_z(kat, l[3], bezug(e), d, v[:decke])
          if (z - l[3]).abs > 1e-9
            e.transformation = transformation([l[0], l[1], l[2], z])
            n += 1
          end
          sockel_angleichen(e, neu_mm)
        end
        n
      end

      def self.setzen(inst, ziel, text)
        model = inst.model
        model.start_operation(text, true, false, true)
        inst.transformation = transformation(ziel)
        model.commit_operation
      end

      # neuen Schrank ohne Maus rechts neben den Nachbarn setzen
      def self.anreihen(inst, nachbar)
        ziel = freies_ende(inst, nachbar)
        setzen(inst, ziel, 'Schrank anreihen') if ziel
      end

      # Menü: ausgewählten Schrank mit dem Werkzeug neu andocken
      def self.starten
        model = Sketchup.active_model
        s = model.selection.to_a.select { |e| schrank?(e) }
        if s.size != 1
          UI.messagebox('Bitte genau einen Schrank auswählen, der angedockt werden soll.')
          return
        end
        model.select_tool(Werkzeug.new(s.first))
      end

      class Werkzeug
        TAB = 9
        LINKS = defined?(VK_LEFT) ? VK_LEFT : 37
        RECHTS = defined?(VK_RIGHT) ? VK_RIGHT : 39
        HOCH = defined?(VK_UP) ? VK_UP : 38
        RUNTER = defined?(VK_DOWN) ? VK_DOWN : 40

        def initialize(inst)
          @inst = inst
          @kasten = Andocken.bezug(inst)
          @kat = Andocken.kategorie(inst)
          @v = Andocken.vorgaben(inst.model)
          @ecke = Andocken.ecke(inst)
          @start = Andocken.lage(inst.transformation)
          @drehung = 0
          @buendig = :hinten
          @ziel = nil
          @info = ''
        end

        def activate
          @ip = Sketchup::InputPoint.new
          status
        end

        def deactivate(view)
          view.invalidate
        end

        def resume(view)
          status
          view.invalidate
        end

        def status
          Sketchup.status_text = 'Schrank andocken: über Schrank = daneben, über Front = quer davor, über Wand = an die Wand (rastet in Ecken ein). ' \
                                 'Tab/Pfeil links-rechts: drehen, Pfeil hoch-runter: Rückwand/Front bündig, Klick: absetzen, Esc: abbrechen'
        end

        def onMouseMove(_flags, x, y, view)
          @ip.pick(view, x, y)
          @maus = [x, y]
          berechnen(view)
          view.invalidate
        end

        def onKeyDown(key, _repeat, _flags, view)
          case key
          when TAB, RECHTS then @drehung = (@drehung + 1) % 4
          when LINKS then @drehung = (@drehung + 3) % 4
          when HOCH, RUNTER then @buendig = @buendig == :hinten ? :vorne : :hinten
          else return false
          end
          berechnen(view) if @ip
          view.invalidate
          true
        end

        def onLButtonDown(_flags, _x, _y, view)
          return unless @ziel
          model = view.model
          model.start_operation('Schrank andocken', true)
          @inst.transformation = Andocken.transformation(@ziel)
          model.commit_operation
          model.selection.clear
          model.selection.add(@inst)
          model.select_tool(nil)
        end

        def onCancel(_reason, view)
          view.model.select_tool(nil)
        end

        def draw(view)
          view.draw_text(Geom::Point3d.new(@maus[0] + 16, @maus[1] + 16, 0), @info) if !@ziel && @maus && !@info.empty?
          return unless @ziel
          e = Rechnung.ecken(@kasten, @ziel).map { |p| Geom::Point3d.new(*p) }
          kanten = [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7]]
          view.line_width = 2
          view.drawing_color = 'Blue'
          view.draw(GL_LINES, kanten.flat_map { |a, b| [e[a], e[b]] })
          # Front (y0) rot und dick, damit die Drehung zu sehen ist
          view.line_width = 4
          view.drawing_color = 'Red'
          view.draw(GL_LINE_LOOP, [e[0], e[1], e[5], e[4]])
          view.draw_text(Geom::Point3d.new(@maus[0] + 16, @maus[1] + 16, 0), @info) if @maus && !@info.empty?
        end

        def getExtents
          bb = Geom::BoundingBox.new
          Rechnung.ecken(@kasten, @ziel).each { |p| bb.add(Geom::Point3d.new(*p)) } if @ziel
          bb
        end

        private

        # Nachbarschrank im Pfad der Maus: [Instanz, Welt-Transformation]
        def nachbar(pfad)
          tr = Geom::Transformation.new
          pfad.each do |e|
            break unless e.respond_to?(:transformation)
            tr *= e.transformation
            return [e, tr] if Andocken.schrank?(e)
          end
          nil
        end

        # Wand des Raums im Pfad der Maus: [Instanz, Welt-Transformation]
        def raumwand(pfad)
          tr = Geom::Transformation.new
          pfad.each do |e|
            break unless e.respond_to?(:transformation)
            tr *= e.transformation
            return [e, tr] if e.respond_to?(:get_attribute) && e.get_attribute(RAUM_DICT, 'typ') == 'Wand'
          end
          nil
        end

        # Instanzen unter der Maus von außen nach innen (InputPoint ab SketchUp 2017,
        # sonst PickHelper)
        def pfad(view)
          return @ip.instance_path.to_a if @ip.respond_to?(:instance_path) && @ip.instance_path
          ph = view.pick_helper
          ph.do_pick(*@maus)
          ph.count > 0 ? (ph.path_at(0) || []) : []
        end

        def berechnen(view)
          p = @ip.position
          pf = pfad(view)
          eigen = pf.include?(@inst) # Maus auf dem Schrank selbst
          ober = @kat == 'Oberschrank'
          n = eigen ? nil : nachbar(pf)
          # Unter- und Hochschränke docken nicht an Oberschränke an
          n = nil if n && !ober && Andocken.kategorie(n[0]) == 'Oberschrank'
          n = nil if n && KEINE_ZEILE.include?(Andocken.kategorie(n[0]))
          if n
            ninst, ntr = n
            nl = Andocken.lage(ntr)
            nk = Andocken.bezug(ninst)
            nkat = Andocken.kategorie(ninst)
            name = ninst.respond_to?(:name) && !ninst.name.to_s.empty? ? ninst.name : 'Schrank'
            lx, = Rechnung.lokal(nl, p.x, p.y)
            rechts = lx > (nk[0] + nk[1]) / 2.0
            if ober && nkat == 'Unterschrank'
              @ziel = Rechnung.ueber_unterschrank(@kasten, nk, nl, rechts, @v[:aufbau])
            @ziel[3] = Rechnung.unter_decke(@ziel[3], @kasten, @v)
              @info = "über #{name} (#{rechts ? 'rechts' : 'links'} bündig)"
              return
            end
            seite = Rechnung.seite(lx, nk, !ober && front?(nl))
            w, x, y = Rechnung.an_nachbar(@kasten, nk, nl, seite, Rechnung.viertel(seite, @drehung), @buendig)
            z = Rechnung.hoehe(@kasten, @kat, nk, nl[3], nkat, @start[3], @v)
            @ziel = [w, x, y, z]
            @info = { rechts: 'rechts an', links: 'links an', vorne_rechts: 'quer vor (rechts)', vorne_links: 'quer vor (links)' }[seite] + " #{name}"
          elsif !eigen && (rw = raumwand(pf))
            winst, wtr = rw
            wl = Andocken.lage(wtr)
            lx, = Rechnung.lokal(wl, p.x, p.y)
            laenge = winst.get_attribute(RAUM_DICT, 'laenge').to_f * MM
            links = (winst.get_attribute(RAUM_DICT, 'kanten_links') || [0]).map { |v| v.to_f * MM }
            rechts = (winst.get_attribute(RAUM_DICT, 'kanten_rechts') || [laenge / MM]).map { |v| v.to_f * MM }
            w, x, y, xs = Rechnung.an_raumwand(@kasten, wl, lx, links, rechts, FANG, @v[:wand], laenge, @ecke)
            @ziel = [w, x, y, Rechnung.raum_hoehe(@kat, wl[3], @kasten, @v)]
            b = @kasten[1] - @kasten[0]
            @info = "an Wand #{winst.get_attribute(RAUM_DICT, 'wand')}: links #{(xs / MM).round} mm, rechts #{((laenge - xs - b) / MM).round} mm"
          elsif !eigen && (wn = wand(view))
            # andere senkrechte Fläche: Fußboden bei z = 0
            z = Rechnung.raum_hoehe(@kat, @v[:boden], @kasten, @v)
            @ziel = Rechnung.an_wand(@kasten, [p.x, p.y], wn, @v[:wand]) + [z]
            @info = 'an die Wand'
          elsif ober
            # Oberschränke nie frei im Raum
            @ziel = nil
            @info = 'Oberschrank: nur an eine Wand oder über einen Unterschrank'
          else
            # Unter-/Hochschränke frei verschiebbar, aber immer auf Fußboden + Sockel
            @ziel = Rechnung.frei(@kasten, [p.x, p.y], @start[0] + @drehung * VIERTEL) + [Rechnung.sockel_z(@kasten, @v)]
            @info = ''
          end
        end

        # Maus auf der Front des Nachbarn? (Fläche zeigt nach vorn, -y des Schranks)
        def front?(nl)
          f = @ip.face
          return false unless f
          v = f.normal.transform(@ip.transformation)
          lx, ly = Rechnung.drehe(-nl[0], v.x, v.y)
          l = Math.sqrt(lx * lx + ly * ly + v.z * v.z)
          l > 0 && -ly / l > 0.7
        end

        # senkrechte Fläche unter der Maus: Normale (zum Betrachter) als [x, y]
        def wand(view)
          f = @ip.face
          return nil unless f
          v = f.normal.transform(@ip.transformation)
          return nil if v.length.zero? || v.z.abs > 0.3 * v.length
          v.reverse! if v % view.camera.direction > 0
          [v.x, v.y]
        end
      end
    end
  end
end

# Haken für die Komponenten: Kuechenplaner.neuer_schrank(inst) nach dem Erzeugen
module Kuechenplaner
  def self.neuer_schrank(inst)
    JTools::SchrankCnc::Andocken.neuer_schrank(inst)
  end
end
