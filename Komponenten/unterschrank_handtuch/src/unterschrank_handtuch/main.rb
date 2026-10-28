# encoding: UTF-8
#
# Schmaler Unterschrank mit Hochauszug (Handtuchschrank) – erzeugt eine Dynamic
# Component
#
# Erweiterung (.rbz): Erweiterungen > Küchenplaner > Unterschränke > Unterschrank Handtuchauszug baut den Schrank im
# aktuellen Modell. Maße und Optionen danach in den Komponentenoptionen einstellen.
#
# Beschlag: Häfele UTENSIO Matrix HU Slim Base (Montageanleitung 4004110659MKT),
# Modell M150 (Schrank 150 mm, lichte Weite >= 112) oder M200 (200 mm, >= 162).
# Zwei Matrix-Schienen an einer Seite (LH = links, RH = rechts), das Gestell trägt
# die Front über die volle Höhe. Korpus wie beim Unterschrank mit Schubladen
# (Seiten, Boden, Streben oben, Rückwand hinter dem Korpus).
# Der Beschlag ist als Platzhalter gezeichnet (Einbauraum laut Häfele:
# lichte Weite x 485 x 565 mm). Er hat das Material "Häfele HU Slim Base"
# (OpenCutList-Typ Beschlag) und kein JT_Schrank, der TCN-Export übergeht ihn.
# Die Bohrungen für Schienen und Front setzt der TCN-Export.
#
# OpenCutList: Platten haben das Material "Melamin weiss" (Plattenwerkstoff),
# sichtbare Kanten das Material "Anleimer Melamin weiss" (Kante, 2 mm, wird nur
# in OCL abgezogen; gezeichnet wird das Endmaß). Jedes Teil hat einen eigenen Tag
# <Kürzel>_<Teil> (z. B. USH1_SeiteL, USH1_Front) und das Wörterbuch "JT_Schrank"
# für den TCN-Export. Anderes Kürzel:
#   UnterschrankHandtuch.erstellen({ 'Kuerzel' => 'USH2' }, ziel)

require 'sketchup.rb'

