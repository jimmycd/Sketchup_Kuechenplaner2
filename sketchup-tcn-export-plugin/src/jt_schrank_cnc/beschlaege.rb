# encoding: UTF-8
# Schrank-CNC – Beschlagliste (eigene Seite in der Stückliste).
#
# Wird aus denselben Werkstücken wie der TCN-Export berechnet (nach Regeln.anwenden), damit
# Bohrbilder und Beschläge zusammenpassen:
#   Schubladen  Blum LEGRABOX free (Montageanleitung MD-015/4): Zargen N, M, K, C oder F (Regeln.zarge),
#               Korpusschienen je Nennlänge (40 kg, NL 650 70 kg), Rückwand- und Fronthalter,
#               Seiteneinsätze (S. 4: C 138 / M 52, F/K abgeleitet, × NL − 112 × 10), Seitenstabilisierung ab KB 600 (S. 9),
#               Schrauben 4 × 15 für Fronthalter und Boden (S. 5), Systemschrauben für die Schienen.
#   Türen       Blum-Topfbänder Ø35 mit Montageplatte (Regeln.topfbaender), Systemschrauben dafür.
#   Klappen     AVENTOS HK-top, Häfele Free Slim flap (Regeln.aventos, Regeln.free_slim).
# Blum-Artikelnummern stehen nicht in der Anleitung; die Liste nennt deshalb Typ, Größe und Anzahl.

