# encoding: UTF-8
# Schrank-CNC – Beschläge und Griffe je Schrank (Jürgen, 2026-11-07: „ermögliche an jedem Schrank
# individuell die generelle Einstellung für Beschläge und Griffe zu ändern“).
#
# Küchenplaner › Beschläge und Griffe der gewählten Schränke… (auch im Kontextmenü eines Schranks):
# je Beschlagart, die der Schrank hat, „wie Küche (…)“ oder ein eigenes Modell aus dem Beschlag-Katalog,
# dazu die Griffe der Fronten (Lochmaß, Lage, Höhe wie bei „Frontfarbe und Griffe ändern“).
# Die eigene Wahl steht am Schrank (JT_Schrank/beschlag_<art>, Beschlagkatalog.schrank_waehlen) und gilt
# für TCN, Beschlagliste und Beschlagmodell; ändert man die Einstellung der Küche, bleibt sie.

module JTools
  module SchrankCnc
    module Schrankbeschlag
      module_function

      WIE_KUECHE = 'wie Küche'.freeze
      GRIFF_OPT = ['unverändert lassen', 'setzen', 'entfernen'].freeze
      GRUPPE_BESCHLAG = 'Beschläge'.freeze
      GRUPPE_GRIFF = 'Griffe'.freeze

      # Schränke (oberste Ebene) in der Auswahl; geöffneter Schrank zählt auch
      def schraenke(model)
        pfad = model.respond_to?(:active_path) ? (model.active_path || []) : []
        kandidaten = model.selection.to_a + pfad.first(1)
        kandidaten.select { |i| (i.is_a?(Sketchup::ComponentInstance) || i.is_a?(Sketchup::Group)) && schrank?(i) }.uniq
      end

      def schrank?(i)
        Schraenke.definition(i).get_attribute(JT_DICT, 'schrank') ? true : false
      end

      # Rollen aller Teile des Schranks
      def rollen(s, d = Schraenke.definition(s), tiefe = 0, out = [])
        return out if tiefe > 5
        Schraenke.instanzen(d.entities).each do |i|
          r = i.get_attribute(JT_DICT, 'rolle')
          out << r.to_s if r
          rollen(s, Schraenke.definition(i), tiefe + 1, out)
        end
        out
      end

      # Beschlagarten, die dieser Schrank hat (in der Reihenfolge der Einstellungen)
      def arten(s)
        d = Schraenke.definition(s)
        r = rollen(s)
        tuer = r.include?('Tuer')
        kasten = Beschlagkatalog.schubladen?(d)
        klappe = Schraenke.dc(s, 'art_klappe')
        jt = Beschlagkatalog::JT_BESCHLAG[d.get_attribute(JT_DICT, 'beschlag').to_s]
        # Falttür (Eckschrank L, Eck-Oberschrank): L-Form trägt l_gebaut
        falt = tuer && %w[JT_Eckschrank JT_EckOberschrank].any? { |k| d.get_attribute(k, 'l_gebaut') } ? true : false
        Beschlagkatalog::ARTEN.keys.select do |a|
          case a
          when 'schubladen' then kasten
          when 'topfband' then tuer
          when 'topfband_innen' then tuer && (kasten || falt)
          when 'falttuer' then falt
          when 'topfband_kuehlschrank' then tuer && !Schraenke.dc(s, 'tuertechnik').nil?
          when 'klappe' then klappe && klappe.to_f.round != 2
          when 'faltklappe' then klappe && klappe.to_f.round == 2
          when 'hochauszug', 'eckauszug' then jt == a
          when 'oeffnung' then tuer || r.include?('Front')
          else false
          end
        end
      end

      def name_wie_kueche(art, model)
        "#{WIE_KUECHE} (#{Beschlagkatalog.kueche(art, model)['name']})"
      end

      # Felder: je Art eine Liste, darunter die Griffe. Vorschlag: gemeinsame eigene Wahl aller Schränke
      def felder(model, schraenke)
        arten = Beschlagkatalog::ARTEN.keys.select { |a| schraenke.any? { |s| arten(s).include?(a) } }
        prompts = arten.map { |a| "#{GRUPPE_BESCHLAG}: #{Beschlagkatalog::ARTEN[a][:name]}" }
        alt = arten.map do |a|
          k = schraenke.map { |s| Beschlagkatalog.eigen(a, s) }.uniq
          k.size == 1 && k.first ? Beschlagkatalog.eintrag(k.first)['name'] : name_wie_kueche(a, model)
        end
        listen = arten.map { |a| ([name_wie_kueche(a, model)] + Beschlagkatalog.zur_art(a).map { |e| e['name'] }).join('|') }
        prompts += ["#{GRUPPE_GRIFF}: Griffe", "#{GRUPPE_GRIFF}: Lochmaß (mm)", "#{GRUPPE_GRIFF}: Lage seitlich",
                    "#{GRUPPE_GRIFF}: Höhe ab Unterkante Front (mm)"]
        alt += [GRIFF_OPT.first, '160', 'Mitte', '35']
        listen += [GRIFF_OPT.join('|'), '', Frontfarbe::LAGEN.join('|'), '']
        [arten, prompts, alt, listen]
      end

      # Eingaben übernehmen: wahl = { art => Kennung oder nil (wie Küche) }, griff wie Frontfarbe.anwenden.
      # Rückgabe: Kürzel der Schränke, deren Schubladen sich nicht anpassen (ältere Version)
      def anwenden(model, schraenke, wahl, griff: nil)
        nicht = []
        schraenke.each do |s|
          eigene = arten(s)
          wahl.each do |a, k|
            next unless eigene.include?(a)
            next if Beschlagkatalog.eigen(a, s) == k
            ok = Beschlagkatalog.schrank_waehlen(s, a, k, model)
            nicht << Schraenke.definition(s).get_attribute(JT_DICT, 'schrank') unless ok
          end
        end
        unless griff.nil?
          f = Frontfarbe.fronten(model, auswahl: schraenke)
          Frontfarbe.anwenden(model, f, nil, griff: griff) unless f.empty?
        end
        nicht
      end

      def dialog(model = Sketchup.active_model)
        sch = schraenke(model)
        if sch.empty?
          UI.messagebox('Bitte zuerst einen oder mehrere Schränke auswählen.')
          return
        end
        arten, prompts, alt, listen = felder(model, sch)
        titel = sch.size == 1 ? "Schrank #{Schraenke.definition(sch.first).get_attribute(JT_DICT, 'schrank')}" : "#{sch.size} Schränke"
        Kuechenplaner::Eingabe.abfragen(prompts, alt, listen, 'Beschläge und Griffe des Schranks',
                                        untertitel: "#{titel} – abweichend von den Einstellungen der Küche",
                                        ok: 'Übernehmen') do |res|
          wahl = arten.each_with_index.to_h do |a, i|
            v = res[i].to_s
            if v.start_with?(WIE_KUECHE)
              [a, nil]
            else
              e = Beschlagkatalog.zur_art(a).find { |x| x['name'] == v }
              raise ArgumentError, "#{Beschlagkatalog::ARTEN[a][:name]}: bitte ein Modell aus der Liste wählen." unless e
              [a, e['kennung']]
            end
          end
          g = res[arten.size, 4]
          griff = case g[0]
                  when 'setzen' then { lochmass: Frontfarbe.zahl(g[1]), lage: g[2], hoehe: Frontfarbe.zahl(g[3]) }
                  when 'entfernen' then false
                  end
          model.start_operation('Beschläge und Griffe des Schranks', true)
          begin
            nicht = anwenden(model, sch, wahl, griff: griff)
            model.commit_operation
          rescue StandardError
            model.abort_operation
            raise
          end
          unless nicht.empty?
            UI.messagebox("Diese Schränke sind mit einer älteren Version angelegt und passen ihre Schubladen nicht an " \
                          "den Auszug an: #{nicht.uniq.join(', ')}. Bitte neu anlegen.")
          end
          Beschlagmodell.nachziehen(model) if defined?(Beschlagmodell)
          true
        end
      rescue ArgumentError => e
        UI.messagebox("Ungültige Eingabe: #{e.message}")
      end
    end
  end
end
