# encoding: UTF-8
# Schrank-CNC – TCN-Export: je sichtbarem Teil eine TCN-Datei (Dateiname = Tag),
# dazu Teileliste.csv. Gleiche Teile (gleicher Tag, gleiche TCN) werden einmal
# geschrieben und gezählt; weicht ein gleichnamiges Teil ab, bekommt es _2, _3 …

module JTools
  module SchrankCnc
    module Export
      Datei = Struct.new(:name, :text, :anzahl, :ws, :lage)

      def self.werkstuecke(model, auswahl: nil)
        # Arbeitsplatten (Komponenten/arbeitsplatte) bekommen einen eigenen Export
        # mit Verbindungsfräsung, siehe docs/plaene/arbeitsplatte.md; bis dahin übergangen
        Schraenke.teile(model).select do |t|
          t.sichtbar? && t.rolle != 'Arbeitsplatte' && (auswahl.nil? || t.pfad.any? { |i| auswahl.include?(i) })
        end.map { |t| Geometrie.werkstueck(t) }
      end

      def self.dateiname(name)
        name.to_s.gsub(/[\\\/:*?"<>|\s]+/, '_')
      end

      # Ergebnis: [Dateien, Meldungen]
      def self.erzeugen(model, auswahl: nil)
        ws = werkstuecke(model, auswahl: auswahl)
        meldungen = Regeln.anwenden(ws)
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
        [dateien, meldungen.uniq]
      end

      def self.teileliste(dateien)
        z = ['Datei;Anzahl;Schrank;Teil;Rolle;Material;DL;DH;DS']
        dateien.each do |d|
          t = d.ws.teil
          mat = t.inst.material ? t.inst.material.name : ''
          z << [d.name + '.tcn', d.anzahl, t.jt('schrank'), t.jt('teil'), t.rolle, mat,
                Tcn.n(d.lage.dl), Tcn.n(d.lage.dh), Tcn.n(d.lage.ds)].join(';')
        end
        z.join("\r\n") + "\r\n"
      end

      def self.schreiben(ordner, dateien)
        dateien.each { |d| Tcn.write(File.join(ordner, "#{d.name}.tcn"), d.text) }
        Tcn.write(File.join(ordner, 'Teileliste.csv'), teileliste(dateien))
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
        text = "#{dateien.size} TCN-Dateien (#{stueck} Teile#{auswahl ? ', nur Auswahl' : ''}) und Teileliste.csv in\n#{ordner}"
        text += "\n\nHinweise:\n" + meldungen.first(15).join("\n") unless meldungen.empty?
        text += "\n…" if meldungen.size > 15
        UI.messagebox(text)
      end
    end
  end
end
