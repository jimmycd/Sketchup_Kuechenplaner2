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
      # Tags, die im Bild nie erscheinen bzw. immer (falls es keine Szene Kunde gibt)
      NIE = %w[Beschriftung Geraete_Plan].freeze
      IMMER = %w[Geraete_Render].freeze

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
        seite = model.respond_to?(:pages) && model.pages ? model.pages[SZENE] : nil
        versteckt = nil
        if seite && (!seite.respond_to?(:use_hidden_layers?) || seite.use_hidden_layers?)
          versteckt = seite.layers.to_a.map(&:name) if seite.respond_to?(:layers)
        end
        lambda do |tag|
          next true if tag.nil?
          name = tag.name.to_s
          next false if NIE.include?(name)
          next true if seite.nil? && IMMER.include?(name)
          versteckt ? !versteckt.include?(name) : tag.visible?
        end
      end

      def szene_kunde?(model)
        model.respond_to?(:pages) && model.pages && model.pages[SZENE] ? true : false
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
        end

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
              flaeche(e, tr, erbe) if sichtbar?(e)
            elsif e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
              next unless sichtbar?(e)
              defn = e.respond_to?(:definition) ? e.definition : nil
              kinder = defn ? defn.entities : e.entities
              entities(kinder, tr * e.transformation, e.material || erbe)
            end
          end
        end

        # Name des Materials in der MTL (eindeutig, nur Buchstaben/Ziffern/_)
        def mtl_name(mat)
          return @namen[mat] if @namen.key?(mat)
          basis = mat ? mat.respond_to?(:display_name) ? mat.display_name : mat.name : 'Standard'
          basis = Rendern.ascii(basis)
          basis = 'Material' if basis.empty?
          name = basis
          k = 1
          name = "#{basis}_#{k += 1}" while @materialien.key?(name)
          @namen[mat] = name
          @materialien[name] = eintrag(mat)
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
          mesh = f.mesh(tex ? 5 : 0) # 1 Punkte + 4 UV vorne
          n = mesh.count_points
          gespiegelt = Rendern.gespiegelt?(tr)
          (1..n).each do |i|
            p = mesh.point_at(i).transform(tr)
            x, y, z = p.x.to_f * M, p.y.to_f * M, p.z.to_f * M
            @obj << format('v %.5f %.5f %.5f', x, y, z)
            erweitern(x, y, z)
          end
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

        def erweitern(x, y, z)
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

      # Kamera der Ansicht in Metern; fov in Grad
      def kamera(view)
        c = view.camera
        perspektive = c.perspective?
        {
          'auge' => c.eye.to_a.map { |v| (v.to_f * M).round(5) },
          'ziel' => c.target.to_a.map { |v| (v.to_f * M).round(5) },
          'oben' => c.up.to_a.map { |v| v.to_f.round(6) },
          'perspektive' => perspektive,
          'fov' => perspektive ? c.fov.to_f : 0.0,
          'fov_hoehe' => c.respond_to?(:fov_is_height?) ? c.fov_is_height? : true,
          'hoehe' => perspektive ? 0.0 : (c.height.to_f * M).round(5)
        }
      end

      # Richtung zur Sonne aus den Schatten-Einstellungen
      def sonne(model)
        si = model.shadow_info
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
      def exportieren(model, ordner, bild, breite:, samples:, raumlicht: true, blend: true)
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
          'kamera' => kamera(view),
          'licht' => { 'sonne' => sonne(model), 'raumlicht' => raumlicht },
          'box' => s.box.map { |p| p.map { |v| v.round(4) } },
          'materialien' => s.materialien.transform_values do |m|
            { 'farbe' => m[:farbe], 'alpha' => m[:alpha], 'textur' => m[:textur], 'art' => m[:art] }
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

      # Fortschritt aus dem Log: [Anteil 0..1 oder nil, Text]
      def fortschritt(log)
        zeilen = log.to_s.lines.map(&:strip).reject(&:empty?)
        sample = nil
        zeilen.reverse_each do |z|
          if (m = z.match(/Sample (\d+)\/(\d+)/))
            sample = [m[1].to_f / m[2].to_f, "Rendern: Sample #{m[1]} von #{m[2]}"]
            break
          end
        end
        status = zeilen.reverse.find { |z| z.start_with?('KP_STATUS ') }
        return sample if sample
        [nil, status ? status.sub('KP_STATUS ', '') : 'Blender startet …']
      end

      # Ergebnis aus dem Log: [:fertig, bild] | [:fehler, text] | nil (läuft noch)
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
        blender = blender_suchen
        prompts = ['Bild: Breite (Pixel, Höhe wie die Ansicht)', 'Bild: Qualität', 'Bild: Raumlicht von oben',
                   'Bild: Bilddatei (PNG)', 'Blender: Programm (blender.exe)']
        werte = [vorgabe('breite', '1920').to_s, vorgabe('qualitaet', 'Normal').to_s,
                 vorgabe('raumlicht', 'ja').to_s, standard_bild(model), blender]
        listen = ['', QUALITAET.keys.join('|'), 'ja|nein', ':speichern', ':programm']
        untertitel = szene_kunde?(model) ? 'Sichtbarkeit wie Szene Kunde, Kamera wie Ansicht' : 'Kamera wie Ansicht (Szene Kunde fehlt)'
        Kuechenplaner::Eingabe.abfragen(prompts, werte, listen, 'Küche rendern (Blender)',
                                        untertitel: untertitel, ok: 'Rendern') do |neu|
          breite = neu[0].to_s.strip.to_i
          raise ArgumentError, 'Breite bitte zwischen 200 und 8000 Pixel.' unless breite.between?(200, 8000)
          bild = neu[3].to_s.strip.tr('\\', '/')
          raise ArgumentError, 'Bitte eine Bilddatei angeben.' if bild.empty?
          bild += '.png' unless bild =~ /\.png\z/i
          exe = neu[4].to_s.strip.tr('\\', '/')
          unless File.file?(exe)
            raise ArgumentError, 'Blender nicht gefunden. Bitte Blender installieren (kostenlos, blender.org) ' \
                                 'und hier blender.exe wählen.'
          end
          merken('breite', breite.to_s)
          merken('qualitaet', neu[1])
          merken('raumlicht', neu[2])
          merken('blender', exe)
          starten(model, exe, bild, breite, QUALITAET.fetch(neu[1], 128), neu[2] != 'nein')
        end
      end

      def starten(model, exe, bild, breite, samples, raumlicht)
        ordner = bild.sub(/\.png\z/i, '_blender')
        json = exportieren(model, ordner, bild, breite: breite, samples: samples, raumlicht: raumlicht)
        File.delete(bild) if File.exist?(bild)
        log = File.join(ordner, 'blender.log')
        pid = Process.spawn(*befehl(exe, json), out: log, err: %i[child out])
        Fortschritt.new(pid, log, bild, ordner).zeigen
        pid
      end

      # Fenster mit Fortschrittsbalken, Abbrechen und am Ende dem Bild
      class Fortschritt
        def initialize(pid, log, bild, ordner)
          @pid, @log, @bild, @ordner = pid, log, bild, ordner
          @fertig = false
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

        def log_text
          File.exist?(@log) ? File.read(@log, encoding: 'UTF-8', invalid: :replace, undef: :replace) : ''
        end

        def pruefen
          return if @fertig
          # zuerst nachsehen, ob Blender beendet ist, dann das Log lesen (sonst fehlt evtl. die letzte Zeile)
          beendet = begin
            Process.wait(@pid, Process::WNOHANG)
          rescue StandardError
            true
          end
          text = log_text
          erg = Rendern.ergebnis(text)
          if erg && erg[0] == :fertig && File.exist?(erg[1])
            fertig(erg[1])
          elsif erg && erg[0] == :fehler
            fehler(erg[1])
          elsif beendet
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
          begin
            Process.kill('KILL', @pid)
            Process.wait(@pid)
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
