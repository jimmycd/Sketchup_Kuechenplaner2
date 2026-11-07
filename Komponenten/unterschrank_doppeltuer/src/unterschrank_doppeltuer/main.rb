# encoding: UTF-8
#
# Unterschrank mit Doppeltür – erzeugt eine Dynamic Component
#
# Erweiterung (.rbz): Erweiterungen > Küchenplaner > Unterschränke > Unterschrank mit Doppeltür baut den
# Schrank im aktuellen Modell. Maße und Optionen danach in den Komponentenoptionen einstellen.
#
# Aufbau wie der Unterschrank mit Tür: Seiten über die volle Höhe, Boden zwischen den
# Seiten, oben eine Strebe vorn und eine hinten, Rückwand (8 mm) hinter dem Korpus,
# 0–3 Einlegeböden in gleich hohen Fächern. Vorne zwei Türen über die volle Höhe,
# die linke mit Anschlag links, die rechte mit Anschlag rechts (Blum-Topfbänder setzt
# der TCN-Export). Mit "Interagieren" lassen sich beide Türen öffnen.
#
# Material: Platten haben das Material "Melamin weiss" (Plattenwerkstoff),
# sichtbare Kanten das Material "Anleimer Melamin weiss" (Kante, 2 mm, wird nur
# in Stückliste/Zuschnitt abgezogen; gezeichnet wird das Endmaß). Jedes Teil hat einen eigenen Tag
# <Kürzel>_<Teil> (z. B. USD1_SeiteL, USD1_TuerR) und das Wörterbuch "JT_Schrank"
# für den TCN-Export. Anderes Kürzel:
#   UnterschrankDoppeltuer.erstellen({ 'Kuerzel' => 'USD2' }, ziel)

require 'sketchup.rb'
require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'eingabe') # Eingabefenster im Treppenplaner-Stil
require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'neuladen') # Neu laden ohne Neustart (Wächter)

