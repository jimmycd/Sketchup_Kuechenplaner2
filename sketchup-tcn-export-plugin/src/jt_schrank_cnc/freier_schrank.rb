# encoding: UTF-8
# Schrank-CNC – freier Schrank (Jürgen, 2026-11-07), Schritt 1: Teile frei modellieren und
# zuweisen, Schrank prüfen.
#
# Die TCN-Regeln, Stückliste, Etiketten, Zuschnitt, Beschlagliste und Rendern richten sich nur
# nach JT_Schrank am Teil (rolle, teil, bereich), seiner Lage, seinem Material und den
# Anleimer-Flächen – nicht danach, welche Komponente das Teil erzeugt hat. Ein frei
# modellierter Schrank läuft deshalb überall mit, wenn
#   * der Schrank (eine Komponente) an seiner Definition JT_Schrank schrank/typ/kategorie trägt
#     („Als freien Schrank kennzeichnen“, Kürzel FS1, FS2 …, typ „Frei“),
#   * jedes Teil darin eine Komponente mit JT_Schrank (schrank, typ, kategorie, bereich, teil,
#     rolle), Tag <Kürzel>_<Bereich>_<Teil>, Plattenmaterial und Anleimer-Flächen ist
#     („Teil zuweisen…“).
# Seiten (auch Mittelwände) bekommen Lochreihen nur, wenn sie gewählt sind (JT_Schrank/lochreihe).
# „Schrank prüfen“ meldet, was beim Export fehlen oder falsch werden würde; der Export
# zeigt dieselben Meldungen.

