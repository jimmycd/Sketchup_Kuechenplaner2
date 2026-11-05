# encoding: UTF-8
#
# Kundensicht – schönere Darstellung der Szene „Kunde“ und „Kundenbild speichern…“
#
# Geraete.szenen_anlegen legt die Szenen Planung/Kunde/Zuschnitt an (oder aktualisiert
# sie) und ruft danach Kundensicht.anwenden: die Szene „Kunde“ bekommt ihren eigenen
# Darstellungsstil, eigene Schatten und eine Perspektiv-Kamera. Es gibt nur diese eine
# Kunden-Szene; der Blender-Export (TCN-Export › Rendern) liest sie ebenfalls.
#
#   Stil:     Flächen mit Texturen (Materialien aus dem Material-Konfigurator), keine
#             Profile/Silhouetten, Kanten dezent hellgrau, kein Text, keine Bemaßungen,
#             keine Achsen, heller Hintergrund mit Himmel und Boden
#   Schatten: an, Sommersonne gegen Mittag, weich (hell 80, dunkel 50)
#   Kamera:   Perspektive (40°). Neue Szene: aktuelle Ansicht; vorhandene Szene: ihre
#             gespeicherte Kamera bleibt, nur Parallelprojektion wird zu Perspektive.
#
# Der Stil wird an der Szene gespeichert (Page#update mit Kamera, Stil, Schatten) und
# zusätzlich direkt in die Optionen der Szene geschrieben. Die laufende Ansicht wird
# danach wiederhergestellt, Planung und Zuschnitt erben den Kundenstil nicht.
# Erneutes Anlegen aktualisiert nur, es entstehen keine Duplikate.
#
# Kundenbild speichern…: wechselt ohne Überblendung in die Szene „Kunde“ (legt die
# Szenen an, falls es sie noch nicht gibt) und schreibt ein PNG in wählbarer Auflösung
# (view.write_image).
#
# Wird von geraete/main.rb mit load geladen (Neu laden ohne Neustart): keine Konstanten.