module JTools
  module SchrankCnc
    module Beschlaege
      module_function

      Posten = Struct.new(:gruppe, :beschlag, :hinweis, :anzahl, :einheit, :schraenke)

      KG_70 = [650].freeze           # NL 650 gibt es nur als 70-kg-Schiene (S. 3)
      KB_STABILISIERUNG = 600.0      # Seitenstabilisierung ab Korpusbreite 600 mm (S. 9)
      BODEN_SCHRAUBEN = 8            # 4 × 15, je Seite 4 (S. 5, Bild 4)
      SYSTEMSCHRAUBE = 'Systemschraube Ø5 (Blum)'.freeze

      # werkstuecke: alle Werkstücke nach Regeln.anwenden (mit Bearbeitungen)
      def liste(werkstuecke)
        sammler = {}
        add = lambda do |gruppe, beschlag, hinweis, anzahl, einheit, schrank|
          return if anzahl.to_i <= 0
          p = (sammler[[gruppe, beschlag, hinweis, einheit]] ||= Posten.new(gruppe, beschlag, hinweis, 0, einheit, []))
          p.anzahl += anzahl
          p.schraenke << schrank unless schrank.to_s.empty? || p.schraenke.include?(schrank)
        end
        werkstuecke.group_by { |w| w.teil.pfad.first }.each_value do |teile|
          schubladen(teile, add)
          tueren(teile, add)
          klappen(teile, add)
        end
        # je Gruppe nach Beschlagart (Zargen, Schienen, Halter …), dann Größe
        sammler.values.each_with_index.sort_by do |p, i|
          [GRUPPEN.index(p.gruppe) || 9, REIHENFOLGE.index { |r| p.beschlag.start_with?(r) } || 99, p.beschlag, p.hinweis.to_s, i]
        end.map(&:first)
      end

      GRUPPEN = ['Schubladen (LEGRABOX free)', 'Schrauben Schubladen', 'Türen (Topfbänder)', 'Klappen (AVENTOS)',
                 'Klappen (Häfele Free Slim)'].freeze
      REIHENFOLGE = ['Zargen', 'Korpusschienen', 'Rückwandhalter', 'Fronthalter', 'Seiteneinsatz', 'Seitenstabilisierung',
                     'Häfele Free Slim', 'Spanplattenschraube', 'Blum Topfband', 'Blum Falttür', 'Blum Montageplatte', 'Blum AVENTOS HK-top Kraft',
                     'Blum AVENTOS HK-top Front', 'Systemschraube'].freeze

      def schubladen(teile, add)
        Regeln.kaesten(teile).each do |kasten|
          boden = kasten.find { |w| w.rolle == 'KastenBoden' } or next
          sk = boden.teil.jt('schrank')
          bereich = boden.teil.jt('bereich')
          m = Regeln.zarge(kasten)
          z = Regeln::ZARGEN[m]
          schienen = teile.flat_map(&:ops).select { |o| o.titel == "Schiene #{bereich}" && o.daten }
          nl = schienen.map { |o| o.daten[:nl] }.compact.max
          wa = Regeln.breite_achse(kasten)
          lw = boden.mass(wa) + 35.0
          seite = teile.find { |w| w.rolle == 'Seite' && w.dicke_achse == wa }
          kb = lw + 2 * (seite ? seite.mass(wa) : 19.0)
          g = GRUPPEN[0]
          nl_text = nl ? "NL #{nl}" : 'NL ? (zu wenig Tiefe)'
          add.(g, "Zargen #{m} (#{Tcn.n(z[:hoehe]).tr('.', ',')} mm), links + rechts", nl_text, 1, 'Paar', sk)
          add.(g, 'Korpusschienen', "#{nl_text}, #{nl && KG_70.include?(nl) ? 70 : 40} kg", 1, 'Paar', sk)
          add.(g, "Rückwandhalter Holzrückwand #{m}", "Holzrückwand #{Tcn.n(z[:rueckwand])} mm hoch", 1, 'Paar', sk)
          add.(g, "Fronthalter #{m}", 'Frontbefestigung links + rechts', 1, 'Paar', sk)
          if z[:einsatz] # Zarge N: kein Seiteneinsatz
            add.(g, 'Seiteneinsatz Glas 10 mm (oder 10-mm-Platte)', nl ? "#{z[:einsatz]} × #{nl - 112} mm" : "#{z[:einsatz]} × (NL − 112) mm", 2, 'Stück', sk)
          end
          add.(g, 'Seitenstabilisierung', "Korpusbreite ab #{KB_STABILISIERUNG.round} mm", 1, 'Stück', sk) if kb >= KB_STABILISIERUNG - Regeln::TOL
          s = GRUPPEN[1]
          add.(s, 'Spanplattenschraube 4 × 15', 'Fronthalter', 2 * z[:front].size, 'Stück', sk)
          add.(s, 'Spanplattenschraube 4 × 15', 'Boden an Zargen', BODEN_SCHRAUBEN, 'Stück', sk)
          add.(s, SYSTEMSCHRAUBE, 'Korpusschienen (vorgebohrt Ø5)', schienen.size, 'Stück', sk)
        end
      end

      def tueren(teile, add)
        teile.select { |w| w.rolle == 'Tuer' }.each do |t|
          sk = t.teil.jt('schrank')
          baender = t.ops.select { |o| o.art == :topfband }
          next if baender.empty?
          g = GRUPPEN[2]
          eck = baender.count { |o| o.daten && o.daten[:eck] }
          add.(g, 'Blum Topfband Ø35 (CLIP top), mit Einpressdübeln', 'Topf 14 tief, Anschlag lt. TCN', baender.size - eck, 'Stück', sk)
          add.(g, 'Blum Falttür-Scharnier Ø35', 'kurze Tür am Eckscharnier', eck, 'Stück', sk)
          platten = baender.count { |o| o.daten && o.daten[:platte] }
          add.(g, 'Blum Montageplatte (CLIP)', 'Abstand 0, im 32er-Raster', platten, 'Stück', sk)
          add.(g, SYSTEMSCHRAUBE, 'Montageplatten (vorgebohrt Ø5)', 2 * platten, 'Stück', sk)
        end
      end

      def klappen(teile, add)
        teile.select { |w| w.ops.any? { |o| o.titel == 'Frontbeschlag AVENTOS HK-top' } }.each do |kl|
          sk = kl.teil.jt('schrank')
          g = GRUPPEN[3]
          add.(g, 'Blum AVENTOS HK-top Kraftspeicher', 'Leistungsfaktor nach Frontgewicht', 1, 'Paar', sk)
          add.(g, 'Blum AVENTOS HK-top Frontbeschlag', '', 1, 'Paar', sk)
          add.(g, SYSTEMSCHRAUBE, 'Kraftspeicher + Frontbeschlag', kl.ops.count { |o| o.titel == 'Frontbeschlag AVENTOS HK-top' } +
               teile.flat_map(&:ops).count { |o| o.titel == 'Kraftspeicher AVENTOS HK-top' }, 'Stück', sk)
        end
        # Häfele Free Slim (Montageanleitung 732.23.046, S. 1): je Klappe Mechanismus L + R (A), 4 Dübel (G),
        # 8 Schrauben Ø4 × 20 (B) für den Mechanismus, 2 Frontbeschläge (E) mit 8 Schrauben Ø4 × 15 (H)
        teile.select { |w| w.ops.any? { |o| o.titel == 'Frontbeschlag Free Slim' } }.each do |kl|
          sk = kl.teil.jt('schrank')
          g = GRUPPEN[4]
          add.(g, 'Häfele Free Slim flap 1.12 (372.92.xxx), Mechanismus L + R', 'Leistungsfaktor PF = Klappenhöhe × Frontgewicht', 1, 'Paar', sk)
          add.(g, 'Häfele Free Slim Frontbeschlag', '', 1, 'Paar', sk)
          add.(g, 'Häfele Free Slim Dübel', 'Mechanismus (Bohrung Ø5 × 10)',
               teile.flat_map(&:ops).count { |o| o.titel == 'Mechanismus Free Slim' }, 'Stück', sk)
          add.(g, 'Spanplattenschraube 4 × 20', 'Mechanismus', 8, 'Stück', sk)
          add.(g, 'Spanplattenschraube 4 × 15', 'Frontbeschlag (vorgebohrt Ø3)', kl.ops.count { |o| o.titel == 'Frontbeschlag Free Slim' }, 'Stück', sk)
        end
      end

      def csv(posten)
        out = ['Gruppe;Beschlag;Größe/Hinweis;Anzahl;Einheit;Schränke']
        posten.each do |p|
          out << [p.gruppe, p.beschlag, p.hinweis, p.anzahl, p.einheit, p.schraenke.join(', ')].map { |v| v.to_s.tr(';', ',') }.join(';')
        end
        out.join("\r\n") + "\r\n"
      end
    end
  end
end
