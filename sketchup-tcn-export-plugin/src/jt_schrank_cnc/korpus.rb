# encoding: UTF-8
# Schrank-CNC – Korpusmaterial ändern (Gegenstück zu „Frontfarbe und Griffe ändern“).
#
# Setzt eine Platte mit Verwendung Korpus (bzw. Rückwand) aus Küchenplaner › Materialien…
# auf die Korpusteile (Seiten, Böden, Deckel, Streben, Zwischen- und Einlegeböden, Leisten,
# Wangen) oder auf die Rückwände, für alle Schränke, nur Ober-, Unter- oder Hochschränke,
# auf Wunsch nur für die ausgewählten. Fronten, Sichtteile mit Frontfarbe und Schubkästen
# bleiben unverändert. Die Anleimer der Teile bekommen den zugeordneten Anleimer.

module JTools
  module SchrankCnc
    module Korpusmaterial
      module_function

      TEILE = {
        'Korpus (Seiten, Böden, Streben …)' => %w[Seite Boden Deckel Strebe Zwischenboden Einlegeboden Leiste Wange],
        'Rückwände' => %w[Rueckwand]
      }.freeze
      BEREICHE = { 'Alle Schränke' => nil, 'Nur Oberschränke' => 'Oberschrank',
                   'Nur Unterschränke' => 'Unterschrank', 'Nur Hochschränke' => 'Hochschrank' }.freeze
      NEU = 'Neues Korpusmaterial…'.freeze

      def ziel_inst?(inst, rollen)
        rollen.include?(inst.get_attribute(JT_DICT, 'rolle')) && !Frontfarbe.front_inst?(inst)
      end

      def teile(model, rollen: TEILE.values.first, kategorie: nil, auswahl: nil)
        Schraenke.teile(model).select do |t|
          ziel_inst?(t.inst, rollen) && (kategorie.nil? || Schraenke.kategorie(t) == kategorie) &&
            (auswahl.nil? || t.pfad.any? { |i| auswahl.include?(i) })
        end
      end

      def vorschau(teile)
        n_s = teile.map(&:schrank).uniq.size
        "#{teile.size} #{teile.size == 1 ? 'Teil' : 'Teile'} in #{n_s} #{n_s == 1 ? 'Schrank' : 'Schränken'}"
      end

      def anwenden(model, teile, material, rollen: TEILE.values.first)
        return 0 if teile.empty?
        kante = Materialien.anleimer(model, material)
        Frontfarbe.eindeutig_machen(teile, ->(i) { ziel_inst?(i, rollen) })
        ids = teile.map { |t| t.pfad.first }.uniq
        namen = teile.map(&:name)
        neu = Schraenke.teile(model).select { |t| ziel_inst?(t.inst, rollen) && ids.include?(t.pfad.first) && namen.include?(t.name) }
        neu.each { |t| Frontfarbe.material_setzen(t.inst, material, kante) }
        neu.size
      end

      def dialog(model = Sketchup.active_model, art: TEILE.keys.first)
        verwendung = art == TEILE.keys.last ? 'Rückwand' : 'Korpus'
        namen = Materialien.plattennamen(model, verwendung)
        prompts = ['Teile', 'Material', 'Bereich', 'Nur ausgewählte Schränke']
        defaults = [art, namen.first || NEU, BEREICHE.keys.first, model.selection.to_a.empty? ? 'Nein' : 'Ja']
        listen = [TEILE.keys.join('|'), (namen + [NEU]).join('|'), BEREICHE.keys.join('|'), 'Ja|Nein']
        Kuechenplaner::Eingabe.abfragen(prompts, defaults, listen, 'Korpusmaterial ändern', ok: 'Übernehmen') do |w|
          rollen = TEILE.fetch(w[0])
          if w[1] == NEU
            Materialdialog.platte_formular(model, verwendung: w[0] == TEILE.keys.last ? 'Rückwand' : 'Korpus') do
              dialog(model, art: w[0])
            end
            next
          end
          raise ArgumentError, "Material „#{w[1]}“ nicht gefunden" unless Materialien.plattennamen(model).include?(w[1])
          t = teile(model, rollen: rollen, kategorie: BEREICHE[w[2]], auswahl: w[3] == 'Ja' ? model.selection.to_a : nil)
          if t.empty?
            UI.messagebox('Im gewählten Bereich gibt es keine passenden Teile.')
            next
          end
          next unless UI.messagebox("#{vorschau(t)} bekommen „#{w[1]}“. Übernehmen?", MB_OKCANCEL) == IDOK

          model.start_operation('Korpusmaterial ändern', true)
          begin
            anwenden(model, t, Materialien.holen(model, w[1]), rollen: rollen)
            model.commit_operation
          rescue StandardError
            model.abort_operation
            raise
          end
        end
      end
    end
  end
end
