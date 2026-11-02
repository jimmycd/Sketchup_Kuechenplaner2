# encoding: UTF-8
#
# Hochschrank Vorrat – erzeugt eine Dynamic Component
#
# Erweiterung (.rbz): Erweiterungen > Küchenplaner > Hochschränke > Hochschrank Vorrat baut den
# Schrank im aktuellen Modell. Maße und Optionen danach in den Komponentenoptionen einstellen.
#
# Aufbau:
#   Korpus wie der Hochschrank (Seiten, Boden, Deckel, Rückwand 8 mm), ein fester Zwischenboden
#   über den Kästen (Oberkante H_Unten).
#   Unten: 2–6 LEGRABOX-Innenschubkästen mit Innenfront (12 mm), Aufteilung über Anteil_1..6 (1 = oben).
#   Oben: 0–6 Einlegeböden.
#   Tür außen: eine Tür über die ganze Höhe oder geteilt (unten bis Zwischenboden, oben), je
#   mit einem Flügel (Anschlag links/rechts) oder zwei Flügeln.
#
# Scharniere (Blum, öffnen nach außen, Jürgen 2026-11-02): Sie sitzen in Lücken zwischen den
# Kästen. Über jedem Kasten bleibt dafür Freiraum_Scharnier frei; die Scharnierhöhen stehen als
# Scharnier_1..6 am Schrank (0 = keins).
#
# OpenCutList: Platten haben das Material "Melamin weiss" (Plattenwerkstoff), sichtbare Kanten
# "Anleimer Melamin weiss" (Kante, 2 mm, nur in OCL abgezogen; gezeichnet wird das Endmaß).
# Jedes Teil hat einen eigenen Tag <Kürzel>_<Bereich>_<Teil> (z. B. HV1_SeiteL, HV1_U2_Innenfront)
# und das Wörterbuch "JT_Schrank" für den TCN-Export.
# Anderes Kürzel: HochschrankVorrat.erstellen({ 'Kuerzel' => 'HV2' })

require 'sketchup.rb'
require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'eingabe') # Eingabefenster im Treppenplaner-Stil

