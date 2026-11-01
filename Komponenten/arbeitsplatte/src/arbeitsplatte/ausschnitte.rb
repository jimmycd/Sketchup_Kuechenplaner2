# encoding: UTF-8
#
# Arbeitsplatte – Ausschnitte für Spüle und Kochfeld
#
# Reine Rechnung ohne SketchUp (mm, Weltkoordinaten). Den Ausschnitt geben die
# Schränke vor: über dem Spülenschrank (typ Spuelenschrank) die Spüle, über dem
# Herdschrank (typ Unterschrank_Kochfeld) das Kochfeld, beide mittig über dem
# Schrank. Größe nach Richtwerten, alles je Schrank über o[:ausschnitte] änderbar:
#   { 'USP1' => { breite:, tiefe:, abstand_vorn:, radius: } }  andere Maße
#   { 'USP1' => false }                                        kein Ausschnitt
#   { 'UST2' => { art: :kochfeld } }                           Kochfeld über einem anderen Schrank
# abstand_vorn zählt von der Vorderkante der Platte.

module Arbeitsplatte
  module Ausschnitte
    ARTEN = { 'Spuelenschrank' => :spuele, 'Unterschrank_Kochfeld' => :kochfeld }.freeze
    NAMEN = { spuele: 'Spüle', kochfeld: 'Kochfeld' }.freeze
    # Kochfeld-Ausschnitt nach Schrankbreite (Richtwerte)
    KOCHFELD = { 600 => [560.0, 490.0], 800 => [750.0, 490.0], 900 => [880.0, 490.0] }.freeze

    OPTIONEN = {
      spuele_rand: 100.0,        # Spülenausschnitt = Schrankbreite - Rand, höchstens spuele_max
      spuele_max: 860.0,
      spuele_tiefe: 490.0,
      spuele_abstand_vorn: 60.0,
      spuele_radius: 10.0,
      kochfeld_abstand_vorn: 50.0,
      kochfeld_radius: 0.0,
      abstand_stoss: 150.0,      # Prüfungen
      abstand_vorn_min: 50.0,
      abstand_hochschrank: 300.0,
      ausschnitte: {}
    }.freeze

    def self.standard(art, breite_schrank, o)
      if art == :spuele
        { breite: [breite_schrank - o[:spuele_rand], o[:spuele_max]].min, tiefe: o[:spuele_tiefe],
          abstand_vorn: o[:spuele_abstand_vorn], radius: o[:spuele_radius] }
      else
        b, t = KOCHFELD[breite_schrank.round] || [breite_schrank - 50.0, 490.0]
        { breite: b, tiefe: t, abstand_vorn: o[:kochfeld_abstand_vorn], radius: o[:kochfeld_radius] }
      end
    end

    # Ausschnitte einer Zeile: Liste mit schrank, art, Maßen, s0/s1 (längs) und Umriss
    def self.fuer_zeile(z, o)
      z[:elemente].map do |e|
        eigen = o[:ausschnitte][e[:kz]]
        next if eigen == false
        art = (eigen && eigen[:art] && eigen[:art].to_sym) || ARTEN[e[:typ]]
        next unless art
        breite_schrank = e[:s1] - e[:s0]
        m = standard(art, breite_schrank, o).merge((eigen || {}).reject { |k, _| k == :art })
        mitte = (e[:s0] + e[:s1]) / 2.0
        vz = Layout.vz(z)
        qa = Layout.q_vorn(z, o) - vz * m[:abstand_vorn]
        qb = qa - vz * m[:tiefe]
        s0, s1 = mitte - m[:breite] / 2.0, mitte + m[:breite] / 2.0
        ecken = [[s0, qa], [s1, qa], [s1, qb], [s0, qb]].map { |s, q| Layout.pt(z, s, q) }
        xs, ys = ecken.transpose
        rechteck = [xs.min, ys.min, xs.max, ys.max].map { |v| v.round(3) }
        { schrank: e[:kz], art: art, breite: m[:breite].to_f, tiefe: m[:tiefe].to_f, abstand_vorn: m[:abstand_vorn].to_f,
          radius: m[:radius].to_f, s0: s0, s1: s1, schrank_s: [e[:s0], e[:s1]], zeile: z[:nr],
          rechteck: rechteck, punkte: umriss(rechteck, m[:radius].to_f, o[:bogen_teile]) }
      end.compact
    end

    # Rechteck mit gerundeten Ecken, gegen den Uhrzeigersinn
    def self.umriss(r, radius, teile)
      x0, y0, x1, y1 = r
      return [[x0, y0], [x1, y0], [x1, y1], [x0, y1]] if radius <= 0
      [[x1 - radius, y0 + radius, -90], [x1 - radius, y1 - radius, 0], [x0 + radius, y1 - radius, 90],
       [x0 + radius, y0 + radius, 180]].flat_map do |cx, cy, a0|
        (0..teile).map do |i|
          a = (a0 + 90.0 * i / teile) * Math::PI / 180
          [(cx + radius * Math.cos(a)).round(3), (cy + radius * Math.sin(a)).round(3)]
        end
      end
    end

    # -------------------------------------------------------------------------
    # Geometrie-Hilfen
    # -------------------------------------------------------------------------
    def self.innen?(p, poly)
      x, y = p
      drin = false
      poly.each_with_index do |a, i|
        b = poly[i - 1]
        if (a[1] > y) != (b[1] > y) && x < (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]) + a[0]
          drin = !drin
        end
      end
      drin
    end

    def self.abstand_punkt_strecke(p, a, b)
      dx, dy = b[0] - a[0], b[1] - a[1]
      l2 = dx * dx + dy * dy
      t = l2.zero? ? 0.0 : (((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / l2).clamp(0.0, 1.0)
      Math.hypot(p[0] - a[0] - t * dx, p[1] - a[1] - t * dy)
    end

    def self.schneiden?(a, b, c, d)
      k = ->(p, q, r) { (q[0] - p[0]) * (r[1] - p[1]) - (q[1] - p[1]) * (r[0] - p[0]) }
      (k.(a, b, c) * k.(a, b, d)).negative? && (k.(c, d, a) * k.(c, d, b)).negative?
    end

    def self.abstand_strecken(a, b, c, d)
      return 0.0 if schneiden?(a, b, c, d)
      [abstand_punkt_strecke(a, c, d), abstand_punkt_strecke(b, c, d),
       abstand_punkt_strecke(c, a, b), abstand_punkt_strecke(d, a, b)].min
    end

    # kleinster Abstand zwischen Ausschnitt-Umriss und einem Stoßpfad
    def self.abstand_zum_stoss(ausschnitt, stoss, o)
      pts = [stoss[:pfad][0][1]] + Layout.pfad_punkte(stoss[:pfad], o)
      poly = ausschnitt[:punkte]
      pts.each_cons(2).flat_map do |a, b|
        poly.each_with_index.map { |c, i| abstand_strecken(a, b, c, poly[(i + 1) % poly.size]) }
      end.min
    end

    # -------------------------------------------------------------------------
    # Ausschnitte den Platten zuordnen und prüfen
    # -------------------------------------------------------------------------
    def self.zuordnen(erg, platten, stoesse, liste, o, warnungen)
      platten.each { |p| p[:ausschnitte] = [] }
      liste.each do |a|
        name = "#{NAMEN[a[:art]]} über #{a[:schrank]}"
        mitte = [(a[:rechteck][0] + a[:rechteck][2]) / 2.0, (a[:rechteck][1] + a[:rechteck][3]) / 2.0]
        p = platten.find { |x| x[:zeile] == a[:zeile] && innen?(mitte, x[:punkte]) }
        unless p
          warnungen << "#{name}: liegt auf keiner Platte, kein Ausschnitt"
          next
        end
        p[:ausschnitte] << a.reject { |k, _| %i[s0 s1 schrank_s zeile].include?(k) }
        ecken = [[a[:rechteck][0], a[:rechteck][1]], [a[:rechteck][2], a[:rechteck][1]],
                 [a[:rechteck][2], a[:rechteck][3]], [a[:rechteck][0], a[:rechteck][3]]]
        warnungen << "#{name}: ragt aus Platte #{p[:nr]}" unless ecken.all? { |e| innen?(e, p[:punkte]) }
        if a[:abstand_vorn] < o[:abstand_vorn_min]
          warnungen << "#{name}: nur #{a[:abstand_vorn].round} mm von der Vorderkante (mindestens #{o[:abstand_vorn_min].round})"
        end
        if a[:s0] < a[:schrank_s][0] - 0.5 || a[:s1] > a[:schrank_s][1] + 0.5
          warnungen << "#{name}: #{a[:breite].round} mm breit, ragt über die Schrankseiten"
        end
        stoesse.select { |s| s[:platten].include?(p[:nr]) }.each do |s|
          d = abstand_zum_stoss(a, s, o)
          next if d >= o[:abstand_stoss]
          warnungen << "#{name}: nur #{d.round} mm vom Stoß #{s[:nr]} (mindestens #{o[:abstand_stoss].round})"
        end
        next unless a[:art] == :kochfeld
        z = erg[:zeilen].find { |x| x[:nr] == a[:zeile] }
        { start: a[:s0] - (z[:s0] - (z[:enden][:start][:fuge] || 0)),
          ende: (z[:s1] + (z[:enden][:ende][:fuge] || 0)) - a[:s1] }.each do |seite, d|
          next unless z[:enden][seite][:art] == :hochschrank && d < o[:abstand_hochschrank]
          warnungen << "#{name}: nur #{d.round} mm neben Hochschrank #{z[:enden][seite][:kz]} (mindestens #{o[:abstand_hochschrank].round})"
        end
      end
    end

    # verbotene Bereiche längs der Zeile für Längsstöße
    def self.sperren(liste, o)
      liste.map { |a| [a[:s0] - o[:abstand_stoss], a[:s1] + o[:abstand_stoss]] }
    end
  end
end
