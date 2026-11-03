# encoding: UTF-8
# Schrank-CNC – Andock-Werkzeug: neue Schränke an vorhandene Schränke oder an
# eine Wand setzen, statt sie von Hand zu verschieben und zu drehen.
#
# Nach dem Erzeugen hängt der Schrank als Vorschau (Kasten, Front rot) an der Maus:
#   * über einem Schrank: rastet links oder rechts bündig an dessen Seite ein,
#     übernimmt Drehung und Höhe (Rückwände bündig, Pfeil hoch/runter: Fronten bündig);
#   * über der Front eines Schranks: stellt sich quer davor, bündig mit dessen
#     linker oder rechter Seite (Ecke einer L- oder U-Küche, z. B. vor ein Blindeck);
#   * über einer Wand des Raums (Erweiterung Raum): Rückseite an die Wand, rastet an
#     Wandenden und Tür-/Durchgangslaibungen ein (Fang 100 mm); Unter- und Hochschränke
#     stehen auf dem Fußboden des Raums plus Sockelhöhe (Küchenplaner › Einstellungen);
#   * über einer anderen senkrechten Fläche: Rückseite daran, Mitte unter der Maus;
#   * sonst: folgt der Maus auf seiner Höhe.
#   Tab oder Pfeil rechts/links drehen um 90°, Klick setzt ab, Esc lässt ihn stehen.
# War beim Erzeugen genau ein Schrank ausgewählt, kommt der neue ohne Maus direkt
# rechts daneben („an Auswahl anreihen“).
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
      SOCKEL = 100 * MM        # Korpusunterkante über dem Fußboden, wenn der Raum keine Sockelhöhe angibt
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

        # Höhe (z der Lage) am Nachbarn: Unterkanten gleich. Ein Oberschrank neben einem
        # Hochschrank: Oberkanten gleich. Ober- neben Unterschrank: eigene Höhe bleibt.
        def hoehe(k, kat, n, nz, nkat, eigene_z)
          ober = kat == 'Oberschrank'
          nober = nkat == 'Oberschrank'
          return nz + n[5] - k[5] if ober && nkat == 'Hochschrank'
          return eigene_z if ober != nober
          nz + n[4] - k[4]
        end

        # Rückseite an eine Wand: punkt = Mauspunkt auf der Wand, normale = zeigt in den Raum.
        def an_wand(k, punkt, normale)
          nx, ny = normale
          l = Math.sqrt(nx * nx + ny * ny)
          nx /= l
          ny /= l
          w = winkel(Math.atan2(nx, -ny)) # x-Achse des Schranks entlang der Wand
          mitte = (k[0] + k[1]) / 2.0
          dx, dy = drehe(w, mitte, k[3])
          [w, punkt[0] - dx, punkt[1] - dy]
        end

        # Rückseite an eine Wand des Raums. wl = Lage der Wand (x entlang der Wand von links
        # nach rechts aus dem Raum gesehen, y in die Wand hinein, wie bei einem Schrank),
        # lx = Maus entlang der Wand, links/rechts = Kanten, an denen die linke bzw. rechte
        # Schrankseite einrastet. Liefert [winkel, x, y, linke Schrankkante entlang der Wand].
        def an_raumwand(k, wl, lx, links, rechts, fang)
          breite = k[1] - k[0]
          xs = lx - breite / 2.0
          dl = links.map { |s| [(xs - s).abs, s] }.min
          dr = rechts.map { |s| [(xs + breite - s).abs, s - breite] }.min
          beste = [dl, dr].compact.select { |d, _| d <= fang }.min
          xs = beste[1] if beste
          x, y = welt(wl, xs - k[0], -k[3])
          [winkel(wl[0]), x, y, xs]
        end

        # Höhe an einer Raumwand: Unter- und Hochschränke stehen auf dem Fußboden (boden_z)
        # plus Sockelhöhe des Raums (mm, nil = 100 mm); Oberschränke behalten ihre Höhe.
        def raum_hoehe(kat, boden_z, sockel_mm, eigene_z)
          return eigene_z unless %w[Unterschrank Hochschrank].include?(kat)
          boden_z + (sockel_mm.nil? ? SOCKEL : sockel_mm.to_f * MM)
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

      # Kasten aus den sichtbaren Teilen (ausgeblendete Schubladen, Wangen … zählen nicht)
      def self.kasten(inst)
        d = Schraenke.definition(inst)
        bb = Geom::BoundingBox.new
        d.entities.each { |e| bb.add(e.bounds) if e.respond_to?(:bounds) && !(e.respond_to?(:hidden?) && e.hidden?) }
        bb = d.bounds if bb.empty?
        mn = bb.min.to_a
        mx = bb.max.to_a
        [mn[0], mx[0], mn[1], mx[1], mn[2], mx[2]].map(&:to_f)
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
        nachbarn = model.selection.to_a.select { |e| e != inst && schrank?(e) }
        if nachbarn.size == 1
          anreihen(inst, nachbarn.first)
        else
          model.select_tool(Werkzeug.new(inst))
        end
      rescue StandardError => e
        puts "Andocken: #{e.message}"
      end

      # neuen Schrank ohne Maus rechts neben den Nachbarn setzen
      def self.anreihen(inst, nachbar)
        nl = lage(nachbar.transformation)
        n = kasten(nachbar)
        k = kasten(inst)
        w, x, y = Rechnung.an_nachbar(k, n, nl, :rechts, 0)
        z = Rechnung.hoehe(k, kategorie(inst), n, nl[3], kategorie(nachbar), inst.transformation.origin.to_a[2].to_f)
        model = inst.model
        model.start_operation('Schrank anreihen', true, false, true)
        inst.transformation = transformation([w, x, y, z])
        model.commit_operation
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
          @kasten = Andocken.kasten(inst)
          @kat = Andocken.kategorie(inst)
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
          eigen = pf.include?(@inst) # Maus auf dem Schrank selbst: frei verschieben
          n = eigen ? nil : nachbar(pf)
          if n
            ninst, ntr = n
            nl = Andocken.lage(ntr)
            nk = Andocken.kasten(ninst)
            lx, = Rechnung.lokal(nl, p.x, p.y)
            seite = Rechnung.seite(lx, nk, front?(nl))
            w, x, y = Rechnung.an_nachbar(@kasten, nk, nl, seite, Rechnung.viertel(seite, @drehung), @buendig)
            z = Rechnung.hoehe(@kasten, @kat, nk, nl[3], Andocken.kategorie(ninst), @start[3])
            @ziel = [w, x, y, z]
            name = ninst.respond_to?(:name) && !ninst.name.to_s.empty? ? ninst.name : 'Schrank'
            @info = { rechts: 'rechts an', links: 'links an', vorne_rechts: 'quer vor (rechts)', vorne_links: 'quer vor (links)' }[seite] + " #{name}"
          elsif !eigen && (rw = raumwand(pf))
            winst, wtr = rw
            wl = Andocken.lage(wtr)
            lx, = Rechnung.lokal(wl, p.x, p.y)
            laenge = winst.get_attribute(RAUM_DICT, 'laenge').to_f * MM
            links = (winst.get_attribute(RAUM_DICT, 'kanten_links') || [0]).map { |v| v.to_f * MM }
            rechts = (winst.get_attribute(RAUM_DICT, 'kanten_rechts') || [laenge / MM]).map { |v| v.to_f * MM }
            w, x, y, xs = Rechnung.an_raumwand(@kasten, wl, lx, links, rechts, FANG)
            sockel = defined?(Kuechenplaner::Einstellungen) ? Kuechenplaner::Einstellungen.sockelhoehe(view.model) : nil
            z = Rechnung.raum_hoehe(@kat, wl[3], sockel, @start[3])
            @ziel = [w, x, y, z]
            b = @kasten[1] - @kasten[0]
            @info = "an Wand #{winst.get_attribute(RAUM_DICT, 'wand')}: links #{(xs / MM).round} mm, rechts #{((laenge - xs - b) / MM).round} mm"
          elsif !eigen && (wn = wand(view))
            @ziel = Rechnung.an_wand(@kasten, [p.x, p.y], wn) + [@start[3]]
            @info = 'an die Wand'
          else
            @ziel = Rechnung.frei(@kasten, [p.x, p.y], @start[0] + @drehung * VIERTEL) + [@start[3]]
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
