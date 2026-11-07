# encoding: UTF-8
# Schrank-CNC – Beschläge und Griffe je Schrank (Jürgen, 2026-11-07: „ermögliche an jedem Schrank
# individuell die generelle Einstellung für Beschläge und Griffe zu ändern“).
#
# Küchenplaner › Beschläge und Griffe der gewählten Schränke… (auch im Kontextmenü eines Schranks):
# je Beschlagart, die der Schrank hat, „wie Küche (…)“ oder ein eigenes Modell aus dem Beschlag-Katalog,
# dazu die Griffe der Fronten: Größe aus der Griffserie der Küche (Griffkatalog; Vorschlag nach Frontbreite,
# feste Größe, eigenes Lochmaß oder kein Griff), Lage und Höhe (automatisch oder fest).
# Die eigene Wahl steht am Schrank (JT_Schrank/beschlag_<art>, Beschlagkatalog.schrank_waehlen) und gilt
# für TCN, Beschlagliste und Beschlagmodell; ändert man die Einstellung der Küche, bleibt sie.

module JTools
  module SchrankCnc
    module Schrankbeschlag
      module_function

      WIE_KUECHE = 'wie Küche'.freeze
      UNVERAENDERT = 'unverändert lassen'.freeze
      VORSCHLAG = 'Vorschlag nach Frontbreite'.freeze
      EIGENES = 'eigenes Lochmaß (unten)'.freeze
      KEIN = 'kein Griff'.freeze
      LAGE_AUTO = 'automatisch (Mitte)'.freeze
      HOEHE_HILFE = 'leer = unverändert, auto = automatisch'.freeze
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
          when 'sockelfuss' then r.include?('Boden') && Regeln::SOCKEL_KATEGORIEN.include?(d.get_attribute(JT_DICT, 'kategorie').to_s)
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
        prompts += ["#{GRUPPE_GRIFF}: Griff", "#{GRUPPE_GRIFF}: eigenes Lochmaß (mm)", "#{GRUPPE_GRIFF}: Lage seitlich",
                    "#{GRUPPE_GRIFF}: Höhe ab Unterkante Front (mm, #{HOEHE_HILFE})"]
        alt += [UNVERAENDERT, '160', UNVERAENDERT, '']
        listen += [groessen(model).keys.join('|'), '', ([UNVERAENDERT, LAGE_AUTO] + Frontfarbe::LAGEN).join('|'), '']
        [arten, prompts, alt, listen]
      end

      # Auswahl der Griffgröße: Text => Wert für Griffkatalog.front_setzen (Größen der Serie der Küche)
      def groessen(model)
        s = Griffkatalog.kueche(model)
        serie = []
        if s
          serie = Griffkatalog.lochabstaende(s).map do |l|
            g = Griffkatalog.groesse(s, l, Griffkatalog.oberflaeche(model))
            text = if Griffkatalog.knopf?(s)
                     "#{s['kennung']} Knopf Ø #{Griffkatalog.zahl(g['laenge'])}"
                   else
                     "#{s['kennung']} Lochabstand #{Griffkatalog.zahl(l)} mm (#{Griffkatalog.zahl(g['laenge'])} lang)"
                   end
            [text, l]
          end
        end
        ([[UNVERAENDERT, nil], [VORSCHLAG, :vorschlag]] + serie + [[EIGENES, :eigen], [KEIN, :aus]]).to_h
      end

      # Vorschlag für die Fronten der Schränke, z. B. „Front 600 → 192 mm, 400 → 128 mm“ (nil ohne Serie)
      def vorschlag_text(model, schraenke)
        s = Griffkatalog.kueche(model) or return nil
        br = Frontfarbe.fronten(model, auswahl: schraenke).select { |t| t.front? && t.sichtbar? }.map do |t|
          w = Geometrie.werkstueck(t)
          next nil if w.dicke_achse == 2
          w.mass(w.dicke_achse.zero? ? 1 : 0).round
        end.compact.uniq.sort.reverse
        return nil if br.empty?
        teile = br.map { |b| "#{b} → #{Griffkatalog.knopf?(s) ? 'Knopf' : "#{Griffkatalog.zahl(Griffkatalog.vorschlag(s, b))} mm"}" }
        "Griffserie #{s['kennung']}, Vorschlag je Frontbreite: #{teile.join(', ')}"
      end

      # Eingaben der Griff-Felder [Griff, Lochmaß, Lage, Höhe] in die Form für Griffkatalog.front_setzen;
      # nil = nichts ändern
      def griff_wahl(model, g)
        gr = groessen(model).fetch(g[0].to_s) { raise ArgumentError, 'Griff: bitte aus der Liste wählen.' }
        gr = Frontfarbe.zahl(g[1]) if gr == :eigen
        lage = case g[2].to_s
               when UNVERAENDERT then nil
               when LAGE_AUTO then :auto
               else g[2].to_s
               end
        hoehe = case g[3].to_s.strip.downcase
                when '' then nil
                when 'auto', 'automatisch' then :auto
                else Frontfarbe.zahl(g[3])
                end
        return nil if gr.nil? && lage.nil? && hoehe.nil?
        { groesse: gr, lage: lage, hoehe: hoehe }
      end

      # Eingaben übernehmen: wahl = { art => Kennung oder nil (wie Küche) }, griff wie Frontfarbe.anwenden.
      # Rückgabe: Kürzel der Schränke, die sich nicht anpassen (Schubladen, grifflose Front; ältere Version)
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
        vs = vorschlag_text(model, sch)
        Kuechenplaner::Eingabe.abfragen(prompts, alt, listen, 'Beschläge und Griffe des Schranks',
                                        untertitel: "#{titel} – abweichend von den Einstellungen der Küche#{vs ? ". #{vs}" : ''}",
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
          griff = griff_wahl(model, res[arten.size, 4])
          model.start_operation('Beschläge und Griffe des Schranks', true)
          begin
            nicht = anwenden(model, sch, wahl, griff: griff)
            model.commit_operation
          rescue StandardError
            model.abort_operation
            raise
          end
          unless nicht.empty?
            UI.messagebox("Diese Schränke sind mit einer älteren Version angelegt und passen sich nicht an den " \
                          "Auszug oder die grifflose Front an: #{nicht.uniq.join(', ')}. Bitte neu anlegen.")
          end
          Beschlagmodell.nachziehen(model) if defined?(Beschlagmodell)
          if defined?(Griffmodell)
            model.start_operation('Griffe', true, false, true)
            sch.each { |s| Griffmodell.schrank_aktualisieren(model, s) }
            model.set_attribute(Griffmodell::DICT, 'an', true)
            model.commit_operation
          end
          true
        end
      rescue ArgumentError => e
        UI.messagebox("Ungültige Eingabe: #{e.message}")
      end
    end
  end
end
