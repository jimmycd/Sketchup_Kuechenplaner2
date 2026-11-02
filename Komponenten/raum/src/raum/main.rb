# encoding: UTF-8
#
# Raum – Wände, Fenster, Türen und Durchgänge als Planungshilfe
#
# Erweiterung (.rbz): Erweiterungen > Küchenplaner > Raum.
#   "Raum anlegen…"          Rechteckraum aus Innenmaßen
#   "Wände aus Linien…"      ausgewählte Linien (Grundriss, offen oder geschlossen) werden zu Wänden
#   "Fenster/Tür einsetzen…" Werkzeug: Öffnung an der Maus, Klick auf eine Wand setzt sie ein
#   "Öffnung bearbeiten…"    Maße, Lage oder Löschen einer Öffnung
#   "Raum bearbeiten…"       Raumhöhe und Wanddicke ändern
#
# Aufbau: eine Gruppe "Raum" (Wörterbuch JT_Raum, typ = Raum) hält alle Daten als
# JSON (Grundriss, Höhe, Dicke, Öffnungen). Die Wände sind daraus abgeleitet und
# werden bei jeder Änderung neu gebaut; deshalb ändert man den Raum über die Befehle,
# nicht von Hand.
#
# Jede Wand ist eine Komponente mit eigenem Koordinatensystem, gleich wie ein Schrank:
#   x = entlang der Wand, von links nach rechts gesehen aus dem Raum
#   y = in die Wand hinein (Raumseite bei y = 0, Außenseite bei y = Dicke)
#   z = nach oben, 0 = Fertigfußboden
# Die Wanddicke geht vom gezeichneten Grundriss nach außen (Grundriss = Innenmaß).
# An der Wand-Instanz stehen typ = Wand, laenge und die Kanten, an denen Schränke
# einrasten (Wandenden, Tür- und Durchgangslaibungen); das Andock-Werkzeug liest sie.
#
# Der Raum ist kein Fertigungsteil: kein Plattenmaterial, kein JT_Schrank, Tags
# "Raum-…". TCN-Export und Zuschnitt übergehen ihn; vor OpenCutList die Szene
# "Zuschnitt" wählen (Geräte › Szenen anlegen blendet die Raum-Tags dort aus).

require 'sketchup.rb'
require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'eingabe') # Eingabefenster im Treppenplaner-Stil
require 'json'

