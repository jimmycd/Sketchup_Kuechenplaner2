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
        # hindernisse = [[lage, [x0, x1, y0, y1], [z0, z1] oder nil, art], …] (Wände: nil = ganze
        # Höhe, art :wand; andere Schränke: :schrank). Platz, wenn der Kasten k in Lage l
        # keines davon um mehr als tol überlappt (Berühren ist erlaubt). Gerechnet im System
        # des Hindernisses.
        def platz?(k, l, hindernisse, tol = TOLERANZ)
          ecken = [[k[0], k[2]], [k[1], k[2]], [k[1], k[3]], [k[0], k[3]]].map { |x, y| welt(l, x, y) }
          z = [(l[3] || 0) + k[4], (l[3] || 0) + k[5]]
          hindernisse.none? do |hl, hb, hz|
            next false unless z_ueberlappt?(z, hz, tol)
            pts = ecken.map { |x, y| lokal(hl, x, y) }
            xs = pts.map(&:first)
            ys = pts.map(&:last)
            xs.max > hb[0] + tol && xs.min < hb[1] - tol && ys.max > hb[2] + tol && ys.min < hb[3] - tol
          end
        end

        def z_ueberlappt?(z, hz, tol = TOLERANZ)
          hz.nil? || (hz[0] < z[1] - tol && hz[1] > z[0] + tol)
        end

        # Grundriss eines Hindernisses im System wl (achsparallele Hülle)
        def huelle(hl, hb, wl)
          pts = [[hb[0], hb[2]], [hb[1], hb[2]], [hb[1], hb[3]], [hb[0], hb[3]]].map { |x, y| lokal(wl, *welt(hl, x, y)) }
          [pts.map(&:first).min, pts.map(&:first).max, pts.map(&:last).min, pts.map(&:last).max]
        end

        # nächster Wert zu x, der in keinem offenen Intervall (a, b) liegt
        def naechster_freier(x, gesperrt)
          frei = ->(v) { gesperrt.none? { |a, b| v > a + 1e-9 && v < b - 1e-9 } }
          return x if frei.call(x)
          gesperrt.flatten.select { |v| frei.call(v) }.min_by { |v| (v - x).abs }
        end

        # --- an der Wand gleiten (Jürgen 2026-11-05) -----------------------------------
        # Schrank (Kasten k, um q Viertel gegen die Wand gedreht) mit der Rückseite im
        # abstand vor der Wand wl (x entlang, y in die Wand), Mitte möglichst bei lx.
        # Rastet an den Wandenden (dort seitlich im abstand) und Laibungen ein (fang),
        # weicht Hindernissen aus (bleibt anliegend stehen) und stellt die Vorderkante bündig
        # mit einem anliegenden Nachbarn, der weiter vorne steht (untere vordere Korpusecke gleich).
        # z = [z0, z1] des Schranks. Liefert [winkel, x, y, linke Kante entlang der Wand] oder nil.
        def an_wand_gleiten(k, wl, laenge, lx, q, abstand, fang, links, rechts, hindernisse, z, tol = TOLERANZ)
          r = rechteck(k, q * VIERTEL)
          b = r[1] - r[0]
          oy = -abstand - r[3]
          xs = lx - b / 2.0
          kanten = links.map { |s| s.abs < 1e-6 ? s + abstand : s } +
                   rechts.map { |s| (laenge && (s - laenge).abs < 1e-6 ? s - abstand : s) - b }
          fangpunkt = kanten.min_by { |c| (c - xs).abs }
          xs = fangpunkt if fangpunkt && (fangpunkt - xs).abs <= fang
          xs = [[xs, 0.0].max, laenge - b].min if laenge && laenge >= b # nicht über das Wandende hinaus
          huellen = hindernisse.select { |_, _, hz| z_ueberlappt?(z, hz, tol) }
                               .map { |hl, hb, _, art| [huelle(hl, hb, wl), art] }
          gesperrt = lambda do |y0|
            huellen.select { |h, _| h[3] > y0 + r[2] + tol && h[2] < y0 + r[3] - tol }
                   .map { |h, _| [h[0] - b, h[1]] }
          end
          xs = naechster_freier(xs, gesperrt.call(oy))
          return nil unless xs
          # Vorderkante bündig mit einem anliegenden Schrank, wenn dieser weiter vorne steht
          nachbar = huellen.find do |h, art|
            art == :schrank && h[2] < oy + r[2] - tol && h[3] > oy + r[2] &&
              ((h[1] - xs).abs <= tol || (h[0] - xs - b).abs <= tol)
          end
          if nachbar
            oy2 = nachbar[0][2] - r[2]
            oy = oy2 if naechster_freier(xs, gesperrt.call(oy2)) == xs
          end
          x, y = welt(wl, xs - r[0], oy)
          [winkel(wl[0] + q * VIERTEL), x, y, xs]
        end

        # nächste Wand zum Punkt (Abstand zur Wandstrecke): Index in waende
        # (waende = [[wl, laenge], …])
        def naechste_wand(waende, px, py)
          return nil if waende.empty?
          waende.each_index.min_by do |i|
            wl, laenge = waende[i]
            lx, ly = lokal(wl, px, py)
            dx = lx < 0 ? -lx : (lx > laenge ? lx - laenge : 0)
            Math.sqrt(dx * dx + ly * ly)
          end
        end

        # Tab im Werkzeug: [wand, q] → nächster Zustand. Eckschrank: erst drehen (q 0 → 3) an
        # derselben Wand, beim nächsten Tab die Wand wechseln. rueck = Shift+Tab.
        def tab(wand, q, n, eck, rueck = false)
          if rueck
            return [wand, 0] if eck && q == 3
            w = (wand - 1) % n
            return [w, eck ? 3 : 0]
          end
          return [wand, 3] if eck && q.zero?
          [(wand + 1) % n, 0]
        end

        # --- Bezugskasten -------------------------------------------------------------
        # seiten/wangen: Kästen der sichtbaren Seiten bzw. Wangen im Schranksystem,
        # virtuell: Kasten aus den Maßen (Schränke ohne eigene Seite), rest: alle sichtbaren Teile.
        # x und Höhe kommen von den Seiten (sonst virtuell), Wangen verbreitern nur in x und
        # verlängern nach hinten (sie reichen bis zum Fußboden und zählen in z nicht).
        # hinten: Kästen der Rückwände, sie zählen im Grundriss mit (Rückseite an der Wand; die
        # Rückwand von Schenkel B der L-Form liegt seitlich), nicht in der Höhe.
        def bezug(seiten, wangen, virtuell, rest, hinten = [])
          b = seiten.empty? ? virtuell : vereinigen(seiten)
          return rest if b.nil?
          b = b.dup
          hinten.each do |r|
            b[0] = [b[0], r[0]].min
            b[1] = [b[1], r[1]].max
            b[3] = [b[3], r[3]].max
          end
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

      # Wände des Raums in ihrer Reihenfolge (Wand 1, 2, …): je { lage:, laenge:, dicke:,
      # links:, rechts: } in Zoll (Wandsystem: x entlang der Wand, y in die Wand hinein)
      def self.raumwaende(model)
        r = raum(model)
        return [] unless r
        dicke = (raum_daten(r)['dicke'] || 240).to_f * MM
        m = r.transformation.to_a.map(&:to_f)
        ws = Schraenke.instanzen(Schraenke.definition(r).entities).select { |w| w.get_attribute(RAUM_DICT, 'typ') == 'Wand' }
        ws.sort_by { |w| w.get_attribute(RAUM_DICT, 'wand').to_i }.map do |w|
          mm = Rechnung.matmul(m, w.transformation.to_a.map(&:to_f))
          laenge = w.get_attribute(RAUM_DICT, 'laenge').to_f * MM
          { lage: [Rechnung.winkel(Math.atan2(mm[1], mm[0])), mm[12], mm[13], mm[14]], laenge: laenge, dicke: dicke,
            links: (w.get_attribute(RAUM_DICT, 'kanten_links') || [0]).map { |v| v.to_f * MM },
            rechts: (w.get_attribute(RAUM_DICT, 'kanten_rechts') || [laenge / MM]).map { |v| v.to_f * MM } }
        end
      end

      # Wände als Hindernisse [lage, [0, laenge, -abstand, dicke], nil (ganze Höhe), :wand]:
      # die Zone des Wandabstands vor der Wand gehört dazu, so hält jeder Schrank ihn ein,
      # hinten wie seitlich in den Ecken
      def self.waende(model, abstand = 0)
        raumwaende(model).map { |w| [w[:lage], [0.0, w[:laenge], -abstand, w[:dicke]], nil, :wand] }
      end

      # Schränke, die nicht in einer Zeile stehen und nicht im Weg sind (Arbeitsplatte, Sockelblende)
      KEINE_ZEILE = %w[Arbeitsplatte Sockel].freeze

      # Hindernisse für einen Schrank: alle Wände und alle anderen Schränke mit ihrem Korpus
      # (Grundriss und Höhe; ob sie im Weg sind, entscheidet die Höhe)
      def self.hindernisse(model, inst, _kat = nil)
        andere = Schraenke.instanzen(model.entities).select do |e|
          e != inst && schrank?(e) && !KEINE_ZEILE.include?(kategorie(e))
        end
        waende(model, vorgabe(:wandabstand) * MM) + andere.map do |e|
          b = bezug(e)
          l = lage(e.transformation)
          [l, [b[0], b[1], b[2], b[3]], [l[3] + b[4], l[3] + b[5]], :schrank]
        end
      end

      # Eckschrank (L-Form, Blindeck, Eck-Oberschrank): Tab dreht erst, dann Wandwechsel
      def self.eckschrank?(inst)
        Schraenke.definition(inst).get_attribute(JT_DICT, 'typ') == 'Eckschrank'
      end

      # feste Höhe (z der Lage) eines Schranks mit Kasten k
      def self.feste_hoehe(kat, k, v)
        Rechnung.raum_hoehe(kat, v[:boden] || 0, k, v)
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

      # Lage für einen neuen Schrank oder nil (dann Werkzeug). start = markierter Schrank.
      # Jürgen 2026-11-05: markiert → an seine freie Seite (rechts bevorzugt), keine frei →
      # Werkzeug; nichts markiert → freies Ende der Zeile des zuletzt eingefügten Schranks
      # (rechts, sonst links), sonst Werkzeug. Frei = keine Wand, kein Schrank im Weg.
      # Nachbarn: untere vordere Korpusecke gleich (Fronten bündig); geht das nicht (neuer
      # Schrank tiefer, stieße an die Wand), Rückseiten bündig.
      def self.freies_ende(inst, start = nil)
        model = inst.model
        gewaehlt = !start.nil?
        kat = kategorie(inst)
        insel = insel?(inst)
        alle = Schraenke.instanzen(model.entities).select { |e| e != inst && schrank?(e) }
        zeile = alle.select { |e| zeile?(kat, insel, e) }
        k = bezug(inst)
        v = vorgaben(model)
        hind = hindernisse(model, inst)
        if gewaehlt && kat == 'Oberschrank' && kategorie(start) == 'Unterschrank'
          # Oberschrank über den markierten Unterschrank, links bündig, sonst rechts bündig
          n = bezug(start)
          nl = lage(start.transformation)
          return [false, true].map do |rechts|
            l = Rechnung.ueber_unterschrank(k, n, nl, rechts, v[:aufbau])
            l[3] = feste_hoehe(kat, k, v)
            l
          end.find { |l| Rechnung.platz?(k, l, hind) }
        end
        return nil if gewaehlt && !zeile.include?(start)
        liste = zeile.map { |e| [bezug(e), lage(e.transformation)] }
        plaetze = if gewaehlt
                    s0 = zeile.index(start)
                    [[s0, :rechts], [s0, :links]]
                  else
                    s0 = zeile.rindex { |e| kategorie(e) == kat } || (zeile.empty? ? nil : zeile.size - 1)
                    if s0.nil? && kat == 'Oberschrank'
                      # erster Oberschrank: über den Anfang (links) der Unterschrank-Zeile
                      unten = alle.select { |e| %w[Unterschrank Hochschrank].include?(kategorie(e)) && insel?(e) == insel }
                      u = unten.rindex { |e| kategorie(e) == 'Unterschrank' }
                      return nil unless u
                      ul = unten.map { |e| [bezug(e), lage(e.transformation)] }
                      n, nl = ul[Rechnung.zeilenende(ul, u, :links)]
                      l = Rechnung.ueber_unterschrank(k, n, nl, false, v[:aufbau])
                      l[3] = feste_hoehe(kat, k, v)
                      return Rechnung.platz?(k, l, hind) ? l : nil
                    end
                    return nil unless s0
                    [[Rechnung.zeilenende(liste, s0, :rechts), :rechts], [Rechnung.zeilenende(liste, s0, :links), :links]]
                  end
        plaetze.uniq.each do |i, seite|
          n, nl = liste[i]
          z = Rechnung.hoehe(k, kat, n, nl[3], kategorie(zeile[i]), 0, v)
          %i[vorne hinten].each do |buendig|
            w, x, y = Rechnung.an_nachbar(k, n, nl, seite, 0, buendig)
            return [w, x, y, z] if Rechnung.platz?(k, [w, x, y, z], hind)
          end
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

      # Andock-Werkzeug (Jürgen 2026-11-05): Schrank hängt an einer Wand des Raums (Rückseite
      # im Wandabstand) und gleitet mit der Maus nur an ihr entlang; Tab/Shift+Tab wechselt
      # die Wand (Eckschrank: erst drehen, dann Wand); nie in Wände oder Schränke hinein;
      # Höhe fest. Strg (Mac: Option) = Freihand: folgt der Maus frei, Pfeil hoch/runter
      # ändert die Höhe um 10 mm, Tab dreht; nur die Kollision wird geprüft. Ohne Raum und für
      # Inselschränke folgt der Schrank der Maus auf fester Höhe (mit Kollisionsprüfung).
      class Werkzeug
        TAB = 9
        SHIFT = defined?(VK_SHIFT) ? VK_SHIFT : 16
        STRG = defined?(COPY_MODIFIER_KEY) ? COPY_MODIFIER_KEY : 17
        STRG_MASKE = defined?(COPY_MODIFIER_MASK) ? COPY_MODIFIER_MASK : 4
        HOCH = defined?(VK_UP) ? VK_UP : 38
        RUNTER = defined?(VK_DOWN) ? VK_DOWN : 40
        SCHRITT = 10 * MM

        attr_reader :ziel, :wand, :q, :frei

        def initialize(inst)
          @inst = inst
          model = inst.model
          @kasten = Andocken.bezug(inst)
          @kat = Andocken.kategorie(inst)
          @v = Andocken.vorgaben(model)
          @eck = Andocken.eckschrank?(inst)
          @insel = Andocken.insel?(inst)
          @start = Andocken.lage(inst.transformation)
          @waende = Andocken.raumwaende(model)
          @hind = Andocken.hindernisse(model, inst)
          @z = Andocken.feste_hoehe(@kat, @kasten, @v)
          @wand = nil
          @q = 0
          @drehung = 0
          @frei = false
          @shift = false
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
          Sketchup.status_text = 'Schrank platzieren: Maus = an der Wand entlang, Tab/Shift+Tab = andere Wand ' \
                                 '(Eckschrank: erst drehen), Strg halten = Freihand (Pfeil hoch/runter: Höhe), ' \
                                 'Klick: absetzen, Esc: abbrechen'
        end

        def onMouseMove(flags, x, y, view)
          @ip.pick(view, x, y)
          @maus = [x, y]
          @frei = (flags & STRG_MASKE) != 0 if flags.is_a?(Integer)
          p = bodenpunkt(view, x, y)
          setze_punkt(p[0], p[1])
          view.invalidate
        end

        def onKeyDown(key, _repeat, _flags, view)
          case key
          when TAB then taste_tab
          when SHIFT then @shift = true
          when STRG then @frei = true
          when HOCH, RUNTER
            return false unless @frei
            hoehe_aendern(key == HOCH ? SCHRITT : -SCHRITT)
          else return false
          end
          neu_rechnen
          view.invalidate
          true
        end

        def onKeyUp(key, _repeat, _flags, view)
          case key
          when SHIFT then @shift = false
          when STRG then @frei = false
          else return false
          end
          neu_rechnen
          view.invalidate
          true
        end

        def onLButtonDown(_flags, _x, _y, view)
          return unless @ziel
          model = view.model
          model.start_operation('Schrank platzieren', true)
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
          view.draw_text(Geom::Point3d.new(@maus[0] + 16, @maus[1] + 16, 0), @info) if @maus && !@info.empty?
          return unless @ziel
          e = Rechnung.ecken(@kasten, @ziel).map { |p| Geom::Point3d.new(*p) }
          kanten = [[0, 1], [1, 2], [2, 3], [3, 0], [4, 5], [5, 6], [6, 7], [7, 4], [0, 4], [1, 5], [2, 6], [3, 7]]
          view.line_width = 2
          view.drawing_color = @frei ? 'Orange' : 'Blue'
          view.draw(GL_LINES, kanten.flat_map { |a, b| [e[a], e[b]] })
          # Vorderseite (y0) rot und dick, damit die Drehung zu sehen ist
          view.line_width = 4
          view.drawing_color = 'Red'
          view.draw(GL_LINE_LOOP, [e[0], e[1], e[5], e[4]])
        end

        def getExtents
          bb = Geom::BoundingBox.new
          Rechnung.ecken(@kasten, @ziel).each { |p| bb.add(Geom::Point3d.new(*p)) } if @ziel
          bb
        end

        # --- ohne SketchUp-Ansicht testbar ----------------------------------------------
        # Maus über dem Fußbodenpunkt (px, py): neues Ziel rechnen. Kein freier Platz →
        # das letzte gültige Ziel bleibt.
        def setze_punkt(px, py)
          @punkt = [px, py]
          neu_rechnen
        end

        def taste_tab
          if @frei || wandlos?
            @drehung = (@drehung + (@shift ? 3 : 1)) % 4
          elsif @wand
            @wand, @q = Rechnung.tab(@wand, @q, @waende.size, @eck, @shift)
          end
        end

        def hoehe_aendern(d)
          @frei_z = (@frei_z || (@ziel ? @ziel[3] : @z)) + d
        end

        def frei=(wert)
          @frei = wert
          neu_rechnen
        end

        def shift=(wert)
          @shift = wert
        end

        private

        def wandlos?
          @waende.empty? || @insel
        end

        def neu_rechnen
          return unless @punkt
          px, py = @punkt
          if @frei || wandlos?
            @frei_z = nil unless @frei
            z = @frei ? (@frei_z ||= (@ziel ? @ziel[3] : @z)) : @z
            l = Rechnung.frei(@kasten, [px, py], @start[0] + @drehung * VIERTEL) + [z]
            if Rechnung.platz?(@kasten, l, @hind)
              @ziel = l
              @info = @frei ? "Freihand (Strg), Höhe #{(z / MM).round} mm" : ''
            else
              @info = 'Kollision'
            end
            return
          end
          @wand ||= Rechnung.naechste_wand(@waende.map { |w| [w[:lage], w[:laenge]] }, px, py)
          w = @waende[@wand]
          lx, = Rechnung.lokal(w[:lage], px, py)
          z = [@z + @kasten[4], @z + @kasten[5]]
          l = Rechnung.an_wand_gleiten(@kasten, w[:lage], w[:laenge], lx, @q, @v[:wand], FANG, w[:links], w[:rechts], @hind, z)
          if l
            @ziel = l[0, 3] + [@z]
            b = (Rechnung.rechteck(@kasten, @q * VIERTEL)[1] - Rechnung.rechteck(@kasten, @q * VIERTEL)[0])
            @info = "Wand #{@wand + 1}: links #{(l[3] / MM).round} mm, rechts #{((w[:laenge] - l[3] - b) / MM).round} mm"
          else
            @info = "Wand #{@wand + 1}: kein Platz"
          end
        end

        # Mauspunkt auf der Fußbodenebene (Höhe des Raumbodens)
        def bodenpunkt(view, x, y)
          o, d = view.pickray(x, y)
          boden = @v[:boden] || 0
          if d && d.z.abs > 1e-9
            t = (boden - o.z) / d.z
            return [o.x + t * d.x, o.y + t * d.y] if t > 0
          end
          p = @ip.position
          [p.x, p.y]
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