module UnterschrankHandtuch

  DICT     = 'dynamic_attributes'.freeze
  NAME     = 'Unterschrank_Handtuch'.freeze
  MATERIAL = 'Melamin weiss'.freeze
  KANTE    = 'Anleimer Melamin weiss'.freeze
  BESCHLAG = 'Häfele HU Slim Base'.freeze
  OCL_DICT = 'ladb_opencutlist'.freeze
  KUERZEL  = 'USH'.freeze

  # Tag-Schema für den TCN-Export (gleich in allen Komponenten, der Test prüft das):
  # Tag <Kürzel>_<Bereich>_<Teil>, dazu am Teil das Wörterbuch JT_Schrank.
  JT_DICT   = 'JT_Schrank'.freeze
  TYP       = 'Unterschrank_Handtuch'.freeze
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

  # Häfele-Modelle: Schrankbreite in cm (lichte Weite = Breite - 2 x 19 mm = 112 bzw. 162 mm)
  MODELLE = { 150 => 15.0, 200 => 20.0 }.freeze
  BESCHLAG_NAME = 'Haefele HU Slim Base'.freeze # steht am Schrank in JT_Schrank/beschlag

  # Standardwerte in cm
  DEFAULTS = {
    'Modell'                   => 150.0, # M150 oder M200
    'Seite_Beschlag'           => 0.0,   # 0 = links (LH), 1 = rechts (RH)
    'Hoehe'                    => 70.0,
    'Tiefe'                    => 80.0,  # Korpus ohne Front/Rückwand, wie die anderen Unterschränke
    'Materialstaerke_Korpus'   => 1.9,
    'Materialstarke_Rueckwand' => 0.8,
    'BreiteStreben'            => 10.0,
    'Spaltbreite'              => 0.2,
    'Bauraum_Tiefe'            => 48.5,  # Häfele: Einbautiefe >= 485 mm
    'Bauraum_Hoehe'            => 56.5,  # Häfele: lichte Höhe >= 565 mm
    'Auszug_Weg'               => 45.0   # Animation "Interagieren"
  }.freeze

  # Kurzhilfe in der Komponente (Kurzfassung der README.md). SketchUp zeigt
  # "summary" und "description" oben im Fenster "Komponentenoptionen".
  DOKU_URL = 'https://github.com/jimmycd/sketchup_kuechenplaner2/tree/main/Komponenten/unterschrank_handtuch'.freeze
  HILFE_KURZ = 'Schmaler Unterschrank 150/200 mm mit Hochauszug Häfele HU Slim Base, OpenCutList-fähig'.freeze
  HILFE = [
    'Modell (M150 = 150 mm, M200 = 200 mm breit), Seite der Schienen (links/rechts), Höhe und Tiefe hier ändern.',
    'Beschlag Häfele UTENSIO Matrix HU Slim Base: zwei Schienen an einer Seite, Front über die volle Höhe; braucht lichte Höhe >= 565 mm und Tiefe >= 485 mm.',
    'Der Beschlag ist als Platzhalter (Einbauraum) gezeichnet; OpenCutList führt ihn als Beschlag.',
    'Mit „Interagieren“ fährt der Auszug heraus.',
    'Gezeichnet ist das Endmaß; den Anleimer (2 mm) zieht nur OpenCutList ab.',
    'Jedes Teil hat einen eigenen Tag <Kürzel>_<Teil>, z. B. USH1_SeiteL, USH1_Front.',
    'Feste Maße (Materialstärken, Streben, Spalt): Fenster „Komponentenattribute“.',
    "Doku: #{DOKU_URL}"
  ].join(' ').freeze

  # ---------------------------------------------------------------------------
  # Reine Berechnung (ohne SketchUp), spiegelt die DC-Formeln. Werte in cm.
  # ---------------------------------------------------------------------------
  def self.berechne(p)
    b = breite(p['Modell'])
    { b: b, lw: b - 2 * p['Materialstaerke_Korpus'] }
  end

  def self.breite(modell)
    MODELLE.fetch(modell.to_i) { raise ArgumentError, "Modell M#{modell.to_i} gibt es nicht (M150, M200)" }
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
    ocl_material(model, BESCHLAG, [150, 150, 155], 'type' => 5, 'description' => 'Häfele UTENSIO Matrix HU Slim Base')
  end

  # Freies Kürzel für die Tags, z. B. USH1, USH2 …
  def self.freies_kuerzel(model)
    n = 1
    n += 1 while model.layers.to_a.any? { |l| l.name.start_with?("#{KUERZEL}#{n}_") }
    "#{KUERZEL}#{n}"
  end

  def self.tag(model, name)
    model.layers[name] || model.layers.add(name)
  end

  # Tag <Kürzel>_<Bereich>_<Teil> (z. B. USH1_SeiteL) und JT_Schrank am Teil
  def self.kennzeichnen(model, inst, kz, teil, bereich = nil)
    inst.layer = tag(model, [kz, bereich, teil].compact.join('_'))
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE, 'bereich' => bereich.to_s,
      'teil' => teil, 'rolle' => ROLLEN.fetch(teil.sub(/\d+\z/, '')) }.each { |k, v| inst.set_attribute(JT_DICT, k, v) }
    inst
  end

  SEITEN = { xmin: [0, -1], xmax: [0, 1], ymin: [1, -1], ymax: [1, 1], zmin: [2, -1], zmax: [2, 1] }.freeze

  # Sichtbare Kanten je Teil, bekommen in OCL einen Anleimer (wie Unterschrank mit Schubladen).
  # ymin = vorne, zmin/zmax = unten/oben, xmin/xmax = links/rechts.
  KANTEN = {
    'Seite'        => %i[ymin],
    'Boden'        => %i[ymin],
    'StrebeVorn'   => %i[ymin],
    'StrebeHinten' => [],
    'Rückwand'     => [],
    'Front'        => %i[xmin xmax zmin zmax],
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

    haupt = model.definitions.add('Unterschrank Handtuch')
    stempel(haupt)
    haupt.set_attribute(DICT, '_name', u)
    hilfe(haupt)
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE, 'beschlag' => BESCHLAG_NAME }.each do |k, v|
      haupt.set_attribute(JT_DICT, k, v)
    end

    # --- Parameter (Komponentenoptionen) ---
    attribut(haupt, 'Modell', p['Modell'].to_f, laenge: false, access: 'LIST', formlabel: 'Häfele HU Slim Base',
             units: 'INTEGER', options: '&M150%20(150%20mm%20breit)=150&M200%20(200%20mm%20breit)=200&')
    attribut(haupt, 'Breite', r[:b], access: 'VIEW', formlabel: 'Breite (aus dem Modell)',
             formula: 'IF(Modell=200,20,15)')
    attribut(haupt, 'Seite_Beschlag', p['Seite_Beschlag'].to_f, laenge: false, access: 'LIST',
             formlabel: 'Schienen an Seite', units: 'INTEGER', options: '&links%20(LH)=0&rechts%20(RH)=1&')
    attribut(haupt, 'Hoehe', p['Hoehe'], access: 'TEXTBOX', formlabel: 'Höhe')
    attribut(haupt, 'Tiefe', p['Tiefe'], access: 'TEXTBOX', formlabel: 'Tiefe (Korpus ohne Front/Rückwand)')

    # --- Feste Maße (über Komponentenattribute änderbar) ---
    %w[Materialstaerke_Korpus Materialstarke_Rueckwand BreiteStreben Spaltbreite
       Bauraum_Tiefe Bauraum_Hoehe Auszug_Weg].each do |n|
      attribut(haupt, n, p[n], units: 'STRING')
    end

    mk = p['Materialstaerke_Korpus']
    b, h, t = r[:b], p['Hoehe'], p['Tiefe']
    bs, rw = p['BreiteStreben'], p['Materialstarke_Rueckwand']
    e = haupt.entities
    innen_b = "#{u}!Breite-2*#{u}!Materialstaerke_Korpus"

    # --- Korpus (wie Unterschrank mit Schubladen) ---
    seite = platte(model, 'Seite', 'Seite', [mk, t, h],
                   ["#{u}!Materialstaerke_Korpus", "#{u}!Tiefe", "#{u}!Hoehe"])
    einsetzen(e, seite, 'SeiteL', [0, mk, 0], [nil, nil, nil], mat: mat, kz: t_.('SeiteL'))
    einsetzen(e, seite, 'SeiteR', [b - mk, mk, 0],
              ["#{u}!Breite-#{u}!Materialstaerke_Korpus", nil, nil], mat: mat, kz: t_.('SeiteR'))

    boden = platte(model, 'Boden', 'Boden', [r[:lw], t, mk], [innen_b, "#{u}!Tiefe", "#{u}!Materialstaerke_Korpus"])
    einsetzen(e, boden, 'Boden', [mk, mk, 0], ["#{u}!Materialstaerke_Korpus", nil, nil], mat: mat, kz: t_.('Boden'))

    strebe_formeln = [innen_b, "#{u}!BreiteStreben", "#{u}!Materialstaerke_Korpus"]
    strebe_v = platte(model, 'StrebeV', 'StrebeVorn', [r[:lw], bs, mk], strebe_formeln)
    einsetzen(e, strebe_v, 'StrebeVorn', [mk, mk, h - mk],
              ["#{u}!Materialstaerke_Korpus", nil, "#{u}!Hoehe-#{u}!Materialstaerke_Korpus"],
              mat: mat, kz: t_.('StrebeVorn'))
    strebe_h = platte(model, 'StrebeH', 'StrebeHinten', [r[:lw], bs, mk], strebe_formeln)
    einsetzen(e, strebe_h, 'StrebeHinten', [mk, t - bs + mk, h - mk],
              ["#{u}!Materialstaerke_Korpus", "#{u}!Tiefe-#{u}!BreiteStreben+#{u}!Materialstaerke_Korpus",
               "#{u}!Hoehe-#{u}!Materialstaerke_Korpus"], mat: mat, kz: t_.('StrebeHinten'))

    rueck = platte(model, 'Rückwand', 'Rückwand', [b, rw, h],
                   ["#{u}!Breite", "#{u}!Materialstarke_Rueckwand", "#{u}!Hoehe"])
    einsetzen(e, rueck, 'Rückwand', [0, t + mk, 0],
              [nil, "#{u}!Tiefe+#{u}!Materialstaerke_Korpus", nil], mat: mat, kz: t_.('Rueckwand'))

    auszug(model, e, p, r, mat, kz)
    haupt
  end

  # Hochauszug: Front über die volle Höhe und Platzhalter für das Häfele-Gestell,
  # zusammen in einer Gruppe, die mit "Interagieren" herausfährt
  def self.auszug(model, e, p, r, mat, kz)
    u = NAME
    a = 'Auszug'
    mk, sp, h = p['Materialstaerke_Korpus'], p['Spaltbreite'], p['Hoehe']
    d = model.definitions.add('Auszug')
    stempel(d)
    d.set_attribute(DICT, '_name', a)
    # Lokale Kopien der Werte vom Schrank (Formeln können nur Eltern/Geschwister ansprechen)
    attribut(d, 'Breite', r[:b], units: 'STRING', formula: "#{u}!Breite")
    attribut(d, 'Hoehe', h, units: 'STRING', formula: "#{u}!Hoehe")
    attribut(d, 'Mk', mk, units: 'STRING', formula: "#{u}!Materialstaerke_Korpus")
    attribut(d, 'Spalt', sp, units: 'STRING', formula: "#{u}!Spaltbreite")
    attribut(d, 'BT', p['Bauraum_Tiefe'], units: 'STRING', formula: "#{u}!Bauraum_Tiefe")
    attribut(d, 'BH', p['Bauraum_Hoehe'], units: 'STRING', formula: "#{u}!Bauraum_Hoehe")
    attribut(d, 'Weg', p['Auszug_Weg'], units: 'STRING', formula: "#{u}!Auszug_Weg")
    d.set_attribute(DICT, 'onclick', 'ANIMATE("Y",0,-Weg)')
    d.set_attribute(DICT, '_onclick_label', 'onClick')

    de = d.entities
    # Front wie bei einer einzelnen Schublade: Spalt/2 seitlich, -Spalt vor dem Korpus, volle Höhe
    front = platte(model, 'Front Hochauszug', 'Front', [r[:b] - sp, mk, h],
                   ["#{a}!Breite-#{a}!Spalt", "#{a}!Mk", "#{a}!Hoehe"])
    einsetzen(de, front, 'Front', [sp / 2.0, -sp, 0], ["#{a}!Spalt/2", "-#{a}!Spalt", nil],
              mat: mat, kz: [model, kz, 'Front'])

    # Platzhalter Beschlag = Einbauraum laut Häfele, auf dem Boden ab Korpusvorderkante.
    # Kein JT_Schrank (kein Werkstück), eigener Tag für die Zuordnung in OCL.
    g = platte(model, 'HU Slim Base', 'Beschlag', [r[:lw], p['Bauraum_Tiefe'], p['Bauraum_Hoehe']],
               ["#{a}!Breite-2*#{a}!Mk", "#{a}!BT", "#{a}!BH"])
    einsetzen(de, g, 'Beschlag', [mk, mk, mk], ["#{a}!Mk", "#{a}!Mk", "#{a}!Mk"],
              mat: beschlag_material(model), layer: tag(model, "#{kz}_Beschlag"))

    einsetzen(e, d, a, [0, 0, 0], [nil, nil, nil], layer: tag(model, "#{kz}_Auszug"))
  end

  # ---------------------------------------------------------------------------
  # Erzeugen (mit ziel zusätzlich als .skp speichern)
  # ---------------------------------------------------------------------------
  def self.erstellen(eingabe = {}, ziel = nil)
    model = Sketchup.active_model
    model.start_operation('Unterschrank Handtuch', true)
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
  Kuechenplaner.untermenu('Unterschränke').add_item('Unterschrank Handtuchauszug…') { UnterschrankHandtuch.erstellen }
  file_loaded(__FILE__)
end
