# encoding: UTF-8
# Schrank-CNC – Beschlagliste (eigene Seite in der Stückliste).
#
# Wird aus denselben Werkstücken wie der TCN-Export berechnet (nach Regeln.anwenden), damit
# Bohrbilder und Beschläge zusammenpassen:
#   Schubladen  gewählter Schubladenauszug (Katalog, Standard Blum LEGRABOX free, Montageanleitung MD-015/4): Zargen N, M, K, C oder F (Regeln.zarge),
#               Korpusschienen je Nennlänge (40 kg, NL 650 70 kg), Rückwand- und Fronthalter,
#               Seiteneinsätze (S. 4: C 138 / M 52, F/K abgeleitet, × NL − 112 × 10), Seitenstabilisierung ab KB 600 (S. 9),
#               Schrauben 4 × 15 für Fronthalter und Boden (S. 5), Systemschrauben für die Schienen.
#   Türen       Blum-Topfbänder Ø35 mit Montageplatte (Regeln.topfbaender), Systemschrauben dafür.
#   Klappen     gewähltes Modell aus dem Beschlag-Katalog (katalog/*.json, Posten unter liste).
#   Hoch-/Eckauszug  HU Slim Base bzw. LeMans II aus dem Katalog (Satz und Schrauben).
# Blum-Artikelnummern stehen nicht in der Anleitung; die Liste nennt deshalb Typ, Größe und Anzahl.

