# encoding: UTF-8
#
# Oberschrank – erzeugt eine Dynamic Component
#
# Erweiterung (.rbz): Erweiterungen > Küchenplaner > Oberschränke > Oberschrank baut den Schrank im
# aktuellen Modell. Maße und Optionen danach in den Komponentenoptionen einstellen.
#
# Aufbau: Seiten über die volle Höhe, Boden und Deckel zwischen den Seiten,
# 0–3 Einlegeböden, offen oder mit einer oder zwei Türen.
# Rückwand 8 mm, 25 mm vor der Hinterkante (Fach für die Aufhängung), steht in
# einer 9 mm tiefen Nut in Seiten und Boden und wird von oben eingeschoben.
# Der Deckel endet vor der Rückwand und wird mit ihr verschraubt.
#
# OpenCutList: Platten haben das Material "Melamin weiss" (Plattenwerkstoff),
# sichtbare Kanten das Material "Anleimer Melamin weiss" (Kante, 2 mm, wird nur
# in OCL abgezogen; gezeichnet wird das Endmaß). Jedes Teil hat einen eigenen Tag
# <Kürzel>_<Teil> (z. B. OS1_SeiteL, OS1_TuerR) und das Wörterbuch "JT_Schrank"
# für den TCN-Export. Anderes Kürzel: Oberschrank.erstellen({ 'Kuerzel' => 'OS2' }, ziel)

require 'sketchup.rb'

