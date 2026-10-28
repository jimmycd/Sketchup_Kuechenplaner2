# encoding: UTF-8
#
# Geräte – Platzhalter für Planung und Kundenrendering
#
# Erweiterung (.rbz): Erweiterungen > Küchenplaner > Geräte.
#   "Geräte in Schränke setzen" sucht in der Auswahl (oder im ganzen Modell) die
#   Schränke mit Gerätenische und setzt das passende Gerät hinein.
#   "Szenen Planung/Kunde/Zuschnitt anlegen" schaltet die Geräte-Tags um.
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
#   Tag "Geraete_Plan":   halbtransparenter Block mit Beschriftung (Planung)
#   Tag "Geraete_Render": Modell aus Schwarzglas, Edelstahl und Gehäuse (Kunde)
# Geräte sind keine Schrankteile: kein Plattenmaterial, kein JT_Schrank, keine
# Teil-Tags. Der TCN-Export übergeht sie; vor OpenCutList die Szene "Zuschnitt"
# wählen (beide Geräte-Tags aus).

require 'sketchup.rb'

module Geraete

  DICT        = 'dynamic_attributes'.freeze
  GERAET_DICT = 'JT_Geraet'.freeze
  NISCHE_DICT = 'JT_Nische'.freeze
  JT_DICT     = 'JT_Schrank'.freeze
  TAG_PLAN    = 'Geraete_Plan'.freeze
  TAG_RENDER  = 'Geraete_Render'.freeze

  # Materialien ohne OpenCutList-Einstellungen: [Farbe, Deckkraft]
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
    'Spuele'          => ['Spüle', 'Geraet Plan Wasser'],
    'Backofen'        => ['Backofen', 'Geraet Plan Kochen', 595.0],
    'Kompakt'         => ['Kompaktgerät', 'Geraet Plan Kochen', 455.0],
    'Mikrowelle'      => ['Mikrowelle', 'Geraet Plan'],
    'Waermeschublade' => ['Wärmeschublade', 'Geraet Plan', 140.0]
  }.freeze

  SPALT        = 2.0    # Fuge vor dem Korpus (wie Spaltbreite der Schränke)
  FRONT_MAX    = 595.0  # Frontbreite der Einbaugeräte
  ARBEITSPLATTE = 40.0  # wenn die Nische keine Stärke angibt

  DOKU_URL = 'https://github.com/jimmycd/sketchup_kuechenplaner2/tree/main/Komponenten/geraete'.freeze
  HILFE_KURZ = 'Geräte-Platzhalter für Planung und Rendering, für OpenCutList und TCN-Export unsichtbar'.freeze

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

  # Teil: [Name, Material, [x, y, z], [Breite, Tiefe, Höhe]]
  def self.teil(name, mat, pos, groesse)
    [name, mat, pos.map(&:to_f), groesse.map(&:to_f)]
  end

  # Liefert { plan: [x,y,z,lx,ly,lz], teile: [...], text: "…" } oder nil
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
    sockel = 100.0
    { plan: [0, 0, 0, b, t, h],
      teile: [teil('Gehaeuse', 'Geraet Edelstahl', [0, 20, sockel], [b, t - 20, h - sockel - 20]),
              teil('Bedienleiste', 'Geraet Gehaeuse', [0, 0, h - 20 - 30], [b, 20, 30]),
              teil('Sockel', 'Geraet Gehaeuse', [20, 50, 0], [b - 40, t - 50, sockel])] }
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
    kx = (b - kb) / 2.0
    ky = 50.0 - zahl(n, 'y', 19.0) - SPALT # 50 mm hinter der Frontebene
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

  # Spüle (Edelstahl, ein Becken) mit Armatur, auf der Arbeitsplatte
  def self.berechne_spuele(n, _)
    b = zahl(n, 'breite')
    mk = zahl(n, 'x', 19.0)
    ap = zahl(n, 'arbeitsplatte', ARBEITSPLATTE)
    sw = [b + 2 * mk - 100, 860.0].min
    st, rand, tiefe = 500.0, 60.0, 180.0
    sx = (b - sw) / 2.0
    sy = 50.0 - zahl(n, 'y', 19.0) - SPALT
    bw, bt = sw - 2 * rand, st - 2 * rand
    bx, by = sx + rand, sy + rand
    z0 = ap - tiefe
    { plan: [sx, sy, z0, sw, st, tiefe + 330],
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

  # Alle Wörterbücher JT_Nische* an der Definition, als Hash mit String-Schlüsseln
  def self.nischen(defn)
    dicts = defn.attribute_dictionaries
    liste = dicts ? dicts.select { |d| d.name.start_with?(NISCHE_DICT) }.sort_by(&:name)
                         .map { |d| d.to_h.transform_keys(&:to_s) } : []
    liste << spuelen_nische(defn) if liste.empty? && defn.get_attribute(JT_DICT, 'typ') == 'Spuelenschrank'
    liste
  end

  # Spülenschrank: Nische aus den Schrankmaßen (DC-Attribute in Zoll)
  def self.spuelen_nische(defn)
    mm = ->(k, std) { (v = defn.get_attribute(DICT, k)) ? v.to_f * 25.4 : std }
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

    # Planung: Block in der Planfarbe mit Beschriftung
    pd = model.definitions.add("Geraet #{nische['geraet']} Plan")
    px, py, pz, *pg = r[:plan]
    quader(pd.entities, *pg)
    if pd.entities.respond_to?(:add_text)
      pd.entities.add_text(r[:text], Geom::Point3d.new(inch(pg[0] / 2), 0, inch(pg[2] / 2)))
    end
    plan = d.entities.add_instance(pd, verschiebung([px, py, pz]))
    plan.name = 'Plan'
    plan.material = material(model, ARTEN[a[0]][1])
    plan.layer = tag(model, TAG_PLAN)

    # Kunde: Modell aus Einzelteilen
    rd = model.definitions.add("Geraet #{nische['geraet']} Render")
    r[:teile].each { |name, mat, pos, groesse| box(model, rd.entities, name, mat, pos, groesse) }
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
    liste = nischen(defn)
    return 0 if liste.empty?
    ents = defn.entities
    alt = ents.grep(Sketchup::ComponentInstance).select { |i| geraet?(i) }
    ents.erase_entities(alt) unless alt.empty?
    ents.grep(Sketchup::ComponentInstance).each do |i|
      i.hidden = true if i.layer && i.layer.name == TAG_PLAN
    end
    kz = defn.get_attribute(JT_DICT, 'schrank')
    liste.count do |n|
      g = erzeuge(model, n) or next false
      inst = ents.add_instance(g, verschiebung(%w[x y z].map { |k| zahl(n, k, 0.0) }))
      inst.name = "Geraet_#{n['nische']}"
      inst.set_attribute(GERAET_DICT, 'schrank', kz.to_s) if kz
      true
    end
  end

  # Schränke in der Auswahl, sonst im ganzen Modell (oberste Ebene)
  def self.schraenke(model)
    quelle = model.selection.to_a.empty? ? model.entities.to_a : model.selection.to_a
    quelle.grep(Sketchup::ComponentInstance).reject { |i| geraet?(i) }.select { |i| nischen(i.definition).any? }
  end

  def self.in_schraenke_setzen(model = Sketchup.active_model)
    liste = schraenke(model)
    if liste.empty?
      UI.messagebox('Keine Schränke mit Gerätenische gefunden (Geschirrspüler, Kochfeld, Spüle, Hochschrank Geräte).')
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

  # Szenen: Planung (Blöcke), Kunde (Modelle), Zuschnitt (keine Geräte, für OCL)
  SZENEN = { 'Planung' => [true, false], 'Kunde' => [false, true], 'Zuschnitt' => [false, false] }.freeze

  def self.szenen_anlegen(model = Sketchup.active_model)
    plan, render = tag(model, TAG_PLAN), tag(model, TAG_RENDER)
    model.start_operation('Szenen für Geräte', true)
    SZENEN.each do |name, (p, r)|
      plan.visible = p
      render.visible = r
      seite = model.pages[name]
      seite ? seite.update(32) : model.pages.add(name) # 32 = sichtbare Tags
    end
    model.commit_operation
    model.pages.selected_page = model.pages['Planung']
  end
end

# Gemeinsames Untermenü "Erweiterungen > Küchenplaner" für alle Komponenten und
# den TCN-Export. Steht wortgleich in jeder Erweiterung (der Test prüft das), damit
# das Untermenü nur einmal angelegt wird, egal welche Erweiterungen geladen sind.
# Schränke kommen in Kuechenplaner.untermenu('Unterschränke' | 'Oberschränke' |
# 'Hochschränke'), Geräte in 'Geräte', Werkzeuge direkt in Kuechenplaner.menu darunter.
module Kuechenplaner
  GRUPPEN = ['Unterschränke', 'Oberschränke', 'Hochschränke', 'Geräte'].freeze

  def self.menu
    @menu ||= UI.menu('Extensions').add_submenu('Küchenplaner')
  end

  # Alle Gruppen beim ersten Aufruf anlegen, damit die Reihenfolge nicht von der
  # Ladereihenfolge der Erweiterungen abhängt.
  def self.untermenu(gruppe)
    @untermenues ||= GRUPPEN.each_with_object({}) { |g, h| h[g] = menu.add_submenu(g) }
    @untermenues.fetch(gruppe)
  end
end unless defined?(Kuechenplaner.untermenu)

unless file_loaded?(__FILE__)
  Kuechenplaner.untermenu('Geräte').add_item('Geräte in Schränke setzen') { Geraete.in_schraenke_setzen }
  Kuechenplaner.untermenu('Geräte').add_item('Szenen Planung/Kunde/Zuschnitt anlegen') { Geraete.szenen_anlegen }
  file_loaded(__FILE__)
end