module JTools
  module SchrankCnc
    module Beschlaege
      module_function

      Posten = Struct.new(:gruppe, :beschlag, :hinweis, :anzahl, :einheit, :schraenke)

      # Schubladen: Werte aus dem Katalog (Schubladenauszug der Küche): Tragkraft je Nennlänge
      # (LEGRABOX NL 650 nur 70 kg, S. 3), Seitenstabilisierung ab Korpusbreite (600, S. 9),
      # Schrauben 4 × 15 für den Boden (je Seite 4, S. 5, Bild 4)

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
          auszuege(teile, add)
        end
        # je Gruppe nach Beschlagart (Zargen, Schienen, Halter …), dann Größe
        sammler.values.each_with_index.sort_by do |p, i|
          [GRUPPEN.index(p.gruppe) || 9, REIHENFOLGE.index { |r| p.beschlag.start_with?(r) } || 99, p.beschlag, p.hinweis.to_s, i]
        end.map(&:first)
      end

      GRUPPEN = ['Schubladen (LEGRABOX free)', 'Schrauben Schubladen', 'Türen (Topfbänder)', 'Klappen (AVENTOS)',
                 'Klappen (Häfele Free Slim)', 'Hochauszug (HU Slim Base)', 'Eckauszug (LeMans II)'].freeze
      REIHENFOLGE = ['Zargen', 'Korpusschienen', 'Rückwandhalter', 'Fronthalter', 'Seiteneinsatz', 'Seitenstabilisierung',
                     'Häfele Free Slim', 'Spanplattenschraube', 'Blum Topfband', 'Blum Falttür', 'Blum Montageplatte', 'Blum AVENTOS HK-top Kraft',
                     'Blum AVENTOS HK-top Front', 'Systemschraube'].freeze

      def schubladen(teile, add)
        Regeln.kaesten(teile).each do |kasten|
          boden = kasten.find { |w| w.rolle == 'KastenBoden' } or next
          sk = boden.teil.jt('schrank')
          bereich = boden.teil.jt('bereich')
          m = Regeln.zarge(kasten)
          ax = Regeln.auszug
          e = Beschlagkatalog.gewaehlt('schubladen')
          li = e['liste']
          z = ax[:zargen][m]
          schienen = teile.flat_map(&:ops).select { |o| o.titel == "Schiene #{bereich}" && o.daten }
          nl = schienen.map { |o| o.daten[:nl] }.compact.max
          wa = Regeln.breite_achse(kasten)
          lw = boden.mass(wa) + ax[:kasten][:boden_b]
          seite = teile.find { |w| w.rolle == 'Seite' && w.dicke_achse == wa }
          kb = lw + 2 * (seite ? seite.mass(wa) : 19.0)
          g = li['gruppe']
          nl_text = nl ? "NL #{nl}" : 'NL ? (zu wenig Tiefe)'
          add.(g, "Zargen #{m} (#{Tcn.n(z[:hoehe]).tr('.', ',')} mm), links + rechts", nl_text, 1, 'Paar', sk)
          add.(g, 'Korpusschienen', "#{nl_text}, #{(nl && ax[:schiene][:kg_nl][nl]) || ax[:schiene][:kg]} kg", 1, 'Paar', sk)
          add.(g, "Rückwandhalter Holzrückwand #{m}", "Holzrückwand #{Tcn.n(z[:rueckwand])} mm hoch", 1, 'Paar', sk)
          add.(g, "Fronthalter #{m}", 'Frontbefestigung links + rechts', 1, 'Paar', sk)
          if z[:einsatz] # Zarge N: kein Seiteneinsatz
            ab = ax[:kasten][:einsatz_abzug]
            add.(g, li['einsatz'], nl ? "#{z[:einsatz]} × #{nl - ab} mm" : "#{z[:einsatz]} × (NL − #{ab}) mm", 2, 'Stück', sk)
          end
          stab = ax[:stabilisierung_ab]
          add.(g, 'Seitenstabilisierung', "Korpusbreite ab #{stab.round} mm", 1, 'Stück', sk) if kb >= stab - Regeln::TOL
          s = li['gruppe_schrauben']
          add.(s, li['schraube_front'], 'Fronthalter', 2 * z[:front].size, 'Stück', sk)
          add.(s, li['schraube_boden'], 'Boden an Zargen', li['boden_schrauben'], 'Stück', sk)
          add.(s, li['systemschraube'], "Korpusschienen (vorgebohrt Ø#{ax[:schiene][:d]})", schienen.size, 'Stück', sk)
        end
      end

      # Türen: Posten aus dem Beschlag-Katalog (Modell am Topfband); Anzahl „baender“ (ohne Eckscharnier),
      # „eck“, „platten“ (Bänder mit Montageplatte), „platten_loecher“ (2 je Platte)
      def tueren(teile, add)
        teile.select { |w| w.rolle == 'Tuer' }.each do |t|
          sk = t.teil.jt('schrank')
          t.ops.select { |o| o.art == :topfband }.group_by { |o| o.daten && o.daten[:modell] }.each do |kennung, baender|
            e = Beschlagkatalog.eintrag(kennung) || Beschlagkatalog.gewaehlt('topfband')
            eck = baender.count { |o| o.daten && o.daten[:eck] }
            platten = baender.count { |o| o.daten && o.daten[:platte] }
            n = { 'baender' => baender.size - eck, 'eck' => eck, 'platten' => platten, 'platten_loecher' => 2 * platten }
            e['liste']['posten'].each do |name, hinweis, anzahl, einheit|
              add.(e['liste']['gruppe'], name, hinweis, anzahl.is_a?(String) ? n.fetch(anzahl) : anzahl, einheit, sk)
            end
          end
        end
      end

      # Klappen: Posten aus dem Beschlag-Katalog (liste.posten = [Beschlag, Hinweis, Anzahl, Einheit]);
      # Anzahl „loecher_seite“ / „loecher_front“ / „loecher“ = gezählte Bohrungen des Modells
      def klappen(teile, add)
        katalog = Beschlagkatalog.eintraege.select { |e| e['bauart'] == 'klappe_seite' }
        teile.each do |kl|
          e = katalog.find { |x| kl.ops.any? { |o| o.titel == x['front']['titel'] } } or next
          sk = kl.teil.jt('schrank')
          n = {
            'loecher_front' => kl.ops.count { |o| o.titel == e['front']['titel'] },
            'loecher_seite' => teile.flat_map(&:ops).count { |o| o.titel == e['seite']['titel'] }
          }
          n['loecher'] = n['loecher_front'] + n['loecher_seite']
          e['liste']['posten'].each do |name, hinweis, anzahl, einheit|
            add.(e['liste']['gruppe'], name, hinweis, anzahl.is_a?(String) ? n.fetch(anzahl) : anzahl, einheit, sk)
          end
        end
      end

      # Hochauszug und Eckauszug: Posten aus dem Katalogeintrag der Küche; Anzahl „loecher“ (HU: Schiene
      # und Front), „profil_lager“ (LeMans: Seitenprofil und Säulenlager), „lager_schrauben“; im Namen
      # steht {groesse} für die LeMans-Größe des Schranks
      def auszuege(teile, add)
        return if teile.empty?
        ops = teile.flat_map(&:ops)
        anzahl = ->(*titel) { ops.count { |o| titel.include?(o.titel) } }
        if Regeln.hu_slim_base?(teile)
          e = Beschlagkatalog.gewaehlt('hochauszug')
          n = { 'loecher' => anzahl.(e['schiene']['titel'], e['front']['titel']) }
        elsif Regeln.lemans?(teile)
          e = Beschlagkatalog.gewaehlt('eckauszug')
          n = { 'profil_lager' => anzahl.(e['profil']['titel'], e['lager']['titel']), 'lager_schrauben' => anzahl.(e['lager_schraube']['titel']) }
          groesse = Schraenke.dc(teile.first.teil.schrank, 'lemans').to_f.round
        else
          return
        end
        return if n.values.sum.zero?
        sk = teile.first.teil.jt('schrank')
        e['liste']['posten'].each do |name, hinweis, a, einheit|
          add.(e['liste']['gruppe'], name.sub('{groesse}', groesse.to_s).strip, hinweis, a.is_a?(String) ? n.fetch(a) : a, einheit, sk)
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