module Raum

  DICT = 'JT_Raum'.freeze

  TAG_WAND     = 'Raum-Wand'.freeze
  TAG_BODEN    = 'Raum-Boden'.freeze
  TAG_FENSTER  = 'Raum-Fenster'.freeze
  TAG_TUER     = 'Raum-Tuer'.freeze
  TAG_AUFSCHLAG = 'Raum-Aufschlag'.freeze

  # Materialien ohne OpenCutList-Einstellungen: [Farbe, Deckkraft]
  MATERIALIEN = {
    'Raum Wand'       => [[236, 233, 226], 1.0],
    'Raum Boden'      => [[205, 195, 175], 1.0],
    'Raum Rahmen'     => [[248, 248, 248], 1.0],
    'Raum Glas'       => [[170, 200, 225], 0.35],
    'Raum Fensterbank' => [[225, 225, 225], 1.0],
    'Raum Tuer'       => [[226, 214, 192], 1.0],
    'Raum Aufschlag'  => [[230, 120, 60], 0.3]
  }.freeze

  ARTEN = %w[Fenster Tür Durchgang].freeze
  SOCKEL_TEXT = 'Sockelhöhe Unter-/Hochschränke (mm)'.freeze

  # Vorschläge in den Dialogen (mm)
  RAUM_STD = { 'breite' => 4000.0, 'tiefe' => 3000.0, 'hoehe' => 2500.0, 'dicke' => 240.0, 'sockel' => 100.0 }.freeze
  OEFFNUNG_STD = {
    'Fenster'   => { 'breite' => 1000.0, 'hoehe' => 1200.0, 'bruestung' => 950.0, 'fensterbank' => 'ja', 'ueberstand' => 30.0 },
    'Tür'       => { 'breite' => 885.0, 'hoehe' => 2010.0, 'anschlag' => 'links', 'richtung' => 'innen' },
    'Durchgang' => { 'breite' => 1000.0, 'hoehe' => 2010.0 }
  }.freeze

  DOKU_URL = 'https://github.com/jimmycd/sketchup_kuechenplaner2/tree/main/Komponenten/raum'.freeze

  class Fehler < StandardError; end

  # ---------------------------------------------------------------------------
  # Reine Berechnung (ohne SketchUp), alles in mm
  # ---------------------------------------------------------------------------
  module Rechnung
    module_function

    RAND        = 10.0   # Mindestabstand Öffnung – Wandende/Decke/andere Öffnung
    MIN_WAND    = 100.0  # kürzeste Wand
    MIN_DICKE   = 100.0  # dünnste Wand (Fensterrahmen 70 mm tief)
    MAX_KNICK   = 170.0  # spitzere Ecken lassen sich nicht auf Gehrung bauen
    RAHMEN      = 60.0   # Fensterrahmen Ansicht
    RAHMEN_T    = 70.0   # Fensterrahmen Tiefe
    ZARGE       = 30.0   # Türzarge Ansicht
    BLATT       = 40.0   # Türblatt Dicke
    FENSTERBANK = 20.0   # Fensterbank innen Dicke
    BOGEN       = 12     # Segmente im Türaufschlag

    # Rechteckraum aus Innenmaßen, im Uhrzeigersinn (Raum rechts der Laufrichtung):
    # Wand 1 hinten, 2 rechts, 3 vorne, 4 links; Ursprung = Innenecke vorne links
    def rechteck(b, t)
      [[0.0, t.to_f], [b.to_f, t.to_f], [b.to_f, 0.0], [0.0, 0.0]]
    end

    # vorzeichenbehaftete Fläche (gegen den Uhrzeigersinn positiv)
    def flaeche(pts)
      pts.each_with_index.sum do |p, i|
        q = pts[(i + 1) % pts.size]
        p[0] * q[1] - q[0] * p[1]
      end / 2.0
    end

    # Linien (je [[x, y], [x, y]]) zu einem Linienzug ordnen. Liefert [punkte, geschlossen].
    def kette(kanten)
      raise Fehler, 'Keine Linien ausgewählt.' if kanten.empty?
      key = ->(p) { [p[0].round(1), p[1].round(1)] }
      nachbarn = Hash.new { |h, k| h[k] = [] }
      kanten.each do |p, q|
        a = key.(p)
        b = key.(q)
        next if a == b
        nachbarn[a] << b
        nachbarn[b] << a
      end
      raise Fehler, 'Keine Linien ausgewählt.' if nachbarn.empty?
      if nachbarn.values.any? { |l| l.size > 2 }
        raise Fehler, 'Die Linien verzweigen sich. Bitte nur einen Linienzug (Grundriss) auswählen.'
      end
      enden = nachbarn.keys.select { |k| nachbarn[k].size == 1 }
      start = enden.first || nachbarn.keys.first
      punkte = [start]
      vorher = nil
      jetzt = start
      loop do
        weiter = (nachbarn[jetzt] - [vorher]).first
        break if weiter.nil? || weiter == start
        punkte << weiter
        vorher = jetzt
        jetzt = weiter
      end
      geschlossen = enden.empty?
      if punkte.size != nachbarn.size
        raise Fehler, 'Die Linien bilden mehrere getrennte Züge. Bitte nur einen Linienzug auswählen.'
      end
      [gerade(punkte, geschlossen), geschlossen]
    end

    # Punkte ohne Knick (zwei Linien in einer Flucht) entfernen
    def gerade(punkte, geschlossen)
      n = punkte.size
      punkte.each_with_index.reject do |p, i|
        next false if !geschlossen && (i.zero? || i == n - 1)
        a = punkte[(i - 1) % n]
        b = punkte[(i + 1) % n]
        kreuz = (p[0] - a[0]) * (b[1] - p[1]) - (p[1] - a[1]) * (b[0] - p[0])
        l = Math.hypot(p[0] - a[0], p[1] - a[1]) * Math.hypot(b[0] - p[0], b[1] - p[1])
        punkt = (p[0] - a[0]) * (b[0] - p[0]) + (p[1] - a[1]) * (b[1] - p[1])
        l > 0 && (kreuz / l).abs < 1e-6 && punkt > 0
      end.map(&:first)
    end

    # Laufrichtung so drehen, dass der Raum rechts liegt (Wanddicke geht nach links = außen).
    # Geschlossen: Uhrzeigersinn. Offen: die Seite, zu der sich der Zug krümmt (L, U);
    # eine einzelne gerade Wand: die Seite, auf der der Betrachter steht (blick = [x, y]).
    def orientieren(punkte, geschlossen, blick = nil)
      if punkte.size >= 3
        return flaeche(punkte) > 0 ? punkte.reverse : punkte
      end
      return punkte unless blick && !geschlossen
      a, b = punkte
      kreuz = (b[0] - a[0]) * (blick[1] - a[1]) - (b[1] - a[1]) * (blick[0] - a[0])
      kreuz > 0 ? punkte.reverse : punkte
    end

    # Knickwinkel von Richtung u nach v (gegen den Uhrzeigersinn positiv), Bogenmaß
    def knick(u, v)
      Math.atan2(u[0] * v[1] - u[1] * v[0], u[0] * v[0] + u[1] * v[1])
    end

    # Wände aus dem Grundriss: nr, start [x, y], winkel (Richtung der x-Achse), laenge,
    # a/b = Gehrung: Außenkante beginnt bei x = a und endet bei x = laenge + b
    def waende(punkte, geschlossen, dicke)
      n = punkte.size
      anzahl = geschlossen ? n : n - 1
      raise Fehler, 'Mindestens zwei Punkte nötig.' if anzahl < 1 || (geschlossen && n < 3)
      seg = (0...anzahl).map do |i|
        p = punkte[i]
        q = punkte[(i + 1) % n]
        l = Math.hypot(q[0] - p[0], q[1] - p[1])
        raise Fehler, "Wand #{i + 1} ist kürzer als #{MIN_WAND.round} mm." if l < MIN_WAND
        { nr: i + 1, start: [p[0].to_f, p[1].to_f], laenge: l, u: [(q[0] - p[0]) / l, (q[1] - p[1]) / l] }
      end
      seg.each_with_index do |s, i|
        s[:winkel] = Math.atan2(s[:u][1], s[:u][0])
        s[:a] = 0.0
        s[:b] = 0.0
        if geschlossen || i > 0
          t = knick(seg[i - 1][:u], s[:u])
          pruefe_knick(t, s[:nr])
          s[:a] = dicke * Math.tan(t / 2)
        end
        if geschlossen || i < anzahl - 1
          t = knick(s[:u], seg[(i + 1) % anzahl][:u])
          pruefe_knick(t, s[:nr])
          s[:b] = -dicke * Math.tan(t / 2)
        end
      end
      seg.each { |s| s.delete(:u) }
    end

    def pruefe_knick(t, nr)
      return if t.abs * 180 / Math::PI <= MAX_KNICK
      raise Fehler, "Die Ecke an Wand #{nr} ist zu spitz (mehr als #{MAX_KNICK.round}° Knick)."
    end

    def zahl(o, k, std = 0.0)
      v = o[k]
      v.nil? || v.to_s.strip.empty? ? std : v.to_f
    end

    # Unterkante und Oberkante einer Öffnung
    def unten(o)
      o['typ'] == 'Fenster' ? zahl(o, 'bruestung') : 0.0
    end

    def oben(o)
      unten(o) + zahl(o, 'hoehe')
    end

    def links(o)
      zahl(o, 'abstand')
    end

    def rechts(o)
      zahl(o, 'abstand') + zahl(o, 'breite')
    end

    # Sockelhöhe (Fußboden bis Korpusunterkante); ältere Räume ohne Angabe: 100 mm
    def sockel(daten)
      v = daten['sockel']
      v.nil? ? 100.0 : v.to_f
    end

    # Raummaße prüfen; liefert Fehlertext oder nil
    def pruefe_raum(hoehe, dicke)
      return 'Die Raumhöhe muss mindestens 1000 mm sein.' if hoehe < 1000
      return "Die Wanddicke muss mindestens #{MIN_DICKE.round} mm sein." if dicke < MIN_DICKE
      return 'Die Wanddicke ist größer als 1000 mm.' if dicke > 1000
      nil
    end

    # Öffnungen einer Wand prüfen; liefert Fehlertext oder nil
    def pruefe_wand(w, hoehe, oeffnungen)
      von = [0.0, w[:a]].max + RAND
      bis = [w[:laenge], w[:laenge] + w[:b]].min - RAND
      oeffnungen.each do |o|
        name = "#{o['typ']} in Wand #{w[:nr]}"
        return "#{name}: unbekannte Art „#{o['typ']}“." unless ARTEN.include?(o['typ'])
        return "#{name}: Breite und Höhe müssen mindestens 200 mm sein." if zahl(o, 'breite') < 200 || zahl(o, 'hoehe') < 200
        return "#{name}: die Brüstung darf nicht negativ sein." if unten(o) < 0
        if links(o) < von - 1e-6 || rechts(o) > bis + 1e-6
          return "#{name} passt nicht in die Wand: links mindestens #{von.ceil} mm, rechts bis höchstens #{bis.floor} mm " \
                 "(jetzt #{links(o).round} bis #{rechts(o).round} mm)."
        end
        if oben(o) > hoehe - RAND + 1e-6
          return "#{name}: Oberkante #{oben(o).round} mm liegt zu nah an der Decke (Raumhöhe #{hoehe.round} mm)."
        end
      end
      sortiert = oeffnungen.sort_by { |o| links(o) }
      sortiert.each_cons(2) do |a, b|
        if links(b) < rechts(a) + RAND - 1e-6
          return "#{a['typ']} und #{b['typ']} in Wand #{w[:nr]} überschneiden sich (mindestens #{RAND.round} mm Abstand)."
        end
      end
      nil
    end

    # ganzen Raum prüfen; liefert Fehlertext oder nil
    def pruefe(daten)
      f = pruefe_raum(daten['hoehe'].to_f, daten['dicke'].to_f)
      return f if f
      s = sockel(daten)
      return 'Die Sockelhöhe muss zwischen 0 und 300 mm liegen.' if s < 0 || s > 300
      ws = waende(daten['punkte'], daten['geschlossen'], daten['dicke'].to_f)
      (daten['oeffnungen'] || []).each do |o|
        return "Öffnung an Wand #{o['wand']}: diese Wand gibt es nicht." unless ws.any? { |w| w[:nr] == o['wand'] }
      end
      ws.each do |w|
        f = pruefe_wand(w, daten['hoehe'].to_f, (daten['oeffnungen'] || []).select { |o| o['wand'] == w[:nr] })
        return f if f
      end
      nil
    rescue Fehler => e
      e.message
    end

    # Öffnung unter der Maus: linke Kante so, dass die Mitte an der Maus steht, auf 10 mm gerundet
    def platzieren(laenge, x, breite)
      ((x - breite / 2.0) / 10.0).round * 10.0
    end

    # Abstand aus der Eingabe: "850" = von links, "r850" = von rechts (bis zur rechten Kante)
    def abstand_aus_text(text, laenge, breite)
      t = text.to_s.strip.downcase.tr(',', '.')
      m = t.match(/\A(r|l)?\s*(-?\d+(?:\.\d+)?)\s*(mm)?\z/)
      return nil unless m
      v = m[2].to_f
      m[1] == 'r' ? laenge - breite - v : v
    end

    # Flächen einer Wand im Wand-Koordinatensystem:
    # [{ pts: [[x, y, z] …], loecher: [[…] …], normal: [nx, ny, nz] }]
    def flaechen(w, hoehe, dicke, oeffnungen)
      l = w[:laenge]
      a = w[:a]
      b = l + w[:b]
      h = hoehe.to_f
      d = dicke.to_f
      oe = oeffnungen.sort_by { |o| links(o) }
      kerben = oe.select { |o| unten(o) <= 1e-6 } # Türen, Durchgänge (bis zum Boden)
      loecher = oe - kerben

      umriss = lambda do |x0, x1|
        pts = [[x0, 0.0]]
        kerben.each { |o| pts.concat([[links(o), 0.0], [links(o), oben(o)], [rechts(o), oben(o)], [rechts(o), 0.0]]) }
        pts.concat([[x1, 0.0], [x1, h], [x0, h]])
      end
      loch = ->(o) { [[links(o), unten(o)], [rechts(o), unten(o)], [rechts(o), oben(o)], [links(o), oben(o)]] }
      ebene = ->(pts, y) { pts.map { |x, z| [x, y, z] } }

      f = []
      f << { pts: ebene.(umriss.(0.0, l), 0.0), loecher: loecher.map { |o| ebene.(loch.(o), 0.0) }, normal: [0, -1, 0] }
      f << { pts: ebene.(umriss.(a, b), d), loecher: loecher.map { |o| ebene.(loch.(o), d) }, normal: [0, 1, 0] }
      f << { pts: [[0.0, 0.0, h], [l, 0.0, h], [b, d, h], [a, d, h]], loecher: [], normal: [0, 0, 1] }
      # Boden: Stücke zwischen den Türen
      grenzen = [[0.0, a]] + kerben.flat_map { |o| [[links(o), links(o)], [rechts(o), rechts(o)]] } + [[l, b]]
      grenzen.each_slice(2) do |(i0, o0), (i1, o1)|
        f << { pts: [[i0, 0.0, 0.0], [i1, 0.0, 0.0], [o1, d, 0.0], [o0, d, 0.0]], loecher: [], normal: [0, 0, -1] }
      end
      # Stirnseiten (Gehrung)
      f << { pts: [[0.0, 0.0, 0.0], [a, d, 0.0], [a, d, h], [0.0, 0.0, h]], loecher: [], normal: normale_stirn(-1, a, d) }
      f << { pts: [[l, 0.0, 0.0], [b, d, 0.0], [b, d, h], [l, 0.0, h]], loecher: [], normal: normale_stirn(1, b - l, d) }
      # Laibungen
      oe.each do |o|
        x0 = links(o)
        x1 = rechts(o)
        z0 = unten(o)
        z1 = oben(o)
        f << { pts: [[x0, 0.0, z0], [x0, d, z0], [x0, d, z1], [x0, 0.0, z1]], loecher: [], normal: [1, 0, 0] }
        f << { pts: [[x1, 0.0, z0], [x1, d, z0], [x1, d, z1], [x1, 0.0, z1]], loecher: [], normal: [-1, 0, 0] }
        f << { pts: [[x0, 0.0, z1], [x1, 0.0, z1], [x1, d, z1], [x0, d, z1]], loecher: [], normal: [0, 0, -1] }
        next if z0 <= 1e-6
        f << { pts: [[x0, 0.0, z0], [x1, 0.0, z0], [x1, d, z0], [x0, d, z0]], loecher: [], normal: [0, 0, 1] }
      end
      f
    end

    # Normale der Stirnseite: seite -1 = Anfang, +1 = Ende; versatz = Außenkante gegenüber Innenkante
    def normale_stirn(seite, versatz, d)
      # Kante von (0,0) nach (versatz, d); Normale steht senkrecht darauf und zeigt nach außen (seite)
      nx = d
      ny = -versatz
      l = Math.hypot(nx, ny)
      [seite * nx / l, seite * ny / l, 0]
    end

    # Teile einer Öffnung: [Name, Material, Tag, [x, y, z], [lx, ly, lz]] im Wand-Koordinatensystem
    def teile(o, dicke)
      x0 = links(o)
      bb = zahl(o, 'breite')
      z0 = unten(o)
      hh = zahl(o, 'hoehe')
      d = dicke.to_f
      case o['typ']
      when 'Fenster'
        ry = (d - RAHMEN_T) / 2.0
        t = [['Rahmen links', 'Raum Rahmen', [x0, ry, z0], [RAHMEN, RAHMEN_T, hh]],
             ['Rahmen rechts', 'Raum Rahmen', [x0 + bb - RAHMEN, ry, z0], [RAHMEN, RAHMEN_T, hh]],
             ['Rahmen unten', 'Raum Rahmen', [x0 + RAHMEN, ry, z0], [bb - 2 * RAHMEN, RAHMEN_T, RAHMEN]],
             ['Rahmen oben', 'Raum Rahmen', [x0 + RAHMEN, ry, z0 + hh - RAHMEN], [bb - 2 * RAHMEN, RAHMEN_T, RAHMEN]],
             ['Glas', 'Raum Glas', [x0 + RAHMEN, d / 2.0 - 2, z0 + RAHMEN], [bb - 2 * RAHMEN, 4.0, hh - 2 * RAHMEN]]]
        if o['fensterbank'].to_s != 'nein' && z0 >= FENSTERBANK
          ue = zahl(o, 'ueberstand', 30.0)
          t << ['Fensterbank', 'Raum Fensterbank', [x0, -ue, z0 - FENSTERBANK], [bb, ry + ue, FENSTERBANK]]
        end
        t.map { |n, m, p, g| [n, m, TAG_FENSTER, p, g] }
      when 'Tür'
        innen = o['richtung'].to_s != 'aussen' && o['richtung'].to_s != 'außen'
        by = innen ? 0.0 : d - BLATT
        [['Zarge links', 'Raum Rahmen', [x0, 0.0, 0.0], [ZARGE, d, hh]],
         ['Zarge rechts', 'Raum Rahmen', [x0 + bb - ZARGE, 0.0, 0.0], [ZARGE, d, hh]],
         ['Zarge oben', 'Raum Rahmen', [x0 + ZARGE, 0.0, hh - ZARGE], [bb - 2 * ZARGE, d, ZARGE]],
         ['Tuerblatt', 'Raum Tuer', [x0 + ZARGE, by, 0.0], [bb - 2 * ZARGE, BLATT, hh - ZARGE]]]
          .map { |n, m, p, g| [n, m, TAG_TUER, p, g] }
      else
        []
      end
    end

    # Aufschlag einer Tür als Viertelkreis am Boden (Punkte [x, y, z]) oder nil
    def aufschlag(o, dicke)
      return nil unless o['typ'] == 'Tür'
      innen = o['richtung'].to_s != 'aussen' && o['richtung'].to_s != 'außen'
      r = zahl(o, 'breite') - 2 * ZARGE
      links_ = o['anschlag'].to_s != 'rechts'
      hx = links_ ? links(o) + ZARGE : rechts(o) - ZARGE
      hy = innen ? 0.0 : dicke.to_f
      zu = links_ ? 1.0 : -1.0  # Richtung des geschlossenen Blatts
      auf = innen ? -1.0 : 1.0  # Richtung des offenen Blatts (in den Raum = -y)
      z = 1.0
      bogen = (0..BOGEN).map do |i|
        t = Math::PI / 2 * i / BOGEN
        [hx + zu * r * Math.cos(t), hy + auf * r * Math.sin(t), z]
      end
      [[hx, hy, z]] + bogen
    end

    # Kanten, an denen ein Schrank einrastet: linke Schrankseite an Wandanfang und
    # rechten Laibungen, rechte Schrankseite an Wandende und linken Laibungen
    def kanten(w, oeffnungen)
      kerben = oeffnungen.select { |o| unten(o) <= 1e-6 }
      [[0.0] + kerben.map { |o| rechts(o) }, [w[:laenge]] + kerben.map { |o| links(o) }]
    end

    # Text für Listen
    def beschreibung(o)
      t = "Wand #{o['wand']}: #{o['typ']} #{zahl(o, 'breite').round}×#{zahl(o, 'hoehe').round}"
      t += ", Brüstung #{unten(o).round}" if o['typ'] == 'Fenster'
      t + ", #{links(o).round} von links"
    end
  end

  # ---------------------------------------------------------------------------
  # Aufbau in SketchUp
  # ---------------------------------------------------------------------------
  def self.inch(mm)
    mm.to_f / 25.4
  end

  def self.mm(inch)
    inch.to_f * 25.4
  end

  def self.punkt(p)
    Geom::Point3d.new(inch(p[0]), inch(p[1]), inch(p[2] || 0))
  end

  def self.material(model, name)
    m = model.materials[name]
    return m if m
    farbe, alpha = MATERIALIEN.fetch(name)
    m = model.materials.add(name)
    m.color = Sketchup::Color.new(*farbe)
    m.alpha = alpha if alpha < 1 && m.respond_to?(:alpha=)
    m
  end

  def self.tag(model, name)
    model.layers[name] || model.layers.add(name)
  end

  def self.raum?(e)
    e.respond_to?(:get_attribute) && e.get_attribute(DICT, 'typ') == 'Raum'
  end

  def self.wand?(e)
    e.respond_to?(:get_attribute) && e.get_attribute(DICT, 'typ') == 'Wand'
  end

  def self.daten(gruppe)
    JSON.parse(gruppe.get_attribute(DICT, 'daten', '{}'))
  end

  def self.speichern(gruppe, daten)
    gruppe.set_attribute(DICT, 'daten', JSON.generate(daten))
  end

  # Fläche mit Löchern; Ausrichtung nach der gewünschten Normale
  def self.flaeche(ents, f)
    face = ents.add_face(f[:pts].map { |p| punkt(p) })
    return nil unless face
    f[:loecher].each do |l|
      innen = ents.add_face(l.map { |p| punkt(p) })
      innen.erase! if innen
    end
    face.reverse! if face.normal % Geom::Vector3d.new(*f[:normal]) < 0
    face
  end

  # Quader als Gruppe (Teil eines Fensters, einer Tür)
  def self.quader(model, ents, name, mat, tag_name, pos, groesse)
    g = ents.add_group
    x, y, z = pos
    lx, ly, lz = groesse
    face = g.entities.add_face(punkt([x, y, z]), punkt([x + lx, y, z]), punkt([x + lx, y + ly, z]), punkt([x, y + ly, z]))
    face.reverse! if face.normal.z < 0
    face.pushpull(inch(lz))
    g.name = name
    g.material = material(model, mat)
    g.layer = tag(model, tag_name)
    g
  end

  def self.boden_flaeche(model, ents, pts, name, mat, tag_name)
    g = ents.add_group
    face = g.entities.add_face(pts.map { |p| punkt(p) })
    face.reverse! if face && face.normal.z < 0
    g.name = name
    g.material = material(model, mat)
    g.layer = tag(model, tag_name)
    g
  end

  def self.transformation(w)
    c = Math.cos(w[:winkel])
    s = Math.sin(w[:winkel])
    Geom::Transformation.axes(punkt(w[:start]), Geom::Vector3d.new(c, s, 0),
                              Geom::Vector3d.new(-s, c, 0), Geom::Vector3d.new(0, 0, 1))
  end

  # Wände, Öffnungen und Boden aus den Daten der Gruppe (neu) bauen
  def self.aufbauen(gruppe)
    model = gruppe.model
    d = daten(gruppe)
    hoehe = d['hoehe'].to_f
    dicke = d['dicke'].to_f
    oeffnungen = d['oeffnungen'] || []
    ws = Rechnung.waende(d['punkte'], d['geschlossen'], dicke)
    ents = gruppe.entities
    alte = ents.grep(Sketchup::ComponentInstance).map(&:definition).uniq
    ents.clear!
    if d['geschlossen']
      boden_flaeche(model, ents, d['punkte'].map { |x, y| [x, y, 0.0] }, 'Boden', 'Raum Boden', TAG_BODEN)
    end
    ws.map do |w|
      oe = oeffnungen.select { |o| o['wand'] == w[:nr] }
      defn = model.definitions.add("Raum Wand #{w[:nr]}")
      defn.description = "Wand #{w[:nr]} des Raums (#{w[:laenge].round} × #{hoehe.round} × #{dicke.round} mm). " \
                         "Ändern über Küchenplaner › Raum. Doku: #{DOKU_URL}"
      Rechnung.flaechen(w, hoehe, dicke, oe).each { |f| flaeche(defn.entities, f) }
      oe.each do |o|
        Rechnung.teile(o, dicke).each { |n, m, t, p, g| quader(model, defn.entities, n, m, t, p, g) }
        a = Rechnung.aufschlag(o, dicke)
        boden_flaeche(model, defn.entities, a, 'Aufschlag', 'Raum Aufschlag', TAG_AUFSCHLAG) if a
      end
      inst = ents.add_instance(defn, transformation(w))
      inst.name = "Wand #{w[:nr]}"
      inst.material = material(model, 'Raum Wand')
      inst.layer = tag(model, TAG_WAND)
      kl, kr = Rechnung.kanten(w, oe)
      { 'typ' => 'Wand', 'wand' => w[:nr], 'laenge' => w[:laenge].round(2),
        'kanten_links' => kl.map { |v| v.round(2) }, 'kanten_rechts' => kr.map { |v| v.round(2) },
        'sockel' => Rechnung.sockel(d) }
        .each { |k, v| inst.set_attribute(DICT, k, v) }
      inst
    end
  ensure
    if alte && model.definitions.respond_to?(:remove)
      alte.each { |a| model.definitions.remove(a) if a.instances.empty? }
    end
  end

  # neuen Raum als Gruppe anlegen; punkte = Grundriss (Innenkante) relativ zur Gruppe
  def self.anlegen(model, punkte, geschlossen, hoehe, dicke, ursprung = [0, 0, 0], sockel = RAUM_STD['sockel'])
    daten = { 'punkte' => punkte.map { |x, y| [x.to_f.round(2), y.to_f.round(2)] }, 'geschlossen' => geschlossen,
              'hoehe' => hoehe.to_f, 'dicke' => dicke.to_f, 'sockel' => sockel.to_f, 'oeffnungen' => [] }
    f = Rechnung.pruefe(daten)
    raise Fehler, f if f
    gruppe = model.active_entities.add_group
    gruppe.transformation = Geom::Transformation.translation(Geom::Vector3d.new(*ursprung.map { |v| inch(v) }))
    gruppe.name = 'Raum'
    gruppe.set_attribute(DICT, 'typ', 'Raum')
    speichern(gruppe, daten)
    aufbauen(gruppe)
    gruppe
  end

  # Daten ändern, prüfen und neu bauen; liefert Fehlertext oder nil
  def self.aendern(gruppe, titel)
    d = daten(gruppe)
    yield d
    f = Rechnung.pruefe(d)
    return f if f
    model = gruppe.model
    model.start_operation(titel, true)
    begin
      speichern(gruppe, d)
      aufbauen(gruppe)
      model.commit_operation
    rescue StandardError
      model.abort_operation
      raise
    end
    nil
  end

  # Raum zur Auswahl (Raum-Gruppe oder eine ihrer Wände) oder zum geöffneten Bearbeitungskontext
  def self.gewaehlter_raum(model)
    kandidaten = model.selection.to_a
    kandidaten += model.active_path.to_a.reverse if model.respond_to?(:active_path) && model.active_path
    kandidaten.each do |e|
      return e if raum?(e)
      if wand?(e)
        r = e.parent.respond_to?(:instances) ? e.parent.instances.find { |i| raum?(i) } : nil
        return r if r
      end
    end
    nil
  end

  def self.gewaehlte_wand(model)
    model.selection.to_a.find { |e| wand?(e) }
  end

  # ---------------------------------------------------------------------------
  # Dialoge
  # ---------------------------------------------------------------------------
  def self.zahlen(werte)
    werte.map do |v|
      t = v.to_s.strip.tr(',', '.')
      raise Fehler, "„#{v}“ ist keine Zahl." unless t =~ /\A-?\d+(\.\d+)?\z/
      t.to_f
    end
  end

  def self.melden(e)
    UI.messagebox(e.message)
    nil
  end

  # Eingabefenster (Kuechenplaner::Eingabe, Stil wie Treppenplaner). Fehler im Block bleiben im
  # Fenster stehen; ohne HtmlDialog (Tests) läuft der Block sofort und Fehler kommen per Meldung.
  def self.fenster(*args, **opts, &blk)
    Kuechenplaner::Eingabe.abfragen(*args, **opts, &blk)
  end

  # Änderung als eine Operation; bei Fehler zurücknehmen
  def self.operation(model, titel)
    model.start_operation(titel, true)
    erg = yield
    model.commit_operation
    erg
  rescue StandardError
    model.abort_operation
    raise
  end

  def self.raum_anlegen_dialog(model = Sketchup.active_model)
    s = RAUM_STD
    fenster(['Breite innen (mm)', 'Tiefe innen (mm)', 'Raumhöhe (mm)', 'Wanddicke (mm)', SOCKEL_TEXT],
            [s['breite'], s['tiefe'], s['hoehe'], s['dicke'], s['sockel']].map { |v| v.round.to_s }, 'Raum anlegen',
            ok: 'Anlegen') do |r|
      b, t, h, d, so = zahlen(r)
      g = operation(model, 'Raum anlegen') { anlegen(model, Rechnung.rechteck(b, t), true, h, d, [0, 0, 0], so) }
      auswaehlen(model, g)
      g
    end
  rescue Fehler => e
    melden(e)
  end

  def self.auswaehlen(model, e)
    sel = model.selection
    sel.clear
    sel.add(e)
  end

  def self.waende_aus_linien(model = Sketchup.active_model)
    kanten = model.selection.to_a.grep(Sketchup::Edge)
    if kanten.empty?
      UI.messagebox("Bitte zuerst den Grundriss als Linien zeichnen (Innenkante der Wände) und die Linien auswählen.\n" \
                    'Ein geschlossener Linienzug wird ein ganzer Raum, ein offener eine Wandreihe (z. B. L-Form).')
      return nil
    end
    zs = kanten.flat_map { |e| [e.start.position.z, e.end.position.z] }
    raise Fehler, 'Die Linien müssen waagrecht in einer Ebene liegen.' if zs.max - zs.min > inch(1)
    paare = kanten.map { |e| [e.start.position, e.end.position].map { |p| [mm(p.x), mm(p.y)] } }
    punkte, geschlossen = Rechnung.kette(paare)
    auge = model.active_view.camera.eye
    punkte = Rechnung.orientieren(punkte, geschlossen, [mm(auge.x), mm(auge.y)])
    s = RAUM_STD
    fenster(['Raumhöhe (mm)', 'Wanddicke nach außen (mm)', SOCKEL_TEXT], [s['hoehe'], s['dicke'], s['sockel']].map { |v| v.round.to_s },
            'Wände aus Linien', untertitel: geschlossen ? 'geschlossener Raum' : 'Wandreihe', ok: 'Anlegen') do |r|
      h, d, so = zahlen(r)
      g = operation(model, 'Wände aus Linien') { anlegen(model, punkte, geschlossen, h, d, [0, 0, mm(zs.min)], so) }
      auswaehlen(model, g)
      g
    end
  rescue Fehler => e
    melden(e)
  end

  # Felder je Art: [Schlüssel, Beschriftung, Auswahlliste oder nil]
  FELDER = {
    'Fenster' => [['breite', 'Breite Rohbau (mm)', nil], ['hoehe', 'Höhe Rohbau (mm)', nil],
                  ['bruestung', 'Brüstungshöhe ab Fußboden (mm)', nil], ['fensterbank', 'Fensterbank innen', 'ja|nein'],
                  ['ueberstand', 'Überstand Fensterbank in den Raum (mm)', nil]],
    'Tür' => [['breite', 'Breite Rohbau (mm)', nil], ['hoehe', 'Höhe Rohbau (mm)', nil],
              ['anschlag', 'Bänder (aus dem Raum gesehen)', 'links|rechts'], ['richtung', 'öffnet nach', 'innen|aussen']],
    'Durchgang' => [['breite', 'Breite (mm)', nil], ['hoehe', 'Höhe (mm)', nil]]
  }.freeze

  # Eingabe einer Öffnung; extra = zusätzliche Felder [[Beschriftung, Vorgabe, Liste]]
  # Ruft den Block mit [öffnung, zusätzliche Werte] auf (nicht bei Abbruch)
  def self.oeffnung_dialog(art, werte, titel, extra = [], ok: 'OK')
    felder = FELDER.fetch(art)
    prompts = felder.map { |f| f[1] } + extra.map(&:first)
    vorgaben = felder.map { |k, _, l| l ? werte[k].to_s : werte[k].to_f.round.to_s } + extra.map { |e| e[1] }
    listen = felder.map { |f| f[2].to_s } + extra.map { |e| e[2].to_s }
    fenster(prompts, vorgaben, listen, titel, untertitel: art, gruppe: art, ok: ok) do |r|
      o = { 'typ' => art }
      felder.each_with_index do |(k, _, l), i|
        o[k] = l ? r[i].to_s : zahlen([r[i]]).first
      end
      yield o, r[felder.size..-1]
    end
  end

  def self.einsetzen_dialog(model = Sketchup.active_model)
    @letzte_art ||= 'Fenster'
    fenster(['Art'], [@letzte_art], [ARTEN.join('|')], 'Fenster/Tür einsetzen', ok: 'Weiter') do |r|
      art = r[0]
      @letzte ||= {}
      werte = @letzte[art] || OEFFNUNG_STD.fetch(art)
      # zweites Fenster ersetzt das erste
      oeffnung_dialog(art, werte, "#{art} einsetzen", ok: 'Einsetzen') do |o, _|
        @letzte_art = art
        @letzte[art] = o
        model.select_tool(Einsetzen.new(o))
      end
    end
  rescue Fehler => e
    melden(e)
  end

  def self.oeffnung_bearbeiten_dialog(model = Sketchup.active_model)
    raum = gewaehlter_raum(model)
    unless raum
      UI.messagebox('Bitte den Raum oder eine Wand mit Öffnung auswählen.')
      return nil
    end
    d = daten(raum)
    wand = gewaehlte_wand(model)
    liste = (d['oeffnungen'] || []).each_with_index.to_a
    liste = liste.select { |o, _| o['wand'] == wand.get_attribute(DICT, 'wand') } if wand
    if liste.empty?
      UI.messagebox('Hier gibt es keine Öffnung. Neue Öffnungen mit „Fenster/Tür einsetzen…“.')
      return nil
    end
    return oeffnung_bearbeiten(raum, *liste.first) if liste.size == 1
    namen = liste.map { |x, i| "#{i + 1}) #{Rechnung.beschreibung(x)}" }
    fenster(['Öffnung'], [namen.first], [namen.join('|')], 'Öffnung bearbeiten', ok: 'Weiter') do |r|
      oeffnung_bearbeiten(raum, *liste[namen.index(r[0])])
    end
  rescue Fehler => e
    melden(e)
  end

  def self.oeffnung_bearbeiten(raum, o, idx)
    oeffnung_dialog(o['typ'], o, 'Öffnung bearbeiten',
                    [['Abstand von links (mm)', Rechnung.links(o).round.to_s, nil], ['Aktion', 'ändern', 'ändern|löschen']],
                    ok: 'Übernehmen') do |neu, extra|
      f = aendern(raum, extra[1] == 'löschen' ? 'Öffnung löschen' : 'Öffnung ändern') do |dd|
        if extra[1] == 'löschen'
          dd['oeffnungen'].delete_at(idx)
        else
          neu['wand'] = o['wand']
          neu['abstand'] = zahlen([extra[0]]).first
          dd['oeffnungen'][idx] = neu
        end
      end
      raise Fehler, f if f
      true
    end
  rescue Fehler => e
    melden(e)
  end

  def self.raum_bearbeiten_dialog(model = Sketchup.active_model)
    raum = gewaehlter_raum(model)
    unless raum
      UI.messagebox('Bitte den Raum auswählen.')
      return nil
    end
    d = daten(raum)
    fenster(['Raumhöhe (mm)', 'Wanddicke nach außen (mm)', SOCKEL_TEXT],
            [d['hoehe'], d['dicke'], Rechnung.sockel(d)].map { |v| v.to_f.round.to_s },
            'Raum bearbeiten', ok: 'Übernehmen') do |r|
      h, di, so = zahlen(r)
      f = aendern(raum, 'Raum bearbeiten') do |dd|
        dd['hoehe'] = h
        dd['dicke'] = di
        dd['sockel'] = so
      end
      raise Fehler, f if f
      true
    end
  rescue Fehler => e
    melden(e)
  end

  # ---------------------------------------------------------------------------
  # Werkzeug: Öffnung an der Maus, Klick auf eine Wand setzt sie ein.
  # Eingabe im Maßfeld: "850" = Abstand von links, "r850" = von rechts.
  # ---------------------------------------------------------------------------
  class Einsetzen
    def initialize(vorlage)
      @vorlage = vorlage
      @ziel = nil
    end

    def activate
      @ip = Sketchup::InputPoint.new
      Sketchup.status_text = "#{@vorlage['typ']} einsetzen: auf eine Wand klicken. Maßfeld: Abstand von links " \
                             '(z. B. 850) oder von rechts (r850). Esc: fertig'
      Sketchup.vcb_label = 'Abstand' if Sketchup.respond_to?(:vcb_label=)
    end

    def deactivate(view)
      view.invalidate
    end

    def enableVCB?
      true
    end

    def onMouseMove(_flags, x, y, view)
      @ip.pick(view, x, y)
      @maus = [x, y]
      @ziel = suchen(view)
      if @ziel
        @ziel[:abstand] = Rechnung.platzieren(@ziel[:laenge], @ziel[:x], @vorlage['breite'])
        Sketchup.vcb_value = @ziel[:abstand].round.to_s if Sketchup.respond_to?(:vcb_value=)
      end
      view.invalidate
    end

    def onLButtonDown(_flags, _x, _y, view)
      setzen(view) if @ziel
    end

    def onUserText(text, view)
      return unless @ziel
      a = Rechnung.abstand_aus_text(text, @ziel[:laenge], @vorlage['breite'])
      return UI.beep unless a
      @ziel[:abstand] = a
      setzen(view)
    end

    def onCancel(_reason, view)
      view.model.select_tool(nil)
    end

    def draw(view)
      return unless @ziel
      o = @vorlage.merge('abstand' => @ziel[:abstand])
      x0 = Rechnung.links(o)
      x1 = Rechnung.rechts(o)
      z0 = Rechnung.unten(o)
      z1 = Rechnung.oben(o)
      pts = [[x0, -1, z0], [x1, -1, z0], [x1, -1, z1], [x0, -1, z1]].map { |p| Raum.punkt(p).transform(@ziel[:tr]) }
      view.line_width = 3
      view.drawing_color = 'Red'
      view.draw(GL_LINE_LOOP, pts)
      text = "Wand #{@ziel[:nr]}: links #{x0.round} mm, rechts #{(@ziel[:laenge] - x1).round} mm"
      view.draw_text(Geom::Point3d.new(@maus[0] + 16, @maus[1] + 16, 0), text) if @maus
    end

    private

    # Wand und Raum unter der Maus: { raum:, nr:, laenge:, tr:, x: (mm entlang der Wand) }
    def suchen(view)
      pfad = if @ip.respond_to?(:instance_path) && @ip.instance_path
               @ip.instance_path.to_a
             else
               ph = view.pick_helper
               ph.do_pick(*@maus)
               ph.count > 0 ? (ph.path_at(0) || []) : []
             end
      tr = Geom::Transformation.new
      raum = nil
      pfad.each do |e|
        break unless e.respond_to?(:transformation)
        tr *= e.transformation
        raum = e if Raum.raum?(e)
        next unless Raum.wand?(e) && raum
        lokal = @ip.position.transform(tr.inverse)
        return { raum: raum, nr: e.get_attribute(DICT, 'wand'), laenge: e.get_attribute(DICT, 'laenge').to_f,
                 tr: tr, x: Raum.mm(lokal.x) }
      end
      nil
    end

    def setzen(view)
      o = @vorlage.merge('wand' => @ziel[:nr], 'abstand' => @ziel[:abstand])
      f = Raum.aendern(@ziel[:raum], "#{o['typ']} einsetzen") { |d| (d['oeffnungen'] ||= []) << o }
      UI.messagebox(f) if f
      @ziel = nil
      view.invalidate
    end
  end
