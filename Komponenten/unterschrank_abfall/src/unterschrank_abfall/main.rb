# encoding: UTF-8
#
# Unterschrank Mülltrennung – erzeugt eine Dynamic Component
#
# Erweiterung (.rbz): Erweiterungen > Küchenplaner > Unterschränke > Unterschrank Mülltrennung baut
# den Schrank im aktuellen Modell. Maße und Optionen danach in den Komponentenoptionen einstellen.
#
# Aufbau: Korpus wie der Unterschrank mit Schubladen (Seiten, Boden, Streben oben, Rückwand hinter
# dem Korpus). Fronten: ein Auszug über die volle Höhe (Bereich A) oder oben eine Schublade
# (Bereich B) und darunter der Auszug. Beide laufen auf Blum LEGRABOX free (Holzboden und
# Holzrückwand, Zargen aus Metall), so setzt der TCN-Export Schienen- und Frontbohrungen wie beim
# Unterschrank mit Schubladen. Im Auszug stehen 1–4 Abfallbehälter als Platzhalter (Kaufteil,
# Material-Typ Beschlag, kein JT_Schrank: der TCN-Export übergeht sie).
#
# Material: Platten haben das Material "Melamin weiss" (Plattenwerkstoff),
# sichtbare Kanten das Material "Anleimer Melamin weiss" (Kante, 2 mm, wird nur
# in Stückliste/Zuschnitt abgezogen; gezeichnet wird das Endmaß). Jedes Teil hat einen eigenen Tag
# <Kürzel>_<Bereich>_<Teil> (z. B. USM1_SeiteL, USM1_A_Front) und das Wörterbuch
# "JT_Schrank" für den TCN-Export. Anderes Kürzel:
#   UnterschrankAbfall.erstellen({ 'Kuerzel' => 'USM2' }, ziel)

require 'sketchup.rb'
require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'eingabe') # Eingabefenster im Treppenplaner-Stil

