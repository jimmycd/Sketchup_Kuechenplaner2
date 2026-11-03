# encoding: UTF-8
# Schrank-CNC – Frontfarbe und Griffe ändern.
#
# Frontmaterialien sind Platten mit Verwendung „Front“ aus Küchenplaner › Materialien…
# (ohne OpenCutList); „Neues Frontmaterial…“ in der Auswahl legt eins an.
# Setzt ein Frontmaterial auf alle Fronten und Türen (rolle Front oder Tuer) und auf
# Teile mit JT_Schrank/frontfarbe (Abschlussregal mit Farbe „Frontfarbe“, ohne Griffe),
# für alle Schränke oder nur Ober-, Unter- oder Hochschränke,
# oder nur auf die Innenfronten der Innenschubkästen (Hochschrank Vorrat),
# Verkleidung und Wangen des Inselschranks (Teil#sichtteil?) bekommen das Frontmaterial mit, aber keinen Griff,
# auf Wunsch nur für die ausgewählten Schränke. Die Anleimer der Fronten
# bekommen den zugeordneten Anleimer (Materialien.anleimer). Korpus und Schubkästen bleiben unverändert.
# Griffe: Lochmaß, Lage und Höhe stehen danach an jeder Front im Wörterbuch
# JT_Schrank (griff_lochmass, griff_lage, griff_hoehe, in mm); der TCN-Export
# setzt daraus die Griffbohrungen.

module JTools
  module SchrankCnc
    module Frontfarbe
      INNEN    = :innenfronten # Bereich "Nur Innenfronten"
      NEU      = 'Neues Frontmaterial…'.freeze
      BEREICHE = { 'Alle Schränke' => nil, 'Nur Oberschränke' => 'Oberschrank',
                   'Nur Unterschränke' => 'Unterschrank', 'Nur Hochschränke' => 'Hochschrank',
                   'Nur Innenfronten' => INNEN }.freeze
      LAGEN = %w[links Mitte rechts].freeze

<<<<<<< HEAD
      # Plattenmaterialien mit Verwendung „Front“ im Modell (siehe Materialien)
      def self.frontmaterialien(model)
        Materialien.platten(model, 'Front')
=======
      # Plattenwerkstoffe (Typ 2 im Material-Wörterbuch), deren Name mit "Front" beginnt; ein in
      # SketchUp neu angelegtes Material ohne Typ zählt auch und wird beim Anwenden zur Platte
      def self.frontmaterialien(model)
        model.materials.to_a.select do |m|
          t = m.get_attribute(OCL_DICT, 'type')
          (t.nil? || t.to_i == 2) && m.name.start_with?(PRAEFIX)
        end.sort_by(&:name)
>>>>>>> origin/main
      end

      def self.kanten(model)
        Materialien.kanten(model)
      end

      def self.dekor(name)
        Materialien.dekor(name)
      end

<<<<<<< HEAD
      # Anleimer zum Frontmaterial: Zuordnung aus „Materialien…“, sonst über den Dekor im Namen
=======
      # Anleimer zum Frontmaterial: eine Kante (Typ 4) mit dem Dekor im Namen, sonst neu "Anleimer <Dekor>"