end

# Gemeinsames Untermenü "Erweiterungen > Küchenplaner" für alle Komponenten und
# den TCN-Export. Steht wortgleich in jeder Erweiterung (der Test prüft das), damit
# das Untermenü nur einmal angelegt wird, egal welche Erweiterungen geladen sind.
# Schränke kommen über Kuechenplaner.schrank('Unterschränke' | 'Oberschränke' |
# 'Hochschränke' | 'Blenden & Wangen', titel) ins Menü und in die Schrank-Auswahl der Symbolleiste,
# Geräte und Raum in Kuechenplaner.untermenu('Geräte' | 'Raum'), Werkzeuge direkt in Kuechenplaner.menu darunter.
module Kuechenplaner
  GRUPPEN = ['Unterschränke', 'Oberschränke', 'Hochschränke', 'Blenden & Wangen', 'Geräte', 'Raum'].freeze

  def self.menu
    @menu ||= UI.menu('Extensions').add_submenu('Küchenplaner')
  end

  # Alle Gruppen beim ersten Aufruf anlegen, damit die Reihenfolge nicht von der
  # Ladereihenfolge der Erweiterungen abhängt.
  def self.untermenu(gruppe)
    @untermenues ||= GRUPPEN.each_with_object({}) { |g, h| h[g] = menu.add_submenu(g) }
    @untermenues.fetch(gruppe)
  end

  # Schrank in seiner Gruppe ins Menü eintragen und für die Symbolleiste merken
  def self.schrank(gruppe, titel, &aktion)
    untermenu(gruppe).add_item(titel, &aktion)
    schraenke << [gruppe, titel, aktion]
  end

  # Alle eingetragenen Schränke als [gruppe, titel, aktion]
  def self.schraenke
    @schraenke ||= []
  end
end unless defined?(Kuechenplaner.schrank)

unless file_loaded?(__FILE__)
  m = Kuechenplaner.untermenu('Raum')
  m.add_item('Raum anlegen…') { Raum.raum_anlegen_dialog }
  m.add_item('Wände aus Linien…') { Raum.waende_aus_linien }
  m.add_item('Fenster/Tür einsetzen…') { Raum.einsetzen_dialog }
  m.add_item('Öffnung bearbeiten…') { Raum.oeffnung_bearbeiten_dialog }
  m.add_item('Raum bearbeiten…') { Raum.raum_bearbeiten_dialog }
  file_loaded(__FILE__)
end
