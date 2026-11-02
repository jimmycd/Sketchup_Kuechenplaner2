# encoding: UTF-8
#
# Inselschrank (Unterschrank für eine Kücheninsel) – erzeugt eine Dynamic Component
#
# Erweiterung (.rbz): Erweiterungen > Küchenplaner > Unterschränke > Inselschrank baut den Schrank im
# aktuellen Modell. Maße und Optionen danach in den Komponentenoptionen einstellen.
#
# Aufbau: Korpus wie die anderen Unterschränke (Seiten, Boden, Streben oben, Rückwand hinter dem
# Korpus). Front: Türen (eine oder zwei, mit 0–2 Einlegeböden) oder 1–4 gleich hohe Schubladen
# (Blum LEGRABOX free wie beim Unterschrank mit Schubladen). Weil die Rückseite einer Insel sichtbar
# ist, kommt hinter die Rückwand eine Verkleidung (19 mm, bis zum Fußboden), dazu wahlweise
# Abschlusswangen links/rechts (von der Front bis hinter die Verkleidung, bis zum Fußboden) und eine
# erhöhte Theke: die Verkleidung geht dann bis unter die Thekenplatte hoch, die zur Sitzseite übersteht.
# Ohne erhöhte Theke merkt sich der Schrank den Sitzüberstand der Arbeitsplatte hinten
# (Attribut Sitzueberstand, JT_Schrank/insel), die Arbeitsplatte liest ihn.
#
# Platten haben das Material "Melamin weiss", sichtbare Kanten das Material "Anleimer Melamin weiss"
# (2 mm, wird erst in der Stückliste abgezogen; gezeichnet wird das Endmaß). Verkleidung und Wangen
# bekommen mit "Frontfarbe und Griffe ändern" das Frontmaterial, die Thekenplatte ist aus dem Material
# der Arbeitsplatte. Jedes Teil hat einen eigenen Tag <Kürzel>_<Bereich>_<Teil> (z. B. USI1_SeiteL,
# USI1_Verkleidung, USI1_A_Front) und das Wörterbuch "JT_Schrank" für den TCN-Export. Anderes Kürzel:
#   UnterschrankInsel.erstellen({ 'Kuerzel' => 'USI2' }, ziel)

require 'sketchup.rb'

