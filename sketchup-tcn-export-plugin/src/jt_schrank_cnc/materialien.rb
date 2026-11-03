# encoding: UTF-8
# Schrank-CNC – Materialien (Plattenwerkstoffe und Anleimer) ohne OpenCutList.
#
# Ein Material ist ein SketchUp-Material mit Angaben für Stückliste, Zuschnitt und
# TCN-Export. Die Angaben stehen wie bisher im Wörterbuch „ladb_opencutlist“ am Material
# (dasselbe Format wie OpenCutList, damit alte Modelle und alle Komponenten ohne Umbau
# weiterlaufen): type 2 = Platte, 4 = Kante; std_thicknesses, std_sizes, grained bei
# Platten; thickness, std_widths, edge_decremented bei Kanten. Dazu im Wörterbuch
# JT_Material: verwendung (Korpus, Front, Rückwand) und kante (Name des passenden Anleimers).
# Nur dieses Modul liest und schreibt die Angaben.
#
# Bibliothek: jedes im Dialog gespeicherte Material steht auch in der Bibliothek auf diesem
# Rechner (Sketchup.write_default) und wird in ein Modell übernommen, sobald man es dort
# auswählt (Frontfarbe, Korpusmaterial) – so stehen eigene Materialien in jedem Modell bereit.
#
# Maserrichtung: bei Platten mit Maserung läuft die Faser bei Fronten, Türen und
# Sichtteilen senkrecht, sonst längs der längeren Seite. Am Teil überschreibt
# JT_Schrank/maserung („senkrecht“, „waagrecht“, „längere Seite“) das.

require 'json'

