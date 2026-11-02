# encoding: UTF-8
#
# Oberschrank Dunstabzug – erzeugt eine Dynamic Component
#
# Erweiterung (.rbz): Erweiterungen > Küchenplaner > Oberschränke > Oberschrank Dunstabzug baut
# den Schrank im aktuellen Modell. Maße und Optionen danach in den Komponentenoptionen einstellen.
#
# Oberschrank für eine Flachschirmhaube, die unten in den Schrank eingebaut wird:
# Seiten über die volle Höhe, KEIN Boden unten (Raum für die Haube), darüber der
# Haubenboden (Teil "Boden", Rolle Boden: die Rückwand steht in seiner Nut wie beim
# Oberschrank), Deckel vor der Rückwand, Strebe hinten unten zwischen den Seiten.
# Rückwand 8 mm nur vom Haubenboden bis oben. Abluftrohr: rechteckiger Ausschnitt
# in Haubenboden, Deckel und Einlegeboden; er steht als Attribut Ausschnitt_X/_Y/_B/_T
# (cm, Lage auf der Platte ab vorne links) an der Platte, der TCN-Export fräst ihn.
# In SketchUp ist die Platte voll gezeichnet, der Ausschnitt ist als Umriss darüber zu sehen.
# Bei Umluft (Abluft = 0) gibt es keinen Ausschnitt.
#
# Material: Platten "Melamin weiss", sichtbare Kanten "Anleimer Melamin weiss"
# (2 mm, wird erst in der Stückliste/im Zuschnitt abgezogen; gezeichnet wird das Endmaß).
# Jedes Teil hat einen eigenen Tag <Kürzel>_<Teil> (z. B. OSD1_SeiteL, OSD1_Boden) und das
# Wörterbuch "JT_Schrank". Am Schrank steht die Gerätenische "JT_Nische" (Flachschirmhaube)
# für "Geräte in Schränke setzen".

require 'sketchup.rb'

