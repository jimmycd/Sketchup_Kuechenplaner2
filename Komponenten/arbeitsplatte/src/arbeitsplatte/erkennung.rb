# encoding: UTF-8
#
# Arbeitsplatte – Schrankzeilen und Ecken erkennen
#
# Reine Rechnung ohne SketchUp: arbeitet auf Elementen (Grundriss-Rechtecke der
# Schränke in Weltkoordinaten, mm). Das Einlesen aus dem Modell steht in
# modell.rb.
#
# Element (Hash):
#   kz:        Schrank-Kürzel (USS1, UES1 …)
#   typ:       JT_Schrank typ
#   kategorie: 'Unterschrank' oder 'Hochschrank' (andere werden übergangen)
#   rechteck:  [x0, y0, x1, y1] mit x0 < x1, y0 < y1 (inkl. Fronten)
#   front:     Blickrichtung der Front: :ny (-y), :py (+y), :nx (-x), :px (+x)
#   z0, z1:    Unter- und Oberkante
#
# Eine Zeile ist eine Reihe von Unterschränken mit gleicher Blickrichtung,
# gleicher Oberkante und gleicher Frontlinie. Längs der Zeile läuft die
# Koordinate s (x bei Front ±y, y bei Front ±x), quer dazu liegen Frontlinie
# (front_linie) und Wand (wand, die Rückseite der tiefsten Schränke).
# Eine Ecke verbindet die Enden zweier Zeilen im rechten Winkel.

