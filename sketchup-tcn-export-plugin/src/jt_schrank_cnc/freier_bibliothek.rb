# encoding: UTF-8
# Schrank-CNC – freier Schrank, Schritt 3 (Jürgen, 2026-11-07): eigene Schränke in einer
# Bibliothek speichern und in andere Küchen einfügen; fertige Schränke „lösen“, um sie frei
# weiterzubearbeiten.
#
# Bibliothek: ein Ordner (Standard E:\sketchup komponenten\Bibliothek, änderbar über
# Küchenplaner › Freier Schrank › Bibliotheksordner…). Je Schrank <Name>.skp (die Definition mit
# allen Teilen, Tags, Materialien und Attributen) und <Name>.json (Name, Version, Datum,
# Kategorie, Maße, Beschreibung). Wird ein Name erneut gespeichert, zählt die Version hoch und
# die bisherige Fassung wandert nach alt/<Name>_v<Version>.skp/.json.
# Einfügen: Definition laden, eigene Kopie, neues Kürzel FS<n> (alle Tags umbenannt), dann wie
# jeder neue Schrank an die Wand (Andocken).
# Lösen: der Schrank (z. B. USS1) bekommt eine eigene Definition, die Formeln der dynamischen
# Komponente werden entfernt (Werte bleiben, nichts wird mehr neu gezeichnet) und JT_Schrank/frei
# = true; danach gehen Teil zuweisen, Einsetzen und Speichern wie beim freien Schrank.

require 'json'
require 'fileutils'