module Geraete
  module Kundensicht
    def self.szene
      'Kunde'
    end

    # Darstellung (RenderingOptions); Farben als [r, g, b]
    def self.stil
      {
        'RenderMode' => 2, 'Texture' => true, 'DisplayColorByLayer' => false,
        'DrawSilhouettes' => false, 'DrawProfilesOnly' => false, 'DrawDepthQue' => false,
        'DrawLineEnds' => false, 'ExtendLines' => false, 'JitterEdges' => false,
        'DrawHidden' => false, 'DrawBackEdges' => false,
        'EdgeColorMode' => 1, 'ForegroundColor' => [180, 180, 180],
        'DisplayText' => false, 'DisplayDims' => false, 'DisplaySketchAxes' => false,
        'DisplayInstanceAxes' => false, 'DisplaySectionPlanes' => false,
        'HideConstructionGeometry' => true, 'DisplayFog' => false,
        'MaterialTransparency' => true, 'ModelTransparency' => false,
        'BackgroundColor' => [247, 245, 241], 'DrawHorizon' => true, 'SkyColor' => [200, 218, 234],
        'DrawGround' => true, 'GroundColor' => [216, 209, 198], 'GroundTransparency' => 0,
        'DrawUnderground' => false
      }
    end

    # Schatten (ShadowInfo): Sonne hoch und seitlich, damit Wände des Raums die Küche
    # nicht ganz abdunkeln
    def self.schatten
      {
        'DisplayShadows' => true, 'UseSunForAllShading' => true,
        'Light' => 80, 'Dark' => 50,
        'DisplayOnAllFaces' => true, 'DisplayOnGroundPlane' => true,
        'ShadowTime' => Time.utc(Time.now.year, 6, 21, 12, 30)
      }
    end

    # Planung/Zuschnitt, falls beim Anlegen gerade die Kunden-Szene aktiv ist
    # (sonst würden neu angelegte Szenen den Kundenstil übernehmen)
    def self.planung
      {
        'DrawSilhouettes' => true, 'DrawProfilesOnly' => false, 'EdgeColorMode' => 1,
        'ForegroundColor' => [0, 0, 0], 'DisplayText' => true, 'DisplayDims' => true,
        'DisplaySketchAxes' => true, 'DrawHorizon' => true, 'DrawGround' => false,
        'BackgroundColor' => [255, 255, 255]
      }
    end

    def self.planung_schatten
      { 'DisplayShadows' => false }
    end

    def self.fov
      40.0
    end

    def self.wert(v)
      v.is_a?(Array) ? Sketchup::Color.new(*v) : v
    end

    # Werte setzen, nur bekannte Schlüssel (andere SketchUp-Versionen kennen nicht alle)
    def self.setzen(opts, werte)
      return 0 unless opts
      bekannt = opts.respond_to?(:keys) ? opts.keys : nil
      n = 0
      werte.each do |k, v|
        next if bekannt && !bekannt.include?(k)
        begin
          opts[k] = wert(v)
          n += 1
        rescue StandardError
          next
        end
      end
      n
    end

    def self.merken(opts, schluessel)
      return {} unless opts
      schluessel.each_with_object({}) do |k, h|
        begin
          h[k] = opts[k]
        rescue StandardError
          next
        end
      end
    end

    def self.zuruecksetzen(opts, werte)
      return unless opts
      werte.each do |k, v|
        begin
          opts[k] = v unless v.nil?
        rescue StandardError
          next
        end
      end
    end

    # Kopie einer Kamera; perspektivisch = true macht aus Parallelprojektion Perspektive
    def self.kamera(c, perspektivisch = nil)
      persp = perspektivisch.nil? ? c.perspective? : perspektivisch
      winkel = c.perspective? && c.fov.to_f > 1 ? c.fov : self.fov
      neu = Sketchup::Camera.new(c.eye, c.target, c.up, persp, winkel)
      neu.height = c.height if !persp && c.respond_to?(:height) && neu.respond_to?(:height=)
      neu
    end

    # Vor dem Anlegen der Szenen: steht die Ansicht im Kundenstil, auf Planungsstil zurück
    def self.vorbereiten(model)
      seite = model.pages.selected_page
      return false unless seite && seite.name == szene
      setzen(model.rendering_options, planung)
      setzen(model.shadow_info, planung_schatten)
      true
    end

    # Szene „Kunde“ gestalten; neu = die Szene wurde gerade erst angelegt
    def self.anwenden(model, seite, neu = false)
      return false unless seite
      ro, si, view = model.rendering_options, model.shadow_info, model.active_view
      vorher = { ro: merken(ro, stil.keys), si: merken(si, schatten.keys), cam: view && kamera(view.camera) }

      setzen(ro, stil)
      setzen(si, schatten)
      if view
        quelle = neu ? view.camera : seite.camera
        view.camera = kamera(quelle, true)
      end
      %i[use_camera= use_rendering_options= use_shadow_info=].each { |m| seite.send(m, true) if seite.respond_to?(m) }
      seite.update(1 | 2 | 4) # Kamera, Stil, Schatten (Tags hat szenen_anlegen schon gesetzt)
      # zusätzlich direkt an der Szene, falls SketchUp den geänderten Stil nicht übernimmt
      setzen(seite.rendering_options, stil) if seite.respond_to?(:rendering_options)
      setzen(seite.shadow_info, schatten) if seite.respond_to?(:shadow_info)
      seite.set_attribute('JT_Kundensicht', 'stand', 1) if seite.respond_to?(:set_attribute)

      zuruecksetzen(ro, vorher[:ro])
      zuruecksetzen(si, vorher[:si])
      view.camera = vorher[:cam] if view && vorher[:cam]
      true
    end

    # Auflösungen für das Kundenbild: Titel => [Breite, Höhe] (nil = Fenstergröße)
    def self.aufloesungen
      {
        'Full HD 1920 × 1080' => [1920, 1080],
        'QHD 2560 × 1440' => [2560, 1440],
        '4K 3840 × 2160' => [3840, 2160],
        'A4 quer 300 dpi 3508 × 2480' => [3508, 2480],
        'Fenstergröße' => nil
      }
    end

    # In die Szene „Kunde“ wechseln, ohne Überblendung
    def self.zur_szene(model)
      seite = model.pages[szene]
      unless seite
        Geraete.szenen_anlegen(model)
        seite = model.pages[szene]
      end
      return nil unless seite
      po = model.options['PageOptions'] rescue nil
      alt = po && po['ShowTransition']
      po['ShowTransition'] = false if po
      model.pages.selected_page = seite
      model.active_view.camera = seite.camera if model.active_view && seite.respond_to?(:camera)
      po['ShowTransition'] = alt if po && !alt.nil?
      seite
    end

    # PNG schreiben; liefert den Pfad oder nil
    def self.bild_speichern(model, pfad, groesse, glatt = true)
      zur_szene(model) or return nil
      pfad = "#{pfad}.png" unless pfad.downcase.end_with?('.png')
      opts = { filename: pfad, antialias: glatt, transparent: false }
      opts[:width], opts[:height] = groesse if groesse
      model.active_view.write_image(opts) ? pfad : nil
    end

    # Menü: Erweiterungen › Küchenplaner › Geräte › Kundenbild speichern…
    def self.dialog(model = Sketchup.active_model)
      liste = aufloesungen
      Kuechenplaner::Eingabe.abfragen(['Auflösung', 'Kantenglättung'], [liste.keys.first, 'ja'],
                                      [liste.keys.join('|'), 'ja|nein'], 'Kundenbild speichern',
                                      untertitel: 'Szene „Kunde“ als PNG-Bild', ok: 'Speichern…') do |werte|
        name = File.basename(model.path.to_s, '.skp')
        name = 'Kueche' if name.empty?
        ordner = model.path.to_s.empty? ? nil : File.dirname(model.path)
        pfad = UI.savepanel('Kundenbild speichern', ordner, "#{name}_Kunde.png")
        if pfad
          ergebnis = bild_speichern(model, pfad, liste[werte[0]], werte[1] == 'ja')
          UI.messagebox(ergebnis ? "Kundenbild gespeichert:\n#{ergebnis}" : 'Das Bild konnte nicht gespeichert werden.')
        end
      end
    end
  end
end
