# encoding: UTF-8
#
# Geräte – Platzhalter für Planung und Kundenrendering
#
# Erweiterung (.rbz): Erweiterungen > Küchenplaner > Geräte.
#   "Geräte in Schränke setzen" sucht in der Auswahl (oder im ganzen Modell) die
#   Schränke mit Gerätenische und setzt das passende Gerät hinein.
#   "Szenen Planung/Kunde/Zuschnitt anlegen" schaltet die Geräte-Tags um und gibt
#   der Szene "Kunde" ihren Darstellungsstil (kundensicht.rb).
#   "Kundenbild speichern…" schreibt die Szene "Kunde" als PNG.
#
# Schnittstelle zu den Schränken: Wörterbuch "JT_Nische" (oder "JT_Nische_N1",
# "JT_Nische_N2" …) an der Schrank-Definition mit nische, geraet, lichten Maßen
# breite/hoehe/tiefe und Einfügepunkt x/y/z, alles in mm, relativ zum
# Schrankursprung. Der Einfügepunkt liegt vorne links an der Korpusvorderkante,
# auf dem Einbauboden (Kochfeld: auf der Korpusoberkante). Der Spülenschrank hat
# kein JT_Nische; seine Nische wird aus den Schrankmaßen abgeleitet.
#
# Jedes Gerät ist eine Komponente "Geraet <Kennung>" mit dem Wörterbuch
# "JT_Geraet" (geraet, nische, schrank) und zwei Darstellungen:
#   Tag "Geraete_Plan":   Gerätemodell mit Beschriftung (Planung)
#   Tag "Geraete_Render": Modell aus Schwarzglas, Edelstahl und Gehäuse (Kunde)
# Geräte sind keine Schrankteile: kein Plattenmaterial, kein JT_Schrank, keine
# Teil-Tags. Der TCN-Export übergeht sie; für Stückliste/Etiketten die Szene "Zuschnitt"
# wählen (beide Geräte-Tags aus).

require 'sketchup.rb'
require 'json'
require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'eingabe') # Eingabefenster im Treppenplaner-Stil
require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'neuladen') # Neu laden ohne Neustart (Wächter)
load File.join(__dir__, 'kundensicht.rb') # Stil der Szene Kunde, Kundenbild speichern

