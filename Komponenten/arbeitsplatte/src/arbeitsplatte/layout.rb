# encoding: UTF-8
#
# Arbeitsplatte – Platten aus den erkannten Zeilen und Ecken zuschneiden
#
# Reine Rechnung ohne SketchUp, alle Maße in mm, Weltkoordinaten. Eingabe ist das
# Ergebnis von Erkennung.erkenne.
#
# Je Zeile eine Platte (bei Überlänge mehrere mit Längsstoß). Tiefe: von der Wand
# (minus Wandabstand) bis vor die Fronten (plus Überstand vorn). Enden:
#   frei         Überstand seitlich
#   Hochschrank  Fuge zum Hochschrank
#   Ecke         die durchlaufende Platte geht bis an die Wand der anderen Zeile,
#                die anstoßende endet am Stoß
#
# Stoßarten in der Ecke (Pfad vom inneren Eckpunkt der Vorderkanten zur Wand):
#   gehrungsansatz  Standard: kurze 45° über die Vorderkante (Gehrungstiefe g), dann
#                   gerade zur Wand; der Übergang ist ein Bogen mit Radius R. Die
#                   durchlaufende Platte bekommt die weibliche Fräsung, die anstoßende
#                   ragt um g in sie hinein (männlich).
#   stumpf          gerade an der Vorderkante der durchlaufenden Platte
#   gehrung         45° vom inneren zum äußeren Eckpunkt
#
# Platte (Hash): nr, zeile, punkte (Umriss gegen den Uhrzeigersinn), kanten (Art
# jeder Kante punkte[i] -> punkte[i+1]: :vorne, :wand, :frei, :hochschrank, :stoss),
# z (Unterkante), staerke, laenge, breite, format [Länge, Breite].
# Stoß (Hash): nr, art, ecke, platten [durchlaufend/links, anstoßend/rechts],
# pfad [[:linie, p0, p1] | [:bogen, p0, p1, mitte, r]] vom inneren Eckpunkt zur Wand.

