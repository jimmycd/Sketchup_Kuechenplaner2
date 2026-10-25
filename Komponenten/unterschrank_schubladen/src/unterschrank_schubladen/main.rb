# encoding: UTF-8
#
# Unterschrank mit Schubladen – Generator für eine Dynamic Component
#
# Erzeugt analog zum "Unterschrank" (mit Tür) einen Korpus aus Seiten, Boden,
# Streben und Rückwand, aber mit 1–6 Schubladen statt Tür/Einlegeböden.
# Anzahl und Höhenaufteilung der Schubladen bleiben anschließend über
# "Komponentenoptionen" (Dynamic Components) änderbar.
#
# Aufteilung: Jede Schublade hat einen "Anteil". Die Fronthöhen werden im
# Verhältnis der Anteile der sichtbaren Schubladen auf die Schrankhöhe verteilt.
# Beispiele bei 3 Schubladen: 1/1/1 = gleich hoch, 1/1/2 = unterste doppelt so
# hoch. Man kann auch direkt Millimeter eingeben (z. B. 140/140/416), die Werte
# werden dann passend auf die Höhe skaliert.

require 'sketchup.rb'

module UnterschrankSchubladen

  DICT     = 'dynamic_attributes'.freeze
  NAME     = 'Unterschrank_Schubladen'.freeze
  MAX_SCHUBLADEN = 6
  PARK_HOEHE = 10.0 # cm
  MATERIAL = 'Melamin weiss'.freeze
  ANLEIMER = 'Anleimer weiss'.freeze
  OCL_DICT = 'ladb_opencutlist'.freeze

  # OpenCutList-Einstellungen, falls die Materialien im Modell noch fehlen
  # (Werte wie in Unterschrank.skp). Vorhandene OCL-Einstellungen bleiben unangetastet.
  OCL_MATERIALIEN = {
    MATERIAL => {
      'type' => 2, # Plattenmaterial
      'thickness' => '0', 'length_increase' => '10 mm', 'width_increase' => '10 mm',
      'thickness_increase' => '0', 'grained' => true, 'edge_decremented' => false,
      'std_thicknesses' => '8 mm;10 mm;15 mm;16 mm;18 mm;19 mm;22 mm',
      'std_sizes' => '2800 mm x 2070 mm;2500 mm x 1250 mm;2440 mm x 1220 mm',
      'description' => 'Span Melamin weiss'
    },
    ANLEIMER => {
      'type' => 4, # Kante
      'thickness' => '2 mm', 'length_increase' => '0', 'width_increase' => '0',
      'thickness_increase' => '0', 'grained' => false, 'edge_decremented' => true,
      'std_widths' => '19 mm;23 mm;28 mm;33 mm;35 mm;43 mm', 'std_lengths' => '75 m'
    }
  }.freeze

  # Sichtbare Kanten je Teil, bekommen in OCL einen Anleimer.
  # Richtungen im Schrank: ymin = vorne, zmax = oben, xmin/xmax = links/rechts.
  # SketchUp zeigt Endmaße; den Abzug für den Anleimer rechnet nur OCL.
  KANTEN = {
    'Seite'        => %i[ymin],                  # Vorderkante
    'Boden'        => %i[ymin],
    'StrebeVorn'   => %i[ymin],
    'StrebeHinten' => [],
    'Rückwand'     => [],
    'Front'        => %i[xmin xmax zmin zmax],   # rundum
    'KastenSeite'  => %i[zmax],                  # Oberkante
    'KastenQuer'   => %i[zmax],
    'KastenBoden'  => []
  }.freeze

  # Standardwerte in cm (Korpus wie beim Unterschrank mit Tür)
  DEFAULTS = {
    'Breite'                      => 60.0,
    'Hoehe'                       => 70.0,
    'Tiefe'                       => 80.0,
    'Materialstaerke_Korpus'      => 1.9,
    'Materialstarke_Rueckwand'    => 0.8,
    'BreiteStreben'               => 10.0,
    'Spaltbreite'                 => 0.2,
    # Schubkasten
    'Materialstaerke_Schubkasten' => 1.6,
    'Materialstaerke_Kastenboden' => 0.8,
    'Luft_Auszug'                 => 1.3,  # Abstand Innenseite Schrankseite -> Außenseite Kasten (Schienensystem)
    'Abstand_Tiefe_Kasten'        => 2.0,  # Kasten ist um so viel kürzer als Tiefe
    'Kasten_Abstand_unten'        => 3.0,  # Unterkante Front -> Unterkante Kasten
    'Kasten_Abstand_oben'         => 3.0,  # Oberkante Kasten -> Oberkante Front
    'Auszug_Anteil'               => 0.8   # Animation: Auszugsweg = Kastentiefe * Anteil
  }.freeze

  # Kurzhilfe in der Komponente (Kurzfassung der README.md). SketchUp zeigt
  # "summary" und "description" oben im Fenster "Komponentenoptionen".
  DOKU_URL = 'https://github.com/jimmycd/sketchup_kuechenplaner2/tree/main/Komponenten/unterschrank_schubladen'.freeze
  HILFE_KURZ = 'Unterschrank mit 1–6 Schubladen, OpenCutList-fähig'.freeze
  HILFE = [
    'Breite, Höhe, Tiefe, Anzahl Schubladen und Anteile (Schublade 1 = oben) hier ändern.',
    'Anteile: 1/1/2 = unterste doppelt so hoch; mm-Werte werden auf die Höhe skaliert.',
    'Abstand Schrankseite–Kasten je Seite passend zum Schienensystem (Standard 13 mm).',
    'Mit „Interagieren“ auf eine Schublade klicken: sie fährt heraus.',
    'Gezeichnet ist das Endmaß; den Anleimer (2 mm) zieht nur OpenCutList ab.',
    'Jedes Teil hat einen eigenen Tag <Kürzel>_<Teil>, z. B. USS1_S2_Front.',
    'Feste Maße (Materialstärken, Abstände): Fenster „Komponentenattribute“.',
    "Doku: #{DOKU_URL}"
  ].join(' ').freeze

  # ---------------------------------------------------------------------------
  # Reine Berechnung (ohne SketchUp), spiegelt exakt die DC-Formeln.
  # Alle Werte in cm.
  # ---------------------------------------------------------------------------
  def self.berechne(p)
    n      = p['Anz_Schubladen'].to_i
    anteil = (1..MAX_SCHUBLADEN).map { |i| p["Anteil_#{i}"].to_f }
    summe  = anteil.first(n).sum
    netto  = p['Hoehe'] - (n - 1) * p['Spaltbreite']
    fronten = (1..MAX_SCHUBLADEN).map do |i|
      if i <= n
        h = netto * anteil[i - 1] / summe
        z = p['Hoehe'] - netto * anteil.first(i).sum / summe - (i - 1) * p['Spaltbreite']
      else
        # ausgeblendete Schubladen im Korpus parken, damit sie die Bounding Box nicht vergrößern
        h = PARK_HOEHE
        z = 0.0
      end
      { h: h, z: z }
    end
    { summe: summe, netto: netto, fronten: fronten }
  end

  # ---------------------------------------------------------------------------
  # Formeln
  # ---------------------------------------------------------------------------
  def self.f_summe
    terms = ['Anteil_1'] + (2..MAX_SCHUBLADEN).map { |i| "IF(Anz_Schubladen>=#{i},Anteil_#{i},0)" }
    "(#{terms.join('+')})"
  end

  def self.f_netto
    '(Hoehe-(Anz_Schubladen-1)*Spaltbreite)'
  end

  # Ausgeblendete Schubladen (i > Anzahl) werden mit dieser Höhe bei z=0 geparkt
  def self.nur_sichtbar(i, formel, park)
    i == 1 ? formel : "IF(Anz_Schubladen>=#{i},#{formel},#{park})"
  end

  def self.f_h_front(i)
    nur_sichtbar(i, "#{f_netto}*Anteil_#{i}/#{f_summe}", PARK_HOEHE)
  end

  def self.f_z_front(i)
    teil = (1..i).map { |j| "Anteil_#{j}" }.join('+')
    nur_sichtbar(i, "Hoehe-#{f_netto}*(#{teil})/#{f_summe}-#{i - 1}*Spaltbreite", 0)
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

  # Benutzerdefiniertes Attribut am Hauptbauteil bzw. an einer Schublade.
  # laenge: true  -> Wert in cm, wird intern in Zoll gespeichert
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

  def self.material(model, name = MATERIAL)
    m = model.materials[name] || begin
      neu = model.materials.add(name)
      neu.color = Sketchup::Color.new(255, 255, 255)
      neu
    end
    if m.get_attribute(OCL_DICT, 'type').nil?
      OCL_MATERIALIEN[name].each { |k, v| m.set_attribute(OCL_DICT, k, v) }
    end
    m
  end

  # Eindeutiges Kürzel für die Tags, z. B. USS1, USS2 …
  def self.freies_kuerzel(model)
    n = 1
    n += 1 while model.layers.to_a.any? { |l| l.name.start_with?("USS#{n}_") }
    "USS#{n}"
  end

  def self.tag(model, name)
    model.layers[name] || model.layers.add(name)
  end

  def self.quader(ents, lx, ly, lz)
    f = ents.add_face([0, 0, 0], [inch(lx), 0, 0], [inch(lx), inch(ly), 0], [0, inch(ly), 0])
    f.reverse! if f.normal.z < 0
    f.pushpull(inch(lz))
  end

  # Richtung einer Quaderfläche anhand ihrer Normalen
  def self.seite_von(face)
    n = face.normal
    return n.x > 0 ? :xmax : :xmin if n.x.abs > 0.5
    return n.y > 0 ? :ymax : :ymin if n.y.abs > 0.5
    n.z > 0 ? :zmax : :zmin
  end

  # Kantenflächen mit dem Anleimer-Material belegen (so erkennt OCL die Kanten)
  def self.anleimer_setzen(defn, kanten, anleimer)
    defn.entities.grep(Sketchup::Face).each do |f|
      f.material = anleimer if kanten.include?(seite_von(f))
    end
  end

  # Legt eine Platten-Definition an (Quader lx*ly*lz cm) mit LenX/Y/Z-Formeln.
  def self.platte(model, defname, dc_name, groesse, len_formeln)
    d = model.definitions.add(defname)
    quader(d.entities, *groesse)
    anleimer_setzen(d, KANTEN.fetch(dc_name), material(model, ANLEIMER))
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

  # Setzt eine Instanz an pos (cm) mit Positionsformeln.
  def self.einsetzen(ents, defn, inst_name, pos, pos_formeln, mat: nil, layer: nil)
    tr = Geom::Transformation.translation(Geom::Vector3d.new(*pos.map { |v| inch(v) }))
    inst = ents.add_instance(defn, tr)
    inst.name = inst_name
    inst.material = mat if mat
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

  # ---------------------------------------------------------------------------
  # Aufbau
  # ---------------------------------------------------------------------------
  def self.erzeuge(model, eingabe)
    p = DEFAULTS.merge(eingabe)
    r = berechne(p)
    u = NAME
    mat = material(model)
    kz = p['Kuerzel'] || freies_kuerzel(model)
    t_ = ->(teil) { tag(model, "#{kz}_#{teil}") } # ein Tag je Teil für die CAD/CAM-Zuordnung

    haupt = model.definitions.add('Unterschrank mit Schubladen')
    stempel(haupt)
    haupt.set_attribute(DICT, '_name', u)
    hilfe(haupt)

    # --- Parameter (sichtbar in den Komponentenoptionen) ---
    attribut(haupt, 'Breite', p['Breite'], access: 'TEXTBOX', formlabel: 'Breite')
    attribut(haupt, 'Hoehe', p['Hoehe'], access: 'TEXTBOX', formlabel: 'Hoehe')
    attribut(haupt, 'Tiefe', p['Tiefe'], access: 'TEXTBOX', formlabel: 'Tiefe (Korpus ohne Front/Rückwand)')
    opts = '&' + (1..MAX_SCHUBLADEN).map { |i| "#{i}=#{i}" }.join('&') + '&'
    attribut(haupt, 'Anz_Schubladen', p['Anz_Schubladen'].to_f, laenge: false, access: 'LIST',
             formlabel: 'Anzahl Schubladen', units: 'INTEGER', options: opts)
    (1..MAX_SCHUBLADEN).each do |i|
      lage = i == 1 ? ' (oben)' : ''
      attribut(haupt, "Anteil_#{i}", p["Anteil_#{i}"].to_f, laenge: false, access: 'TEXTBOX',
               formlabel: "Anteil Schublade #{i}#{lage}")
    end
    attribut(haupt, 'Luft_Auszug', p['Luft_Auszug'], access: 'TEXTBOX',
             formlabel: 'Abstand Schrankseite–Kasten je Seite (Schiene)')

    # --- Feste Maße (wie beim Unterschrank mit Tür über Attribute änderbar) ---
    %w[Materialstaerke_Korpus Materialstarke_Rueckwand BreiteStreben Spaltbreite
       Materialstaerke_Schubkasten Materialstaerke_Kastenboden
       Abstand_Tiefe_Kasten Kasten_Abstand_unten Kasten_Abstand_oben].each do |n|
      attribut(haupt, n, p[n], units: 'STRING')
    end
    attribut(haupt, 'Auszug_Anteil', p['Auszug_Anteil'], laenge: false, units: 'STRING')

    # --- Abgeleitete Werte je Schublade ---
    r[:fronten].each_with_index do |fr, idx|
      i = idx + 1
      attribut(haupt, "H_Front_#{i}", fr[:h], units: 'STRING', formula: f_h_front(i))
      attribut(haupt, "Z_Front_#{i}", fr[:z], units: 'STRING', formula: f_z_front(i))
    end

    mk = p['Materialstaerke_Korpus']
    b, h, t = p['Breite'], p['Hoehe'], p['Tiefe']
    bs, rw, sp = p['BreiteStreben'], p['Materialstarke_Rueckwand'], p['Spaltbreite']
    e = haupt.entities

    # --- Korpus (identisch zum Unterschrank mit Tür) ---
    seite = platte(model, 'Seite', 'Seite', [mk, t, h],
                   ["#{u}!Materialstaerke_Korpus", "#{u}!Tiefe", "#{u}!Hoehe"])
    einsetzen(e, seite, 'SeiteL', [0, mk, 0], [nil, nil, nil], mat: mat, layer: t_.('SeiteL'))
    einsetzen(e, seite, 'SeiteR', [b - mk, mk, 0],
              ["#{u}!Breite-#{u}!Materialstaerke_Korpus", nil, nil], mat: mat, layer: t_.('SeiteR'))

    boden = platte(model, 'Boden', 'Boden', [b - 2 * mk, t, mk],
                   ["#{u}!Breite-2*#{u}!Materialstaerke_Korpus", "#{u}!Tiefe", "#{u}!Materialstaerke_Korpus"])
    einsetzen(e, boden, 'Boden', [mk, mk, 0], ["#{u}!Materialstaerke_Korpus", nil, nil],
              mat: mat, layer: t_.('Boden'))

    strebe_formeln = ["#{u}!Breite-2*#{u}!Materialstaerke_Korpus", "#{u}!BreiteStreben",
                      "#{u}!Materialstaerke_Korpus"]
    strebe_v = platte(model, 'StrebeV', 'StrebeVorn', [b - 2 * mk, bs, mk], strebe_formeln)
    einsetzen(e, strebe_v, 'StrebeVorn', [mk, mk, h - mk],
              ["#{u}!Materialstaerke_Korpus", nil, "#{u}!Hoehe-#{u}!Materialstaerke_Korpus"],
              mat: mat, layer: t_.('StrebeVorn'))
    strebe_h = platte(model, 'StrebeH', 'StrebeHinten', [b - 2 * mk, bs, mk], strebe_formeln)
    einsetzen(e, strebe_h, 'StrebeHinten', [mk, t - bs + mk, h - mk],
              ['StrebeVorn!X', "#{u}!Tiefe-#{u}!BreiteStreben+#{u}!Materialstaerke_Korpus", 'StrebeVorn!Z'],
              mat: mat, layer: t_.('StrebeHinten'))

    rueck = platte(model, 'Rückwand', 'Rückwand', [b, rw, h],
                   ["#{u}!Breite", "#{u}!Materialstarke_Rueckwand", "#{u}!Hoehe"])
    einsetzen(e, rueck, 'Rückwand', [0, t + mk, 0],
              [nil, "#{u}!Tiefe+#{u}!Materialstaerke_Korpus", nil], mat: mat, layer: t_.('Rueckwand'))

    # --- Schubladen ---
    (1..MAX_SCHUBLADEN).each do |i|
      schublade(model, e, p, r[:fronten][i - 1], i, mat, t_)
    end

    haupt.set_attribute(OCL_DICT, 'kuerzel', kz)
    haupt
  end

  def self.schublade(model, ents, p, fr, i, mat, t_)
    u  = NAME
    s  = "Schublade#{i}"
    mk = p['Materialstaerke_Korpus']
    sp = p['Spaltbreite']
    b  = p['Breite']
    luft = p['Luft_Auszug']
    mks  = p['Materialstaerke_Schubkasten']
    mb   = p['Materialstaerke_Kastenboden']
    tk   = p['Tiefe'] - p['Abstand_Tiefe_Kasten']
    au, ao = p['Kasten_Abstand_unten'], p['Kasten_Abstand_oben']
    hf   = fr[:h]
    kb   = b - 2 * mk - 2 * luft        # Außenbreite Kasten
    kh   = [hf - au - ao, 2.0].max      # Höhe Kasten (Seiten), mind. 2 cm
    st = ->(teil) { t_.("S#{i}_#{teil}") }

    d = model.definitions.add(s)
    stempel(d)
    d.set_attribute(DICT, '_name', s)
    # Lokale Kopien der Werte vom Unterschrank (Formeln können nur Eltern/Geschwister ansprechen)
    attribut(d, 'Breite', b, units: 'STRING', formula: "#{u}!Breite")
    attribut(d, 'Hoehe_Front', hf, units: 'STRING', formula: "#{u}!H_Front_#{i}")
    attribut(d, 'Mk', mk, units: 'STRING', formula: "#{u}!Materialstaerke_Korpus")
    attribut(d, 'Spalt', sp, units: 'STRING', formula: "#{u}!Spaltbreite")
    attribut(d, 'Luft', luft, units: 'STRING', formula: "#{u}!Luft_Auszug")
    attribut(d, 'Mks', mks, units: 'STRING', formula: "#{u}!Materialstaerke_Schubkasten")
    attribut(d, 'Mb', mb, units: 'STRING', formula: "#{u}!Materialstaerke_Kastenboden")
    attribut(d, 'Tiefe_Kasten', tk, units: 'STRING', formula: "#{u}!Tiefe-#{u}!Abstand_Tiefe_Kasten")
    attribut(d, 'Ab_unten', au, units: 'STRING', formula: "#{u}!Kasten_Abstand_unten")
    attribut(d, 'Ab_oben', ao, units: 'STRING', formula: "#{u}!Kasten_Abstand_oben")
    attribut(d, 'Auszug', tk * p['Auszug_Anteil'], units: 'STRING',
             formula: "(#{u}!Tiefe-#{u}!Abstand_Tiefe_Kasten)*#{u}!Auszug_Anteil")
    # Sichtbarkeit (wie Einlegeböden beim Unterschrank mit Tür)
    d.set_attribute(DICT, 'hidden', i <= p['Anz_Schubladen'].to_i ? 0.0 : 1.0)
    d.set_attribute(DICT, '_hidden_formula', "IF(#{u}!Anz_Schubladen>=#{i},0,1)")
    d.set_attribute(DICT, '_hidden_label', 'Hidden')
    d.set_attribute(DICT, '_hidden_formlabel', 'Hidden')
    d.set_attribute(DICT, '_hidden_units', 'BOOLEAN')
    # Mit "Interagieren" anklicken -> Schublade fährt heraus
    d.set_attribute(DICT, 'onclick', 'ANIMATE("Y",0,-Auszug)')
    d.set_attribute(DICT, '_onclick_label', 'onClick')

    de = d.entities
    # Front (wie Tür: Spalt/2 seitlich, -Spalt vor dem Korpus)
    front = platte(model, "Front S#{i}", 'Front', [b - sp, mk, hf],
                   ["#{s}!Breite-#{s}!Spalt", "#{s}!Mk", "#{s}!Hoehe_Front"])
    einsetzen(de, front, 'Front', [sp / 2.0, -sp, 0], ["#{s}!Spalt/2", "-#{s}!Spalt", nil],
              mat: mat, layer: st.('Front'))

    # Kasten-Seiten
    roh_kh = "#{s}!Hoehe_Front-#{s}!Ab_unten-#{s}!Ab_oben"
    f_kh   = "IF(#{roh_kh}>2,#{roh_kh},2)"
    ks = platte(model, "Kasten Seite S#{i}", 'KastenSeite', [mks, tk, kh],
                ["#{s}!Mks", "#{s}!Tiefe_Kasten", f_kh])
    einsetzen(de, ks, 'KastenSeiteL', [mk + luft, mk, au],
              ["#{s}!Mk+#{s}!Luft", "#{s}!Mk", "#{s}!Ab_unten"], mat: mat, layer: st.('KastenSeiteL'))
    einsetzen(de, ks, 'KastenSeiteR', [b - mk - luft - mks, mk, au],
              ["#{s}!Breite-#{s}!Mk-#{s}!Luft-#{s}!Mks", "#{s}!Mk", "#{s}!Ab_unten"], mat: mat, layer: st.('KastenSeiteR'))

    innen_b = "#{s}!Breite-2*#{s}!Mk-2*#{s}!Luft-2*#{s}!Mks"
    # Kastenboden zwischen den Seiten, Vorder-/Rückstück stehen darauf
    kbod = platte(model, "Kasten Boden S#{i}", 'KastenBoden', [kb - 2 * mks, tk, mb],
                  [innen_b, "#{s}!Tiefe_Kasten", "#{s}!Mb"])
    einsetzen(de, kbod, 'KastenBoden', [mk + luft + mks, mk, au],
              ["#{s}!Mk+#{s}!Luft+#{s}!Mks", "#{s}!Mk", "#{s}!Ab_unten"], mat: mat, layer: st.('KastenBoden'))

    kvr = platte(model, "Kasten Vorder-Rueckstueck S#{i}", 'KastenQuer', [kb - 2 * mks, mks, kh - mb],
                 [innen_b, "#{s}!Mks", "#{f_kh}-#{s}!Mb"])
    einsetzen(de, kvr, 'KastenVorne', [mk + luft + mks, mk, au + mb],
              ["#{s}!Mk+#{s}!Luft+#{s}!Mks", "#{s}!Mk", "#{s}!Ab_unten+#{s}!Mb"], mat: mat, layer: st.('KastenVorne'))
    einsetzen(de, kvr, 'KastenHinten', [mk + luft + mks, mk + tk - mks, au + mb],
              ["#{s}!Mk+#{s}!Luft+#{s}!Mks", "#{s}!Mk+#{s}!Tiefe_Kasten-#{s}!Mks", "#{s}!Ab_unten+#{s}!Mb"],
              mat: mat, layer: st.('KastenHinten'))

    inst = einsetzen(ents, d, s, [0, 0, fr[:z]], [nil, nil, "#{u}!Z_Front_#{i}"], layer: st.('Schublade'))
    inst.hidden = i > p['Anz_Schubladen'].to_i
    inst
  end

  # ---------------------------------------------------------------------------
  # Eingabe
  # ---------------------------------------------------------------------------
  # "1;1;2", "1/1/2", "140 140 416" -> [1.0, 1.0, 2.0]
  def self.parse_aufteilung(text, anzahl)
    werte = text.to_s.split(%r{[;/\s]+}).reject(&:empty?).map { |w| w.tr(',', '.').to_f }
    werte = werte.first(anzahl)
    werte << 1.0 while werte.size < anzahl
    raise ArgumentError, 'Anteile müssen größer als 0 sein' if werte.any? { |w| w <= 0 }
    werte
  end

  def self.dialog
    prompts = ['Breite (mm)', 'Höhe (mm)', 'Tiefe Korpus (mm)', 'Anzahl Schubladen',
               'Aufteilung von oben (Anteile oder mm, z. B. 1;1;2)',
               'Abstand Schrankseite–Kasten je Seite (mm)',
               'Kürzel für Tags (eindeutig je Schrank)']
    defaults = ['600', '700', '800', '3', '1;1;1', '13', freies_kuerzel(Sketchup.active_model)]
    lists = ['', '', '', (1..MAX_SCHUBLADEN).to_a.join('|'), '', '', '']
    res = UI.inputbox(prompts, defaults, lists, 'Unterschrank mit Schubladen')
    return unless res

    anz = res[3].to_i
    eingabe = {
      'Breite' => res[0].tr(',', '.').to_f / 10.0,
      'Hoehe'  => res[1].tr(',', '.').to_f / 10.0,
      'Tiefe'  => res[2].tr(',', '.').to_f / 10.0,
      'Anz_Schubladen' => anz,
      'Luft_Auszug' => res[5].tr(',', '.').to_f / 10.0,
      'Kuerzel' => res[6].strip
    }
    raise ArgumentError, 'Kürzel darf nicht leer sein' if eingabe['Kuerzel'].empty?
    if Sketchup.active_model.layers.to_a.any? { |l| l.name.start_with?("#{eingabe['Kuerzel']}_") }
      raise ArgumentError, "Kürzel #{eingabe['Kuerzel']} ist schon vergeben"
    end
    raise ArgumentError, 'Abstand Schrankseite–Kasten darf nicht negativ sein' if eingabe['Luft_Auszug'] < 0
    parse_aufteilung(res[4], anz).each_with_index { |w, idx| eingabe["Anteil_#{idx + 1}"] = w }
    (anz + 1..MAX_SCHUBLADEN).each { |i| eingabe["Anteil_#{i}"] = 1.0 }
    erstellen(eingabe)
  rescue ArgumentError => e
    UI.messagebox("Ungültige Eingabe: #{e.message}")
  end

  def self.erstellen(eingabe)
    model = Sketchup.active_model
    model.start_operation('Unterschrank mit Schubladen', true)
    defn = erzeuge(model, eingabe)
    # Rechts neben vorhandene Geometrie setzen, damit nichts überlappt
    x = model.entities.length > 0 ? model.bounds.max.x + 10.cm : 0
    inst = model.entities.add_instance(defn, Geom::Transformation.translation([x, 0, 0]))
    inst.name = NAME
    inst.set_attribute(DICT, '_name', NAME)
    model.commit_operation

    # Formeln einmal durch das Dynamic-Components-Plugin auswerten lassen
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

  unless file_loaded?(__FILE__)
    UI.menu('Extensions').add_item('Unterschrank mit Schubladen…') { dialog }
    file_loaded(__FILE__)
  end
end