module Geraete

  DICT        = 'dynamic_attributes'.freeze
  GERAET_DICT = 'JT_Geraet'.freeze
  NISCHE_DICT = 'JT_Nische'.freeze
  JT_DICT     = 'JT_Schrank'.freeze
  AP_DICT     = 'JT_Arbeitsplatte'.freeze
  TAG_PLAN    = 'Geraete_Plan'.freeze
  TAG_RENDER  = 'Geraete_Render'.freeze

  # Materialien ohne Plattenwerkstoff-Einstellungen: [Farbe, Deckkraft]
  MATERIALIEN = {
    'Geraet Schwarzglas' => [[20, 20, 22], 1.0],
    'Geraet Edelstahl'   => [[190, 192, 195], 1.0],
    'Geraet Gehaeuse'    => [[70, 72, 75], 1.0],
    'Geraet Glas'        => [[40, 45, 50], 0.85],
    'Geraet Spuele'      => [[200, 202, 205], 1.0],
    'Geraet Plan'        => [[90, 140, 200], 0.4],
    'Geraet Plan Kochen' => [[220, 120, 60], 0.4],
    'Geraet Plan Wasser' => [[60, 170, 190], 0.4]
  }.freeze

  # Kennung -> Bezeichnung, Planfarbe, Fronthöhe (mm) der Einbaugeräte
  ARTEN = {
    'Geschirrspueler' => ['Geschirrspüler', 'Geraet Plan Wasser'],
    'KochfeldAbzug'   => ['Kochfeld mit Abzug', 'Geraet Plan Kochen'],
    'Kochfeld'        => ['Kochfeld', 'Geraet Plan Kochen'],
    'Spuele'          => ['Spüle', 'Geraet Plan Wasser'],
    'Flachschirmhaube' => ['Flachschirmhaube', 'Geraet Plan Kochen'],
    'Backofen'        => ['Backofen', 'Geraet Plan Kochen', 595.0],
    'Kompakt'         => ['Kompaktgerät', 'Geraet Plan Kochen', 455.0],
    'Mikrowelle'      => ['Mikrowelle', 'Geraet Plan'],
    'Waermeschublade' => ['Wärmeschublade', 'Geraet Plan', 140.0],
    'Kuehlschrank'    => ['Kühlschrank integriert', 'Geraet Plan'],
    'KuehlschrankFrei' => ['Kühlschrank unterbaufähig', 'Geraet Plan'],
    'Kuehlgeraet'     => ['Einbau-Kühlgerät', 'Geraet Plan'], # Hochschrank Kühlschrank, Zahl = Nischenhöhe cm
    'Weinkuehler'     => ['Weinkühler', 'Geraet Plan']
  }.freeze
  KUEHL_ARTEN = %w[Kuehlschrank Weinkuehler KuehlschrankFrei].freeze # Geraet_Art 0/1/2 des Kühlschrank-Unterschranks

  SPALT        = 2.0    # Fuge vor dem Korpus (wie Spaltbreite der Schränke)
  FRONT_MAX    = 595.0  # Frontbreite der Einbaugeräte
  # Unterbaugeräte (Spüler, Kühlgeräte) haben einen zurückspringenden Sockel: er beginnt hinter der
  # Sockelblende (Korpus 19 + Rücksprung 50 + Blende 16 mm ab Korpusvorderkante), wie der Platzhalter
  # der Nischen (Geraet_Sockel_Versatz). Jürgen 2026-11-05: Gerätesockel stand zu weit vorne.
  SOCKEL_VERSATZ = 85.0
  ARBEITSPLATTE = 38.0  # wenn die Nische keine Stärke angibt (Schichtstoff, Standard der Arbeitsplatte)

  # Spüle und Kochfeld sitzen im Ausschnitt der Arbeitsplatte. Liegt im Modell eine Arbeitsplatte
  # mit Ausschnitt über dem Schrank, gilt dieser (einsetzen liest ihn, siehe ausschnitt_aus_modell).
  # Sonst die Richtwerte der Arbeitsplatte (Arbeitsplatte::Layout/Ausschnitte::OPTIONEN, der Test
  # vergleicht beide): Platte steht AP_UEBERSTAND vor der Front, Ausschnitt abstand_vorn dahinter.
  AP_UEBERSTAND = 20.0
  AUSSCHNITT_SPUELE = { rand: 100.0, max: 860.0, tiefe: 490.0, abstand_vorn: 60.0 }.freeze
  AUSSCHNITT_KOCHFELD = { abstand_vorn: 50.0, tiefe: 490.0,
                          breiten: { 600 => 560.0, 800 => 750.0, 900 => 880.0 } }.freeze
  SPUELE_AUFLAGE = 10.0 # so weit liegt der Spülenrand rundum auf der Platte

  DOKU_URL = 'https://github.com/jimmycd/sketchup_kuechenplaner2/tree/main/Komponenten/geraete'.freeze
  HILFE_KURZ = 'Geräte-Platzhalter für Planung und Rendering, für Stückliste und TCN-Export unsichtbar'.freeze

  # ---------------------------------------------------------------------------
  # Reine Berechnung (ohne SketchUp). Alles in mm, relativ zum Einfügepunkt der
  # Nische (x nach rechts, y nach hinten, z nach oben).
  # ---------------------------------------------------------------------------

  # "Backofen60" -> ["Backofen", 60]; nil für "frei", "keine" und Unbekanntes
  def self.art(kennung)
    m = kennung.to_s.match(/\A([A-Za-z]+?)(\d*)\z/)
    m && ARTEN.key?(m[1]) ? [m[1], m[2].empty? ? nil : m[2].to_i] : nil
  end

  def self.zahl(n, k, std = nil)
    v = n[k]
    v.nil? || v.to_s.empty? ? std : v.to_f
  end

  # Ausschnitt der Arbeitsplatte über der Nische: [x0, y0, x1, y1] in mm relativ zum Einfügepunkt.
  # Aus dem Modell (n['ausschnitt']), sonst wie die Arbeitsplatte ihn mit den Richtwerten rechnet:
  # mittig über dem Schrank, abstand_vorn hinter der Plattenvorderkante.
  def self.ausschnitt(n, art)
    a = n['ausschnitt']
    return a.map(&:to_f) if a.is_a?(Array) && a.size == 4
    b, mk = zahl(n, 'breite'), zahl(n, 'x', 19.0)
    schrank = b + 2 * mk
    if art == :spuele
      m = AUSSCHNITT_SPUELE
      breite = [schrank - m[:rand], m[:max]].min
    else
      m = AUSSCHNITT_KOCHFELD
      breite = m[:breiten][schrank.round] || schrank - 50.0
    end
    vorn = -(zahl(n, 'y', 19.0) + SPALT) - AP_UEBERSTAND + m[:abstand_vorn] # Front liegt SPALT vor dem Korpus
    [(b - breite) / 2, vorn, (b + breite) / 2, vorn + m[:tiefe]]
  end

  # Gerät der Größe kb × kt mittig auf den Ausschnitt: [x, y]
  def self.mittig(n, art, kb, kt)
    x0, y0, x1, y1 = ausschnitt(n, art)
    [(x0 + x1 - kb) / 2, (y0 + y1 - kt) / 2]
  end

  # Gerätesockel: y relativ zum Einfügepunkt (der liegt n['y'] hinter der Korpusvorderkante)
  def self.sockel_y(n)
    SOCKEL_VERSATZ - zahl(n, 'y', 19.0)
  end

  # Teil: [Name, Material, [x, y, z], [Breite, Tiefe, Höhe]]
  def self.teil(name, mat, pos, groesse)
    [name, mat, pos.map(&:to_f), groesse.map(&:to_f)]
  end

  # Liefert { plan: [x,y,z,lx,ly,lz] (nil = kein Planblock, Modell + text_pos), teile: [...], text: "…" } oder nil
  def self.berechne(n)
    a = art(n['geraet']) or return nil
    send("berechne_#{a[0].downcase}", n, a[1]).merge(text: beschriftung(n, a))
  end

  def self.beschriftung(n, a)
    masse = [zahl(n, 'breite', 0.0), zahl(n, 'hoehe', 0.0)].select(&:positive?).map(&:round).join(' × ')
    "#{ARTEN[a[0]][0]}#{a[1] ? " #{a[1]}" : ''} · Nische #{masse} mm"
  end

  # Vollintegrierter Spüler: nur das Gerät, die Möbelfront gehört zum Schrank
  def self.berechne_geschirrspueler(n, _)
    b, h = zahl(n, 'breite'), zahl(n, 'hoehe')
    t = [550.0, zahl(n, 'tiefe', 550.0)].min
    sockel = zahl(n, 'z', 0.0) < 0 ? -zahl(n, 'z') : 100.0 # Einfügepunkt auf dem Fußboden: Sockel bis Unterkante Korpus
    { plan: [0, 0, 0, b, t, h],
      teile: [teil('Gehaeuse', 'Geraet Edelstahl', [0, 20, sockel], [b, t - 20, h - sockel - 20]),
              teil('Bedienleiste', 'Geraet Gehaeuse', [0, 0, h - 20 - 30], [b, 20, 30]),
              teil('Sockel', 'Geraet Gehaeuse', [20, sockel_y(n), 0], [b - 40, t - sockel_y(n), sockel])] }
  end

  # Unterbau-Kühlgeräte: Einfügepunkt auf dem Fußboden an der Korpusvorderkante,
  # Gerät steht auf eigenen Füßen in der Sockelzone. Integriert: nur Gehäuse und
  # Gerätetür, die Möbelfront gehört zum Schrank. Unterbaufähig und Weinkühler:
  # eigene Tür bündig mit den Möbelfronten.
  def self.kuehl(n)
    b, h = zahl(n, 'breite'), zahl(n, 'hoehe')
    t = [550.0, zahl(n, 'tiefe', 550.0)].min
    so = zahl(n, 'sockel', 100.0)
    fy = -(zahl(n, 'y', 19.0) + SPALT) # Vorderseite der Möbelfronten
    { b: b, h: h, t: t, so: so, fy: fy,
      gehaeuse: teil('Gehaeuse', 'Geraet Gehaeuse', [0, 20, so], [b, t - 20, h - so]),
      fuesse: teil('Fuesse', 'Geraet Gehaeuse', [20, sockel_y(n), 0], [b - 40, t - 20 - sockel_y(n), so]) }
  end

  def self.berechne_kuehlschrank(n, _)
    k = kuehl(n)
    { plan: [0, 0, 0, k[:b], k[:t], k[:h]],
      teile: [k[:gehaeuse], k[:fuesse], teil('Geraetetuer', 'Geraet Gehaeuse', [0, 0, k[:so]], [k[:b], 20, k[:h] - k[:so]])] }
  end

  # Einbau-Kühlgerät im Hochschrank Kühlschrank: Gehäuse und Gerätetür hinter der Möbeltür
  # (die Möbeltür gehört zum Schrank), steht auf dem Boden der Nische
  def self.berechne_kuehlgeraet(n, _)
    b, h = zahl(n, 'breite'), zahl(n, 'hoehe')
    t = [545.0, zahl(n, 'tiefe', 560.0)].min
    { plan: [0, 0, 0, b, t, h],
      teile: [teil('Gehaeuse', 'Geraet Gehaeuse', [2, 20, 0], [b - 4, t - 20, h - 2]),
              teil('Geraetetuer', 'Geraet Gehaeuse', [2, 0, 0], [b - 4, 20, h - 2])] }
  end

  def self.berechne_kuehlschrankfrei(n, _)
    k = kuehl(n)
    th = k[:h] - k[:so]
    { plan: [0, k[:fy], 0, k[:b], k[:t] - k[:fy], k[:h]],
      teile: [k[:gehaeuse], k[:fuesse],
              teil('Tuer', 'Geraet Edelstahl', [0, k[:fy], k[:so]], [k[:b], 20 - k[:fy], th]),
              teil('Griff', 'Geraet Edelstahl', [40, k[:fy] - 25, k[:h] - 60], [k[:b] - 80, 25, 20])] }
  end

  def self.berechne_weinkuehler(n, _)
    k = kuehl(n)
    th = k[:h] - k[:so]
    { plan: [0, k[:fy], 0, k[:b], k[:t] - k[:fy], k[:h]],
      teile: [k[:gehaeuse], k[:fuesse],
              teil('Rahmen', 'Geraet Schwarzglas', [0, k[:fy], k[:so]], [k[:b], 20 - k[:fy], th]),
              teil('Glas', 'Geraet Glas', [30, k[:fy] - 4, k[:so] + 30], [k[:b] - 60, 4, th - 60]),
              teil('Griff', 'Geraet Edelstahl', [k[:b] - 45, k[:fy] - 29, k[:so] + 100], [20, 25, th - 200])] }
  end

  # Backofen, Kompaktgerät, Mikrowelle, Wärmeschublade: Gehäuse in der Nische,
  # Front 595 breit vor dem Korpus, bündig mit den Möbelfronten
  def self.einbau(n, art)
    b, h = zahl(n, 'breite'), zahl(n, 'hoehe')
    t = [545.0, zahl(n, 'tiefe', 560.0) - 20].min
    mk = zahl(n, 'y', 19.0) # Einfügepunkt liegt um die Plattenstärke hinter der Front
    fb = [FRONT_MAX, b + 33].min
    fh = ARTEN[art][2] || h + 2
    fx = (b - fb) / 2.0
    fy = -(mk + SPALT)        # Vorderseite der Möbelfronten
    { b: b, h: h, t: t, fb: fb, fh: fh, fx: fx, fy: fy,
      gehaeuse: teil('Gehaeuse', 'Geraet Gehaeuse', [2, 0, 0], [b - 4, t, [h - 2, fh].min]),
      rahmen: teil('Rahmen', 'Geraet Edelstahl', [fx, fy, 0], [fb, -fy, fh]) }
  end

  def self.berechne_backofen(n, _, art = 'Backofen')
    e = einbau(n, art)
    blende = 95.0
    tuer_h = e[:fh] - blende - 10
    gy = e[:fy] - 4
    { plan: [e[:fx], e[:fy], 0, e[:fb], e[:t] - e[:fy], e[:fh]],
      teile: [e[:gehaeuse], e[:rahmen],
              teil('Tuer', 'Geraet Schwarzglas', [e[:fx] + 5, gy, 5], [e[:fb] - 10, 4, tuer_h]),
              teil('Display', 'Geraet Schwarzglas', [e[:fx] + e[:fb] / 2 - 60, e[:fy] - 1, e[:fh] - blende / 2 - 15], [120, 1, 30]),
              teil('Griff', 'Geraet Edelstahl', [e[:fx] + 40, gy - 25, tuer_h - 40], [e[:fb] - 80, 25, 20])] }
  end

  def self.berechne_kompakt(n, groesse)

    berechne_backofen(n, groesse, 'Kompakt')

  end

  # Mikrowelle: Glastür links, Bedienfeld rechts, kein Griff (Taste)
  def self.berechne_mikrowelle(n, _)
    e = einbau(n, 'Mikrowelle')
    tb = (e[:fb] - 10) * 0.72
    { plan: [e[:fx], e[:fy], 0, e[:fb], e[:t] - e[:fy], e[:fh]],
      teile: [e[:gehaeuse], e[:rahmen],
              teil('Tuer', 'Geraet Schwarzglas', [e[:fx] + 5, e[:fy] - 4, 5], [tb, 4, e[:fh] - 10]),
              teil('Display', 'Geraet Schwarzglas', [e[:fx] + 5 + tb + 20, e[:fy] - 1, e[:fh] - 70], [e[:fb] - tb - 50, 1, 30])] }
  end

  # Wärmeschublade: grifflose Glasfront
  def self.berechne_waermeschublade(n, _)
    e = einbau(n, 'Waermeschublade')
    { plan: [e[:fx], e[:fy], 0, e[:fb], e[:t] - e[:fy], e[:fh]],
      teile: [e[:gehaeuse], e[:rahmen],
              teil('Front', 'Geraet Schwarzglas', [e[:fx] + 5, e[:fy] - 4, 5], [e[:fb] - 10, 4, e[:fh] - 10])] }
  end

  # Kochfeld mit Abzug: Glaskeramik auf der Arbeitsplatte, Abzugsgitter in der
  # Mitte, Lüftermodul unter der Platte und Kanal im Installationsraum nach unten.
  # Einfügepunkt: Korpusoberkante vorne links; z der Nische = Korpushöhe.
  def self.berechne_kochfeldabzug(n, groesse)
    b, hb, t = zahl(n, 'breite'), zahl(n, 'hoehe', 200.0), zahl(n, 'tiefe', 560.0)
    mk = zahl(n, 'x', 19.0)
    ap = zahl(n, 'arbeitsplatte', ARBEITSPLATTE)
    kb = [(groesse || 80) * 10.0, b + 2 * mk].min
    kt = 520.0
    kx, ky = mittig(n, :kochfeld, kb, kt) # liegt im Ausschnitt der Arbeitsplatte
    it = zahl(n, 'installationstiefe', 150.0)
    kab = zahl(n, 'kanal_breite', 300.0)
    kanal_x = zahl(n, 'kanal_x', mk + (b - kab) / 2.0) - mk
    korpus = zahl(n, 'z', 700.0)
    modul_b = [kb - 100, 500.0].min
    { plan: [kx, ky, -hb, kb, kt, hb + ap + 6],
      teile: [teil('Kochfeld', 'Geraet Schwarzglas', [kx, ky, ap], [kb, kt, 6]),
              teil('Abzug', 'Geraet Edelstahl', [kx + kb / 2 - 50, ky + 30, ap + 6], [100, kt - 60, 1]),
              teil('Wanne', 'Geraet Gehaeuse', [kx + 20, ky + 20, -60], [kb - 40, kt - 40, 60]),
              teil('Luefter', 'Geraet Gehaeuse', [kx + (kb - modul_b) / 2, ky + 100, -(hb - 20)], [modul_b, kt - 200, hb - 80]),
              teil('Kanal', 'Geraet Gehaeuse', [kanal_x, t - it + 20, -korpus], [kab, 90, korpus - hb + 20])] }
  end

  # Flachschirmhaube im Oberschrank Dunstabzug: unten bündig mit der Schrankunterkante,
  # Wrasenschirm vorn, Filterwanne, Lüfterbaustein darüber; bei Abluft das Rohr durch
  # Haubenboden und Deckel. Einfügepunkt: vorne links an der Korpusvorderkante auf der Unterkante,
  # Haubenraum = hoehe; Rohrausschnitt (rohr_x/_y ab Einfügepunkt, rohr_breite/_tiefe) und schrank_hoehe.
  def self.berechne_flachschirmhaube(n, _)
    b, h, t = zahl(n, 'breite'), zahl(n, 'hoehe', 380.0), zahl(n, 'tiefe', 400.0)
    wt = [t - 50, 300.0].min # Tiefe der Filterwanne
    teile = [teil('Wrasenschirm', 'Geraet Edelstahl', [0, 0, 0], [b, 20, 40]),
             teil('Filter', 'Geraet Edelstahl', [5, 20, 0], [b - 10, wt, 40]),
             teil('Luefter', 'Geraet Gehaeuse', [10, 30, 40], [b - 20, [wt - 20, 50.0].max, [h - 50, 50.0].max])]
    sh = zahl(n, 'schrank_hoehe', 0.0)
    if zahl(n, 'abluft', 0.0) >= 1 && sh > h
      rb, rt = zahl(n, 'rohr_breite', 170.0), zahl(n, 'rohr_tiefe', 170.0)
      teile << teil('Rohr', 'Geraet Gehaeuse', [zahl(n, 'rohr_x', (b - rb) / 2) + 10, zahl(n, 'rohr_y', 0.0) + 10, h - 10],
                    [rb - 20, rt - 20, sh - h + 10])
    end
    { plan: [0, 0, 0, b, wt + 20, h], teile: teile }
  end

  # Kochfeld ohne Abzug (Herdumbauschrank): Glaskeramik auf der Arbeitsplatte, darunter die
  # Gerätewanne (ca. 50 mm unter der Glasoberkante). Einfügepunkt: Korpusoberkante vorne links.
  def self.berechne_kochfeld(n, groesse)
    b = zahl(n, 'breite')
    mk = zahl(n, 'x', 19.0)
    ap = zahl(n, 'arbeitsplatte', ARBEITSPLATTE)
    kb = [(groesse || 60) * 10.0 - 10, b + 2 * mk].min
    kt = 520.0
    kx, ky = mittig(n, :kochfeld, kb, kt) # liegt im Ausschnitt der Arbeitsplatte
    wanne = 50.0
    { plan: [kx, ky, ap + 6 - wanne, kb, kt, wanne],
      teile: [teil('Kochfeld', 'Geraet Schwarzglas', [kx, ky, ap], [kb, kt, 6]),
              teil('Wanne', 'Geraet Gehaeuse', [kx + 20, ky + 20, ap + 6 - wanne], [kb - 40, kt - 40, wanne - 6]),
              teil('Bedienfeld', 'Geraet Edelstahl', [kx + kb / 2 - 100, ky + 10, ap + 6], [200, 40, 1])] }
  end

  # Spüle (Edelstahl, ein Becken) mit Armatur, auf der Arbeitsplatte. Der Rand liegt rundum
  # SPUELE_AUFLAGE auf der Platte, das Becken hängt im Ausschnitt.
  def self.berechne_spuele(n, _)
    ap = zahl(n, 'arbeitsplatte', ARBEITSPLATTE)
    ax0, ay0, ax1, ay1 = ausschnitt(n, :spuele)
    sx, sy = ax0 - SPUELE_AUFLAGE, ay0 - SPUELE_AUFLAGE
    sw, st = ax1 - ax0 + 2 * SPUELE_AUFLAGE, ay1 - ay0 + 2 * SPUELE_AUFLAGE
    rand, tiefe = 60.0, 180.0
    bw, bt = sw - 2 * rand, st - 2 * rand
    bx, by = sx + rand, sy + rand
    z0 = ap - tiefe
    # Kein Planblock: ein Quader um Becken und Armatur verdeckt die Spüle (Jürgen, 2026-11-02).
    # In der Planung steht stattdessen das Spülenmodell selbst mit Beschriftung.
    { plan: nil, text_pos: [sx + sw / 2, sy, ap + 2],
      teile: [teil('RandVorn', 'Geraet Spuele', [sx, sy, ap], [sw, rand, 2]),
              teil('RandHinten', 'Geraet Spuele', [sx, sy + st - rand, ap], [sw, rand, 2]),
              teil('RandL', 'Geraet Spuele', [sx, by, ap], [rand, bt, 2]),
              teil('RandR', 'Geraet Spuele', [sx + sw - rand, by, ap], [rand, bt, 2]),
              teil('Beckenboden', 'Geraet Spuele', [bx, by, z0], [bw, bt, 1]),
              teil('BeckenVorn', 'Geraet Spuele', [bx, by, z0], [bw, 1, tiefe + 2]),
              teil('BeckenHinten', 'Geraet Spuele', [bx, by + bt - 1, z0], [bw, 1, tiefe + 2]),
              teil('BeckenL', 'Geraet Spuele', [bx, by, z0], [1, bt, tiefe + 2]),
              teil('BeckenR', 'Geraet Spuele', [bx + bw - 1, by, z0], [1, bt, tiefe + 2]),
              teil('Armatur', 'Geraet Edelstahl', [sx + sw / 2 - 25, sy + st - rand / 2 - 25, ap + 2], [50, 50, 300]),
              teil('Auslauf', 'Geraet Edelstahl', [sx + sw / 2 - 15, sy + st - rand / 2 - 200, ap + 272], [30, 200, 30])] }
  end

  # ---------------------------------------------------------------------------
  # Nischen eines Schranks lesen
  # ---------------------------------------------------------------------------

  # Alle Wörterbücher JT_Nische* an der Definition, als Hash mit String-Schlüsseln.
  # Die Nischen stehen dort mit dem Stand beim Erzeugen; die Tiefe kann man danach im Fenster
  # Komponentenoptionen ändern (die DC schreibt sie an die Instanz), daher gilt die aktuelle Tiefe.
  def self.nischen(defn, inst = nil)
    dicts = defn.attribute_dictionaries
    liste = dicts ? dicts.select { |d| d.name.start_with?(NISCHE_DICT) }.sort_by(&:name)
                         .map { |d| d.to_h.transform_keys(&:to_s) } : []
    liste << spuelen_nische(defn, inst) if liste.empty? && defn.get_attribute(JT_DICT, 'typ') == 'Spuelenschrank'
    liste.map! { |n| kuehl_nische(n, defn, inst) } if defn.get_attribute(JT_DICT, 'typ') == 'Unterschrank_Kuehlschrank'
    liste.map! { |n| spueler_nische(n, defn, inst) } if defn.get_attribute(JT_DICT, 'typ') == 'Unterschrank_Geschirrspueler'
    liste.map! { |n| hauben_nische(n, defn, inst) } if defn.get_attribute(JT_DICT, 'typ') == 'OberschrankDunstabzug'
    t = dc_mm(defn, inst, 'tiefe')
    liste.each { |n| n['tiefe'] = t.round(1) } if t
    liste
  end

  # DC-Attribut des Schranks in mm (gespeichert in Zoll): zuerst an der Instanz, dann an der Definition
  def self.dc_mm(defn, inst, k)
    v = inst && inst.get_attribute(DICT, k)
    v = defn.get_attribute(DICT, k) if v.nil?
    v.nil? ? nil : v.to_f * 25.4
  end

  # Oberschrank Dunstabzug: Breite, Höhe, Haubenraum, Abluft und Rohrausschnitt kann man in den
  # Komponentenoptionen ändern, deshalb Nische aus den aktuellen DC-Werten (wie der Schrank rechnet)
  def self.hauben_nische(n, defn, inst)
    b = dc_mm(defn, inst, 'breite') or return n
    mm = ->(k, std) { dc_mm(defn, inst, k) || std }
    abluft = inst && inst.get_attribute(DICT, 'abluft')
    abluft = defn.get_attribute(DICT, 'abluft') if abluft.nil?
    mk = mm.('materialstaerke_korpus', 19.0)
    rb, rt = mm.('rohr_breite', 170.0), mm.('rohr_tiefe', 170.0)
    t_innen = mm.('tiefe', 400.0) - mm.('rueckwand_versatz', 25.0) - mm.('materialstarke_rueckwand', 8.0)
    n.merge('geraet' => "Flachschirmhaube#{(b / 10).round}", 'breite' => (b - 2 * mk).round(1),
            'hoehe' => mm.('haube_hoehe', 380.0).round(1), 'x' => mk.round(1), 'y' => mk.round(1), 'z' => 0.0,
            'abluft' => abluft.to_i, 'rohr_x' => ((b - 2 * mk - rb) / 2).round(1),
            'rohr_y' => [t_innen - mm.('rohr_abstand_hinten', 20.0) - rt, 0.0].max.round(1),
            'rohr_breite' => rb.round(1), 'rohr_tiefe' => rt.round(1), 'schrank_hoehe' => mm.('hoehe', 700.0).round(1))
  end

  # Kühlschrank-Unterschrank: Gerät, Breite, Wange und Sockel kann man in den Komponentenoptionen
  # ändern, deshalb Nische aus den aktuellen DC-Werten (JT_Nische ist der Stand beim Erzeugen)
  def self.kuehl_nische(n, defn, inst)
    art = inst && inst.get_attribute(DICT, 'geraet_art')
    art = defn.get_attribute(DICT, 'geraet_art') if art.nil?
    wange = inst && inst.get_attribute(DICT, 'art_wange')
    wange = defn.get_attribute(DICT, 'art_wange') if wange.nil?
    b = dc_mm(defn, inst, 'breite')
    return n if art.nil? || b.nil?
    mm = ->(k, std) { dc_mm(defn, inst, k) || std }
    so = mm.('sockelhoehe', zahl(n, 'sockel', 100.0))
    mk = mm.('materialstaerke_korpus', 19.0)
    n.merge('geraet' => "#{KUEHL_ARTEN[art.to_i] || KUEHL_ARTEN[0]}#{(b / 10).round}",
            'breite' => (b - mm.('geraet_luft', 4.0)).round(1), 'hoehe' => (mm.('hoehe', 700.0) + so).round(1),
            'x' => (x_wange(wange, mk) + mm.('geraet_luft', 4.0) / 2).round(1), 'z' => -so.round(1), 'sockel' => so.round(1))
  end

  # Nische hinter der Abschlusswange links (Art_Wange 1 = links, 3 = beidseitig)
  def self.x_wange(wange, mk)
    [1, 3].include?(wange.to_i) ? mk : 0.0
  end

  # Geschirrspüler-Unterschrank: Breite, Wange und Sockel kann man in den Komponentenoptionen
  # ändern, deshalb Nische aus den aktuellen DC-Werten. Das Gerät (Nische - Geraet_Luft) sitzt
  # mittig in der Nische wie der Platzhalter, also Geraet_Luft/2 hinter der Nischenkante.
  def self.spueler_nische(n, defn, inst)
    wange = inst && inst.get_attribute(DICT, 'art_wange')
    wange = defn.get_attribute(DICT, 'art_wange') if wange.nil?
    b = dc_mm(defn, inst, 'breite')
    return n if b.nil?
    mm = ->(k, std) { dc_mm(defn, inst, k) || std }
    so = mm.('sockelhoehe', -zahl(n, 'z', -100.0))
    luft = mm.('geraet_luft', 2.0)
    n.merge('geraet' => "Geschirrspueler#{(b / 10).round}", 'breite' => (b - luft).round(1),
            'hoehe' => (mm.('hoehe', 700.0) + so).round(1),
            'x' => (x_wange(wange, mm.('materialstaerke_korpus', 19.0)) + luft / 2).round(1), 'z' => -so.round(1))
  end

  # Spülenschrank: Nische aus den Schrankmaßen (DC-Attribute in Zoll)
  def self.spuelen_nische(defn, inst = nil)
    mm = ->(k, std) { dc_mm(defn, inst, k) || std }
    mk = mm.('materialstaerke_korpus', 19.0)
    { 'nische' => 'SP', 'geraet' => 'Spuele', 'breite' => mm.('breite', 800.0) - 2 * mk,
      'hoehe' => 0.0, 'tiefe' => mm.('tiefe', 800.0), 'x' => mk, 'y' => mk, 'z' => mm.('hoehe', 700.0) }
  end

  # ---------------------------------------------------------------------------
  # Aufbau in SketchUp
  # ---------------------------------------------------------------------------
  def self.inch(mm)
    mm.to_f / 25.4
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

  def self.verschiebung(pos)

    Geom::Transformation.translation(Geom::Vector3d.new(*pos.map { |v| inch(v) }))

  end

  def self.quader(ents, lx, ly, lz)
    f = ents.add_face([0, 0, 0], [inch(lx), 0, 0], [inch(lx), inch(ly), 0], [0, inch(ly), 0])
    f.reverse! if f.normal.z < 0
    f.pushpull(inch(lz))
  end

  def self.box(model, ents, name, mat, pos, groesse)
    d = model.definitions.add("Geraet #{name}")
    quader(d.entities, *groesse)
    i = ents.add_instance(d, verschiebung(pos))
    i.name = name
    i.material = material(model, mat)
    i
  end

  # Gerät als Komponente bauen; liefert die Definition oder nil (frei/unbekannt)
  def self.erzeuge(model, nische)
    r = berechne(nische) or return nil
    a = art(nische['geraet'])
    d = model.definitions.add("Geraet #{nische['geraet']}")
    d.description = "#{r[:text]}. #{HILFE_KURZ}. Doku: #{DOKU_URL}"
    { 'geraet' => nische['geraet'].to_s, 'nische' => nische['nische'].to_s, 'text' => r[:text] }
      .each { |k, v| d.set_attribute(GERAET_DICT, k, v) }

    # Kunde: Modell aus Einzelteilen
    rd = model.definitions.add("Geraet #{nische['geraet']} Render")
    r[:teile].each { |name, mat, pos, groesse| box(model, rd.entities, name, mat, pos, groesse) }

    # Planung: das Gerätemodell selbst mit Beschriftung (Gerät und Nischenmaß). Ein farbiger Kasten
    # um das Gerät sah aus wie eine leere Nische (Jürgen 2026-11-05: "Backofen/Kochfeld wird nicht
    # eingesetzt"), bei der Spüle verdeckte er das Becken (2026-11-02). Die Beschriftung steht vorn
    # mittig auf dem früheren Planblock (r[:plan]), bei der Spüle auf dem Rand.
    pd = model.definitions.add("Geraet #{nische['geraet']} Plan")
    pd.entities.add_instance(rd, verschiebung([0, 0, 0]))
    text_pos = r[:text_pos] || (px, py, pz, lx, _, lz = r[:plan]; [px + lx / 2, py, pz + lz / 2])
    if pd.entities.respond_to?(:add_text)
      tx = pd.entities.add_text(r[:text], Geom::Point3d.new(*text_pos.map { |v| inch(v) }))
      # auf dem Tag der Schrank-Beschriftung: der Schalter in der Symbolleiste blendet beide ein/aus
      tx.layer = tag(model, TAG_BESCHRIFTUNG)
    end
    plan = d.entities.add_instance(pd, verschiebung([0, 0, 0]))
    plan.name = 'Plan'
    plan.layer = tag(model, TAG_PLAN)

    render = d.entities.add_instance(rd, verschiebung([0, 0, 0]))
    render.name = 'Render'
    render.layer = tag(model, TAG_RENDER)
    d
  end

  def self.geraet?(inst)

    !inst.definition.get_attribute(GERAET_DICT, 'geraet').nil?

  end

  # Geräte in einen Schrank setzen; vorhandene Geräte werden ersetzt, die
  # Platzhalter der Schränke (Tag Geraete_Plan) ausgeblendet. Liefert die Anzahl.
  def self.einsetzen(model, schrank)
    defn = schrank.definition
    liste = nischen(defn, schrank)
    return 0 if liste.empty?
    ents = defn.entities
    alt = ents.grep(Sketchup::ComponentInstance).select { |i| geraet?(i) }
    ents.erase_entities(alt) unless alt.empty?
    ents.grep(Sketchup::ComponentInstance).each do |i|
      i.hidden = true if i.layer && i.layer.name == TAG_PLAN
    end
    kz = defn.get_attribute(JT_DICT, 'schrank')
    liste.count do |n|
      n = n.merge(ausschnitt_aus_modell(model, schrank, n, kz.to_s)) if %w[Spuele Kochfeld KochfeldAbzug].include?(art(n['geraet'])&.first)
      g = erzeuge(model, n) or next false
      inst = ents.add_instance(g, verschiebung(%w[x y z].map { |k| zahl(n, k, 0.0) }))
      inst.name = "Geraet_#{n['nische']}"
      inst.set_attribute(GERAET_DICT, 'schrank', kz.to_s) if kz
      true
    end
  end

  # Ausschnitt der Arbeitsplatte über dem Schrank (Wörterbuch JT_Arbeitsplatte an den Platten, Rechteck
  # in Weltkoordinaten mm) umgerechnet auf den Einfügepunkt der Nische, dazu die Höhe der Plattenoberseite
  # über dem Einfügepunkt: { 'ausschnitt' => [x0, y0, x1, y1], 'arbeitsplatte' => mm }; {} ohne Arbeitsplatte.
  def self.ausschnitt_aus_modell(model, schrank, n, kz)
    return {} if kz.empty?
    model.entities.grep(Sketchup::ComponentInstance).each do |ap|
      next unless ap.definition.get_attribute(JT_DICT, 'typ') == 'Arbeitsplatte'
      ap.definition.entities.grep(Sketchup::ComponentInstance).each do |platte|
        liste = JSON.parse(platte.get_attribute(AP_DICT, 'ausschnitte').to_s) rescue next
        a = liste.find { |x| x['schrank'] == kz } or next
        m_ap = ap.transformation.to_a.map(&:to_f)
        m_s = schrank.transformation.to_a.map(&:to_f)
        nx, ny, nz = %w[x y z].map { |k| zahl(n, k, 0.0) }
        x0, y0, x1, y1 = a['rechteck'].map(&:to_f)
        oben = platte.transformation.to_a[14].to_f * 25.4 + platte.get_attribute(AP_DICT, 'staerke').to_f
        ecken = [[x0, y0], [x1, y0], [x1, y1], [x0, y1]].map do |x, y|
          welt = punkt(m_ap, [x, y, oben].map { |v| v / 25.4 })
          lokal(m_s, welt).map { |v| v * 25.4 }
        end
        xs, ys, zs = ecken.transpose
        return { 'ausschnitt' => [xs.min - nx, ys.min - ny, xs.max - nx, ys.max - ny].map { |v| v.round(2) },
                 'arbeitsplatte' => (zs.first - nz).round(2) }
      end
    end
    {}
  end

  # Nach dem Erzeugen/Neuberechnen einer Arbeitsplatte: Spüle und Kochfeld in Schränken, die schon
  # Geräte haben, neu einsetzen, damit sie im (neuen) Ausschnitt sitzen. Liefert die Anzahl Schränke.
  def self.an_arbeitsplatte_ausrichten(model)
    model.entities.grep(Sketchup::ComponentInstance).count do |s|
      g = s.definition.entities.grep(Sketchup::ComponentInstance).select { |i| geraet?(i) }
      next false unless g.any? { |i| %w[Spuele Kochfeld KochfeldAbzug].include?(art(i.definition.get_attribute(GERAET_DICT, 'geraet'))&.first) }
      einsetzen(model, s)
      true
    end
  end

  # Punkt mit Transformation (Spaltenform wie Geom::Transformation#to_a, Zoll)
  def self.punkt(m, p)
    (0..2).map { |r| (0..2).sum { |k| m[k * 4 + r] * p[k] } + m[12 + r] }
  end

  # Umkehrung für Drehung + Verschiebung (Schränke werden nicht skaliert)
  def self.lokal(m, p)
    d = (0..2).map { |r| p[r] - m[12 + r] }
    (0..2).map { |k| (0..2).sum { |r| m[k * 4 + r] * d[r] } }
  end

  # Schränke in der Auswahl, sonst (oder mit alle = true) im ganzen Modell (oberste Ebene)
  def self.schraenke(model, alle = false)
    quelle = alle || model.selection.to_a.empty? ? model.entities.to_a : model.selection.to_a
    quelle.grep(Sketchup::ComponentInstance).reject { |i| geraet?(i) }.select { |i| nischen(i.definition).any? }
  end

  def self.in_schraenke_setzen(model = Sketchup.active_model)
    liste = schraenke(model)
    if liste.empty?
      UI.messagebox('Keine Schränke mit Gerätenische gefunden (Geschirrspüler, Kühlschrank, Kochfeld, Herdumbau, Spüle, Hochschrank Geräte, Hochschrank Kühlschrank).')
      return 0
    end
    model.start_operation('Geräte in Schränke setzen', true)
    anzahl = liste.sum { |s| einsetzen(model, s) }
    model.commit_operation
    UI.messagebox("#{anzahl} Geräte in #{liste.size} Schränke gesetzt. Nach Änderungen an einem Schrank einfach erneut ausführen.")
    anzahl
  rescue StandardError => e
    model.abort_operation
    UI.messagebox("Fehler beim Einsetzen: #{e.message}")
    raise
  end

  # Geräte aus einem Schrank entfernen und die alten Platzhalter (Tag Geraete_Plan)
  # wieder einblenden, so dass der Schrank aussieht wie vor dem Einsetzen.
  # Korpus, Nischen (JT_Nische*) und Schrankteile bleiben unberührt. Liefert die Anzahl.
  def self.entfernen_aus(schrank)
    ents = schrank.definition.entities
    alt = ents.grep(Sketchup::ComponentInstance).select { |i| geraet?(i) }
    return 0 if alt.empty?
    ents.erase_entities(alt)
    platzhalter_zeigen(ents)
    alt.size
  end

  # Platzhalter wieder einblenden, sobald im Schrank kein Gerät mehr steckt
  def self.platzhalter_zeigen(ents)
    kinder = ents.grep(Sketchup::ComponentInstance)
    return if kinder.any? { |i| geraet?(i) }
    kinder.each { |i| i.hidden = false if i.layer && i.layer.name == TAG_PLAN }
  end

  # Was der Befehl "Geräte entfernen" trifft: gewählte Geräte einzeln (auch im
  # geöffneten Schrank gewählt), sonst die gewählten Schränke, ohne Auswahl alle
  # Schränke des Modells (oberste Ebene). Liefert [einzelne Geräte, Schränke].
  def self.entfernen_ziele(model)
    auswahl = model.selection.to_a.grep(Sketchup::ComponentInstance)
    einzeln = auswahl.select { |i| geraet?(i) }
    quelle = model.selection.to_a.empty? ? model.entities.to_a : auswahl
    schraenke = quelle.grep(Sketchup::ComponentInstance).reject { |i| geraet?(i) }.select do |i|
      i.definition.entities.grep(Sketchup::ComponentInstance).any? { |k| geraet?(k) }
    end
    [einzeln, schraenke]
  end

  def self.entfernen(model = Sketchup.active_model)
    einzeln, schraenke = entfernen_ziele(model)
    if einzeln.empty? && schraenke.empty?
      UI.messagebox('Keine eingesetzten Geräte gefunden. Ohne Auswahl werden alle Geräte des Modells entfernt, mit Auswahl nur die der gewählten Schränke oder die gewählten Geräte.')
      return 0
    end
    model.start_operation('Geräte entfernen', true)
    eltern = einzeln.map(&:parent).uniq
    einzeln.each(&:erase!)
    eltern.each { |d| platzhalter_zeigen(d.entities) if d.respond_to?(:entities) }
    anzahl = einzeln.size
    anzahl += schraenke.sum { |s| entfernen_aus(s) }
    model.commit_operation
    UI.messagebox("#{anzahl} Geräte entfernt. Mit \"Geräte in Schränke setzen\" lassen sie sich jederzeit wieder einsetzen.")
    anzahl
  rescue StandardError => e
    model.abort_operation
    UI.messagebox("Fehler beim Entfernen: #{e.message}")
    raise
  end

  # ---------- Schalter der Symbolleiste (Geräte ein/aus, wie Schrank-Beschriftung) ----------

  # Eingeschaltet (Icon gedrückt), sobald in einem Schrank (oberste Ebene) ein Gerät steckt
  def self.eingesetzt?(model = Sketchup.active_model)
    return false unless model
    model.entities.grep(Sketchup::ComponentInstance).any? do |s|
      !geraet?(s) && s.definition.entities.grep(Sketchup::ComponentInstance).any? { |k| geraet?(k) }
    end
  end

  # Klick auf den Schalter: sind Geräte eingesetzt, alle entfernen, sonst in alle Schränke
  # setzen – unabhängig von der Auswahl und ohne Erfolgsmeldung. Liefert den neuen Zustand.
  def self.umschalten(model = Sketchup.active_model)
    eingesetzt?(model) ? alle_entfernen(model) : alle_einsetzen(model)
    eingesetzt?(model)
  end

  def self.alle_einsetzen(model = Sketchup.active_model)
    liste = schraenke(model, true)
    if liste.empty?
      UI.messagebox('Keine Schränke mit Gerätenische gefunden (Geschirrspüler, Kühlschrank, Kochfeld, Herdumbau, Spüle, Hochschrank Geräte, Hochschrank Kühlschrank).')
      return 0
    end
    model.start_operation('Geräte in Schränke setzen', true)
    anzahl = liste.sum { |s| einsetzen(model, s) }
    model.commit_operation
    anzahl
  rescue StandardError => e
    model.abort_operation
    UI.messagebox("Fehler beim Einsetzen: #{e.message}")
    raise
  end

  def self.alle_entfernen(model = Sketchup.active_model)
    liste = model.entities.grep(Sketchup::ComponentInstance).reject { |i| geraet?(i) }
    model.start_operation('Geräte entfernen', true)
    anzahl = liste.sum { |s| entfernen_aus(s) }
    model.commit_operation
    anzahl
  rescue StandardError => e
    model.abort_operation
    UI.messagebox("Fehler beim Entfernen: #{e.message}")
    raise
  end

  # Szenen: Planung (Blöcke), Kunde (Modelle), Zuschnitt (keine Geräte und kein Raum)
  SZENEN = { 'Planung' => [true, false], 'Kunde' => [false, true], 'Zuschnitt' => [false, false] }.freeze
  RAUM_TAGS = 'Raum-'.freeze # Tags der Erweiterung Raum (Wände, Fenster, Türen, Boden)
  TAG_BESCHRIFTUNG = 'Beschriftung'.freeze # Schrank-Kürzel (JTools::SchrankCnc::Beschriftung)
  BESCHRIFTUNG = 'JT_Beschriftung'.freeze

  def self.szenen_anlegen(model = Sketchup.active_model)
    plan, render = tag(model, TAG_PLAN), tag(model, TAG_RENDER)
    model.start_operation('Szenen für Geräte', true)
    Kundensicht.vorbereiten(model) # neue Szenen nicht im Kundenstil anlegen
    kunde_neu = model.pages[Kundensicht.szene].nil?
    SZENEN.each do |name, (p, r)|
      plan.visible = p
      render.visible = r
      model.layers.to_a.each { |l| l.visible = name != 'Zuschnitt' if l.name.start_with?(RAUM_TAGS) }
      # Schrank-Beschriftung (TCN-Export › Beschriftung): in Planung/Zuschnitt, wenn eingeschaltet, in Kunde nie
      model.layers.to_a.each { |l| l.visible = name != 'Kunde' && model.get_attribute(BESCHRIFTUNG, 'an') == true if l.name == TAG_BESCHRIFTUNG }
      seite = model.pages[name]
      seite ? seite.update(32) : model.pages.add(name) # 32 = sichtbare Tags
    end
    # Kunde: eigener Stil (Texturen, dezente Kanten, Himmel/Boden), Schatten, Perspektive
    Kundensicht.anwenden(model, model.pages[Kundensicht.szene], kunde_neu)
    model.commit_operation
    model.pages.selected_page = model.pages['Planung']
  end