module JTools
  module SchrankCnc
    module FreierSchrank
      module_function

      VORLAGE_DICT = 'JT_Vorlage'.freeze
      BIB_SEKTION = 'JT_SchrankCnc_Bibliothek'.freeze
      BIB_STANDARD = 'E:/sketchup komponenten/Bibliothek'.freeze

      def bibliothek_ordner
        Sketchup.read_default(BIB_SEKTION, 'ordner', BIB_STANDARD).to_s
      end

      def bibliothek_ordner=(pfad)
        Sketchup.write_default(BIB_SEKTION, 'ordner', pfad.to_s)
      end

      def dateiname(name)
        n = name.to_s.strip.gsub(/[\\\/:*?"<>|]+/, '_')
        raise ArgumentError, 'Bitte einen Namen angeben.' if n.empty?
        n
      end

      # Einträge der Bibliothek (aus den .json), nach Name
      def bibliothek(ordner = bibliothek_ordner)
        Dir.glob(File.join(ordner, '*.json')).map do |f|
          e = JSON.parse(File.read(f, encoding: 'UTF-8')) rescue nil
          next unless e.is_a?(Hash) && File.exist?(f.sub(/\.json\z/, '.skp'))
          e.merge('datei' => f.sub(/\.json\z/, '.skp'))
        end.compact.sort_by { |e| e['name'].to_s.downcase }
      end

      # Maße des Schranks (mm) aus seinen Teilen
      def masse(schrank)
        ws = werkstuecke_im(schrank)
        return [0, 0, 0] if ws.empty?
        (0..2).map { |a| (ws.map { |w| w.hi[a] }.max - ws.map { |w| w.lo[a] }.min).round }
      end

      # Freien (oder gelösten) Schrank in die Bibliothek speichern; liefert den Eintrag
      def speichern(model, schrank, name:, beschreibung: '', ordner: bibliothek_ordner)
        raise ArgumentError, 'Nur freie oder gelöste Schränke lassen sich speichern.' unless frei?(schrank)
        n = dateiname(name)
        FileUtils.mkdir_p(ordner)
        skp = File.join(ordner, "#{n}.skp")
        json = File.join(ordner, "#{n}.json")
        alt = File.exist?(json) ? (JSON.parse(File.read(json, encoding: 'UTF-8')) rescue {}) : {}
        version = alt['version'].to_i + 1
        if File.exist?(skp)
          FileUtils.mkdir_p(File.join(ordner, 'alt'))
          v = [alt['version'].to_i, 1].max
          FileUtils.mv(skp, File.join(ordner, 'alt', "#{n}_v#{v}.skp"))
          FileUtils.mv(json, File.join(ordner, 'alt', "#{n}_v#{v}.json")) if File.exist?(json)
        end
        d = Schraenke.definition(schrank)
        b, t, h = masse(schrank)
        e = { 'name' => name.to_s.strip, 'version' => version, 'datum' => Time.now.strftime('%Y-%m-%d %H:%M'),
              'kategorie' => d.get_attribute(JT_DICT, 'kategorie'), 'breite' => b, 'hoehe' => h, 'tiefe' => t,
              'beschreibung' => beschreibung.to_s }
        e.each { |k, v| d.set_attribute(VORLAGE_DICT, k, v) }
        d.set_attribute(JT_DICT, 'name', e['name'])
        raise 'Diese SketchUp-Version kann Komponenten nicht speichern.' unless d.respond_to?(:save_as)
        raise "Speichern nach #{skp} ging nicht." unless d.save_as(skp)
        File.write(json, JSON.pretty_generate(e), encoding: 'UTF-8')
        e.merge('datei' => skp)
      end

      # Alle Instanzen im Schrank (beliebige Tiefe)
      def alle_instanzen(ents, out = [])
        Schraenke.instanzen(ents).each do |i|
          out << i
          alle_instanzen(Schraenke.definition(i).entities, out)
        end
        out
      end

      # Neues Kürzel für den Schrank: JT_Schrank/schrank und alle Tags <alt>_… → <neu>_…
      def kuerzel_tauschen(model, schrank, neu)
        d = Schraenke.definition(schrank)
        alt = d.get_attribute(JT_DICT, 'schrank')
        d.set_attribute(JT_DICT, 'schrank', neu)
        alle_instanzen(d.entities).each do |i|
          i.set_attribute(JT_DICT, 'schrank', neu) if i.get_attribute(JT_DICT, 'schrank')
          n = i.layer && i.layer.name.to_s
          next unless alt && n && n.start_with?("#{alt}_")
          t = neu + n[alt.length..]
          i.layer = model.layers[t] || model.layers.add(t)
        end
        schrank.name = "#{neu} #{d.get_attribute(JT_DICT, 'name')}".strip if schrank.respond_to?(:name=)
        neu
      end

      # Schrank und jede Zwischenebene (Türhalter, Schubladen) bekommen eigene Definitionen, damit das
      # Umbenennen der Tags (sie hängen an den Instanzen darin) andere Schränke nicht ändert
      def eigene_definitionen(inst)
        d = Schraenke.definition(inst)
        inst.make_unique if inst.respond_to?(:make_unique) && d.respond_to?(:instances) && d.instances.length > 1
        Schraenke.instanzen(Schraenke.definition(inst).entities).each do |c|
          eigene_definitionen(c) unless Schraenke.instanzen(Schraenke.definition(c).entities).empty?
        end
      end

      # Schrank aus der Bibliothek ins Modell (noch nicht angedockt); datei = .skp
      def einfuegen(model, datei)
        raise ArgumentError, "#{datei} gibt es nicht." unless File.exist?(datei)
        d = model.definitions.load(datei)
        raise ArgumentError, "#{File.basename(datei)} ist kein freier Schrank." unless d && d.get_attribute(JT_DICT, 'schrank')
        x = model.entities.length > 0 ? model.bounds.max.x + zoll(100) : 0
        inst = model.entities.add_instance(d, Geom::Transformation.translation(Geom::Vector3d.new(x, 0, 0)))
        eigene_definitionen(inst)
        kuerzel_tauschen(model, inst, freies_kuerzel(model, ausser: inst))
        inst
      end

      # Fertigen Schrank lösen: eigene Definition, keine DC-Formeln mehr, frei bearbeitbar
      def loesen(model, schrank)
        raise ArgumentError, 'Bitte einen Schrank aus dem Küchenplaner wählen.' unless schrank?(schrank)
        return schrank if frei?(schrank)
        schrank.make_unique if schrank.respond_to?(:make_unique) && Schraenke.definition(schrank).instances.length > 1
        d = Schraenke.definition(schrank)
        ([schrank, d] + alle_instanzen(d.entities).flat_map { |i| [i, Schraenke.definition(i)] }).uniq.each do |e|
          dict = e.attribute_dictionary(DC_DICT) or next
          dict.keys.select { |k| k.to_s.end_with?('_formula') }.each { |k| e.delete_attribute(DC_DICT, k) }
        end
        d.set_attribute(JT_DICT, 'frei', true)
        schrank
      end

      # ------------------------------------------------------------------
      # Bedienung
      # ------------------------------------------------------------------
      def ordner_dialog
        Kuechenplaner::Eingabe.abfragen(['Bibliotheksordner'], [bibliothek_ordner], [':ordner'], 'Bibliothek eigener Schränke',
                                        ok: 'Übernehmen') do |w|
          raise ArgumentError, 'Bitte einen Ordner angeben.' if w[0].to_s.strip.empty?
          self.bibliothek_ordner = w[0].to_s.strip
        end
      end

      def speichern_dialog(model = Sketchup.active_model)
        schrank = schrank_zur_auswahl(model)
        unless schrank && frei?(schrank)
          UI.messagebox('Bitte einen freien oder gelösten Schrank wählen.')
          return
        end
        d = Schraenke.definition(schrank)
        name = d.get_attribute(VORLAGE_DICT, 'name') || d.get_attribute(JT_DICT, 'name').to_s
        Kuechenplaner::Eingabe.abfragen(['Name', 'Beschreibung'], [name, d.get_attribute(VORLAGE_DICT, 'beschreibung').to_s], ['', ''],
                                        'Eigenen Schrank speichern', ok: 'Speichern') do |w|
          meld = pruefen(model, schrank)
          e = speichern(model, schrank, name: w[0], beschreibung: w[1])
          text = "„#{e['name']}“ Version #{e['version']} gespeichert:\n#{e['datei']}"
          text += "\n\nHinweise:\n" + meld.map { |m| "• #{m}" }.join("\n") unless meld.empty?
          UI.messagebox(text)
        end
      end

      def einfuegen_dialog(model = Sketchup.active_model)
        liste = bibliothek
        if liste.empty?
          UI.messagebox("In #{bibliothek_ordner} liegen noch keine eigenen Schränke.\n" \
                        'Einen freien Schrank wählen und „Als eigenen Schrank speichern…“.')
          return
        end
        text = liste.map { |e| "#{e['name']} (#{e['kategorie']}, #{e['breite']} × #{e['hoehe']} × #{e['tiefe']}, V#{e['version']})" }
        Kuechenplaner::Eingabe.abfragen(['Schrank'], [text.first], [text.join('|')], 'Eigenen Schrank einfügen',
                                        untertitel: 'Bibliothek', ok: 'Einfügen') do |w|
          e = liste[text.index(w[0]) || 0]
          model.start_operation('Eigenen Schrank einfügen', true)
          begin
            inst = einfuegen(model, e['datei'])
            model.commit_operation
          rescue StandardError
            model.abort_operation
            raise
          end
          Kuechenplaner.neuer_schrank(inst) if Kuechenplaner.respond_to?(:neuer_schrank)
          model.selection.clear
          model.selection.add(inst)
        end
      end

      def loesen_dialog(model = Sketchup.active_model)
        s = model.selection.to_a.find { |e| schrank?(e) }
        unless s
          UI.messagebox('Bitte einen Schrank wählen.')
          return
        end
        if frei?(s)
          UI.messagebox('Der Schrank ist schon frei bearbeitbar.')
          return
        end
        kz = Schraenke.definition(s).get_attribute(JT_DICT, 'schrank')
        return unless UI.messagebox("#{kz} lösen? Danach lassen sich Teile frei ändern, die Komponentenoptionen " \
                                    'rechnen aber nichts mehr neu.', MB_OKCANCEL) == IDOK
        model.start_operation('Schrank lösen', true)
        begin
          loesen(model, s)
          model.commit_operation
        rescue StandardError
          model.abort_operation
          raise
        end
      end
    end
  end
end