module Arbeitsplatte
  module Layout
    STANDARDFORMATE = [[4100.0, 600.0], [4100.0, 650.0], [4100.0, 900.0], [4100.0, 1200.0]].freeze
    STAERKE = { schichtstoff: 38.0, massivholz: 40.0 }.freeze
    STOSSARTEN = %i[gehrungsansatz stumpf gehrung].freeze

    OPTIONEN = {
      art: :schichtstoff,        # :schichtstoff (Anleimer ab Werk) oder :massivholz
      staerke: nil,              # nil = Standard der Art
      ueberstand_vorn: 20.0,     # vor der Frontlinie
      ueberstand_seite: 0.0,     # an freien Enden
      wandabstand: 5.0,          # Luft zur Wand
      fuge_hochschrank: 2.0,     # Fuge zum Hochschrank
      stoss: :gehrungsansatz,    # Standard für alle Ecken
      gehrungstiefe: 30.0,       # Gehrungsansatz: Tiefe der 45° in die durchlaufende Platte
      radius: 30.0,              # Gehrungsansatz: Bogen zwischen 45° und geradem Schnitt
      bogen_teile: 8,            # Bogen im Umriss als so viele gerade Stücke
      formate: STANDARDFORMATE,  # Auswahl, die schmalste passende gewinnt
      format: nil,               # festes Format [Länge, Breite] statt Auswahl
      besaeumen: 10.0,           # je Plattenende vom Rohformat ab
      min_stueck: 300.0,         # kürzestes Stück beim Teilen
      ecken: {}                  # je Ecke: { nr => { stoss:, durchlaufend: Zeilennummer } }
    }.freeze

    # -------------------------------------------------------------------------
    # Koordinaten einer Zeile: s längs, q quer (Weltachsen)
    # -------------------------------------------------------------------------
    def self.achse(z)
      z[:achse]
    end

    def self.vz(z)
      Erkennung::FRONTEN.fetch(z[:front])[1]
    end

    def self.pt(z, s, q)
      achse(z).zero? ? [s.to_f, q.to_f] : [q.to_f, s.to_f]
    end

    # Plattenvorderkante und -hinterkante quer zur Zeile
    def self.q_vorn(z, o)
      z[:front_linie] + vz(z) * o[:ueberstand_vorn]
    end

    def self.q_wand(z, o)
      z[:wand] + vz(z) * o[:wandabstand]
    end

    def self.einheit(v)
      l = Math.sqrt(v[0]**2 + v[1]**2)
      [v[0] / l, v[1] / l]
    end

    def self.plus(a, b, f = 1.0)
      [a[0] + b[0] * f, a[1] + b[1] * f]
    end

    def self.minus(a, b)
      [a[0] - b[0], a[1] - b[1]]
    end

    def self.flaeche(punkte)
      punkte.each_with_index.sum do |p, i|
        q = punkte[(i + 1) % punkte.size]
        p[0] * q[1] - q[0] * p[1]
      end / 2.0
    end

    # -------------------------------------------------------------------------
    # Ecken: welche Platte läuft durch, Stoßpfad
    # -------------------------------------------------------------------------
    # Länge der Zeile mit Überständen, ohne Ecken (für die Wahl der durchlaufenden)
    def self.roh_laenge(z)
      z[:s1] - z[:s0]
    end

    # Standard: die längere Zeile läuft durch (Zeilennummer)
    def self.standard_durchlaufend(a, b)
      roh_laenge(a) >= roh_laenge(b) ? a[:nr] : b[:nr]
    end

    def self.ecken_planen(erg, o, warnungen)
      zeilen = erg[:zeilen]
      erg[:ecken].map do |e|
        a, b = e[:zeilen].map { |nr| zeilen.find { |z| z[:nr] == nr } }
        eo = o[:ecken][e[:nr]] || {}
        art = (eo[:stoss] || o[:stoss]).to_sym
        raise ArgumentError, "Stoßart #{art} unbekannt (#{STOSSARTEN.join(', ')})" unless STOSSARTEN.include?(art)
        durch_nr = eo[:durchlaufend] || standard_durchlaufend(a, b)
        durch, anst = durch_nr == a[:nr] ? [a, b] : [b, a]
        { nr: e[:nr], art: art, durch: durch, anst: anst,
          ende_durch: e[:enden][durch[:nr]], ende_anst: e[:enden][anst[:nr]] }.tap do |k|
          k[:pfad], k[:w] = stosspfad(k, o, warnungen)
        end
      end
    end

    # Pfad vom inneren Eckpunkt P (Vorderkanten) bis zur Wandlinie der anstoßenden
    # Platte; liefert [pfad, Endpunkt an der Wand]
    def self.stosspfad(k, o, warnungen)
      d, a = k[:durch], k[:anst]
      p_in = pt(d, q_vorn(a, o), q_vorn(d, o))
      case k[:art]
      when :stumpf
        w = pt(d, q_wand(a, o), q_vorn(d, o))
        [[[:linie, p_in, w]], w]
      when :gehrung
        w = pt(d, q_wand(a, o), q_wand(d, o))
        [[[:linie, p_in, w]], w]
      else
        g = o[:gehrungstiefe]
        m = pt(d, q_vorn(a, o) - vz(a) * g, q_vorn(d, o) - vz(d) * g)
        w = pt(d, q_wand(a, o), q_vorn(d, o) - vz(d) * g)
        [bogen_pfad(p_in, m, w, o, warnungen, k[:nr]), w]
      end
    end

    # Gerade p -> m, Bogen mit Radius r um die Ecke m, gerade weiter nach w
    def self.bogen_pfad(p, m, w, o, warnungen, nr)
      r = o[:radius].to_f
      return [[:linie, p, m], [:linie, m, w]] if r <= 0
      d1 = einheit(minus(m, p))
      d2 = einheit(minus(w, m))
      cos = (d1[0] * d2[0] + d1[1] * d2[1]).clamp(-1.0, 1.0)
      phi = Math.acos(cos) # Ablenkung, beim Gehrungsansatz 45°
      tl = r * Math.tan(phi / 2)
      l1 = Math.sqrt(minus(m, p).sum { |v| v**2 })
      l2 = Math.sqrt(minus(w, m).sum { |v| v**2 })
      if tl > l1 || tl > l2
        warnungen << "Ecke #{nr}: Radius #{r.round(1)} mm passt nicht in den Gehrungsansatz, Ecke ohne Bogen"
        return [[:linie, p, m], [:linie, m, w]]
      end
      t1 = plus(m, d1, -tl)
      t2 = plus(m, d2, tl)
      links = d1[0] * d2[1] - d1[1] * d2[0] > 0
      nrm = links ? [-d1[1], d1[0]] : [d1[1], -d1[0]]
      mitte = plus(t1, nrm, r)
      [[:linie, p, t1], [:bogen, t1, t2, mitte, r], [:linie, t2, w]]
    end

    # Punkte eines Pfads (Bogen in gerade Stücke geteilt), ohne den Startpunkt
    def self.pfad_punkte(pfad, o)
      pfad.flat_map do |seg|
        next [seg[2]] if seg[0] == :linie
        _, p0, p1, c, r = seg
        a0 = Math.atan2(p0[1] - c[1], p0[0] - c[0])
        a1 = Math.atan2(p1[1] - c[1], p1[0] - c[0])
        da = a1 - a0
        da -= 2 * Math::PI while da > Math::PI
        da += 2 * Math::PI while da < -Math::PI
        n = o[:bogen_teile]
        (1..n).map { |i| [c[0] + r * Math.cos(a0 + da * i / n), c[1] + r * Math.sin(a0 + da * i / n)] }
      end
    end

    # -------------------------------------------------------------------------
    # Enden einer Zeile: s-Lage und Kette von der Vorderkante zur Hinterkante
    # -------------------------------------------------------------------------
    # Kette [[punkt, art der Kante zum nächsten Punkt], …] von vorn nach hinten
    def self.endkette(z, seite, o, ecken)
      e = z[:enden][seite]
      qv, qw = q_vorn(z, o), q_wand(z, o)
      aussen = seite == :start ? -1 : 1
      gerade = lambda do |s, art|
        [[pt(z, s, qv), art], [pt(z, s, qw), nil]]
      end
      case e[:art]
      when :ecke
        k = ecken.find { |x| x[:nr] == e[:ecke] }
        pfad_pt = [k[:pfad][0][1]] + pfad_punkte(k[:pfad], o)
        kette = pfad_pt.each_with_index.map { |p, i| [p, i < pfad_pt.size - 1 ? :stoss : nil] }
        if k[:durch][:nr] == z[:nr]
          # weiter an der Wand der anderen Zeile bis in die Ecke
          ecke = pt(z, q_wand(k[:anst], o), qw)
          kette[-1][1] = :wand
          kette << [ecke, nil]
        end
        kette
      when :hochschrank
        s = seite == :start ? z[:s0] - e[:fuge] + o[:fuge_hochschrank] : z[:s1] + e[:fuge] - o[:fuge_hochschrank]
        gerade.(s, :hochschrank)
      when :laengs
        gerade.(e[:s], :stoss)
      else
        gerade.((seite == :start ? z[:s0] : z[:s1]) + aussen * o[:ueberstand_seite], :frei)
      end
    end

    # äußerste s-Lage eines Endes (für Länge und Teilung)
    def self.end_s(z, seite, o, ecken)
      kette = endkette(z, seite, o, ecken)
      ss = kette.map { |p, _| achse(z).zero? ? p[0] : p[1] }
      seite == :start ? ss.min : ss.max
    end

    # -------------------------------------------------------------------------
    # Teilen bei Überlänge: Stoß über einer Schrankseite
    # -------------------------------------------------------------------------
    def self.teilungen(z, s_a, s_e, nutzbar, o, warnungen)
      grenzen = z[:elemente].flat_map { |e| [e[:s0], e[:s1]] }.uniq.sort
      schnitte = []
      cur = s_a
      while s_e - cur > nutzbar
        kand = grenzen.select { |g| g > cur + o[:min_stueck] && g <= cur + nutzbar && g < s_e - o[:min_stueck] }
        s = kand.max
        unless s
          s = cur + nutzbar
          warnungen << "Zeile #{z[:nr]}: Längsstoß bei #{s.round} mm liegt nicht über einer Schrankseite"
        end
        schnitte << s
        cur = s
      end
      schnitte
    end

    # -------------------------------------------------------------------------
    # Platten
    # -------------------------------------------------------------------------
    # Umriss: Endkette (vorn -> hinten), Hinterkante, Anfangskette rückwärts, Vorderkante
    def self.umriss(z, start, ende, o, ecken)
      zs = z.merge(enden: { start: start, ende: ende })
      e = endkette(zs, :ende, o, ecken)
      a = endkette(zs, :start, o, ecken)
      punkte = e.map(&:first) + a.map(&:first).reverse
      kanten = e[0..-2].map(&:last) + [:wand] + a[0..-2].map(&:last).reverse + [:vorne]
      bereinigen(punkte, kanten)
    end

    # doppelte Punkte entfernen, Umlauf gegen den Uhrzeigersinn
    def self.bereinigen(punkte, kanten)
      p2, k2 = [], []
      punkte.each_with_index do |p, i|
        if p2.any? && (p2.last[0] - p[0]).abs < 1e-6 && (p2.last[1] - p[1]).abs < 1e-6
          k2[-1] = kanten[i]
          next
        end
        p2 << p
        k2 << kanten[i]
      end
      if p2.size > 1 && (p2.first[0] - p2.last[0]).abs < 1e-6 && (p2.first[1] - p2.last[1]).abs < 1e-6
        p2.pop
        k2.pop
      end
      if flaeche(p2) < 0
        n = p2.size
        p2 = p2.reverse
        k2 = (0...n).map { |j| k2[(n - 2 - j) % n] }
      end
      [p2.map { |p| p.map { |v| v.round(3) } }, k2]
    end

    def self.masse(punkte, z)
      ss = punkte.map { |p| achse(z).zero? ? p[0] : p[1] }
      qs = punkte.map { |p| achse(z).zero? ? p[1] : p[0] }
      [(ss.max - ss.min).round(1), (qs.max - qs.min).round(1)]
    end

    def self.format_waehlen(laenge, breite, o, warnungen, nr)
      return o[:format].map(&:to_f) if o[:format]
      f = o[:formate].map { |x| x.map(&:to_f) }.select { |l, b| b >= breite - 1e-6 }.min_by { |_, b| b }
      unless f
        f = o[:formate].map { |x| x.map(&:to_f) }.max_by { |_, b| b }
        warnungen << "Platte #{nr}: Tiefe #{breite.round} mm breiter als jedes Format (max. #{f[1].round} mm)"
      end
      warnungen << "Platte #{nr}: Länge #{laenge.round} mm länger als das Format #{f[0].round} mm" if laenge > f[0] + 1e-6
      f
    end

    # Ergebnis: { platten:, stoesse:, warnungen: }
    def self.berechne(erg, optionen = {})
      o = OPTIONEN.merge(optionen)
      o[:staerke] ||= STAERKE.fetch(o[:art].to_sym)
      warnungen = []
      ecken = ecken_planen(erg, o, warnungen)
      platten = []
      stoesse = []
      nutzbar_fuer = lambda do |breite|
        l = o[:format] ? o[:format][0] : o[:formate].map { |x| x.map(&:to_f) }.select { |_, b| b >= breite - 1e-6 }
                                                    .map(&:first).max || o[:formate].map(&:first).max
        l.to_f - 2 * o[:besaeumen]
      end

      erg[:zeilen].each do |z|
        s_a = end_s(z, :start, o, ecken)
        s_e = end_s(z, :ende, o, ecken)
        breite = (q_wand(z, o) - q_vorn(z, o)).abs
        schnitte = teilungen(z, s_a, s_e, nutzbar_fuer.(breite), o, warnungen)
        grenzen = [z[:enden][:start]] + schnitte.map { |s| { art: :laengs, s: s } } + [z[:enden][:ende]]
        stuecke = grenzen.each_cons(2).map { |s0, s1| [s0, s1] }
        stuecke.each_with_index do |(st, en), i|
          punkte, kanten = umriss(z, st, en, o, ecken)
          nr = platten.size + 1
          laenge, br = masse(punkte, z)
          platten << { nr: nr, zeile: z[:nr], stueck: i + 1, punkte: punkte, kanten: kanten, z: z[:z],
                       staerke: o[:staerke], art: o[:art].to_sym, laenge: laenge, breite: br,
                       format: format_waehlen(laenge, br, o, warnungen, nr), achse: z[:achse], front: z[:front] }
          next if i.zero?
          s = st[:s]
          stoesse << { nr: stoesse.size + 1, art: :laengs, platten: [nr - 1, nr],
                       pfad: [[:linie, pt(z, s, q_vorn(z, o)), pt(z, s, q_wand(z, o))]] }
        end
        z[:platten] = platten.select { |p| p[:zeile] == z[:nr] }.map { |p| p[:nr] }
      end

      ecken.each do |k|
        # Platte der Zeile, die an dieser Ecke liegt (erstes oder letztes Stück)
        platte = lambda do |zeile, ende|
          nrs = zeile[:platten]
          ende == :start ? nrs.first : nrs.last
        end
        stoesse << { nr: stoesse.size + 1, art: k[:art], ecke: k[:nr],
                     platten: [platte.(k[:durch], k[:ende_durch]), platte.(k[:anst], k[:ende_anst])],
                     pfad: k[:pfad] }
      end
      erg[:zeilen].each { |z| z.delete(:platten) }
      { platten: platten, stoesse: stoesse, warnungen: warnungen, optionen: o }
    end

    def self.zusammenfassung(lay)
      txt = lay[:platten].map do |p|
        "Platte #{p[:nr]} (Zeile #{p[:zeile]}): #{p[:laenge].round} × #{p[:breite].round} × #{p[:staerke].round} mm, " \
          "Format #{p[:format].map(&:round).join(' × ')}"
      end
      txt += lay[:stoesse].map do |s|
        name = { gehrungsansatz: 'Gehrungsansatz', stumpf: 'stumpf', gehrung: 'Gehrung 45°', laengs: 'Längsstoß' }[s[:art]]
        "Stoß #{s[:nr]}: #{name}, Platte #{s[:platten].join(' + ')}"
      end
      (txt + lay[:warnungen].map { |w| "Achtung: #{w}" }).join("\n")
    end
  end
end
