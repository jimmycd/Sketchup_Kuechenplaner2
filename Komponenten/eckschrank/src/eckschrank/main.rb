# encoding: UTF-8
#
# Eck-Unterschrank – erzeugt eine Dynamic Component
#
# Erweiterung (.rbz): Erweiterungen > Küchenplaner > Unterschränke > Eckschrank Blindeck bzw.
# Eckschrank L-Form baut den Schrank im aktuellen Modell.
#
# Blindeck: gerader Korpus wie der Unterschrank mit Tür; ein Teil der Breite steckt
# hinter der Nachbarzeile und ist mit einer festen Blende zu. Variante in den
# Komponentenoptionen: eine Tür, zwei Türen oder Le Mans (Kesseböhmer LeMans II,
# Montageanleitung MA 406954 0000). Die Blindseite (links/rechts) ist umschaltbar.
# Der Le-Mans-Beschlag ist als Platzhalter gezeichnet (Material "Kesseböhmer
# LeMans II", OpenCutList-Typ Beschlag, kein JT_Schrank); die Bohrungen für
# Säulenlager und Seitenprofil setzt der TCN-Export.
#
# L-Form: L-förmiger Korpus mit zwei Schenkeln und Falttür. Boden und Einlegeböden
# sind je eine L-förmige Platte; die Innenecke fräst der TCN-Export aus. Weil eine
# Dynamic Component eine L-Fläche beim Skalieren verzerren würde, werden
# Schenkellängen und Tiefe beim Erzeugen festgelegt (Dialog); Höhe und Einlegeböden
# bleiben Komponentenoptionen.
#
# OpenCutList: Platten haben das Material "Melamin weiss" (Plattenwerkstoff),
# sichtbare Kanten das Material "Anleimer Melamin weiss" (Kante, 2 mm, wird nur
# in OCL abgezogen; gezeichnet wird das Endmaß). Die Kanten der Innenecke einer
# L-Platte kann OCL nicht als Anleimer erkennen (OCL sieht nur die Außenseiten);
# der TCN-Export fräst sie 2 mm zurück. Jedes Teil hat einen eigenen Tag
# <Kürzel>_<Teil> (z. B. UES1_SeiteL, UES1_Blende) und das Wörterbuch "JT_Schrank"
# für den TCN-Export. Anderes Kürzel:
#   Eckschrank.erstellen({ 'Kuerzel' => 'UES2' })

require 'sketchup.rb'