module UnterschrankAbfall

  DICT     = 'dynamic_attributes'.freeze
  NAME     = 'UnterschrankAbfall'.freeze
  MATERIAL = 'Melamin weiss'.freeze
  KANTE    = 'Anleimer Melamin weiss'.freeze
  BEHAELTER = 'Abfallbehälter'.freeze
  OCL_DICT = 'ladb_opencutlist'.freeze
  KUERZEL  = 'USM'.freeze
  MAX_BEHAELTER = 4

  # Tag-Schema für den TCN-Export (gleich in allen Komponenten, der Test prüft das):
  # Tag <Kürzel>_<Bereich>_<Teil>, dazu am Teil das Wörterbuch JT_Schrank.
  JT_DICT   = 'JT_Schrank'.freeze
  TYP       = 'Unterschrank_Abfall'.freeze
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
    'Frontvariante'             => 0.0,   # 0 = ein Auszug über die volle Höhe, 1 = Schublade oben + Auszug
    'Hoehe_Front_Oben'          => 20.0,  # Front der Schublade oben (bei Frontvariante 1)
    'Anz_Behaelter'             => 3.0,
    'Behaelter_Hoehe'           => 40.0,  # wird begrenzt, wenn der Auszug niedriger ist
    'Materialstaerke_Korpus'    => 1.9,
    'Materialstarke_Rueckwand'  => 0.8,
    'BreiteStreben'             => 10.0,
    'Spaltbreite'               => 0.2,
    # Blum LEGRABOX free wie im Unterschrank mit Schubladen
    'Materialstaerke_Kastenboden'     => 1.6,
    'Materialstaerke_Kastenrueckwand' => 1.6,
    'Hoehe_Kastenrueckwand'     => 14.8,
    'Hoehenoffset_Schiene'      => 0.0,
    'Lochraster_Start'          => 3.5,
    'Lochraster'                => 3.2,
    'Kasten_Abstand_unten'      => 3.0,   # Unterkante Front -> Unterkante Kasten (mindestens)
    'Kasten_Abstand_oben'       => 3.0,   # Oberkante Kasten/Behälter -> Oberkante Front (mindestens)
    'Behaelter_Abstand'         => 1.0,   # Luft zwischen den Behältern und zur Kastenrückwand
    'Auszug_Anteil'             => 0.8
  }.freeze

  # Kurzhilfe in der Komponente (Kurzfassung der README.md). SketchUp zeigt
  # "summary" und "description" oben im Fenster "Komponentenoptionen".
  DOKU_URL = 'https://github.com/jimmycd/sketchup_kuechenplaner2/tree/main/Komponenten/unterschrank_abfall'.freeze
  HILFE_KURZ = 'Unterschrank Mülltrennung: Auszug mit 1–4 Abfallbehältern, wahlweise Schublade oben (Blum LEGRABOX)'.freeze
  HILFE = [
    'Breite, Höhe, Tiefe, Fronten (ein Auszug oder Schublade oben + Auszug), Höhe der oberen Front, Anzahl und Höhe der Abfallbehälter hier ändern.',
    'Auszug und Schublade: Blum LEGRABOX free, Nennlänge aus der Tiefe (NL + 3 mm ≤ Tiefe), Holzteile Boden LW−35 × NL−10 und Rückwand LW−38 × höchstens 148.',
    'Die Abfallbehälter sind Platzhalter auf dem Kastenboden, gleich breit verteilt; ihre Höhe wird unter der Oberkante der Front begrenzt. Stückliste und TCN-Export übergehen sie.',
    'Mit „Interagieren“ fahren Auszug und Schublade heraus.',
    'Gezeichnet ist das Endmaß; den Anleimer (2 mm) ziehen Stückliste und Zuschnitt ab.',
    'Jedes Teil hat einen eigenen Tag <Kürzel>_<Bereich>_<Teil>, z. B. USM1_SeiteL, USM1_A_Front (Auszug), USM1_B_Front (Schublade oben).',
    'Feste Maße (Materialstärken, Abstände, LEGRABOX): Fenster „Komponentenattribute“.',
    "Doku: #{DOKU_URL}"
  ].join(' ').freeze

  # ---------------------------------------------------------------------------
  # Reine Berechnung (ohne SketchUp), spiegelt die DC-Formeln. Werte in cm.
  # ---------------------------------------------------------------------------
  def self.berechne(p)
    mk, sp, h = p['Materialstaerke_Korpus'], p['Spaltbreite'], p['Hoehe']
    lw = p['Breite'] - 2 * mk
    oben = p['Frontvariante'].to_i == 1
    h_a = oben ? h - p['Hoehe_Front_Oben'] - sp : h # Front Auszug
    z_b = h - p['Hoehe_Front_Oben']                  # Unterkante Front Schublade oben
    ab_a = kasten_unten(p, 0.0)
    ab_b = kasten_unten(p, z_b)
    mb, ao = p['Materialstaerke_Kastenboden'], p['Kasten_Abstand_oben']
    n = p['Anz_Behaelter'].to_i.clamp(1, MAX_BEHAELTER)
    ba = p['Behaelter_Abstand']
    nl = nennlaenge(p['Tiefe'])
    {
      h_a: h_a, z_b: z_b, nl: nl, ab_a: ab_a, ab_b: ab_b,
      hrw_a: hrw(p['Hoehe_Kastenrueckwand'], h_a - ao - ab_a - mb),
      hrw_b: hrw(p['Hoehe_Kastenrueckwand'], h - ao - ab_b - mb),
      n: n,
      b_beh: (lw - 3.5 - (n - 1) * ba) / n,                           # Breite je Behälter
      t_beh: nl - 1.0 - p['Materialstaerke_Kastenrueckwand'] - ba,   # Tiefe bis vor die Kastenrückwand
      h_beh: [[p['Behaelter_Hoehe'], h_a - ao - ab_a - mb].min, 5.0].max
    }
  end

  def self.hrw(soll, platz)
    [[soll, platz].min, 2.0].max
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

  # Kaufteil: Material-Typ 5 = Beschlag (kein Plattenteil)
  def self.behaelter_material(model)
    ocl_material(model, BEHAELTER, [90, 95, 100], 'type' => 5, 'description' => 'Abfallbehälter (Platzhalter)')
  end

  # Freies Kürzel für die Tags, z. B. USM1, USM2 …
  def self.freies_kuerzel(model)
    n = 1
    n += 1 while model.layers.to_a.any? { |l| l.name.start_with?("#{KUERZEL}#{n}_") }
    "#{KUERZEL}#{n}"
  end

  def self.tag(model, name)
    model.layers[name] || model.layers.add(name)
  end

  # Tag <Kürzel>_<Bereich>_<Teil> (z. B. USM1_A_Front) und JT_Schrank am Teil
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
    'Seite'           => %i[ymin],
    'Boden'           => %i[ymin],
    'StrebeVorn'      => %i[ymin],
    'StrebeHinten'    => [],
    'Rückwand'        => [],
    'Front'           => %i[xmin xmax zmin zmax],
    'KastenBoden'     => [],
    'KastenRueckwand' => %i[zmax],
    'Behaelter'       => []
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
    attribut(haupt, 'Tiefe', p['Tiefe'], access: 'TEXTBOX', formlabel: 'Tiefe (Korpus ohne Front/Rückwand)')
    attribut(haupt, 'Frontvariante', p['Frontvariante'], laenge: false, access: 'LIST', formlabel: 'Fronten',
             units: 'INTEGER', options: '&Ein%20Auszug%20%C3%BCber%20die%20volle%20H%C3%B6he=0&Schublade%20oben%20%2B%20Auszug=1&')
    attribut(haupt, 'Hoehe_Front_Oben', p['Hoehe_Front_Oben'], access: 'TEXTBOX',
             formlabel: 'Höhe Front Schublade oben (bei Schublade oben)')
    attribut(haupt, 'Anz_Behaelter', p['Anz_Behaelter'], laenge: false, access: 'LIST', formlabel: 'Anzahl Abfallbehälter',
             units: 'INTEGER', options: (1..MAX_BEHAELTER).map { |i| "#{i}=#{i}" }.join('&').prepend('&') + '&')
    attribut(haupt, 'Behaelter_Hoehe', p['Behaelter_Hoehe'], access: 'TEXTBOX', formlabel: 'Höhe Abfallbehälter')

    # --- Feste Maße (über Komponentenattribute änderbar) ---
    %w[Materialstaerke_Korpus Materialstarke_Rueckwand BreiteStreben Spaltbreite
       Materialstaerke_Kastenboden Materialstaerke_Kastenrueckwand Hoehe_Kastenrueckwand Hoehenoffset_Schiene
       Lochraster_Start Lochraster Kasten_Abstand_unten Kasten_Abstand_oben Behaelter_Abstand].each do |n|
      attribut(haupt, n, p[n], units: 'STRING')
    end
    attribut(haupt, 'Auszug_Anteil', p['Auszug_Anteil'], laenge: false, units: 'STRING')

    # --- Abgeleitete Werte (nur auf Eingabe-Attribute gestützt: SketchUp rechnet die Formeln
    # eines Bauteils nur einmal der Reihe nach) ---
    attribut(haupt, 'NL', r[:nl], units: 'STRING', formula: f_nennlaenge('Tiefe'))
    attribut(haupt, 'H_Auszug', r[:h_a], units: 'STRING',
             formula: 'IF(Frontvariante=1,Hoehe-Hoehe_Front_Oben-Spaltbreite,Hoehe)')
    attribut(haupt, 'Z_Oben', r[:z_b], units: 'STRING', formula: 'Hoehe-Hoehe_Front_Oben')

    mk = p['Materialstaerke_Korpus']
    b, h, t = p['Breite'], p['Hoehe'], p['Tiefe']
    bs, rw = p['BreiteStreben'], p['Materialstarke_Rueckwand']
    e = haupt.entities
    innen_b = "#{u}!Breite-2*#{u}!Materialstaerke_Korpus"

    # --- Korpus (wie Unterschrank mit Schubladen, beginnt bei y = Materialstärke) ---
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
              ['StrebeVorn!X', "#{u}!Tiefe-#{u}!BreiteStreben+#{u}!Materialstaerke_Korpus", 'StrebeVorn!Z'],
              mat: mat, kz: t_.('StrebeHinten'))

    rueck = platte(model, 'Rückwand', 'Rückwand', [b, rw, h],
                   ["#{u}!Breite", "#{u}!Materialstarke_Rueckwand", "#{u}!Hoehe"])
    einsetzen(e, rueck, 'Rückwand', [0, t + mk, 0],
              [nil, "#{u}!Tiefe+#{u}!Materialstaerke_Korpus", nil], mat: mat, kz: t_.('Rueckwand'))

    auszug(model, e, p, r, mat, kz)
    schublade_oben(model, e, p, r, mat, kz)
    haupt
  end

  # Lokale Kopien der Werte vom Schrank in einem Auszug (Formeln können nur Eltern/Geschwister ansprechen)
  def self.kasten_attribute(d, p, r)
    u = NAME
    attribut(d, 'Breite', p['Breite'], units: 'STRING', formula: "#{u}!Breite")
    attribut(d, 'Mk', p['Materialstaerke_Korpus'], units: 'STRING', formula: "#{u}!Materialstaerke_Korpus")
    attribut(d, 'Spalt', p['Spaltbreite'], units: 'STRING', formula: "#{u}!Spaltbreite")
    attribut(d, 'Mb', p['Materialstaerke_Kastenboden'], units: 'STRING', formula: "#{u}!Materialstaerke_Kastenboden")
    attribut(d, 'Mrw', p['Materialstaerke_Kastenrueckwand'], units: 'STRING', formula: "#{u}!Materialstaerke_Kastenrueckwand")
    attribut(d, 'NL', r[:nl], units: 'STRING', formula: "#{u}!NL")
    attribut(d, 'Auszug', r[:nl] * p['Auszug_Anteil'], units: 'STRING', formula: "#{u}!NL*#{u}!Auszug_Anteil")
    # Mit "Interagieren" anklicken -> fährt heraus
    d.set_attribute(DICT, 'onclick', 'ANIMATE("Y",0,-Auszug)')
    d.set_attribute(DICT, '_onclick_label', 'onClick')
  end

  # Front, Kastenboden (LW-35 x NL-10) und Holzrückwand (LW-38) eines LEGRABOX-Kastens im Bauteil s
  def self.kasten(model, d, s, p, r, mat, kz, bereich, z_front, h_front, ab, hrw)
    sp, mk, b = p['Spaltbreite'], p['Materialstaerke_Korpus'], p['Breite']
    mb, mrw, nl = p['Materialstaerke_Kastenboden'], p['Materialstaerke_Kastenrueckwand'], r[:nl]
    lw = b - 2 * mk
    de = d.entities
    st = ->(teil) { [model, kz, teil, bereich] }
    front = platte(model, "Front #{s}", 'Front', [b - sp, mk, h_front],
                   ["#{s}!Breite-#{s}!Spalt", "#{s}!Mk", "#{s}!Hoehe_Front"])
    einsetzen(de, front, 'Front', [sp / 2.0, -sp, z_front], ["#{s}!Spalt/2", "-#{s}!Spalt", "#{s}!Z_Front"],
              mat: mat, kz: st.('Front'))

    kbod = platte(model, "Kasten Boden #{s}", 'KastenBoden', [lw - 3.5, nl - 1.0, mb],
                  ["#{s}!Breite-2*#{s}!Mk-3.5", "#{s}!NL-1", "#{s}!Mb"])
    einsetzen(de, kbod, 'KastenBoden', [mk + 1.75, mk, ab],
              ["#{s}!Mk+1.75", "#{s}!Mk", "#{s}!Ab_unten"], mat: mat, kz: st.('KastenBoden'))

    krw = platte(model, "Kasten Rueckwand #{s}", 'KastenRueckwand', [lw - 3.8, mrw, hrw],
                 ["#{s}!Breite-2*#{s}!Mk-3.8", "#{s}!Mrw", "#{s}!Hrw"])
    einsetzen(de, krw, 'KastenRueckwand', [mk + 1.9, mk + nl - 1.0 - mrw, ab + mb],
              ["#{s}!Mk+1.9", "#{s}!Mk+#{s}!NL-1-#{s}!Mrw", "#{s}!Ab_unten+#{s}!Mb"],
              mat: mat, kz: st.('KastenRueckwand'))
  end

  # Auszug für den Abfallsammler (Bereich A), Front ab Unterkante Korpus. Die Kastenrückwand und die
  # Behälter enden mindestens Kasten_Abstand_oben unter der Oberkante der Front, damit sie beim
  # Herausfahren unter der Schublade oben bzw. der Strebe vorn durchpassen.
  def self.auszug(model, e, p, r, mat, kz)
    u = NAME
    s = 'Auszug'
    d = model.definitions.add(s)
    stempel(d)
    d.set_attribute(DICT, '_name', s)
    kasten_attribute(d, p, r)
    ab = f_kasten_unten('0')
    attribut(d, 'Hoehe_Front', r[:h_a], units: 'STRING', formula: "#{u}!H_Auszug")
    attribut(d, 'Z_Front', 0.0, units: 'STRING', formula: '0')
    attribut(d, 'Ab_unten', r[:ab_a], units: 'STRING', formula: ab)
    platz = "#{u}!H_Auszug-#{u}!Kasten_Abstand_oben-(#{ab})-#{u}!Materialstaerke_Kastenboden"
    attribut(d, 'Hrw', r[:hrw_a], units: 'STRING', formula: "MAX(MIN(#{u}!Hoehe_Kastenrueckwand,#{platz}),2)")
    # Behälter: n gleich breite nebeneinander auf dem Kastenboden, vor der Kastenrückwand
    attribut(d, 'Anz', r[:n], laenge: false, units: 'STRING',
             formula: "MAX(1,MIN(#{MAX_BEHAELTER},#{u}!Anz_Behaelter))")
    attribut(d, 'B_Beh', r[:b_beh], units: 'STRING',
             formula: "(#{u}!Breite-2*#{u}!Materialstaerke_Korpus-3.5-(MAX(1,MIN(#{MAX_BEHAELTER},#{u}!Anz_Behaelter))-1)" \
                      "*#{u}!Behaelter_Abstand)/MAX(1,MIN(#{MAX_BEHAELTER},#{u}!Anz_Behaelter))")
    attribut(d, 'T_Beh', r[:t_beh], units: 'STRING',
             formula: "#{u}!NL-1-#{u}!Materialstaerke_Kastenrueckwand-#{u}!Behaelter_Abstand")
    attribut(d, 'H_Beh', r[:h_beh], units: 'STRING', formula: "MAX(MIN(#{u}!Behaelter_Hoehe,#{platz}),5)")
    attribut(d, 'Ba', p['Behaelter_Abstand'], units: 'STRING', formula: "#{u}!Behaelter_Abstand")

    kasten(model, d, s, p, r, mat, kz, 'A', 0.0, r[:h_a], r[:ab_a], r[:hrw_a])

    mk, mb, ba = p['Materialstaerke_Korpus'], p['Materialstaerke_Kastenboden'], p['Behaelter_Abstand']
    bm = behaelter_material(model)
    (1..MAX_BEHAELTER).each do |i|
      g = platte(model, "Abfallbehälter #{i}", "Behaelter#{i}", [r[:b_beh], r[:t_beh], r[:h_beh]],
                 ["#{s}!B_Beh", "#{s}!T_Beh", "#{s}!H_Beh"], art: 'Behaelter')
      sichtbarkeit(g, i <= r[:n], "IF(#{s}!Anz>=#{i},0,1)")
      # kein JT_Schrank (kein Werkstück), eigener Tag für die Zuordnung
      gi = einsetzen(d.entities, g, "Behaelter#{i}", [mk + 1.75 + (i - 1) * (r[:b_beh] + ba), mk, r[:ab_a] + mb],
                     ["#{s}!Mk+1.75+#{i - 1}*(#{s}!B_Beh+#{s}!Ba)", "#{s}!Mk", "#{s}!Ab_unten+#{s}!Mb"],
                     mat: bm, layer: tag(model, "#{kz}_A_Behaelter#{i}"))
      gi.hidden = i > r[:n]
    end

    einsetzen(e, d, s, [0, 0, 0], [nil, nil, nil], layer: tag(model, "#{kz}_A_Auszug"))
  end

  # Schublade oben (Bereich B), nur bei Frontvariante 1
  def self.schublade_oben(model, e, p, r, mat, kz)
    u = NAME
    s = 'SchubladeOben'
    sichtbar = p['Frontvariante'].to_i == 1
    d = model.definitions.add(s)
    stempel(d)
    d.set_attribute(DICT, '_name', s)
    kasten_attribute(d, p, r)
    ab = f_kasten_unten("#{u}!Z_Oben")
    attribut(d, 'Hoehe_Front', p['Hoehe_Front_Oben'], units: 'STRING', formula: "#{u}!Hoehe_Front_Oben")
    attribut(d, 'Z_Front', r[:z_b], units: 'STRING', formula: "#{u}!Z_Oben")
    attribut(d, 'Ab_unten', r[:ab_b], units: 'STRING', formula: ab)
    attribut(d, 'Hrw', r[:hrw_b], units: 'STRING',
             formula: "MAX(MIN(#{u}!Hoehe_Kastenrueckwand,#{u}!Hoehe-#{u}!Kasten_Abstand_oben-(#{ab})" \
                      "-#{u}!Materialstaerke_Kastenboden),2)")
    sichtbarkeit(d, sichtbar, "IF(#{u}!Frontvariante=1,0,1)")
    kasten(model, d, s, p, r, mat, kz, 'B', r[:z_b], p['Hoehe_Front_Oben'], r[:ab_b], r[:hrw_b])
    inst = einsetzen(e, d, s, [0, 0, 0], [nil, nil, nil], layer: tag(model, "#{kz}_B_Schublade"))
    inst.hidden = !sichtbar
    inst
  end

  # ---------------------------------------------------------------------------
  # Erzeugen (mit ziel zusätzlich als .skp speichern)
  # ---------------------------------------------------------------------------
  # Neuer Schrank: Maße beim Anlegen abfragen, Tiefe = Korpus ohne Front/Rückwand. Danach bleiben sie im
  # Fenster Komponentenoptionen änderbar; alle abhängigen Teile folgen dort per Formel.
  TIEFE_NEU = 52.0 # cm, Vorschlag im Dialog

  def self.dialog
    Kuechenplaner::Eingabe.abfragen(['Breite (mm)', 'Höhe (mm)', 'Tiefe Korpus (mm)'],
                      [(DEFAULTS['Breite'] * 10).round.to_s, (DEFAULTS['Hoehe'] * 10).round.to_s, (TIEFE_NEU * 10).round.to_s],
                      'Unterschrank Mülltrennung', untertitel: 'Neuer Schrank', ok: 'Einfügen') do |res|
      w = res.map { |v| v.to_s.tr(',', '.').to_f / 10.0 }
      eingabe = { 'Breite' => w[0], 'Hoehe' => w[1], 'Tiefe' => w[2] }
      raise ArgumentError, 'Maße müssen größer als 0 sein' if eingabe.values.any? { |v| v <= 0 }
      if eingabe['Tiefe'] < 35.3 - 0.000001
        raise ArgumentError, "Tiefe #{(eingabe['Tiefe'] * 10).round} mm ist zu klein (LEGRABOX NL 350 braucht mindestens 353 mm)"
      end
      erstellen(eingabe)
    end
  rescue ArgumentError => e
    UI.messagebox("Ungültige Eingabe: #{e.message}")
  end

  def self.erstellen(eingabe = {}, ziel = nil)
    model = Sketchup.active_model
    model.start_operation('Unterschrank Mülltrennung', true)
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
  Kuechenplaner.schrank('Unterschränke', 'Unterschrank Mülltrennung…') { UnterschrankAbfall.dialog }
  file_loaded(__FILE__)
end
