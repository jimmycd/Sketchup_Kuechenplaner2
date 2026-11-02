# encoding: UTF-8
#
# Unterschrank Geschirrspüler – erzeugt eine Dynamic Component
#
# Erweiterung (.rbz): Erweiterungen > Küchenplaner > Unterschränke > Unterschrank Geschirrspüler baut den Schrank im
# aktuellen Modell. Maße und Optionen danach in den Komponentenoptionen einstellen.
#
# Ein vollintegrierter Geschirrspüler hat keinen Korpus: Die Komponente ist eine
# Nische (450 oder 600 mm) mit Möbelfront, die auf die Gerätetür geschraubt wird,
# optional mit Abschlusswangen links/rechts und einem Platzhalter für das Gerät.
# Die Front wird vor Ort mit der Schablone des Herstellers befestigt, deshalb gibt
# es dafür keine CNC-Bohrungen.
#
# OpenCutList: Platten haben das Material "Melamin weiss" (Plattenwerkstoff),
# sichtbare Kanten das Material "Anleimer Melamin weiss" (Kante, 2 mm, wird nur
# in OCL abgezogen; gezeichnet wird das Endmaß). Jedes Teil hat einen eigenen Tag
# <Kürzel>_<Teil> (z. B. USG1_Front, USG1_WangeL) und das Wörterbuch "JT_Schrank"
# für den TCN-Export. Der Geräte-Platzhalter liegt auf dem Tag "Geraete_Plan", hat
# kein Plattenmaterial und kein JT_Schrank. Die Nische steht im Wörterbuch
# "JT_Nische" am Schrank (für die Geräte-Komponenten).
# Anderes Kürzel: UnterschrankGeschirrspueler.erstellen({ 'Kuerzel' => 'USG2' }, ziel)

require 'sketchup.rb'
require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'eingabe') # Eingabefenster im Treppenplaner-Stil