module Arbeitsplatte
  module Erkennung
    # Standardwerte (mm), alle über optionen änderbar
    OPTIONEN = {
      max_luecke: 650.0,       # Lücke in einer Zeile, die überbrückt wird (Spüler, Unterbaukühlschrank)
      toleranz_front: 5.0,     # Frontlinien, die so nah liegen, gehören zu einer Zeile
      toleranz_hoehe: 1.0,     # Oberkanten, die so nah liegen, gehören zu einer Zeile
      toleranz_ecke: 100.0,    # so weit darf ein Zeilenende von der anderen Zeile entfernt sein (Passleiste)
      toleranz_hochschrank: 30.0 # Abstand Zeilenende – Hochschrank, damit die Zeile dort endet
    }.freeze

    UNTERSCHRANK = 'Unterschrank'.freeze
    HOCHSCHRANK  = 'Hochschrank'.freeze

    # Achse längs der Zeile (0 = x, 1 = y) und Vorzeichen der Front quer dazu
    FRONTEN = { ny: [0, -1], py: [0, 1], nx: [1, -1], px: [1, 1] }.freeze

    def self.laengs(front)
      FRONTEN.fetch(front)[0]
    end

    # Rechteck in Zeilenkoordinaten: [s0, s1, vorn, hinten] (vorn = Frontlinie)
    def self.zeilenmass(el)
      x0, y0, x1, y1 = el[:rechteck]
      achse, vz = FRONTEN.fetch(el[:front])
      s0, s1 = achse.zero? ? [x0, x1] : [y0, y1]
      q0, q1 = achse.zero? ? [y0, y1] : [x0, x1]
      vz < 0 ? [s0, s1, q0, q1] : [s0, s1, q1, q0]
    end

    # Liefert { zeilen:, ecken:, formen:, warnungen: }
    def self.erkenne(elemente, optionen = {})
      o = OPTIONEN.merge(optionen)
      warnungen = []
      unter = elemente.select { |e| e[:kategorie] == UNTERSCHRANK }
      hoch  = elemente.select { |e| e[:kategorie] == HOCHSCHRANK }
      zeilen = zeilen_bilden(unter, o, warnungen)
      zeilen.each { |z| hochschraenke_an_enden(z, hoch, o) }
      ecken = ecken_finden(zeilen, o, warnungen)
      hoehen_pruefen(zeilen, ecken, warnungen)
      { zeilen: zeilen, ecken: ecken, formen: formen(zeilen, ecken), warnungen: warnungen }
    end

    # -------------------------------------------------------------------------
    # Zeilen
    # -------------------------------------------------------------------------
    def self.zeilen_bilden(unter, o, warnungen)
      gruppen = []
      unter.each do |el|
        s0, s1, vorn, hinten = zeilenmass(el)
        g = gruppen.find do |gr|
          gr[:front] == el[:front] && (gr[:z1] - el[:z1]).abs <= o[:toleranz_hoehe] &&
            (gr[:vorn] - vorn).abs <= o[:toleranz_front]
        end
        unless g
          g = { front: el[:front], z1: el[:z1], vorn: vorn, elemente: [] }
          gruppen << g
        end
        g[:elemente] << el.merge(s0: s0, s1: s1, vorn: vorn, hinten: hinten)
      end

      zeilen = []
      gruppen.each do |g|
        lauf = nil
        g[:elemente].sort_by { |e| e[:s0] }.each do |el|
          if lauf && el[:s0] - lauf[:s1] <= o[:max_luecke]
            if el[:s0] < lauf[:s1] - 1.0
              warnungen << "#{el[:kz]} überlappt #{lauf[:elemente].last[:kz]} um #{(lauf[:s1] - el[:s0]).to_f.round(1)} mm"
            elsif el[:s0] > lauf[:s1] + 1.0
              lauf[:luecken] << [lauf[:s1], el[:s0]]
            end
            lauf[:elemente] << el
            lauf[:s1] = [lauf[:s1], el[:s1]].max
          else
            lauf = { front: g[:front], achse: laengs(g[:front]), z: g[:z1], s0: el[:s0], s1: el[:s1],
                     elemente: [el], luecken: [] }
            zeilen << lauf
          end
        end
      end

      zeilen.each do |z|
        vz = FRONTEN[z[:front]][1]
        vorne = z[:elemente].map { |e| e[:vorn] }
        hinten = z[:elemente].map { |e| e[:hinten] }
        # Frontlinie: die am weitesten vorstehende Front; Wand: hinter dem tiefsten Schrank
        z[:front_linie] = vz < 0 ? vorne.min : vorne.max
        z[:wand] = vz < 0 ? hinten.max : hinten.min
        flach = z[:elemente].select { |e| (e[:hinten] - z[:wand]).abs > 1.0 }
        unless flach.empty?
          warnungen << "Zeile #{bezeichnung(z)}: #{flach.map { |e| e[:kz] }.join(', ')} steht nicht an der Wand " \
                       "(#{flach.map { |e| (e[:hinten] - z[:wand]).abs.round(1) }.join(', ')} mm Abstand)"
        end
        z[:enden] = { start: { art: :frei }, ende: { art: :frei } }
      end
      zeilen.sort_by { |z| [z[:achse], z[:front_linie], z[:s0]] }.each_with_index { |z, i| z[:nr] = i + 1 }
    end

    def self.bezeichnung(z)
      "#{z[:elemente].first[:kz]}–#{z[:elemente].last[:kz]}"
    end

    # Hochschrank gleicher Blickrichtung direkt neben einem Zeilenende
    def self.hochschraenke_an_enden(z, hoch, o)
      hoch.select { |h| h[:front] == z[:front] }.each do |h|
        s0, s1, vorn, hinten = zeilenmass(h)
        quer = [[vorn, hinten].min, [vorn, hinten].max]
        next unless z[:front_linie].between?(quer[0] - o[:toleranz_front], quer[1] + o[:toleranz_front]) ||
                    z[:wand].between?(quer[0] - o[:toleranz_front], quer[1] + o[:toleranz_front])
        if (z[:s0] - s1).between?(-1.0, o[:toleranz_hochschrank])
          z[:enden][:start] = { art: :hochschrank, kz: h[:kz], fuge: z[:s0] - s1 }
        elsif (s0 - z[:s1]).between?(-1.0, o[:toleranz_hochschrank])
          z[:enden][:ende] = { art: :hochschrank, kz: h[:kz], fuge: s0 - z[:s1] }
        end
      end
    end

    # -------------------------------------------------------------------------
    # Ecken
    # -------------------------------------------------------------------------
    def self.ecken_finden(zeilen, o, warnungen)
      ecken = []
      zeilen.combination(2).each do |a, b|
        next if a[:achse] == b[:achse]
        a, b = b, a if a[:achse] == 1 # a läuft in x, b in y
        t = o[:toleranz_ecke]
        band_a = [a[:front_linie], a[:wand]].minmax # quer zu a (y)
        band_b = [b[:front_linie], b[:wand]].minmax # quer zu b (x)
        kandidaten = [:start, :ende].product([:start, :ende]).map do |ea, eb|
          xa = ea == :start ? a[:s0] : a[:s1]
          yb = eb == :start ? b[:s0] : b[:s1]
          next unless xa.between?(band_b[0] - t, band_b[1] + t) && yb.between?(band_a[0] - t, band_a[1] + t)
          # In der Ecke reicht ein Ende bis an die Wand der anderen Zeile, das andere bis
          # an deren Front; bei kurzen Zeilen passen mehrere Enden, das beste gewinnt
          guete = [(xa - b[:wand]).abs + (yb - a[:front_linie]).abs,
                   (xa - b[:front_linie]).abs + (yb - a[:wand]).abs].min
          [guete, ea, eb, xa, yb]
        end.compact
        next if kandidaten.empty?
        _, ea, eb, xa, yb = kandidaten.min_by(&:first)
        belegt = [[a, ea], [b, eb]].find { |z, e| z[:enden][e][:art] != :frei }
        if belegt
          warnungen << "Zeile #{bezeichnung(belegt[0])}: Ende hat schon #{belegt[0][:enden][belegt[1]][:art]}, Ecke übergangen"
          next
        end
        # Welche Zeile steht mit ihren Schränken in der Ecke? Die, deren Ende bis an die
        # Wand der anderen reicht.
        a_in_ecke = (xa - b[:wand]).abs <= (yb - a[:wand]).abs
        ecke = { zeilen: [a[:nr], b[:nr]], enden: { a[:nr] => ea, b[:nr] => eb },
                 innen: [b[:front_linie], a[:front_linie]], aussen: [b[:wand], a[:wand]],
                 schraenke_in_ecke: a_in_ecke ? a[:nr] : b[:nr] }
        frei_z, frei_e, frei_s = a_in_ecke ? [b, eb, yb] : [a, ea, xa]
        voll_z = a_in_ecke ? a : b
        ecke[:passleiste] = (frei_s - voll_z[:front_linie]).abs.round(1)
        eckel = voll_z[:elemente].send(ecke[:enden][voll_z[:nr]] == :start ? :first : :last)
        ecke[:eckschrank] = eckel[:kz] if eckel[:typ] == 'Eckschrank'
        frei_el = frei_z[:elemente].send(frei_e == :start ? :first : :last)
        ecke[:eckschrank] ||= frei_el[:kz] if frei_el[:typ] == 'Eckschrank'
        a[:enden][ea] = { art: :ecke, ecke: ecken.size + 1 }
        b[:enden][eb] = { art: :ecke, ecke: ecken.size + 1 }
        ecke[:nr] = ecken.size + 1
        ecken << ecke
      end
      ecken
    end

    def self.hoehen_pruefen(zeilen, ecken, warnungen)
      ecken.each do |e|
        a, b = e[:zeilen].map { |nr| zeilen.find { |z| z[:nr] == nr } }
        next if (a[:z] - b[:z]).abs <= 1.0
        warnungen << "Ecke #{e[:nr]}: Oberkanten unterschiedlich (#{a[:z].round(1)} / #{b[:z].round(1)} mm)"
      end
    end

    # Zusammenhängende Zeilen (über Ecken) und ihre Form: I, L, U oder mehr
    def self.formen(zeilen, ecken)
      offen = zeilen.map { |z| z[:nr] }
      formen = []
      until offen.empty?
        gruppe = [offen.shift]
        loop do
          neu = ecken.flat_map { |e| e[:zeilen] }.uniq.select do |nr|
            !gruppe.include?(nr) && ecken.any? { |e| e[:zeilen].include?(nr) && (e[:zeilen] & gruppe).any? }
          end
          break if neu.empty?
          gruppe.concat(neu)
          offen -= neu
        end
        n = ecken.count { |e| (e[:zeilen] & gruppe).any? }
        form = case n
               when 0 then 'I'
               when 1 then 'L'
               when 2 then gruppe.size == 3 ? 'U' : 'mehrere Ecken'
               else 'mehrere Ecken'
               end
        formen << { form: form, zeilen: gruppe.sort }
      end
      formen
    end

    # Kurzer Text für die Meldung in SketchUp
    def self.zusammenfassung(erg)
      return 'Keine Unterschränke gefunden.' if erg[:zeilen].empty?
      zeilen = erg[:zeilen].map do |z|
        enden = z[:enden].map do |_, e|
          case e[:art]
          when :ecke then "Ecke #{e[:ecke]}"
          when :hochschrank then "Hochschrank #{e[:kz]}"
          else 'frei'
          end
        end
        luecken = z[:luecken].empty? ? '' : ", Lücken #{z[:luecken].map { |l0, l1| (l1 - l0).round }.join('/')} mm"
        "Zeile #{z[:nr]}: #{z[:elemente].map { |e| e[:kz] }.uniq.join(' ')} · Länge #{(z[:s1] - z[:s0]).round} mm, " \
          "Tiefe #{(z[:wand] - z[:front_linie]).abs.round} mm · Enden: #{enden.join(' / ')}#{luecken}"
      end
      ecken = erg[:ecken].map do |e|
        "Ecke #{e[:nr]}: Zeile #{e[:zeilen].join(' + ')}#{e[:eckschrank] ? ", Eckschrank #{e[:eckschrank]}" : ''}" \
          "#{e[:passleiste] > 1 ? ", Passleiste #{e[:passleiste].round} mm" : ''}"
      end
      formen = erg[:formen].map { |f| f[:form] == 'I' ? 'gerade' : "#{f[:form]}-Form" }
      (["Küche: #{formen.join(', ')}"] + zeilen + ecken + erg[:warnungen].map { |w| "Achtung: #{w}" }).join("\n")
    end
  end
end