module UnterschrankDoppeltuer

  DICT     = 'dynamic_attributes'.freeze
  NAME     = 'Unterschrank_Doppeltuer'.freeze
  MAX_EB   = 3
  MATERIAL = 'Melamin weiss'.freeze
  KANTE    = 'Anleimer Melamin weiss'.freeze
  OCL_DICT = 'ladb_opencutlist'.freeze
  KUERZEL  = 'USD'.freeze

  # Tag-Schema für den TCN-Export (gleich in allen Komponenten, der Test prüft das):
  # Tag <Kürzel>_<Bereich>_<Teil>, dazu am Teil das Wörterbuch JT_Schrank.
  JT_DICT   = 'JT_Schrank'.freeze
  TYP       = 'Unterschrank_Doppeltuer'.freeze
  KATEGORIE = 'Unterschrank'.freeze # Unterschrank, Oberschrank oder Hochschrank
  ROLLEN = {
    'SeiteL' => 'Seite', 'SeiteR' => 'Seite', 'Boden' => 'Boden', 'Deckel' => 'Deckel',
    'StrebeVorn' => 'Strebe', 'StrebeHinten' => 'Strebe',
    'ZwischenbodenUnten' => 'Zwischenboden', 'ZwischenbodenMitte' => 'Zwischenboden', 'ZwischenbodenOben' => 'Zwischenboden',
    'Mittelboden' => 'Zwischenboden', 'Mittelwand' => 'Seite',
    'Rueckwand' => 'Rueckwand', 'RueckwandOben' => 'Rueckwand', 'RueckwandUnten' => 'Rueckwand',
    'Einlegeboden' => 'Einlegeboden', 'Front' => 'Front',
    'Tuer' => 'Tuer', 'TuerL' => 'Tuer', 'TuerR' => 'Tuer', 'TuerUnten' => 'Tuer', 'TuerOben' => 'Tuer',
    'Klappe' => 'Front', 'KlappeO' => 'Front', 'KlappeU' => 'Front',
    'KastenBoden' => 'KastenBoden', 'KastenRueckwand' => 'KastenRueckwand',
    'Innenfront' => 'Innenfront',
    'Auflageleiste' => 'Leiste',
    'Blende' => 'Front',
    'WangeL' => 'Wange', 'WangeR' => 'Wange',
    'Winkelleiste' => 'Leiste', 'Sockelblende' => 'Sockel', 'SockelSeiteL' => 'Sockel', 'SockelSeiteR' => 'Sockel',
    'Platte' => 'Arbeitsplatte',
    'Verkleidung' => 'Verkleidung', 'Theke' => 'Theke'
  }.freeze

  # Standardwerte in cm
  DEFAULTS = {
    'Breite'                    => 80.0,
    'Hoehe'                     => 70.0,
    'Tiefe'                     => 52.0,  # Korpus ohne Front und Rückwand
    'Anz_Einlegeboeden'         => 1.0,
    'Materialstaerke_Korpus'    => 1.9,
    'Materialstarke_Rueckwand'  => 0.8,
    'BreiteStreben'             => 10.0,
    'Spaltbreite'               => 0.2,
    'Rueckversatz_Einlegeboden' => 1.0    # Einlegeböden vorne zurückgesetzt
  }.freeze

  # Kurzhilfe in der Komponente (Kurzfassung der README.md), steht oben im Fenster "Komponentenoptionen".
  DOKU_URL = 'https://github.com/jimmycd/sketchup_kuechenplaner2/tree/main/Komponenten/unterschrank_doppeltuer'.freeze
  HILFE_KURZ = 'Unterschrank mit zwei Türen (links und rechts angeschlagen) und 0–3 Einlegeböden'.freeze

  # ---------------------------------------------------------------------------
  # Reine Berechnung (ohne SketchUp), spiegelt die DC-Formeln. Werte in cm.
  # Einlegeböden teilen den Raum zwischen Boden und Streben in gleich hohe lichte Fächer.
  # ---------------------------------------------------------------------------
  def self.berechne(p)
    mk, sp = p['Materialstaerke_Korpus'], p['Spaltbreite']
    b, h = p['Breite'], p['Hoehe']
    n = p['Anz_Einlegeboeden'].to_i
    {
      b_tuer: b / 2.0 - sp,
      eb: (1..MAX_EB).map { |k| n >= k ? mk + k * (h - (n + 2) * mk) / (n + 1) + (k - 1) * mk : mk }
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

  def self.liste(von, bis)
    '&' + (von..bis).map { |i| "#{i}=#{i}" }.join('&') + '&'
  end

  # OpenCutList: Materialtyp und Maße im Wörterbuch "ladb_opencutlist" am Material.
  # Bereits konfigurierte Materialien werden nicht verändert.
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
                          'edge_decremented' => true) # 2 mm werden erst in Stückliste/Zuschnitt abgezogen
  end

  # Freies Kürzel für die Tags, z. B. USD1, USD2 …
  def self.freies_kuerzel(model)
    n = 1
    n += 1 while model.layers.to_a.any? { |l| l.name.start_with?("#{KUERZEL}#{n}_") }
    "#{KUERZEL}#{n}"
  end

  def self.tag(model, name)
    model.layers[name] || model.layers.add(name)
  end

  # Tag <Kürzel>_<Bereich>_<Teil> (z. B. USD1_TuerL) und JT_Schrank am Teil
  def self.kennzeichnen(model, inst, kz, teil, bereich = nil)
    inst.layer = tag(model, [kz, bereich, teil].compact.join('_'))
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE, 'bereich' => bereich.to_s,
      'teil' => teil, 'rolle' => ROLLEN.fetch(teil.sub(/\d+\z/, '')) }.each { |k, v| inst.set_attribute(JT_DICT, k, v) }
    inst
  end

  SEITEN = { xmin: [0, -1], xmax: [0, 1], ymin: [1, -1], ymax: [1, 1], zmin: [2, -1], zmax: [2, 1] }.freeze

  # Sichtbare Kanten je Teil, bekommen einen Anleimer.
  # ymin = vorne, zmin/zmax = unten/oben, xmin/xmax = links/rechts.
  KANTEN = {
    'Seite'        => %i[ymin],
    'Boden'        => %i[ymin],
    'StrebeVorn'   => %i[ymin],
    'StrebeHinten' => [],
    'Rückwand'     => [],
    'Einlegeboden' => %i[ymin],
    'Tür'          => %i[xmin xmax zmin zmax]
  }.freeze

  # Quader in Endmaß zeichnen; die in "kanten" genannten Flächen bekommen das
  # Anleimer-Material (Stückliste und TCN-Export erkennen den Anleimer an der Material-Zuweisung der Kantenfläche).
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
    attribut(haupt, 'Anz_Einlegeboeden', p['Anz_Einlegeboeden'], laenge: false, access: 'LIST',
             formlabel: 'Anzahl Einlegeböden', units: 'INTEGER', options: liste(0, MAX_EB))

    # --- Feste Maße (über Komponentenattribute änderbar) ---
    %w[Materialstaerke_Korpus Materialstarke_Rueckwand BreiteStreben Spaltbreite Rueckversatz_Einlegeboden].each do |n|
      attribut(haupt, n, p[n], units: 'STRING')
    end

    # --- Abgeleitete Werte ---
    attribut(haupt, 'B_Tuer', r[:b_tuer], units: 'STRING', formula: 'Breite/2-Spaltbreite')
    (1..MAX_EB).each do |k|
      # gleich hohe lichte Fächer wie beim Unterschrank mit Tür
      f = "IF(Anz_Einlegeboeden>=#{k},Materialstaerke_Korpus+#{k}*(Hoehe-(Anz_Einlegeboeden+2)*Materialstaerke_Korpus)/" \
          "(Anz_Einlegeboeden+1)+#{k - 1}*Materialstaerke_Korpus,Materialstaerke_Korpus)"
      attribut(haupt, "Z_Einlegeboden_#{k}", r[:eb][k - 1], units: 'STRING', formula: f)
    end

    mk = p['Materialstaerke_Korpus']
    b, h, t = p['Breite'], p['Hoehe'], p['Tiefe']
    rw, bs = p['Materialstarke_Rueckwand'], p['BreiteStreben']
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
    strebe_h = platte(model, 'StrebeH', 'StrebeHinten', [b - 2 * mk, bs, mk], strebe_formeln)
    einsetzen(e, strebe_h, 'StrebeHinten', [mk, mk + t - bs, h - mk],
              ['StrebeVorn!X', "#{u}!Materialstaerke_Korpus+#{u}!Tiefe-#{u}!BreiteStreben", 'StrebeVorn!Z'],
              mat: mat, kz: t_.('StrebeHinten'))

    # Rückwand wie beim Unterschrank mit Tür: volle Breite und Höhe hinter dem Korpus
    rueck = platte(model, 'Rückwand', 'Rückwand', [b, rw, h],
                   ["#{u}!Breite", "#{u}!Materialstarke_Rueckwand", "#{u}!Hoehe"])
    einsetzen(e, rueck, 'Rückwand', [0, mk + t, 0], [nil, "#{u}!Materialstaerke_Korpus+#{u}!Tiefe", nil],
              mat: mat, kz: t_.('Rueckwand'))

    # --- Einlegeböden ---
    rv = p['Rueckversatz_Einlegeboden']
    (1..MAX_EB).each do |k|
      # eigene Definition je Boden, damit "hidden" einzeln gesteuert werden kann
      d = platte(model, "Einlegeboden #{k}", "Einlegeboden#{k}", [b - 2 * mk, t - rv, mk],
                 [innen_b, "#{u}!Tiefe-#{u}!Rueckversatz_Einlegeboden", "#{u}!Materialstaerke_Korpus"],
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

  # Zwei Türen über die volle Höhe (wie beim Spülenschrank), mit "Interagieren" öffnen.
  # Links: Drehpunkt am Ursprung der Tür (Anschlag links).
  def self.tueren(model, e, p, r, mat, t_)
    u = NAME
    sp, mk, b, h = p['Spaltbreite'], p['Materialstaerke_Korpus'], p['Breite'], p['Hoehe']
    h_f = "#{u}!Hoehe"

    tl = platte(model, 'Tür links', 'TürL', [r[:b_tuer], mk, h],
                ["#{u}!B_Tuer", "#{u}!Materialstaerke_Korpus", h_f], art: 'Tür')
    tuer_drehen(tl, -100)
    einsetzen(e, tl, 'TürL', [sp / 2.0, -sp, 0], ["#{u}!Spaltbreite/2", "-#{u}!Spaltbreite", nil], mat: mat, kz: t_.('TuerL'))

    # rechts: Drehpunkt muss rechts liegen, deshalb steckt die Tür in einem
    # Halter am Scharnier und liegt darin bei x = -Breite der Tür
    halter = model.definitions.add('Tür rechts Halter')
    stempel(halter)
    halter.set_attribute(DICT, '_name', 'TuerRHalter')
    attribut(halter, 'B_Tuer', r[:b_tuer], units: 'STRING', formula: "#{u}!B_Tuer")
    attribut(halter, 'H_Tuer', h, units: 'STRING', formula: h_f)
    attribut(halter, 'Mk', mk, units: 'STRING', formula: "#{u}!Materialstaerke_Korpus")
    tuer_drehen(halter, 100)
    hn = 'TuerRHalter'
    tr = platte(model, 'Tür rechts', 'TürR', [r[:b_tuer], mk, h],
                ["#{hn}!B_Tuer", "#{hn}!Mk", "#{hn}!H_Tuer"], art: 'Tür')
    einsetzen(halter.entities, tr, 'TürR', [-r[:b_tuer], 0, 0], ["-#{hn}!B_Tuer", nil, nil], mat: mat, kz: t_.('TuerR'))
    einsetzen(e, halter, hn, [b - sp / 2.0, -sp, 0], ["#{u}!Breite-#{u}!Spaltbreite/2", "-#{u}!Spaltbreite", nil])
  end

  def self.tuer_drehen(d, winkel)
    d.set_attribute(DICT, 'rotz', 0.0)
    d.set_attribute(DICT, 'onclick', "ANIMATE(\"ROTZ\",0,#{winkel})")
    d.set_attribute(DICT, '_onclick_label', 'onClick')
  end

  # ---------------------------------------------------------------------------
  # Erzeugen (mit ziel zusätzlich als .skp speichern)
  # ---------------------------------------------------------------------------
  # Neuer Schrank: Maße beim Anlegen abfragen, Tiefe = Korpus ohne Front/Rückwand. Danach bleiben sie im
  # Fenster Komponentenoptionen änderbar; alle abhängigen Teile folgen dort per Formel.
  TIEFE_NEU = 52.0 # cm, Vorschlag im Dialog
  TIEFE_MIN = 20.0

  def self.dialog
    Kuechenplaner::Eingabe.abfragen(['Breite (mm)', 'Höhe (mm)', 'Tiefe Korpus (mm)'],
                      [(DEFAULTS['Breite'] * 10).round.to_s, (DEFAULTS['Hoehe'] * 10).round.to_s, (TIEFE_NEU * 10).round.to_s], 'Unterschrank mit Doppeltür', untertitel: 'Neuer Schrank', ok: 'Einfügen') do |res|
      w = res.map { |v| v.to_s.tr(',', '.').to_f / 10.0 }
      eingabe = { 'Breite' => w[0], 'Hoehe' => w[1], 'Tiefe' => w[2] }
      t = eingabe['Tiefe']
      raise ArgumentError, "Tiefe #{(t * 10).round} mm ist zu klein (mindestens #{(TIEFE_MIN * 10).round} mm)" if t < TIEFE_MIN
      raise ArgumentError, 'Maße müssen größer als 0 sein' if eingabe.values.any? { |v| v <= 0 }
      erstellen(eingabe)
    end
  rescue ArgumentError => e
    UI.messagebox("Ungültige Eingabe: #{e.message}")
  end

  def self.erstellen(eingabe = {}, ziel = nil)
    model = Sketchup.active_model
    model.start_operation('Unterschrank mit Doppeltür', true)
    defn = erzeuge(model, eingabe)
    x = model.entities.length > 0 ? model.bounds.max.x + 10.cm : 0
    inst = model.entities.add_instance(defn, Geom::Transformation.translation([x, 0, 0]))
    inst.name = NAME
    inst.set_attribute(DICT, '_name', NAME)
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
        UI.messagebox('Automatisches Speichern ging nicht. Rechtsklick auf den Unterschrank → "Speichern unter…"')
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
  Kuechenplaner.schrank('Unterschränke', 'Unterschrank mit Doppeltür…') { UnterschrankDoppeltuer.dialog }
  file_loaded(__FILE__)
end
