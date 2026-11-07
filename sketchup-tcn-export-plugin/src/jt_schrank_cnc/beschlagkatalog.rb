# encoding: UTF-8
# Schrank-CNC – Beschlag-Katalog (Jürgen, 2026-11-06: „konfigurierbar, jede Beschlagart einmal
# für die ganze Küche“).
#
# Jedes Modell ist eine JSON-Datei in katalog/ (eine Datei je Modell). Sie nennt die Beschlagart
# (wo es gewählt wird, z. B. „klappe“) und die Bauart (welcher Rechenweg in Regeln, Beschlagliste
# und Beschlagmodell es auswertet) und enthält alle Zahlen: Bohrbild Korpus und Front mit
# Bezugskanten, Beschlagliste, vereinfachte Modellkörper, Einsatzbereich und Quelle.
# Ein neues Modell einer vorhandenen Bauart ist nur eine neue Datei.
#
# Gewählt wird je Beschlagart einmal für die ganze Küche (Küchenplaner › Einstellungen…,
# Abschnitt Beschläge), gespeichert im Modell im Wörterbuch Kuechenplaner_Einstellungen wie
# Sockelhöhe und Wandabstand; ein neues Modell übernimmt die zuletzt gewählten Beschläge dieses
# Rechners. Alte Küchen ohne Einstellung: ein Oberschrank mit Klappe, der noch die frühere
# Option Free Slim (Art_Klappe 3) trägt, behält Free Slim, bis die Einstellung gespeichert wird.
#
# Schubladenauszug (Bauart auszug_zarge): die Schränke bauen Kastenboden, Holzrückwand und Zarge
# mit den Attributen Ausz_* (gemeinsam/schubkasten.rb). Beim Wechsel schreibt waehlen die Werte des
# neuen Systems in das Modell und in jeden Schrank und zeichnet ihn neu (Jürgen: „automatisch“).

require 'json'

