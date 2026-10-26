# encoding: UTF-8
#
# Spülenschrank – erzeugt eine Dynamic Component und speichert sie als .skp
#
# Kein Plugin: einmal in der Ruby-Konsole laden, z. B.
#   load 'C:/Users/<Name>/Downloads/spuelenschrank.rb'
# Das Skript baut den Spülenschrank im aktuellen Modell und speichert ihn als
# "Spuelenschrank.skp" neben diese Datei. Danach wird das Skript nicht mehr
# gebraucht, die .skp ist eine normale Dynamic Component.
#
# Aufbau: Korpus wie der Unterschrank mit Tür (Seiten, Boden, Streben oben),
# aber mit Installationsebene: die Rückwand steht 50 mm vor der Hinterkante in
# einer Nut der Seiten, auf dem Boden, und hat einen rechteckigen Ausschnitt für
# die Wasser- und Abwasseranschlüsse. Keine Einlegeböden.
# Fronten: Türen (eine oder zwei) oder oben eine feste Blende (Spülbecken) und
# darunter ein Auszug Blum LEGRABOX für den Abfallsammler. Über dem Kasten
# bleibt unter der Blende Platz für den Siphon (Siphon_Freiraum).
#
# OpenCutList: Platten haben das Material "Melamin weiss" (Plattenwerkstoff),
# sichtbare Kanten das Material "Anleimer Melamin weiss" (Kante, 2 mm, wird nur
# in OCL abgezogen; gezeichnet wird das Endmaß). Jedes Teil hat einen eigenen Tag
# <Kürzel>_<Bereich>_<Teil> (z. B. USP1_SeiteL, USP1_A_Front) und das Wörterbuch
# "JT_Schrank" für den TCN-Export. Anderes Kürzel:
#   Spuelenschrank.erstellen({ 'Kuerzel' => 'USP2' }, ziel)

require 'sketchup.rb'

