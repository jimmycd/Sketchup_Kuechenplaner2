# encoding: UTF-8
# Schrank-CNC – Griffkatalog (Jürgen, 2026-11-07: „lege einen Griffkatalog an. Man kann pro Küche eine
# Griffserie auswählen, pro Schrank wählt man dann die Größe des Griffes aus, das Programm soll aber einen
# Vorschlag machen abhängig von der Schrankbreite“; „der Griffkatalog soll die Bilder der Griffe beinhalten“;
# „automatische Griffzuordnung ok, muss aber änderbar sein“).
#
# Daten: griffe/<katalog>.json (je Katalog eine Datei, heute Häfele DÉCO Kollektion 2025, aus Jürgens
# Blätterkatalog ausgelesen) mit Serien (Kennung H…, Bauart griff/knopf), je Oberfläche die Größen
# (Länge × Höhe, Lochabstand, Artikel-Nr.) und je Serie ein Bild griffe/<Kennung>.jpg (Fotoseite des Katalogs).
#
# Wahl:
#   Küche     Griffserie und Oberfläche (Küchenplaner › Griffkatalog… oder Einstellungen), im Modell gespeichert
#             (Wörterbuch Kuechenplaner_Einstellungen, griff_serie/griff_oberflaeche). Ohne Serie bleibt alles
#             wie vorher: Griffe nur an Fronten, an denen man sie von Hand setzt.
#   Front     Mit Serie bekommt jede Front und Tür automatisch einen Griff in der vorgeschlagenen Größe.
#             Ändern je Schrank (Beschläge und Griffe der gewählten Schränke…): feste Größe (griff_lochmass),
#             kein Griff (griff_aus), Lage (griff_lage), Höhe (griff_hoehe) – stehen an der Front im Wörterbuch
#             JT_Schrank wie bisher bei „Frontfarbe und Griffe ändern“.
#
# Vorschlag (Regel, nicht aus dem Katalog): Ziel-Lochabstand = 30 % der Frontbreite, genommen wird der
# nächstliegende Lochabstand der Serie (bei Gleichstand der kleinere), der mit VORSCHLAG[:rand] Abstand
# je Seite auf die Front passt. Grundlage ist die Breite der Front, nicht die des Schranks (Doppeltür am
# 800er-Schrank: zwei 400er-Türen → 128 statt 256). Beispiele mit 96/128/160/192/320:
# 300 → 96, 450 → 128, 600 → 192, 900 → 320 (270 liegt näher an 320 als an 192).
# Knopf-Serien: eine Bohrung in der Mitte (Lochabstand 0).
# Höhe (automatisch): Griffmitte möglichst 1000 mm über dem Boden, aber mindestens VORSCHLAG[:kante] von
# Ober- und Unterkante der Front: Unterschrank-Fronten oben, Oberschränke unten, hohe Türen auf 1000 mm.
# Lage (automatisch): Mitte.

require 'json'