module JTools
  module SchrankCnc
    module Beschlagkatalog
      module_function

      DICT = 'Kuechenplaner_Einstellungen'.freeze
      SEKTION = 'Kuechenplaner_Einstellungen'.freeze
      ORDNER = File.join(__dir__, 'katalog')

      # Beschlagart => Bezeichnung im Dialog, Standardmodell, Bauarten, die sie annimmt
      ARTEN = {
        'schubladen' => { name: 'Schubladenauszug', standard: 'blum-legrabox-free', bauarten: %w[auszug_zarge] },
        'topfband' => { name: 'Topfband (Türen)', standard: 'blum-clip-top', bauarten: %w[topfband_platte] },
        # Türen vor Innenauszügen (Hochschrank Vorrat): Blum empfiehlt das 155°-Scharnier mit 0-Einsprung,
        # damit die geöffnete Tür die lichte Weite freigibt (Katalog 2024/2025 S. 84)
        'topfband_innen' => { name: 'Topfband vor Innenauszügen', standard: 'blum-clip-top-155', bauarten: %w[topfband_platte],
                              auch: %w[topfband] },
        # Schlepptür vor dem Einbau-Kühlschrank (Hochschrank Kühlschrank, Tuertechnik 1): Möbeltür am Korpus,
        # Gerätetür wird mitgenommen; Blum MODUL Kühlschrank-Schlepptürscharnier (Katalog 2024/2025 S. 168)
        'topfband_kuehlschrank' => { name: 'Topfband Kühlschrank-Schlepptür', standard: 'blum-modul-kuehlschrank',
                                     bauarten: %w[topfband_platte], auch: %w[topfband] },
        # Eckschrank L: Scharnier zwischen den beiden Türen der Falttür (Katalog 2024/2025 S. 116); die Tür
        # am Korpus bekommt das Topfband vor Innenauszügen (155° oder 170°, nur damit erlaubt)
        'falttuer' => { name: 'Falttür-Eckscharnier (Eckschrank L)', standard: 'blum-clip-top-falttuer', bauarten: %w[falttuer_eck] },
        'klappe' => { name: 'Klappe (eine Klappe)', standard: 'blum-aventos-hk-top', bauarten: %w[klappe_seite] },
        'faltklappe' => { name: 'Faltklappe (zweiteilig)', standard: 'blum-aventos-hf-top', bauarten: %w[faltklappe_seite] },
        'hochauszug' => { name: 'Hochauszug (Handtuchauszug)', standard: 'haefele-hu-slim-base', bauarten: %w[hochauszug_seite] },
        'eckauszug' => { name: 'Eckauszug (Eckschrank Le Mans)', standard: 'kesseboehmer-lemans-ii', bauarten: %w[eckauszug_saeule] },
        # Griffe oder grifflos (Blum TIP-ON / SERVO-DRIVE): Türen bekommen TIP-ON an der Öffnungskante,
        # Schubladen und Klappen die Öffnungsunterstützung in der Beschlagliste
        'oeffnung' => { name: 'Öffnung (Griffe oder grifflos)', standard: 'griffe', bauarten: %w[oeffnung] },
        # Sockelversteller unter dem Korpusboden (Unter- und Hochschränke): Bohrbild im Boden, Fuß passend
        # zur Sockelhöhe der Küche in der Beschlagliste (Häfele MB 2026, Kap. 9; Jürgen 2026-11-07)
        'sockelfuss' => { name: 'Sockelfuß (Sockelversteller)', standard: 'haefele-axilo-78-schrauben', bauarten: %w[sockelfuss] }
      }.freeze

      # Schränke, die einen Beschlag dieser Art tragen, sind in JT_Schrank/beschlag markiert
      # (Wert aus der Komponente, steht so auch in alten Küchen)
      JT_BESCHLAG = { 'Haefele HU Slim Base' => 'hochauszug', 'Kesseboehmer LeMans II' => 'eckauszug' }.freeze

      # Pflichtteile je Bauart (der Test prüft jeden Eintrag)
      PFLICHT = {
        'auszug_zarge' => %w[schiene zargen standard_zarge kasten front boden_falz stabilisierung_ab liste koerper],
        'klappe_seite' => %w[seite front liste koerper],
        'faltklappe_seite' => %w[seite front scharnier platte liste koerper],
        'hochauszug_seite' => %w[schiene front bauraum liste koerper],
        'eckauszug_saeule' => %w[groessen korpus_min lager lager_schraube profil tiefe_min strebe_min liste koerper],
        'topfband_platte' => %w[topf verteilung platte liste koerper],
        'falttuer_eck' => %w[topf platte liste koerper],
        'oeffnung' => %w[liste],
        'sockelfuss' => %w[hoehen bohrung lage verteilung liste]
      }.freeze

      # Frühere Klappen-Option im Oberschrank mit Klappe (Art_Klappe 3 = Free Slim)
      ALT_KLAPPE = { 3 => 'haefele-free-slim-1.12' }.freeze

      def eintraege
        @eintraege ||= Dir.glob(File.join(ORDNER, '*.json')).sort.map do |f|
          JSON.parse(File.read(f, encoding: 'UTF-8')).merge('datei' => File.basename(f))
        end
      end

      # Eintrag mit Symbol-Schlüsseln (Zahlen-Schlüssel wie "40" als Integer) für die Rechnung
      def werte(e)
        tief = lambda do |v|
          case v
          when Hash then v.map { |k, x| [k =~ /\A\d+\z/ ? k.to_i : k.to_sym, tief.(x)] }.to_h
          when Array then v.map { |x| tief.(x) }
          else v
          end
        end
        tief.(e)
      end

      def neu_laden
        @eintraege = nil
      end

      def eintrag(kennung)
        eintraege.find { |e| e['kennung'] == kennung }
      end

      # Modelle, die für die Beschlagart passen: ihre eigene Art oder eine Art aus ARTEN[art][:auch]
      # (jedes normale Topfband kann auch vor Innenauszügen oder an der Kühlschrank-Schlepptür gewählt werden)
      def passt?(e, art)
        e['art'] == art || (ARTEN[art] && (ARTEN[art][:auch] || []).include?(e['art']) && ARTEN[art][:bauarten].include?(e['bauart']))
      end

      def zur_art(art)
        eintraege.select { |e| passt?(e, art) }.sort_by { |e| e['name'] }
      end

      # Fehlerliste eines Eintrags (leer = in Ordnung)
      def fehler(e)
        f = []
        %w[kennung name hersteller art bauart quelle].each { |k| f << "#{k} fehlt" if e[k].to_s.strip.empty? }
        f << "Beschlagart #{e['art']} unbekannt" unless ARTEN.key?(e['art'])
        f << "Bauart #{e['bauart']} unbekannt" unless PFLICHT.key?(e['bauart'])
        (PFLICHT[e['bauart']] || []).each { |k| f << "#{k} fehlt" unless e[k] }
        f << "Datei #{e['datei']} passt nicht zur Kennung" if e['datei'] && e['datei'] != "#{e['kennung']}.json"
        f.concat(fehler_auszug(e)) if e['bauart'] == 'auszug_zarge' && e['zargen'] && e['schiene'] && e['kasten']
        f.concat(fehler_sockelfuss(e)) if e['bauart'] == 'sockelfuss' && e['hoehen'] && e['bohrung'] && e['liste']
        f
      end

      # Sockelfuß: Höhen aufsteigend mit Einstellbereich und Artikel-Nr., Bohrbild mit Punkten ab (0, 0)
      def fehler_sockelfuss(e)
        f = []
        h = e['hoehen']
        f << 'Höhen nicht aufsteigend' unless h.map { |x| x['bauhoehe'] } == h.map { |x| x['bauhoehe'] }.sort
        h.each { |x| f << "Höhe #{x['bauhoehe']}: Einstellbereich oder Artikel fehlt" unless x['von'] && x['bis'] && x['von'] <= x['bis'] && x['artikel'] }
        pk = e['bohrung']['punkte']
        f << 'Bohrbild ohne Punkte' if pk.to_a.empty?
        f << 'Bohrbild beginnt nicht bei 0' unless pk.to_a.empty? || pk.map(&:first).min.zero? && pk.map(&:last).min.zero?
        f << 'Bohrtiefe fehlt' unless e['bohrung']['tiefe'] || e['bohrung']['durch']
        f << 'liste.fuss fehlt' unless e['liste']['fuss']
        f
      end

      # Sockelfuß für eine Sockelhöhe (mm): die Höhe, deren Einstellbereich sie enthält (bei zweien die,
      # in deren Mitte sie näher liegt), sonst die nächste mit passt = false
      def sockelfuss_hoehe(e, sockel)
        s = sockel.to_f
        mitte = ->(x) { ((x['von'] + x['bis']) / 2.0 - s).abs }
        drin = e['hoehen'].select { |x| s >= x['von'] - 0.01 && s <= x['bis'] + 0.01 }
        return drin.min_by(&mitte).merge('passt' => true) unless drin.empty?
        n = e['hoehen'].min_by { |x| [(x['von'] - s).abs, (x['bis'] - s).abs].min }
        n.merge('passt' => false)
      end

      # Einstellbereich aller Höhen eines Sockelfußes [von, bis]
      def sockelfuss_bereich(e)
        [e['hoehen'].map { |x| x['von'] }.min, e['hoehen'].map { |x| x['bis'] }.max]
      end

      # Auszug: Zargen von hoch nach niedrig (die Schränke nehmen die höchste, die passt), höchstens
      # Kuechenplaner::Schubkasten::STUFEN, Standardzarge vorhanden, Nennlängen in gleichen Schritten
      def fehler_auszug(e)
        f = []
        h = e['zargen'].values.map { |z| z['hoehe'] }
        f << 'Zargen nicht von hoch nach niedrig' unless h == h.sort.reverse
        f << "mehr als #{Kuechenplaner::Schubkasten::STUFEN} Zargen" if defined?(Kuechenplaner::Schubkasten) && h.size > Kuechenplaner::Schubkasten::STUFEN
        f << "Standardzarge #{e['standard_zarge']} fehlt" unless e['zargen'][e['standard_zarge']]
        nl = e['schiene']['hinten'].keys.map(&:to_i).sort
        f << 'Nennlängen nicht in gleichen Schritten' if nl.each_cons(2).map { |a, b| b - a }.uniq.size > 1
        f
      end

      def modell(model)
        model || (defined?(Sketchup) && Sketchup.respond_to?(:active_model) ? Sketchup.active_model : nil)
      end

      def schluessel(art)
        "beschlag_#{art}"
      end

      # Im Modell gespeicherte Wahl (Kennung) oder nil
      def gespeichert(art, model = nil)
        m = modell(model)
        k = m.get_attribute(DICT, schluessel(art)) if m.respond_to?(:get_attribute)
        k && eintrag(k) ? k : nil
      end

      # ---------------------------------------------------------------------
      # Abweichung je Schrank (Jürgen, 2026-11-07: „an jedem Schrank individuell die generelle Einstellung
      # für Beschläge und Griffe ändern“): am Schrank (äußerste Instanz) steht im Wörterbuch JT_Schrank
      # beschlag_<art> = Kennung; fehlt der Eintrag, gilt die Wahl der Küche. Regeln, Beschlagliste und
      # Beschlagmodell rechnen je Schrank in mit_schrank, damit gilt dort die Wahl dieses Schranks.
      # ---------------------------------------------------------------------
      SCHRANK_DICT = 'JT_Schrank'.freeze

      def aktueller_schrank
        @schrank
      end

      # Block mit der Wahl dieses Schranks rechnen (verschachtelt möglich)
      def mit_schrank(schrank)
        alt = @schrank
        @schrank = schrank
        yield
      ensure
        @schrank = alt
      end

      # Schrank einer Gruppe von Werkstücken (alle aus einem Schrank, gruppiert nach teil.pfad.first)
      def schrank_von(werkstuecke)
        t = werkstuecke.first && werkstuecke.first.teil
        t && (t.schrank || t.pfad.first)
      end

      # Eigene Wahl des Schranks (Kennung) oder nil = wie Küche
      def eigen(art, schrank)
        return nil unless schrank.respond_to?(:get_attribute)
        k = schrank.get_attribute(SCHRANK_DICT, schluessel(art))
        e = k && eintrag(k)
        e && passt?(e, art) ? k : nil
      end

      # Abweichende Wahl am Schrank setzen; kennung nil = wieder wie die Küche.
      # Beim Schubladenauszug passt sich der Schrank an (Ausz_* und neu zeichnen); Rückgabe false,
      # wenn er das nicht kann (ältere Version ohne Ausz_*)
      def schrank_waehlen(schrank, art, kennung, model = nil)
        if kennung
          e = eintrag(kennung)
          raise ArgumentError, "Unbekannter Beschlag: #{kennung}" unless e && passt?(e, art)
          schrank.set_attribute(SCHRANK_DICT, schluessel(art), kennung)
        else
          schrank.delete_attribute(SCHRANK_DICT, schluessel(art)) if schrank.respond_to?(:delete_attribute)
        end
        return true unless art == 'schubladen'
        w = schubkasten_werte(gewaehlt('schubladen', model, schrank: schrank))
        schrank_anpassen(schrank, Kuechenplaner::Schubkasten.attribute(w), w) != :alt
      end

      # Kennungen, in denen der Schrank von der Küche abweicht ({ art => kennung })
      def abweichungen(schrank)
        ARTEN.keys.map { |a| [a, eigen(a, schrank)] }.select(&:last).to_h
      end

      # Gewähltes Modell (Eintrag) der Beschlagart: eigene Wahl des Schranks (schrank:, sonst der Schrank
      # aus mit_schrank), sonst die Wahl der Küche (kueche)
      def gewaehlt(art, model = nil, schrank: @schrank)
        k = eigen(art, schrank)
        return eintrag(k) if k
        kueche(art, model)
      end

      # Wahl der ganzen Küche: Modell, sonst zuletzt auf diesem Rechner gewählt, sonst Standard
      def kueche(art, model = nil)
        k = gespeichert(art, model)
        if k.nil? && defined?(Sketchup) && Sketchup.respond_to?(:read_default)
          v = Sketchup.read_default(SEKTION, schluessel(art), nil)
          k = v if v && eintrag(v)
        end
        eintrag(k || ARTEN.fetch(art)[:standard])
      end

      # Klappenmodell für einen Schrank (Übergang für alte Küchen, siehe oben)
      def klappe_fuer(schrank, model = nil)
        k = eigen('klappe', schrank)
        return eintrag(k) if k
        unless gespeichert('klappe', model)
          alt = ALT_KLAPPE[Schraenke.dc(schrank, 'art_klappe').to_f.round] if schrank
          return eintrag(alt) if alt
        end
        gewaehlt('klappe', model)
      end

      # Vorschlag im Dialog: gespeichert, sonst das Klappenmodell, das die meisten Schränke heute haben
      def vorschlag(art, model = nil)
        k = gespeichert(art, model)
        return eintrag(k) if k
        if art == 'klappe' && (m = modell(model)).respond_to?(:entities)
          alt = Schraenke.instanzen(m.entities).map { |s| ALT_KLAPPE[Schraenke.dc(s, 'art_klappe').to_f.round] }.compact
          return eintrag(alt.max_by { |a| alt.count(a) }) unless alt.empty?
        end
        kueche(art, model)
      end

      # Wahl speichern; beim Schubladenauszug passen sich die Schränke an (Rückgabe: Eintrag und
      # Liste der Schränke, die das nicht können, weil sie mit einer älteren Version angelegt sind)
      def waehlen(art, kennung, model = nil)
        e = eintrag(kennung)
        raise ArgumentError, "Unbekannter Beschlag: #{kennung}" unless e && passt?(e, art)
        m = modell(model)
        m.set_attribute(DICT, schluessel(art), kennung) if m.respond_to?(:set_attribute)
        Sketchup.write_default(SEKTION, schluessel(art), kennung) if defined?(Sketchup) && Sketchup.respond_to?(:write_default)
        @nicht_angepasst = art == 'schubladen' ? schubladen_anpassen(m, e) : []
        e
      end

      def nicht_angepasst
        @nicht_angepasst || []
      end

      # Werte für die Schränke (Kuechenplaner::Schubkasten, cm) aus einem Auszug-Eintrag (mm)
      def schubkasten_werte(e)
        z = e['zargen'].values
        nl = e['schiene']['hinten'].keys.map(&:to_i).sort
        cm = ->(v) { v.to_f / 10.0 }
        { 'kennung' => e['kennung'], 'zargen' => z.map { |v| [cm.(v['hoehe']), cm.(v['rueckwand'])] },
          'std' => cm.(e['zargen'][e['standard_zarge']]['rueckwand']), 'ueber_boden' => cm.(e['schiene']['ueber_boden']),
          'nl_min' => cm.(nl.first), 'nl_max' => cm.(nl.last), 'nl_schritt' => cm.(nl.size > 1 ? nl[1] - nl[0] : 50),
          'nl_abstand' => cm.(e['schiene']['abstand_nl']), 'boden_b' => cm.(e['kasten']['boden_b']),
          'boden_t' => cm.(e['kasten']['boden_t']), 'rw_b' => cm.(e['kasten']['rueckwand_b']) }
      end

      # Auszugssystem in das Modell schreiben und alle Schränke mit Schubladen anpassen: Attribute Ausz_*
      # neu setzen, Hoehe_Kastenrueckwand mitziehen, wenn sie auf der alten Standardrückwand stand,
      # und neu zeichnen. Schränke ohne Ausz_* (ältere Version) bleiben, wie sie sind.
      def schubladen_anpassen(m, e)
        return [] unless m.respond_to?(:set_attribute)
        w = schubkasten_werte(e)
        json = JSON.generate(w)
        m.set_attribute(DICT, Kuechenplaner::Schubkasten::SCHLUESSEL, json)
        Sketchup.write_default(SEKTION, Kuechenplaner::Schubkasten::SCHLUESSEL, json) if defined?(Sketchup) && Sketchup.respond_to?(:write_default)
        return [] unless m.respond_to?(:entities)
        attr = Kuechenplaner::Schubkasten.attribute(w)
        nicht = []
        Schraenke.instanzen(m.entities).each do |s|
          next if eigen('schubladen', s) # eigene Wahl des Schranks bleibt
          kz = Schraenke.definition(s).get_attribute(JT_DICT, 'schrank') or next
          nicht << kz if schrank_anpassen(s, attr, w) == :alt
        end
        nicht
      end

      # Einen Schrank auf ein Auszugssystem setzen (attr aus Kuechenplaner::Schubkasten.attribute(w)):
      # :alt = ältere Version ohne Ausz_* (mit Schubladen), :gleich = schon so, :neu = angepasst und neu gezeichnet
      def schrank_anpassen(s, attr, w)
        d = Schraenke.definition(s)
        return(schubladen?(d) ? :alt : :gleich) if Schraenke.dc(s, 'ausz_z1').nil?
        # unverändert (gleiches System): nichts tun, sonst würde jeder Schrank neu gezeichnet
        return :gleich if attr.all? { |n, v| (Schraenke.dc(s, n.downcase).to_f * 2.54 - v).abs < 0.001 }
        alt_std = Schraenke.dc(s, 'ausz_std').to_f * 2.54
        hrw = Schraenke.dc(s, 'hoehe_kastenrueckwand')
        [s, d].uniq.each do |ent|
          # Werte in Zoll wie alle Längen der Komponenten; an der Instanz nur, was dort schon steht
          attr.each { |n, v| ent.set_attribute(DC_DICT, n.downcase, v / 2.54) if ent == d || ent.get_attribute(DC_DICT, n.downcase) }
          if hrw && (hrw.to_f * 2.54 - alt_std).abs < 0.01 && (ent == d || ent.get_attribute(DC_DICT, 'hoehe_kastenrueckwand'))
            ent.set_attribute(DC_DICT, 'hoehe_kastenrueckwand', w['std'] / 2.54)
          end
        end
        $dc_observers.get_latest_class.redraw_with_undo(s) if defined?($dc_observers) && $dc_observers
        :neu
      end

      # Hat der Schrank Schubladen (Kastenteile)?
      def schubladen?(d, tiefe = 0)
        return false if tiefe > 4
        Schraenke.instanzen(d.entities).any? do |i|
          %w[KastenBoden KastenRueckwand].include?(i.get_attribute(JT_DICT, 'rolle').to_s) ||
            schubladen?(Schraenke.definition(i), tiefe + 1)
        end
      end

      # Für den Fingerabdruck der Beschläge im Modell: ändert sich mit jeder Wahl
      def fingerabdruck(model = nil, schrank = nil)
        ARTEN.keys.map { |a| "#{a}=#{eigen(a, schrank) || gespeichert(a, model)}" }.join(';')
      end

      # Bohrbild-Teil (seite, front) für eine Korpushöhe (mm): mit „stufen“ (je Stufe „bis“ = größte
      # Korpushöhe) gilt die erste passende Stufe, darüber die letzte (AVENTOS HL/HF top: Hebel-Set nach KH)
      def stufe(teil, korpushoehe)
        st = teil['stufen'] or return teil
        s = st.find { |x| korpushoehe.round <= x['bis'] } || st.last
        teil.merge(s)
      end

      # Passt das Modell zum Schrank? nil oder Hinweistext (Maße in mm)
      def hinweis(e, korpushoehe: nil, breite: nil)
        ein = e['einsatz'] || {}
        t = []
        { 'korpushoehe' => ['Korpushöhe', korpushoehe], 'breite' => ['Breite', breite] }.each do |k, (name, wert)|
          bereich = ein[k]
          next unless bereich && wert
          next if wert.round >= bereich[0] && wert.round <= bereich[1]
          t << "#{name} #{wert.round} mm (#{e['name']}: #{bereich[0]}–#{bereich[1]} mm)"
        end
        t.empty? ? nil : t.join(', ')
      end
    end
  end
end
