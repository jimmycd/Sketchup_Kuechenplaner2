# encoding: UTF-8
# Schrank-CNC – TCN-Export: je sichtbarem Teil eine TCN-Datei (Dateiname = laufende Nummer
# der Stückliste + Tag, z. B. 102_UST2_StrebeVorn.tcn; die Nummer ist dieselbe wie auf
# Stückliste, Etiketten und Zuschnittplan, siehe Stueckliste.zeilen),
# dazu Teileliste.csv und die Fräsliste Liste_<Ordner>.xmlst für das TpaCAD-Board
# (alle TCN zusammen, größte Teile zuerst, siehe fraesliste.rb). Gleiche Teile (gleicher Tag, gleiche TCN) werden einmal
# geschrieben und gezählt; weicht ein gleichnamiges Teil ab, bekommt es _2, _3 …
# Arbeitsplatten: je Stoßende eine TCN mit der Verbindungsfräsung (arbeitsplatte.rb).

module JTools
  module SchrankCnc
    module Export
      Datei = Struct.new(:name, :text, :anzahl, :ws, :lage, :nr) do
        # Dateiname der TCN: "<Nr>_<Tag>.tcn" (ohne Nummer nur der Tag)
        def datei
          nr ? "#{nr}_#{name}.tcn" : "#{name}.tcn"
        end
      end

      def self.werkstuecke(model, auswahl: nil)
        # Arbeitsplatten (Komponenten/arbeitsplatte) haben einen eigenen Export
        # mit Verbindungsfräsung, siehe arbeitsplatte.rb
        Schraenke.teile(model).select do |t|
          t.sichtbar? && t.rolle != 'Arbeitsplatte' && (auswahl.nil? || t.pfad.any? { |i| auswahl.include?(i) })
        end.map { |t| Geometrie.werkstueck(t) }
      end

      def self.dateiname(name)
        name.to_s.gsub(/[\\\/:*?"<>|\s]+/, '_')
      end

      # Ergebnis: [Dateien, Meldungen]; alle_ws: Array, das alle Werkstücke mit Bearbeitungen bekommt
      # (gleiche Teile nicht zusammengefasst, z. B. für die Beschlagliste)
      def self.erzeugen(model, auswahl: nil, alle_ws: nil)
        ws = werkstuecke(model, auswahl: auswahl)
        meldungen = Regeln.anwenden(ws)
        alle_ws&.concat(ws)
        dateien = []
        ws.each do |w|
          lage = Geometrie.lage(w, Regeln.flaeche1(w))
          text = Tcn.text(lage, meldungen)
          basis = dateiname(w.name)
          gleich = dateien.find { |d| d.name.sub(/_\d+\z/, '') == basis && d.text == text } ||
                   dateien.find { |d| d.name == basis && d.text == text }
          if gleich
            gleich.anzahl += 1
          else
            name = basis
            k = 1
            name = "#{basis}_#{k += 1}" while dateien.any? { |d| d.name == name }
            dateien << Datei.new(name, text, 1, w, lage)
          end
        end
        ap, ap_meldungen = Arbeitsplatten.dateien(model, auswahl: auswahl)
        ap.each { |name, text, teil, lage| dateien << Datei.new(name, text, 1, Arbeitsplatten::Ws.new(teil), lage) }
        nummerieren(dateien)
        [dateien, (meldungen + ap_meldungen).uniq]
      end

      # Laufende Nummer je Datei aus der Stückliste (gleiche Sortierung, gleiche Nummer wie
      # Stückliste/Etiketten/Zuschnitt); beide TCN einer Arbeitsplatte mit zwei Stoßenden
      # gehören zu einer Stücklistenzeile und bekommen dieselbe Nummer.
      def self.nummerieren(dateien)
        nr = {}.compare_by_identity
        Stueckliste.zeilen(dateien).each { |z| nr[z.quelle.ws.teil.inst] = z.nr }
        dateien.each { |d| d.nr = nr[d.ws.teil.inst] }
      end

      def self.teileliste(dateien)
        z = ['Datei;Anzahl;Schrank;Teil;Rolle;Material;DL;DH;DS;Teilname']
        dateien.each do |d|
          t = d.ws.teil
          mat = t.inst.material ? t.inst.material.name : ''
          z << [d.datei, d.anzahl, t.jt('schrank'), t.jt('teil'), t.rolle, mat,
                Tcn.n(d.lage.dl), Tcn.n(d.lage.dh), Tcn.n(d.lage.ds), Fraesliste.ocl_name(d)].join(';')
        end
        z.join("\r\n") + "\r\n"
      end

      def self.schreiben(ordner, dateien)
        dateien.each { |d| Tcn.write(File.join(ordner, d.datei), d.text) }
        Tcn.write(File.join(ordner, 'Teileliste.csv'), teileliste(dateien))
        Fraesliste.schreiben(ordner, dateien)
      end

      def self.dialog(model = Sketchup.active_model)
        auswahl = model.selection.to_a.empty? ? nil : model.selection.to_a
        dateien, meldungen = erzeugen(model, auswahl: auswahl)
        if dateien.empty?
          UI.messagebox('Keine Schrankteile gefunden (Teile mit Tag und JT_Schrank, sichtbar).')
          return
        end
        ordner = UI.select_directory(title: 'Ordner für die TCN-Dateien')
        return unless ordner
        schreiben(ordner, dateien)
        stueck = dateien.sum(&:anzahl)
        text = "#{dateien.size} TCN-Dateien (#{stueck} Teile#{auswahl ? ', nur Auswahl' : ''}), Teileliste.csv und #{Fraesliste.name(ordner)} in\n#{ordner}"
        text += "\n\nHinweise:\n" + meldungen.first(15).join("\n") unless meldungen.empty?
        text += "\n…" if meldungen.size > 15
        UI.messagebox(text)
      end
    end
  end
end