end

# Gemeinsames Untermenü "Erweiterungen > Küchenplaner" für alle Komponenten und
# den TCN-Export. Steht wortgleich in jeder Erweiterung (der Test prüft das), damit
# das Untermenü nur einmal angelegt wird, egal welche Erweiterungen geladen sind.
# Schränke kommen über Kuechenplaner.schrank('Unterschränke' | 'Oberschränke' |
# 'Hochschränke' | 'Blenden & Wangen', titel) ins Menü und in die Schrank-Auswahl der Symbolleiste,
# Geräte und Raum in Kuechenplaner.untermenu('Geräte' | 'Raum'), Werkzeuge direkt in Kuechenplaner.menu darunter.
# Darf mehrfach laufen (Neuladen ohne Neustart): die Methoden werden ersetzt, die
# angelegten Menüs bleiben gemerkt.
module Kuechenplaner
  GRUPPEN = ['Unterschränke', 'Oberschränke', 'Hochschränke', 'Blenden & Wangen', 'Geräte', 'Raum'].freeze unless const_defined?(:GRUPPEN, false)

  def self.menu
    @menu ||= UI.menu('Extensions').add_submenu('Küchenplaner')
  end

  # Alle Gruppen beim ersten Aufruf anlegen, damit die Reihenfolge nicht von der
  # Ladereihenfolge der Erweiterungen abhängt.
  def self.untermenu(gruppe)
    @untermenues ||= GRUPPEN.each_with_object({}) { |g, h| h[g] = menu.add_submenu(g) }
    @untermenues[gruppe] ||= menu.add_submenu(gruppe) # neue Gruppe aus einem Update: unten anhängen
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
end # gemeinsames Untermenü

unless file_loaded?(__FILE__)
  Kuechenplaner.untermenu('Geräte').add_item('Geräte in Schränke setzen') { Geraete.in_schraenke_setzen }
  Kuechenplaner.untermenu('Geräte').add_item('Geräte entfernen') { Geraete.entfernen }
  Kuechenplaner.untermenu('Geräte').add_item('Szenen Planung/Kunde/Zuschnitt anlegen') { Geraete.szenen_anlegen }
  file_loaded(__FILE__)
end
# Eigener Schlüssel: erscheint auch nach Neu laden ohne Neustart
unless file_loaded?("#{__FILE__}:kundenbild")
  Kuechenplaner.untermenu('Geräte').add_item('Kundenbild speichern…') { Geraete::Kundensicht.dialog }
  file_loaded("#{__FILE__}:kundenbild")
end
