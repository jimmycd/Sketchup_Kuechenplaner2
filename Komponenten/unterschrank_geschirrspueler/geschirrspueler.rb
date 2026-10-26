# encoding: UTF-8
#
# Unterschrank Geschirrspüler – erzeugt eine Dynamic Component und speichert sie als .skp
#
# Kein Plugin: einmal in der Ruby-Konsole laden, z. B.
#   load 'C:/Users/<Name>/Downloads/geschirrspueler.rb'
# Das Skript baut den Schrank im aktuellen Modell und speichert ihn als
# "Unterschrank_Geschirrspueler.skp" neben diese Datei.
#
# Ein vollintegrierter Geschirrspüler hat keinen Korpus: Die Komponente ist eine
# Nische (450 oder 600 mm) mit Möbelfront, die auf die Gerätetür geschraubt wird,
# optional mit Abschlusswangen links/rechts und einem Platzhalter für das Gerät.
# Die Front wird vor Ort mit der Schablone des Herstellers befestigt, deshalb gibt
# es dafür keine CNC-Bohrungen.
#
# OpenCutList: Platten haben das Material "Melamin weiss" (Plattenwerkstoff),
# sichtbare Kanten das Material "Anleimer Melamin weiss" (Kante, 2 mm, wird nur
# in OCL abgezogen; gezeichnet wird das Endmaß). Jedes Teil hat einen eigenen Tag
# <Kürzel>_<Teil> (z. B. USG1_Front, USG1_WangeL) und das Wörterbuch "JT_Schrank"
# für den TCN-Export. Der Geräte-Platzhalter liegt auf dem Tag "Geraete_Plan", hat
# kein Plattenmaterial und kein JT_Schrank. Die Nische steht im Wörterbuch
# "JT_Nische" am Schrank (für die Geräte-Komponenten).
# Anderes Kürzel: UnterschrankGeschirrspueler.erstellen({ 'Kuerzel' => 'USG2' }, ziel)

require 'sketchup.rb'

