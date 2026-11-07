# encoding: UTF-8
# Küchenplaner – fotorealistisch rendern mit Blender (Cycles), Teil 1 von 2.
#
# Erweiterungen › Küchenplaner › Rendern… (und Symbolleiste):
#   1. Fenster im Treppenplaner-Stil: Bildbreite, Qualität, Raumlicht, Ausgabedatei,
#      Blender-Programm (wird gesucht und auf diesem Rechner gemerkt).
#   2. Export der sichtbaren Geometrie mit der Tag-Sichtbarkeit der Szene „Kunde“
#      (Geräte als Modell, Raum sichtbar, keine Beschriftung) als OBJ + MTL in Metern,
#      Z nach oben, Texturen als Bilddateien, dazu szene.json mit Kamera der aktuellen
#      Ansicht, Sonnenrichtung (Schatten-Einstellungen) und Materialart je Material.
#   3. Blender läuft unsichtbar im Hintergrund (blender -b -P rendern.py -- szene.json),
#      ein Fenster zeigt den Fortschritt (Abbrechen möglich) und am Ende das Bild.
# Alles landet neben dem Bild: Kueche_Render.png und Ordner Kueche_Render_blender/
# (szene.obj/.mtl/.json, Texturen, szene.blend zum Weiterbearbeiten in Blender).
# Der Python-Teil steht in rendern.py.

require 'json'
require 'fileutils'