module HochschrankVorrat

  DICT     = 'dynamic_attributes'.freeze
  NAME     = 'HochschrankVorrat'.freeze
  MAX_K    = 6
  MIN_K    = 2
  MAX_EB   = 6
  PARK_HOEHE = 10.0 # cm
  MATERIAL = 'Melamin weiss'.freeze
  KANTE    = 'Anleimer Melamin weiss'.freeze
  OCL_DICT = 'ladb_opencutlist'.freeze
  KUERZEL  = 'HV'.freeze

  # Tag-Schema für den TCN-Export (gleich in allen Komponenten, der Test prüft das):
  # Tag <Kürzel>_<Bereich>_<Teil>, dazu am Teil das Wörterbuch JT_Schrank.
  JT_DICT   = 'JT_Schrank'.freeze
  TYP       = 'Hochschrank Vorrat'.freeze
  KATEGORIE = 'Hochschrank'.freeze # Unterschrank, Oberschrank oder Hochschrank
  ROLLEN = {
    'SeiteL' => 'Seite', 'SeiteR' => 'Seite', 'Boden' => 'Boden', 'Deckel' => 'Deckel',
    'StrebeVorn' => 'Strebe', 'StrebeHinten' => 'Strebe',
    'ZwischenbodenUnten' => 'Zwischenboden', 'ZwischenbodenMitte' => 'Zwischenboden', 'ZwischenbodenOben' => 'Zwischenboden',
    'Mittelboden' => 'Zwischenboden',
    'Rueckwand' => 'Rueckwand', 'Einlegeboden' => 'Einlegeboden', 'Front' => 'Front',
    'Tuer' => 'Tuer', 'TuerL' => 'Tuer', 'TuerR' => 'Tuer',
    'Klappe' => 'Front', 'KlappeO' => 'Front', 'KlappeU' => 'Front',
    'KastenBoden' => 'KastenBoden', 'KastenRueckwand' => 'KastenRueckwand',
    'Innenfront' => 'Innenfront',
    'Blende' => 'Front',
    'WangeL' => 'Wange', 'WangeR' => 'Wange',
    'Platte' => 'Arbeitsplatte'
  }.freeze

  # Standardwerte in cm
  DEFAULTS = {
    'Breite'                      => 60.0,
    'Hoehe'                       => 210.0,
    'Tiefe'                       => 80.0,
    'H_Unten'                     => 100.0, # Oberkante Zwischenboden über den Kästen
    'Anz_Kaesten'                 => 4.0,
    'Anz_Einlegeboeden'           => 3.0,
    'Tueren'                      => 0.0,   # 0 = eine Tür über die ganze Höhe, 1 = geteilt (unten/oben)
    'Fluegel'                     => 1.0,   # 1 oder 2 Flügel (Standard: 2 ab Breite über 600 mm)
    'Anschlag'                    => 0.0,   # ein Flügel: 0 = links, 1 = rechts
    'Materialstaerke_Korpus'      => 1.9,
    'Materialstarke_Rueckwand'    => 0.8,
    'Spaltbreite'                 => 0.2,
    # Innenfront (Jürgen 2026-11-02: 12 mm, Farbe wählbar über Frontfarbe → Nur Innenfronten)
    'Materialstaerke_Innenfront'  => 1.2,
    'Rueckversatz_Innenfront'     => 0.3,   # hinter der Korpusvorderkante
    'Luft_Innenfront'             => 0.2,   # seitlich zur Korpusseite
    # Schubkasten Blum LEGRABOX free (MD-015/4): aus Holz nur Boden (LW-35 x NL-10, 16 mm)
    # und Holzrückwand (LW-38 x 148, auf dem Boden)
    'Materialstaerke_Kastenboden' => 1.6,
    'Materialstaerke_Kastenrueckwand' => 1.6,
    'Hoehe_Kastenrueckwand'       => 14.8,
    'Hoehenoffset_Schiene'        => 0.0,
    'Lochraster_Start'            => 3.5,
    'Lochraster'                  => 3.2,
    'Kasten_Abstand_unten'        => 3.0,
    # Scharniere: über jedem Kasten bleibt so viel frei (Topf und Arm liegen in der Lücke)
    'Freiraum_Scharnier'          => 6.0,
    'Scharnier_Rand'              => 10.0,  # Mitte Scharnier ab Ober-/Unterkante Tür (Fach oben)
    'Auszug_Anteil'               => 0.8,
    'Rueckversatz_Einlegeboden'   => 1.0
  }.merge((1..MAX_K).to_h { |i| ["Anteil_#{i}", 1.0] }).freeze

  # Kurzhilfe in der Komponente (Kurzfassung der README.md)
  DOKU_URL = 'https://github.com/jimmycd/sketchup_kuechenplaner2/tree/main/Komponenten/hochschrank_vorrat'.freeze
  HILFE_KURZ = 'Hochschrank Vorrat: Tür außen, dahinter LEGRABOX-Innenschubkästen unten und Einlegeböden oben'.freeze
  HILFE = [
    'Unten: Höhe bis Oberkante Zwischenboden, 2–6 Innenschubkästen (Anteile: 1/1/2 = unterster doppelt so hoch, Kasten 1 = oben).',
    'Oben: 0–6 Einlegeböden. Tür: ganz oder geteilt (unten/oben), ein Flügel (Anschlag links/rechts) oder zwei.',
    'Die Scharniere sitzen in Lücken über den Kästen (Freiraum_Scharnier, Standard 60 mm); ihre Höhen stehen unten in den Optionen.',
    'Innenfront 12 mm, Farbe über Frontfarbe und Griffe › Nur Innenfronten.',
    'Gezeichnet ist das Endmaß; den Anleimer (2 mm) zieht nur OpenCutList ab.',
    'Jedes Teil hat einen eigenen Tag <Kürzel>_<Bereich>_<Teil>, z. B. HV1_SeiteL, HV1_U2_Innenfront, HV1_O_Tuer.',
    'Feste Maße (Materialstärken, Abstände): Fenster „Komponentenattribute“.',
    "Doku: #{DOKU_URL}"
  ].join(' ').freeze

  # ---------------------------------------------------------------------------
  # Reine Berechnung (ohne SketchUp), spiegelt die DC-Formeln. Werte in cm.
  # ---------------------------------------------------------------------------
  def self.mitte_kasten(n)
    ((n + 1) / 2.0).floor
  end

  def self.berechne(p)
    mk, f = p['Materialstaerke_Korpus'], p['Freiraum_Scharnier']
    n = p['Anz_Kaesten'].to_i
    ant = (1..MAX_K).map { |i| p["Anteil_#{i}"].to_f }
    summe = ant.first(n).sum
    netto = p['H_Unten'] - 2 * mk
    oben = p['H_Unten'] - mk
    top = ->(i) { oben - netto * ant.first(i - 1).sum / summe }
    erg = {}
    erg[:faecher] = (1..MAX_K).map do |i|
      if i <= n
        h = netto * ant[i - 1] / summe
        { h: h, z: top.(i) - h, top: top.(i) }
      else
        { h: PARK_HOEHE, z: mk, top: mk + PARK_HOEHE }
      end
    end
    n_eb = p['Anz_Einlegeboeden'].to_i
    bereich = p['Hoehe'] - mk - p['H_Unten']
    erg[:eb] = (1..MAX_EB).map { |k| k <= n_eb ? p['H_Unten'] + bereich * k / (n_eb + 1) - mk / 2 : p['H_Unten'] }
    geteilt = p['Tueren'].to_i == 1
    j = mitte_kasten(n_eb)
    erg[:scharniere] = [
      top.(n) - f / 2,
      !geteilt && p['Hoehe'] > 200.0 && n >= 3 ? top.(mitte_kasten(n)) - f / 2 : 0.0,
      oben - f / 2,
      geteilt ? p['H_Unten'] + p['Scharnier_Rand'] : 0.0,
      p['H_Unten'] + bereich * (j + 0.5) / (n_eb + 1),
      p['Hoehe'] - p['Scharnier_Rand']
    ]
    erg
  end

  # Unterkante Kasten über Unterkante Fach (cm): mindestens Kasten_Abstand_unten und so, dass die
  # Schienenbohrung (Unterkante Kasten + Höhenoffset) auf dem Lochraster der Seite liegt.
  def self.kasten_unten(p, z_fach)
    st, ra, off = p['Lochraster_Start'], p['Lochraster'], p['Hoehenoffset_Schiene']
    n = ((z_fach + p['Kasten_Abstand_unten'] + off - st) / ra - 0.0001).ceil
    st + ra * n - off - z_fach
  end

  def self.f_kasten_unten(z_fach)
    u = NAME
    "#{u}!Lochraster_Start+#{u}!Lochraster*(-INT(-((#{z_fach}+#{u}!Kasten_Abstand_unten+#{u}!Hoehenoffset_Schiene" \
      "-#{u}!Lochraster_Start)/#{u}!Lochraster-0.0001)))-#{u}!Hoehenoffset_Schiene-#{z_fach}"
  end

  # ---------------------------------------------------------------------------
  # Formeln am Schrank (nur auf Eingabe-Attribute gestützt, berechnete Werte inline)
  # ---------------------------------------------------------------------------
  def self.f_summe
    terms = ['Anteil_1'] + (2..MAX_K).map { |i| i <= MIN_K ? "Anteil_#{i}" : "IF(Anz_Kaesten>=#{i},Anteil_#{i},0)" }
    "(#{terms.join('+')})"
  end

  F_NETTO = '(H_Unten-2*Materialstaerke_Korpus)'.freeze

  # Oberkante Fach i (Unterseite Zwischenboden bzw. Unterkante Fach darüber)
  def self.f_top(i)
    return '(H_Unten-Materialstaerke_Korpus)' if i == 1
    teil = (1...i).map { |j| "Anteil_#{j}" }.join('+')
    "(H_Unten-Materialstaerke_Korpus-#{F_NETTO}*(#{teil})/#{f_summe})"
  end

  def self.nur_sichtbar(i, formel, park)
    i <= MIN_K ? formel : "IF(Anz_Kaesten>=#{i},#{formel},#{park})"
  end

  def self.f_h_fach(i)
    nur_sichtbar(i, "#{F_NETTO}*Anteil_#{i}/#{f_summe}", PARK_HOEHE)
  end

  def self.f_z_fach(i)
    nur_sichtbar(i, "#{f_top(i)}-#{F_NETTO}*Anteil_#{i}/#{f_summe}", 'Materialstaerke_Korpus')
  end

  # Wert je Kastenanzahl: IF(Anz_Kaesten=2,a,IF(Anz_Kaesten=3,b,…))
  def self.f_je_anzahl(von = MIN_K)
    return yield(MAX_K) if von == MAX_K
    "IF(Anz_Kaesten=#{von},#{yield(von)},#{f_je_anzahl(von + 1) { |n| yield(n) }})"
  end

  def self.f_scharniere
    bereich = '(Hoehe-Materialstaerke_Korpus-H_Unten)'
    j = 'INT((Anz_Einlegeboeden+1)/2)'
    [
      f_je_anzahl { |n| "#{f_top(n)}-Freiraum_Scharnier/2" },
      "IF(AND(Tueren=0,Hoehe>200,Anz_Kaesten>=3),#{f_je_anzahl { |n| n < 3 ? '0' : "#{f_top(mitte_kasten(n))}-Freiraum_Scharnier/2" }},0)",
      'H_Unten-Materialstaerke_Korpus-Freiraum_Scharnier/2',
      'IF(Tueren=1,H_Unten+Scharnier_Rand,0)',
      "H_Unten+#{bereich}*(#{j}+0.5)/(Anz_Einlegeboeden+1)",
      'Hoehe-Scharnier_Rand'
    ]
  end

  SCHARNIER_LABEL = [
    'Scharnier 1: über dem untersten Kasten',
    'Scharnier 2: über dem mittleren Kasten (nur ganze Tür über 2 m, sonst 0)',
    'Scharnier 3: unter dem Zwischenboden',
    'Scharnier 4: unten an der oberen Tür (nur geteilt, sonst 0)',
    'Scharnier 5: Mitte Fach oben (zwischen zwei Einlegeböden)',
    'Scharnier 6: oben'
  ].freeze

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
                 'std_thicknesses' => '8mm;12mm;16mm;19mm',
                 'std_sizes' => '2800mm x 2070mm',
                 'grained' => false)
  end

  def self.kanten_material(model)
    @kante = ocl_material(model, KANTE, [245, 245, 240],
                          'type' => 4, # Kante/Anleimer
                          'thickness' => '2mm',
                          'std_widths' => '23mm',
                          'std_lengths' => '75m',
                          'edge_decremented' => true)
  end

  def self.freies_kuerzel(model)
    n = 1
    n += 1 while model.layers.to_a.any? { |l| l.name.start_with?("#{KUERZEL}#{n}_") }
    "#{KUERZEL}#{n}"
  end

  def self.kennzeichnen(model, inst, kz, teil, bereich = nil)
    name = [kz, bereich, teil].compact.join('_')
    inst.layer = model.layers[name] || model.layers.add(name)
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE, 'bereich' => bereich.to_s,
      'teil' => teil, 'rolle' => ROLLEN.fetch(teil.sub(/\d+\z/, '')) }.each { |k, v| inst.set_attribute(JT_DICT, k, v) }
    inst
  end

  SEITEN = { xmin: [0, -1], xmax: [0, 1], ymin: [1, -1], ymax: [1, 1], zmin: [2, -1], zmax: [2, 1] }.freeze
  RUNDUM = %i[xmin xmax zmin zmax].freeze

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

  def self.platte(model, defname, dc_name, groesse, len_formeln, kanten: [])
    d = model.definitions.add(defname)
    quader(d.entities, *groesse, kanten)
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

  # LEGRABOX-Nennlänge (cm) für die Tiefe hinter der Innenfront (siehe Hochschrank)
  NENNLAENGEN = [35.0, 40.0, 45.0, 50.0, 55.0, 60.0, 65.0].freeze

  def self.nennlaenge(tiefe)
    NENNLAENGEN.select { |nl| nl + 0.3 <= tiefe + 0.000001 }.max || NENNLAENGEN.first
  end

  def self.f_nennlaenge(tiefe)
    "MAX(35,MIN(65,INT((#{tiefe}-0.3)/5+0.000001)*5))"
  end

  # Kasten beginnt hinter der Innenfront (Rückversatz + Stärke + Fuge wie bei normalen Fronten)
  def self.versatz(p)
    p['Rueckversatz_Innenfront'] + p['Materialstaerke_Innenfront'] + p['Spaltbreite']
  end
  F_VERSATZ = '(Rueckversatz_Innenfront+Materialstaerke_Innenfront+Spaltbreite)'.freeze

  # ---------------------------------------------------------------------------
  # Aufbau
  # ---------------------------------------------------------------------------
  def self.erzeuge(model, eingabe = {})
    p = DEFAULTS.merge(eingabe)
    p['Fluegel'] = p['Breite'] > 60.0 + 1e-6 ? 2.0 : 1.0 unless eingabe.key?('Fluegel')
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
    attribut(haupt, 'Tueren', p['Tueren'], laenge: false, access: 'LIST', formlabel: 'Tür',
             units: 'INTEGER', options: '&Eine%20T%C3%BCr%20(ganze%20H%C3%B6he)=0&Geteilt%20(unten%20und%20oben)=1&')
    attribut(haupt, 'Fluegel', p['Fluegel'], laenge: false, access: 'LIST', formlabel: 'Flügel',
             units: 'INTEGER', options: '&1=1&2=2&')
    attribut(haupt, 'Anschlag', p['Anschlag'], laenge: false, access: 'LIST', formlabel: 'Anschlag (ein Flügel)',
             units: 'INTEGER', options: '&links=0&rechts=1&')
    attribut(haupt, 'H_Unten', p['H_Unten'], access: 'TEXTBOX', formlabel: 'Unten: Höhe Bereich (bis Oberkante Zwischenboden)')
    attribut(haupt, 'Anz_Kaesten', p['Anz_Kaesten'], laenge: false, access: 'LIST',
             formlabel: 'Unten: Anzahl Innenschubkästen', units: 'INTEGER', options: liste(MIN_K, MAX_K))
    (1..MAX_K).each do |i|
      attribut(haupt, "Anteil_#{i}", p["Anteil_#{i}"], laenge: false, access: 'TEXTBOX',
               formlabel: "Unten: Anteil Kasten #{i}#{i == 1 ? ' (oben)' : ''}")
    end
    attribut(haupt, 'Anz_Einlegeboeden', p['Anz_Einlegeboeden'], laenge: false, access: 'LIST',
             formlabel: 'Oben: Anzahl Einlegeböden', units: 'INTEGER', options: liste(0, MAX_EB))
    attribut(haupt, 'Materialstaerke_Kastenboden', p['Materialstaerke_Kastenboden'], access: 'TEXTBOX',
             formlabel: 'Stärke Kastenboden')
    attribut(haupt, 'Hoehenoffset_Schiene', p['Hoehenoffset_Schiene'], access: 'TEXTBOX',
             formlabel: 'Höhenoffset Schiene (Bohrung über Unterkante Kasten)')
    f_s = f_scharniere
    SCHARNIER_LABEL.each_with_index do |label, i|
      attribut(haupt, "Scharnier_#{i + 1}", r[:scharniere][i], access: 'VIEW',
               formlabel: "#{label} – Mitte über Unterkante Schrank", formula: f_s[i])
    end

    # --- Feste Maße (über Komponentenattribute änderbar) ---
    %w[Materialstaerke_Korpus Materialstarke_Rueckwand Spaltbreite Materialstaerke_Innenfront Rueckversatz_Innenfront
       Luft_Innenfront Materialstaerke_Kastenrueckwand Hoehe_Kastenrueckwand Kasten_Abstand_unten Freiraum_Scharnier
       Scharnier_Rand Rueckversatz_Einlegeboden Lochraster_Start Lochraster].each do |n|
      attribut(haupt, n, p[n], units: 'STRING')
    end
    attribut(haupt, 'Auszug_Anteil', p['Auszug_Anteil'], laenge: false, units: 'STRING')
    attribut(haupt, 'NL', nennlaenge(p['Tiefe'] - versatz(p)), units: 'STRING', formula: f_nennlaenge("Tiefe-#{F_VERSATZ}"))

    # --- Abgeleitete Werte ---
    r[:faecher].each_with_index do |fa, idx|
      i = idx + 1
      attribut(haupt, "H_Fach_#{i}", fa[:h], units: 'STRING', formula: f_h_fach(i))
      attribut(haupt, "Z_Fach_#{i}", fa[:z], units: 'STRING', formula: f_z_fach(i))
    end
    (1..MAX_EB).each do |k|
      f = "IF(Anz_Einlegeboeden>=#{k},H_Unten+(Hoehe-Materialstaerke_Korpus-H_Unten)*#{k}/" \
          "(Anz_Einlegeboeden+1)-Materialstaerke_Korpus/2,H_Unten)"
      attribut(haupt, "Z_Einlegeboden_#{k}", r[:eb][k - 1], units: 'STRING', formula: f)
    end

    mk = p['Materialstaerke_Korpus']
    b, h, t = p['Breite'], p['Hoehe'], p['Tiefe']
    rw = p['Materialstarke_Rueckwand']
    e = haupt.entities
    innen = ["#{u}!Breite-2*#{u}!Materialstaerke_Korpus", "#{u}!Tiefe", "#{u}!Materialstaerke_Korpus"]

    # --- Korpus ---
    seite = platte(model, 'Seite', 'Seite', [mk, t, h],
                   ["#{u}!Materialstaerke_Korpus", "#{u}!Tiefe", "#{u}!Hoehe"], kanten: %i[ymin zmax])
    einsetzen(e, seite, 'SeiteL', [0, mk, 0], [nil, nil, nil], mat: mat, kz: t_.('SeiteL'))
    einsetzen(e, seite, 'SeiteR', [b - mk, mk, 0],
              ["#{u}!Breite-#{u}!Materialstaerke_Korpus", nil, nil], mat: mat, kz: t_.('SeiteR'))

    boden = platte(model, 'Boden', 'Boden', [b - 2 * mk, t, mk], innen, kanten: %i[ymin])
    einsetzen(e, boden, 'Boden', [mk, mk, 0], ["#{u}!Materialstaerke_Korpus", nil, nil],
              mat: mat, kz: t_.('Boden'))
    einsetzen(e, boden, 'Deckel', [mk, mk, h - mk],
              ["#{u}!Materialstaerke_Korpus", nil, "#{u}!Hoehe-#{u}!Materialstaerke_Korpus"],
              mat: mat, kz: t_.('Deckel'))
    einsetzen(e, boden, 'Zwischenboden', [mk, mk, p['H_Unten'] - mk],
              ["#{u}!Materialstaerke_Korpus", nil, "#{u}!H_Unten-#{u}!Materialstaerke_Korpus"],
              mat: mat, kz: t_.('ZwischenbodenUnten'))

    rueck = platte(model, 'Rückwand', 'Rückwand', [b, rw, h],
                   ["#{u}!Breite", "#{u}!Materialstarke_Rueckwand", "#{u}!Hoehe"], kanten: %i[xmin xmax zmax])
    einsetzen(e, rueck, 'Rückwand', [0, t + mk, 0],
              [nil, "#{u}!Tiefe+#{u}!Materialstaerke_Korpus", nil], mat: mat, kz: t_.('Rueckwand'))

    # --- Einlegeböden oben ---
    rv = p['Rueckversatz_Einlegeboden']
    (1..MAX_EB).each do |k|
      d = platte(model, "Einlegeboden #{k}", "Einlegeboden#{k}", [b - 2 * mk, t - rv, mk],
                 ["#{u}!Breite-2*#{u}!Materialstaerke_Korpus", "#{u}!Tiefe-#{u}!Rueckversatz_Einlegeboden",
                  "#{u}!Materialstaerke_Korpus"], kanten: %i[ymin])
      sichtbarkeit(d, k <= p['Anz_Einlegeboeden'].to_i, "IF(#{u}!Anz_Einlegeboeden>=#{k},0,1)")
      inst = einsetzen(e, d, "Einlegeboden#{k}", [mk, mk + rv, r[:eb][k - 1]],
                       ["#{u}!Materialstaerke_Korpus", "#{u}!Materialstaerke_Korpus+#{u}!Rueckversatz_Einlegeboden",
                        "#{u}!Z_Einlegeboden_#{k}"], mat: mat, kz: t_.("Einlegeboden#{k}", 'O'))
      inst.hidden = k > p['Anz_Einlegeboeden'].to_i
    end

    tueren(model, e, p, mat, t_)

    # --- Innenschubkästen ---
    (1..MAX_K).each { |i| kasten(model, e, p, r[:faecher][i - 1], i, mat, kz) }
    haupt
  end

  # Türen je Bereich U (unten bzw. ganze Höhe) und O (oben, nur geteilt): ein Flügel (Anschlag links
  # oder rechts) oder zwei. Drehpunkt am Scharnier: die Tür steckt in einem Halter, der dort sitzt.
  def self.tueren(model, e, p, mat, t_)
    u = NAME
    sp, mk, b, h = p['Spaltbreite'], p['Materialstaerke_Korpus'], p['Breite'], p['Hoehe']
    geteilt = p['Tueren'].to_i == 1
    zwei = p['Fluegel'].to_i == 2
    rechts = p['Anschlag'].to_i == 1
    b1 = b - sp
    b2 = (b - 2 * sp) / 2.0
    f_b1 = "#{u}!Breite-#{u}!Spaltbreite"
    f_b2 = "(#{u}!Breite-2*#{u}!Spaltbreite)/2"
    { 'U' => [0.0, geteilt ? p['H_Unten'] - sp : h, '0', "IF(#{u}!Tueren=1,#{u}!H_Unten-#{u}!Spaltbreite,#{u}!Hoehe)", true],
      'O' => [p['H_Unten'], h - p['H_Unten'], "#{u}!H_Unten", "#{u}!Hoehe-#{u}!H_Unten", geteilt] }
      .each do |ber, (z, ht, f_z, f_h, da)|
      bed = ber == 'O' ? "#{u}!Tueren=1" : nil
      und = ->(c) { bed ? "AND(#{bed},#{c})" : c }
      # ein Flügel
      halter(model, e, "Tuer#{ber}Halter", 'Tuer', ber, [b1, ht, mk, rechts], da && !zwei,
             "IF(#{und.("#{u}!Fluegel=1")},0,1)", f_b1, f_h, f_z,
             x: rechts ? b - sp / 2.0 : sp / 2.0,
             f_x: "IF(#{u}!Anschlag=1,#{u}!Breite-#{u}!Spaltbreite/2,#{u}!Spaltbreite/2)",
             f_winkel: "IF(#{u}!Anschlag=1,100,-100)", f_anschlag: "#{u}!Anschlag", f_innen_x: ->(hn) { "IF(#{hn}!Anschlag=1,-#{hn}!B_Tuer,0)" },
             mat: mat, t_: t_, z: z, sp: sp)
      # zwei Flügel
      halter(model, e, "TuerL#{ber}Halter", 'TuerL', ber, [b2, ht, mk, false], da && zwei,
             "IF(#{und.("#{u}!Fluegel=2")},0,1)", f_b2, f_h, f_z,
             x: sp / 2.0, f_x: "#{u}!Spaltbreite/2", f_winkel: '-100', f_anschlag: '0', f_innen_x: ->(_) { '0' },
             mat: mat, t_: t_, z: z, sp: sp)
      halter(model, e, "TuerR#{ber}Halter", 'TuerR', ber, [b2, ht, mk, true], da && zwei,
             "IF(#{und.("#{u}!Fluegel=2")},0,1)", f_b2, f_h, f_z,
             x: b - sp / 2.0, f_x: "#{u}!Breite-#{u}!Spaltbreite/2", f_winkel: '100', f_anschlag: '1',
             f_innen_x: ->(hn) { "-#{hn}!B_Tuer" }, mat: mat, t_: t_, z: z, sp: sp)
    end
  end

  def self.halter(model, e, hn, teil, ber, (bt, ht, mk, rechts), sichtbar, f_hidden, f_b, f_h, f_z,
                  x:, f_x:, f_winkel:, f_innen_x:, f_anschlag:, mat:, t_:, z:, sp:)
    u = NAME
    hd = model.definitions.add(hn)
    stempel(hd)
    hd.set_attribute(DICT, '_name', hn)
    attribut(hd, 'B_Tuer', bt, units: 'STRING', formula: f_b)
    attribut(hd, 'H_Tuer', ht, units: 'STRING', formula: f_h)
    attribut(hd, 'Mk', mk, units: 'STRING', formula: "#{u}!Materialstaerke_Korpus")
    attribut(hd, 'Anschlag', rechts ? 1.0 : 0.0, laenge: false, units: 'STRING', formula: f_anschlag)
    attribut(hd, 'Winkel', rechts ? 100.0 : -100.0, laenge: false, units: 'STRING', formula: f_winkel)
    sichtbarkeit(hd, sichtbar, f_hidden)
    hd.set_attribute(DICT, 'rotz', 0.0)
    hd.set_attribute(DICT, 'onclick', 'ANIMATE("ROTZ",0,Winkel)')
    hd.set_attribute(DICT, '_onclick_label', 'onClick')
    td = platte(model, "Tür #{teil} #{ber}", teil, [bt, mk, ht], ["#{hn}!B_Tuer", "#{hn}!Mk", "#{hn}!H_Tuer"], kanten: RUNDUM)
    einsetzen(hd.entities, td, teil, [rechts ? -bt : 0.0, 0, 0], [f_innen_x.(hn), nil, nil], mat: mat, kz: t_.(teil, ber))
    hi = einsetzen(e, hd, hn, [x, -sp, z], [f_x, "-#{u}!Spaltbreite", f_z])
    hi.hidden = !sichtbar
    hi
  end

  # Innenschubkasten i (1 = oben) im Fach i: Innenfront, LEGRABOX-Boden und -Holzrückwand.
  # Unterkante im Lochraster, oben bleibt Freiraum_Scharnier bis zur Oberkante des Fachs frei.
  def self.kasten(model, ents, p, fa, i, mat, kz)
    u  = NAME
    s  = "Kasten#{i}"
    mk = p['Materialstaerke_Korpus']
    b  = p['Breite']
    mb   = p['Materialstaerke_Kastenboden']
    mrw  = p['Materialstaerke_Kastenrueckwand']
    mi   = p['Materialstaerke_Innenfront']
    rvi  = p['Rueckversatz_Innenfront']
    li   = p['Luft_Innenfront']
    v    = versatz(p)
    nl   = nennlaenge(p['Tiefe'] - v)
    fr   = p['Freiraum_Scharnier']
    lw   = b - 2 * mk
    ab   = kasten_unten(p, fa[:z])
    kh   = [fa[:h] - ab - fr, 2.0].max
    hrw  = [p['Hoehe_Kastenrueckwand'], kh - mb].min
    sicht = i <= p['Anz_Kaesten'].to_i
    bt   = ->(teil) { [model, kz, teil, "U#{i}"] }

    d = model.definitions.add(s)
    stempel(d)
    d.set_attribute(DICT, '_name', s)
    attribut(d, 'Breite', b, units: 'STRING', formula: "#{u}!Breite")
    attribut(d, 'H_Fach', fa[:h], units: 'STRING', formula: "#{u}!H_Fach_#{i}")
    attribut(d, 'Mk', mk, units: 'STRING', formula: "#{u}!Materialstaerke_Korpus")
    attribut(d, 'Mb', mb, units: 'STRING', formula: "#{u}!Materialstaerke_Kastenboden")
    attribut(d, 'Mrw', mrw, units: 'STRING', formula: "#{u}!Materialstaerke_Kastenrueckwand")
    attribut(d, 'Hrw', p['Hoehe_Kastenrueckwand'], units: 'STRING', formula: "#{u}!Hoehe_Kastenrueckwand")
    attribut(d, 'Mi', mi, units: 'STRING', formula: "#{u}!Materialstaerke_Innenfront")
    attribut(d, 'Rvi', rvi, units: 'STRING', formula: "#{u}!Rueckversatz_Innenfront")
    attribut(d, 'Li', li, units: 'STRING', formula: "#{u}!Luft_Innenfront")
    attribut(d, 'V', v, units: 'STRING', formula: "#{u}!Rueckversatz_Innenfront+#{u}!Materialstaerke_Innenfront+#{u}!Spaltbreite")
    attribut(d, 'NL', nl, units: 'STRING', formula: "#{u}!NL")
    attribut(d, 'F', fr, units: 'STRING', formula: "#{u}!Freiraum_Scharnier")
    attribut(d, 'Ab_unten', ab, units: 'STRING', formula: f_kasten_unten("#{u}!Z_Fach_#{i}"))
    attribut(d, 'Auszug', nl * p['Auszug_Anteil'], units: 'STRING', formula: "#{u}!NL*#{u}!Auszug_Anteil")
    sichtbarkeit(d, sicht, "IF(#{u}!Anz_Kaesten>=#{i},0,1)")
    d.set_attribute(DICT, 'onclick', 'ANIMATE("Y",0,-Auszug)')
    d.set_attribute(DICT, '_onclick_label', 'onClick')

    de = d.entities
    roh_kh = "#{s}!H_Fach-#{s}!Ab_unten-#{s}!F"
    f_kh   = "IF(#{roh_kh}>2,#{roh_kh},2)"

    # Innenfront zwischen den Seiten, so hoch wie der Kasten
    ifr = platte(model, "Innenfront #{i}", 'Innenfront', [lw - 2 * li, mi, kh],
                 ["#{s}!Breite-2*#{s}!Mk-2*#{s}!Li", "#{s}!Mi", f_kh], kanten: RUNDUM)
    einsetzen(de, ifr, 'Innenfront', [mk + li, mk + rvi, ab],
              ["#{s}!Mk+#{s}!Li", "#{s}!Mk+#{s}!Rvi", "#{s}!Ab_unten"], mat: mat, kz: bt.('Innenfront'))

    # Boden LW-35 x NL-10, mittig, hinter der Innenfront
    kbod = platte(model, "Kasten Boden #{i}", 'KastenBoden', [lw - 3.5, nl - 1.0, mb],
                  ["#{s}!Breite-2*#{s}!Mk-3.5", "#{s}!NL-1", "#{s}!Mb"])
    einsetzen(de, kbod, 'KastenBoden', [mk + 1.75, mk + v, ab],
              ["#{s}!Mk+1.75", "#{s}!Mk+#{s}!V", "#{s}!Ab_unten"], mat: mat, kz: bt.('KastenBoden'))

    # Holzrückwand LW-38 x 148 (höchstens bis zur Kastenoberkante), hinten auf dem Boden
    krw = platte(model, "Kasten Rueckwand #{i}", 'KastenRueckwand', [lw - 3.8, mrw, hrw],
                 ["#{s}!Breite-2*#{s}!Mk-3.8", "#{s}!Mrw", "MIN(#{s}!Hrw,#{f_kh}-#{s}!Mb)"], kanten: %i[zmax])
    einsetzen(de, krw, 'KastenRueckwand', [mk + 1.9, mk + v + nl - 1.0 - mrw, ab + mb],
              ["#{s}!Mk+1.9", "#{s}!Mk+#{s}!V+#{s}!NL-1-#{s}!Mrw", "#{s}!Ab_unten+#{s}!Mb"],
              mat: mat, kz: bt.('KastenRueckwand'))

    inst = einsetzen(ents, d, s, [0, 0, fa[:z]], [nil, nil, "#{u}!Z_Fach_#{i}"])
    inst.hidden = !sicht
    inst
  end

  # ---------------------------------------------------------------------------
  # Erzeugen
  # ---------------------------------------------------------------------------
  TIEFE_NEU = 52.0 # cm, Vorschlag im Dialog

  # NL 350 + 3 mm hinter der Innenfront
  def self.tiefe_min
    35.3 + versatz(DEFAULTS)
  end

  def self.dialog
    Kuechenplaner::Eingabe.abfragen(['Breite (mm)', 'Höhe (mm)', 'Tiefe Korpus (mm)'],
                      [(DEFAULTS['Breite'] * 10).round.to_s, (DEFAULTS['Hoehe'] * 10).round.to_s, (TIEFE_NEU * 10).round.to_s],
                      'Hochschrank Vorrat', untertitel: 'Neuer Schrank', ok: 'Einfügen') do |res|
      w = res.map { |v| v.to_s.tr(',', '.').to_f / 10.0 }
      eingabe = { 'Breite' => w[0], 'Hoehe' => w[1], 'Tiefe' => w[2] }
      t = eingabe['Tiefe']
      if t < tiefe_min - 0.000001
        raise ArgumentError, "Tiefe #{(t * 10).round} mm ist zu klein (LEGRABOX NL 350 hinter der Innenfront, mindestens #{(tiefe_min * 10).round} mm)"
      end
      raise ArgumentError, 'Maße müssen größer als 0 sein' if eingabe.values.any? { |v| v <= 0 }
      erstellen(eingabe)
    end
  rescue ArgumentError => e
    UI.messagebox("Ungültige Eingabe: #{e.message}")
  end

  def self.erstellen(eingabe = {}, ziel = nil)
    model = Sketchup.active_model
    model.start_operation('Hochschrank Vorrat', true)
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
  Kuechenplaner.schrank('Hochschränke', 'Hochschrank Vorrat…') { HochschrankVorrat.dialog }
  file_loaded(__FILE__)
end