module JTools
  module SchrankCnc
    module FreierSchrank
      module_function

      KUERZEL = 'FS'.freeze
      TYP = 'Frei'.freeze
      KATEGORIEN = %w[Unterschrank Oberschrank Hochschrank].freeze
      STANDARD_MATERIAL = 'Melamin weiss'.freeze
      TOL = 0.5 # mm

      # Auswahl im Dialog => [Teilname, Rolle, Anleimer-Vorgabe]
      TEILE = {
        'Seite links'      => ['SeiteL', 'Seite', %i[vorn]],
        'Seite rechts'     => ['SeiteR', 'Seite', %i[vorn]],
        'Mittelwand'       => ['Mittelwand', 'Seite', %i[vorn]],
        'Boden'            => ['Boden', 'Boden', %i[vorn]],
        'Deckel'           => ['Deckel', 'Deckel', %i[vorn]],
        'Strebe vorn'      => ['StrebeVorn', 'Strebe', %i[vorn]],
        'Strebe hinten'    => ['StrebeHinten', 'Strebe', []],
        'Zwischenboden'    => ['Zwischenboden', 'Zwischenboden', %i[vorn]],
        'Einlegeboden'     => ['Einlegeboden', 'Einlegeboden', %i[vorn]],
        'Rückwand'         => ['Rueckwand', 'Rueckwand', []],
        'Tür'              => ['Tuer', 'Tuer', %i[vorn hinten oben unten links rechts]],
        'Tür links'        => ['TuerL', 'Tuer', %i[vorn hinten oben unten links rechts]],
        'Tür rechts'       => ['TuerR', 'Tuer', %i[vorn hinten oben unten links rechts]],
        'Klappe'           => ['Klappe', 'Front', %i[vorn hinten oben unten links rechts]],
        'Klappe oben'      => ['KlappeO', 'Front', %i[vorn hinten oben unten links rechts]],
        'Klappe unten'     => ['KlappeU', 'Front', %i[vorn hinten oben unten links rechts]],
        'Front'            => ['Front', 'Front', %i[vorn hinten oben unten links rechts]],
        'Blende'           => ['Blende', 'Front', %i[vorn hinten oben unten links rechts]],
        'Kastenboden'      => ['KastenBoden', 'KastenBoden', []],
        'Kastenrückwand'   => ['KastenRueckwand', 'KastenRueckwand', []],
        'Innenfront'       => ['Innenfront', 'Innenfront', %i[oben]],
        'Wange'            => ['Wange', 'Wange', %i[vorn oben]],
        'Leiste'           => ['Leiste', 'Leiste', %i[vorn]],
        'Sockelblende'     => ['Sockelblende', 'Sockel', []]
      }.freeze

      # Richtung im Schrank (Front zeigt nach -y) => Achse, Vorzeichen
      RICHTUNGEN = { vorn: [1, -1], hinten: [1, 1], links: [0, -1], rechts: [0, 1], unten: [2, -1], oben: [2, 1] }.freeze
      RICHTUNG_TEXT = { vorn: 'vorn', hinten: 'hinten', oben: 'oben', unten: 'unten', links: 'links', rechts: 'rechts' }.freeze

      # ------------------------------------------------------------------
      # Schrank
      # ------------------------------------------------------------------
      def schrank?(inst)
        inst && Schraenke.definition(inst).get_attribute(JT_DICT, 'schrank') ? true : false
      end

      def frei?(inst)
        schrank?(inst) && Schraenke.definition(inst).get_attribute(JT_DICT, 'typ') == TYP
      end

      # Freies Kürzel FS1, FS2 …: weder als Tag-Anfang noch an einem Schrank vergeben
      def freies_kuerzel(model)
        belegt = model.definitions.to_a.map { |d| d.get_attribute(JT_DICT, 'schrank') }.compact
        n = 1
        n += 1 while belegt.include?("#{KUERZEL}#{n}") || model.layers.to_a.any? { |l| l.name.start_with?("#{KUERZEL}#{n}_") }
        "#{KUERZEL}#{n}"
      end

      # Gruppe oder Komponente als freien Schrank kennzeichnen; liefert die Schrank-Instanz
      def kennzeichnen(model, inst, kategorie: 'Unterschrank', name: nil)
        raise ArgumentError, "Kategorie „#{kategorie}“ unbekannt" unless KATEGORIEN.include?(kategorie)
        inst = inst.to_component if inst.is_a?(Sketchup::Group) && inst.respond_to?(:to_component)
        raise ArgumentError, 'Bitte eine Gruppe oder Komponente wählen.' unless inst.respond_to?(:definition)
        inst.make_unique if inst.definition.instances.length > 1 && inst.respond_to?(:make_unique)
        d = inst.definition
        kz = d.get_attribute(JT_DICT, 'typ') == TYP && d.get_attribute(JT_DICT, 'schrank') || freies_kuerzel(model)
        { 'schrank' => kz, 'typ' => TYP, 'kategorie' => kategorie }.each { |k, v| d.set_attribute(JT_DICT, k, v) }
        d.set_attribute(JT_DICT, 'name', name.to_s) unless name.to_s.strip.empty?
        inst.name = "#{kz} #{name}".strip if inst.respond_to?(:name=)
        # Teile, die schon zugewiesen sind, ziehen Kürzel und Kategorie nach
        teile(inst).each do |pfad|
          p = pfad.last
          next unless p.get_attribute(JT_DICT, 'teil')
          p.set_attribute(JT_DICT, 'schrank', kz)
          p.set_attribute(JT_DICT, 'kategorie', kategorie)
          tag_setzen(model, p, kz)
        end
        inst
      end

      # Pfade (ohne den Schrank selbst) zu allen Blättern im Schrank: zugewiesene Teile und
      # Instanzen ohne weitere Instanzen darin (frei modellierte Platten)
      def teile(schrank, ents = Schraenke.definition(schrank).entities, pfad = [], out = [])
        Schraenke.instanzen(ents).each do |i|
          p = pfad + [i]
          innen = Schraenke.instanzen(Schraenke.definition(i).entities)
          if i.get_attribute(JT_DICT, 'teil') || innen.empty?
            out << p
          else
            teile(schrank, Schraenke.definition(i).entities, p, out)
          end
        end
        out
      end

      # Pfad vom Schrank zum Teil (ohne Schrank), nil wenn das Teil nicht darin liegt
      def pfad_zu(schrank, inst)
        suche = lambda do |ents, pfad|
          Schraenke.instanzen(ents).each do |i|
            p = pfad + [i]
            return p if i.equal?(inst)
            r = suche.(Schraenke.definition(i).entities, p)
            return r if r
          end
          nil
        end
        suche.(Schraenke.definition(schrank).entities, [])
      end

      # Teilname im Schrank eindeutig machen (Einlegeboden, Einlegeboden2 …), eigener bleibt
      def teilname(schrank, inst, basis, bereich)
        andere = teile(schrank).map(&:last).reject { |i| i.equal?(inst) }
                              .select { |i| i.get_attribute(JT_DICT, 'bereich').to_s == bereich.to_s }
                              .map { |i| i.get_attribute(JT_DICT, 'teil') }.compact
        eigen = inst.get_attribute(JT_DICT, 'teil')
        return eigen if eigen && eigen.sub(/\d+\z/, '') == basis && !andere.include?(eigen)
        return basis unless andere.include?(basis)
        n = 2
        n += 1 while andere.include?("#{basis}#{n}")
        "#{basis}#{n}"
      end

      def tag_name(kz, inst)
        bereich = inst.get_attribute(JT_DICT, 'bereich').to_s
        [kz, (bereich.empty? ? nil : bereich), inst.get_attribute(JT_DICT, 'teil')].compact.join('_')
      end

      def tag_setzen(model, inst, kz)
        n = tag_name(kz, inst)
        inst.layer = model.layers[n] || model.layers.add(n)
      end

      # ------------------------------------------------------------------
      # Teil zuweisen
      # ------------------------------------------------------------------
      def standard_material(model)
        Materialien.holen(model, STANDARD_MATERIAL) ||
          Materialien.platte_setzen(model, name: STANDARD_MATERIAL, verwendung: 'Korpus', farbe: '#ffffff', staerke: 19.0,
                                           bibliothek: false)
      end

      # Matrix vom Teil in den Schrank (pfad ohne Schrank)
      def matrix(pfad)
        Geometrie.welt(pfad)
      end

      # Richtung (vorn, hinten …) einer Fläche im Schrank; nil, wenn sie schräg liegt
      def richtung_von(m, face)
        v = Geometrie.richtung(m, face.normal.to_a.map(&:to_f))
        l = Math.sqrt(v.sum { |x| x * x })
        return nil if l.zero?
        a = (0..2).max_by { |k| v[k].abs }
        return nil if v[a].abs / l < 0.9999
        RICHTUNGEN.find { |_, (ax, sg)| ax == a && (v[a] > 0) == (sg > 0) }&.first
      end

      # Richtungen der Plattenstärke (Hauptflächen bekommen nie Anleimer)
      def dicken_richtungen(pfad)
        a = Geometrie.werkstueck(Teil.new(pfad.last, pfad, pfad.first)).dicke_achse
        RICHTUNGEN.select { |_, (ax, _)| ax == a }.keys
      end

      # Anleimer-Richtungen, die das Teil jetzt hat
      def kanten_von(pfad)
        m = matrix(pfad)
        Schraenke.definition(pfad.last).entities.grep(Sketchup::Face).select { |f| Materialien.kante?(f.material) }
                 .map { |f| richtung_von(m, f) }.compact.uniq
      end

      # art: Schlüssel aus TEILE; kanten: Richtungen mit Anleimer; lochreihe nur für Seiten
      def zuweisen(model, schrank, inst, art:, bereich: '', material: nil, kanten: nil, lochreihe: true)
        raise ArgumentError, 'Zuerst den Schrank als freien Schrank kennzeichnen.' unless schrank?(schrank)
        basis, rolle, vorgabe = TEILE.fetch(art) { raise ArgumentError, "Teil „#{art}“ unbekannt" }
        pfad = pfad_zu(schrank, inst) or raise ArgumentError, 'Das Teil liegt nicht im Schrank.'
        raise ArgumentError, 'Das Teil muss eine Komponente sein (Gruppe vorher in Komponente umwandeln).' unless inst.respond_to?(:definition)
        inst.make_unique if inst.definition.instances.length > 1 && inst.respond_to?(:make_unique)
        d = Schraenke.definition(schrank)
        kz = d.get_attribute(JT_DICT, 'schrank')
        bereich = bereich.to_s.strip.gsub(/[\s_]+/, '')
        teil = teilname(schrank, inst, basis, bereich)
        { 'schrank' => kz, 'typ' => d.get_attribute(JT_DICT, 'typ'), 'kategorie' => d.get_attribute(JT_DICT, 'kategorie'),
          'bereich' => bereich, 'teil' => teil, 'rolle' => rolle }.each { |k, v| inst.set_attribute(JT_DICT, k, v) }
        if rolle == 'Seite'
          inst.set_attribute(JT_DICT, 'lochreihe', lochreihe ? true : false)
        else
          inst.delete_attribute(JT_DICT, 'lochreihe') if inst.respond_to?(:delete_attribute)
        end
        tag_setzen(model, inst, kz)
        mat = material || inst.material || standard_material(model)
        Materialien.platte_machen(mat) unless Materialien.platte?(mat)
        anleimer = Materialien.anleimer(model, mat)
        inst.material = mat
        kanten_setzen(pfad, kanten || vorgabe, anleimer)
        inst
      end

      def kanten_setzen(pfad, kanten, anleimer)
        m = matrix(pfad)
        dicke = dicken_richtungen(pfad)
        Schraenke.definition(pfad.last).entities.grep(Sketchup::Face).each do |f|
          r = richtung_von(m, f)
          next if r.nil? # Schräg- und Bogenkanten bleiben, wie sie sind (Kontur)
          if kanten.include?(r) && !dicke.include?(r)
            f.material = anleimer
          elsif Materialien.kante?(f.material)
            f.material = nil
          end
        end
      end

      # ------------------------------------------------------------------
      # Prüfen
      # ------------------------------------------------------------------
      def name_von(inst)
        n = inst.respond_to?(:name) ? inst.name.to_s : ''
        n = Schraenke.definition(inst).name.to_s if n.empty?
        n.empty? ? 'ohne Namen' : n
      end

      def quader?(inst)
        d = Schraenke.definition(inst)
        return true if d.attribute_dictionary('JT_Kontur')
        flaechen = d.entities.grep(Sketchup::Face)
        flaechen.size == 6
      end

      # achsparallel im Schrank?
      def achsparallel?(m)
        (0..2).all? do |c|
          spalte = m[c * 4, 3]
          spalte.count { |x| x.abs > 1e-6 } == 1
        end
      end

      def ueberlapp(a, b)
        (0..2).map { |i| [a.hi[i], b.hi[i]].min - [a.lo[i], b.lo[i]].max }
      end

      # Meldungen zu einem freien Schrank (Texte für Prüfen und Export)
      def pruefen(model, schrank)
        kz = Schraenke.definition(schrank).get_attribute(JT_DICT, 'schrank')
        meld = []
        pfade = teile(schrank)
        meld << "#{kz}: der Schrank hat noch keine Teile." if pfade.empty?
        zugewiesen = []
        pfade.each do |p|
          i = p.last
          next if p.any?(&:hidden?)
          unless i.get_attribute(JT_DICT, 'teil')
            meld << "#{kz}: Teil „#{name_von(i)}“ hat keine Rolle (Teil zuweisen…) und fehlt in Stückliste und TCN."
            next
          end
          tag = i.layer ? i.layer.name : tag_name(kz, i)
          meld << "#{tag}: kein Plattenmaterial." unless Materialien.platte?(i.material)
          meld << "#{tag}: keine rechteckige Platte (Formteil braucht eine Kontur)." unless quader?(i)
          meld << "#{tag}: liegt schräg im Schrank; der TCN-Export rechnet nur achsparallele Teile." unless achsparallel?(matrix(p))
          zugewiesen << [p, Geometrie.werkstueck(Teil.new(i, [schrank] + p, schrank))]
        end
        # doppelte Tags im Schrank (Zuordnung zu den CAD/CAM-Dateien); Kopien eines Schranks
        # behalten wie alle Schränke ihre Tags, gleiche Teile zählt der Export zusammen
        tags = zugewiesen.map { |p, _| p.last.layer&.name }.compact
        tags.tally.select { |_, n| n > 1 }.each_key { |t| meld << "#{t}: Tag ist im Schrank doppelt vergeben." }
        # Überschneidungen (Rückwand in der Nut ausgenommen)
        zugewiesen.combination(2).each do |(_, a), (_, b)|
          next if [a.rolle, b.rolle].include?('Rueckwand')
          next unless ueberlapp(a, b).all? { |u| u > TOL }
          meld << "#{a.name} und #{b.name} überschneiden sich."
        end
        # Schubladen: Kastenteile brauchen einen Bereich und eine Front darin
        zugewiesen.map(&:last).select { |w| Regeln::KASTEN.include?(w.rolle) }.group_by { |w| w.teil.jt('bereich').to_s }.each do |b, ks|
          if b.empty?
            meld << "#{kz}: Kastenteile ohne Bereich (z. B. S1) – Schienen und Frontbefestigung brauchen ihn."
          elsif zugewiesen.none? { |_, w| w.teil.jt('bereich').to_s == b && w.rolle == 'Front' }
            meld << "#{kz}_#{b}: Schublade ohne Front."
          end
          meld << "#{kz}_#{b}: Kastenrückwand fehlt." if ks.none? { |w| w.rolle == 'KastenRueckwand' }
        end
        meld
      end

      # Meldungen aller freien Schränke im Modell (für den Export)
      def pruefen_alle(model, auswahl: nil)
        Schraenke.instanzen(model.entities).select { |i| frei?(i) }
                 .select { |i| auswahl.nil? || auswahl.include?(i) }
                 .flat_map { |i| pruefen(model, i) }
      end

      # ------------------------------------------------------------------
      # Bedienung
      # ------------------------------------------------------------------
      # Schrank zur Auswahl: geöffneter freier Schrank (Bearbeiten-Pfad) oder gewählte Instanz
      def schrank_zur_auswahl(model)
        pfad = model.respond_to?(:active_path) ? (model.active_path || []) : []
        s = pfad.find { |i| schrank?(i) }
        s || model.selection.to_a.find { |i| schrank?(i) }
      end

      def kennzeichnen_dialog(model = Sketchup.active_model)
        sel = model.selection.to_a.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
        unless sel.size == 1
          UI.messagebox('Bitte genau eine Gruppe oder Komponente wählen, die den ganzen Schrank enthält.')
          return
        end
        d = Schraenke.definition(sel.first)
        if d.get_attribute(JT_DICT, 'schrank') && d.get_attribute(JT_DICT, 'typ') != TYP
          UI.messagebox('Das ist schon ein Schrank aus dem Küchenplaner.')
          return
        end
        kat = d.get_attribute(JT_DICT, 'kategorie') || 'Unterschrank'
        Kuechenplaner::Eingabe.abfragen(['Kategorie', 'Name'], [kat, d.get_attribute(JT_DICT, 'name').to_s],
                                        [KATEGORIEN.join('|'), ''], 'Freier Schrank', ok: 'Kennzeichnen') do |w|
          model.start_operation('Freien Schrank kennzeichnen', true)
          begin
            s = kennzeichnen(model, sel.first, kategorie: w[0], name: w[1])
            model.commit_operation
            UI.messagebox("#{Schraenke.definition(s).get_attribute(JT_DICT, 'schrank')} ist ein freier #{w[0]}. " \
                          'Jetzt den Schrank öffnen, Teile wählen und „Teil zuweisen…“.')
          rescue StandardError
            model.abort_operation
            raise
          end
        end
      end

      def teil_dialog(model = Sketchup.active_model)
        schrank = schrank_zur_auswahl(model)
        unless schrank && frei?(schrank)
          UI.messagebox('Bitte den freien Schrank öffnen (Doppelklick) und die Teile darin wählen. ' \
                        'Den Schrank vorher mit „Als freien Schrank kennzeichnen…“ anlegen.')
          return
        end
        ziele = model.selection.to_a.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
        if ziele.empty?
          UI.messagebox('Bitte ein oder mehrere Teile (Komponenten) im Schrank wählen.')
          return
        end
        erst = ziele.first
        jetzt = TEILE.find { |_, (b, _, _)| erst.get_attribute(JT_DICT, 'teil').to_s.sub(/\d+\z/, '') == b }&.first || TEILE.keys.first
        p = pfad_zu(schrank, erst)
        kanten = p && erst.get_attribute(JT_DICT, 'teil') ? kanten_von(p) : TEILE[jetzt][2]
        namen = Materialien.plattennamen(model)
        namen = [STANDARD_MATERIAL] + namen unless namen.include?(STANDARD_MATERIAL)
        mat = erst.material && Materialien.platte?(erst.material) ? erst.material.name.to_s : STANDARD_MATERIAL
        prompts = ['Teil', 'Bereich (z. B. S1, leer = keiner)', 'Material'] +
                  RICHTUNGEN.keys.map { |r| "Anleimer: #{RICHTUNG_TEXT[r]}" } + ['Lochreihe (nur Seiten)']
        defaults = [jetzt, erst.get_attribute(JT_DICT, 'bereich').to_s, mat] +
                   RICHTUNGEN.keys.map { |r| kanten.include?(r) ? 'Ja' : 'Nein' } +
                   [erst.get_attribute(JT_DICT, 'lochreihe') == false ? 'Nein' : 'Ja']
        listen = [TEILE.keys.join('|'), '', namen.join('|')] + RICHTUNGEN.keys.map { 'Ja|Nein' } + ['Ja|Nein']
        titel = ziele.size == 1 ? 'Teil zuweisen' : "#{ziele.size} Teile zuweisen"
        Kuechenplaner::Eingabe.abfragen(prompts, defaults, listen, titel, ok: 'Zuweisen') do |w|
          m = w[2] == STANDARD_MATERIAL ? standard_material(model) : Materialien.holen(model, w[2])
          raise ArgumentError, "Material „#{w[2]}“ nicht gefunden" unless m
          k = RICHTUNGEN.keys.each_with_index.select { |_, i| w[3 + i] == 'Ja' }.map(&:first)
          model.start_operation(titel, true)
          begin
            ziele.each do |z|
              z = z.to_component if z.is_a?(Sketchup::Group) && z.respond_to?(:to_component)
              zuweisen(model, schrank, z, art: w[0], bereich: w[1], material: m, kanten: k, lochreihe: w[9] == 'Ja')
            end
            model.commit_operation
          rescue StandardError
            model.abort_operation
            raise
          end
        end
      end

      def pruefen_dialog(model = Sketchup.active_model)
        schrank = schrank_zur_auswahl(model)
        liste = schrank && frei?(schrank) ? [schrank] : Schraenke.instanzen(model.entities).select { |i| frei?(i) }
        if liste.empty?
          UI.messagebox('Im Modell gibt es keinen freien Schrank.')
          return
        end
        meld = liste.flat_map { |s| pruefen(model, s) }
        kz = liste.map { |s| Schraenke.definition(s).get_attribute(JT_DICT, 'schrank') }.join(', ')
        UI.messagebox(meld.empty? ? "#{kz}: alles in Ordnung." : "#{kz}:\n\n" + meld.map { |x| "• #{x}" }.join("\n"))
        meld
      end
    end
  end
end
