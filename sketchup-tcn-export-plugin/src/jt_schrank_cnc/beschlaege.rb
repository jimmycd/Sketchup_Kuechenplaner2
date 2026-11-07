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
          oeffnung(teile, add)
        end
        # SERVO-DRIVE: Netzteil, Halterung und Verteilerkabel einmal für die ganze Küche
        o = Beschlagkatalog.gewaehlt('oeffnung')
        if o['servo'] && sammler.values.any? { |p| p.gruppe == o['liste']['gruppe'] }
          o['servo']['kueche'].each { |name, hinweis, a, einheit| add.(o['liste']['gruppe'], name, hinweis, a, einheit, nil) }
        end
        # je Gruppe nach Beschlagart (Zargen, Schienen, Halter …), dann Größe
        sammler.values.each_with_index.sort_by do |p, i|
          [GRUPPEN.index(p.gruppe) || 9, REIHENFOLGE.index { |r| p.beschlag.start_with?(r) } || 99, p.beschlag, p.hinweis.to_s, i]
        end.map(&:first)
      end

      GRUPPEN = ['Schubladen (LEGRABOX free)', 'Schubladen (LEGRABOX pure)', 'Schubladen (MERIVOBOX)', 'Schubladen (TANDEMBOX antaro)', 'Schrauben Schubladen', 'Türen (Topfbänder)', 'Klappen (AVENTOS)',
                 'Klappen (Häfele Free Slim)', 'Hochauszug (HU Slim Base)', 'Eckauszug (LeMans II)',
                 'Öffnung grifflos (TIP-ON)', 'Öffnung grifflos (SERVO-DRIVE)'].freeze
      REIHENFOLGE = ['Zargen', 'Korpusschienen', 'Rückwandhalter', 'Fronthalter', 'Seiteneinsatz', 'Seitenstabilisierung',
                     'Häfele Free Slim', 'Spanplattenschraube', 'Blum Topfband', 'Blum 155°', 'Blum 170°', 'Blum Eckschrank-Falttür', 'Blum Montageplatte', 'Blum AVENTOS HK-top Kraft',
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
          # Schmaler Schrank (Blum SPACE TWIN, KB 185–250): diagonal versetzte Korpusschienen, 20 kg
          tw = e['space_twin']
          if tw && kb.round.between?(tw['kb'][0], tw['kb'][1])
            hinweis = "#{nl_text}, #{tw['kg']} kg, Korpusbreite #{kb.round} mm"
            hinweis += ", Zarge #{m} bei SPACE TWIN nicht vorgesehen (#{tw['zargen'].join('/')})" unless tw['zargen'].include?(m.to_s)
            add.(g, tw['schienen'], hinweis, 1, 'Paar', sk)
          else
            kg = (nl && ax[:schiene][:kg_nl][nl]) || ax[:schiene][:kg]
            tob = grifflos?(kasten, teile) && Beschlagkatalog.gewaehlt('oeffnung')['schublade'] == 'tip_on_blumotion' && e['tip_on_blumotion']
            add.(g, 'Korpusschienen', "#{nl_text}, #{kg} kg#{tob ? ", #{tob['schiene_hinweis']}" : ''}", 1, 'Paar', sk)
          end
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

      # Schublade mit grifflos zu öffnender Front (nicht hinter einer Tür: Innenfront)
      def grifflos?(kasten, teile)
        f = Regeln.front_zu(kasten, teile)
        !f.nil? && f.rolle == 'Front'
      end

      # Grifflose Öffnung (Beschlagart „oeffnung“): TIP-ON an Türen (Anzahl je Version, Adapterplatten
      # mit Bohrungen), Schubladen TIP-ON BLUMOTION (Set nach NL und Schiene, Synchronisierung nach LW,
      # Werte im Schubladenauszug) oder SERVO-DRIVE (Antrieb je Auszug, Trägerprofil je Schrank),
      # Klappen nach liste.klappe
      def oeffnung(teile, add)
        o = Beschlagkatalog.gewaehlt('oeffnung')
        return unless o['tuer'] || o['schublade']
        g = o['liste']['gruppe']
        sk = teile.first.teil.jt('schrank')
        if o['tuer']
          tueren = Regeln.tip_on_tueren(teile)
          tu = o['tuer']
          loecher = teile.flat_map(&:ops).select { |x| x.titel == tu['titel'] && x.daten }
          tueren.each do |t|
            l = loecher.select { |x| x.daten[:tuer] == t.name }
            if l.any? { |x| x.daten[:kreuz] }
              add.(g, tu['kreuz']['name'], 'Doppeltür, im Boden', 1, 'Stück', sk)
              add.(g, tu['kreuz']['platte'], 'Boden an der Öffnungskante, vorgebohrt', 1, 'Stück', sk)
            else
              v = Regeln.tip_on_version(o, t)
              add.(g, v['name'], "Tür bis #{v['bis']} mm hoch", 1, 'Stück', sk)
              add.(g, v['platte'], l.empty? ? 'von Hand setzen' : 'Seite an der Öffnungskante, vorgebohrt', 1, 'Stück', sk)
            end
            add.(g, 'Systemschraube Ø5', 'Adapterplatte TIP-ON', 2, 'Stück', sk) unless l.empty?
          end
          o['liste']['tuer'].each do |name, hinweis, a, einheit|
            add.(g, name, hinweis, a == 'tueren' ? tueren.size : a, einheit, sk)
          end
        end
        kl = Beschlagkatalog.eintraege.select { |e| %w[klappe_seite faltklappe_seite].include?(e['bauart']) }
        klappen = teile.count { |w| kl.any? { |e| w.ops.any? { |x| x.titel == e['front']['titel'] } } }
        o['liste']['klappe'].each { |name, hinweis, a, einheit| add.(g, name, hinweis, a * klappen, einheit, sk) }
        kaesten = Regeln.kaesten(teile).select { |k| k.any? { |w| w.rolle == 'KastenBoden' } && grifflos?(k, teile) }
        return if kaesten.empty?
        ax = Regeln.auszug
        e = Beschlagkatalog.gewaehlt('schubladen')
        kaesten.each do |kasten|
          boden = kasten.find { |w| w.rolle == 'KastenBoden' }
          bereich = boden.teil.jt('bereich')
          nl = teile.flat_map(&:ops).select { |x| x.titel == "Schiene #{bereich}" && x.daten }.map { |x| x.daten[:nl] }.compact.max
          kg = (nl && ax[:schiene][:kg_nl][nl]) || ax[:schiene][:kg]
          lw = (boden.mass(Regeln.breite_achse(kasten)) + ax[:kasten][:boden_b]).round
          case o['schublade']
          when 'tip_on_blumotion'
            tob = e['tip_on_blumotion']
            unless tob
              add.(g, 'TIP-ON BLUMOTION', "für #{e['name']} nicht im Katalog", 1, 'Auszug', sk)
              next
            end
            set = tob['sets'].find { |x| x['kg'] == kg && nl && nl <= x['nl_bis'] }
            add.(g, set ? set['name'] : 'Blum TIP-ON BLUMOTION-Set', set ? set['hinweis'] : "NL #{nl || '?'}, #{kg} kg: Set nach Katalog wählen", 1, 'Stück', sk)
            sy = tob['sync'].find { |x| lw.between?(x['lw_ab'], x['lw_bis']) }
            if sy
              add.(g, sy['name'], sy['abzug'] ? "Zuschnitt #{lw - sy['abzug']} mm (LW #{lw} − #{sy['abzug']})" : "LW #{lw}, Zuschnitt nach Blum-Katalog", 1, 'Stück', sk)
            end
          when 'servo_drive'
            f = Regeln.front_zu(kasten, teile)
            fh = f ? f.mass(2) : 0
            puffer = fh <= 300 + Regeln::TOL && kg < 70 ? 2 : 4
            o['servo']['schublade'].each do |name, hinweis, a, einheit|
              add.(g, name, hinweis, a == 'puffer' ? puffer : a, einheit, sk)
            end
          end
        end
        return unless o['schublade'] == 'servo_drive'
        seiten = teile.select { |w| w.rolle == 'Seite' }
        return if seiten.empty?
        unten = teile.select { |w| w.rolle == 'Boden' }.map { |w| w.hi[2] }.max || seiten.map { |w| w.lo[2] }.min
        oben = teile.select { |w| Regeln::FESTE_BOEDEN.include?(w.rolle) && w.lo[2] > unten + Regeln::TOL }.map { |w| w.lo[2] }.min ||
               seiten.map { |w| w.hi[2] }.max
        pl = (((oben - unten) - o['servo']['abzug_lh']) / 10.0).floor * 10
        profil = o['servo']['profile'].find { |x| x >= pl } || o['servo']['profile'].last
        o['servo']['schrank'].each do |name, hinweis, a, einheit|
          add.(g, name, hinweis.sub('{profil}', "#{profil} mm, Zuschnitt #{pl} mm (LH − #{o['servo']['abzug_lh']})"), a.to_i, einheit, sk)
        end
      end

      # Türen: Posten aus dem Beschlag-Katalog (Modell am Topfband); Anzahl „baender“ (ohne Eckscharnier),
      # „eck“ (alte Falttür-Lesart, heute 0), „platten“ (Bänder mit Montageplatte), „platten_loecher“ (2 je Platte)
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
          # Falttür (Eckschrank L): Eckschrank-Falttürscharniere am Topf in der langen Tür, Montageplatte
          # mit 2 Schrauben auf der kurzen Tür
          t.ops.select { |o| o.titel == 'Falttürscharnier Topf' }.group_by { |o| o.daten && o.daten[:modell] }.each do |kennung, toepfe|
            e = Beschlagkatalog.eintrag(kennung) || Beschlagkatalog.gewaehlt('falttuer')
            n = { 'anzahl' => toepfe.size, 'loecher' => 2 * toepfe.size }
            e['liste']['posten'].each do |name, hinweis, anzahl, einheit|
              add.(e['liste']['gruppe'], name, hinweis, anzahl.is_a?(String) ? n.fetch(anzahl) : anzahl, einheit, sk)
            end
          end
        end
      end

      # Klappen: Posten aus dem Beschlag-Katalog (liste.posten = [Beschlag, Hinweis, Anzahl, Einheit]);
      # Anzahl „loecher_seite“ / „loecher_front“ / „loecher“ = gezählte Bohrungen des Modells
      def klappen(teile, add)
        katalog = Beschlagkatalog.eintraege.select { |e| %w[klappe_seite faltklappe_seite].include?(e['bauart']) }
        teile.each do |kl|
          e = katalog.find { |x| kl.ops.any? { |o| o.titel == x['front']['titel'] } } or next
          sk = kl.teil.jt('schrank')
          n = {
            'loecher_front' => kl.ops.count { |o| o.titel == e['front']['titel'] },
            'loecher_seite' => teile.flat_map(&:ops).count { |o| o.titel == e['seite']['titel'] }
          }
          # Faltklappe: Montageplatten (Deckel, obere Klappe) zählen bei den Schrauben mit
          n['loecher'] = n['loecher_front'] + n['loecher_seite'] +
                         (e['platte'] ? teile.flat_map(&:ops).count { |o| o.titel == e['platte']['titel'] } : 0)
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