>>>>>>> origin/main
      def self.anleimer(model, front)
        Materialien.anleimer(model, front)
      end

      # Fronten im gewählten Bereich. kategorie nil = alle; auswahl = Instanzen, von denen
      # mindestens eine im Pfad der Front liegen muss (nil = ohne Einschränkung)
      def self.fronten(model, kategorie: nil, auswahl: nil)
        Schraenke.teile(model).select do |t|
          (kategorie == INNEN ? t.rolle == 'Innenfront' : t.frontfarbe? && (kategorie.nil? || Schraenke.kategorie(t) == kategorie)) &&
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
      # ziel?: welche Teil-Instanzen umgefärbt werden (Standard: Fronten)
      def self.eindeutig_machen(fronten, ziel = method(:front_inst?))
        oben = fronten.map { |f| f.pfad.first }.uniq
        innen = oben.flat_map { |s| baum(s) }
        oben.each { |inst| eindeutig(inst, innen, ziel) }
      end

      def self.eindeutig(inst, innen, ziel)
        fremd = inst.definition.instances.reject { |i| innen.include?(i) }
        inst.make_unique unless fremd.empty?
        inst_baum = baum(inst)
        Schraenke.instanzen(inst.definition.entities).each do |c|
          # nur Zweige, in denen ein Zielteil liegt (gleiche Teile wie Seiten bleiben geteilt)
          next unless baum(c).any? { |i| ziel.call(i) }
          eindeutig(c, inst_baum, ziel)
        end
      end

      # Material auf ein Teil setzen; Kantenflächen bekommen den Anleimer kante
      def self.material_setzen(inst, material, kante)
        inst.material = material
        inst.set_attribute(DC_DICT, 'material', material.name) # übersteht ein DC-Neuzeichnen
        inst.definition.entities.grep(Sketchup::Face).each do |fl|
          fl.material = kante if Materialien.kante?(fl.material)
        end
      end

      def self.front_inst?(i)
        rolle = i.get_attribute(JT_DICT, 'rolle')
        %w[Front Tuer Innenfront Verkleidung].include?(rolle) ||
          (rolle == 'Wange' && i.get_attribute(JT_DICT, 'typ') == 'Unterschrank_Insel') ||
          (i.get_attribute(JT_DICT, 'frontfarbe') ? true : false)
      end

      # Material und Anleimer auf die Fronten setzen; griff = { lochmass:, lage:, hoehe: } (mm),
      # griff: false entfernt die Griffangaben, nil lässt sie unverändert
      def self.anwenden(model, fronten, material, griff: nil)
        return 0 if fronten.empty?
        kante = material && anleimer(model, material)
        material.set_attribute(OCL_DICT, 'type', 2) if material && material.get_attribute(OCL_DICT, 'type').nil?
        eindeutig_machen(fronten)
        # nach dem Eindeutigmachen die Fronten neu einsammeln (die Instanzen haben sich geändert)
        ids = fronten.map { |f| f.pfad.first }.uniq
        neu = Schraenke.teile(model).select { |t| (t.frontfarbe? || t.rolle == 'Innenfront') && ids.include?(t.pfad.first) &&
                                               fronten.any? { |f| f.name == t.name } }
        neu.each do |f|
          material_setzen(f.inst, material, kante) if material
          if griff && (f.jt('teil') == 'Blende' || !f.front?)
            next # feste Blende (Unterschrank Kochfeld), Innenfronten, Regalteile, Verkleidung und Wangen bekommen keinen Griff
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
<<<<<<< HEAD
        namen = Materialien.plattennamen(model, 'Front')
        if namen.empty?
          # noch kein Frontmaterial: gleich eins anlegen, danach geht es hier weiter
          Materialdialog.platte_formular(model, verwendung: 'Front') { dialog(model) }
=======
        mats = frontmaterialien(model)
        if mats.empty?
          UI.messagebox("Im Modell gibt es kein Frontmaterial.\n\nLege unter Fenster › Materialien ein Material an, " \
                        "dessen Name mit „#{PRAEFIX}“ beginnt (z. B. „Front Eiche 19mm“).")
>>>>>>> origin/main
          return
        end
        griff_opt = ['unverändert lassen', 'setzen', 'entfernen']
        prompts = ['Frontmaterial', 'Bereich', 'Nur ausgewählte Schränke', 'Griffe',
                   'Griff: Lochmaß (mm)', 'Griff: Lage seitlich', 'Griff: Höhe ab Unterkante Front (mm)']
        auswahl_da = !model.selection.to_a.empty?
        defaults = [namen.first, BEREICHE.keys.first, auswahl_da ? 'Ja' : 'Nein', griff_opt.first, '160', 'Mitte', '35']
        lists = [(namen + [NEU]).join('|'), BEREICHE.keys.join('|'), 'Ja|Nein', griff_opt.join('|'), '',
                 LAGEN.join('|'), '']
        Kuechenplaner::Eingabe.abfragen(prompts, defaults, lists, 'Frontfarbe und Griffe ändern', ok: 'Übernehmen') do |res|
          if res[0] == NEU
            Materialdialog.platte_formular(model, verwendung: 'Front') { dialog(model) }
            next
          end
          raise ArgumentError, "Material „#{res[0]}“ nicht gefunden" unless namen.include?(res[0])
          auswahl = res[2] == 'Ja' ? model.selection.to_a : nil
          f = fronten(model, kategorie: BEREICHE[res[1]], auswahl: auswahl)
          if f.empty?
            UI.messagebox('Im gewählten Bereich gibt es keine Fronten (Teile mit JT_Schrank-Rolle Front oder Tür).')
            next
          end
          griff = case res[3]
                  when 'setzen' then { lochmass: zahl(res[4]), lage: res[5], hoehe: zahl(res[6]) }
                  when 'entfernen' then false
                  end
          frage = "#{vorschau(f)} bekommen „#{res[0]}“#{griff ? ' und Griffbohrungen' : ''}. Übernehmen?"
          next unless UI.messagebox(frage, MB_OKCANCEL) == IDOK

          begin
            model.start_operation('Frontfarbe ändern', true)
            anwenden(model, f, Materialien.holen(model, res[0]), griff: griff) # aus der Bibliothek, falls nötig
            model.commit_operation
          rescue StandardError
            model.abort_operation
            raise
          end
        end
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