module Eckschrank

  DICT     = 'dynamic_attributes'.freeze
  NAME     = 'Eckschrank_Blindeck'.freeze
  NAME_L   = 'Eckschrank_L'.freeze
  MATERIAL = 'Melamin weiss'.freeze
  KANTE    = 'Anleimer Melamin weiss'.freeze
  BESCHLAG = 'Kesseböhmer LeMans II'.freeze
  OCL_DICT = 'ladb_opencutlist'.freeze
  KUERZEL  = 'UES'.freeze
  L_DICT   = 'JT_Eckschrank'.freeze
  L_GEBAUT = 'l_gebaut'.freeze # [Schenkel A, Schenkel B, Tiefe] in cm, mit denen die L-Form gebaut ist
  L_MASSE  = %w[Schenkel_A Schenkel_B Tiefe].freeze

  # Tag-Schema für den TCN-Export (gleich in allen Komponenten, der Test prüft das):
  # Tag <Kürzel>_<Bereich>_<Teil>, dazu am Teil das Wörterbuch JT_Schrank.
  JT_DICT   = 'JT_Schrank'.freeze
  TYP       = 'Eckschrank'.freeze
  KATEGORIE = 'Unterschrank'.freeze # Unterschrank, Oberschrank oder Hochschrank
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

  # Blindeck-Varianten (Komponentenoption "Variante")
  EINE_TUER  = 0
  ZWEI_TUEREN = 1
  LEMANS     = 2
  # Kesseböhmer LeMans II (MA 406954 0000, S. 3 und 11): Türbreite (cm) =>
  # X = Innenseite der Seite auf der Türseite bis Säulenlager, kleinste Korpusbreite (cm)
  LEMANS_MODELLE = {
    40 => { x: 42.6, korpus: 76.4 }, 45 => { x: 47.6, korpus: 80.0 },
    50 => { x: 52.6, korpus: 91.0 }, 60 => { x: 62.6, korpus: 96.0 }
  }.freeze
  BESCHLAG_NAME = 'Kesseboehmer LeMans II'.freeze # steht am Schrank in JT_Schrank/beschlag
  MAX_EB = 2

  # Standardwerte in cm. Tiefe 560 wie in Jürgens Beispiel-TCN (Seite DH 558):
  # mit 800 hätte eine L-Form 900 x 900 keinen Innenraum.
  FEST = {
    'Materialstaerke_Korpus'    => 1.9,
    'Materialstarke_Rueckwand'  => 0.8,
    'BreiteStreben'             => 10.0,
    'Spaltbreite'               => 0.2,
    'Rueckversatz_Einlegeboden' => 1.0   # Einlegeböden vorne zurückgesetzt
  }.freeze
  DEFAULTS = FEST.merge(
    'Variante'          => 0.0,   # 0 = eine Tür, 1 = zwei Türen, 2 = Le Mans
    'Blindseite'        => 0.0,   # 0 = links (Tür rechts), 1 = rechts (Tür links)
    'Breite'            => 100.0,
    'Tuerbreite'        => 50.0,  # Türbereich (bei zwei Türen beide zusammen)
    'LeMans'            => 50.0,  # LeMans 40/45/50/60 = Türbreite in cm
    'Hoehe'             => 70.0,
    'Tiefe'             => 56.0,  # Korpus ohne Front/Rückwand
    'Anz_Einlegeboeden' => 1.0,
    'Tiefe_Nachbar'     => 58.9,  # Wand bis Frontfläche des Nachbarschranks (8 + 560 + 19 + 2 mm)
    'Passleiste'        => 5.0    # sichtbare Blende neben der Tür, Abstand zu Front und Griff des Nachbarn
  ).freeze
  DEFAULTS_L = FEST.merge(
    'Schenkel_A'        => 90.0,  # entlang der hinteren Wand: Außenmaß Rückwand links bis Seite rechts
    'Schenkel_B'        => 90.0,  # entlang der linken Wand: Außenmaß Rückwand hinten bis Seite vorne
    'Hoehe'             => 70.0,
    'Tiefe'             => 56.0,
    'Anz_Einlegeboeden' => 1.0
  ).freeze

  # Kurzhilfe in der Komponente (Kurzfassung der README.md). SketchUp zeigt
  # "summary" und "description" oben im Fenster "Komponentenoptionen".
  DOKU_URL = 'https://github.com/jimmycd/sketchup_kuechenplaner2/tree/main/Komponenten/eckschrank'.freeze
  HILFE_KURZ = 'Eck-Unterschrank Blindeck: eine Tür, zwei Türen oder Le Mans (Kesseböhmer), OpenCutList-fähig'.freeze
  HILFE = [
    'Variante, Blindseite, Breite, Türbreite, LeMans-Größe, Höhe, Tiefe und Einlegeböden hier ändern.',
    'Der Blindteil steckt hinter der Nachbarzeile und ist mit einer festen Blende zu.',
    '„Abstand zur Wand“ zeigt, wie weit die Blindseite von der Seitenwand wegbleiben muss, damit neben der Tür die Passleiste frei bleibt (aus Tiefe des Nachbarn und Passleiste).',
    'Le Mans (Kesseböhmer LeMans II): Türbreite = LeMans-Größe (40/45/50/60 cm), Korpus mindestens 764/800/910/960 mm breit und 500 mm tief; Einlegeböden entfallen.',
    'Der Beschlag ist als Platzhalter gezeichnet; OpenCutList führt ihn als Beschlag. Bohrungen setzt der TCN-Export.',
    'Mit „Interagieren“ öffnen sich die Türen.',
    'Gezeichnet ist das Endmaß; den Anleimer (2 mm) zieht nur OpenCutList ab.',
    'Jedes Teil hat einen eigenen Tag <Kürzel>_<Teil>, z. B. UES1_SeiteL, UES1_Blende.',
    'Feste Maße (Materialstärken, Streben, Spalt): Fenster „Komponentenattribute“.',
    "Doku: #{DOKU_URL}"
  ].join(' ').freeze
  HILFE_KURZ_L = 'Eck-Unterschrank L-Form mit Falttür, OpenCutList-fähig'.freeze
  HILFE_L = [
    'L-förmiger Korpus, Falttür (zwei Türen mit Blum-Scharnier verbunden).',
    'Schenkel A, Schenkel B, Tiefe, Höhe und Anzahl Einlegeböden hier ändern.',
    'Nach einer Änderung von Schenkel oder Tiefe baut die Erweiterung den Schrank neu auf (eine L-Platte lässt sich nicht per Formel umformen); Frontmaterial und Griffe bleiben erhalten.',
    'Boden und Einlegeböden sind je eine L-Platte; die Innenecke fräst der TCN-Export aus. OpenCutList rechnet mit dem Rechteck; die Anleimer der Innenecke erkennt OCL nicht.',
    'Gezeichnet ist das Endmaß; den Anleimer (2 mm) zieht nur OpenCutList ab.',
    'Jedes Teil hat einen eigenen Tag <Kürzel>_<Teil>, z. B. UES1_Boden, UES1_TuerL.',
    "Doku: #{DOKU_URL}"
  ].join(' ').freeze

  # ---------------------------------------------------------------------------
  # Reine Berechnung (ohne SketchUp), spiegelt die DC-Formeln. Werte in cm.
  # ---------------------------------------------------------------------------
  def self.lemans(p)
    LEMANS_MODELLE.fetch(p['LeMans'].to_i) { raise ArgumentError, "LeMans #{p['LeMans'].to_i} gibt es nicht (40, 45, 50, 60)" }
  end

  def self.berechne(p)
    mk, h, n = p['Materialstaerke_Korpus'], p['Hoehe'], p['Anz_Einlegeboeden'].to_i
    tb = p['Variante'].to_i == LEMANS ? p['LeMans'].to_f : p['Tuerbreite']
    raise ArgumentError, "Türbreite #{tb} cm passt nicht in Breite #{p['Breite']} cm" unless tb > 2 * p['Spaltbreite'] && tb < p['Breite']
    { tb: tb, x_lm: lemans(p)[:x],
      abstand: [p['Tiefe_Nachbar'] + p['Passleiste'] - p['Breite'] + tb, 0].max,
      eb: (1..MAX_EB).map { |k| n >= k ? mk + (h - 2 * mk) * k / (n + 1) - mk / 2 : mk } }
  end

  # x-Lage bei Blindseite links (Tür rechts) -> tatsächliche Lage; Formel und Wert
  def self.spiegel_f(xl, w)
    "IF(#{NAME}!Blindseite=1,#{NAME}!Breite-(#{xl})-(#{w}),#{xl})"
  end
  def self.spiegel(p, xl, w)
    p['Blindseite'].to_i == 1 ? p['Breite'] - xl - w : xl
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
  def self.hilfe(d, kurz = HILFE_KURZ, lang = HILFE)
    d.description = kurz
    { 'summary' => ['Summary', kurz], 'description' => ['Description', lang] }.each do |k, (label, text)|
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

  # Kaufteil: OCL-Typ 5 = Beschlag (erscheint in OCL als Beschlag, nicht als Platte)
  def self.beschlag_material(model)
    ocl_material(model, BESCHLAG, [150, 150, 155], 'type' => 5, 'description' => 'Kesseböhmer LeMans II, 2 Tablare')
  end

  # Freies Kürzel für die Tags, z. B. UES1, UES2 …
  def self.freies_kuerzel(model)
    n = 1
    n += 1 while model.layers.to_a.any? { |l| l.name.start_with?("#{KUERZEL}#{n}_") }
    "#{KUERZEL}#{n}"
  end

  def self.tag(model, name)
    model.layers[name] || model.layers.add(name)
  end

  # Tag <Kürzel>_<Bereich>_<Teil> (z. B. UES1_SeiteL) und JT_Schrank am Teil
  def self.kennzeichnen(model, inst, kz, teil, bereich = nil)
    inst.layer = tag(model, [kz, bereich, teil].compact.join('_'))
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE, 'bereich' => bereich.to_s,
      'teil' => teil, 'rolle' => ROLLEN.fetch(teil.sub(/\d+\z/, '')) }.each { |k, v| inst.set_attribute(JT_DICT, k, v) }
    inst
  end

  SEITEN = { xmin: [0, -1], xmax: [0, 1], ymin: [1, -1], ymax: [1, 1], zmin: [2, -1], zmax: [2, 1] }.freeze

  # Sichtbare Kanten je Teil, bekommen in OCL einen Anleimer (wie Unterschrank mit Tür).
  # ymin = vorne, zmin/zmax = unten/oben, xmin/xmax = links/rechts.
  # In der L-Form zeigt die Vorderkante des linken Schenkels nach +x (…B).
  KANTEN = {
    'Seite'        => %i[ymin],
    'SeiteB'       => %i[xmax],
    'Boden'        => %i[ymin],
    'StrebeVorn'   => %i[ymin],
    'StrebeVornB'  => %i[xmax],
    'StrebeHinten' => [],
    'Rückwand'     => [],
    'Einlegeboden' => %i[ymin],
    'Tür'          => %i[xmin xmax zmin zmax],
    'TürB'         => %i[ymin ymax zmin zmax],
    'Blende'       => %i[xmin xmax zmin zmax],
    'Beschlag'     => []
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

  # L-förmige Platte (L-Form: Boden, Einlegeböden): Rechteck lx x ly ohne die Ecke
  # vorne rechts (x >= ex, y <= ey). Die Kanten der Innenecke bleiben ohne Material,
  # OCL erkennt dort keinen Anleimer. Die Ecke steht als ecke_x/ecke_y (Zoll, lokal)
  # an der Definition, daraus fräst der TCN-Export den Ausschnitt.
  def self.l_platte(model, defname, dc_name, lx, ly, lz, ex, ey)
    d = model.definitions.add(defname)
    pts = [[ex, ey], [lx, ey], [lx, ly], [0, ly], [0, 0], [ex, 0]].map { |x, y| [inch(x), inch(y), 0] }
    f = d.entities.add_face(*pts)
    f.reverse! if f.normal.z < 0
    f.pushpull(inch(lz))
    stempel(d)
    d.set_attribute(DICT, '_name', dc_name)
    { 'lenx' => lx, 'leny' => ly, 'lenz' => lz, 'ecke_x' => ex, 'ecke_y' => ey }.each { |k, v| d.set_attribute(DICT, k, inch(v)) }
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

  def self.tuer_drehen(d, sichtbar, formel, winkel)
    sichtbarkeit(d, sichtbar, formel)
    d.set_attribute(DICT, 'rotz', 0.0)
    d.set_attribute(DICT, 'onclick', "ANIMATE(\"ROTZ\",0,#{winkel})")
    d.set_attribute(DICT, '_onclick_label', 'onClick')
  end

  def self.hauptteil(model, defname, dc_name, kz, kurz, lang)
    haupt = model.definitions.add(defname)
    stempel(haupt)
    haupt.set_attribute(DICT, '_name', dc_name)
    hilfe(haupt, kurz, lang)
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE }.each { |k, v| haupt.set_attribute(JT_DICT, k, v) }
    haupt
  end

  # ---------------------------------------------------------------------------
  # Blindeck
  # ---------------------------------------------------------------------------
  def self.erzeuge(model, eingabe = {})
    p = DEFAULTS.merge(eingabe)
    r = berechne(p)
    u = NAME
    mat = material(model)
    kanten_material(model)
    kz = p['Kuerzel'] || freies_kuerzel(model)
    t_ = ->(teil) { [model, kz, teil] }
    variante = p['Variante'].to_i

    haupt = hauptteil(model, 'Eckschrank Blindeck', u, kz, HILFE_KURZ, HILFE)
    haupt.set_attribute(JT_DICT, 'beschlag', BESCHLAG_NAME) # nur wirksam bei Variante Le Mans (Export prüft)

    # --- Parameter (Komponentenoptionen) ---
    attribut(haupt, 'Variante', p['Variante'].to_f, laenge: false, access: 'LIST', formlabel: 'Variante', units: 'INTEGER',
             options: '&eine%20T%C3%BCr=0&zwei%20T%C3%BCren=1&Le%20Mans%20(Kesseb%C3%B6hmer)=2&')
    attribut(haupt, 'Blindseite', p['Blindseite'].to_f, laenge: false, access: 'LIST', formlabel: 'Blindseite', units: 'INTEGER',
             options: '&links%20(T%C3%BCr%20rechts)=0&rechts%20(T%C3%BCr%20links)=1&')
    attribut(haupt, 'Breite', p['Breite'], access: 'TEXTBOX', formlabel: 'Breite')
    attribut(haupt, 'Tuerbreite', p['Tuerbreite'], access: 'TEXTBOX', formlabel: 'Türbreite (eine/zwei Türen, mit Fugen)')
    attribut(haupt, 'LeMans', p['LeMans'].to_f, laenge: false, access: 'LIST', formlabel: 'LeMans-Größe = Türbreite',
             units: 'INTEGER', options: '&LeMans%2040=40&LeMans%2045=45&LeMans%2050=50&LeMans%2060=60&')
    attribut(haupt, 'Hoehe', p['Hoehe'], access: 'TEXTBOX', formlabel: 'Höhe')
    attribut(haupt, 'Tiefe', p['Tiefe'], access: 'TEXTBOX', formlabel: 'Tiefe (Korpus ohne Front/Rückwand)')
    attribut(haupt, 'Anz_Einlegeboeden', p['Anz_Einlegeboeden'].to_f, laenge: false, access: 'LIST',
             formlabel: 'Anzahl Einlegeböden (nicht bei Le Mans)', units: 'INTEGER', options: '&0=0&1=1&2=2&')
    attribut(haupt, 'Tiefe_Nachbar', p['Tiefe_Nachbar'], access: 'TEXTBOX', formlabel: 'Nachbarschrank: Wand bis Front')
    attribut(haupt, 'Passleiste', p['Passleiste'], access: 'TEXTBOX', formlabel: 'Passleiste (sichtbare Blende)')
    attribut(haupt, 'Abstand_Wand', r[:abstand], access: 'VIEW', formlabel: 'Abstand Blindseite zur Wand',
             formula: 'MAX(Tiefe_Nachbar+Passleiste-Breite+TB,0)')

    # --- Feste Maße (über Komponentenattribute änderbar) ---
    FEST.each_key { |n| attribut(haupt, n, p[n], units: 'STRING') }

    # --- Abgeleitete Werte ---
    attribut(haupt, 'TB', r[:tb], units: 'STRING', formula: 'IF(Variante=2,LeMans,Tuerbreite)')
    attribut(haupt, 'X_LeMans', r[:x_lm], units: 'STRING',
             formula: 'IF(LeMans=40,42.6,IF(LeMans=45,47.6,IF(LeMans=50,52.6,62.6)))')
    (1..MAX_EB).each do |k|
      f = "IF(Anz_Einlegeboeden>=#{k},Materialstaerke_Korpus+(Hoehe-2*Materialstaerke_Korpus)*#{k}/" \
          "(Anz_Einlegeboeden+1)-Materialstaerke_Korpus/2,Materialstaerke_Korpus)"
      attribut(haupt, "Z_Einlegeboden_#{k}", r[:eb][k - 1], units: 'STRING', formula: f)
    end

    mk = p['Materialstaerke_Korpus']
    b, h, t = p['Breite'], p['Hoehe'], p['Tiefe']
    bs, rw = p['BreiteStreben'], p['Materialstarke_Rueckwand']
    e = haupt.entities
    innen_b = "#{u}!Breite-2*#{u}!Materialstaerke_Korpus"

    # --- Korpus wie Unterschrank mit Tür ---
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
    einsetzen(e, strebe_h, 'StrebeHinten', [mk, t - bs + mk, h - mk],
              ["#{u}!Materialstaerke_Korpus", "#{u}!Tiefe-#{u}!BreiteStreben+#{u}!Materialstaerke_Korpus",
               "#{u}!Hoehe-#{u}!Materialstaerke_Korpus"], mat: mat, kz: t_.('StrebeHinten'))

    rueck = platte(model, 'Rückwand', 'Rückwand', [b, rw, h],
                   ["#{u}!Breite", "#{u}!Materialstarke_Rueckwand", "#{u}!Hoehe"])
    einsetzen(e, rueck, 'Rückwand', [0, t + mk, 0],
              [nil, "#{u}!Tiefe+#{u}!Materialstaerke_Korpus", nil], mat: mat, kz: t_.('Rueckwand'))

    # --- Einlegeböden (gleichmäßig verteilt, bei Le Mans keine) ---
    rv = p['Rueckversatz_Einlegeboden']
    (1..MAX_EB).each do |k|
      d = platte(model, "Einlegeboden #{k}", "Einlegeboden#{k}", [b - 2 * mk, t - rv, mk],
                 [innen_b, "#{u}!Tiefe-#{u}!Rueckversatz_Einlegeboden", "#{u}!Materialstaerke_Korpus"], art: 'Einlegeboden')
      sichtbar = variante != LEMANS && p['Anz_Einlegeboeden'].to_i >= k
      sichtbarkeit(d, sichtbar, "IF(OR(#{u}!Variante=2,#{u}!Anz_Einlegeboeden<#{k}),1,0)")
      inst = einsetzen(e, d, "Einlegeboden#{k}", [mk, mk + rv, r[:eb][k - 1]],
                       ["#{u}!Materialstaerke_Korpus", "#{u}!Materialstaerke_Korpus+#{u}!Rueckversatz_Einlegeboden",
                        "#{u}!Z_Einlegeboden_#{k}"], mat: mat, kz: t_.("Einlegeboden#{k}"))
      inst.hidden = !sichtbar
    end

    fronten(model, e, p, r, mat, t_)
    lemans_platzhalter(model, e, p, r, kz)
    haupt
  end

  # Blende vor dem Blindteil, Tür(en) im Türbereich TB an der offenen Seite.
  # Fugen wie beim Unterschrank mit Tür: außen Spalt/2, dazwischen Spalt.
  def self.fronten(model, e, p, r, mat, t_)
    u = NAME
    sp, mk, b, h, tb = p['Spaltbreite'], p['Materialstaerke_Korpus'], p['Breite'], p['Hoehe'], r[:tb]
    variante = p['Variante'].to_i
    h_f = "#{u}!Hoehe"
    mk_f = "#{u}!Materialstaerke_Korpus"

    # Blende über dem Blindteil (Rolle Front, bekommt Frontfarbe, aber keinen Griff)
    wb = b - tb - sp
    bl = platte(model, 'Blende', 'Blende', [wb, mk, h], ["#{u}!Breite-#{u}!TB-#{u}!Spaltbreite", mk_f, h_f])
    einsetzen(e, bl, 'Blende', [spiegel(p, sp / 2.0, wb), -sp, 0],
              [spiegel_f("#{u}!Spaltbreite/2", "#{u}!Breite-#{u}!TB-#{u}!Spaltbreite"), "-#{u}!Spaltbreite", nil],
              mat: mat, kz: t_.('Blende'))

    # Eine Tür (auch Le Mans), Anschlag an der offenen Seite: Drehpunkt an der Außenkante,
    # die Tür steckt in einem Halter am Scharnier
    eine = variante != ZWEI_TUEREN
    links = p['Blindseite'].to_i == 1 # Tür links
    halter = model.definitions.add('Tür Halter')
    stempel(halter)
    halter.set_attribute(DICT, '_name', 'TuerHalter')
    hn = 'TuerHalter'
    attribut(halter, 'B_Tuer', tb - sp, units: 'STRING', formula: "#{u}!TB-#{u}!Spaltbreite")
    attribut(halter, 'H_Tuer', h, units: 'STRING', formula: h_f)
    attribut(halter, 'Mk', mk, units: 'STRING', formula: mk_f)
    attribut(halter, 'Links', links ? 1.0 : 0.0, laenge: false, formula: "#{u}!Blindseite")
    attribut(halter, 'Winkel', links ? -100.0 : 100.0, laenge: false, formula: 'IF(Links=1,-100,100)')
    tuer_drehen(halter, eine, "IF(#{u}!Variante=1,1,0)", 'Winkel')
    t1 = platte(model, 'Tür', 'Tür', [tb - sp, mk, h], ["#{hn}!B_Tuer", "#{hn}!Mk", "#{hn}!H_Tuer"])
    einsetzen(halter.entities, t1, 'Tür', [links ? 0 : -(tb - sp), 0, 0], ["IF(#{hn}!Links=1,0,-#{hn}!B_Tuer)", nil, nil],
              mat: mat, kz: t_.('Tuer'))
    ih = einsetzen(e, halter, hn, [links ? sp / 2.0 : b - sp / 2.0, -sp, 0],
                   ["IF(#{u}!Blindseite=1,#{u}!Spaltbreite/2,#{u}!Breite-#{u}!Spaltbreite/2)", "-#{u}!Spaltbreite", nil])
    ih.hidden = !eine

    # Zwei Türen im Türbereich: links um die linke, rechts um die rechte Kante
    zwei = variante == ZWEI_TUEREN
    zwei_f = "IF(#{u}!Variante=1,0,1)"
    w2 = tb / 2.0 - sp
    w2_f = "#{u}!TB/2-#{u}!Spaltbreite"
    tl = platte(model, 'Tür links', 'TürL', [w2, mk, h], [w2_f, mk_f, h_f], art: 'Tür')
    tuer_drehen(tl, zwei, zwei_f, -100)
    il = einsetzen(e, tl, 'TürL', [links ? sp / 2.0 : b - tb + sp / 2.0, -sp, 0],
                   ["IF(#{u}!Blindseite=1,#{u}!Spaltbreite/2,#{u}!Breite-#{u}!TB+#{u}!Spaltbreite/2)", "-#{u}!Spaltbreite", nil],
                   mat: mat, kz: t_.('TuerL'))
    il.hidden = !zwei

    hr = model.definitions.add('Tür rechts Halter')
    stempel(hr)
    hr.set_attribute(DICT, '_name', 'TuerRHalter')
    hrn = 'TuerRHalter'
    attribut(hr, 'B_Tuer', w2, units: 'STRING', formula: w2_f)
    attribut(hr, 'H_Tuer', h, units: 'STRING', formula: h_f)
    attribut(hr, 'Mk', mk, units: 'STRING', formula: mk_f)
    tuer_drehen(hr, zwei, zwei_f, 100)
    tr = platte(model, 'Tür rechts', 'TürR', [w2, mk, h], ["#{hrn}!B_Tuer", "#{hrn}!Mk", "#{hrn}!H_Tuer"], art: 'Tür')
    einsetzen(hr.entities, tr, 'TürR', [-w2, 0, 0], ["-#{hrn}!B_Tuer", nil, nil], mat: mat, kz: t_.('TuerR'))
    ir = einsetzen(e, hr, hrn, [links ? tb - sp / 2.0 : b - sp / 2.0, -sp, 0],
                   ["IF(#{u}!Blindseite=1,#{u}!TB-#{u}!Spaltbreite/2,#{u}!Breite-#{u}!Spaltbreite/2)", "-#{u}!Spaltbreite", nil])
    ir.hidden = !zwei
  end

  # Platzhalter Kesseböhmer LeMans II: Einbauraum von der Innenseite der Seite an der
  # Tür bis zum Säulenlager (X), Tiefe bis 500 mm, Boden bis unter die Streben.
  # Kein JT_Schrank (kein Werkstück), eigener Tag für die Zuordnung in OCL.
  def self.lemans_platzhalter(model, e, p, r, kz)
    u = NAME
    mk, h, t = p['Materialstaerke_Korpus'], p['Hoehe'], p['Tiefe']
    x = r[:x_lm]
    ty = [t, 50.0].min
    g = platte(model, 'LeMans II', 'Beschlag', [x, ty, h - 2 * mk],
               ["#{u}!X_LeMans", "MIN(#{u}!Tiefe,50)", "#{u}!Hoehe-2*#{u}!Materialstaerke_Korpus"], art: 'Beschlag')
    sichtbar = p['Variante'].to_i == LEMANS
    sichtbarkeit(g, sichtbar, "IF(#{u}!Variante=2,0,1)")
    xl = p['Breite'] - mk - x
    ig = einsetzen(e, g, 'LeMans', [spiegel(p, xl, x), mk, mk],
                   [spiegel_f("#{u}!Breite-#{u}!Materialstaerke_Korpus-#{u}!X_LeMans", "#{u}!X_LeMans"),
                    "#{u}!Materialstaerke_Korpus", "#{u}!Materialstaerke_Korpus"],
                   mat: beschlag_material(model), layer: tag(model, "#{kz}_LeMans"))
    ig.hidden = !sichtbar
  end

  # ---------------------------------------------------------------------------
  # L-Form mit Falttür
  #
  # Draufsicht: Schenkel A entlang der hinteren Wand (y = Wand A), Schenkel B entlang
  # der linken Wand (x = 0). Der Korpus von A beginnt wie bei allen Unterschränken bei
  # y = Materialstärke, die Front liegt davor; Schenkel B ragt nach vorne (-y) heraus,
  # seine Front zeigt nach +x. Die Innenecke liegt bei x = Rückwand + Tiefe, y = Mk.
  # ---------------------------------------------------------------------------
  def self.masse_l(p)
    mk, t, rw, sp, rv = p['Materialstaerke_Korpus'], p['Tiefe'], p['Materialstarke_Rueckwand'], p['Spaltbreite'],
                        p['Rueckversatz_Einlegeboden']
    a, bb = p['Schenkel_A'], p['Schenkel_B']
    yw = mk + t + rw # Wand hinter Schenkel A
    xk = rw + t      # Korpusvorderkante Schenkel B
    ye = yw - bb + mk # Innenseite der Seite am Ende von Schenkel B
    raise ArgumentError, "Tiefe #{t} cm: mindestens #{2 * p['BreiteStreben'] + 10} cm" if t < 2 * p['BreiteStreben'] + 10
    { 'Schenkel A' => a - mk - xk, 'Schenkel B' => mk - ye }.each do |n, frei|
      raise ArgumentError, "#{n} zu kurz: Innenraum vor der Ecke #{frei.round(1)} cm (mindestens 15 cm)" if frei < 15
    end
    { yw: yw, xk: xk, ye: ye, rv: rv, sp: sp,
      boden: [a - mk - rw, mk + t - ye], ecke: [t, mk - ye], ecke_eb: [t - rv, mk + rv - ye] }
  end

  def self.erzeuge_l(model, eingabe = {})
    p = DEFAULTS_L.merge(eingabe)
    m = masse_l(p)
    u = NAME_L
    mat = material(model)
    kanten_material(model)
    kz = p['Kuerzel'] || freies_kuerzel(model)
    t_ = ->(teil) { [model, kz, teil] }
    mk, h, t, rw, bs, sp = p['Materialstaerke_Korpus'], p['Hoehe'], p['Tiefe'], p['Materialstarke_Rueckwand'],
                           p['BreiteStreben'], p['Spaltbreite']
    a, bb = p['Schenkel_A'], p['Schenkel_B']
    yw, xk, ye = m[:yw], m[:xk], m[:ye]
    n = p['Anz_Einlegeboeden'].to_i

    haupt = hauptteil(model, 'Eckschrank L-Form', u, kz, HILFE_KURZ_L, HILFE_L)
    # Schenkel und Tiefe sind änderbar, aber eine L-Platte lässt sich nicht per Formel
    # umformen: nach einer Änderung baut l_pruefen den Schrank neu auf (L_GEBAUT merkt
    # sich die Maße, mit denen er gebaut ist)
    attribut(haupt, 'Schenkel_A', a, access: 'TEXTBOX', formlabel: 'Schenkel A (hinten)')
    attribut(haupt, 'Schenkel_B', bb, access: 'TEXTBOX', formlabel: 'Schenkel B (links)')
    attribut(haupt, 'Tiefe', t, access: 'TEXTBOX', formlabel: 'Tiefe')
    haupt.set_attribute(L_DICT, L_GEBAUT, [a, bb, t])
    attribut(haupt, 'Hoehe', h, access: 'TEXTBOX', formlabel: 'Höhe')
    attribut(haupt, 'Anz_Einlegeboeden', n.to_f, laenge: false, access: 'LIST', formlabel: 'Anzahl Einlegeböden',
             units: 'INTEGER', options: '&0=0&1=1&2=2&')
    FEST.each_key { |k| attribut(haupt, k, p[k], units: 'STRING') }
    eb = (1..MAX_EB).map do |k|
      f = "IF(Anz_Einlegeboeden>=#{k},Materialstaerke_Korpus+(Hoehe-2*Materialstaerke_Korpus)*#{k}/" \
          "(Anz_Einlegeboeden+1)-Materialstaerke_Korpus/2,Materialstaerke_Korpus)"
      z = n >= k ? mk + (h - 2 * mk) * k / (n + 1) - mk / 2 : mk
      attribut(haupt, "Z_Einlegeboden_#{k}", z, units: 'STRING', formula: f)
      z
    end

    e = haupt.entities
    h_f = "#{u}!Hoehe"
    oben_f = [nil, nil, "#{u}!Hoehe-#{u}!Materialstaerke_Korpus"]
    hoch = ->(defname, name, gr, art) { platte(model, defname, name, gr, [nil, nil, h_f], art: art) }

    # Seiten an den Enden der Schenkel
    einsetzen(e, hoch.('Seite', 'Seite', [mk, t, h], 'Seite'), 'SeiteR', [a - mk, mk, 0], [nil, nil, nil],
              mat: mat, kz: t_.('SeiteR'))
    einsetzen(e, hoch.('Seite Schenkel B', 'Seite', [t, mk, h], 'SeiteB'), 'SeiteL', [rw, yw - bb, 0], [nil, nil, nil],
              mat: mat, kz: t_.('SeiteL'))

    # L-Boden zwischen den Seiten bis an die Rückwände
    boden = l_platte(model, 'Boden L', 'Boden', *m[:boden], mk, *m[:ecke])
    einsetzen(e, boden, 'Boden', [rw, ye, 0], [nil, nil, nil], mat: mat, kz: t_.('Boden'))

    # Streben oben (Jürgen 2026-10-28): die vordere Strebe von A läuft durch die Ecke bis an
    # die Rückwand von B, die vordere Strebe von B stößt mit dem Ende an sie. Hinten liegt
    # eine Strebe über die ganze Länge von A an der Wand; Schenkel B hat hinten keine.
    {
      'StrebeVorn1' => ['Strebe vorn A', [rw, mk], [a - mk - rw, bs], 'StrebeVorn'],
      'StrebeVorn2' => ['Strebe vorn B', [xk - bs, ye], [bs, mk - ye], 'StrebeVornB'],
      'StrebeHinten' => ['Strebe hinten A', [rw, mk + t - bs], [a - mk - rw, bs], 'StrebeHinten']
    }.each do |name, (defname, (x, y), (lx, ly), art)|
      d = platte(model, defname, name.sub(/\d\z/, ''), [lx, ly, mk], [nil, nil, nil], art: art)
      einsetzen(e, d, name, [x, y, h - mk], oben_f, mat: mat, kz: t_.(name))
    end

    # Rückwände hinter dem Korpus; die von A geht durch die Ecke
    einsetzen(e, hoch.('Rückwand A', 'Rückwand', [a, rw, h], 'Rückwand'), 'Rückwand1', [0, mk + t, 0], [nil, nil, nil],
              mat: mat, kz: t_.('Rueckwand1'))
    einsetzen(e, hoch.('Rückwand B', 'Rückwand', [rw, mk + t - (yw - bb), h], 'Rückwand'), 'Rückwand2', [0, yw - bb, 0],
              [nil, nil, nil], mat: mat, kz: t_.('Rueckwand2'))

    # L-Einlegeböden, vorne zurückgesetzt
    (1..MAX_EB).each do |k|
      d = l_platte(model, "Einlegeboden L #{k}", "Einlegeboden#{k}", *m[:boden], mk, *m[:ecke_eb])
      sichtbarkeit(d, n >= k, "IF(#{u}!Anz_Einlegeboeden<#{k},1,0)")
      inst = einsetzen(e, d, "Einlegeboden#{k}", [rw, ye, eb[k - 1]], [nil, nil, "#{u}!Z_Einlegeboden_#{k}"],
                       mat: mat, kz: t_.("Einlegeboden#{k}"))
      inst.hidden = n < k
    end

    # Falttür: Tür A (TuerR) vor Schenkel A läuft durch die Ecke, Tür B (TuerL) vor
    # Schenkel B endet mit einer Fuge vor der Front von A; verbunden mit einem Blum-Scharnier
    xa = xk + sp
    einsetzen(e, hoch.('Tür A', 'Tür', [a - sp / 2.0 - xa, mk, h], 'Tür'), 'TürR', [xa, -sp, 0], [nil, nil, nil],
              mat: mat, kz: t_.('TuerR'))
    yb0 = yw - bb + sp / 2.0
    einsetzen(e, hoch.('Tür B', 'Tür', [mk, -1.5 * sp - yb0, h], 'TürB'), 'TürL', [xa, yb0, 0], [nil, nil, nil],
              mat: mat, kz: t_.('TuerL'))
    haupt
  end

  # ---------------------------------------------------------------------------
  # L-Form nach dem Ändern von Schenkel oder Tiefe neu aufbauen
  # ---------------------------------------------------------------------------
  # Wert wie die DC ihn sieht: zuerst an der Instanz (dort schreibt das Fenster
  # Komponentenoptionen hin), sonst an der Definition
  def self.dc_wert(inst, k)
    v = inst.get_attribute(DICT, k.downcase)
    v = inst.definition.get_attribute(DICT, k.downcase) if v.nil?
    v
  end

  def self.dc_cm(inst, k)
    dc_wert(inst, k).to_f * 2.54
  end

  # Alle L-Eckschränke im Modell prüfen; geänderte Maße -> neu aufbauen
  def self.l_pruefen(model)
    model.definitions.to_a.select { |d| d.get_attribute(L_DICT, L_GEBAUT) }.each do |d|
      gebaut = d.get_attribute(L_DICT, L_GEBAUT)
      d.instances.to_a.each do |inst|
        neu = L_MASSE.map { |k| dc_cm(inst, k).round(2) }
        l_neu_aufbauen(model, inst, neu) unless neu.zip(gebaut).all? { |x, y| (x - y).abs < 0.01 }
      end
    end
  end

  def self.l_neu_aufbauen(model, inst, masse)
    alt = inst.definition
    gebaut = alt.get_attribute(L_DICT, L_GEBAUT)
    p = DEFAULTS_L.merge(L_MASSE.zip(masse).to_h)
    begin
      masse_l(p)
    rescue ArgumentError => e
      # ungültig: alte Maße zurück
      L_MASSE.zip(gebaut).each do |k, v|
        [inst, alt].each { |ent| ent.set_attribute(DICT, k.downcase, inch(v)) unless ent.get_attribute(DICT, k.downcase).nil? }
      end
      UI.messagebox("Eckschrank L-Form: #{e.message}. Die alten Maße bleiben.")
      return nil
    end
    p['Hoehe'] = dc_cm(inst, 'Hoehe')
    p['Anz_Einlegeboeden'] = dc_wert(inst, 'Anz_Einlegeboeden').to_f
    p['Kuerzel'] = alt.get_attribute(JT_DICT, 'schrank')
    FEST.each_key { |k| p[k] = dc_cm(inst, k) unless dc_wert(inst, k).nil? }
    # Frontmaterial und Griffe (Frontfarbe) der Teile merken
    vorher = alt.entities.grep(Sketchup::ComponentInstance).to_h do |c|
      [c.name, [c.material, c.attribute_dictionary(JT_DICT) && c.attribute_dictionary(JT_DICT).to_h]]
    end
    model.start_operation('Eckschrank L-Form ändern', true, false, true)
    neu = erzeuge_l(model, p)
    neu.entities.grep(Sketchup::ComponentInstance).each do |c|
      mat, jt = vorher[c.name]
      next unless mat || jt
      c.material = mat if mat
      jt.each { |k, v| c.set_attribute(JT_DICT, k, v) if k.start_with?('griff_') } if jt
    end
    inst.definition = neu
    L_MASSE.zip(masse).each { |k, v| inst.set_attribute(DICT, k.downcase, inch(v)) unless inst.get_attribute(DICT, k.downcase).nil? }
    model.definitions.remove(alt) if alt.instances.empty? && model.definitions.respond_to?(:remove)
    model.commit_operation
    if defined?($dc_observers) && $dc_observers
      $dc_observers.get_latest_class.redraw_with_undo(inst)
    end
    inst
  rescue StandardError
    model.abort_operation
    raise
  end

  # Nach jedem Vorgang (z. B. „Übernehmen“ im Fenster Komponentenoptionen) prüfen;
  # verzögert, weil das Modell im Beobachter nicht geändert werden soll
  if defined?(Sketchup::ModelObserver)
    class LBeobachter < Sketchup::ModelObserver
      def onTransactionCommit(model)
        return if @laeuft
        @laeuft = true
        UI.start_timer(0, false) do
          begin
            Eckschrank.l_pruefen(model)
          ensure
            @laeuft = false
          end
        end
      end
    end

    class LAppBeobachter < Sketchup::AppObserver
      def onNewModel(model)
        Eckschrank.beobachten(model)
      end

      def onOpenModel(model)
        Eckschrank.beobachten(model)
      end
    end
  end

  def self.beobachten(model)
    return unless model && defined?(LBeobachter)
    @beobachter ||= LBeobachter.new
    model.add_observer(@beobachter)
  end

  # ---------------------------------------------------------------------------
  # Erzeugen
  # ---------------------------------------------------------------------------
  def self.erstellen(eingabe = {}, l_form: false)
    model = Sketchup.active_model
    model.start_operation(l_form ? 'Eckschrank L-Form' : 'Eckschrank Blindeck', true)
    defn = l_form ? erzeuge_l(model, eingabe) : erzeuge(model, eingabe)
    x = model.entities.length > 0 ? model.bounds.max.x + 10.cm : 0
    inst = model.entities.add_instance(defn, Geom::Transformation.translation([x, 0, 0]))
    name = l_form ? NAME_L : NAME
    inst.name = name
    inst.set_attribute(DICT, '_name', name)
    model.commit_operation

    if defined?($dc_observers) && $dc_observers
      $dc_observers.get_latest_class.redraw_with_undo(inst)
    end
    model.selection.clear
    model.selection.add(inst)
    inst
  rescue StandardError => e
    model.abort_operation
    UI.messagebox("Fehler beim Erzeugen: #{e.message}")
    raise
  end

  # L-Form: Schenkel und Tiefe vor dem Erzeugen abfragen (mm)
  def self.dialog_l
    d = DEFAULTS_L
    werte = UI.inputbox(['Schenkel A, hinten (mm)', 'Schenkel B, links (mm)', 'Tiefe Korpus (mm)'],
                        [d['Schenkel_A'], d['Schenkel_B'], d['Tiefe']].map { |v| (v * 10).round.to_s },
                        'Eckschrank L-Form')
    return unless werte
    a, b, t = werte.map { |v| Float(v.tr(',', '.')) / 10.0 }
    erstellen({ 'Schenkel_A' => a, 'Schenkel_B' => b, 'Tiefe' => t }, l_form: true)
  rescue ArgumentError => e
    UI.messagebox("Ungültige Eingabe: #{e.message}")
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
  Kuechenplaner.untermenu('Unterschränke').add_item('Eckschrank Blindeck…') { Eckschrank.erstellen }
  Kuechenplaner.untermenu('Unterschränke').add_item('Eckschrank L-Form…') { Eckschrank.dialog_l }
  if defined?(Eckschrank::LAppBeobachter)
    Sketchup.add_observer(Eckschrank::LAppBeobachter.new)
    Eckschrank.beobachten(Sketchup.active_model)
  end
  file_loaded(__FILE__)
end