module Spuelenschrank

  DICT     = 'dynamic_attributes'.freeze
  NAME     = 'Spuelenschrank'.freeze
  MATERIAL = 'Melamin weiss'.freeze
  KANTE    = 'Anleimer Melamin weiss'.freeze
  OCL_DICT = 'ladb_opencutlist'.freeze
  KUERZEL  = 'USP'.freeze

  # Tag-Schema für den TCN-Export (gleich in allen Komponenten, der Test prüft das):
  # Tag <Kürzel>_<Bereich>_<Teil>, dazu am Teil das Wörterbuch JT_Schrank.
  JT_DICT   = 'JT_Schrank'.freeze
  TYP       = 'Spuelenschrank'.freeze
  KATEGORIE = 'Unterschrank'.freeze # Unterschrank, Oberschrank oder Hochschrank
  ROLLEN = {
    'SeiteL' => 'Seite', 'SeiteR' => 'Seite', 'Boden' => 'Boden', 'Deckel' => 'Deckel',
    'StrebeVorn' => 'Strebe', 'StrebeHinten' => 'Strebe',
    'ZwischenbodenUnten' => 'Zwischenboden', 'ZwischenbodenOben' => 'Zwischenboden',
    'Rueckwand' => 'Rueckwand', 'Einlegeboden' => 'Einlegeboden', 'Front' => 'Front',
    'Tuer' => 'Tuer', 'TuerL' => 'Tuer', 'TuerR' => 'Tuer',
    'KastenBoden' => 'KastenBoden', 'KastenRueckwand' => 'KastenRueckwand'
  }.freeze

  # Standardwerte in cm
  DEFAULTS = {
    'Breite'                    => 80.0,
    'Hoehe'                     => 70.0,
    'Tiefe'                     => 80.0,  # Korpus ohne Front (wie Unterschrank mit Tür)
    'Frontvariante'             => 1.0,   # 0 = Türen, 1 = Blende + Auszug
    'Art_Tuer'                  => 2.0,   # 1 = eine Tür (Anschlag links), 2 = zwei Türen
    'Hoehe_Blende'              => 20.0,
    'Siphon_Freiraum'           => 20.0,  # Unterkante Blende -> Oberkante Kasten, mindestens
    'Rueckwand_Versatz'         => 5.0,   # Installationsebene: Hinterkante Seite -> Rückseite Rückwand
    'Ausschnitt_Unten'          => 25.0,  # Rückwand-Ausschnitt: Unterkante über Unterkante Korpus
    'Ausschnitt_Hoehe'          => 40.0,  # 0 = kein Ausschnitt
    'Ausschnitt_Rand'           => 5.0,   # Steg links, rechts und oben
    'Materialstaerke_Korpus'    => 1.9,
    'Materialstarke_Rueckwand'  => 0.8,
    'Nuttiefe'                  => 0.9,
    'BreiteStreben'             => 10.0,
    'Spaltbreite'               => 0.2,
    # Auszug Blum LEGRABOX free wie im Unterschrank mit Schubladen
    'Materialstaerke_Kastenboden'     => 1.6,
    'Materialstaerke_Kastenrueckwand' => 1.6,
    'Hoehe_Kastenrueckwand'     => 14.8,
    'Hoehenoffset_Schiene'      => 0.0,
    'Lochraster_Start'          => 3.5,
    'Lochraster'                => 3.2,
    'Kasten_Abstand_unten'      => 3.0,
    'Auszug_Anteil'             => 0.8
  }.freeze

  # Kurzhilfe in der Komponente (Kurzfassung der README.md). SketchUp zeigt
  # "summary" und "description" oben im Fenster "Komponentenoptionen".
  DOKU_URL = 'https://github.com/jimmycd/sketchup_kuechenplaner2/tree/main/Komponenten/unterschrank_spuele'.freeze
  HILFE_KURZ = 'Spülenschrank mit Türen oder Blende + Auszug (Abfallsammler), Installationsebene, OpenCutList-fähig'.freeze
  HILFE = [
    'Breite, Höhe, Tiefe, Fronten (Türen oder Blende + Auszug), Anzahl Türen, Höhe Blende, Siphon-Freiraum, Installationsebene und Rückwand-Ausschnitt hier ändern.',
    'Rückwand 8 mm in einer 9 mm tiefen Nut der Seiten, steht auf dem Boden, 50 mm vor der Hinterkante (Installationsebene); Ausschnitt für die Anschlüsse (wird gefräst).',
    'Auszug: Blum LEGRABOX, Nennlänge aus der Tiefe bis zur Rückwand; unter der Blende bleibt der Siphon-Freiraum frei.',
    'Mit „Interagieren“ öffnen sich Türen und Auszug.',
    'Gezeichnet ist das Endmaß; den Anleimer (2 mm) zieht nur OpenCutList ab.',
    'Jedes Teil hat einen eigenen Tag <Kürzel>_<Bereich>_<Teil>, z. B. USP1_SeiteL, USP1_A_Front (Auszug), USP1_B_Front (Blende).',
    'Feste Maße (Materialstärken, Nut, Spalt, LEGRABOX): Fenster „Komponentenattribute“.',
    "Doku: #{DOKU_URL}"
  ].join(' ').freeze

  # ---------------------------------------------------------------------------
  # Reine Berechnung (ohne SketchUp), spiegelt die DC-Formeln. Werte in cm.
  # ---------------------------------------------------------------------------
  def self.berechne(p)
    mk, rw, sp = p['Materialstaerke_Korpus'], p['Materialstarke_Rueckwand'], p['Spaltbreite']
    b, h, t = p['Breite'], p['Hoehe'], p['Tiefe']
    t_innen = t - p['Rueckwand_Versatz'] - rw
    rand = p['Ausschnitt_Rand']
    a_unten = [p['Ausschnitt_Unten'], mk + rand].max
    ab = kasten_unten(p)
    z_max = h - p['Hoehe_Blende'] - p['Siphon_Freiraum'] # höchste Oberkante Kasten
    {
      t_innen: t_innen,                                  # Vorderkante Korpus -> Vorderseite Rückwand
      b_tuer1: b - sp,
      b_tuer2: b / 2.0 - sp,
      h_auszug: h - p['Hoehe_Blende'] - sp,              # Front des Auszugs
      nl: nennlaenge(t_innen),
      ab: ab,                                            # Unterkante Kasten
      hrw: [[p['Hoehe_Kastenrueckwand'], z_max - ab - p['Materialstaerke_Kastenboden']].min, 2.0].max,
      a_unten: a_unten,
      a_hoehe: [[p['Ausschnitt_Hoehe'], h - rand - a_unten].min, 0.0].max,
      a_breite: b - 2 * mk - 2 * rand
    }
  end

  # Nennlänge der LEGRABOX-Schiene (cm) zur lichten Tiefe (cm): größte NL (35 … 65) mit NL + 3 mm <= Tiefe
  def self.nennlaenge(tiefe)
    [65.0, ((tiefe - 0.3) / 5.0 + 0.000001).floor * 5.0].min
  end

  def self.f_nennlaenge(tiefe)
    "MIN(65,INT((#{tiefe}-0.3)/5+0.000001)*5)"
  end

  # Unterkante Kasten über Unterkante Front (= Unterkante Korpus): mindestens Kasten_Abstand_unten
  # und so, dass die Schienenbohrung auf dem Lochraster der Seite liegt (wie Unterschrank mit Schubladen)
  def self.kasten_unten(p)
    st, ra, off = p['Lochraster_Start'], p['Lochraster'], p['Hoehenoffset_Schiene']
    n = ((p['Kasten_Abstand_unten'] + off - st) / ra - 0.0001).ceil
    st + ra * n - off
  end

  def self.f_kasten_unten
    u = NAME
    "#{u}!Lochraster_Start+#{u}!Lochraster*(-INT(-((#{u}!Kasten_Abstand_unten+#{u}!Hoehenoffset_Schiene" \
      "-#{u}!Lochraster_Start)/#{u}!Lochraster-0.0001)))-#{u}!Hoehenoffset_Schiene"
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
    ent.set_attribute(DICT, "_#{k}_options", options || '')
    ent.set_attribute(DICT, "_#{k}_formula", formula) if formula
  end

  # Kurzhilfe als Komponenten-Info ("Summary"/"Description") und an der Definition
  def self.hilfe(d)
    d.description = HILFE_KURZ
    { 'summary' => ['Summary', HILFE_KURZ], 'description' => ['Description', HILFE] }.each do |k, (label, text)|
      d.set_attribute(DICT, k, text)
      d.set_attribute(DICT, "_#{k}_label", label)
      d.set_attribute(DICT, "_#{k}_formlabel", label)
      d.set_attribute(DICT, "_#{k}_access", 'VIEW')
      d.set_attribute(DICT, "_#{k}_units", 'STRING')
    end
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

  # Freies Kürzel für die Tags, z. B. USP1, USP2 …
  def self.freies_kuerzel(model)
    n = 1
    n += 1 while model.layers.to_a.any? { |l| l.name.start_with?("#{KUERZEL}#{n}_") }
    "#{KUERZEL}#{n}"
  end

  def self.tag(model, name)
    model.layers[name] || model.layers.add(name)
  end

  # Tag <Kürzel>_<Bereich>_<Teil> (z. B. USP1_A_Front) und JT_Schrank am Teil
  def self.kennzeichnen(model, inst, kz, teil, bereich = nil)
    inst.layer = tag(model, [kz, bereich, teil].compact.join('_'))
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE, 'bereich' => bereich.to_s,
      'teil' => teil, 'rolle' => ROLLEN.fetch(teil.sub(/\d+\z/, '')) }.each { |k, v| inst.set_attribute(JT_DICT, k, v) }
    inst
  end

  SEITEN = { xmin: [0, -1], xmax: [0, 1], ymin: [1, -1], ymax: [1, 1], zmin: [2, -1], zmax: [2, 1] }.freeze

  # Sichtbare Kanten je Teil, bekommen in OCL einen Anleimer.
  # ymin = vorne, zmin/zmax = unten/oben, xmin/xmax = links/rechts.
  KANTEN = {
    'Seite'           => %i[ymin],
    'Boden'           => %i[ymin],
    'StrebeVorn'      => %i[ymin],
    'StrebeHinten'    => [],
    'Rückwand'        => [],
    'Front'           => %i[xmin xmax zmin zmax], # Blende und Auszug
    'Tür'             => %i[xmin xmax zmin zmax],
    'KastenBoden'     => [],
    'KastenRueckwand' => %i[zmax]
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
    inst.layer = layer if layer
    kennzeichnen(kz[0], inst, *kz[1..]) if kz
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

  # ---------------------------------------------------------------------------
  # Aufbau
  # ---------------------------------------------------------------------------
  def self.erzeuge(model, eingabe = {})
    p = DEFAULTS.merge(eingabe)
    r = berechne(p)
    u = NAME
    mat = material(model)
    kanten_material(model)
    kz = p['Kuerzel'] || freies_kuerzel(model)
    t_ = ->(teil, bereich = nil) { [model, kz, teil, bereich] }

    haupt = model.definitions.add(NAME)
    stempel(haupt)
    haupt.set_attribute(DICT, '_name', u)
    hilfe(haupt)
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE }.each { |k, v| haupt.set_attribute(JT_DICT, k, v) }

    # --- Parameter (Komponentenoptionen) ---
    attribut(haupt, 'Breite', p['Breite'], access: 'TEXTBOX', formlabel: 'Breite')
    attribut(haupt, 'Hoehe', p['Hoehe'], access: 'TEXTBOX', formlabel: 'Höhe')
    attribut(haupt, 'Tiefe', p['Tiefe'], access: 'TEXTBOX', formlabel: 'Tiefe (Korpus ohne Front)')
    attribut(haupt, 'Frontvariante', p['Frontvariante'], laenge: false, access: 'LIST', formlabel: 'Fronten',
             units: 'INTEGER', options: '&T%C3%BCren=0&Blende%20%2B%20Auszug=1&')
    attribut(haupt, 'Art_Tuer', p['Art_Tuer'], laenge: false, access: 'LIST', formlabel: 'Türen (bei Fronten = Türen)',
             units: 'INTEGER', options: '&Eine%20T%C3%BCr%20(Anschlag%20links)=1&Zwei%20T%C3%BCren=2&')
    attribut(haupt, 'Hoehe_Blende', p['Hoehe_Blende'], access: 'TEXTBOX', formlabel: 'Höhe Blende (bei Auszug)')
    attribut(haupt, 'Siphon_Freiraum', p['Siphon_Freiraum'], access: 'TEXTBOX',
             formlabel: 'Siphon-Freiraum unter der Blende (bei Auszug)')
    attribut(haupt, 'Rueckwand_Versatz', p['Rueckwand_Versatz'], access: 'TEXTBOX',
             formlabel: 'Installationsebene (Rückwand vor der Hinterkante)')
    attribut(haupt, 'Ausschnitt_Unten', p['Ausschnitt_Unten'], access: 'TEXTBOX',
             formlabel: 'Rückwand-Ausschnitt: Unterkante über Korpus-Unterkante')
    attribut(haupt, 'Ausschnitt_Hoehe', p['Ausschnitt_Hoehe'], access: 'TEXTBOX',
             formlabel: 'Rückwand-Ausschnitt: Höhe (0 = keiner)')
    attribut(haupt, 'Ausschnitt_Rand', p['Ausschnitt_Rand'], access: 'TEXTBOX',
             formlabel: 'Rückwand-Ausschnitt: Steg seitlich und oben')

    # --- Feste Maße (über Komponentenattribute änderbar) ---
    %w[Materialstaerke_Korpus Materialstarke_Rueckwand Nuttiefe BreiteStreben Spaltbreite
       Materialstaerke_Kastenboden Materialstaerke_Kastenrueckwand Hoehe_Kastenrueckwand Hoehenoffset_Schiene
       Lochraster_Start Lochraster Kasten_Abstand_unten].each do |n|
      attribut(haupt, n, p[n], units: 'STRING')
    end
    attribut(haupt, 'Auszug_Anteil', p['Auszug_Anteil'], laenge: false, units: 'STRING')

    # --- Abgeleitete Werte ---
    attribut(haupt, 'T_Innen', r[:t_innen], units: 'STRING', formula: 'Tiefe-Rueckwand_Versatz-Materialstarke_Rueckwand')
    attribut(haupt, 'B_Tuer2', r[:b_tuer2], units: 'STRING', formula: 'Breite/2-Spaltbreite')
    attribut(haupt, 'H_Auszug', r[:h_auszug], units: 'STRING', formula: 'Hoehe-Hoehe_Blende-Spaltbreite')
    # Nennlänge der LEGRABOX-Schiene aus der lichten Tiefe bis zur Rückwand
    attribut(haupt, 'NL', r[:nl], units: 'STRING', formula: f_nennlaenge('T_Innen'))
    attribut(haupt, 'A_Unten', r[:a_unten], units: 'STRING',
             formula: 'MAX(Ausschnitt_Unten,Materialstaerke_Korpus+Ausschnitt_Rand)')
    attribut(haupt, 'A_Hoehe', r[:a_hoehe], units: 'STRING',
             formula: 'MAX(MIN(Ausschnitt_Hoehe,Hoehe-Ausschnitt_Rand-A_Unten),0)')

    mk = p['Materialstaerke_Korpus']
    b, h, t = p['Breite'], p['Hoehe'], p['Tiefe']
    rw, sp, nut, bs = p['Materialstarke_Rueckwand'], p['Spaltbreite'], p['Nuttiefe'], p['BreiteStreben']
    e = haupt.entities
    innen_b = "#{u}!Breite-2*#{u}!Materialstaerke_Korpus"

    # --- Korpus (beginnt wie die anderen Schränke bei y = Materialstärke) ---
    seite = platte(model, 'Seite', 'Seite', [mk, t, h],
                   ["#{u}!Materialstaerke_Korpus", "#{u}!Tiefe", "#{u}!Hoehe"])
    einsetzen(e, seite, 'SeiteL', [0, mk, 0], [nil, nil, nil], mat: mat, kz: t_.('SeiteL'))
    einsetzen(e, seite, 'SeiteR', [b - mk, mk, 0],
              ["#{u}!Breite-#{u}!Materialstaerke_Korpus", nil, nil], mat: mat, kz: t_.('SeiteR'))

    boden = platte(model, 'Boden', 'Boden', [b - 2 * mk, t, mk], [innen_b, "#{u}!Tiefe", "#{u}!Materialstaerke_Korpus"])
    einsetzen(e, boden, 'Boden', [mk, mk, 0], ["#{u}!Materialstaerke_Korpus", nil, nil], mat: mat, kz: t_.('Boden'))

    strebe_formeln = [innen_b, "#{u}!BreiteStreben", "#{u}!Materialstaerke_Korpus"]
    strebe_v = platte(model, 'StrebeV', 'StrebeVorn', [b - 2 * mk, bs, mk], strebe_formeln)
    einsetzen(e, strebe_v, 'StrebeVorn', [mk, mk, h - mk],
              ["#{u}!Materialstaerke_Korpus", nil, "#{u}!Hoehe-#{u}!Materialstaerke_Korpus"],
              mat: mat, kz: t_.('StrebeVorn'))
    # Strebe hinten endet an der Rückwand
    strebe_h = platte(model, 'StrebeH', 'StrebeHinten', [b - 2 * mk, bs, mk], strebe_formeln)
    einsetzen(e, strebe_h, 'StrebeHinten', [mk, mk + r[:t_innen] - bs, h - mk],
              ['StrebeVorn!X', "#{u}!Materialstaerke_Korpus+#{u}!T_Innen-#{u}!BreiteStreben", 'StrebeVorn!Z'],
              mat: mat, kz: t_.('StrebeHinten'))

    rueckwand(model, e, p, r, mat, kz)
    tueren(model, e, p, r, mat, t_)
    blende_und_auszug(model, e, p, r, mat, kz)
    haupt
  end

  # Rückwand in der Nut beider Seiten, steht auf dem Boden, oben bündig.
  # Der Ausschnitt steht als Attribut an der Rückwand (Lage in der Rückwand, cm),
  # daraus fräst der TCN-Export die Kontur; sichtbar ist er als Umriss davor.
  def self.rueckwand(model, e, p, r, mat, kz)
    u = NAME
    mk, rw, nut, rand = p['Materialstaerke_Korpus'], p['Materialstarke_Rueckwand'], p['Nuttiefe'], p['Ausschnitt_Rand']
    b, h = p['Breite'], p['Hoehe']
    d = platte(model, 'Rückwand', 'Rückwand', [b - 2 * mk + 2 * nut, rw, h - mk],
               ["#{u}!Breite-2*#{u}!Materialstaerke_Korpus+2*#{u}!Nuttiefe", "#{u}!Materialstarke_Rueckwand",
                "#{u}!Hoehe-#{u}!Materialstaerke_Korpus"])
    attribut(d, 'Ausschnitt_X', nut + rand, units: 'STRING', formula: "#{u}!Nuttiefe+#{u}!Ausschnitt_Rand")
    attribut(d, 'Ausschnitt_Z', r[:a_unten] - mk, units: 'STRING', formula: "#{u}!A_Unten-#{u}!Materialstaerke_Korpus")
    attribut(d, 'Ausschnitt_B', r[:a_breite], units: 'STRING', formula: "#{u}!Breite-2*#{u}!Materialstaerke_Korpus-2*#{u}!Ausschnitt_Rand")
    attribut(d, 'Ausschnitt_H', r[:a_hoehe], units: 'STRING', formula: "#{u}!A_Hoehe")
    y_rw = mk + r[:t_innen]
    einsetzen(e, d, 'Rückwand', [mk - nut, y_rw, mk],
              ["#{u}!Materialstaerke_Korpus-#{u}!Nuttiefe", "#{u}!Materialstaerke_Korpus+#{u}!T_Innen",
               "#{u}!Materialstaerke_Korpus"], mat: mat, kz: [model, kz, 'Rueckwand'])

    # Umriss des Ausschnitts (nur Kanten, keine Fläche: kein Teil für OpenCutList)
    a = model.definitions.add('Rückwand Ausschnitt')
    stempel(a)
    a.set_attribute(DICT, '_name', 'Ausschnitt')
    # ohne Ausschnitt (Höhe 0) wird ein flacher Umriss gezeichnet und ausgeblendet
    lx, lz = inch(r[:a_breite]), inch([r[:a_hoehe], 1.0].max)
    a.entities.add_line([0, 0, 0], [lx, 0, 0])
    a.entities.add_line([lx, 0, 0], [lx, 0, lz])
    a.entities.add_line([lx, 0, lz], [0, 0, lz])
    a.entities.add_line([0, 0, lz], [0, 0, 0])
    { 'lenx' => [r[:a_breite], "#{u}!Breite-2*#{u}!Materialstaerke_Korpus-2*#{u}!Ausschnitt_Rand"],
      'lenz' => [r[:a_hoehe], "#{u}!A_Hoehe"] }.each do |k, (wert, f)|
      a.set_attribute(DICT, k, inch(wert))
      a.set_attribute(DICT, "_#{k}_formula", f)
      a.set_attribute(DICT, "_#{k}_label", k.capitalize)
    end
    sichtbarkeit(a, r[:a_hoehe] > 0, "IF(#{u}!A_Hoehe>0,0,1)")
    ia = einsetzen(e, a, 'Ausschnitt', [mk + rand, y_rw - 0.05, r[:a_unten]],
                   ["#{u}!Materialstaerke_Korpus+#{u}!Ausschnitt_Rand", "#{u}!Materialstaerke_Korpus+#{u}!T_Innen-0.05",
                    "#{u}!A_Unten"], layer: tag(model, "#{kz}_Rueckwand_Ausschnitt"))
    ia.hidden = r[:a_hoehe] <= 0
  end

  # Türen über die volle Höhe (wie die Fronten im Unterschrank mit Schubladen):
  # eine (Anschlag links) oder zwei, nur bei Frontvariante 0
  def self.tueren(model, e, p, r, mat, t_)
    u = NAME
    sp, mk, b, h = p['Spaltbreite'], p['Materialstaerke_Korpus'], p['Breite'], p['Hoehe']
    tuer = p['Frontvariante'].to_i == 0
    art = p['Art_Tuer'].to_i
    h_f = "#{u}!Hoehe"

    t1 = platte(model, 'Tür', 'Tür', [r[:b_tuer1], mk, h],
                ["#{u}!Breite-#{u}!Spaltbreite", "#{u}!Materialstaerke_Korpus", h_f])
    tuer_drehen(t1, tuer && art == 1, "IF(AND(#{u}!Frontvariante=0,#{u}!Art_Tuer=1),0,1)", -100)
    i1 = einsetzen(e, t1, 'Tür', [sp / 2.0, -sp, 0],
                   ["#{u}!Spaltbreite/2", "-#{u}!Spaltbreite", nil], mat: mat, kz: t_.('Tuer'))
    i1.hidden = !(tuer && art == 1)

    zwei = "IF(AND(#{u}!Frontvariante=0,#{u}!Art_Tuer=2),0,1)"
    tl = platte(model, 'Tür links', 'TürL', [r[:b_tuer2], mk, h],
                ["#{u}!B_Tuer2", "#{u}!Materialstaerke_Korpus", h_f], art: 'Tür')
    tuer_drehen(tl, tuer && art == 2, zwei, -100)
    il = einsetzen(e, tl, 'TürL', [sp / 2.0, -sp, 0],
                   ["#{u}!Spaltbreite/2", "-#{u}!Spaltbreite", nil], mat: mat, kz: t_.('TuerL'))
    il.hidden = !(tuer && art == 2)

    # rechts: Drehpunkt muss rechts liegen, deshalb steckt die Tür in einem
    # Halter am Scharnier und liegt darin bei x = -Breite der Tür
    halter = model.definitions.add('Tür rechts Halter')
    stempel(halter)
    halter.set_attribute(DICT, '_name', 'TuerRHalter')
    attribut(halter, 'B_Tuer', r[:b_tuer2], units: 'STRING', formula: "#{u}!B_Tuer2")
    attribut(halter, 'H_Tuer', h, units: 'STRING', formula: h_f)
    attribut(halter, 'Mk', mk, units: 'STRING', formula: "#{u}!Materialstaerke_Korpus")
    tuer_drehen(halter, tuer && art == 2, zwei, 100)
    hn = 'TuerRHalter'
    tr = platte(model, 'Tür rechts', 'TürR', [r[:b_tuer2], mk, h],
                ["#{hn}!B_Tuer", "#{hn}!Mk", "#{hn}!H_Tuer"], art: 'Tür')
    einsetzen(halter.entities, tr, 'TürR', [-r[:b_tuer2], 0, 0], ["-#{hn}!B_Tuer", nil, nil], mat: mat, kz: t_.('TuerR'))
    ih = einsetzen(e, halter, hn, [b - sp / 2.0, -sp, 0],
                   ["#{u}!Breite-#{u}!Spaltbreite/2", "-#{u}!Spaltbreite", nil])
    ih.hidden = !(tuer && art == 2)
  end

  def self.tuer_drehen(d, sichtbar, formel, winkel)
    sichtbarkeit(d, sichtbar, formel)
    d.set_attribute(DICT, 'rotz', 0.0)
    d.set_attribute(DICT, 'onclick', "ANIMATE(\"ROTZ\",0,#{winkel})")
    d.set_attribute(DICT, '_onclick_label', 'onClick')
  end

  # Frontvariante 1: oben feste Blende (Bereich B), darunter ein Auszug (Bereich A) mit
  # Blum LEGRABOX: Front, Boden (LW-35 x NL-10) und Holzrückwand (LW-38, höchstens 148 mm
  # und so, dass unter der Blende Siphon_Freiraum frei bleibt); die Zargen sind aus Metall.
  def self.blende_und_auszug(model, e, p, r, mat, kz)
    u = NAME
    sp, mk, b, h = p['Spaltbreite'], p['Materialstaerke_Korpus'], p['Breite'], p['Hoehe']
    auszug = p['Frontvariante'].to_i == 1
    hb = p['Hoehe_Blende']
    formel = "IF(#{u}!Frontvariante=1,0,1)"

    bl = platte(model, 'Blende', 'Blende', [b - sp, mk, hb],
                ["#{u}!Breite-#{u}!Spaltbreite", "#{u}!Materialstaerke_Korpus", "#{u}!Hoehe_Blende"], art: 'Front')
    sichtbarkeit(bl, auszug, formel)
    ib = einsetzen(e, bl, 'Blende', [sp / 2.0, -sp, h - hb],
                   ["#{u}!Spaltbreite/2", "-#{u}!Spaltbreite", "#{u}!Hoehe-#{u}!Hoehe_Blende"],
                   mat: mat, kz: [model, kz, 'Front', 'B'])
    ib.hidden = !auszug

    s = 'Auszug'
    mb, mrw, nl = p['Materialstaerke_Kastenboden'], p['Materialstaerke_Kastenrueckwand'], r[:nl]
    lw = b - 2 * mk
    d = model.definitions.add(s)
    stempel(d)
    d.set_attribute(DICT, '_name', s)
    # Lokale Kopien der Werte vom Schrank (Formeln können nur Eltern/Geschwister ansprechen)
    attribut(d, 'Breite', b, units: 'STRING', formula: "#{u}!Breite")
    attribut(d, 'Hoehe_Front', r[:h_auszug], units: 'STRING', formula: "#{u}!H_Auszug")
    attribut(d, 'Mk', mk, units: 'STRING', formula: "#{u}!Materialstaerke_Korpus")
    attribut(d, 'Spalt', sp, units: 'STRING', formula: "#{u}!Spaltbreite")
    attribut(d, 'Mb', mb, units: 'STRING', formula: "#{u}!Materialstaerke_Kastenboden")
    attribut(d, 'Mrw', mrw, units: 'STRING', formula: "#{u}!Materialstaerke_Kastenrueckwand")
    attribut(d, 'NL', nl, units: 'STRING', formula: "#{u}!NL")
    attribut(d, 'Ab_unten', r[:ab], units: 'STRING', formula: f_kasten_unten)
    # Höhe Holzrückwand: höchstens Hoehe_Kastenrueckwand, Oberkante Kasten Siphon_Freiraum unter der Blende
    attribut(d, 'Hrw', r[:hrw], units: 'STRING',
             formula: "MAX(MIN(#{u}!Hoehe_Kastenrueckwand,#{u}!Hoehe-#{u}!Hoehe_Blende-#{u}!Siphon_Freiraum" \
                      "-Ab_unten-Mb),2)")
    attribut(d, 'Auszug', nl * p['Auszug_Anteil'], units: 'STRING', formula: "#{u}!NL*#{u}!Auszug_Anteil")
    sichtbarkeit(d, auszug, formel)
    # Mit "Interagieren" anklicken -> Auszug fährt heraus
    d.set_attribute(DICT, 'onclick', 'ANIMATE("Y",0,-Auszug)')
    d.set_attribute(DICT, '_onclick_label', 'onClick')

    de = d.entities
    st = ->(teil) { [model, kz, teil, 'A'] }
    front = platte(model, 'Front Auszug', 'Front', [b - sp, mk, r[:h_auszug]],
                   ["#{s}!Breite-#{s}!Spalt", "#{s}!Mk", "#{s}!Hoehe_Front"])
    einsetzen(de, front, 'Front', [sp / 2.0, -sp, 0], ["#{s}!Spalt/2", "-#{s}!Spalt", nil], mat: mat, kz: st.('Front'))

    kbod = platte(model, 'Kasten Boden Auszug', 'KastenBoden', [lw - 3.5, nl - 1.0, mb],
                  ["#{s}!Breite-2*#{s}!Mk-3.5", "#{s}!NL-1", "#{s}!Mb"])
    einsetzen(de, kbod, 'KastenBoden', [mk + 1.75, mk, r[:ab]],
              ["#{s}!Mk+1.75", "#{s}!Mk", "#{s}!Ab_unten"], mat: mat, kz: st.('KastenBoden'))

    krw = platte(model, 'Kasten Rueckwand Auszug', 'KastenRueckwand', [lw - 3.8, mrw, r[:hrw]],
                 ["#{s}!Breite-2*#{s}!Mk-3.8", "#{s}!Mrw", "#{s}!Hrw"])
    einsetzen(de, krw, 'KastenRueckwand', [mk + 1.9, mk + nl - 1.0 - mrw, r[:ab] + mb],
              ["#{s}!Mk+1.9", "#{s}!Mk+#{s}!NL-1-#{s}!Mrw", "#{s}!Ab_unten+#{s}!Mb"],
              mat: mat, kz: st.('KastenRueckwand'))

    inst = einsetzen(e, d, s, [0, 0, 0], [nil, nil, nil], layer: tag(model, "#{kz}_A_Auszug"))
    inst.hidden = !auszug
    inst
  end

  # ---------------------------------------------------------------------------
  # Erzeugen + als .skp speichern
  # ---------------------------------------------------------------------------
  def self.erstellen(eingabe = {}, ziel = nil)
    model = Sketchup.active_model
    model.start_operation('Spülenschrank', true)
    defn = erzeuge(model, eingabe)
    x = model.entities.length > 0 ? model.bounds.max.x + 10.cm : 0
    inst = model.entities.add_instance(defn, Geom::Transformation.translation([x, 0, 0]))
    inst.name = NAME
    inst.set_attribute(DICT, '_name', NAME)
    model.commit_operation

    if defined?($dc_observers) && $dc_observers
      $dc_observers.get_latest_class.redraw_with_undo(inst)
    end
    model.selection.clear
    model.selection.add(inst)

    if ziel
      if defn.respond_to?(:save_as) && defn.save_as(ziel)
        puts "Gespeichert: #{ziel}"
      else
        UI.messagebox('Automatisches Speichern ging nicht. Rechtsklick auf den Spülenschrank → "Speichern unter…"')
      end
    end
    inst
  rescue StandardError => e
    model.abort_operation
    UI.messagebox("Fehler beim Erzeugen: #{e.message}")
    raise
  end
end

# Beim Laden in der Ruby-Konsole direkt erzeugen und speichern
unless defined?($SPUELENSCHRANK_TEST)
  Spuelenschrank.erstellen({}, File.join(File.dirname(File.expand_path(__FILE__)), 'Spuelenschrank.skp'))
end
