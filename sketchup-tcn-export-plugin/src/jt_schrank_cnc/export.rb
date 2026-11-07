# encoding: UTF-8
# Schrank-CNC – TCN-Export: je sichtbarem Teil eine TCN-Datei (Dateiname = laufende Nummer
# der Stückliste + Tag, z. B. 102_UST2_StrebeVorn.tcn; die Nummer ist dieselbe wie auf
# Stückliste, Etiketten und Zuschnittplan, siehe Stueckliste.zeilen),
# dazu die Fräsliste Liste_<Ordner>.xmlst für das TpaCAD-Board
# (alle TCN zusammen, größte Teile zuerst, siehe fraesliste.rb). Gleiche Teile (gleicher Tag, gleiche TCN) werden einmal
# geschrieben und gezählt; weicht ein gleichnamiges Teil ab, bekommt es _2, _3 …
# Arbeitsplatten: je Stoßende eine TCN mit der Verbindungsfräsung (arbeitsplatte.rb).
# Eine eigene Teileliste gibt es nicht mehr: alle Angaben (TCN-Datei, Anzahl, Maße, Material)
# stehen in der Stückliste. Den Dialog für alle Ausgaben hat ausgabe.rb.

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
        meldungen.concat(FreierSchrank.pruefen_alle(model, auswahl: auswahl)) # frei modellierte Schränke
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

      # TCN-Dateien und Fräsliste in den Ordner; liste = Name der Fräsliste (Standard Liste_<Ordner>.xmlst)
      def self.schreiben(ordner, dateien, liste: nil)
        dateien.each { |d| Tcn.write(File.join(ordner, d.datei), d.text) }
        Fraesliste.schreiben(ordner, dateien, liste: liste)
      end

      # Früher eigener TCN-Dialog; jetzt ein Dialog für Stückliste, Etiketten, Zuschnitt und TCN
      def self.dialog(model = Sketchup.active_model)
        Ausgabe.dialog(model)
      end
    end
  end
end
