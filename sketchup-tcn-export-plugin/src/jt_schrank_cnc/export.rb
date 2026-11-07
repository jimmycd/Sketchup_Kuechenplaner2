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
      # zweite: zweite Aufspannung desselben Teils (freier Schrank: Mittelwand, auf beiden Flächen gebohrt)
      Datei = Struct.new(:name, :text, :anzahl, :ws, :lage, :nr, :zweite) do
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
          f1 = Regeln.flaeche1(w)
          lage = Geometrie.lage(w, f1)
          w2 = zweite_seite(w, f1)
          if w2
            m = []
            text = Tcn.text(lage, m)
            meldungen.concat(m.reject { |x| x.include?('auf der Unterseite') })
          else
            text = Tcn.text(lage, meldungen)
          end
          ablegen(dateien, w, lage, text)
          next unless w2
          l2 = Geometrie.lage(w2, gegenseite(f1))
          ablegen(dateien, w2, l2, Tcn.text(l2, meldungen), zweite: true)
        end
        ap, ap_meldungen = Arbeitsplatten.dateien(model, auswahl: auswahl)
        ap.each { |name, text, teil, lage| dateien << Datei.new(name, text, 1, Arbeitsplatten::Ws.new(teil), lage) }
        nummerieren(dateien)
        [dateien, (meldungen + ap_meldungen).uniq]
      end

      def self.gegenseite(f)
        f.to_s.end_with?('max') ? f.to_s.sub('max', 'min').to_sym : f.to_s.sub('min', 'max').to_sym
      end

      # Freier Schrank: Teil mit Bearbeitungen auf beiden Flächen (Mittelwand: Schienen auf der einen,
      # Lochreihe auf der anderen Seite) bekommt eine zweite TCN „…_Seite2“ für die gewendete Platte
      # mit den Bearbeitungen der Gegenseite; in der Stückliste bleibt es eine Zeile.
      def self.zweite_seite(w, f1)
        return nil unless w.teil.jt('typ') == FreierSchrank::TYP
        g = gegenseite(f1)
        ops = w.ops.select { |o| o.seite == g && o.art != :kontur }
        return nil if ops.empty?
        w2 = w.dup
        w2.ops = ops
        w2
      end

      def self.ablegen(dateien, w, lage, text, zweite: false)
        basis = dateiname(w.name)
        basis = "#{basis}_Seite2" if zweite
        gleich = dateien.find { |d| d.name.sub(/_\d+\z/, '') == basis && d.text == text } ||
                 dateien.find { |d| d.name == basis && d.text == text }
        if gleich
          gleich.anzahl += 1
        else
          name = basis
          k = 1
          name = "#{basis}_#{k += 1}" while dateien.any? { |d| d.name == name }
          dateien << Datei.new(name, text, 1, w, lage, nil, zweite)
        end
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