module JTools
  module SchrankCnc
    module Materialien
      module_function

      OCL_DICT = 'ladb_opencutlist'.freeze
      JT_MAT   = 'JT_Material'.freeze
      PLATTE   = 2
      KANTE    = 4
      VERWENDUNGEN = %w[Korpus Front Rückwand].freeze
      BIB_SEKTION  = 'JT_SchrankCnc_Materialien'.freeze
      MASERUNGEN   = ['automatisch', 'senkrecht', 'waagrecht', 'längere Seite'].freeze
      STANDARD_FORMAT = [2800.0, 2070.0].freeze

      # ------------------------------------------------------------------
      # Angaben lesen
      # ------------------------------------------------------------------
      def ocl(m, k)
        m && m.get_attribute(OCL_DICT, k)
      end

      def typ(m)
        ocl(m, 'type').to_i
      end

      def platte?(m)
        typ(m) == PLATTE
      end

      def kante?(m)
        typ(m) == KANTE
      end

      # "19mm", "1,9 cm", "0.75\"" -> mm
      def mm(v)
        s = v.to_s.strip.tr(',', '.')
        z = s[/-?\d+(\.\d+)?/].to_f
        case s
        when /cm\z/ then z * 10
        when /\bm\z/ then z * 1000
        when /("|in)\z/ then z * 25.4
        else z
        end
      end

      def mm_text(v)
        v = v.to_f.round(1)
        "#{v == v.to_i ? v.to_i : v}mm"
      end

      # Plattenstärke (erste Standardstärke) in mm, nil wenn keine angegeben
      def staerke(m)
        s = ocl(m, 'std_thicknesses').to_s.split(';').first
        s && mm(s) > 0 ? mm(s) : nil
      end

      # Anleimerstärke einer Kante in mm (ohne Angabe 2 mm)
      def kantendicke(m)
        d = mm(ocl(m, 'thickness'))
        d > 0 ? d : 2.0
      end

      def kantenbreite(m)
        s = ocl(m, 'std_widths').to_s.split(';').first
        s ? mm(s) : nil
      end

      # Plattenformat [Länge, Breite] in mm aus "2800mm x 2070mm;4100mm x 1300mm" (erstes Format)
      def plattenformat(m)
        s = ocl(m, 'std_sizes').to_s.split(';').first.to_s
        t = s.split(/x/i).map { |v| mm(v) }
        t.size == 2 && t.all? { |v| v > 0 } ? t.sort.reverse : nil
      end

      def maserung?(m)
        v = ocl(m, 'grained')
        v == true || v.to_s == 'true'
      end

      # Verwendung aus JT_Material, sonst aus dem Namen („Front …“ wie früher, „Rück…“)
      def verwendung(m)
        v = m && m.get_attribute(JT_MAT, 'verwendung')
        return v if VERWENDUNGEN.include?(v)
        n = m ? m.name.to_s : ''
        return 'Front' if n.start_with?('Front')
        return 'Rückwand' if n =~ /\Ar(ü|ue)ck/i
        'Korpus'
      end

      def platten(model, verwendung = nil)
        model.materials.to_a.select { |m| platte?(m) && (verwendung.nil? || Array(verwendung).include?(verwendung(m))) }
             .sort_by { |m| m.name.to_s }
      end

      def kanten(model)
        model.materials.to_a.select { |m| kante?(m) }.sort_by { |m| m.name.to_s }
      end

      # Namen der Platten im Modell und in der Bibliothek (für Auswahllisten)
      def plattennamen(model, verwendung = nil)
        im_modell = platten(model, verwendung).map { |m| m.name.to_s }
        bib = bibliothek.select do |e|
          e['typ'] == 'platte' && (verwendung.nil? || Array(verwendung).include?(e['verwendung']))
        end.map { |e| e['name'] }
        (im_modell + bib).uniq.sort
      end

      # Zugeordneter Anleimer (JT_Material/kante), nil ohne Zuordnung
      def kante_zu(model, platte)
        n = platte && platte.get_attribute(JT_MAT, 'kante')
        k = n && holen(model, n)
        kante?(k) ? k : nil
      end

      # "Front Eiche hell 19mm" -> "Eiche hell"
      def dekor(name)
        name.to_s.sub(/\AFront\s*/, '').sub(/\s*\d+([.,]\d+)?\s*mm\z/i, '').strip
      end

      # Anleimer zur Platte: Zuordnung, sonst eine Kante mit dem Dekor im Namen, sonst neu
      # „Anleimer <Dekor>“ (2 mm, Farbe der Platte); die Zuordnung wird an der Platte gemerkt
      def anleimer(model, platte)
        k = kante_zu(model, platte)
        return k if k
        d = dekor(platte.name)
        vorhanden = kanten(model).select { |m| !d.empty? && m.name.to_s.downcase.include?(d.downcase) }
        k = vorhanden.min_by { |m| m.name.to_s.length }
        k ||= kante_setzen(model, name: "Anleimer #{d.empty? ? platte.name : d}", farbe: platte.color,
                           dicke: 2.0, breite: 23.0, bibliothek: false)
        platte.set_attribute(JT_MAT, 'kante', k.name.to_s)
        k
      end

      # ------------------------------------------------------------------
      # Angaben schreiben
      # ------------------------------------------------------------------
      # "#rrggbb", "r,g,b" oder Sketchup::Color -> Sketchup::Color (nil bei leer)
      def farbe(v)
        return v if v.is_a?(Sketchup::Color)
        s = v.to_s.strip
        return nil if s.empty?
        rgb = if s =~ /\A#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})\z/i
                [$1, $2, $3].map { |x| x.to_i(16) }
              elsif s =~ /\A(\d{1,3})\s*[,; ]\s*(\d{1,3})\s*[,; ]\s*(\d{1,3})\z/
                [$1, $2, $3].map(&:to_i)
              end
        raise ArgumentError, "Farbe „#{s}“ nicht lesbar (z. B. #E8E4DC oder 232,228,220)" unless rgb && rgb.all? { |x| x <= 255 }
        Sketchup::Color.new(*rgb)
      end

      def farbe_text(m)
        c = m && m.color
        return '' unless c && c.respond_to?(:red)
        format('#%02X%02X%02X', c.red, c.green, c.blue)
      end

      # Material anlegen oder umbenennen; alt = bisheriger Name
      def material_holen(model, name, alt = nil)
        name = name.to_s.strip
        raise ArgumentError, 'Name fehlt' if name.empty?
        m = alt && model.materials[alt]
        andere = model.materials[name]
        raise ArgumentError, "„#{name}“ gibt es schon" if andere && !andere.equal?(m)
        if m
          m.name = name if m.name.to_s != name
          m
        else
          andere || model.materials.add(name)
        end
      end

      def textur_setzen(m, bild, breite)
        return if bild.to_s.strip.empty? || !m.respond_to?(:texture=)
        raise ArgumentError, "Texturbild „#{bild}“ nicht gefunden" unless File.exist?(bild.to_s.strip)
        m.texture = bild.to_s.strip
        m.texture.size = (breite.to_f > 0 ? breite.to_f : 1000.0) / 25.4 if m.texture.respond_to?(:size=)
      end

      def platte_setzen(model, name:, verwendung: 'Korpus', farbe: nil, staerke: 19.0, format: STANDARD_FORMAT,
                        maserung: false, kante: nil, textur: nil, textur_breite: nil, alt: nil, bibliothek: true)
        raise ArgumentError, "Verwendung „#{verwendung}“ unbekannt" unless VERWENDUNGEN.include?(verwendung)
        raise ArgumentError, 'Stärke muss größer 0 sein' unless staerke.to_f > 0
        raise ArgumentError, 'Plattenformat muss größer 0 sein' unless format.size == 2 && format.all? { |v| v.to_f > 0 }
        m = material_holen(model, name, alt)
        f = self.farbe(farbe)
        m.color = f if f
        textur_setzen(m, textur, textur_breite)
        l, b = format.map(&:to_f).sort.reverse
        { 'type' => PLATTE, 'std_thicknesses' => mm_text(staerke), 'std_sizes' => "#{mm_text(l)} x #{mm_text(b)}",
          'grained' => maserung ? true : false }.each { |k, v| m.set_attribute(OCL_DICT, k, v) }
        m.set_attribute(JT_MAT, 'verwendung', verwendung)
        m.set_attribute(JT_MAT, 'kante', kante.to_s) unless kante.nil?
        m.set_attribute(JT_MAT, 'textur', textur.to_s.strip) unless textur.to_s.strip.empty?
        bibliothek_speichern(m, alt) if bibliothek
        m
      end

      def kante_setzen(model, name:, farbe: nil, dicke: 2.0, breite: 23.0, alt: nil, bibliothek: true)
        raise ArgumentError, 'Dicke muss größer 0 sein' unless dicke.to_f > 0
        raise ArgumentError, 'Breite muss größer 0 sein' unless breite.to_f > 0
        m = material_holen(model, name, alt)
        f = self.farbe(farbe)
        m.color = f if f
        { 'type' => KANTE, 'thickness' => mm_text(dicke), 'std_widths' => mm_text(breite), 'std_lengths' => '75m',
          'edge_decremented' => true }.each { |k, v| m.set_attribute(OCL_DICT, k, v) }
        if alt && alt != m.name.to_s
          # Zuordnungen auf den neuen Namen umstellen
          platten(model).each { |p| p.set_attribute(JT_MAT, 'kante', m.name.to_s) if p.get_attribute(JT_MAT, 'kante') == alt }
          bib_aendern { |l| l.each { |e| e['kante'] = m.name.to_s if e['kante'] == alt } }
        end
        bibliothek_speichern(m, alt) if bibliothek
        m
      end

      # Material löschen (Modell und Bibliothek). SketchUp setzt die Teile damit auf „Standard“.
      def loeschen(model, name)
        m = model.materials[name]
        model.materials.remove(m) if m && model.materials.respond_to?(:remove)
        bib_aendern { |l| l.reject! { |e| e['name'] == name } }
      end

      # ------------------------------------------------------------------
      # Bibliothek auf diesem Rechner
      # ------------------------------------------------------------------
      def bibliothek
        l = JSON.parse(Sketchup.read_default(BIB_SEKTION, 'liste', '[]').to_s)
        l.is_a?(Array) ? l.select { |e| e.is_a?(Hash) && e['name'] } : []
      rescue JSON::ParserError
        []
      end

      def bib_aendern
        l = bibliothek
        yield l
        Sketchup.write_default(BIB_SEKTION, 'liste', JSON.generate(l))
      end

      def daten(m)
        if kante?(m)
          { 'name' => m.name.to_s, 'typ' => 'kante', 'farbe' => farbe_text(m), 'dicke' => kantendicke(m),
            'breite' => kantenbreite(m) || 23.0 }
        else
          { 'name' => m.name.to_s, 'typ' => 'platte', 'farbe' => farbe_text(m), 'verwendung' => verwendung(m),
            'staerke' => staerke(m) || 19.0, 'format' => plattenformat(m) || STANDARD_FORMAT, 'maserung' => maserung?(m),
            'kante' => m.get_attribute(JT_MAT, 'kante'), 'textur' => m.get_attribute(JT_MAT, 'textur') }
        end
      end

      def bibliothek_speichern(m, alt = nil)
        e = daten(m)
        bib_aendern do |l|
          l.reject! { |x| x['name'] == e['name'] || (alt && x['name'] == alt) }
          l << e
          l.sort_by! { |x| x['name'] }
        end
      end

      def in_bibliothek?(name)
        bibliothek.any? { |e| e['name'] == name }
      end

      # Material aus dem Modell, sonst aus der Bibliothek ins Modell übernehmen (nil wenn unbekannt)
      def holen(model, name)
        m = model.materials[name]
        return m if m
        e = bibliothek.find { |x| x['name'] == name }
        return nil unless e
        if e['typ'] == 'kante'
          kante_setzen(model, name: e['name'], farbe: e['farbe'], dicke: e['dicke'], breite: e['breite'], bibliothek: false)
        else
          holen(model, e['kante']) if e['kante'] && !e['kante'].empty?
          textur = e['textur'] && File.exist?(e['textur'].to_s) ? e['textur'] : nil
          platte_setzen(model, name: e['name'], verwendung: e['verwendung'] || 'Korpus', farbe: e['farbe'],
                               staerke: e['staerke'], format: e['format'], maserung: e['maserung'], kante: e['kante'],
                               textur: textur, bibliothek: false)
        end
      end

      # ------------------------------------------------------------------
      # Maserrichtung
      # ------------------------------------------------------------------
      # Faser senkrecht: Fronten, Türen, Innenfronten, Sichtteile mit Frontfarbe
      def senkrecht_standard?(teil)
        teil.frontfarbe? || teil.rolle == 'Innenfront'
      end

      # Achse (0 x, 1 y, 2 z in Weltkoordinaten) der Faser für ein Werkstück, längere Seite als Rückfall
      def maser_achse(teil, achsen, laengen)
        laengere = achsen.max_by { |a| [laengen[a].round(3), -a] }
        regel = teil.jt('maserung').to_s
        regel = senkrecht_standard?(teil) ? 'senkrecht' : 'längere Seite' if regel.empty? || regel == 'automatisch'
        case regel
        when 'senkrecht' then achsen.include?(2) ? 2 : laengere
        when 'waagrecht' then achsen.include?(2) ? (achsen - [2]).first : laengere
        else laengere
        end
      end

      # Maserrichtung an Teilen setzen ('automatisch' entfernt die Angabe)
      def maserung_setzen(teile, regel)
        raise ArgumentError, "Maserrichtung „#{regel}“ unbekannt" unless MASERUNGEN.include?(regel)
        teile.each do |t|
          if regel == 'automatisch'
            t.inst.delete_attribute(JT_DICT, 'maserung')
          else
            t.inst.set_attribute(JT_DICT, 'maserung', regel)
          end
        end
        teile.size
      end
    end
  end
end