module UnterschrankGeschirrspueler

  DICT     = 'dynamic_attributes'.freeze
  NAME     = 'Unterschrank Geschirrspueler'.freeze
  MATERIAL = 'Melamin weiss'.freeze
  KANTE    = 'Anleimer Melamin weiss'.freeze
  GERAET_MATERIAL = 'Geraet Plan'.freeze
  GERAET_TAG = 'Geraete_Plan'.freeze
  OCL_DICT = 'ladb_opencutlist'.freeze
  KUERZEL  = 'USG'.freeze

  # Tag-Schema für den TCN-Export (gleich in allen Komponenten, der Test prüft das):
  # Tag <Kürzel>_<Bereich>_<Teil>, dazu am Teil das Wörterbuch JT_Schrank.
  JT_DICT   = 'JT_Schrank'.freeze
  TYP       = 'Unterschrank_Geschirrspueler'.freeze
  KATEGORIE = 'Unterschrank'.freeze # Unterschrank, Oberschrank oder Hochschrank
  ROLLEN = {
    'SeiteL' => 'Seite', 'SeiteR' => 'Seite', 'Boden' => 'Boden', 'Deckel' => 'Deckel',
    'StrebeVorn' => 'Strebe', 'StrebeHinten' => 'Strebe',
    'ZwischenbodenUnten' => 'Zwischenboden', 'ZwischenbodenOben' => 'Zwischenboden',
    'Rueckwand' => 'Rueckwand', 'Einlegeboden' => 'Einlegeboden', 'Front' => 'Front',
    'Tuer' => 'Tuer', 'TuerL' => 'Tuer', 'TuerR' => 'Tuer',
    'KastenBoden' => 'KastenBoden', 'KastenRueckwand' => 'KastenRueckwand',
    'WangeL' => 'Wange', 'WangeR' => 'Wange'
  }.freeze

  # Nische für die Geräte-Komponenten (Thread "Geräte in Schränken darstellen")
  NISCHE_DICT = 'JT_Nische'.freeze

  # Standardwerte in cm
  DEFAULTS = {
    'Breite'                   => 60.0,  # Nischenbreite, 45 oder 60
    'Hoehe'                    => 70.0,  # wie Korpushöhe der anderen Unterschränke
    'Tiefe'                    => 80.0,  # wie Korpustiefe der anderen Unterschränke
    'Fronthoehe'               => 70.0,  # Oberkante bündig mit den Nachbarfronten
    'Art_Wange'                => 0.0,   # 0 = keine, 1 = links, 2 = rechts, 3 = beide
    'Sockelhoehe'              => 10.0,  # Wangen und Gerät reichen bis zum Boden
    'Materialstaerke_Korpus'   => 1.9,
    'Materialstarke_Rueckwand' => 0.8,
    'Spaltbreite'              => 0.2,
    'Geraet_Luft'              => 0.2,   # Nische 600 -> Gerät 598
    'Geraet_Tiefe'             => 55.0
  }.freeze

  # Kurzhilfe in der Komponente (Kurzfassung der README.md). SketchUp zeigt
  # "summary" und "description" oben im Fenster "Komponentenoptionen".
  DOKU_URL = 'https://github.com/jimmycd/sketchup_kuechenplaner2/tree/main/Komponenten/unterschrank_geschirrspueler'.freeze
  HILFE_KURZ = 'Nische für vollintegrierten Geschirrspüler (45/60 cm) mit Möbelfront, OpenCutList-fähig'.freeze
  HILFE = [
    'Nischenbreite (450/600 mm), Höhe und Tiefe wie die Unterschränke daneben, Fronthöhe und Abschlusswangen hier ändern.',
    'Kein Korpus: Die Front wird mit der Schablone des Geräteherstellers auf die Gerätetür geschraubt (keine CNC-Bohrungen).',
    'Achtung: Prüfen, ob die Fronthöhe zum Gerät passt (Herstellerangabe zu Fronthöhe und Nischenhöhe, übliche Nische 815–875 mm inkl. Sockel).',
    'Wangen und Geräte-Platzhalter reichen um die Sockelhöhe unter den Korpus bis zum Boden.',
    'Der Platzhalter liegt auf dem Tag Geraete_Plan; vor OpenCutList ausblenden.',
    'Mit „Interagieren“ klappt die Front auf.',
    'Gezeichnet ist das Endmaß; den Anleimer (2 mm) zieht nur OpenCutList ab.',
    'Jedes Teil hat einen eigenen Tag <Kürzel>_<Teil>, z. B. USG1_Front, USG1_WangeL.',
    "Doku: #{DOKU_URL}"
  ].join(' ').freeze

  # ---------------------------------------------------------------------------
  # Reine Berechnung (ohne SketchUp), spiegelt die DC-Formeln. Werte in cm.
  # ---------------------------------------------------------------------------
  def self.berechne(p)
    mk, sp = p['Materialstaerke_Korpus'], p['Spaltbreite']
    w = p['Art_Wange'].to_i
    {
      x_nische: [1, 3].include?(w) ? mk : 0.0,
      links: [1, 3].include?(w),
      rechts: [2, 3].include?(w),
      b_front: p['Breite'] - sp,
      z_front: p['Hoehe'] - p['Fronthoehe'],
      h_unten: p['Hoehe'] + p['Sockelhoehe'] # Boden bis Oberkante Korpus
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

  # Halbtransparentes Material für den Platzhalter, ohne OCL-Einstellungen
  def self.geraet_material(model)
    m = model.materials[GERAET_MATERIAL]
    return m if m
    m = model.materials.add(GERAET_MATERIAL)
    m.color = Sketchup::Color.new(90, 140, 200)
    m.alpha = 0.4 if m.respond_to?(:alpha=)
    m
  end

  # Freies Kürzel für die Tags, z. B. USG1, USG2 …
  def self.freies_kuerzel(model)
    n = 1
    n += 1 while model.layers.to_a.any? { |l| l.name.start_with?("#{KUERZEL}#{n}_") }
    "#{KUERZEL}#{n}"
  end

  # Tag <Kürzel>_<Bereich>_<Teil> (z. B. USG1_Front) und JT_Schrank am Teil
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
    'Front'  => %i[xmin xmax zmin zmax], # rundum
    'Wange'  => %i[ymin zmax],           # vorne und oben, unten steht sie auf dem Boden
    'Geraet' => []
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
    kennzeichnen(kz[0], inst, *kz[1..]) if kz
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

  # Nische für die Geräte-Komponenten: lichte Maße und Einfügepunkt (vorne links
  # unten auf dem Fußboden, an der Korpusvorderkante) in mm, Stand beim Erzeugen
  def self.nische(d, p, r)
    b = ((p['Breite'] - p['Geraet_Luft']) * 10).round(1)
    { 'nische' => 'N1', 'geraet' => "Geschirrspueler#{p['Breite'].round}",
      'breite' => b, 'hoehe' => (r[:h_unten] * 10).round(1), 'tiefe' => (p['Tiefe'] * 10).round(1),
      'x' => (r[:x_nische] * 10).round(1), 'y' => (p['Materialstaerke_Korpus'] * 10).round(1),
      'z' => (-p['Sockelhoehe'] * 10).round(1) }.each { |k, v| d.set_attribute(NISCHE_DICT, k, v) }
  end

  # ---------------------------------------------------------------------------
  # Aufbau
  # ---------------------------------------------------------------------------
  def self.erzeuge(model, eingabe = {})
    p = DEFAULTS.merge(eingabe)
    r = berechne(p)
    u = 'UnterschrankGeschirrspueler'
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
    attribut(haupt, 'Breite', p['Breite'], access: 'LIST', formlabel: 'Nischenbreite',
             options: '&450%20mm=45&600%20mm=60&')
    attribut(haupt, 'Hoehe', p['Hoehe'], access: 'TEXTBOX', formlabel: 'Höhe (wie Korpus der Nachbarschränke)')
    attribut(haupt, 'Tiefe', p['Tiefe'], access: 'TEXTBOX', formlabel: 'Tiefe (wie Korpus der Nachbarschränke)')
    attribut(haupt, 'Fronthoehe', p['Fronthoehe'], access: 'TEXTBOX', formlabel: 'Fronthöhe (Oberkante bleibt)')
    attribut(haupt, 'Art_Wange', p['Art_Wange'], laenge: false, access: 'LIST', formlabel: 'Abschlusswange',
             units: 'INTEGER', options: '&Keine=0&Links=1&Rechts=2&Beide=3&')
    attribut(haupt, 'Sockelhoehe', p['Sockelhoehe'], access: 'TEXTBOX', formlabel: 'Sockelhöhe (Wange bis Boden)')

    # --- Feste Maße (über Komponentenattribute änderbar) ---
    %w[Materialstaerke_Korpus Materialstarke_Rueckwand Spaltbreite Geraet_Luft Geraet_Tiefe].each do |n|
      attribut(haupt, n, p[n], units: 'STRING')
    end

    # --- Abgeleitete Werte ---
    attribut(haupt, 'X_Nische', r[:x_nische], units: 'STRING',
             formula: 'IF(Art_Wange=1,Materialstaerke_Korpus,IF(Art_Wange=3,Materialstaerke_Korpus,0))')

    mk, sp = p['Materialstaerke_Korpus'], p['Spaltbreite']
    e = haupt.entities

    # --- Front: wie die Fronten der Unterschränke, Oberkante = Korpusoberkante ---
    front = platte(model, 'Front', 'Front', [r[:b_front], mk, p['Fronthoehe']],
                   ["#{u}!Breite-#{u}!Spaltbreite", "#{u}!Materialstaerke_Korpus", "#{u}!Fronthoehe"])
    # Aufklappen um die Unterkante (wie die Gerätetür)
    front.set_attribute(DICT, 'rotx', 0.0)
    front.set_attribute(DICT, 'onclick', 'ANIMATE("ROTX",0,90)')
    front.set_attribute(DICT, '_onclick_label', 'onClick')
    einsetzen(e, front, 'Front', [r[:x_nische] + sp / 2.0, -sp, r[:z_front]],
              ["#{u}!X_Nische+#{u}!Spaltbreite/2", "-#{u}!Spaltbreite", "#{u}!Hoehe-#{u}!Fronthoehe"],
              mat: mat, kz: t_.('Front'))

    # --- Abschlusswangen außerhalb der Nische, wie die Seiten der Unterschränke, bis zum Boden ---
    wangen = [['WangeL', r[:links], 'IF(OR(Art_Wange=1,Art_Wange=3),0,1)', [0, nil]],
              ['WangeR', r[:rechts], 'IF(OR(Art_Wange=2,Art_Wange=3),0,1)',
               [r[:x_nische] + p['Breite'], "#{u}!X_Nische+#{u}!Breite"]]]
    wangen.each do |teil, sichtbar, formel, (x, fx)|
      d = platte(model, teil, teil, [mk, p['Tiefe'] + p['Materialstarke_Rueckwand'], r[:h_unten]],
                 ["#{u}!Materialstaerke_Korpus", "#{u}!Tiefe+#{u}!Materialstarke_Rueckwand",
                  "#{u}!Hoehe+#{u}!Sockelhoehe"], art: 'Wange')
      sichtbarkeit(d, sichtbar, formel.gsub('Art_Wange', "#{u}!Art_Wange"))
      inst = einsetzen(e, d, teil, [x, mk, -p['Sockelhoehe']], [fx, nil, "-#{u}!Sockelhoehe"],
                       mat: mat, kz: t_.(teil))
      inst.hidden = !sichtbar
    end

    # --- Geräte-Platzhalter (kein Schrankteil: kein Plattenmaterial, kein JT_Schrank) ---
    g = platte(model, 'Geschirrspueler Platzhalter', 'Geraet',
               [p['Breite'] - p['Geraet_Luft'], p['Geraet_Tiefe'], r[:h_unten]],
               ["#{u}!Breite-#{u}!Geraet_Luft", "#{u}!Geraet_Tiefe", "#{u}!Hoehe+#{u}!Sockelhoehe"])
    tag = model.layers[GERAET_TAG] || model.layers.add(GERAET_TAG)
    einsetzen(e, g, 'Geraet', [r[:x_nische] + p['Geraet_Luft'] / 2.0, mk, -p['Sockelhoehe']],
              ["#{u}!X_Nische+#{u}!Geraet_Luft/2", nil, "-#{u}!Sockelhoehe"],
              mat: geraet_material(model), layer: tag)
    haupt
  end

  # ---------------------------------------------------------------------------
  # Erzeugen + als .skp speichern
  # ---------------------------------------------------------------------------
  def self.erstellen(eingabe = {}, ziel = nil)
    model = Sketchup.active_model
    model.start_operation('Unterschrank Geschirrspüler', true)
    defn = erzeuge(model, eingabe)
    x = model.entities.length > 0 ? model.bounds.max.x + 10.cm : 0
    inst = model.entities.add_instance(defn, Geom::Transformation.translation([x, 0, 0]))
    inst.name = NAME
    inst.set_attribute(DICT, '_name', 'UnterschrankGeschirrspueler')
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

# Beim Laden in der Ruby-Konsole direkt erzeugen und speichern
unless defined?($GESCHIRRSPUELER_TEST)
  UnterschrankGeschirrspueler.erstellen({}, File.join(File.dirname(File.expand_path(__FILE__)), 'Unterschrank_Geschirrspueler.skp'))
end