module Oberschrank

  DICT     = 'dynamic_attributes'.freeze
  NAME     = 'Oberschrank'.freeze
  MAX_EB   = 3
  MATERIAL = 'Melamin weiss'.freeze
  KANTE    = 'Anleimer Melamin weiss'.freeze
  OCL_DICT = 'ladb_opencutlist'.freeze
  KUERZEL  = 'OS'.freeze

  # Tag-Schema für den TCN-Export (gleich in allen Komponenten, der Test prüft das):
  # Tag <Kürzel>_<Bereich>_<Teil>, dazu am Teil das Wörterbuch JT_Schrank.
  JT_DICT   = 'JT_Schrank'.freeze
  TYP       = 'Oberschrank'.freeze
  KATEGORIE = 'Oberschrank'.freeze # Unterschrank, Oberschrank oder Hochschrank
  ROLLEN = {
    'SeiteL' => 'Seite', 'SeiteR' => 'Seite', 'Boden' => 'Boden', 'Deckel' => 'Deckel',
    'StrebeVorn' => 'Strebe', 'StrebeHinten' => 'Strebe',
    'ZwischenbodenUnten' => 'Zwischenboden', 'ZwischenbodenMitte' => 'Zwischenboden', 'ZwischenbodenOben' => 'Zwischenboden',
    'Mittelboden' => 'Zwischenboden',
    'Rueckwand' => 'Rueckwand', 'Einlegeboden' => 'Einlegeboden', 'Front' => 'Front',
    'Tuer' => 'Tuer', 'TuerL' => 'Tuer', 'TuerR' => 'Tuer',
    'KastenBoden' => 'KastenBoden', 'KastenRueckwand' => 'KastenRueckwand',
    'Blende' => 'Front',
    'WangeL' => 'Wange', 'WangeR' => 'Wange'
  }.freeze

  # Standardwerte in cm
  DEFAULTS = {
    'Breite'                    => 60.0,
    'Hoehe'                     => 70.0,
    'Tiefe'                     => 40.0,  # Korpus ohne Front
    'Art_Tuer'                  => 2.0,   # 0 = offen, 1 = eine Tür (Anschlag links), 2 = zwei Türen
    'Anz_Einlegeboeden'         => 1.0,
    'Materialstaerke_Korpus'    => 1.9,
    'Materialstarke_Rueckwand'  => 0.8,
    'Rueckwand_Versatz'         => 2.5,   # Hinterkante Seite -> Rückseite Rückwand
    'Nuttiefe'                  => 0.9,
    'Spaltbreite'               => 0.2,
    'Rueckversatz_Einlegeboden' => 1.0    # Einlegeböden vorne zurückgesetzt
  }.freeze

  # Kurzhilfe in der Komponente (Kurzfassung der README.md). SketchUp zeigt
  # "summary" und "description" oben im Fenster "Komponentenoptionen".
  DOKU_URL = 'https://github.com/jimmycd/sketchup_kuechenplaner2/tree/main/Komponenten/oberschrank'.freeze
  HILFE_KURZ = 'Oberschrank offen, mit einer oder zwei Türen, 0–3 Einlegeböden, OpenCutList-fähig'.freeze
  HILFE = [
    'Breite, Höhe, Tiefe (Korpus ohne Front), Türen (keine, eine mit Anschlag links, zwei) und Anzahl Einlegeböden hier ändern.',
    'Rückwand 8 mm, 25 mm vor der Hinterkante in einer 9 mm tiefen Nut in Seiten und Boden, von oben eingeschoben; der Deckel endet vor der Rückwand.',
    'Mit „Interagieren“ öffnen sich die Türen.',
    'Gezeichnet ist das Endmaß; den Anleimer (2 mm) zieht nur OpenCutList ab.',
    'Jedes Teil hat einen eigenen Tag <Kürzel>_<Teil>, z. B. OS1_SeiteL, OS1_TuerR.',
    'Feste Maße (Materialstärken, Versatz, Nut, Spalt): Fenster „Komponentenattribute“.',
    "Doku: #{DOKU_URL}"
  ].join(' ').freeze

  # ---------------------------------------------------------------------------
  # Reine Berechnung (ohne SketchUp), spiegelt die DC-Formeln. Werte in cm.
  # ---------------------------------------------------------------------------
  def self.berechne(p)
    mk, rw, sp = p['Materialstaerke_Korpus'], p['Materialstarke_Rueckwand'], p['Spaltbreite']
    b, h, t = p['Breite'], p['Hoehe'], p['Tiefe']
    n_eb = p['Anz_Einlegeboeden'].to_i
    {
      t_innen: t - p['Rueckwand_Versatz'] - rw, # Vorderkante Korpus -> Vorderseite Rückwand
      b_tuer1: b - sp,
      b_tuer2: b / 2.0 - sp,
      h_tuer: h - sp,
      eb: (1..MAX_EB).map { |k| k <= n_eb ? mk + (h - 2 * mk) * k / (n_eb + 1) - mk / 2 : mk }
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

  def self.liste(von, bis)
    '&' + (von..bis).map { |i| "#{i}=#{i}" }.join('&') + '&'
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

  # Freies Kürzel für die Tags, z. B. OS1, OS2 …
  def self.freies_kuerzel(model)
    n = 1
    n += 1 while model.layers.to_a.any? { |l| l.name.start_with?("#{KUERZEL}#{n}_") }
    "#{KUERZEL}#{n}"
  end

  # Tag <Kürzel>_<Bereich>_<Teil> (z. B. OS1_SeiteL) und JT_Schrank am Teil
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
    'Seite'        => %i[ymin zmin zmax], # Oberschrank: Unter- und Oberkante sichtbar
    'Boden'        => %i[ymin],
    'Deckel'       => %i[ymin],
    'Einlegeboden' => %i[ymin],
    'Rückwand'     => [],
    'Tür'          => %i[xmin xmax zmin zmax]
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
  def self.einsetzen(ents, defn, inst_name, pos, pos_formeln, mat: nil, kz: nil)
    tr = Geom::Transformation.translation(Geom::Vector3d.new(*pos.map { |v| inch(v) }))
    inst = ents.add_instance(defn, tr)
    inst.name = inst_name
    inst.material = mat if mat
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
    t_ = ->(teil) { [model, kz, teil] }

    haupt = model.definitions.add(NAME)
    stempel(haupt)
    haupt.set_attribute(DICT, '_name', u)
    hilfe(haupt)
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE }.each { |k, v| haupt.set_attribute(JT_DICT, k, v) }

    # --- Parameter (Komponentenoptionen) ---
    attribut(haupt, 'Breite', p['Breite'], access: 'TEXTBOX', formlabel: 'Breite')
    attribut(haupt, 'Hoehe', p['Hoehe'], access: 'TEXTBOX', formlabel: 'Höhe')
    attribut(haupt, 'Tiefe', p['Tiefe'], access: 'TEXTBOX', formlabel: 'Tiefe (Korpus ohne Front)')
    attribut(haupt, 'Art_Tuer', p['Art_Tuer'], laenge: false, access: 'LIST', formlabel: 'Türen',
             units: 'INTEGER', options: '&Keine%20(offen)=0&Eine%20T%C3%BCr%20(Anschlag%20links)=1&Zwei%20T%C3%BCren=2&')
    attribut(haupt, 'Anz_Einlegeboeden', p['Anz_Einlegeboeden'], laenge: false, access: 'LIST',
             formlabel: 'Anzahl Einlegeböden', units: 'INTEGER', options: liste(0, MAX_EB))

    # --- Feste Maße (über Komponentenattribute änderbar) ---
    %w[Materialstaerke_Korpus Materialstarke_Rueckwand Rueckwand_Versatz Nuttiefe Spaltbreite
       Rueckversatz_Einlegeboden].each do |n|
      attribut(haupt, n, p[n], units: 'STRING')
    end

    # --- Abgeleitete Werte ---
    attribut(haupt, 'T_Innen', r[:t_innen], units: 'STRING', formula: 'Tiefe-Rueckwand_Versatz-Materialstarke_Rueckwand')
    attribut(haupt, 'B_Tuer2', r[:b_tuer2], units: 'STRING', formula: 'Breite/2-Spaltbreite')
    (1..MAX_EB).each do |k|
      f = "IF(Anz_Einlegeboeden>=#{k},Materialstaerke_Korpus+(Hoehe-2*Materialstaerke_Korpus)*#{k}/" \
          "(Anz_Einlegeboeden+1)-Materialstaerke_Korpus/2,Materialstaerke_Korpus)"
      attribut(haupt, "Z_Einlegeboden_#{k}", r[:eb][k - 1], units: 'STRING', formula: f)
    end

    mk = p['Materialstaerke_Korpus']
    b, h, t = p['Breite'], p['Hoehe'], p['Tiefe']
    rw, sp, nut = p['Materialstarke_Rueckwand'], p['Spaltbreite'], p['Nuttiefe']
    e = haupt.entities

    # --- Korpus (beginnt wie die anderen Schränke bei y = Materialstärke) ---
    seite = platte(model, 'Seite', 'Seite', [mk, t, h],
                   ["#{u}!Materialstaerke_Korpus", "#{u}!Tiefe", "#{u}!Hoehe"])
    einsetzen(e, seite, 'SeiteL', [0, mk, 0], [nil, nil, nil], mat: mat, kz: t_.('SeiteL'))
    einsetzen(e, seite, 'SeiteR', [b - mk, mk, 0],
              ["#{u}!Breite-#{u}!Materialstaerke_Korpus", nil, nil], mat: mat, kz: t_.('SeiteR'))

    innen_b = "#{u}!Breite-2*#{u}!Materialstaerke_Korpus"
    boden = platte(model, 'Boden', 'Boden', [b - 2 * mk, t, mk], [innen_b, "#{u}!Tiefe", "#{u}!Materialstaerke_Korpus"])
    einsetzen(e, boden, 'Boden', [mk, mk, 0], ["#{u}!Materialstaerke_Korpus", nil, nil], mat: mat, kz: t_.('Boden'))

    # Deckel endet vor der Rückwand
    deckel = platte(model, 'Deckel', 'Deckel', [b - 2 * mk, r[:t_innen], mk],
                    [innen_b, "#{u}!T_Innen", "#{u}!Materialstaerke_Korpus"])
    einsetzen(e, deckel, 'Deckel', [mk, mk, h - mk],
              ["#{u}!Materialstaerke_Korpus", nil, "#{u}!Hoehe-#{u}!Materialstaerke_Korpus"], mat: mat, kz: t_.('Deckel'))

    # Rückwand in der Nut von Seiten und Boden, oben bündig
    rueck = platte(model, 'Rückwand', 'Rückwand', [b - 2 * mk + 2 * nut, rw, h - mk + nut],
                   ["#{u}!Breite-2*#{u}!Materialstaerke_Korpus+2*#{u}!Nuttiefe", "#{u}!Materialstarke_Rueckwand",
                    "#{u}!Hoehe-#{u}!Materialstaerke_Korpus+#{u}!Nuttiefe"])
    einsetzen(e, rueck, 'Rückwand', [mk - nut, mk + r[:t_innen], mk - nut],
              ["#{u}!Materialstaerke_Korpus-#{u}!Nuttiefe", "#{u}!Materialstaerke_Korpus+#{u}!T_Innen",
               "#{u}!Materialstaerke_Korpus-#{u}!Nuttiefe"], mat: mat, kz: t_.('Rueckwand'))

    # --- Einlegeböden ---
    rv = p['Rueckversatz_Einlegeboden']
    (1..MAX_EB).each do |k|
      # eigene Definition je Boden, damit "hidden" einzeln gesteuert werden kann
      d = platte(model, "Einlegeboden #{k}", "Einlegeboden#{k}", [b - 2 * mk, r[:t_innen] - rv, mk],
                 [innen_b, "#{u}!T_Innen-#{u}!Rueckversatz_Einlegeboden", "#{u}!Materialstaerke_Korpus"],
                 art: 'Einlegeboden')
      sichtbarkeit(d, k <= p['Anz_Einlegeboeden'].to_i, "IF(#{u}!Anz_Einlegeboeden>=#{k},0,1)")
      inst = einsetzen(e, d, "Einlegeboden#{k}", [mk, mk + rv, r[:eb][k - 1]],
                       ["#{u}!Materialstaerke_Korpus", "#{u}!Materialstaerke_Korpus+#{u}!Rueckversatz_Einlegeboden",
                        "#{u}!Z_Einlegeboden_#{k}"], mat: mat, kz: t_.("Einlegeboden#{k}"))
      inst.hidden = k > p['Anz_Einlegeboeden'].to_i
    end

    tueren(model, e, p, r, mat, t_)
    haupt
  end

  # Türen: eine (Anschlag links) oder zwei, mit "Interagieren" öffnen
  def self.tueren(model, e, p, r, mat, t_)
    u = NAME
    sp, mk, b = p['Spaltbreite'], p['Materialstaerke_Korpus'], p['Breite']
    art = p['Art_Tuer'].to_i
    h_f = "#{u}!Hoehe-#{u}!Spaltbreite"

    # eine Tür, Drehpunkt links (Ursprung der Komponente)
    t1 = platte(model, 'Tür', 'Tür', [r[:b_tuer1], mk, r[:h_tuer]],
                ["#{u}!Breite-#{u}!Spaltbreite", "#{u}!Materialstaerke_Korpus", h_f])
    tuer_drehen(t1, art == 1, "IF(#{u}!Art_Tuer=1,0,1)", -100)
    i1 = einsetzen(e, t1, 'Tür', [sp / 2.0, -sp, sp / 2.0],
                   ["#{u}!Spaltbreite/2", "-#{u}!Spaltbreite", "#{u}!Spaltbreite/2"], mat: mat, kz: t_.('Tuer'))
    i1.hidden = art != 1

    # zwei Türen: links wie oben, Drehpunkt links
    tl = platte(model, 'Tür links', 'TürL', [r[:b_tuer2], mk, r[:h_tuer]],
                ["#{u}!B_Tuer2", "#{u}!Materialstaerke_Korpus", h_f], art: 'Tür')
    tuer_drehen(tl, art == 2, "IF(#{u}!Art_Tuer=2,0,1)", -100)
    il = einsetzen(e, tl, 'TürL', [sp / 2.0, -sp, sp / 2.0],
                   ["#{u}!Spaltbreite/2", "-#{u}!Spaltbreite", "#{u}!Spaltbreite/2"], mat: mat, kz: t_.('TuerL'))
    il.hidden = art != 2

    # rechts: Drehpunkt muss rechts liegen, deshalb steckt die Tür in einem
    # Halter am Scharnier und liegt darin bei x = -Breite der Tür
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
    ih = einsetzen(e, halter, h, [b - sp / 2.0, -sp, sp / 2.0],
                   ["#{u}!Breite-#{u}!Spaltbreite/2", "-#{u}!Spaltbreite", "#{u}!Spaltbreite/2"])
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
  def self.erstellen(eingabe = {}, ziel = nil)
    model = Sketchup.active_model
    model.start_operation('Oberschrank', true)
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
        UI.messagebox('Automatisches Speichern ging nicht. Rechtsklick auf den Oberschrank → "Speichern unter…"')
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
  Kuechenplaner.untermenu('Oberschränke').add_item('Oberschrank…') { Oberschrank.erstellen }
  file_loaded(__FILE__)
end