module JTools
  module SchrankCnc
    module Rendern
      module_function

      SEKTION = 'JT_Rendern'.freeze
      SZENE = 'Kunde'.freeze
      M = 0.0254 # Zoll -> Meter
      # Qualität -> Samples (Cycles, mit Entrauschen)
      QUALITAET = { 'Entwurf' => 32, 'Normal' => 128, 'Hoch' => 512 }.freeze
      # Umgebung: HDRI aus Blenders eigenen Dateien (datafiles/studiolights/world), kein Download
      UMGEBUNG = { 'Innenraum' => 'interior.exr', 'Innenhof' => 'courtyard.exr', 'Studio' => 'studio.exr',
                   'Stadt' => 'city.exr', 'Wald' => 'forest.exr', 'Sonnenuntergang' => 'sunset.exr',
                   'einfarbig hell' => nil }.freeze
      # Deko auf der Arbeitsplatte: Anzahl der Gegenstände
      DEKO = { 'keine' => 0, 'wenig' => 3, 'mittel' => 6, 'viel' => 10 }.freeze
      # Bodenbelag im Bild (in Blender erzeugt, ohne Bilddateien)
      BODEN = { 'wie Modell' => nil, 'Parkett Eiche' => 'parkett', 'Fliesen hell' => 'fliesen_hell',
                'Fliesen anthrazit' => 'fliesen_dunkel', 'Beton' => 'beton' }.freeze
      # Tags, die im Bild nie erscheinen bzw. immer (falls es keine Szene Kunde gibt)
      NIE = %w[Beschriftung Geraete_Plan Bohrungen].freeze
      IMMER = %w[Geraete_Render].freeze
      # Griffe der Fronten (Griffmodell, Tag „Griffe“) gehören zum Bild, auch wenn die Szene Kunde
      # älter ist als der Tag oder ihn ausblendet (Jürgen 2026-11-07: „stelle sicher, dass die Griffe auch
      # gerendert werden“)
      GRIFFE = 'Griffe'.freeze

      # Materialart am Namen erkennen (Reihenfolge zählt: Schwarzglas vor Glas)
      ARTEN = [
        ['schwarzglas', /schwarzglas|ceran|kochfeld|backofen.*glas|glas.*schwarz/i],
        ['glas', /glas|fenster.*scheibe|scheibe/i],
        ['metall', /edelstahl|stahl|chrom|metall|alu|inox|griff|armatur|nickel|messing/i],
        ['hochglanz', /hochglanz|lack|glanz/i],
        ['stein', /stein|granit|quarz|keramik|marmor|beton|fliese/i],
        ['holz', /holz|eiche|buche|nuss|ahorn|esche|fichte|kiefer|furnier|wood|oak/i],
        ['matt', /wand|decke|putz|boden|matt|raum|tapete/i]
      ].freeze

      # Name für OBJ/MTL und Blender: nur ASCII, höchstens 50 Zeichen
      def ascii(text)
        t = text.to_s.gsub('ä', 'ae').gsub('ö', 'oe').gsub('ü', 'ue').gsub('Ä', 'Ae').gsub('Ö', 'Oe')
                .gsub('Ü', 'Ue').gsub('ß', 'ss')
        t.gsub(/[^0-9A-Za-z_-]+/, '_').gsub(/\A_+|_+\z/, '')[0, 50]
      end

      TAG_BODEN = 'Raum-Boden'.freeze
      TAG_WAND = 'Raum-Wand'.freeze

      def tag_name(e)
        e.respond_to?(:layer) && e.layer ? e.layer.name.to_s : ''
      end

      def arbeitsplatte?(defn)
        defn.respond_to?(:get_attribute) && defn.get_attribute('JT_Schrank', 'kategorie') == 'Arbeitsplatte'
      end

      def insel?(defn)
        defn.respond_to?(:get_attribute) && defn.get_attribute('JT_Schrank', 'insel') ? true : false
      end

      # Gerätename (JT_Geraet/geraet, z. B. Spuele, Kochfeld60) oder nil
      def geraet(defn)
        defn.respond_to?(:get_attribute) ? defn.get_attribute('JT_Geraet', 'geraet') : nil
      end

      def begrenzung(punkte)
        return nil if punkte.nil? || punkte.empty?
        xs, ys, zs = punkte.transpose
        [[xs.min, ys.min, zs.min].map { |v| v.round(4) }, [xs.max, ys.max, zs.max].map { |v| v.round(4) }]
      end

      def vereinen(a, b)
        return b unless a
        [a[0].zip(b[0]).map(&:min), a[1].zip(b[1]).map(&:max)]
      end

      # Definition eines Oberschranks oder Wandregals (JT_Schrank/kategorie, wie Stückliste und
      # TCN-Export): darunter hängt eine LED-Leiste
      def oberschrank?(defn)
        defn.respond_to?(:get_attribute) && %w[Oberschrank Wandregal].include?(defn.get_attribute('JT_Schrank', 'kategorie'))
      end

      def materialart(name, alpha = 1.0)
        n = name.to_s
        ARTEN.each { |art, re| return art if n =~ re }
        alpha < 0.95 ? 'glas' : 'standard'
      end

      # --- Einstellungen auf diesem Rechner -------------------------------------
      def vorgabe(k, std)
        v = Sketchup.read_default(SEKTION, k, nil)
        v.nil? || v.to_s.empty? ? std : v
      end

      def merken(k, v)
        Sketchup.write_default(SEKTION, k, v)
      end

      # --- Blender finden -----------------------------------------------------------
      # Mögliche Programmdateien je Betriebssystem, neueste Version zuerst
      def blender_kandidaten(env = ENV)
        muster = []
        %w[ProgramFiles ProgramW6432 ProgramFiles(x86)].map { |k| env[k] }.compact.uniq.each do |pf|
          pf = pf.tr('\\', '/')
          muster << "#{pf}/Blender Foundation/Blender*/blender.exe"
          muster << "#{pf}/Steam/steamapps/common/Blender/blender.exe"
        end
        if env['LOCALAPPDATA']
          muster << "#{env['LOCALAPPDATA'].tr('\\', '/')}/Programs/Blender Foundation/Blender*/blender.exe"
        end
        muster << 'C:/Program Files/Blender Foundation/Blender*/blender.exe'
        muster << '/Applications/Blender*.app/Contents/MacOS/Blender'
        muster << '/usr/bin/blender' << '/usr/local/bin/blender' << '/snap/bin/blender'
        treffer = muster.uniq.flat_map { |m| Dir.glob(m) }
        treffer.uniq.sort_by { |p| version(p) }.reverse
      end

      # "…/Blender 4.2/blender.exe" -> [4, 2]; ohne Nummer ganz hinten
      def version(pfad)
        m = pfad.match(/Blender[ _-]?(\d+)\.(\d+)/i)
        m ? [m[1].to_i, m[2].to_i] : [0, 0]
      end

      # Gemerkter Pfad, falls es ihn noch gibt, sonst die neueste gefundene Version
      def blender_suchen(env = ENV)
        gemerkt = vorgabe('blender', '').to_s
        return gemerkt if !gemerkt.empty? && File.file?(gemerkt)
        blender_kandidaten(env).first.to_s
      end

      # --- Sichtbarkeit wie in der Szene Kunde --------------------------------------
      # Liefert ein Lambda tag -> sichtbar?
      def sichtbarkeit(model)
        seite = seite_kunde(model)
        versteckt = nil
        if seite && (!seite.respond_to?(:use_hidden_layers?) || seite.use_hidden_layers?)
          versteckt = seite.layers.to_a.map(&:name) if seite.respond_to?(:layers)
        end
        lambda do |tag|
          next true if tag.nil?
          name = tag.name.to_s
          next false if NIE.include?(name)
          next true if name == GRIFFE
          next true if seite.nil? && IMMER.include?(name)
          versteckt ? !versteckt.include?(name) : tag.visible?
        end
      end

      def szene_kunde?(model)
        seite_kunde(model) ? true : false
      end

      # --- Export ---------------------------------------------------------------------
      # Sammelt Flächen aus dem Modell und schreibt OBJ + MTL + Texturen
      class Sammler
        attr_reader :materialien, :flaechen, :box

        def initialize(sichtbar)
          @sichtbar = sichtbar
          @obj = []
          @v = 0
          @vt = 0
          @materialien = {} # Name in der MTL => { mat:, farbe:, alpha:, textur:, art: }
          @namen = {}       # SketchUp-Material (oder nil) => Name in der MTL
          @flaechen = 0
          @box = nil
          @leds = []     # Unterseiten der Oberschränke [x0, y0, x1, y1, z] in m
          @punkte = []   # alle Punkte in m (für die Begrenzung der Oberschränke)
          @im_ober = false
          @arbeitsflaechen = [] # Dreiecke der Arbeitsplatten-Oberseiten [[x,y,z]×3] in m (Deko)
          @inseln = []   # Begrenzung der Inselschränke [[min], [max]]
          @geraete = []  # Begrenzung der Geräte (Spüle, Kochfeld …) [[min], [max], name]
          @raum = nil    # Begrenzung der Wände [[min], [max]]
          @dreiecke = nil # beim Sammeln einer Arbeitsplatte: ihre waagrechten Dreiecke
          @boden = false  # Flächen auf dem Tag Raum-Boden bekommen eigene Materialien
        end

        attr_reader :leds, :arbeitsflaechen, :inseln, :geraete, :raum

        def obj_text
          @obj.join("\n") + "\n"
        end

        def sichtbar?(e)
          return false if e.respond_to?(:hidden?) && e.hidden?
          return false if e.respond_to?(:visible?) && !e.visible?
          @sichtbar.call(e.respond_to?(:layer) ? e.layer : nil)
        end

        def entities(ents, tr, erbe)
          ents.each do |e|
            if e.is_a?(Sketchup::Face)
              next unless sichtbar?(e)
              boden_vorher = @boden
              @boden ||= Rendern.tag_name(e) == TAG_BODEN
              flaeche(e, tr, erbe)
              @boden = boden_vorher
            elsif e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
              next unless sichtbar?(e)
              instanz(e, tr, erbe)
            end
          end
        end

        # Eine Instanz (oder Gruppe) samt Inhalt; merkt sich Oberschränke (LED), Arbeitsplatten
        # (Deko), Inseln (Pendelleuchten), Geräte (dort keine Deko) und Wände (Decke)
        def instanz(e, tr, erbe)
          defn = e.respond_to?(:definition) ? e.definition : nil
          defn = e.entities.parent if defn.nil? && e.respond_to?(:entities) && e.entities.respond_to?(:parent)
          kinder = e.respond_to?(:definition) ? e.definition.entities : e.entities
          t = tr * e.transformation
          mat = e.material || erbe
          tag = Rendern.tag_name(e)
          start = @punkte.size
          boden_vorher = @boden
          @boden ||= tag == TAG_BODEN
          if !@im_ober && Rendern.oberschrank?(defn)
            @im_ober = true
            entities(kinder, t, mat)
            @im_ober = false
            led(@punkte[start..-1])
          elsif @dreiecke.nil? && Rendern.arbeitsplatte?(defn)
            @dreiecke = []
            entities(kinder, t, mat)
            oben = @dreiecke.map { |d| d.map { |p| p[2] }.max }.max
            @arbeitsflaechen.concat(@dreiecke.select { |d| d.all? { |p| p[2] > oben - 0.003 } }) if oben
            @dreiecke = nil
          else
            entities(kinder, t, mat)
          end
          @boden = boden_vorher
          box = Rendern.begrenzung(@punkte[start..-1])
          return unless box
          @inseln << box if Rendern.insel?(defn)
          name = Rendern.geraet(defn)
          @geraete << (box + [name]) if name
          @raum = Rendern.vereinen(@raum, box) if tag == TAG_WAND
        end

        # Name des Materials in der MTL (eindeutig, nur Buchstaben/Ziffern/_)
        def mtl_name(mat)
          schluessel = [mat, @boden]
          return @namen[schluessel] if @namen.key?(schluessel)
          basis = mat ? mat.respond_to?(:display_name) ? mat.display_name : mat.name : 'Standard'
          basis = Rendern.ascii(basis)
          basis = 'Material' if basis.empty?
          basis = "Boden_#{basis}" if @boden
          name = basis
          k = 1
          name = "#{basis}_#{k += 1}" while @materialien.key?(name)
          @namen[schluessel] = name
          @materialien[name] = eintrag(mat).merge(boden: @boden)
          name
        end

        def eintrag(mat)
          return { mat: nil, farbe: [0.85, 0.85, 0.85], alpha: 1.0, textur: nil, art: 'standard' } unless mat
          c = mat.color
          farbe = [c.red, c.green, c.blue].map { |x| (x / 255.0).round(4) }
          alpha = mat.respond_to?(:alpha) ? mat.alpha.to_f : 1.0
          name = mat.respond_to?(:display_name) ? mat.display_name : mat.name
          { mat: mat, farbe: farbe, alpha: alpha, textur: nil, art: Rendern.materialart(name, alpha) }
        end

        def flaeche(f, tr, erbe)
          eigenes = f.material || f.back_material
          mat = eigenes || erbe
          name = mtl_name(mat)
          tex = mat && mat.respond_to?(:texture) ? mat.texture : nil
          mesh = f.mesh(tex ? 1 : 0) # 0 nur Punkte, 1 mit UVQ vorne
          n = mesh.count_points
          gespiegelt = Rendern.gespiegelt?(tr)
          welt = (1..n).map do |i|
            p = mesh.point_at(i).transform(tr)
            x, y, z = p.x.to_f * M, p.y.to_f * M, p.z.to_f * M
            @obj << format('v %.5f %.5f %.5f', x, y, z)
            erweitern(x, y, z)
            [x, y, z]
          end
          arbeitsflaeche(mesh, welt) if @dreiecke
          if tex
            (1..n).each do |i|
              uvq = mesh.uv_at(i, true)
              q = uvq.z.to_f.zero? ? 1.0 : uvq.z.to_f
              u, v = uvq.x.to_f / q, uvq.y.to_f / q
              # geerbtes Material: UV in Zoll, durch die Texturgröße teilen
              unless eigenes
                u /= tex.width.to_f.nonzero? || 1.0
                v /= tex.height.to_f.nonzero? || 1.0
              end
              @obj << format('vt %.5f %.5f', u, v)
            end
          end
          @obj << "usemtl #{name}"
          mesh.polygons.each do |poly|
            idx = poly.map(&:abs)
            idx = idx.reverse if gespiegelt
            @obj << 'f ' + idx.map { |i| tex ? "#{@v + i}/#{@vt + i}" : (@v + i).to_s }.join(' ')
          end
          @v += n
          @vt += n if tex
          @flaechen += 1
        end

        # Waagrechte Dreiecke einer Arbeitsplatte (Oberseite wird danach ausgewählt)
        def arbeitsflaeche(mesh, welt)
          mesh.polygons.each do |poly|
            next unless poly.size == 3
            d = poly.map { |i| welt[i.abs - 1].map { |v| v.round(4) } }
            @dreiecke << d if d.map { |p| p[2] }.minmax.reduce(:-).abs < 0.001
          end
        end

        # LED-Leiste unter dem Oberschrank: Unterseite seiner Begrenzung
        def led(punkte)
          return if punkte.nil? || punkte.empty?
          xs, ys, zs = punkte.transpose
          @leds << [xs.min, ys.min, xs.max, ys.max, zs.min].map { |v| v.round(4) }
        end

        def erweitern(x, y, z)
          @punkte << [x, y, z]
          if @box
            @box[0] = [[@box[0][0], x].min, [@box[0][1], y].min, [@box[0][2], z].min]
            @box[1] = [[@box[1][0], x].max, [@box[1][1], y].max, [@box[1][2], z].max]
          else
            @box = [[x, y, z], [x, y, z]]
          end
        end

        # MTL schreiben, Texturen in den Ordner legen
        def mtl_text(ordner)
          @materialien.map do |name, m|
            r, g, b = m[:farbe]
            zeilen = ["newmtl #{name}", format('Kd %.4f %.4f %.4f', r, g, b), format('d %.3f', m[:alpha])]
            if m[:mat] && m[:mat].respond_to?(:texture) && m[:mat].texture
              datei = textur_schreiben(m[:mat], name, ordner)
              if datei
                m[:textur] = datei
                zeilen << "map_Kd #{datei}"
              end
            end
            zeilen.join("\n")
          end.join("\n\n") + "\n"
        end

        def textur_schreiben(mat, name, ordner)
          tex = mat.texture
          ext = File.extname(tex.filename.to_s).downcase
          ext = '.png' unless %w[.png .jpg .jpeg .bmp .tif .tiff .tga].include?(ext)
          datei = "textur_#{name}#{ext}"
          ok = tex.respond_to?(:write) ? tex.write(File.join(ordner, datei), false) : false
          ok == false ? nil : datei
        rescue StandardError
          nil
        end
      end

      # Spiegelung (negative Determinante) dreht die Reihenfolge der Ecken um
      def gespiegelt?(tr)
        a = tr.to_a
        x = [a[0], a[1], a[2]]
        y = [a[4], a[5], a[6]]
        z = [a[8], a[9], a[10]]
        kreuz = [x[1] * y[2] - x[2] * y[1], x[2] * y[0] - x[0] * y[2], x[0] * y[1] - x[1] * y[0]]
        (kreuz[0] * z[0] + kreuz[1] * z[1] + kreuz[2] * z[2]) < 0
      end

      def seite_kunde(model)
        model.respond_to?(:pages) && model.pages ? model.pages[SZENE] : nil
      end

      # Kamera in Metern; fov in Grad. Aus der Ansicht oder (kamera_kunde) aus der Szene Kunde
      def kamera(view, seite = nil)
        c = seite && seite.respond_to?(:camera) && seite.camera ? seite.camera : view.camera
        perspektive = c.perspective?
        k = {
          'auge' => c.eye.to_a.map { |v| (v.to_f * M).round(5) },
          'ziel' => c.target.to_a.map { |v| (v.to_f * M).round(5) },
          'oben' => c.up.to_a.map { |v| v.to_f.round(6) },
          'perspektive' => perspektive,
          'fov' => perspektive ? c.fov.to_f : 0.0,
          'fov_hoehe' => c.respond_to?(:fov_is_height?) ? c.fov_is_height? : true,
          'hoehe' => perspektive ? 0.0 : (c.height.to_f * M).round(5)
        }
        # nur für die aktuelle Ansicht: die Strahlen gehören zu dem, was gerade zu sehen ist
        return k unless perspektive && seite.nil? && view.respond_to?(:pickray)
        bild = begin
          bildebene(view)
        rescue StandardError
          nil
        end
        bild ? k.merge(bild) : k
      end

      # Genau der Bildausschnitt der Ansicht, aus den Blickstrahlen der vier Bildecken
      # (view.pickray). So zählen auch Zweipunktperspektive und 2D-Zoom/-Verschieben
      # von SketchUp mit, die in Auge/Ziel/fov nicht stehen.
      # Liefert Auge, Bildachsen, senkrechten Öffnungswinkel und Objektiv-Shift
      # (in Bildhöhen, wie Blender bei sensor_fit VERTICAL).
      def bildebene(view)
        w = view.vpwidth.to_i
        h = view.vpheight.to_i
        return nil if w <= 1 || h <= 1
        auge = nil
        strahl = lambda do |x, y|
          o, d = view.pickray(x, y)
          auge ||= o.to_a.map(&:to_f)
          norm(d.to_a.map(&:to_f))
        end
        ol, or_, ul, ur = strahl.(0, 0), strahl.(w, 0), strahl.(0, h), strahl.(w, h)
        # Bildzeilen sind parallel: die Ebenen (Auge, obere Zeile) und (Auge, untere Zeile)
        # schneiden sich in der waagrechten Bildachse; ebenso die Spalten in der senkrechten
        rechts = norm(kreuz(kreuz(ol, or_), kreuz(ul, ur)))
        hoch = norm(kreuz(kreuz(ol, ul), kreuz(or_, ur)))
        return nil unless rechts && hoch
        rechts = rechts.map(&:-@) if punkt(rechts, minus(or_, ol)).negative?
        hoch = hoch.map(&:-@) if punkt(hoch, minus(ol, ul)).negative?
        blick = norm(kreuz(hoch, rechts))
        return nil unless blick
        blick = blick.map(&:-@) if punkt(blick, plus(ol, ur)).negative?
        hoch = kreuz(rechts, blick)
        # Ecken auf der Bildebene im Abstand 1 vor dem Auge
        xy = [ol, or_, ul, ur].map do |d|
          t = punkt(d, blick)
          return nil if t <= 1e-9
          [punkt(d, rechts) / t, punkt(d, hoch) / t]
        end
        links = (xy[0][0] + xy[2][0]) / 2.0
        rechts_x = (xy[1][0] + xy[3][0]) / 2.0
        oben = (xy[0][1] + xy[1][1]) / 2.0
        unten = (xy[2][1] + xy[3][1]) / 2.0
        hoehe = oben - unten
        return nil if hoehe <= 1e-9 || rechts_x <= links
        {
          'auge' => auge.map { |v| (v * M).round(5) },
          'ziel' => auge.each_with_index.map { |v, i| (v * M + blick[i]).round(5) },
          'oben' => hoch.map { |v| v.round(6) },
          'rechts' => rechts.map { |v| v.round(6) },
          'fov' => (2.0 * Math.atan(hoehe / 2.0) * 180.0 / Math::PI).round(4),
          'fov_hoehe' => true,
          'shift' => [((links + rechts_x) / 2.0 / hoehe).round(5), ((oben + unten) / 2.0 / hoehe).round(5)]
        }
      end

      def kreuz(a, b)
        [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
      end

      def punkt(a, b)
        a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
      end

      def minus(a, b)
        [a[0] - b[0], a[1] - b[1], a[2] - b[2]]
      end

      def plus(a, b)
        [a[0] + b[0], a[1] + b[1], a[2] + b[2]]
      end

      def norm(a)
        l = Math.sqrt(punkt(a, a))
        l < 1e-12 ? nil : a.map { |v| v / l }
      end

      # Richtung zur Sonne: Schatten-Einstellungen der Szene Kunde (falls sie eigene hat),
      # sonst die des Modells
      def sonne(model)
        seite = seite_kunde(model)
        si = if seite && seite.respond_to?(:shadow_info) && (!seite.respond_to?(:use_shadow_info?) || seite.use_shadow_info?)
               seite.shadow_info
             else
               model.shadow_info
             end
        d = si['SunDirection']
        d ? d.to_a.map { |v| v.to_f.round(5) } : nil
      rescue StandardError
        nil
      end

      # Bildhöhe aus der Breite und dem Seitenverhältnis der Ansicht
      def bildhoehe(view, breite)
        w = view.vpwidth.to_f
        h = view.vpheight.to_f
        return (breite * 9 / 16.0).round if w <= 0 || h <= 0
        [(breite * h / w).round, 16].max
      end

      # Exportiert Modell und Szene; liefert den Pfad der szene.json
      # Optionen: raumlicht, led (unter Oberschränken), umgebung (Name aus UMGEBUNG),
      # senkrecht (Zweipunktperspektive: senkrechte Kanten bleiben senkrecht), kamera_kunde
      def exportieren(model, ordner, bild, breite:, samples:, raumlicht: true, blend: true, kamera_kunde: false,
                      led: true, umgebung: 'Innenraum', senkrecht: true, deko: 'mittel', variante: 1,
                      pendel: true, boden: 'wie Modell', decke: true)
        FileUtils.mkdir_p(ordner)
        s = Sammler.new(sichtbarkeit(model))
        s.entities(model.entities, Geom::Transformation.new, nil)
        raise ArgumentError, 'Im Modell ist nichts Sichtbares zum Rendern.' if s.flaechen.zero?
        File.write(File.join(ordner, 'szene.mtl'), s.mtl_text(ordner), encoding: 'UTF-8')
        File.write(File.join(ordner, 'szene.obj'), "mtllib szene.mtl\n" + s.obj_text, encoding: 'UTF-8')
        view = model.active_view
        daten = {
          'obj' => 'szene.obj',
          'blend' => blend ? 'szene.blend' : nil,
          'bild' => { 'datei' => bild, 'breite' => breite, 'hoehe' => bildhoehe(view, breite), 'samples' => samples },
          'kamera' => kamera(view, kamera_kunde ? seite_kunde(model) : nil).merge('senkrecht' => senkrecht),
          'licht' => { 'sonne' => sonne(model), 'raumlicht' => raumlicht, 'led' => led ? s.leds : [],
                       'umgebung' => UMGEBUNG[umgebung] },
          'kanten' => 0.0015, # Kantenradius in m (Bevel-Shader)
          'deko' => { 'anzahl' => DEKO.fetch(deko, 0), 'variante' => variante.to_i, 'arbeitsflaechen' => s.arbeitsflaechen,
                      'geraete' => s.geraete, 'inseln' => s.inseln, 'pendel' => pendel },
          'raum' => { 'boden' => BODEN[boden], 'decke' => decke && s.raum ? s.raum : nil },
          'box' => s.box.map { |p| p.map { |v| v.round(4) } },
          'materialien' => s.materialien.transform_values do |m|
            { 'farbe' => m[:farbe], 'alpha' => m[:alpha], 'textur' => m[:textur], 'art' => m[:art], 'boden' => m[:boden] ? true : false }
          end,
          'flaechen' => s.flaechen
        }
        pfad = File.join(ordner, 'szene.json')
        File.write(pfad, JSON.pretty_generate(daten), encoding: 'UTF-8')
        pfad
      end

      # --- Blender starten und beobachten ---------------------------------------------
      def skript
        File.join(__dir__, 'rendern.py')
      end

      def befehl(blender, json)
        [blender, '-b', '--factory-startup', '-P', skript, '--', json]
      end

      # Fortschritt aus Statusdatei bzw. Log: [Anteil 0..1 oder nil, Text]
      def fortschritt(log)
        zeilen = log.to_s.lines.map(&:strip).reject(&:empty?)
        zeilen.reverse_each do |z|
          if (m = z.match(/(?:KP_SAMPLE |Sample )(\d+)\/(\d+)/))
            return [m[1].to_f / m[2].to_f, "Rendern: Sample #{m[1]} von #{m[2]}"]
          end
        end
        status = zeilen.reverse.find { |z| z.start_with?('KP_STATUS ') }
        [nil, status ? status.sub('KP_STATUS ', '') : 'Blender startet …']
      end

      # Ergebnis: [:fertig, bild] | [:fehler, text] | nil (läuft noch)
      def ergebnis(log)
        z = log.to_s.lines.map(&:strip)
        if (f = z.find { |l| l.start_with?('KP_FERTIG ') })
          return [:fertig, f.sub('KP_FERTIG ', '')]
        end
        if (f = z.find { |l| l.start_with?('KP_FEHLER ') })
          return [:fehler, f.sub('KP_FEHLER ', '')]
        end
        nil
      end

      # Prozessnummern aus der Statusdatei (Blender kann sich unter Windows neu starten)
      def pids(log)
        log.to_s.scan(/^KP_PID (\d+)/).flatten.map(&:to_i)
      end

      # Gilt Blender als beendet ohne Ergebnis? Erst wenn der gestartete Prozess weg ist UND
      # sich Statusdatei und Log seit `ruhe` Sekunden nicht mehr geändert haben: Blender 5
      # unter Windows meldet den Start-Prozess früh als beendet, rendert aber weiter.
      def abgebrochen?(beendet, letzte_aenderung, jetzt = Time.now, ruhe = 30)
        beendet && (jetzt - letzte_aenderung) > ruhe
      end

      def standard_bild(model)
        pfad = model.path.to_s
        if pfad.empty?
          dok = File.join(Dir.home, 'Documents')
          ordner = File.directory?(dok) ? dok : Dir.home
          return File.join(ordner, 'Kueche_Render.png')
        end
        File.join(File.dirname(pfad), "#{File.basename(pfad, '.*')}_Render.png")
      end

      # --- Fenster -----------------------------------------------------------------------
      def dialog(model = Sketchup.active_model)
        Roentgen.zuruecksetzen(model) if defined?(Roentgen)
        blender = blender_suchen
        kunde = szene_kunde?(model)
        prompts = ['Bild: Breite (Pixel, Höhe wie die Ansicht)', 'Bild: Qualität', 'Bild: Kamera',
                   'Bild: Senkrechte Kanten gerade (Zweipunktperspektive)', 'Licht: Umgebung',
                   'Licht: Raumlicht von oben', 'Licht: LED-Leisten unter Oberschränken',
                   'Ausstattung: Deko auf der Arbeitsplatte', 'Ausstattung: Deko-Variante (1–9, andere Auswahl und Anordnung)',
                   'Ausstattung: Pendelleuchten über der Insel', 'Ausstattung: Bodenbelag', 'Ausstattung: Decke',
                   'Datei: Bilddatei (PNG)', 'Datei: Blender-Programm (blender.exe)']
        kameras = kunde ? 'aktuelle Ansicht|Szene Kunde' : 'aktuelle Ansicht'
        werte = [vorgabe('breite', '1920').to_s, vorgabe('qualitaet', 'Normal').to_s, 'aktuelle Ansicht',
                 vorgabe('senkrecht', 'ja').to_s, vorgabe('umgebung', 'Innenraum').to_s,
                 vorgabe('raumlicht', 'ja').to_s, vorgabe('led', 'ja').to_s, vorgabe('deko', 'mittel').to_s,
                 vorgabe('variante', '1').to_s, vorgabe('pendel', 'ja').to_s, vorgabe('boden', 'wie Modell').to_s,
                 vorgabe('decke', 'ja').to_s, standard_bild(model), blender]
        listen = ['', QUALITAET.keys.join('|'), kameras, 'ja|nein', UMGEBUNG.keys.join('|'), 'ja|nein', 'ja|nein',
                  DEKO.keys.join('|'), (1..9).to_a.join('|'), 'ja|nein', BODEN.keys.join('|'), 'ja|nein',
                  ':speichern', ':programm']
        untertitel = kunde ? 'Sichtbarkeit und Sonne wie Szene Kunde' : 'Szene Kunde fehlt: aktuelle Sichtbarkeit'
        Kuechenplaner::Eingabe.abfragen(prompts, werte, listen, 'Küche rendern (Blender)',
                                        untertitel: untertitel, ok: 'Rendern') do |neu|
          breite = neu[0].to_s.strip.to_i
          raise ArgumentError, 'Breite bitte zwischen 200 und 8000 Pixel.' unless breite.between?(200, 8000)
          bild = neu[12].to_s.strip.tr('\\', '/')
          raise ArgumentError, 'Bitte eine Bilddatei angeben.' if bild.empty?
          bild += '.png' unless bild =~ /\.png\z/i
          exe = neu[13].to_s.strip.tr('\\', '/')
          unless File.file?(exe)
            raise ArgumentError, 'Blender nicht gefunden. Bitte Blender installieren (kostenlos, blender.org) ' \
                                 'und hier blender.exe wählen.'
          end
          { 'breite' => breite.to_s, 'qualitaet' => neu[1], 'senkrecht' => neu[3], 'umgebung' => neu[4],
            'raumlicht' => neu[5], 'led' => neu[6], 'deko' => neu[7], 'variante' => neu[8], 'pendel' => neu[9],
            'boden' => neu[10], 'decke' => neu[11], 'blender' => exe }.each { |k, v| merken(k, v) }
          optionen = { raumlicht: neu[5] != 'nein', kamera_kunde: neu[2] == 'Szene Kunde', senkrecht: neu[3] != 'nein',
                       umgebung: UMGEBUNG.key?(neu[4]) ? neu[4] : 'Innenraum', led: neu[6] != 'nein',
                       deko: DEKO.key?(neu[7]) ? neu[7] : 'mittel', variante: [[neu[8].to_i, 1].max, 9].min,
                       pendel: neu[9] != 'nein', boden: BODEN.key?(neu[10]) ? neu[10] : 'wie Modell', decke: neu[11] != 'nein' }
          starten(model, exe, bild, breite, QUALITAET.fetch(neu[1], 128), optionen)
        end
      end

      def starten(model, exe, bild, breite, samples, optionen = {})
        ordner = bild.sub(/\.png\z/i, '_blender')
        json = exportieren(model, ordner, bild, breite: breite, samples: samples, **optionen)
        File.delete(bild) if File.exist?(bild)
        log = File.join(ordner, 'blender.log')
        status = File.join(ordner, 'kp_status.txt')
        File.delete(status) if File.exist?(status)
        pid = Process.spawn(*befehl(exe, json), out: log, err: %i[child out])
        Fortschritt.new(pid, log, bild, ordner, status).zeigen
        pid
      end

      # Fenster mit Fortschrittsbalken, Abbrechen und am Ende dem Bild
      class Fortschritt
        def initialize(pid, log, bild, ordner, status = File.join(ordner, 'kp_status.txt'))
          @pid, @log, @bild, @ordner, @status = pid, log, bild, ordner, status
          @fertig = false
          @beendet = false
          @start = Time.now
        end

        def zeigen
          @d = UI::HtmlDialog.new(dialog_title: 'Küche rendern', preferences_key: 'Kuechenplaner_Rendern',
                                  scrollable: false, resizable: true, width: 720, height: 560,
                                  style: UI::HtmlDialog::STYLE_DIALOG)
          @d.set_html(Rendern.html)
          @d.add_action_callback('abbrechen') { |_c| abbrechen }
          @d.add_action_callback('oeffnen') { |_c| UI.openURL("file:///#{@bild}") }
          @d.add_action_callback('ordner') { |_c| UI.openURL("file:///#{File.dirname(@bild)}") }
          @d.add_action_callback('schliessen') { |_c| @d.close }
          @d.set_on_closed { abbrechen unless @fertig }
          @d.center
          @d.show
          weiter
        end

        # Einmal-Timer, der sich selbst neu stellt (Timer-Regel: zuerst anhalten)
        def weiter
          id = UI.start_timer(0.5, false) do
            UI.stop_timer(id)
            pruefen
          end
        end

        def lesen(datei)
          File.exist?(datei) ? File.read(datei, encoding: 'UTF-8', invalid: :replace, undef: :replace) : ''
        end

        # Statusdatei des Skripts und Log (Konsolenausgabe, falls umgeleitet)
        def log_text
          lesen(@status) + "\n" + lesen(@log)
        end

        def letzte_aenderung
          [@status, @log, @bild].select { |f| File.exist?(f) }.map { |f| File.mtime(f) }.push(@start).max
        end

        def pruefen
          return if @fertig
          unless @beendet
            @beendet = begin
              Process.wait(@pid, Process::WNOHANG) ? true : false
            rescue StandardError
              true
            end
          end
          text = log_text
          erg = Rendern.ergebnis(text)
          if erg && erg[0] == :fertig && File.exist?(erg[1])
            fertig(erg[1])
          elsif erg && erg[0] == :fehler
            fehler(erg[1])
          elsif Rendern.abgebrochen?(@beendet, letzte_aenderung)
            fehler("Blender wurde beendet, ohne ein Bild zu schreiben. Details: #{@log}")
          else
            anteil, t = Rendern.fortschritt(text)
            js("KP.stand(#{anteil ? (anteil * 100).round : 'null'}, #{JSON.generate(t)})")
            weiter
          end
        end

        def fertig(bild)
          @fertig = true
          daten = [File.binread(bild)].pack('m0')
          js("KP.bild('data:image/png;base64,#{daten}', #{JSON.generate(bild)})")
        end

        def fehler(text)
          @fertig = true
          js("KP.fehler(#{JSON.generate(text)})")
        end

        def abbrechen
          return if @fertig
          @fertig = true
          ([@pid] + Rendern.pids(lesen(@status))).uniq.each do |p|
            begin
              Process.kill('KILL', p)
            rescue StandardError
              nil
            end
          end
          begin
            Process.wait(@pid, Process::WNOHANG)
          rescue StandardError
            nil
          end
          js("KP.fehler('Abgebrochen.')")
        end

        def js(code)
          @d.execute_script(code) if @d && @d.visible?
        end
      end

      def html
        <<~HTML
          <!DOCTYPE html>
          <html lang="de"><head><meta charset="utf-8"><title>Küche rendern</title>
          <style>#{Kuechenplaner::Eingabe.css}
            .balken { height:14px; border:1px solid var(--line); border-radius:7px; background:#fff; overflow:hidden; }
            .balken div { height:100%; width:0; background:var(--accent); transition:width .3s; }
            .balken.unbestimmt div { width:30%; animation:hin 1.2s ease-in-out infinite alternate; }
            @keyframes hin { from { margin-left:0 } to { margin-left:70% } }
            #bild { max-width:100%; max-height:100%; display:none; margin:auto; border:1px solid var(--line); }
            #rahmen { flex:1; min-height:0; display:flex; align-items:center; justify-content:center; }
            main { display:flex; flex-direction:column; gap:10px; }
            #datei { color:var(--muted); word-break:break-all; }
          </style></head>
          <body>
          <header><h1>Küche rendern</h1><span class="sub">Blender Cycles im Hintergrund</span></header>
          <main>
            <div class="balken unbestimmt" id="balken"><div></div></div>
            <div id="text">Szene exportiert, Blender startet …</div>
            <div id="rahmen"><img id="bild" alt="Rendering"></div>
            <div id="datei"></div>
          </main>
          <footer><span id="status"></span><span class="spacer"></span>
            <button id="oeffnen" class="primary" style="display:none" onclick="sketchup.oeffnen()">Bild öffnen</button>
            <button id="ordner" onclick="sketchup.ordner()">Ordner öffnen</button>
            <button id="abbrechen" onclick="sketchup.abbrechen()">Abbrechen</button>
            <button id="schliessen" style="display:none" onclick="sketchup.schliessen()">Schließen</button></footer>
          <script>
          (function () {
            var $ = function (id) { return document.getElementById(id); };
            var ende = function () { $('abbrechen').style.display = 'none'; $('schliessen').style.display = ''; };
            window.KP = {
              stand: function (p, t) {
                $('text').textContent = t;
                if (p === null) { $('balken').className = 'balken unbestimmt'; $('balken').firstChild.style.width = ''; }
                else { $('balken').className = 'balken'; $('balken').firstChild.style.width = p + '%'; }
              },
              bild: function (src, datei) {
                $('balken').style.display = 'none'; $('text').textContent = 'Fertig.';
                $('bild').src = src; $('bild').style.display = 'block'; $('datei').textContent = datei;
                $('oeffnen').style.display = ''; ende();
              },
              fehler: function (t) {
                $('balken').style.display = 'none'; $('text').textContent = '';
                $('status').className = 'err'; $('status').textContent = t; ende();
              }
            };
          })();
          </script>
          </body></html>
        HTML
      end
    end
  end
end
