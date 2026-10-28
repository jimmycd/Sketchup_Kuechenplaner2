# encoding: UTF-8
#
# Apothekerschrank – Hochschrank mit Vollauszug, erzeugt eine Dynamic Component
#
# Erweiterung (.rbz): Erweiterungen > Küchenplaner > Hochschränke > Apothekerschrank baut den Schrank im
# aktuellen Modell. Maße und Optionen danach in den Komponentenoptionen einstellen.
#
# Aufbau: Korpus wie der Hochschrank (19 mm, Rückwand 8 mm, Fugen 2 mm). Eine
# Hochfront (oder zwei Fronten, unten/oben getrennt) fährt komplett heraus und
# nimmt 2–6 Innenkästen Blum LEGRABOX mit (Prinzip Blum SPACE TOWER). Die Kästen
# sitzen gleichmäßig im 32-mm-Lochraster. Ein fester Mittelboden steift die Seiten
# aus; bei zwei Fronten liegt er an der Teilung. Front und Kästen stecken in einer
# Auszug-Komponente, damit sie mit "Interagieren" zusammen herausfahren.
#
# OpenCutList: Platten haben das Material "Melamin weiss" (Plattenwerkstoff),
# sichtbare Kanten das Material "Anleimer Melamin weiss" (Kante, 2 mm, wird nur
# in OCL abgezogen; gezeichnet wird das Endmaß). Jedes Teil hat einen eigenen Tag
# <Kürzel>_<Bereich>_<Teil> (z. B. AP1_SeiteL, AP1_A_Front, AP1_A3_KastenBoden) und
# das Wörterbuch "JT_Schrank" für den TCN-Export; die Kästen tragen dort zusätzlich
# "front" (Bereich ihrer Front). Anderes Kürzel: Apothekerschrank.erstellen({ 'Kuerzel' => 'AP2' }, ziel)

require 'sketchup.rb'