module UnterschrankGeschirrspueler

  DICT     = 'dynamic_attributes'.freeze
  NAME     = 'Unterschrank Geschirrspueler'.freeze
  MATERIAL = 'Melamin weiss'.freeze
  KANTE    = 'Anleimer Melamin weiss'.freeze
  GERAET_MATERIAL = 'Geraet Plan'.freeze
  GERAET_TAG = 'Geraete_Plan'.freeze
  OCL_DICT = 'ladb_opencutlist'.freeze
  KUERZEL  = 'USG'.freeze

  # Tag-Schema für den TCN-Export (gleich in allen Komponenten, der Test prüft das):
  # Tag <Kürzel>_<Bereich>_<Teil>, dazu am Teil das Wörterbuch JT_Schrank.
  JT_DICT   = 'JT_Schrank'.freeze
  TYP       = 'Unterschrank_Geschirrspueler'.freeze
  KATEGORIE = 'Unterschrank'.freeze # Unterschrank, Oberschrank oder Hochschrank
  ROLLEN = {
    'SeiteL' => 'Seite', 'SeiteR' => 'Seite', 'Boden' => 'Boden', 'Deckel' => 'Deckel',
    'StrebeVorn' => 'Strebe', 'StrebeHinten' => 'Strebe',
    'ZwischenbodenUnten' => 'Zwischenboden', 'ZwischenbodenMitte' => 'Zwischenboden', 'ZwischenbodenOben' => 'Zwischenboden',
    'Mittelboden' => 'Zwischenboden',
    'Rueckwand' => 'Rueckwand', 'RueckwandOben' => 'Rueckwand', 'RueckwandUnten' => 'Rueckwand',
    'Einlegeboden' => 'Einlegeboden', 'Front' => 'Front',
    'Tuer' => 'Tuer', 'TuerL' => 'Tuer', 'TuerR' => 'Tuer', 'TuerUnten' => 'Tuer', 'TuerOben' => 'Tuer',
    'Klappe' => 'Front', 'KlappeO' => 'Front', 'KlappeU' => 'Front',
    'KastenBoden' => 'KastenBoden', 'KastenRueckwand' => 'KastenRueckwand',
    'Innenfront' => 'Innenfront',
    'Auflageleiste' => 'Leiste',
    'Blende' => 'Front',
    'WangeL' => 'Wange', 'WangeR' => 'Wange',
    'Platte' => 'Arbeitsplatte',
    'Verkleidung' => 'Verkleidung', 'Theke' => 'Theke'
  }.freeze

  # Nische für die Geräte-Komponenten (Thread "Geräte in Schränken darstellen")
  NISCHE_DICT = 'JT_Nische'.freeze

  # Standardwerte in cm
  DEFAULTS = {
    'Breite'                   => 60.0,  # Nischenbreite, 45 oder 60
    'Hoehe'                    => 70.0,  # wie Korpushöhe der anderen Unterschränke
    'Tiefe'                    => 80.0,  # wie Korpustiefe der anderen Unterschränke
    'Fronthoehe'               => 70.0,  # Oberkante bündig mit den Nachbarfronten
    'Art_Wange'                => 0.0,   # 0 = keine, 1 = links, 2 = rechts, 3 = beide
    'Sockelhoehe'              => 10.0,  # Wangen und Gerät reichen bis zum Boden
    'Materialstaerke_Korpus'   => 1.9,
    'Materialstarke_Rueckwand' => 0.8,
    'Spaltbreite'              => 0.2,
    'Geraet_Luft'              => 0.2,   # Nische 600 -> Gerät 598
    'Geraet_Tiefe'             => 55.0
  }.freeze

  # Kurzhilfe in der Komponente (Kurzfassung der README.md), steht oben im Fenster "Komponentenoptionen".
  DOKU_URL = 'https://github.com/jimmycd/sketchup_kuechenplaner2/tree/main/Komponenten/unterschrank_geschirrspueler'.freeze
  HILFE_KURZ = 'Nische für vollintegrierten Geschirrspüler (45/60 cm) mit Möbelfront, OpenCutList-fähig'.freeze

  # ---------------------------------------------------------------------------
  # Reine Berechnung (ohne SketchUp), spiegelt die DC-Formeln. Werte in cm.
  # ---------------------------------------------------------------------------
  def self.berechne(p)
    mk, sp = p['Materialstaerke_Korpus'], p['Spaltbreite']
    w = p['Art_Wange'].to_i
    {
      x_nische: [1, 3].include?(w) ? mk : 0.0,
      links: [1, 3].include?(w),
      rechts: [2, 3].include?(w),
      b_front: p['Breite'] - sp,
      z_front: p['Hoehe'] - p['Fronthoehe'],
      h_unten: p['Hoehe'] + p['Sockelhoehe'] # Boden bis Oberkante Korpus
    }
  end

  # ---------------------------------------------------------------------------
  # Hilfen für Dynamic-Component-Attribute
  # ---------------------------------------------------------------------------
  def self.inch(cm)
    cm.to_f / 2.54
  end

  def self.stempel(ent)
    ent.set_attribute(DICT, '_formatversion', 1.0)
    ent.set_attribute(DICT, '_has_movetool_behaviors', 1.0)
    ent.set_attribute(DICT, '_hasbehaviors', 1.0)
    ent.set_attribute(DICT, '_lengthunits', 'CENTIMETERS')
    ent.set_attribute(DICT, '_lastmodified', Time.now.strftime('%Y-%m-%d %H:%M'))
  end

  def self.attribut(ent, name, wert, laenge: true, access: 'NONE', formlabel: nil,
                    units: nil, formulaunits: nil, options: nil, formula: nil)
    k = name.downcase
    ent.set_attribute(DICT, k, laenge ? inch(wert) : wert)
    ent.set_attribute(DICT, "_#{k}_label", name)
    ent.set_attribute(DICT, "_#{k}_access", access)
    ent.set_attribute(DICT, "_#{k}_formlabel", formlabel || name)
    ent.set_attribute(DICT, "_#{k}_units", units || (laenge ? 'MILLIMETERS' : 'FLOAT'))
    ent.set_attribute(DICT, "_#{k}_formulaunits", formulaunits || (laenge ? 'CENTIMETERS' : 'FLOAT'))
    ent.set_attribute(DICT, "_#{k}_options", dc_optionen(options))
    ent.set_attribute(DICT, "_#{k}_formula", formula) if formula
  end

  # Listen-Optionen kodiert das DC-Fenster mit JavaScript unescape() zurück, also Zeichen für
  # Zeichen (Latin-1): UTF-8-Kodierung wie %C3%BC erscheint dort als "Ã¼". Deshalb Umlaute als
  # %FC usw., andere Sonderzeichen als %uXXXX; ASCII bleibt, wie es ist.
  def self.dc_optionen(text)
    t = text.to_s.gsub(/(?:%[89A-Fa-f][0-9A-Fa-f])+/) do |m|
      s = [m.delete('%')].pack('H*').force_encoding('UTF-8')
      s.valid_encoding? ? s : m
    end
    t.each_char.map do |c|
      o = c.ord
      next c if o < 128
      o < 256 ? format('%%%02X', o) : format('%%u%04X', o)
    end.join
  end

  # Kurzhilfe: nur die Kurzfassung als "summary" (steht oben im Fenster "Komponentenoptionen")
  # und als Beschreibung der Definition. Keine lange "description" und keine eigenen Zeilen
  # dafür, sonst ist das Fenster nicht mehr ganz lesbar; die ausführliche Doku ist README.md.
  def self.hilfe(d, kurz = HILFE_KURZ)
    d.description = kurz
    d.set_attribute(DICT, 'summary', kurz)
    %w[_summary_label _summary_formlabel _summary_access _summary_units description _description_label
       _description_formlabel _description_access _description_units].each { |k| d.delete_attribute(DICT, k) }
    d.set_attribute(DICT, 'dialogwidth', 520)
    d.set_attribute(DICT, '_dialogwidth_label', 'DialogWidth')
  end

  def self.sichtbarkeit(d, wert, formel)
    d.set_attribute(DICT, 'hidden', wert ? 0.0 : 1.0)
    d.set_attribute(DICT, '_hidden_formula', formel)
    d.set_attribute(DICT, '_hidden_label', 'Hidden')
    d.set_attribute(DICT, '_hidden_formlabel', 'Hidden')
    d.set_attribute(DICT, '_hidden_units', 'BOOLEAN')
  end

  # OpenCutList: Materialtyp und Maße im Wörterbuch "ladb_opencutlist" am Material.
  # Bereits von OCL konfigurierte Materialien werden nicht verändert.
  def self.ocl_material(model, name, farbe, attribute)
    m = model.materials[name] || model.materials.add(name)
    m.color = Sketchup::Color.new(*farbe) unless m.texture || m.get_attribute(OCL_DICT, 'type')
    if m.get_attribute(OCL_DICT, 'type').to_i == 0
      attribute.each { |k, v| m.set_attribute(OCL_DICT, k, v) }
    end
    m
  end

  def self.material(model)
    ocl_material(model, MATERIAL, [255, 255, 255],
                 'type' => 2, # Plattenwerkstoff
                 'std_thicknesses' => '8mm;16mm;19mm',
                 'std_sizes' => '2800mm x 2070mm',
                 'grained' => false)
  end

  def self.kanten_material(model)
    @kante = ocl_material(model, KANTE, [245, 245, 240],
                          'type' => 4, # Kante/Anleimer
                          'thickness' => '2mm',
                          'std_widths' => '23mm',
                          'std_lengths' => '75m',
                          'edge_decremented' => true) # 2 mm werden nur in OCL abgezogen
  end

  # Halbtransparentes Material für den Platzhalter, ohne OCL-Einstellungen
  def self.geraet_material(model)
    m = model.materials[GERAET_MATERIAL]
    return m if m
    m = model.materials.add(GERAET_MATERIAL)
    m.color = Sketchup::Color.new(90, 140, 200)
    m.alpha = 0.4 if m.respond_to?(:alpha=)
    m
  end

  # Freies Kürzel für die Tags, z. B. USG1, USG2 …
  def self.freies_kuerzel(model)
    n = 1
    n += 1 while model.layers.to_a.any? { |l| l.name.start_with?("#{KUERZEL}#{n}_") }
    "#{KUERZEL}#{n}"
  end

  # Tag <Kürzel>_<Bereich>_<Teil> (z. B. USG1_Front) und JT_Schrank am Teil
  def self.kennzeichnen(model, inst, kz, teil, bereich = nil)
    name = [kz, bereich, teil].compact.join('_')
    inst.layer = model.layers[name] || model.layers.add(name)
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE, 'bereich' => bereich.to_s,
      'teil' => teil, 'rolle' => ROLLEN.fetch(teil.sub(/\d+\z/, '')) }.each { |k, v| inst.set_attribute(JT_DICT, k, v) }
    inst
  end

  SEITEN = { xmin: [0, -1], xmax: [0, 1], ymin: [1, -1], ymax: [1, 1], zmin: [2, -1], zmax: [2, 1] }.freeze

  # Sichtbare Kanten je Teil, bekommen in OCL einen Anleimer.
  # ymin = vorne, zmin/zmax = unten/oben, xmin/xmax = links/rechts.
  KANTEN = {
    'Front'  => %i[xmin xmax zmin zmax], # rundum
    'Wange'  => %i[ymin zmax],           # vorne und oben, unten steht sie auf dem Boden
    'Geraet' => []
  }.freeze

  # Quader in Endmaß zeichnen; die in "kanten" genannten Flächen bekommen das
  # Anleimer-Material (OCL erkennt Anleimer an der Material-Zuweisung der Kantenfläche).
  def self.quader(ents, lx, ly, lz, kanten = [])
    f = ents.add_face([0, 0, 0], [inch(lx), 0, 0], [inch(lx), inch(ly), 0], [0, inch(ly), 0])
    f.reverse! if f.normal.z < 0
    f.pushpull(inch(lz))
    return if kanten.empty?
    ents.grep(Sketchup::Face).each do |face|
      n = face.normal.to_a
      seite = SEITEN.find { |_, (ax, vz)| n[ax] * vz > 0.5 }&.first
      face.material = @kante if kanten.include?(seite)
    end
  end

  def self.platte(model, defname, dc_name, groesse, len_formeln, art: dc_name)
    d = model.definitions.add(defname)
    quader(d.entities, *groesse, KANTEN.fetch(art))
    stempel(d)
    d.set_attribute(DICT, '_name', dc_name)
    %w[x y z].each_with_index do |ax, idx|
      d.set_attribute(DICT, "len#{ax}", inch(groesse[idx]))
      next unless len_formeln[idx]
      d.set_attribute(DICT, "_len#{ax}_formula", len_formeln[idx])
      d.set_attribute(DICT, "_len#{ax}_label", "Len#{ax.upcase}")
    end
    d
  end

  # kz: [Modell, Kürzel, Teil, Bereich] -> Tag und JT_Schrank (siehe kennzeichnen)
  def self.einsetzen(ents, defn, inst_name, pos, pos_formeln, mat: nil, kz: nil, layer: nil)
    tr = Geom::Transformation.translation(Geom::Vector3d.new(*pos.map { |v| inch(v) }))
    inst = ents.add_instance(defn, tr)
    inst.name = inst_name
    inst.material = mat if mat
    kennzeichnen(kz[0], inst, *kz[1..]) if kz
    inst.layer = layer if layer
    inst.set_attribute(DICT, '_has_movetool_behaviors', 1.0)
    inst.set_attribute(DICT, '_hasbehaviors', 1.0)
    inst.set_attribute(DICT, '_iscollapsed', false)
    inst.set_attribute(DICT, '_lengthunits', 'CENTIMETERS')
    inst.set_attribute(DICT, '_name', inst_name)
    %w[x y z].each_with_index do |ax, idx|
      next unless pos_formeln[idx]
      inst.set_attribute(DICT, ax, inch(pos[idx]))
      inst.set_attribute(DICT, "_#{ax}_formula", pos_formeln[idx])
      inst.set_attribute(DICT, "_#{ax}_label", ax.upcase)
    end
    inst
  end

  # Nische für die Geräte-Komponenten: lichte Maße und Einfügepunkt (vorne links
  # unten auf dem Fußboden, an der Korpusvorderkante) in mm, Stand beim Erzeugen
  def self.nische(d, p, r)
    b = ((p['Breite'] - p['Geraet_Luft']) * 10).round(1)
    { 'nische' => 'N1', 'geraet' => "Geschirrspueler#{p['Breite'].round}",
      'breite' => b, 'hoehe' => (r[:h_unten] * 10).round(1), 'tiefe' => (p['Tiefe'] * 10).round(1),
      'x' => (r[:x_nische] * 10).round(1), 'y' => (p['Materialstaerke_Korpus'] * 10).round(1),
      'z' => (-p['Sockelhoehe'] * 10).round(1) }.each { |k, v| d.set_attribute(NISCHE_DICT, k, v) }
  end

  # ---------------------------------------------------------------------------
  # Aufbau
  # ---------------------------------------------------------------------------
  def self.erzeuge(model, eingabe = {})
    p = DEFAULTS.merge(eingabe)
    r = berechne(p)
    u = 'UnterschrankGeschirrspueler'
    mat = material(model)
    kanten_material(model)
    kz = p['Kuerzel'] || freies_kuerzel(model)
    t_ = ->(teil) { [model, kz, teil] }

    haupt = model.definitions.add(NAME)
    stempel(haupt)
    haupt.set_attribute(DICT, '_name', u)
    hilfe(haupt)
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE }.each { |k, v| haupt.set_attribute(JT_DICT, k, v) }
    nische(haupt, p, r)

    # --- Parameter (Komponentenoptionen) ---
    attribut(haupt, 'Breite', p['Breite'], access: 'LIST', formlabel: 'Nischenbreite',
             options: '&450%20mm=45&600%20mm=60&')
    attribut(haupt, 'Hoehe', p['Hoehe'], access: 'TEXTBOX', formlabel: 'Höhe (wie Korpus der Nachbarschränke)')
    attribut(haupt, 'Tiefe', p['Tiefe'], access: 'TEXTBOX', formlabel: 'Tiefe (wie Korpus der Nachbarschränke)')
    attribut(haupt, 'Fronthoehe', p['Fronthoehe'], access: 'TEXTBOX', formlabel: 'Fronthöhe (Oberkante bleibt)')
    attribut(haupt, 'Art_Wange', p['Art_Wange'], laenge: false, access: 'LIST', formlabel: 'Abschlusswange',
             units: 'INTEGER', options: '&Keine=0&Links=1&Rechts=2&Beide=3&')
    attribut(haupt, 'Sockelhoehe', p['Sockelhoehe'], access: 'TEXTBOX', formlabel: 'Sockelhöhe (Wange bis Boden)')

    # --- Feste Maße (über Komponentenattribute änderbar) ---
    %w[Materialstaerke_Korpus Materialstarke_Rueckwand Spaltbreite Geraet_Luft Geraet_Tiefe].each do |n|
      attribut(haupt, n, p[n], units: 'STRING')
    end

    # --- Abgeleitete Werte ---
    attribut(haupt, 'X_Nische', r[:x_nische], units: 'STRING',
             formula: 'IF(Art_Wange=1,Materialstaerke_Korpus,IF(Art_Wange=3,Materialstaerke_Korpus,0))')

    mk, sp = p['Materialstaerke_Korpus'], p['Spaltbreite']
    e = haupt.entities

    # --- Front: wie die Fronten der Unterschränke, Oberkante = Korpusoberkante ---
    front = platte(model, 'Front', 'Front', [r[:b_front], mk, p['Fronthoehe']],
                   ["#{u}!Breite-#{u}!Spaltbreite", "#{u}!Materialstaerke_Korpus", "#{u}!Fronthoehe"])
    # Aufklappen um die Unterkante (wie die Gerätetür)
    front.set_attribute(DICT, 'rotx', 0.0)
    front.set_attribute(DICT, 'onclick', 'ANIMATE("ROTX",0,90)')
    front.set_attribute(DICT, '_onclick_label', 'onClick')
    einsetzen(e, front, 'Front', [r[:x_nische] + sp / 2.0, -sp, r[:z_front]],
              ["#{u}!X_Nische+#{u}!Spaltbreite/2", "-#{u}!Spaltbreite", "#{u}!Hoehe-#{u}!Fronthoehe"],
              mat: mat, kz: t_.('Front'))

    # --- Abschlusswangen außerhalb der Nische, wie die Seiten der Unterschränke, bis zum Boden ---
    wangen = [['WangeL', r[:links], 'IF(OR(Art_Wange=1,Art_Wange=3),0,1)', [0, nil]],
              ['WangeR', r[:rechts], 'IF(OR(Art_Wange=2,Art_Wange=3),0,1)',
               [r[:x_nische] + p['Breite'], "#{u}!X_Nische+#{u}!Breite"]]]
    wangen.each do |teil, sichtbar, formel, (x, fx)|
      d = platte(model, teil, teil, [mk, p['Tiefe'] + p['Materialstarke_Rueckwand'], r[:h_unten]],
                 ["#{u}!Materialstaerke_Korpus", "#{u}!Tiefe+#{u}!Materialstarke_Rueckwand",
                  "#{u}!Hoehe+#{u}!Sockelhoehe"], art: 'Wange')
      sichtbarkeit(d, sichtbar, formel.gsub('Art_Wange', "#{u}!Art_Wange"))
      inst = einsetzen(e, d, teil, [x, mk, -p['Sockelhoehe']], [fx, nil, "-#{u}!Sockelhoehe"],
                       mat: mat, kz: t_.(teil))
      inst.hidden = !sichtbar
    end

    # --- Geräte-Platzhalter (kein Schrankteil: kein Plattenmaterial, kein JT_Schrank) ---
    g = platte(model, 'Geschirrspueler Platzhalter', 'Geraet',
               [p['Breite'] - p['Geraet_Luft'], p['Geraet_Tiefe'], r[:h_unten]],
               ["#{u}!Breite-#{u}!Geraet_Luft", "#{u}!Geraet_Tiefe", "#{u}!Hoehe+#{u}!Sockelhoehe"])
    tag = model.layers[GERAET_TAG] || model.layers.add(GERAET_TAG)
    einsetzen(e, g, 'Geraet', [r[:x_nische] + p['Geraet_Luft'] / 2.0, mk, -p['Sockelhoehe']],
              ["#{u}!X_Nische+#{u}!Geraet_Luft/2", nil, "-#{u}!Sockelhoehe"],
              mat: geraet_material(model), layer: tag)
    haupt
  end

  # ---------------------------------------------------------------------------
  # Erzeugen (mit ziel zusätzlich als .skp speichern)
  # ---------------------------------------------------------------------------
  # Neuer Schrank: Maße beim Anlegen abfragen, Tiefe = Korpus ohne Front/Rückwand. Danach bleiben sie im
  # Fenster Komponentenoptionen änderbar; alle abhängigen Teile folgen dort per Formel.
  TIEFE_NEU = 52.0 # cm, Vorschlag im Dialog

  def self.tiefe_min
    20.0
  end

  def self.dialog
    Kuechenplaner::Eingabe.abfragen(['Breite (mm)', 'Höhe (mm)', 'Tiefe Korpus (mm)'],
                      [(DEFAULTS['Breite'] * 10).round.to_s, (DEFAULTS['Hoehe'] * 10).round.to_s, (TIEFE_NEU * 10).round.to_s], ['450|600', '', ''], 'Unterschrank Geschirrspüler', untertitel: 'Neuer Schrank', ok: 'Einfügen') do |res|
      w = res.map { |v| v.to_s.tr(',', '.').to_f / 10.0 }
      eingabe = { 'Breite' => w[0], 'Hoehe' => w[1], 'Tiefe' => w[2] }
      t = eingabe['Tiefe']
      if t < tiefe_min - 0.000001
        raise ArgumentError, "Tiefe #{(t * 10).round} mm ist zu klein (mindestens 200 mm, mindestens #{(tiefe_min * 10).round} mm)"
      end
      raise ArgumentError, 'Maße müssen größer als 0 sein' if eingabe.values.any? { |v| v <= 0 }
      erstellen(eingabe)
    end
  rescue ArgumentError => e
    UI.messagebox("Ungültige Eingabe: #{e.message}")
  end

  def self.erstellen(eingabe = {}, ziel = nil)
    model = Sketchup.active_model
    model.start_operation('Unterschrank Geschirrspüler', true)
    defn = erzeuge(model, eingabe)
    x = model.entities.length > 0 ? model.bounds.max.x + 10.cm : 0
    inst = model.entities.add_instance(defn, Geom::Transformation.translation([x, 0, 0]))
    inst.name = NAME
    inst.set_attribute(DICT, '_name', 'UnterschrankGeschirrspueler')
    model.commit_operation

    if defined?($dc_observers) && $dc_observers
      $dc_observers.get_latest_class.redraw_with_undo(inst)
    end
    # Andock-Werkzeug (Schrank-CNC): neuen Schrank an Nachbarn oder Wand setzen
    Kuechenplaner.neuer_schrank(inst) if Kuechenplaner.respond_to?(:neuer_schrank)
    model.selection.clear
    model.selection.add(inst)

    if ziel
      if defn.respond_to?(:save_as) && defn.save_as(ziel)
        puts "Gespeichert: #{ziel}"
      else
        UI.messagebox('Automatisches Speichern ging nicht. Rechtsklick auf den Schrank → "Speichern unter…"')
      end
    end
    inst
  rescue StandardError => e
    model.abort_operation
    UI.messagebox("Fehler beim Erzeugen: #{e.message}")
    raise
  end
end

# Gemeinsames Untermenü "Erweiterungen > Küchenplaner" für alle Komponenten und
# den TCN-Export. Steht wortgleich in jeder Erweiterung (der Test prüft das), damit
# das Untermenü nur einmal angelegt wird, egal welche Erweiterungen geladen sind.
# Schränke kommen über Kuechenplaner.schrank('Unterschränke' | 'Oberschränke' |
# 'Hochschränke', titel) ins Menü und in die Schrank-Auswahl der Symbolleiste,
# Geräte und Raum in Kuechenplaner.untermenu('Geräte' | 'Raum'), Werkzeuge direkt in Kuechenplaner.menu darunter.
module Kuechenplaner
  GRUPPEN = ['Unterschränke', 'Oberschränke', 'Hochschränke', 'Geräte', 'Raum'].freeze

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
  Kuechenplaner.schrank('Unterschränke', 'Unterschrank Geschirrspüler…') { UnterschrankGeschirrspueler.dialog }
  file_loaded(__FILE__)
end