module JTools
  module SchrankCnc
    module Griffkatalog
      module_function

      ORDNER = File.join(__dir__, 'griffe')
      DICT = 'Kuechenplaner_Einstellungen'.freeze
      SEKTION = 'Kuechenplaner_Einstellungen'.freeze
      VORSCHLAG = { anteil: 0.3, rand: 20.0, kante: 35.0, griffhoehe: 1000.0 }.freeze
      KEINE = 'keine (Griffe von Hand)'.freeze

      def kataloge
        @kataloge ||= Dir.glob(File.join(ORDNER, '*.json')).sort.map do |f|
          JSON.parse(File.read(f, encoding: 'UTF-8')).merge('datei' => File.basename(f))
        end
      end

      def neu_laden
        @kataloge = nil
        @serien = nil
      end

      # Alle Serien (mit Katalogname und Hersteller)
      def serien
        @serien ||= kataloge.flat_map do |k|
          k['serien'].map { |s| s.merge('katalog' => k['name'], 'hersteller' => k['hersteller']) }
        end
      end

      def serie(kennung)
        serien.find { |s| s['kennung'] == kennung.to_s }
      end

      def knopf?(s)
        s['bauart'] == 'knopf'
      end

      def bild(s)
        File.join(ORDNER, s['bild'] || "#{s['kennung']}.jpg")
      end

      # Lochabstände der Serie (mm, aufsteigend; Knopf: [0])
      def lochabstaende(s)
        return [0.0] if knopf?(s)
        s['oberflaechen'].flat_map { |o| o['groessen'].flat_map { |g| g['lochabstand'] || [] } }.map(&:to_f).uniq.sort
      end

      def oberflaechen(s)
        s['oberflaechen'].map { |o| o['name'] }
      end

      # Anzeigename, z. B. „H2510 Griff (128–320 mm)“, „H2515 Knopf“
      def name(s)
        return "#{s['kennung']} Knopf" if knopf?(s)
        la = lochabstaende(s)
        "#{s['kennung']} Griff (#{[la.first, la.last].uniq.map { |v| zahl(v) }.join('–')} mm)"
      end

      def zahl(v)
        v.to_f == v.to_f.round ? v.to_f.round.to_s : v.to_s.tr('.', ',')
      end

      # Größe (Eintrag aus der Tabelle) für Lochabstand und Oberfläche; Oberfläche fehlt → erste mit der Größe
      def groesse(s, lochabstand, oberflaeche = nil)
        os = s['oberflaechen']
        os = os.select { |o| o['name'] == oberflaeche } + os.reject { |o| o['name'] == oberflaeche } if oberflaeche
        os.each do |o|
          g = o['groessen'].find { |x| knopf?(s) || (x['lochabstand'] || []).any? { |l| (l.to_f - lochabstand.to_f).abs < 0.05 } }
          return g.merge('oberflaeche' => o['name']) if g
        end
        nil
      end

      # Vorgeschlagener Lochabstand für eine Frontbreite (mm), siehe oben
      def vorschlag(s, breite)
        la = lochabstaende(s)
        return la.first if knopf?(s)
        laenge = ->(l) { (groesse(s, l) || {})['laenge'].to_f }
        passt = la.select { |l| laenge.(l) + 2 * VORSCHLAG[:rand] <= breite.to_f + 0.01 }
        passt = [la.first] if passt.empty?
        ziel = VORSCHLAG[:anteil] * breite.to_f
        passt.min_by { |l| [(l - ziel).abs.round(3), l] }
      end

      # --- Wahl der Küche ------------------------------------------------------
      def modell(model)
        model || (defined?(Sketchup) && Sketchup.respond_to?(:active_model) ? Sketchup.active_model : nil)
      end

      def lesen(model, key)
        m = modell(model)
        m.respond_to?(:get_attribute) ? m.get_attribute(DICT, key) : nil
      end

      # Serie der Küche (Eintrag) oder nil
      def kueche(model = nil)
        k = lesen(model, 'griff_serie')
        k && serie(k)
      end

      def oberflaeche(model = nil)
        s = kueche(model) or return nil
        o = lesen(model, 'griff_oberflaeche').to_s
        oberflaechen(s).include?(o) ? o : oberflaechen(s).first
      end

      # Serie (Kennung oder nil = keine) und Oberfläche für die Küche speichern
      def waehlen(kennung, oberflaeche = nil, model = nil)
        m = modell(model)
        if kennung.nil? || kennung.to_s.empty?
          m.delete_attribute(DICT, 'griff_serie') if m.respond_to?(:delete_attribute)
          m.delete_attribute(DICT, 'griff_oberflaeche') if m.respond_to?(:delete_attribute)
          return nil
        end
        s = serie(kennung) or raise ArgumentError, "Unbekannte Griffserie: #{kennung}"
        o = oberflaechen(s).include?(oberflaeche) ? oberflaeche : oberflaechen(s).first
        m.set_attribute(DICT, 'griff_serie', s['kennung'])
        m.set_attribute(DICT, 'griff_oberflaeche', o)
        s
      end

      def fingerabdruck(model = nil)
        "#{lesen(model, 'griff_serie')}/#{lesen(model, 'griff_oberflaeche')}"
      end

      # --- Griff einer Front -------------------------------------------------
      # Griff an einem Werkstück (Front/Tür nach Geometrie.werkstueck), oder nil.
      # Liefert { lochmass:, lage:, hoehe: (ab Unterkante Front), serie:, groesse: (Tabelle mit oberflaeche),
      #           automatisch: (Größe aus dem Vorschlag) }
      def griff(w, model = nil)
        t = w.teil
        return nil if t.jt('griff_aus')
        return nil unless %w[Front Tuer].include?(w.rolle) && t.jt('teil') != 'Blende'
        da = w.dicke_achse
        return nil if da == 2
        wa = da.zero? ? 1 : 0
        s = kueche(model)
        lm = t.jt('griff_lochmass')
        return nil if lm.nil? && s.nil?
        auto = lm.nil?
        lm = auto ? vorschlag(s, w.mass(wa)) : lm.to_f
        h = t.jt('griff_hoehe')
        h = h.nil? ? hoehe_auto(w) : h.to_f
        g = s && groesse(s, lm, oberflaeche(model))
        g = nil if g && !knopf?(s) && lm <= 0
        lage = t.jt('griff_lage').to_s
        lage = 'Mitte' if lage.empty?
        { lochmass: lm, lage: lage, hoehe: h, serie: g ? s : nil, groesse: g, automatisch: auto }
      end

      # Griffangaben an einer Front (Instanz) setzen (Schrank-Dialog): groesse nil = unverändert,
      # :vorschlag = Größe nach Frontbreite, :aus = kein Griff, Zahl = fester Lochabstand (0 = Knopf);
      # lage nil = unverändert, :auto = automatisch (Mitte), sonst links/Mitte/rechts;
      # hoehe nil = unverändert, :auto = automatisch, Zahl = mm ab Unterkante Front
      def front_setzen(inst, g)
        d = 'JT_Schrank'
        case g[:groesse]
        when :vorschlag then inst.delete_attribute(d, 'griff_lochmass'); inst.delete_attribute(d, 'griff_aus')
        when :aus then inst.set_attribute(d, 'griff_aus', true)
        when Numeric then inst.set_attribute(d, 'griff_lochmass', g[:groesse].to_f); inst.delete_attribute(d, 'griff_aus')
        end
        case g[:lage]
        when :auto then inst.delete_attribute(d, 'griff_lage')
        when String then inst.set_attribute(d, 'griff_lage', g[:lage])
        end
        case g[:hoehe]
        when :auto then inst.delete_attribute(d, 'griff_hoehe')
        when Numeric then inst.set_attribute(d, 'griff_hoehe', g[:hoehe].to_f)
        end
      end

      # Höhe der Griffmitte über der Unterkante der Front (siehe oben)
      def hoehe_auto(w)
        k = VORSCHLAG[:kante]
        hoehe = w.mass(2)
        return hoehe / 2.0 if hoehe <= 2 * k
        (VORSCHLAG[:griffhoehe] - w.lo[2]).clamp(k, hoehe - k)
      end

      # Text für Beschlagliste und Dialoge
      def bezeichnung(g)
        s = g[:serie]
        return "Griff Lochabstand #{zahl(g[:lochmass])} mm (nicht im Griffkatalog)" unless s
        gr = g[:groesse]
        art = knopf?(s) ? 'Knopf' : "Griff #{zahl(g[:lochmass])} mm"
        "#{s['hersteller']} #{s['kennung']} #{art}, #{gr['oberflaeche']}#{gr['ausfuehrung'] ? " (#{gr['ausfuehrung']})" : ''}"
      end

      def hinweis(g)
        gr = g[:groesse] or return 'Lochabstand frei gewählt'
        mass = knopf?(g[:serie]) ? "Ø #{zahl(gr['laenge'])}" : zahl(gr['laenge'])
        "Art.-Nr. #{gr['artikel']}, #{mass} × #{zahl(gr['hoehe'])} mm"
      end

      # Fehler in den Katalogdaten (für den Test)
      def fehler
        f = []
        kennungen = serien.map { |s| s['kennung'] }
        f << 'Kennungen doppelt' if kennungen.uniq.size != kennungen.size
        serien.each do |s|
          f << "#{s['kennung']}: Bild fehlt" unless File.file?(bild(s))
          f << "#{s['kennung']}: Bauart #{s['bauart']}" unless %w[griff knopf].include?(s['bauart'])
          f << "#{s['kennung']}: keine Oberflächen" if s['oberflaechen'].to_a.empty?
          s['oberflaechen'].to_a.each do |o|
            f << "#{s['kennung']}: Oberfläche ohne Namen" if o['name'].to_s.strip.empty?
            o['groessen'].each do |g|
              f << "#{s['kennung']} #{o['name']}: Artikel-Nr. #{g['artikel']}" unless g['artikel'].to_s =~ /\A\d{3}\.\d{2}\.\d{3}\z/
              f << "#{s['kennung']} #{o['name']}: Maße" unless g['laenge'].to_f > 0 && g['hoehe'].to_f > 0
              f << "#{s['kennung']} #{o['name']}: Lochabstand" if knopf?(s) != g['lochabstand'].nil?
            end
          end
        end
        f
      end
    end
  end
end