module OberschrankDunstabzug

  DICT     = 'dynamic_attributes'.freeze
  NAME     = 'Oberschrank Dunstabzug'.freeze
  DC_NAME  = 'OberschrankDunstabzug'.freeze # Name in den DC-Formeln (ohne Leerzeichen)
  MAX_EB   = 1
  MATERIAL = 'Melamin weiss'.freeze
  KANTE    = 'Anleimer Melamin weiss'.freeze
  OCL_DICT = 'ladb_opencutlist'.freeze # Material-Daten in diesem Format liest auch das eigene Plugin
  KUERZEL  = 'OSD'.freeze
  NISCHE_DICT = 'JT_Nische'.freeze

  # Tag-Schema für den TCN-Export (gleich in allen Komponenten, der Test prüft das):
  # Tag <Kürzel>_<Bereich>_<Teil>, dazu am Teil das Wörterbuch JT_Schrank.
  JT_DICT   = 'JT_Schrank'.freeze
  TYP       = 'OberschrankDunstabzug'.freeze
  KATEGORIE = 'Oberschrank'.freeze # Unterschrank, Oberschrank oder Hochschrank
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

  # Standardwerte in cm
  DEFAULTS = {
    'Breite'                    => 60.0,
    'Hoehe'                     => 70.0,
    'Tiefe'                     => 40.0,  # Korpus ohne Front
    'Art_Tuer'                  => 2.0,   # 1 = eine Tür (Anschlag links), 2 = zwei Türen
    'Anz_Einlegeboeden'         => 0.0,   # 0 oder 1, über dem Haubenboden
    'Haube_Hoehe'               => 38.0,  # Unterkante Schrank -> Unterseite Haubenboden
    'Abluft'                    => 1.0,   # 1 = Abluft (Rohrausschnitt), 0 = Umluft
    'Rohr_Breite'               => 17.0,  # Ausschnitt quer (Rundrohr Ø150 + Luft)
    'Rohr_Tiefe'                => 17.0,  # Ausschnitt in der Tiefe
    'Rohr_Abstand_Hinten'       => 2.0,   # Vorderseite Rückwand -> Hinterkante Ausschnitt
    'Tuer_Frei_Unten'           => 0.0,   # Türen enden so weit über der Unterkante (Blende Wrasenschirm)
    'Materialstaerke_Korpus'    => 1.9,
    'Materialstarke_Rueckwand'  => 0.8,
    'Rueckwand_Versatz'         => 2.5,   # Hinterkante Seite -> Rückseite Rückwand
    'Nuttiefe'                  => 0.9,
    'Spaltbreite'               => 0.2,
    'Rueckversatz_Einlegeboden' => 1.0,   # Einlegeboden vorne zurückgesetzt
    'Strebe_Hoehe'              => 8.0    # Strebe hinten unten, hochkant
  }.freeze

  # Kurzhilfe in der Komponente (Kurzfassung der README.md). SketchUp zeigt
  # "summary" und "description" oben im Fenster "Komponentenoptionen".
  DOKU_URL = 'https://github.com/jimmycd/sketchup_kuechenplaner2/tree/main/Komponenten/oberschrank_dunstabzug'.freeze
  HILFE_KURZ = 'Oberschrank für eine Flachschirmhaube: unten offen, Haubenboden und Deckel mit Ausschnitt für das Abluftrohr'.freeze
  HILFE = [
    'Breite, Höhe, Tiefe (Korpus ohne Front), Türen, Höhe des Haubenraums, Abluft/Umluft, Größe und Lage des Rohrausschnitts,',
    'Einlegeboden (0 oder 1) und unten frei gelassene Höhe der Türen (Blende des Wrasenschirms) hier ändern.',
    'Unten ist kein Boden: dort sitzt die Haube. Darüber der Haubenboden; die Rückwand (8 mm, in der Nut) geht vom Haubenboden bis oben.',
    'Der Rohrausschnitt in Haubenboden, Deckel und Einlegeboden wird gefräst (TCN), in SketchUp ist er als Umriss zu sehen.',
    'Gezeichnet ist das Endmaß; den Anleimer (2 mm) ziehen Stückliste und Zuschnitt ab.',
    'Jedes Teil hat einen eigenen Tag <Kürzel>_<Teil>, z. B. OSD1_SeiteL, OSD1_Boden.',
    'Feste Maße (Materialstärken, Versatz, Nut, Spalt, Strebe): Fenster „Komponentenattribute“.',
    "Doku: #{DOKU_URL}"
  ].join(' ').freeze

  # ---------------------------------------------------------------------------
  # Reine Berechnung (ohne SketchUp), spiegelt die DC-Formeln. Werte in cm.
  # ---------------------------------------------------------------------------
  def self.berechne(p)
    mk, rw, sp = p['Materialstaerke_Korpus'], p['Materialstarke_Rueckwand'], p['Spaltbreite']
    b, h, t = p['Breite'], p['Hoehe'], p['Tiefe']
    hh = p['Haube_Hoehe']
    t_innen = t - p['Rueckwand_Versatz'] - rw
    frei = p['Tuer_Frei_Unten']
    abluft = p['Abluft'].to_i == 1
    {
      t_innen: t_innen, # Vorderkante Korpus -> Vorderseite Rückwand
      b_tuer1: b - sp,
      b_tuer2: b / 2.0 - sp,
      z_tuer: sp / 2.0 + frei,
      h_tuer: h - sp - frei,
      z_eb: (hh + mk + h - mk) / 2.0 - mk / 2.0, # Mitte des Fachs über dem Haubenboden
      a_x: (b - 2 * mk - p['Rohr_Breite']) / 2.0,
      a_y: [t_innen - p['Rohr_Abstand_Hinten'] - p['Rohr_Tiefe'], 0.0].max, # ab Vorderkante Korpus
      a_b: abluft ? p['Rohr_Breite'] : 0.0,
      a_t: abluft ? p['Rohr_Tiefe'] : 0.0
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

  # Materialtyp und Maße im Wörterbuch "ladb_opencutlist" am Material (liest Stückliste/Zuschnitt).
  # Bereits eingestellte Materialien werden nicht verändert.
  def self.platten_material(model, name, farbe, attribute)
    m = model.materials[name] || model.materials.add(name)
    m.color = Sketchup::Color.new(*farbe) unless m.texture || m.get_attribute(OCL_DICT, 'type')
    if m.get_attribute(OCL_DICT, 'type').to_i == 0
      attribute.each { |k, v| m.set_attribute(OCL_DICT, k, v) }
    end
    m
  end

  def self.material(model)
    platten_material(model, MATERIAL, [255, 255, 255],
                     'type' => 2, # Plattenwerkstoff
                     'std_thicknesses' => '8mm;16mm;19mm',
                     'std_sizes' => '2800mm x 2070mm',
                     'grained' => false)
  end

  def self.kanten_material(model)
    @kante = platten_material(model, KANTE, [245, 245, 240],
                              'type' => 4, # Kante/Anleimer
                              'thickness' => '2mm',
                              'std_widths' => '23mm',
                              'std_lengths' => '75m',
                              'edge_decremented' => true) # 2 mm werden erst in Stückliste/Zuschnitt abgezogen
  end

  def self.tag(model, name)
    model.layers[name] || model.layers.add(name)
  end

  # Freies Kürzel für die Tags, z. B. OSD1, OSD2 …
  def self.freies_kuerzel(model)
    n = 1
    n += 1 while model.layers.to_a.any? { |l| l.name.start_with?("#{KUERZEL}#{n}_") }
    "#{KUERZEL}#{n}"
  end

  # Tag <Kürzel>_<Bereich>_<Teil> (z. B. OSD1_SeiteL) und JT_Schrank am Teil
  def self.kennzeichnen(model, inst, kz, teil, bereich = nil)
    name = [kz, bereich, teil].compact.join('_')
    inst.layer = tag(model, name)
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE, 'bereich' => bereich.to_s,
      'teil' => teil, 'rolle' => ROLLEN.fetch(teil.sub(/\d+\z/, '')) }.each { |k, v| inst.set_attribute(JT_DICT, k, v) }
    inst
  end

  SEITEN = { xmin: [0, -1], xmax: [0, 1], ymin: [1, -1], ymax: [1, 1], zmin: [2, -1], zmax: [2, 1] }.freeze

  # Sichtbare Kanten je Teil, bekommen einen Anleimer.
  # ymin = vorne, zmin/zmax = unten/oben, xmin/xmax = links/rechts.
  KANTEN = {
    'Seite'        => %i[ymin zmin zmax], # Oberschrank: Unter- und Oberkante sichtbar
    'Boden'        => %i[ymin],           # Haubenboden
    'Deckel'       => %i[ymin],
    'Einlegeboden' => %i[ymin],
    'Strebe'       => %i[zmin],           # von unten sichtbar
    'Rückwand'     => [],
    'Tür'          => %i[xmin xmax zmin zmax]
  }.freeze

  # Quader in Endmaß zeichnen; die in "kanten" genannten Flächen bekommen das Anleimer-Material
  def self.quader(ents, lx, ly, lz, kanten = [])
    f = ents.add_face([0, 0, 0], [inch(lx), 0, 0], [inch(lx), inch(ly), 0], [0, inch(ly), 0])
    f.reverse! if f.normal.z < 0
    f.pushpull(inch(lz))
    return if kanten.empty?
    ents.grep(Sketchup::Face).each do |face|
      n = face.normal.to_a
      seite = SEITEN.find { |_, (ax, vz)| n[ax] * vz > 0.5 }
      face.material = @kante if seite && kanten.include?(seite.first)
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
    kennzeichnen(kz[0], inst, *kz[1..-1]) if kz
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

  # Rohrausschnitt als Attribute an der Platte (cm, Lage auf der Platte ab vorne links);
  # y_versatz: Platte beginnt so weit hinter der Vorderkante des Korpus
  def self.ausschnitt_attribute(d, r, y_versatz, y_formel_versatz)
    u = DC_NAME
    attribut(d, 'Ausschnitt_X', r[:a_x], units: 'STRING',
             formula: "(#{u}!Breite-2*#{u}!Materialstaerke_Korpus-#{u}!Rohr_Breite)/2")
    attribut(d, 'Ausschnitt_Y', r[:a_y] - y_versatz, units: 'STRING',
             formula: "MAX(#{u}!T_Innen-#{u}!Rohr_Abstand_Hinten-#{u}!Rohr_Tiefe,0)#{y_formel_versatz}")
    attribut(d, 'Ausschnitt_B', r[:a_b], units: 'STRING', formula: "IF(#{u}!Abluft=1,#{u}!Rohr_Breite,0)")
    attribut(d, 'Ausschnitt_T', r[:a_t], units: 'STRING', formula: "IF(#{u}!Abluft=1,#{u}!Rohr_Tiefe,0)")
  end

  # Umriss des Rohrausschnitts knapp über der Platte (nur Kanten, keine Fläche: kein Teil für die Stückliste)
  def self.umriss(model, e, kz, name, pos, pos_formeln, sichtbar, hidden_formel)
    u = DC_NAME
    r_b, r_t = [pos[3], 1.0].max, [pos[4], 1.0].max
    a = model.definitions.add("Rohrausschnitt #{name}")
    stempel(a)
    a.set_attribute(DICT, '_name', "Ausschnitt#{name}")
    lx, ly = inch(r_b), inch(r_t)
    a.entities.add_line([0, 0, 0], [lx, 0, 0])
    a.entities.add_line([lx, 0, 0], [lx, ly, 0])
    a.entities.add_line([lx, ly, 0], [0, ly, 0])
    a.entities.add_line([0, ly, 0], [0, 0, 0])
    { 'lenx' => [r_b, "MAX(#{u}!Rohr_Breite,1)"], 'leny' => [r_t, "MAX(#{u}!Rohr_Tiefe,1)"] }.each do |k, (wert, f)|
      a.set_attribute(DICT, k, inch(wert))
      a.set_attribute(DICT, "_#{k}_formula", f)
      a.set_attribute(DICT, "_#{k}_label", k.capitalize)
    end
    sichtbarkeit(a, sichtbar, hidden_formel)
    i = einsetzen(e, a, "Ausschnitt#{name}", pos[0, 3], pos_formeln, layer: tag(model, "#{kz}_#{name}_Ausschnitt"))
    i.hidden = !sichtbar
    i
  end

  # Gerätenische für "Geräte in Schränke setzen": Raum unter dem Haubenboden (lichte Weite
  # x Haubenraum x Tiefe), Einfügepunkt vorne links an der Korpusvorderkante auf der
  # Unterkante, in mm (Stand beim Erzeugen); dazu Rohrausschnitt und Schrankhöhe.
  def self.nische(d, p, r)
    mm = ->(cm) { (cm * 10).round(1) }
    mk = p['Materialstaerke_Korpus']
    { 'nische' => 'DA', 'geraet' => "Flachschirmhaube#{p['Breite'].round}",
      'breite' => mm.(p['Breite'] - 2 * mk), 'hoehe' => mm.(p['Haube_Hoehe']), 'tiefe' => mm.(p['Tiefe']),
      'x' => mm.(mk), 'y' => mm.(mk), 'z' => 0.0,
      'abluft' => p['Abluft'].to_i, 'rohr_x' => mm.(r[:a_x]), 'rohr_y' => mm.(r[:a_y]),
      'rohr_breite' => mm.(p['Rohr_Breite']), 'rohr_tiefe' => mm.(p['Rohr_Tiefe']),
      'schrank_hoehe' => mm.(p['Hoehe']) }
      .each { |k, v| d.set_attribute(NISCHE_DICT, k, v) }
  end

  def self.pruefen(p)
    mk = p['Materialstaerke_Korpus']
    raise ArgumentError, 'Maße müssen größer als 0 sein' if %w[Breite Hoehe Tiefe].any? { |k| p[k] <= 0 }
    if p['Haube_Hoehe'] < p['Strebe_Hoehe'] || p['Haube_Hoehe'] + 2 * mk + 5.0 > p['Hoehe']
      raise ArgumentError, "Haubenraum #{(p['Haube_Hoehe'] * 10).round} mm passt nicht zur Schrankhöhe #{(p['Hoehe'] * 10).round} mm"
    end
    return unless p['Abluft'].to_i == 1 && p['Rohr_Breite'] > p['Breite'] - 2 * mk
    raise ArgumentError, 'Rohrausschnitt ist breiter als der Schrank innen'
  end

  # ---------------------------------------------------------------------------
  # Aufbau
  # ---------------------------------------------------------------------------
  def self.erzeuge(model, eingabe = {})
    p = DEFAULTS.merge(eingabe)
    pruefen(p)
    r = berechne(p)
    u = DC_NAME
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
    attribut(haupt, 'Breite', p['Breite'], access: 'TEXTBOX', formlabel: 'Breite')
    attribut(haupt, 'Hoehe', p['Hoehe'], access: 'TEXTBOX', formlabel: 'Höhe')
    attribut(haupt, 'Tiefe', p['Tiefe'], access: 'TEXTBOX', formlabel: 'Tiefe (Korpus ohne Front)')
    attribut(haupt, 'Art_Tuer', p['Art_Tuer'], laenge: false, access: 'LIST', formlabel: 'Türen',
             units: 'INTEGER', options: '&Eine%20T%C3%BCr%20(Anschlag%20links)=1&Zwei%20T%C3%BCren=2&')
    attribut(haupt, 'Haube_Hoehe', p['Haube_Hoehe'], access: 'TEXTBOX',
             formlabel: 'Haubenraum: Unterkante bis Haubenboden')
    attribut(haupt, 'Abluft', p['Abluft'], laenge: false, access: 'LIST', formlabel: 'Betrieb',
             units: 'INTEGER', options: '&Abluft%20(Rohrausschnitt)=1&Umluft%20(kein%20Ausschnitt)=0&')
    attribut(haupt, 'Rohr_Breite', p['Rohr_Breite'], access: 'TEXTBOX', formlabel: 'Rohrausschnitt: Breite')
    attribut(haupt, 'Rohr_Tiefe', p['Rohr_Tiefe'], access: 'TEXTBOX', formlabel: 'Rohrausschnitt: Tiefe')
    attribut(haupt, 'Rohr_Abstand_Hinten', p['Rohr_Abstand_Hinten'], access: 'TEXTBOX',
             formlabel: 'Rohrausschnitt: Abstand zur Rückwand')
    attribut(haupt, 'Anz_Einlegeboeden', p['Anz_Einlegeboeden'], laenge: false, access: 'LIST',
             formlabel: 'Einlegeboden über dem Haubenboden', units: 'INTEGER', options: '&0=0&1=1&')
    attribut(haupt, 'Tuer_Frei_Unten', p['Tuer_Frei_Unten'], access: 'TEXTBOX',
             formlabel: 'Türen unten frei (Blende Wrasenschirm)')

    # --- Feste Maße (über Komponentenattribute änderbar) ---
    %w[Materialstaerke_Korpus Materialstarke_Rueckwand Rueckwand_Versatz Nuttiefe Spaltbreite
       Rueckversatz_Einlegeboden Strebe_Hoehe].each do |n|
      attribut(haupt, n, p[n], units: 'STRING')
    end

    # --- Abgeleitete Werte ---
    attribut(haupt, 'T_Innen', r[:t_innen], units: 'STRING', formula: 'Tiefe-Rueckwand_Versatz-Materialstarke_Rueckwand')
    attribut(haupt, 'B_Tuer2', r[:b_tuer2], units: 'STRING', formula: 'Breite/2-Spaltbreite')
    attribut(haupt, 'H_Tuer', r[:h_tuer], units: 'STRING', formula: 'Hoehe-Spaltbreite-Tuer_Frei_Unten')
    attribut(haupt, 'Z_Einlegeboden', r[:z_eb], units: 'STRING',
             formula: '(Haube_Hoehe+Hoehe)/2-Materialstaerke_Korpus/2')

    mk = p['Materialstaerke_Korpus']
    b, h, t = p['Breite'], p['Hoehe'], p['Tiefe']
    rw, nut, hh = p['Materialstarke_Rueckwand'], p['Nuttiefe'], p['Haube_Hoehe']
    abluft = p['Abluft'].to_i == 1
    e = haupt.entities
    mkf = "#{u}!Materialstaerke_Korpus"
    innen_b = "#{u}!Breite-2*#{mkf}"
    a_pos = ->(y0, z, yf, zf) { [[mk + r[:a_x], y0 + r[:a_y], z, p['Rohr_Breite'], p['Rohr_Tiefe']],
                                 ["#{mkf}+(#{u}!Breite-2*#{mkf}-#{u}!Rohr_Breite)/2",
                                  "#{yf}+MAX(#{u}!T_Innen-#{u}!Rohr_Abstand_Hinten-#{u}!Rohr_Tiefe,0)", zf]] }
    hid = "IF(#{u}!Abluft=1,0,1)"

    # --- Korpus (beginnt wie die anderen Schränke bei y = Materialstärke) ---
    seite = platte(model, 'Seite', 'Seite', [mk, t, h], [mkf, "#{u}!Tiefe", "#{u}!Hoehe"])
    einsetzen(e, seite, 'SeiteL', [0, mk, 0], [nil, nil, nil], mat: mat, kz: t_.('SeiteL'))
    einsetzen(e, seite, 'SeiteR', [b - mk, mk, 0], ["#{u}!Breite-#{mkf}", nil, nil], mat: mat, kz: t_.('SeiteR'))

    # Haubenboden über die volle Tiefe, die Rückwand steht in seiner Nut
    boden = platte(model, 'Haubenboden', 'Haubenboden', [b - 2 * mk, t, mk], [innen_b, "#{u}!Tiefe", mkf], art: 'Boden')
    ausschnitt_attribute(boden, r, 0.0, '')
    einsetzen(e, boden, 'Haubenboden', [mk, mk, hh], [mkf, nil, "#{u}!Haube_Hoehe"], mat: mat, kz: t_.('Boden'))
    pos, f = a_pos.(mk, hh + mk + 0.05, mkf, "#{u}!Haube_Hoehe+#{mkf}+0.05")
    umriss(model, e, kz, 'Boden', pos, f, abluft, hid)

    # Deckel endet vor der Rückwand
    deckel = platte(model, 'Deckel', 'Deckel', [b - 2 * mk, r[:t_innen], mk], [innen_b, "#{u}!T_Innen", mkf])
    ausschnitt_attribute(deckel, r, 0.0, '')
    einsetzen(e, deckel, 'Deckel', [mk, mk, h - mk], [mkf, nil, "#{u}!Hoehe-#{mkf}"], mat: mat, kz: t_.('Deckel'))
    pos, f = a_pos.(mk, h + 0.05, mkf, "#{u}!Hoehe+0.05")
    umriss(model, e, kz, 'Deckel', pos, f, abluft, hid)

    # Rückwand vom Haubenboden bis oben, in der Nut von Seiten und Haubenboden
    rueck = platte(model, 'Rückwand', 'Rückwand', [b - 2 * mk + 2 * nut, rw, h - hh - mk + nut],
                   ["#{innen_b}+2*#{u}!Nuttiefe", "#{u}!Materialstarke_Rueckwand",
                    "#{u}!Hoehe-#{u}!Haube_Hoehe-#{mkf}+#{u}!Nuttiefe"])
    einsetzen(e, rueck, 'Rückwand', [mk - nut, mk + r[:t_innen], hh + mk - nut],
              ["#{mkf}-#{u}!Nuttiefe", "#{mkf}+#{u}!T_Innen", "#{u}!Haube_Hoehe+#{mkf}-#{u}!Nuttiefe"],
              mat: mat, kz: t_.('Rueckwand'))

    # Strebe hinten unten, hochkant, hinten bündig mit den Seiten
    strebe = platte(model, 'Strebe hinten', 'StrebeHinten', [b - 2 * mk, mk, p['Strebe_Hoehe']],
                    [innen_b, mkf, "#{u}!Strebe_Hoehe"], art: 'Strebe')
    einsetzen(e, strebe, 'StrebeHinten', [mk, t, 0], [mkf, "#{u}!Tiefe", nil], mat: mat, kz: t_.('StrebeHinten'))

    # --- Einlegeboden in der Mitte des Fachs über dem Haubenboden ---
    rv = p['Rueckversatz_Einlegeboden']
    eb = p['Anz_Einlegeboeden'].to_i >= 1
    d = platte(model, 'Einlegeboden 1', 'Einlegeboden1', [b - 2 * mk, r[:t_innen] - rv, mk],
               [innen_b, "#{u}!T_Innen-#{u}!Rueckversatz_Einlegeboden", mkf], art: 'Einlegeboden')
    ausschnitt_attribute(d, r, rv, "-#{u}!Rueckversatz_Einlegeboden")
    sichtbarkeit(d, eb, "IF(#{u}!Anz_Einlegeboeden>=1,0,1)")
    inst = einsetzen(e, d, 'Einlegeboden1', [mk, mk + rv, r[:z_eb]],
                     [mkf, "#{mkf}+#{u}!Rueckversatz_Einlegeboden", "#{u}!Z_Einlegeboden"],
                     mat: mat, kz: t_.('Einlegeboden1'))
    inst.hidden = !eb
    pos, f = a_pos.(mk, r[:z_eb] + mk + 0.05, mkf, "#{u}!Z_Einlegeboden+#{mkf}+0.05")
    umriss(model, e, kz, 'Einlegeboden1', pos, f, abluft && eb,
           "IF(AND(#{u}!Abluft=1,#{u}!Anz_Einlegeboeden>=1),0,1)")

    tueren(model, e, p, r, mat, t_)
    haupt
  end

  # Türen: eine (Anschlag links) oder zwei, mit "Interagieren" öffnen; unten bleibt Tuer_Frei_Unten frei
  def self.tueren(model, e, p, r, mat, t_)
    u = DC_NAME
    sp, mk, b = p['Spaltbreite'], p['Materialstaerke_Korpus'], p['Breite']
    art = p['Art_Tuer'].to_i
    h_f = "#{u}!H_Tuer"
    z_f = "#{u}!Spaltbreite/2+#{u}!Tuer_Frei_Unten"
    z = r[:z_tuer]

    t1 = platte(model, 'Tür', 'Tür', [r[:b_tuer1], mk, r[:h_tuer]],
                ["#{u}!Breite-#{u}!Spaltbreite", "#{u}!Materialstaerke_Korpus", h_f])
    tuer_drehen(t1, art == 1, "IF(#{u}!Art_Tuer=1,0,1)", -100)
    i1 = einsetzen(e, t1, 'Tür', [sp / 2.0, -sp, z], ["#{u}!Spaltbreite/2", "-#{u}!Spaltbreite", z_f],
                   mat: mat, kz: t_.('Tuer'))
    i1.hidden = art != 1

    tl = platte(model, 'Tür links', 'TürL', [r[:b_tuer2], mk, r[:h_tuer]],
                ["#{u}!B_Tuer2", "#{u}!Materialstaerke_Korpus", h_f], art: 'Tür')
    tuer_drehen(tl, art == 2, "IF(#{u}!Art_Tuer=2,0,1)", -100)
    il = einsetzen(e, tl, 'TürL', [sp / 2.0, -sp, z], ["#{u}!Spaltbreite/2", "-#{u}!Spaltbreite", z_f],
                   mat: mat, kz: t_.('TuerL'))
    il.hidden = art != 2

    # rechts: Drehpunkt rechts, die Tür steckt in einem Halter am Scharnier
    halter = model.definitions.add('Tür rechts Halter')
    stempel(halter)
    halter.set_attribute(DICT, '_name', 'TuerRHalter')
    attribut(halter, 'B_Tuer', r[:b_tuer2], units: 'STRING', formula: "#{u}!B_Tuer2")
    attribut(halter, 'H_Tuer', r[:h_tuer], units: 'STRING', formula: h_f)
    attribut(halter, 'Mk', mk, units: 'STRING', formula: "#{u}!Materialstaerke_Korpus")
    tuer_drehen(halter, art == 2, "IF(#{u}!Art_Tuer=2,0,1)", 100)
    h = 'TuerRHalter'
    tr = platte(model, 'Tür rechts', 'TürR', [r[:b_tuer2], mk, r[:h_tuer]],
                ["#{h}!B_Tuer", "#{h}!Mk", "#{h}!H_Tuer"], art: 'Tür')
    einsetzen(halter.entities, tr, 'TürR', [-r[:b_tuer2], 0, 0], ["-#{h}!B_Tuer", nil, nil], mat: mat, kz: t_.('TuerR'))
    ih = einsetzen(e, halter, h, [b - sp / 2.0, -sp, z],
                   ["#{u}!Breite-#{u}!Spaltbreite/2", "-#{u}!Spaltbreite", z_f])
    ih.hidden = art != 2
  end

  def self.tuer_drehen(d, sichtbar, formel, winkel)
    sichtbarkeit(d, sichtbar, formel)
    d.set_attribute(DICT, 'rotz', 0.0)
    d.set_attribute(DICT, 'onclick', "ANIMATE(\"ROTZ\",0,#{winkel})")
    d.set_attribute(DICT, '_onclick_label', 'onClick')
  end

  # ---------------------------------------------------------------------------
  # Erzeugen (mit ziel zusätzlich als .skp speichern)
  # ---------------------------------------------------------------------------
  # Neuer Schrank: Maße beim Anlegen abfragen, Tiefe = Korpus ohne Front/Rückwand. Danach bleiben sie im
  # Fenster Komponentenoptionen änderbar; alle abhängigen Teile folgen dort per Formel.
  TIEFE_NEU = 40.0 # cm, Vorschlag im Dialog (wie Oberschrank)

  def self.tiefe_min
    # Rohrausschnitt, Abstand zur Rückwand und ein Steg vorne müssen in den Deckel passen
    d = DEFAULTS
    [20.0, d['Rueckwand_Versatz'] + d['Materialstarke_Rueckwand'] + d['Rohr_Abstand_Hinten'] + d['Rohr_Tiefe'] + 2.0].max
  end

  def self.dialog
    res = UI.inputbox(['Breite (mm)', 'Höhe (mm)', 'Tiefe Korpus (mm)'],
                      [(DEFAULTS['Breite'] * 10).round.to_s, (DEFAULTS['Hoehe'] * 10).round.to_s, (TIEFE_NEU * 10).round.to_s],
                      'Oberschrank Dunstabzug')
    return unless res
    w = res.map { |v| v.to_s.tr(',', '.').to_f / 10.0 }
    eingabe = { 'Breite' => w[0], 'Hoehe' => w[1], 'Tiefe' => w[2] }
    t = eingabe['Tiefe']
    if t < tiefe_min - 0.000001
      raise ArgumentError, "Tiefe #{(t * 10).round} mm ist zu klein (mindestens #{(tiefe_min * 10).round} mm)"
    end
    raise ArgumentError, 'Maße müssen größer als 0 sein' if eingabe.values.any? { |v| v <= 0 }
    erstellen(eingabe)
  rescue ArgumentError => e
    UI.messagebox("Ungültige Eingabe: #{e.message}")
  end

  def self.erstellen(eingabe = {}, ziel = nil)
    model = Sketchup.active_model
    model.start_operation('Oberschrank Dunstabzug', true)
    defn = erzeuge(model, eingabe)
    x = model.entities.length > 0 ? model.bounds.max.x + 10.cm : 0
    inst = model.entities.add_instance(defn, Geom::Transformation.translation([x, 0, 0]))
    inst.name = NAME
    inst.set_attribute(DICT, '_name', DC_NAME)
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
  rescue ArgumentError
    model.abort_operation
    raise
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
  Kuechenplaner.schrank('Oberschränke', 'Oberschrank Dunstabzug…') { OberschrankDunstabzug.dialog }
  file_loaded(__FILE__)
end
