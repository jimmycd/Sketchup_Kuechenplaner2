# encoding: UTF-8
# Schrank-CNC – Frontfarbe und Griffe ändern.
#
# Setzt ein Frontmaterial aus OpenCutList auf alle Fronten und Türen (rolle
# Front oder Tuer), für alle Schränke oder nur Ober-, Unter- oder Hochschränke,
# auf Wunsch nur für die ausgewählten Schränke. Die Anleimer der Fronten
# bekommen den passenden Anleimer. Korpus und Schubkästen bleiben unverändert.
# Griffe: Lochmaß, Lage und Höhe stehen danach an jeder Front im Wörterbuch
# JT_Schrank (griff_lochmass, griff_lage, griff_hoehe, in mm); der TCN-Export
# setzt daraus die Griffbohrungen.

module JTools
  module SchrankCnc
    module Frontfarbe
      OCL_DICT = 'ladb_opencutlist'.freeze
      PRAEFIX  = 'Front'.freeze # Frontmaterialien erkennt man am Namen, z. B. "Front Eiche 19mm"
      BEREICHE = { 'Alle Schränke' => nil, 'Nur Oberschränke' => 'Oberschrank',
                   'Nur Unterschränke' => 'Unterschrank', 'Nur Hochschränke' => 'Hochschrank' }.freeze
      LAGEN = %w[links Mitte rechts].freeze

      # OCL-Plattenwerkstoffe (Typ 2), deren Name mit "Front" beginnt
      def self.frontmaterialien(model)
        model.materials.to_a.select do |m|
          m.get_attribute(OCL_DICT, 'type').to_i == 2 && m.name.start_with?(PRAEFIX)
        end.sort_by(&:name)
      end

      def self.kanten(model)
        model.materials.to_a.select { |m| m.get_attribute(OCL_DICT, 'type').to_i == 4 }
      end

      # "Front Eiche hell 19mm" -> "Eiche hell"
      def self.dekor(name)
        name.sub(/\A#{PRAEFIX}\s*/, '').sub(/\s*\d+([.,]\d+)?\s*mm\z/i, '').strip
      end

      # Anleimer zum Frontmaterial: eine OCL-Kante mit dem Dekor im Namen, sonst neu "Anleimer <Dekor>"
      def self.anleimer(model, front)
        d = dekor(front.name)
        vorhanden = kanten(model).select { |k| !d.empty? && k.name.downcase.include?(d.downcase) }
        return vorhanden.min_by { |k| k.name.length } unless vorhanden.empty?
        name = "Anleimer #{d.empty? ? front.name : d}"
        k = model.materials[name] || model.materials.add(name)
        k.color = front.color if front.respond_to?(:color) && front.color
        { 'type' => 4, 'thickness' => '2 mm', 'std_widths' => '23 mm', 'std_lengths' => '75 m',
          'edge_decremented' => true }.each { |a, v| k.set_attribute(OCL_DICT, a, v) }
        k
      end

      # Fronten im gewählten Bereich. kategorie nil = alle; auswahl = Instanzen, von denen
      # mindestens eine im Pfad der Front liegen muss (nil = ohne Einschränkung)
      def self.fronten(model, kategorie: nil, auswahl: nil)
        Schraenke.teile(model).select do |t|
          t.front? &&
            (kategorie.nil? || Schraenke.kategorie(t) == kategorie) &&
            (auswahl.nil? || t.pfad.any? { |i| auswahl.include?(i) })
        end
      end

      # Vorschau, z. B. "14 Fronten in 5 Schränken" (nur sichtbare Fronten gezählt)
      def self.vorschau(fronten)
        s = fronten.select(&:sichtbar?)
        n_s = s.map(&:schrank).uniq.size
        "#{s.size} #{s.size == 1 ? 'Front' : 'Fronten'} in #{n_s} #{n_s == 1 ? 'Schrank' : 'Schränken'}"
      end

      # Instanzen im Teilbaum unter inst (inst selbst eingeschlossen)
      def self.baum(inst, out = [])
        out << inst
        Schraenke.instanzen(inst.definition.entities).each { |c| baum(c, out) }
        out
      end

      # Definitionen auf dem Weg zu den Fronten eindeutig machen, wenn sie auch von
      # Instanzen außerhalb der gewählten Schränke benutzt werden. Sonst würden
      # nicht gewählte Kopien mit umgefärbt.
      def self.eindeutig_machen(fronten)
        ziel = fronten.map { |f| f.pfad.first }.uniq
        innen = ziel.flat_map { |s| baum(s) }
        ziel.each { |inst| eindeutig(inst, innen, fronten) }
      end

      def self.eindeutig(inst, innen, fronten)
        fremd = inst.definition.instances.reject { |i| innen.include?(i) }
        inst.make_unique unless fremd.empty?
        inst_baum = baum(inst)
        Schraenke.instanzen(inst.definition.entities).each do |c|
          # nur Zweige, in denen eine Front liegt (gleiche Teile wie Seiten bleiben geteilt)
          next unless baum(c).any? { |i| front_inst?(i) }
          eindeutig(c, inst_baum, fronten)
        end
      end

      def self.front_inst?(i)
        %w[Front Tuer].include?(i.get_attribute(JT_DICT, 'rolle'))
      end

      # Material und Anleimer auf die Fronten setzen; griff = { lochmass:, lage:, hoehe: } (mm),
      # griff: false entfernt die Griffangaben, nil lässt sie unverändert
      def self.anwenden(model, fronten, material, griff: nil)
        return 0 if fronten.empty?
        kante = material && anleimer(model, material)
        eindeutig_machen(fronten)
        # nach dem Eindeutigmachen die Fronten neu einsammeln (die Instanzen haben sich geändert)
        ids = fronten.map { |f| f.pfad.first }.uniq
        neu = Schraenke.teile(model).select { |t| t.front? && ids.include?(t.pfad.first) &&
                                               fronten.any? { |f| f.name == t.name } }
        neu.each do |f|
          if material
            f.inst.material = material
            f.inst.set_attribute(DC_DICT, 'material', material.name) # übersteht ein DC-Neuzeichnen
            f.inst.definition.entities.grep(Sketchup::Face).each do |fl|
              fl.material = kante if fl.material && fl.material.get_attribute(OCL_DICT, 'type').to_i == 4
            end
          end
          if griff && f.jt('teil') == 'Blende'
            next # feste Blende (Unterschrank Kochfeld) bekommt keinen Griff
          elsif griff
            f.inst.set_attribute(JT_DICT, 'griff_lochmass', griff[:lochmass].to_f)
            f.inst.set_attribute(JT_DICT, 'griff_lage', griff[:lage])
            f.inst.set_attribute(JT_DICT, 'griff_hoehe', griff[:hoehe].to_f)
          elsif griff == false
            %w[griff_lochmass griff_lage griff_hoehe].each { |k| f.inst.delete_attribute(JT_DICT, k) }
          end
        end
        neu.size
      end

      def self.zahl(text)
        Float(text.to_s.tr(',', '.').strip)
      rescue ArgumentError
        raise ArgumentError, "„#{text}“ ist keine Zahl"
      end

      # ---------------------------------------------------------------------
      # Dialog
      # ---------------------------------------------------------------------
      def self.dialog(model = Sketchup.active_model)
        mats = frontmaterialien(model)
        if mats.empty?
          UI.messagebox("Im Modell gibt es kein Frontmaterial.\n\nLege in OpenCutList einen Plattenwerkstoff an, " \
                        "dessen Name mit „#{PRAEFIX}“ beginnt (z. B. „Front Eiche 19mm“).")
          return
        end
        griff_opt = ['unverändert lassen', 'setzen', 'entfernen']
        prompts = ['Frontmaterial', 'Bereich', 'Nur ausgewählte Schränke', 'Griffe',
                   'Griff: Lochmaß (mm)', 'Griff: Lage seitlich', 'Griff: Höhe ab Unterkante Front (mm)']
        auswahl_da = !model.selection.to_a.empty?
        defaults = [mats.first.name, BEREICHE.keys.first, auswahl_da ? 'Ja' : 'Nein', griff_opt.first, '160', 'Mitte', '35']
        lists = [mats.map(&:name).join('|'), BEREICHE.keys.join('|'), 'Ja|Nein', griff_opt.join('|'), '',
                 LAGEN.join('|'), '']
        res = UI.inputbox(prompts, defaults, lists, 'Frontfarbe und Griffe ändern')
        return unless res

        material = model.materials[res[0]]
        auswahl = res[2] == 'Ja' ? model.selection.to_a : nil
        f = fronten(model, kategorie: BEREICHE[res[1]], auswahl: auswahl)
        if f.empty?
          UI.messagebox('Im gewählten Bereich gibt es keine Fronten (Teile mit JT_Schrank-Rolle Front oder Tür).')
          return
        end
        griff = case res[3]
                when 'setzen' then { lochmass: zahl(res[4]), lage: res[5], hoehe: zahl(res[6]) }
                when 'entfernen' then false
                end
        frage = "#{vorschau(f)} bekommen „#{material.name}“#{griff ? ' und Griffbohrungen' : ''}. Übernehmen?"
        return unless UI.messagebox(frage, MB_OKCANCEL) == IDOK

        model.start_operation('Frontfarbe ändern', true)
        anwenden(model, f, material, griff: griff)
        model.commit_operation
      rescue ArgumentError => e
        UI.messagebox("Ungültige Eingabe: #{e.message}")
      rescue StandardError => e
        model.abort_operation
        UI.messagebox("Fehler: #{e.message}")
        raise
      end
    end
  end
end