module Apothekerschrank

  DICT     = 'dynamic_attributes'.freeze
  NAME     = 'Apothekerschrank'.freeze
  MAX_K    = 6 # Kästen je Front
  MIN_K    = 2
  MATERIAL = 'Melamin weiss'.freeze
  KANTE    = 'Anleimer Melamin weiss'.freeze
  OCL_DICT = 'ladb_opencutlist'.freeze
  KUERZEL  = 'AP'.freeze
  FRONTEN  = %w[A B].freeze # A = untere bzw. einzige Front, B = obere

  # Tag-Schema für den TCN-Export (gleich in allen Komponenten, der Test prüft das):
  # Tag <Kürzel>_<Bereich>_<Teil>, dazu am Teil das Wörterbuch JT_Schrank.
  JT_DICT   = 'JT_Schrank'.freeze
  TYP       = 'Apothekerschrank'.freeze
  KATEGORIE = 'Hochschrank'.freeze # Unterschrank, Oberschrank oder Hochschrank
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
    'Breite'                      => 40.0,
    'Hoehe'                       => 210.0,
    'Tiefe'                       => 80.0,
    'Anz_Fronten'                 => 1.0,   # 1 = eine Hochfront, 2 = unten/oben getrennt
    'H_Teilung'                   => 70.0,  # bei 2 Fronten: Oberkante Mittelboden = Unterkante obere Front
    'Anz_Kaesten_A'               => 5.0,   # untere bzw. einzige Front
    'Anz_Kaesten_B'               => 3.0,   # obere Front
    'Mittelboden'                 => 1.0,   # 1 = ja (bei 2 Fronten immer)
    'Materialstaerke_Korpus'      => 1.9,
    'Materialstarke_Rueckwand'    => 0.8,
    'Spaltbreite'                 => 0.2,
    # Schubkasten Blum LEGRABOX free (Montageanleitung MD-015/4): Metallzargen, aus Holz nur
    # Boden (LW-35 x NL-10, 16 mm) und Holzrückwand (LW-38 x 148 bei Zarge C, auf dem Boden)
    'Materialstaerke_Kastenboden' => 1.6,
    'Materialstaerke_Kastenrueckwand' => 1.6,
    'Hoehe_Kastenrueckwand'       => 14.8,
    'Hoehenoffset_Schiene'        => 0.0,  # Schienenbohrung über Unterkante Kasten
    'Lochraster_Start'            => 3.5,  # erste Rasterbohrung über Unterkante Seite
    'Lochraster'                  => 3.2,
    'Kasten_Abstand_unten'        => 3.0,  # Unterkante Kasten mindestens so hoch über dem festen Boden darunter
    'Kasten_Abstand_oben'         => 3.0,  # Abstand Oberkante Kasten zum nächsten Kasten bzw. festen Boden
    'Auszug_Anteil'               => 0.8
  }.freeze

  # Kurzhilfe in der Komponente (Kurzfassung der README.md). SketchUp zeigt
  # "summary" und "description" oben im Fenster "Komponentenoptionen".
  DOKU_URL = 'https://github.com/jimmycd/sketchup_kuechenplaner2/tree/main/Komponenten/apothekerschrank'.freeze
  HILFE_KURZ = 'Apothekerschrank: Hochfront mit Vollauszug, die 2–6 Innenkästen (Blum LEGRABOX) mitnimmt'.freeze
  HILFE = [
    'Eine Hochfront oder zwei Fronten (unten/oben getrennt, Teilung = Oberkante Mittelboden). Je Front 2–6 Kästen, gleichmäßig im 32-mm-Lochraster.',
    'Fester Mittelboden zum Aussteifen: bei einer Front zwischen zwei Kästen in der Mitte, bei zwei Fronten an der Teilung.',
    'Kästen: LEGRABOX-Boden LW−35 × NL−10, Holzrückwand LW−38 × 148 mm (Zarge C); für Zarge C braucht jeder Kasten etwa 22 cm Höhe.',
    'Mit „Interagieren“ fährt die Front mit ihren Kästen heraus.',
    'Gezeichnet ist das Endmaß; den Anleimer (2 mm) zieht nur OpenCutList ab.',
    'Jedes Teil hat einen eigenen Tag <Kürzel>_<Bereich>_<Teil>, z. B. AP1_SeiteL, AP1_A_Front, AP1_A3_KastenBoden (Kasten 1 = oben).',
    'Feste Maße (Materialstärken, Abstände): Fenster „Komponentenattribute“.',
    "Doku: #{DOKU_URL}"
  ].join(' ').freeze

  # ---------------------------------------------------------------------------
  # Reine Berechnung (ohne SketchUp), spiegelt die DC-Formeln. Werte in cm.
  # ---------------------------------------------------------------------------
  # Raum für die Kästen einer Front: Oberkante fester Boden darunter, Unterkante fester Boden darüber
  def self.raum(p, f)
    mk = p['Materialstaerke_Korpus']
    zwei = p['Anz_Fronten'].to_i == 2
    if f == 'A'
      [mk, zwei ? p['H_Teilung'] - mk : p['Hoehe'] - mk]
    else
      [p['H_Teilung'], p['Hoehe'] - mk]
    end
  end

  # Unterkante des untersten Kastens: mindestens Kasten_Abstand_unten über zb und so, dass die
  # Schienenbohrung (Unterkante Kasten + Höhenoffset) auf dem Lochraster der Seite liegt
  def self.kasten_start(p, zb)
    st, ra, off = p['Lochraster_Start'], p['Lochraster'], p['Hoehenoffset_Schiene']
    st + ra * ((zb + p['Kasten_Abstand_unten'] + off - st) / ra - 0.0001).ceil - off
  end

  # Kästen einer Front: Teilung (Vielfaches des Rasters), Unterkanten (1 = oben), Höhe der Holzrückwand
  def self.kaesten(p, f)
    zb, zt = raum(p, f)
    n = p["Anz_Kaesten_#{f}"].to_i
    ra = p['Lochraster']
    k0 = kasten_start(p, zb)
    teilung = ra * ((zt - k0) / n / ra + 0.000001).floor
    rest = zt - k0 - n * teilung
    k0 += ra * (rest / 2 / ra + 0.000001).floor # Kästen mittig im Raum
    hrw = [[p['Hoehe_Kastenrueckwand'], teilung - abstand_oben(p, f) - p['Materialstaerke_Kastenboden']].min, 1.0].max
    z = (1..MAX_K).map { |j| j <= n ? k0 + (n - j) * teilung : k0 }
    { teilung: teilung, z: z, hrw: hrw, n: n }
  end

  # Abstand über einem Kasten; bei einer Front mit Mittelboden muss zwischen zwei Kästen auch der
  # Mittelboden mit Kasten_Abstand_unten zum Kasten darüber Platz haben
  def self.abstand_oben(p, f)
    mitte = f == 'A' && p['Anz_Fronten'].to_i == 1 && p['Mittelboden'].to_i == 1
    p['Kasten_Abstand_oben'] + (mitte ? p['Kasten_Abstand_unten'] + p['Materialstaerke_Korpus'] : 0)
  end

  def self.berechne(p)
    mk, sp = p['Materialstaerke_Korpus'], p['Spaltbreite']
    zwei = p['Anz_Fronten'].to_i == 2
    erg = { 'A' => kaesten(p, 'A'), 'B' => kaesten(p, 'B') }
    erg[:front] = { 'A' => [0.0, zwei ? p['H_Teilung'] - sp : p['Hoehe']],
                    'B' => [p['H_Teilung'], p['Hoehe'] - p['H_Teilung']] }
    a = erg['A']
    # bei einer Front: unter dem Kasten INT(n/2) (gezählt von oben), Kasten_Abstand_unten darunter
    erg[:mittelboden] = zwei ? p['H_Teilung'] - mk : a[:z][a[:n] / 2 - 1] - p['Kasten_Abstand_unten'] - mk
    erg[:mittelboden_sichtbar] = zwei || p['Mittelboden'].to_i == 1
    erg
  end

  # ---------------------------------------------------------------------------
  # Formeln (nur Eingabe-Attribute des Apothekerschranks verwenden, keine berechneten)
  # ---------------------------------------------------------------------------
  def self.a(n)
    "#{NAME}!#{n}"
  end

  def self.f_raum(f)
    if f == 'A'
      [a('Materialstaerke_Korpus'), "IF(#{a('Anz_Fronten')}=2,#{a('H_Teilung')},#{a('Hoehe')})-#{a('Materialstaerke_Korpus')}"]
    else
      [a('H_Teilung'), "#{a('Hoehe')}-#{a('Materialstaerke_Korpus')}"]
    end
  end

  def self.f_kasten_start(zb)
    st, ra, off = a('Lochraster_Start'), a('Lochraster'), a('Hoehenoffset_Schiene')
    # INT rundet ab, -INT(-x) also auf
    "(#{st}+#{ra}*(-INT(-((#{zb}+#{a('Kasten_Abstand_unten')}+#{off}-#{st})/#{ra}-0.0001)))-#{off})"
  end

  def self.f_teilung(f)
    zb, zt = f_raum(f)
    ra = a('Lochraster')
    "(#{ra}*INT((#{zt}-#{f_kasten_start(zb)})/#{a("Anz_Kaesten_#{f}")}/#{ra}+0.000001))"
  end

  # Unterkante des untersten Kastens, mittig verschoben
  def self.f_k0(f)
    zb, zt = f_raum(f)
    ra = a('Lochraster')
    k0 = f_kasten_start(zb)
    "(#{k0}+#{ra}*INT((#{zt}-#{k0}-#{a("Anz_Kaesten_#{f}")}*#{f_teilung(f)})/2/#{ra}+0.000001))"
  end

  # Unterkante Kasten j (1 = oben); j darf ein Ausdruck sein
  def self.f_z_kasten(f, j)
    "#{f_k0(f)}+(#{a("Anz_Kaesten_#{f}")}-(#{j}))*#{f_teilung(f)}"
  end

  def self.f_abstand_oben(f)
    return a('Kasten_Abstand_oben') if f == 'B'
    "(#{a('Kasten_Abstand_oben')}+IF(AND(#{a('Anz_Fronten')}=1,#{a('Mittelboden')}=1)," \
      "#{a('Kasten_Abstand_unten')}+#{a('Materialstaerke_Korpus')},0))"
  end

  def self.f_hrw(f)
    "MAX(MIN(#{a('Hoehe_Kastenrueckwand')},#{f_teilung(f)}-#{f_abstand_oben(f)}-#{a('Materialstaerke_Kastenboden')}),1)"
  end

  def self.f_mittelboden
    "IF(#{a('Anz_Fronten')}=2,#{a('H_Teilung')}-#{a('Materialstaerke_Korpus')}," \
      "#{f_z_kasten('A', "INT(#{a('Anz_Kaesten_A')}/2)")}-#{a('Kasten_Abstand_unten')}-#{a('Materialstaerke_Korpus')})"
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

  # Freies Kürzel für die Tags, z. B. AP1, AP2 …
  def self.freies_kuerzel(model)
    n = 1
    n += 1 while model.layers.to_a.any? { |l| l.name.start_with?("#{KUERZEL}#{n}_") }
    "#{KUERZEL}#{n}"
  end

  # Tag <Kürzel>_<Bereich>_<Teil> (z. B. AP1_SeiteL, AP1_A3_KastenBoden) und JT_Schrank am Teil;
  # front = Bereich der Front, an der ein Kasten hängt (für die Frontbefestigung im TCN-Export)
  def self.kennzeichnen(model, inst, kz, teil, bereich = nil, front = nil)
    name = [kz, bereich, teil].compact.join('_')
    inst.layer = model.layers[name] || model.layers.add(name)
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE, 'bereich' => bereich.to_s,
      'teil' => teil, 'rolle' => ROLLEN.fetch(teil.sub(/\d+\z/, '')) }.each { |k, v| inst.set_attribute(JT_DICT, k, v) }
    inst.set_attribute(JT_DICT, 'front', front) if front
    inst
  end

  SEITEN = { xmin: [0, -1], xmax: [0, 1], ymin: [1, -1], ymax: [1, 1], zmin: [2, -1], zmax: [2, 1] }.freeze

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

  # kz: [Modell, Kürzel, Teil, Bereich, Front] -> Tag und JT_Schrank (siehe kennzeichnen)
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

  # Größte LEGRABOX-Nennlänge (cm, 5er-Schritte, max. 65), für die die Einbautiefe reicht (LT >= NL + 3 mm)
  def self.nennlaenge(tiefe)
    [65.0, ((tiefe - 0.3) / 5.0 + 0.000001).floor * 5.0].min
  end

  def self.f_nennlaenge(tiefe)
    "MIN(65,INT((#{tiefe}-0.3)/5+0.000001)*5)"
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
    attribut(haupt, 'Anz_Fronten', p['Anz_Fronten'], laenge: false, access: 'LIST', formlabel: 'Fronten',
             units: 'INTEGER', options: '&Eine%20Hochfront=1&Zwei%20(unten%2Foben)=2&')
    attribut(haupt, 'H_Teilung', p['H_Teilung'], access: 'TEXTBOX',
             formlabel: 'Zwei Fronten: Höhe untere Front (bis Oberkante Mittelboden)')
    attribut(haupt, 'Anz_Kaesten_A', p['Anz_Kaesten_A'], laenge: false, access: 'LIST',
             formlabel: 'Kästen an der unteren bzw. einzigen Front', units: 'INTEGER', options: liste(MIN_K, MAX_K))
    attribut(haupt, 'Anz_Kaesten_B', p['Anz_Kaesten_B'], laenge: false, access: 'LIST',
             formlabel: 'Zwei Fronten: Kästen an der oberen Front', units: 'INTEGER', options: liste(MIN_K, MAX_K))
    attribut(haupt, 'Mittelboden', p['Mittelboden'], laenge: false, access: 'LIST',
             formlabel: 'Fester Mittelboden (bei zwei Fronten immer)', units: 'INTEGER', options: '&Ja=1&Nein=0&')
    attribut(haupt, 'Hoehe_Kastenrueckwand', p['Hoehe_Kastenrueckwand'], access: 'TEXTBOX',
             formlabel: 'Höhe Kastenrückwand (148 = LEGRABOX C)')
    attribut(haupt, 'Materialstaerke_Kastenboden', p['Materialstaerke_Kastenboden'], access: 'TEXTBOX',
             formlabel: 'Stärke Kastenboden')
    attribut(haupt, 'Hoehenoffset_Schiene', p['Hoehenoffset_Schiene'], access: 'TEXTBOX',
             formlabel: 'Höhenoffset Schiene (Bohrung über Unterkante Kasten)')

    # --- Feste Maße (über Komponentenattribute änderbar) ---
    %w[Materialstaerke_Korpus Materialstarke_Rueckwand Spaltbreite Materialstaerke_Kastenrueckwand
       Kasten_Abstand_unten Kasten_Abstand_oben Lochraster_Start Lochraster].each do |n|
      attribut(haupt, n, p[n], units: 'STRING')
    end
    attribut(haupt, 'Auszug_Anteil', p['Auszug_Anteil'], laenge: false, units: 'STRING')
    # Blum-Nennlänge (cm) aus der Korpustiefe, steuert Kastenlänge und Schienenbohrungen
    attribut(haupt, 'NL', nennlaenge(p['Tiefe']), units: 'STRING', formula: f_nennlaenge('Tiefe'))

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

    # Mittelboden: eigene Definition, damit "hidden" einzeln gesteuert werden kann
    mb = platte(model, 'Mittelboden', 'Mittelboden', [b - 2 * mk, t, mk], innen, kanten: %i[ymin])
    sichtbarkeit(mb, r[:mittelboden_sichtbar], "IF(OR(#{u}!Anz_Fronten=2,#{u}!Mittelboden=1),0,1)")
    m_inst = einsetzen(e, mb, 'Mittelboden', [mk, mk, r[:mittelboden]],
                       ["#{u}!Materialstaerke_Korpus", nil, f_mittelboden], mat: mat, kz: t_.('Mittelboden'))
    m_inst.hidden = !r[:mittelboden_sichtbar]

    rueck = platte(model, 'Rückwand', 'Rückwand', [b, rw, h],
                   ["#{u}!Breite", "#{u}!Materialstarke_Rueckwand", "#{u}!Hoehe"], kanten: %i[xmin xmax zmax])
    einsetzen(e, rueck, 'Rückwand', [0, t + mk, 0],
              [nil, "#{u}!Tiefe+#{u}!Materialstaerke_Korpus", nil], mat: mat, kz: t_.('Rueckwand'))

    # --- Auszüge: Front mit ihren Kästen ---
    FRONTEN.each { |f| auszug(model, e, p, r, f, mat, kz) }

    haupt
  end

  # Auszug f (A unten bzw. einzige Front, B oben): Front und bis zu MAX_K Kästen in einer
  # Komponente, die mit "Interagieren" herausfährt. Die Kastenlagen stehen als Attribute am
  # Auszug (aus den Eingaben des Apothekerschranks berechnet), die Teile beziehen sich darauf.
  def self.auszug(model, ents, p, r, f, mat, kz)
    u  = NAME
    s  = "Auszug#{f}"
    mk = p['Materialstaerke_Korpus']
    sp = p['Spaltbreite']
    b  = p['Breite']
    mb   = p['Materialstaerke_Kastenboden']
    mrw  = p['Materialstaerke_Kastenrueckwand']
    nl   = nennlaenge(p['Tiefe'])
    lw   = b - 2 * mk # lichte Weite
    k    = r[f]
    zf, hf = r[:front][f]
    sichtbar = f == 'A' || p['Anz_Fronten'].to_i == 2

    d = model.definitions.add(s)
    stempel(d)
    d.set_attribute(DICT, '_name', s)
    attribut(d, 'Breite', b, units: 'STRING', formula: "#{u}!Breite")
    attribut(d, 'Mk', mk, units: 'STRING', formula: "#{u}!Materialstaerke_Korpus")
    attribut(d, 'Spalt', sp, units: 'STRING', formula: "#{u}!Spaltbreite")
    attribut(d, 'Mb', mb, units: 'STRING', formula: "#{u}!Materialstaerke_Kastenboden")
    attribut(d, 'Mrw', mrw, units: 'STRING', formula: "#{u}!Materialstaerke_Kastenrueckwand")
    attribut(d, 'NL', nl, units: 'STRING', formula: "#{u}!NL")
    attribut(d, 'Anz', k[:n].to_f, laenge: false, units: 'INTEGER', formula: "#{u}!Anz_Kaesten_#{f}")
    if f == 'A'
      attribut(d, 'Z_Front', zf, units: 'STRING', formula: '0')
      attribut(d, 'H_Front', hf, units: 'STRING',
               formula: "IF(#{u}!Anz_Fronten=2,#{u}!H_Teilung-#{u}!Spaltbreite,#{u}!Hoehe)")
    else
      attribut(d, 'Z_Front', zf, units: 'STRING', formula: "#{u}!H_Teilung")
      attribut(d, 'H_Front', hf, units: 'STRING', formula: "#{u}!Hoehe-#{u}!H_Teilung")
    end
    attribut(d, 'Hrw', k[:hrw], units: 'STRING', formula: f_hrw(f))
    (1..MAX_K).each do |j|
      attribut(d, "Z_Kasten_#{j}", k[:z][j - 1], units: 'STRING',
               formula: "IF(#{u}!Anz_Kaesten_#{f}>=#{j},#{f_z_kasten(f, j)},#{f_k0(f)})")
    end
    attribut(d, 'Auszug', nl * p['Auszug_Anteil'], units: 'STRING', formula: "#{u}!NL*#{u}!Auszug_Anteil")
    sichtbarkeit(d, sichtbar, f == 'A' ? '0' : "IF(#{u}!Anz_Fronten=2,0,1)")
    d.set_attribute(DICT, 'onclick', 'ANIMATE("Y",0,-Auszug)')
    d.set_attribute(DICT, '_onclick_label', 'onClick')

    de = d.entities
    front = platte(model, "Front #{f}", 'Front', [b - sp, mk, hf],
                   ["#{s}!Breite-#{s}!Spalt", "#{s}!Mk", "#{s}!H_Front"], kanten: %i[xmin xmax zmin zmax])
    einsetzen(de, front, 'Front', [sp / 2.0, -sp, zf], ["#{s}!Spalt/2", "-#{s}!Spalt", "#{s}!Z_Front"],
              mat: mat, kz: [model, kz, 'Front', f])

    (1..MAX_K).each do |j|
      bt = ->(teil) { [model, kz, teil, "#{f}#{j}", f] }
      an = j <= k[:n]
      versteckt = "IF(#{s}!Anz>=#{j},0,1)"
      z = k[:z][j - 1]

      # Boden LW-35 x NL-10, mittig, vorne an der Korpusvorderkante
      kbod = platte(model, "Kasten Boden #{f}#{j}", 'KastenBoden', [lw - 3.5, nl - 1.0, mb],
                    ["#{s}!Breite-2*#{s}!Mk-3.5", "#{s}!NL-1", "#{s}!Mb"])
      sichtbarkeit(kbod, an, versteckt)
      i1 = einsetzen(de, kbod, 'KastenBoden', [mk + 1.75, mk, z],
                     ["#{s}!Mk+1.75", "#{s}!Mk", "#{s}!Z_Kasten_#{j}"], mat: mat, kz: bt.('KastenBoden'))

      # Holzrückwand LW-38 x Hrw, hinten auf dem Boden
      krw = platte(model, "Kasten Rueckwand #{f}#{j}", 'KastenRueckwand', [lw - 3.8, mrw, k[:hrw]],
                   ["#{s}!Breite-2*#{s}!Mk-3.8", "#{s}!Mrw", "#{s}!Hrw"], kanten: %i[zmax])
      sichtbarkeit(krw, an, versteckt)
      i2 = einsetzen(de, krw, 'KastenRueckwand', [mk + 1.9, mk + nl - 1.0 - mrw, z + mb],
                     ["#{s}!Mk+1.9", "#{s}!Mk+#{s}!NL-1-#{s}!Mrw", "#{s}!Z_Kasten_#{j}+#{s}!Mb"],
                     mat: mat, kz: bt.('KastenRueckwand'))
      i1.hidden = i2.hidden = !an
    end

    inst = einsetzen(ents, d, s, [0, 0, 0], [nil, nil, nil])
    inst.hidden = !sichtbar
    inst
  end

  # ---------------------------------------------------------------------------
  # Erzeugen (mit ziel zusätzlich als .skp speichern)
  # ---------------------------------------------------------------------------
  def self.erstellen(eingabe = {}, ziel = nil)
    model = Sketchup.active_model
    model.start_operation('Apothekerschrank', true)
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
        UI.messagebox('Automatisches Speichern ging nicht. Rechtsklick auf den Apothekerschrank → "Speichern unter…"')
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
  Kuechenplaner.untermenu('Hochschränke').add_item('Apothekerschrank…') { Apothekerschrank.erstellen }
  file_loaded(__FILE__)
end