module UnterschrankInsel

  DICT     = 'dynamic_attributes'.freeze
  NAME     = 'Inselschrank'.freeze
  MATERIAL = 'Melamin weiss'.freeze
  KANTE    = 'Anleimer Melamin weiss'.freeze
  THEKE_MATERIAL = 'Arbeitsplatte Schichtstoff'.freeze # wie die Arbeitsplatte (Komponenten/arbeitsplatte)
  THEKE_KANTE    = 'Anleimer Arbeitsplatte'.freeze
  OCL_DICT = 'ladb_opencutlist'.freeze
  KUERZEL  = 'USI'.freeze
  MAX_SCHUBLADEN = 4
  MAX_EB = 2

  # Tag-Schema für den TCN-Export (gleich in allen Komponenten, der Test prüft das):
  # Tag <Kürzel>_<Bereich>_<Teil>, dazu am Teil das Wörterbuch JT_Schrank.
  JT_DICT   = 'JT_Schrank'.freeze
  TYP       = 'Unterschrank_Insel'.freeze
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

  # Standardwerte in cm
  DEFAULTS = {
    'Breite'                    => 60.0,
    'Hoehe'                     => 70.0,
    'Tiefe'                     => 80.0,  # Korpus ohne Front/Rückwand (wie die anderen Unterschränke)
    'Frontart'                  => 1.0,   # 0 = Türen, 1 = Schubladen
    'Art_Tuer'                  => 2.0,   # 1 = eine Tür (Anschlag links), 2 = zwei Türen
    'Anz_Einlegeboeden'         => 1.0,   # nur bei Türen
    'Anz_Schubladen'            => 3.0,   # gleich hohe Fronten
    'Verkleidung'               => 1.0,   # 1 = Rückseite verkleidet, 0 = ohne
    'Art_Wange'                 => 0.0,   # 0 = keine, 1 = links, 2 = rechts, 3 = beide
    'Theke'                     => 0.0,   # 0 = keine (Sitzüberstand der Arbeitsplatte), 1 = erhöhte Theke
    'Sitzueberstand'            => 30.0,  # Arbeitsplatte hinten über die Verkleidung (ohne erhöhte Theke)
    'Hoehe_Theke'               => 110.0, # Fußboden bis Oberkante Thekenplatte
    'Tiefe_Theke'               => 35.0,
    'Ueberstand_Theke'          => 25.0,  # Thekenplatte hinter der Verkleidung (Sitzseite)
    'Materialstaerke_Korpus'    => 1.9,
    'Materialstarke_Rueckwand'  => 0.8,
    'Materialstaerke_Verkleidung' => 1.9,
    'Staerke_Theke'             => 3.8,
    'Sockelhoehe'               => 10.0,  # Verkleidung und Wangen reichen bis zum Fußboden
    'BreiteStreben'             => 10.0,
    'Spaltbreite'               => 0.2,
    'Rueckversatz_Einlegeboden' => 1.0,
    # Blum LEGRABOX free wie im Unterschrank mit Schubladen
    'Materialstaerke_Kastenboden'     => 1.6,
    'Materialstaerke_Kastenrueckwand' => 1.6,
    'Hoehe_Kastenrueckwand'     => 14.8,
    'Hoehenoffset_Schiene'      => 0.0,
    'Lochraster_Start'          => 3.5,
    'Lochraster'                => 3.2,
    'Kasten_Abstand_unten'      => 3.0,   # Unterkante Front -> Unterkante Kasten (mindestens)
    'Kasten_Abstand_oben'       => 3.0,   # Oberkante Kastenrückwand -> Oberkante Front (mindestens)
    'Auszug_Anteil'             => 0.8
  }.freeze

  # Kurzhilfe in der Komponente (Kurzfassung der README.md). SketchUp zeigt
  # "summary" und "description" oben im Fenster "Komponentenoptionen".
  DOKU_URL = 'https://github.com/jimmycd/sketchup_kuechenplaner2/tree/main/Komponenten/unterschrank_insel'.freeze
  HILFE_KURZ = 'Inselschrank: Türen oder 1–4 Schubladen, Rückseite verkleidet, Wangen und erhöhte Theke wählbar'.freeze
  HILFE = [
    'Breite, Höhe, Tiefe, Front (Türen mit Einlegeböden oder Schubladen), Verkleidung der Rückseite, Wangen, Theke und Sitzüberstand hier ändern.',
    'Verkleidung 19 mm hinter der Rückwand bis zum Fußboden, von innen verschraubt; Wangen von der Front bis hinter die Verkleidung.',
    'Erhöhte Theke: die Verkleidung geht bis unter die Thekenplatte (Höhe ab Fußboden), die Platte steht zur Sitzseite über.',
    'Ohne erhöhte Theke steht die Arbeitsplatte hinten um den Sitzüberstand über (Arbeitsplatte erzeugen liest den Wert).',
    'Schubladen: Blum LEGRABOX free, Nennlänge aus der Tiefe. Mit „Interagieren“ öffnen Türen und Schubladen.',
    'Gezeichnet ist das Endmaß; den Anleimer (2 mm) zieht erst die Stückliste ab.',
    'Jedes Teil hat einen eigenen Tag <Kürzel>_<Bereich>_<Teil>, z. B. USI1_Verkleidung, USI1_A_Front (Schublade oben).',
    'Feste Maße (Materialstärken, Sockelhöhe, LEGRABOX): Fenster „Komponentenattribute“.',
    "Doku: #{DOKU_URL}"
  ].join(' ').freeze

  # ---------------------------------------------------------------------------
  # Reine Berechnung (ohne SketchUp), spiegelt die DC-Formeln. Werte in cm.
  # ---------------------------------------------------------------------------
  def self.berechne(p)
    mk, sp, h, b = p['Materialstaerke_Korpus'], p['Spaltbreite'], p['Hoehe'], p['Breite']
    n = p['Anz_Schubladen'].to_i.clamp(1, MAX_SCHUBLADEN)
    n_eb = p['Anz_Einlegeboeden'].to_i
    hf = (h - (n - 1) * sp) / n
    theke = p['Theke'].to_i == 1
    verkleidet = theke || p['Verkleidung'].to_i == 1
    w = p['Art_Wange'].to_i
    y_hinten = p['Tiefe'] + mk + p['Materialstarke_Rueckwand']
    y_aussen = y_hinten + (verkleidet ? p['Materialstaerke_Verkleidung'] : 0.0)
    schub = (1..MAX_SCHUBLADEN).map do |i|
      z = h - i * hf - (i - 1) * sp
      ab = kasten_unten(p, z)
      { z: z, ab: ab, hrw: [[p['Hoehe_Kastenrueckwand'], z + hf - p['Kasten_Abstand_oben'] - ab - p['Materialstaerke_Kastenboden']].min, 2.0].max }
    end
    {
      nl: nennlaenge(p['Tiefe']), n: n, hf: hf, schub: schub,
      b_tuer1: b - sp, b_tuer2: b / 2.0 - sp,
      eb: (1..MAX_EB).map { |k| k <= n_eb ? mk + (h - 2 * mk) * k / (n_eb + 1) - mk / 2 : mk },
      verkleidet: verkleidet, theke: theke, links: [1, 3].include?(w), rechts: [2, 3].include?(w),
      y_hinten: y_hinten, y_aussen: y_aussen,
      h_verkleidung: theke ? p['Hoehe_Theke'] - p['Staerke_Theke'] : h + p['Sockelhoehe'],
      y_theke: y_aussen + p['Ueberstand_Theke'] - p['Tiefe_Theke'],
      z_theke: p['Hoehe_Theke'] - p['Sockelhoehe'] - p['Staerke_Theke']
    }
  end

  # LEGRABOX gibt es nur in festen Nennlängen (cm). Gewählt wird die größte mit NL + 3 mm <= Tiefe;
  # passt keine (Tiefe < 353 mm), bleibt es bei der kürzesten, der TCN-Export meldet dann zu wenig Tiefe.
  NENNLAENGEN = [35.0, 40.0, 45.0, 50.0, 55.0, 60.0, 65.0].freeze

  def self.nennlaenge(tiefe)
    NENNLAENGEN.select { |nl| nl + 0.3 <= tiefe + 0.000001 }.max || NENNLAENGEN.first
  end

  # dieselbe Wahl als DC-Formel (die Nennlängen liegen im 5-cm-Raster)
  def self.f_nennlaenge(tiefe)
    "MAX(35,MIN(65,INT((#{tiefe}-0.3)/5+0.000001)*5))"
  end

  # Unterkante Kasten über Unterkante Korpus: mindestens Kasten_Abstand_unten über der Unterkante
  # der Front (z_front) und so, dass die Schienenbohrung auf dem Lochraster der Seite liegt
  def self.kasten_unten(p, z_front)
    st, ra, off = p['Lochraster_Start'], p['Lochraster'], p['Hoehenoffset_Schiene']
    n = ((z_front + p['Kasten_Abstand_unten'] + off - st) / ra - 0.0001).ceil
    st + ra * n - off
  end

  def self.f_kasten_unten(z_front)
    u = NAME
    "#{u}!Lochraster_Start+#{u}!Lochraster*(-INT(-((#{z_front}+#{u}!Kasten_Abstand_unten+#{u}!Hoehenoffset_Schiene" \
      "-#{u}!Lochraster_Start)/#{u}!Lochraster-0.0001)))-#{u}!Hoehenoffset_Schiene"
  end

  # Formeln der Schubladen, nur auf Attribute des Schranks gestützt (SketchUp rechnet die Formeln eines
  # Bauteils nur einmal der Reihe nach, Verweise auf andere Formeln desselben Bauteils lesen alte Werte)
  def self.f_anz
    "MAX(1,MIN(#{MAX_SCHUBLADEN},#{NAME}!Anz_Schubladen))"
  end

  def self.f_hf
    u = NAME
    "(#{u}!Hoehe-(#{f_anz}-1)*#{u}!Spaltbreite)/#{f_anz}"
  end

  def self.f_z(i)
    "#{NAME}!Hoehe-#{i}*(#{f_hf})-#{i - 1}*#{NAME}!Spaltbreite"
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

  # Materialtyp und Maße im Wörterbuch "ladb_opencutlist" am Material (Stückliste, Zuschnitt).
  # Bereits eingestellte Materialien werden nicht verändert.
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
    ocl_material(model, KANTE, [245, 245, 240],
                 'type' => 4, # Kante/Anleimer
                 'thickness' => '2mm',
                 'std_widths' => '23mm',
                 'std_lengths' => '75m',
                 'edge_decremented' => true) # 2 mm werden erst in der Stückliste abgezogen
  end

  # wie Komponenten/arbeitsplatte (Ausgabe::MATERIALIEN[:schichtstoff], Ausgabe::KANTE)
  def self.theke_material(model)
    ocl_material(model, THEKE_MATERIAL, [214, 205, 190],
                 'type' => 2, 'std_thicknesses' => '38mm',
                 'std_sizes' => '4100mm x 600mm;4100mm x 650mm;4100mm x 900mm;4100mm x 1200mm', 'grained' => false)
  end

  def self.theke_kante(model)
    ocl_material(model, THEKE_KANTE, [200, 190, 175],
                 'type' => 4, 'thickness' => '2mm', 'std_widths' => '45mm', 'edge_decremented' => true)
  end

  # Freies Kürzel für die Tags, z. B. USI1, USI2 …
  def self.freies_kuerzel(model)
    n = 1
    n += 1 while model.layers.to_a.any? { |l| l.name.start_with?("#{KUERZEL}#{n}_") }
    "#{KUERZEL}#{n}"
  end

  def self.tag(model, name)
    model.layers[name] || model.layers.add(name)
  end

  # Tag <Kürzel>_<Bereich>_<Teil> (z. B. USI1_A_Front) und JT_Schrank am Teil
  def self.kennzeichnen(model, inst, kz, teil, bereich = nil)
    inst.layer = tag(model, [kz, bereich, teil].compact.join('_'))
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE, 'bereich' => bereich.to_s,
      'teil' => teil, 'rolle' => ROLLEN.fetch(teil.sub(/\d+\z/, '')) }.each { |k, v| inst.set_attribute(JT_DICT, k, v) }
    inst
  end

  SEITEN = { xmin: [0, -1], xmax: [0, 1], ymin: [1, -1], ymax: [1, 1], zmin: [2, -1], zmax: [2, 1] }.freeze

  # Sichtbare Kanten je Teil, bekommen einen Anleimer.
  # ymin = vorne, ymax = hinten, zmin/zmax = unten/oben, xmin/xmax = links/rechts.
  KANTEN = {
    'Seite'           => %i[ymin],
    'Boden'           => %i[ymin],
    'Einlegeboden'    => %i[ymin],
    'StrebeVorn'      => %i[ymin],
    'StrebeHinten'    => [],
    'Rückwand'        => [],
    'Front'           => %i[xmin xmax zmin zmax],
    'Tür'             => %i[xmin xmax zmin zmax],
    'KastenBoden'     => [],
    'KastenRueckwand' => %i[zmax],
    'Verkleidung'     => %i[xmin xmax zmax],      # unten steht sie auf dem Fußboden
    'Wange'           => %i[ymin ymax zmax],      # vorne, hinten, oben
    'Theke'           => %i[xmin xmax ymin ymax]  # rundum
  }.freeze

  # Quader in Endmaß zeichnen; die in "kanten" genannten Flächen bekommen das Anleimer-Material.
  def self.quader(ents, lx, ly, lz, kanten = [], kante = @kante)
    f = ents.add_face([0, 0, 0], [inch(lx), 0, 0], [inch(lx), inch(ly), 0], [0, inch(ly), 0])
    f.reverse! if f.normal.z < 0
    f.pushpull(inch(lz))
    return if kanten.empty?
    ents.grep(Sketchup::Face).each do |face|
      n = face.normal.to_a
      seite = SEITEN.find { |_, (ax, vz)| n[ax] * vz > 0.5 }&.first
      face.material = kante if kanten.include?(seite)
    end
  end

  def self.platte(model, defname, dc_name, groesse, len_formeln, art: dc_name, kante: @kante)
    d = model.definitions.add(defname)
    quader(d.entities, *groesse, KANTEN.fetch(art), kante)
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
    kennzeichnen(kz[0], inst, *kz[1..-1]) if kz
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
    @kante = kanten_material(model)
    kz = p['Kuerzel'] || freies_kuerzel(model)
    t_ = ->(teil, bereich = nil) { [model, kz, teil, bereich] }

    haupt = model.definitions.add(NAME)
    stempel(haupt)
    haupt.set_attribute(DICT, '_name', u)
    hilfe(haupt)
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE, 'insel' => true }.each { |k, v| haupt.set_attribute(JT_DICT, k, v) }

    # --- Parameter (Komponentenoptionen) ---
    attribut(haupt, 'Breite', p['Breite'], access: 'TEXTBOX', formlabel: 'Breite')
    attribut(haupt, 'Hoehe', p['Hoehe'], access: 'TEXTBOX', formlabel: 'Höhe')
    attribut(haupt, 'Tiefe', p['Tiefe'], access: 'TEXTBOX', formlabel: 'Tiefe (Korpus ohne Front/Rückwand)')
    attribut(haupt, 'Frontart', p['Frontart'], laenge: false, access: 'LIST', formlabel: 'Front',
             units: 'INTEGER', options: '&T%C3%BCren=0&Schubladen=1&')
    attribut(haupt, 'Art_Tuer', p['Art_Tuer'], laenge: false, access: 'LIST', formlabel: 'Türen (bei Front Türen)',
             units: 'INTEGER', options: '&Eine%20T%C3%BCr%20(Anschlag%20links)=1&Zwei%20T%C3%BCren=2&')
    attribut(haupt, 'Anz_Einlegeboeden', p['Anz_Einlegeboeden'], laenge: false, access: 'LIST',
             formlabel: 'Anzahl Einlegeböden (bei Türen)', units: 'INTEGER', options: liste(0, MAX_EB))
    attribut(haupt, 'Anz_Schubladen', p['Anz_Schubladen'], laenge: false, access: 'LIST',
             formlabel: 'Anzahl Schubladen (bei Schubladen)', units: 'INTEGER', options: liste(1, MAX_SCHUBLADEN))
    attribut(haupt, 'Verkleidung', p['Verkleidung'], laenge: false, access: 'LIST', formlabel: 'Rückseite verkleiden',
             units: 'INTEGER', options: '&Ja=1&Nein=0&')
    attribut(haupt, 'Art_Wange', p['Art_Wange'], laenge: false, access: 'LIST', formlabel: 'Abschlusswange',
             units: 'INTEGER', options: '&Keine=0&Links=1&Rechts=2&Beide=3&')
    attribut(haupt, 'Theke', p['Theke'], laenge: false, access: 'LIST', formlabel: 'Erhöhte Theke',
             units: 'INTEGER', options: '&Nein%20(Sitz%C3%BCberstand%20der%20Arbeitsplatte)=0&Ja=1&')
    attribut(haupt, 'Sitzueberstand', p['Sitzueberstand'], access: 'TEXTBOX',
             formlabel: 'Sitzüberstand Arbeitsplatte hinten (ohne erhöhte Theke)')
    attribut(haupt, 'Hoehe_Theke', p['Hoehe_Theke'], access: 'TEXTBOX', formlabel: 'Thekenhöhe ab Fußboden')
    attribut(haupt, 'Tiefe_Theke', p['Tiefe_Theke'], access: 'TEXTBOX', formlabel: 'Tiefe Thekenplatte')
    attribut(haupt, 'Ueberstand_Theke', p['Ueberstand_Theke'], access: 'TEXTBOX', formlabel: 'Überstand Theke zur Sitzseite')

    # --- Feste Maße (über Komponentenattribute änderbar) ---
    %w[Materialstaerke_Korpus Materialstarke_Rueckwand Materialstaerke_Verkleidung Staerke_Theke Sockelhoehe
       BreiteStreben Spaltbreite Rueckversatz_Einlegeboden
       Materialstaerke_Kastenboden Materialstaerke_Kastenrueckwand Hoehe_Kastenrueckwand Hoehenoffset_Schiene
       Lochraster_Start Lochraster Kasten_Abstand_unten Kasten_Abstand_oben].each do |n|
      attribut(haupt, n, p[n], units: 'STRING')
    end
    attribut(haupt, 'Auszug_Anteil', p['Auszug_Anteil'], laenge: false, units: 'STRING')

    # --- Abgeleitete Werte (nur auf Eingabe-Attribute gestützt) ---
    verkleidet = 'OR(Verkleidung=1,Theke=1)'
    attribut(haupt, 'NL', r[:nl], units: 'STRING', formula: f_nennlaenge('Tiefe'))
    attribut(haupt, 'B_Tuer2', r[:b_tuer2], units: 'STRING', formula: 'Breite/2-Spaltbreite')
    attribut(haupt, 'Y_Hinten', r[:y_hinten], units: 'STRING', formula: 'Tiefe+Materialstaerke_Korpus+Materialstarke_Rueckwand')
    attribut(haupt, 'Y_Aussen', r[:y_aussen], units: 'STRING',
             formula: "Tiefe+Materialstaerke_Korpus+Materialstarke_Rueckwand+IF(#{verkleidet},Materialstaerke_Verkleidung,0)")
    attribut(haupt, 'H_Verkleidung', r[:h_verkleidung], units: 'STRING',
             formula: 'IF(Theke=1,Hoehe_Theke-Staerke_Theke,Hoehe+Sockelhoehe)')
    (1..MAX_EB).each do |k|
      f = "IF(Anz_Einlegeboeden>=#{k},Materialstaerke_Korpus+(Hoehe-2*Materialstaerke_Korpus)*#{k}/" \
          "(Anz_Einlegeboeden+1)-Materialstaerke_Korpus/2,Materialstaerke_Korpus)"
      attribut(haupt, "Z_Einlegeboden_#{k}", r[:eb][k - 1], units: 'STRING', formula: f)
    end

    korpus(model, haupt.entities, p, r, mat, t_)
    tueren(model, haupt.entities, p, r, mat, t_)
    (1..MAX_SCHUBLADEN).each { |i| schublade(model, haupt.entities, p, r, mat, kz, i) }
    rueckseite(model, haupt.entities, p, r, mat, t_)
    haupt
  end

  # Korpus wie beim Unterschrank mit Schubladen (beginnt bei y = Materialstärke), Einlegeböden bei Türen
  def self.korpus(model, e, p, r, mat, t_)
    u = NAME
    mk = p['Materialstaerke_Korpus']
    b, h, t = p['Breite'], p['Hoehe'], p['Tiefe']
    bs, rw = p['BreiteStreben'], p['Materialstarke_Rueckwand']
    innen_b = "#{u}!Breite-2*#{u}!Materialstaerke_Korpus"

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
               "#{u}!Hoehe-#{u}!Materialstaerke_Korpus"],
              mat: mat, kz: t_.('StrebeHinten'))

    rueck = platte(model, 'Rückwand', 'Rückwand', [b, rw, h],
                   ["#{u}!Breite", "#{u}!Materialstarke_Rueckwand", "#{u}!Hoehe"])
    einsetzen(e, rueck, 'Rückwand', [0, t + mk, 0],
              [nil, "#{u}!Tiefe+#{u}!Materialstaerke_Korpus", nil], mat: mat, kz: t_.('Rueckwand'))

    rv = p['Rueckversatz_Einlegeboden']
    tueren_da = p['Frontart'].to_i == 0
    (1..MAX_EB).each do |k|
      d = platte(model, "Einlegeboden #{k}", "Einlegeboden#{k}", [b - 2 * mk, t - rv, mk],
                 [innen_b, "#{u}!Tiefe-#{u}!Rueckversatz_Einlegeboden", "#{u}!Materialstaerke_Korpus"],
                 art: 'Einlegeboden')
      sichtbar = tueren_da && k <= p['Anz_Einlegeboeden'].to_i
      sichtbarkeit(d, sichtbar, "IF(AND(#{u}!Frontart=0,#{u}!Anz_Einlegeboeden>=#{k}),0,1)")
      inst = einsetzen(e, d, "Einlegeboden#{k}", [mk, mk + rv, r[:eb][k - 1]],
                       ["#{u}!Materialstaerke_Korpus", "#{u}!Materialstaerke_Korpus+#{u}!Rueckversatz_Einlegeboden",
                        "#{u}!Z_Einlegeboden_#{k}"], mat: mat, kz: t_.("Einlegeboden#{k}"))
      inst.hidden = !sichtbar
    end
  end

  # Türen über die volle Höhe: eine (Anschlag links) oder zwei, mit "Interagieren" öffnen
  def self.tueren(model, e, p, r, mat, t_)
    u = NAME
    sp, mk, b, h = p['Spaltbreite'], p['Materialstaerke_Korpus'], p['Breite'], p['Hoehe']
    art = p['Frontart'].to_i == 0 ? p['Art_Tuer'].to_i : 0
    eine = "IF(AND(#{u}!Frontart=0,#{u}!Art_Tuer=1),0,1)"
    zwei = "IF(AND(#{u}!Frontart=0,#{u}!Art_Tuer=2),0,1)"

    t1 = platte(model, 'Tür', 'Tür', [r[:b_tuer1], mk, h],
                ["#{u}!Breite-#{u}!Spaltbreite", "#{u}!Materialstaerke_Korpus", "#{u}!Hoehe"])
    tuer_drehen(t1, art == 1, eine, -100)
    i1 = einsetzen(e, t1, 'Tür', [sp / 2.0, -sp, 0], ["#{u}!Spaltbreite/2", "-#{u}!Spaltbreite", nil],
                   mat: mat, kz: t_.('Tuer'))
    i1.hidden = art != 1

    tl = platte(model, 'Tür links', 'TürL', [r[:b_tuer2], mk, h],
                ["#{u}!B_Tuer2", "#{u}!Materialstaerke_Korpus", "#{u}!Hoehe"], art: 'Tür')
    tuer_drehen(tl, art == 2, zwei, -100)
    il = einsetzen(e, tl, 'TürL', [sp / 2.0, -sp, 0], ["#{u}!Spaltbreite/2", "-#{u}!Spaltbreite", nil],
                   mat: mat, kz: t_.('TuerL'))
    il.hidden = art != 2

    # rechts: Drehpunkt muss rechts liegen, deshalb steckt die Tür in einem Halter am Scharnier
    halter = model.definitions.add('Tür rechts Halter')
    stempel(halter)
    halter.set_attribute(DICT, '_name', 'TuerRHalter')
    attribut(halter, 'B_Tuer', r[:b_tuer2], units: 'STRING', formula: "#{u}!B_Tuer2")
    attribut(halter, 'H_Tuer', h, units: 'STRING', formula: "#{u}!Hoehe")
    attribut(halter, 'Mk', mk, units: 'STRING', formula: "#{u}!Materialstaerke_Korpus")
    tuer_drehen(halter, art == 2, zwei, 100)
    hn = 'TuerRHalter'
    tr = platte(model, 'Tür rechts', 'TürR', [r[:b_tuer2], mk, h],
                ["#{hn}!B_Tuer", "#{hn}!Mk", "#{hn}!H_Tuer"], art: 'Tür')
    einsetzen(halter.entities, tr, 'TürR', [-r[:b_tuer2], 0, 0], ["-#{hn}!B_Tuer", nil, nil], mat: mat, kz: t_.('TuerR'))
    ih = einsetzen(e, halter, hn, [b - sp / 2.0, -sp, 0], ["#{u}!Breite-#{u}!Spaltbreite/2", "-#{u}!Spaltbreite", nil])
    ih.hidden = art != 2
  end

  def self.tuer_drehen(d, sichtbar, formel, winkel)
    sichtbarkeit(d, sichtbar, formel)
    d.set_attribute(DICT, 'rotz', 0.0)
    d.set_attribute(DICT, 'onclick', "ANIMATE(\"ROTZ\",0,#{winkel})")
    d.set_attribute(DICT, '_onclick_label', 'onClick')
  end

  # Schublade i (1 = oben, Bereich A, B, …): Front, LEGRABOX-Kastenboden (LW-35 x NL-10) und Holzrückwand (LW-38)
  def self.schublade(model, e, p, r, mat, kz, i)
    u = NAME
    s = "Schublade#{i}"
    bereich = ('A'.ord + i - 1).chr
    sp, mk, b = p['Spaltbreite'], p['Materialstaerke_Korpus'], p['Breite']
    mb, mrw, nl = p['Materialstaerke_Kastenboden'], p['Materialstaerke_Kastenrueckwand'], r[:nl]
    lw = b - 2 * mk
    w = r[:schub][i - 1]
    sichtbar = p['Frontart'].to_i == 1 && i <= r[:n]

    d = model.definitions.add(s)
    stempel(d)
    d.set_attribute(DICT, '_name', s)
    attribut(d, 'Breite', b, units: 'STRING', formula: "#{u}!Breite")
    attribut(d, 'Mk', mk, units: 'STRING', formula: "#{u}!Materialstaerke_Korpus")
    attribut(d, 'Spalt', sp, units: 'STRING', formula: "#{u}!Spaltbreite")
    attribut(d, 'Mb', mb, units: 'STRING', formula: "#{u}!Materialstaerke_Kastenboden")
    attribut(d, 'Mrw', mrw, units: 'STRING', formula: "#{u}!Materialstaerke_Kastenrueckwand")
    attribut(d, 'NL', nl, units: 'STRING', formula: "#{u}!NL")
    attribut(d, 'Auszug', nl * p['Auszug_Anteil'], units: 'STRING', formula: "#{u}!NL*#{u}!Auszug_Anteil")
    attribut(d, 'Hoehe_Front', r[:hf], units: 'STRING', formula: f_hf)
    attribut(d, 'Z_Front', w[:z], units: 'STRING', formula: f_z(i))
    ab = f_kasten_unten("(#{f_z(i)})")
    attribut(d, 'Ab_unten', w[:ab], units: 'STRING', formula: ab)
    attribut(d, 'Hrw', w[:hrw], units: 'STRING',
             formula: "MAX(MIN(#{u}!Hoehe_Kastenrueckwand,#{f_z(i)}+#{f_hf}-#{u}!Kasten_Abstand_oben-(#{ab})" \
                      "-#{u}!Materialstaerke_Kastenboden),2)")
    d.set_attribute(DICT, 'onclick', 'ANIMATE("Y",0,-Auszug)')
    d.set_attribute(DICT, '_onclick_label', 'onClick')
    sichtbarkeit(d, sichtbar, "IF(AND(#{u}!Frontart=1,#{u}!Anz_Schubladen>=#{i}),0,1)")

    de = d.entities
    st = ->(teil) { [model, kz, teil, bereich] }
    front = platte(model, "Front #{s}", 'Front', [b - sp, mk, r[:hf]],
                   ["#{s}!Breite-#{s}!Spalt", "#{s}!Mk", "#{s}!Hoehe_Front"])
    einsetzen(de, front, 'Front', [sp / 2.0, -sp, w[:z]], ["#{s}!Spalt/2", "-#{s}!Spalt", "#{s}!Z_Front"],
              mat: mat, kz: st.('Front'))
    kbod = platte(model, "Kasten Boden #{s}", 'KastenBoden', [lw - 3.5, nl - 1.0, mb],
                  ["#{s}!Breite-2*#{s}!Mk-3.5", "#{s}!NL-1", "#{s}!Mb"])
    einsetzen(de, kbod, 'KastenBoden', [mk + 1.75, mk, w[:ab]],
              ["#{s}!Mk+1.75", "#{s}!Mk", "#{s}!Ab_unten"], mat: mat, kz: st.('KastenBoden'))
    krw = platte(model, "Kasten Rueckwand #{s}", 'KastenRueckwand', [lw - 3.8, mrw, w[:hrw]],
                 ["#{s}!Breite-2*#{s}!Mk-3.8", "#{s}!Mrw", "#{s}!Hrw"])
    einsetzen(de, krw, 'KastenRueckwand', [mk + 1.9, mk + nl - 1.0 - mrw, w[:ab] + mb],
              ["#{s}!Mk+1.9", "#{s}!Mk+#{s}!NL-1-#{s}!Mrw", "#{s}!Ab_unten+#{s}!Mb"],
              mat: mat, kz: st.('KastenRueckwand'))

    inst = einsetzen(e, d, s, [0, 0, 0], [nil, nil, nil], layer: tag(model, "#{kz}_#{bereich}_Schublade"))
    inst.hidden = !sichtbar
    inst
  end

  # Rückseite der Insel: Verkleidung hinter der Rückwand (bis zum Fußboden, bei erhöhter Theke bis unter
  # die Thekenplatte), Abschlusswangen außen neben den Seiten von der Frontfläche bis hinter die Verkleidung,
  # Thekenplatte auf der Verkleidung mit Überstand zur Sitzseite
  def self.rueckseite(model, e, p, r, mat, t_)
    u = NAME
    b, h, sp, sh = p['Breite'], p['Hoehe'], p['Spaltbreite'], p['Sockelhoehe']
    mv = p['Materialstaerke_Verkleidung']

    v = platte(model, 'Verkleidung', 'Verkleidung', [b, mv, r[:h_verkleidung]],
               ["#{u}!Breite", "#{u}!Materialstaerke_Verkleidung", "#{u}!H_Verkleidung"])
    sichtbarkeit(v, r[:verkleidet], "IF(OR(#{u}!Verkleidung=1,#{u}!Theke=1),0,1)")
    vi = einsetzen(e, v, 'Verkleidung', [0, r[:y_hinten], -sh], [nil, "#{u}!Y_Hinten", "-#{u}!Sockelhoehe"],
                   mat: mat, kz: t_.('Verkleidung'))
    vi.hidden = !r[:verkleidet]

    wangen = [['WangeL', r[:links], "IF(OR(#{u}!Art_Wange=1,#{u}!Art_Wange=3),0,1)", [-mv, "-#{u}!Materialstaerke_Verkleidung"]],
              ['WangeR', r[:rechts], "IF(OR(#{u}!Art_Wange=2,#{u}!Art_Wange=3),0,1)", [b, "#{u}!Breite"]]]
    wangen.each do |teil, sichtbar, formel, (x, fx)|
      d = platte(model, teil, teil, [mv, r[:y_aussen] + sp, h + sh],
                 ["#{u}!Materialstaerke_Verkleidung", "#{u}!Y_Aussen+#{u}!Spaltbreite", "#{u}!Hoehe+#{u}!Sockelhoehe"],
                 art: 'Wange')
      sichtbarkeit(d, sichtbar, formel)
      inst = einsetzen(e, d, teil, [x, -sp, -sh], [fx, "-#{u}!Spaltbreite", "-#{u}!Sockelhoehe"], mat: mat, kz: t_.(teil))
      inst.hidden = !sichtbar
    end

    tk = platte(model, 'Thekenplatte', 'Theke', [b, p['Tiefe_Theke'], p['Staerke_Theke']],
                ["#{u}!Breite", "#{u}!Tiefe_Theke", "#{u}!Staerke_Theke"], kante: theke_kante(model))
    sichtbarkeit(tk, r[:theke], "IF(#{u}!Theke=1,0,1)")
    ti = einsetzen(e, tk, 'Theke', [0, r[:y_theke], r[:z_theke]],
                   [nil, "#{u}!Y_Aussen+#{u}!Ueberstand_Theke-#{u}!Tiefe_Theke",
                    "#{u}!Hoehe_Theke-#{u}!Sockelhoehe-#{u}!Staerke_Theke"],
                   mat: theke_material(model), kz: t_.('Theke'))
    ti.hidden = !r[:theke]
  end

  # ---------------------------------------------------------------------------
  # Erzeugen (mit ziel zusätzlich als .skp speichern)
  # ---------------------------------------------------------------------------
  # Neuer Schrank: Maße beim Anlegen abfragen, Tiefe = Korpus ohne Front/Rückwand. Danach bleiben sie im
  # Fenster Komponentenoptionen änderbar; alle abhängigen Teile folgen dort per Formel.
  TIEFE_NEU = 52.0 # cm, Vorschlag im Dialog
  FRONTEN = { 'Schubladen' => 1.0, 'Türen' => 0.0 }.freeze
  RUECKSEITEN = { 'Verkleidung, Sitzüberstand' => [1.0, 0.0], 'Verkleidung, erhöhte Theke' => [1.0, 1.0],
                  'Ohne Verkleidung' => [0.0, 0.0] }.freeze

  def self.dialog
    res = UI.inputbox(['Breite (mm)', 'Höhe (mm)', 'Tiefe Korpus (mm)', 'Front', 'Rückseite'],
                      [(DEFAULTS['Breite'] * 10).round.to_s, (DEFAULTS['Hoehe'] * 10).round.to_s, (TIEFE_NEU * 10).round.to_s,
                       FRONTEN.keys.first, RUECKSEITEN.keys.first],
                      ['', '', '', FRONTEN.keys.join('|'), RUECKSEITEN.keys.join('|')], 'Inselschrank')
    return unless res
    w = res[0, 3].map { |v| v.to_s.tr(',', '.').to_f / 10.0 }
    eingabe = { 'Breite' => w[0], 'Hoehe' => w[1], 'Tiefe' => w[2] }
    raise ArgumentError, 'Maße müssen größer als 0 sein' if eingabe.values.any? { |v| v <= 0 }
    front = FRONTEN.fetch(res[3]) { 1.0 }
    if front == 1.0 && eingabe['Tiefe'] < 35.3 - 0.000001
      raise ArgumentError, "Tiefe #{(eingabe['Tiefe'] * 10).round} mm ist zu klein für Schubladen (LEGRABOX NL 350 braucht mindestens 353 mm)"
    end
    verkleidung, theke = RUECKSEITEN.fetch(res[4]) { RUECKSEITEN.values.first }
    erstellen(eingabe.merge('Frontart' => front, 'Verkleidung' => verkleidung, 'Theke' => theke))
  rescue ArgumentError => e
    UI.messagebox("Ungültige Eingabe: #{e.message}")
  end

  def self.erstellen(eingabe = {}, ziel = nil)
    model = Sketchup.active_model
    model.start_operation('Inselschrank', true)
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
  Kuechenplaner.schrank('Unterschränke', 'Inselschrank…') { UnterschrankInsel.dialog }
  file_loaded(__FILE__)
end
