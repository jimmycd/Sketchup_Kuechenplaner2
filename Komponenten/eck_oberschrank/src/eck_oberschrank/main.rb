# encoding: UTF-8
#
# Eck-Oberschrank L-Form – erzeugt eine Dynamic Component
#
# Erweiterung (.rbz): Erweiterungen > Küchenplaner > Oberschränke > Eck-Oberschrank L-Form
# fragt Schenkel A, Schenkel B, Höhe und Tiefe ab und baut den Schrank im aktuellen Modell.
#
# Gegenstück zur L-Form des Eck-Unterschranks, aber mit dem Korpus des Oberschranks:
# Seiten an den Schenkelenden über die volle Höhe und Tiefe, Boden über die volle Tiefe,
# Deckel endet vor den Rückwänden und wird mit ihnen verschraubt. Die Rückwände (8 mm)
# liegen 25 mm vor der Wand (Fach für die Aufhängung) in einer 9 mm tiefen Nut in Seiten
# und Boden; die hinter Schenkel A geht durch die Ecke, die hinter B stößt daran.
# Boden, Deckel und Einlegeböden sind je eine L-Platte; die Innenecke fräst der TCN-Export
# aus. Unter jedem Einlegeboden trägt eine Auflageleiste an der Rückwand die Ecke.
# Falttür: Tür A (TuerR) läuft durch die Ecke, Tür B (TuerL) endet 1 mm vor ihr.
#
# Eine Dynamic Component würde eine L-Platte beim Skalieren verzerren. Ändern sich
# Schenkel A, Schenkel B oder Tiefe in den Komponentenoptionen, baut die Erweiterung den
# Schrank deshalb neu auf (Beobachter, EckOberschrank.l_pruefen). Höhe und Einlegeböden
# folgen per Formel.
#
# Platten haben das Material "Melamin weiss", sichtbare Kanten das Material "Anleimer
# Melamin weiss" (2 mm, wird erst in Stückliste und Zuschnitt abgezogen; gezeichnet wird
# das Endmaß). Jedes Teil hat einen eigenen Tag <Kürzel>_<Teil> (z. B. OES1_SeiteL,
# OES1_TuerR) und das Wörterbuch "JT_Schrank" für TCN-Export und Stückliste.
# Anderes Kürzel: EckOberschrank.erstellen({ 'Kuerzel' => 'OES2' })

require 'sketchup.rb'
require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'eingabe') # Eingabefenster im Treppenplaner-Stil

module EckOberschrank

  DICT     = 'dynamic_attributes'.freeze
  NAME     = 'Eck_Oberschrank'.freeze
  MATERIAL = 'Melamin weiss'.freeze
  KANTE    = 'Anleimer Melamin weiss'.freeze
  # Materialdaten (Typ, Stärke, Kante abziehen) stehen im selben Wörterbuch wie bisher;
  # die Stückliste des Schrank-CNC-Plugins liest sie dort
  MAT_DICT = 'ladb_opencutlist'.freeze
  KUERZEL  = 'OES'.freeze
  L_DICT   = 'JT_EckOberschrank'.freeze
  L_GEBAUT = 'l_gebaut'.freeze # [Schenkel A, Schenkel B, Tiefe] in cm, mit denen der Schrank gebaut ist
  L_MASSE  = %w[Schenkel_A Schenkel_B Tiefe].freeze
  MAX_EB   = 2

  # Tag-Schema für den TCN-Export (gleich in allen Komponenten, der Test prüft das):
  # Tag <Kürzel>_<Bereich>_<Teil>, dazu am Teil das Wörterbuch JT_Schrank.
  JT_DICT   = 'JT_Schrank'.freeze
  TYP       = 'Eckschrank'.freeze
  KATEGORIE = 'Oberschrank'.freeze # Unterschrank, Oberschrank oder Hochschrank
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
    'Winkelleiste' => 'Leiste', 'Sockelblende' => 'Sockel', 'SockelSeiteL' => 'Sockel', 'SockelSeiteR' => 'Sockel',
    'Platte' => 'Arbeitsplatte',
    'Verkleidung' => 'Verkleidung', 'Theke' => 'Theke'
  }.freeze

  # Standardwerte in cm
  FEST = {
    'Materialstaerke_Korpus'    => 1.9,
    'Materialstarke_Rueckwand'  => 0.8,
    'Rueckwand_Versatz'         => 2.5,   # Wand -> Rückseite Rückwand (Fach für die Aufhängung)
    'Nuttiefe'                  => 0.9,
    'Spaltbreite'               => 0.2,
    'Rueckversatz_Einlegeboden' => 1.0,   # Einlegeböden vorne zurückgesetzt
    'Leiste_Laenge'             => 20.0,  # Auflageleiste unter dem Einlegeboden, entlang Schenkel A
    'Leiste_Breite'             => 3.0    # Tiefe der Leiste (Höhe = Materialstärke)
  }.freeze
  DEFAULTS = FEST.merge(
    'Schenkel_A'        => 65.0,  # entlang der hinteren Wand, außen (Wand links bis Seite rechts)
    'Schenkel_B'        => 65.0,  # entlang der linken Wand, außen (Wand hinten bis Seite vorne)
    'Hoehe'             => 70.0,
    'Tiefe'             => 35.0,  # Seite = Korpus mit Aufhängefach, ohne Front
    'Anz_Einlegeboeden' => 1.0
  ).freeze

  # Kurzhilfe in der Komponente (Kurzfassung der README.md), steht oben im Fenster "Komponentenoptionen".
  DOKU_URL = 'https://github.com/jimmycd/sketchup_kuechenplaner2/tree/main/Komponenten/eck_oberschrank'.freeze
  HILFE_KURZ = 'Eck-Oberschrank L-Form mit Falttür, 0–2 L-Einlegeböden'.freeze

  # ---------------------------------------------------------------------------
  # Reine Berechnung (ohne SketchUp). Werte in cm.
  #
  # Draufsicht: Schenkel A entlang der hinteren Wand (y = yw), Schenkel B entlang der
  # linken Wand (x = 0). Der Korpus von A beginnt wie bei allen Schränken bei
  # y = Materialstärke, die Tür liegt davor; Schenkel B ragt nach vorne (-y) heraus,
  # seine Front zeigt nach +x. Die Innenecke liegt bei x = Tiefe, y = Mk.
  # ---------------------------------------------------------------------------
  def self.masse(p)
    mk, t, rw, v, rv = p['Materialstaerke_Korpus'], p['Tiefe'], p['Materialstarke_Rueckwand'],
                       p['Rueckwand_Versatz'], p['Rueckversatz_Einlegeboden']
    a, bb = p['Schenkel_A'], p['Schenkel_B']
    yw = mk + t        # Wand hinter Schenkel A
    ye = yw - bb + mk  # Innenseite der Seite am Ende von Schenkel B
    hi = v + rw        # Abstand Wand -> Vorderseite Rückwand (Deckel, Einlegeböden bis hier)
    raise ArgumentError, "Tiefe #{(t * 10).round} mm: mindestens #{(tiefe_min * 10).round} mm" if t < tiefe_min - 1e-6
    { 'Schenkel A' => a - mk - t, 'Schenkel B' => bb - t - mk }.each do |n, frei|
      raise ArgumentError, "#{n} zu kurz: Innenraum vor der Ecke #{(frei * 10).round} mm (mindestens 150 mm)" if frei < 15
    end
    { yw: yw, ye: ye, hi: hi,
      boden: [a - mk, yw - ye], ecke: [t, mk - ye],
      deckel: [a - mk - hi, yw - hi - ye], ecke_deckel: [t - hi, mk - ye],
      ecke_eb: [t - rv - hi, mk + rv - ye] }
  end

  def self.tiefe_min
    20.0
  end

  def self.z_einlegeboden(p, k)
    mk, h, n = p['Materialstaerke_Korpus'], p['Hoehe'], p['Anz_Einlegeboeden'].to_i
    n >= k ? mk + (h - 2 * mk) * k / (n + 1) - mk / 2 : mk
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

  # Materialtyp und Maße im Wörterbuch MAT_DICT am Material.
  # Bereits konfigurierte Materialien werden nicht verändert.
  def self.platten_material(model, name, farbe, attribute)
    m = model.materials[name] || model.materials.add(name)
    m.color = Sketchup::Color.new(*farbe) unless m.texture || m.get_attribute(MAT_DICT, 'type')
    if m.get_attribute(MAT_DICT, 'type').to_i == 0
      attribute.each { |k, v| m.set_attribute(MAT_DICT, k, v) }
    end
    m
  end

  def self.material(model)
    platten_material(model, MATERIAL, [255, 255, 255],
                     'type' => 2, # Plattenwerkstoff
                     'std_thicknesses' => '8mm;16mm;19mm',
                     'std_sizes' => '2800mm x 2070mm',
                     'grained' => false)
  end

  def self.kanten_material(model)
    @kante = platten_material(model, KANTE, [245, 245, 240],
                              'type' => 4, # Kante/Anleimer
                              'thickness' => '2mm',
                              'std_widths' => '23mm',
                              'std_lengths' => '75m',
                              'edge_decremented' => true) # 2 mm werden erst in Stückliste/Zuschnitt abgezogen
  end

  # Freies Kürzel für die Tags, z. B. OES1, OES2 …
  def self.freies_kuerzel(model)
    n = 1
    n += 1 while model.layers.to_a.any? { |l| l.name.start_with?("#{KUERZEL}#{n}_") }
    "#{KUERZEL}#{n}"
  end

  # Tag <Kürzel>_<Bereich>_<Teil> (z. B. OES1_SeiteL) und JT_Schrank am Teil
  def self.kennzeichnen(model, inst, kz, teil, bereich = nil)
    name = [kz, bereich, teil].compact.join('_')
    inst.layer = model.layers[name] || model.layers.add(name)
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE, 'bereich' => bereich.to_s,
      'teil' => teil, 'rolle' => ROLLEN.fetch(teil.sub(/\d+\z/, '')) }.each { |k, v| inst.set_attribute(JT_DICT, k, v) }
    inst
  end

  SEITEN = { xmin: [0, -1], xmax: [0, 1], ymin: [1, -1], ymax: [1, 1], zmin: [2, -1], zmax: [2, 1] }.freeze

  # Sichtbare Kanten je Teil, bekommen einen Anleimer.
  # ymin = vorne, zmin/zmax = unten/oben, xmin/xmax = links/rechts.
  # Die Vorderkante von Schenkel B zeigt nach +x (…B).
  KANTEN = {
    'Seite'        => %i[ymin zmin zmax], # Oberschrank: Unter- und Oberkante sichtbar
    'SeiteB'       => %i[xmax zmin zmax],
    'Rückwand'     => [],
    'Leiste'       => %i[ymin xmax],
    'Tür'          => %i[xmin xmax zmin zmax],
    'TürB'         => %i[ymin ymax zmin zmax]
  }.freeze

  # Quader in Endmaß zeichnen; die in "kanten" genannten Flächen bekommen das
  # Anleimer-Material (Material der Kantenfläche).
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

  # L-förmige Platte (Boden, Deckel, Einlegeböden): Rechteck lx x ly ohne die Ecke
  # vorne rechts (x >= ex, y <= ey). Die Ecke steht als ecke_x/ecke_y (Zoll, lokal)
  # an der Definition, daraus fräst der TCN-Export den Ausschnitt (mit Anleimer an den
  # Kanten der Innenecke). Die Außenkanten bleiben ohne Kantenmaterial: Stückliste und
  # Zuschnitt rechnen mit dem umschließenden Rechteck.
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

  # kz: [Modell, Kürzel, Teil] -> Tag und JT_Schrank (siehe kennzeichnen)
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
    m = masse(p)
    u = NAME
    mat = material(model)
    kanten_material(model)
    kz = p['Kuerzel'] || freies_kuerzel(model)
    t_ = ->(teil) { [model, kz, teil] }
    mk, h, t, rw, v, nut, sp = p['Materialstaerke_Korpus'], p['Hoehe'], p['Tiefe'], p['Materialstarke_Rueckwand'],
                               p['Rueckwand_Versatz'], p['Nuttiefe'], p['Spaltbreite']
    a, bb = p['Schenkel_A'], p['Schenkel_B']
    yw, ye, hi = m[:yw], m[:ye], m[:hi]
    n = p['Anz_Einlegeboeden'].to_i

    haupt = model.definitions.add('Eck-Oberschrank L-Form')
    stempel(haupt)
    haupt.set_attribute(DICT, '_name', u)
    hilfe(haupt)
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE }.each { |k, val| haupt.set_attribute(JT_DICT, k, val) }

    # Schenkel und Tiefe sind änderbar, aber eine L-Platte lässt sich nicht per Formel
    # umformen: nach einer Änderung baut l_pruefen den Schrank neu auf (L_GEBAUT merkt
    # sich die Maße, mit denen er gebaut ist)
    attribut(haupt, 'Schenkel_A', a, access: 'TEXTBOX', formlabel: 'Schenkel A (hinten)')
    attribut(haupt, 'Schenkel_B', bb, access: 'TEXTBOX', formlabel: 'Schenkel B (links)')
    attribut(haupt, 'Tiefe', t, access: 'TEXTBOX', formlabel: 'Tiefe (Seite, ohne Front)')
    haupt.set_attribute(L_DICT, L_GEBAUT, [a, bb, t])
    attribut(haupt, 'Hoehe', h, access: 'TEXTBOX', formlabel: 'Höhe')
    attribut(haupt, 'Anz_Einlegeboeden', n.to_f, laenge: false, access: 'LIST', formlabel: 'Anzahl Einlegeböden',
             units: 'INTEGER', options: '&0=0&1=1&2=2&')
    FEST.each_key { |k| attribut(haupt, k, p[k], units: 'STRING') }
    eb = (1..MAX_EB).map do |k|
      f = "IF(Anz_Einlegeboeden>=#{k},Materialstaerke_Korpus+(Hoehe-2*Materialstaerke_Korpus)*#{k}/" \
          "(Anz_Einlegeboeden+1)-Materialstaerke_Korpus/2,Materialstaerke_Korpus)"
      z = z_einlegeboden(p, k)
      attribut(haupt, "Z_Einlegeboden_#{k}", z, units: 'STRING', formula: f)
      z
    end

    e = haupt.entities
    hoehe_f = [nil, nil, "#{u}!Hoehe"]
    rueck_f = [nil, nil, "#{u}!Hoehe-#{u}!Materialstaerke_Korpus+#{u}!Nuttiefe"]
    tuer_f = [nil, nil, "#{u}!Hoehe-#{u}!Spaltbreite"]

    # Seiten an den Enden der Schenkel, volle Höhe und Tiefe
    einsetzen(e, platte(model, 'Seite', 'Seite', [mk, t, h], hoehe_f), 'SeiteR', [a - mk, mk, 0], [nil, nil, nil],
              mat: mat, kz: t_.('SeiteR'))
    einsetzen(e, platte(model, 'Seite Schenkel B', 'Seite', [t, mk, h], hoehe_f, art: 'SeiteB'), 'SeiteL',
              [0, yw - bb, 0], [nil, nil, nil], mat: mat, kz: t_.('SeiteL'))

    # L-Boden zwischen den Seiten über die volle Tiefe (Nut für die Rückwände oben)
    boden = l_platte(model, 'Boden L', 'Boden', *m[:boden], mk, *m[:ecke])
    einsetzen(e, boden, 'Boden', [0, ye, 0], [nil, nil, nil], mat: mat, kz: t_.('Boden'))

    # L-Deckel endet vor den Rückwänden und wird mit ihnen verschraubt
    deckel = l_platte(model, 'Deckel L', 'Deckel', *m[:deckel], mk, *m[:ecke_deckel])
    einsetzen(e, deckel, 'Deckel', [hi, ye, h - mk], [nil, nil, "#{u}!Hoehe-#{u}!Materialstaerke_Korpus"],
              mat: mat, kz: t_.('Deckel'))

    # Rückwände in der Nut von Seite und Boden, oben bündig; die von A geht durch die Ecke
    # (bis an die Rückseite von B), die von B stößt an ihre Vorderseite
    rwa = platte(model, 'Rückwand A', 'Rückwand', [a - mk + nut - v, rw, h - mk + nut], rueck_f)
    einsetzen(e, rwa, 'Rückwand1', [v, yw - hi, mk - nut], [nil, nil, nil], mat: mat, kz: t_.('Rueckwand1'))
    rwb = platte(model, 'Rückwand B', 'Rückwand', [rw, yw - hi - ye + nut, h - mk + nut], rueck_f)
    einsetzen(e, rwb, 'Rückwand2', [v, ye - nut, mk - nut], [nil, nil, nil], mat: mat, kz: t_.('Rueckwand2'))

    # L-Einlegeböden (vorne zurückgesetzt, hinten bis an die Rückwände), darunter je eine
    # Auflageleiste an der Rückwand A in der Ecke
    ll, lb = p['Leiste_Laenge'], p['Leiste_Breite']
    (1..MAX_EB).each do |k|
      d = l_platte(model, "Einlegeboden L #{k}", "Einlegeboden#{k}", *m[:deckel], mk, *m[:ecke_eb])
      sichtbarkeit(d, n >= k, "IF(#{u}!Anz_Einlegeboeden<#{k},1,0)")
      inst = einsetzen(e, d, "Einlegeboden#{k}", [hi, ye, eb[k - 1]], [nil, nil, "#{u}!Z_Einlegeboden_#{k}"],
                       mat: mat, kz: t_.("Einlegeboden#{k}"))
      inst.hidden = n < k
      l = platte(model, "Auflageleiste #{k}", "Auflageleiste#{k}", [ll, lb, mk], [nil, nil, nil], art: 'Leiste')
      sichtbarkeit(l, n >= k, "IF(#{u}!Anz_Einlegeboeden<#{k},1,0)")
      inst = einsetzen(e, l, "Auflageleiste#{k}", [hi, yw - hi - lb, eb[k - 1] - mk],
                       [nil, nil, "#{u}!Z_Einlegeboden_#{k}-#{u}!Materialstaerke_Korpus"],
                       mat: mat, kz: t_.("Auflageleiste#{k}"))
      inst.hidden = n < k
    end

    # Falttür: Tür A (TuerR) vor Schenkel A läuft durch die Ecke, Tür B (TuerL) vor
    # Schenkel B endet 1 mm vor der Front von A; verbunden mit einem Blum-Scharnier.
    # Oben und unten 1 mm Fuge, 2 mm vor dem Korpus.
    xa = t + sp
    einsetzen(e, platte(model, 'Tür A', 'Tür', [a - sp / 2.0 - xa, mk, h - sp], tuer_f), 'TürR',
              [xa, -sp, sp / 2.0], [nil, nil, nil], mat: mat, kz: t_.('TuerR'))
    yb0 = yw - bb + sp / 2.0
    einsetzen(e, platte(model, 'Tür B', 'Tür', [mk, -1.5 * sp - yb0, h - sp], tuer_f, art: 'TürB'), 'TürL',
              [xa, yb0, sp / 2.0], [nil, nil, nil], mat: mat, kz: t_.('TuerL'))
    haupt
  end

  # ---------------------------------------------------------------------------
  # Nach dem Ändern von Schenkel oder Tiefe neu aufbauen
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

  # Alle Eck-Oberschränke im Modell prüfen; geänderte Maße -> neu aufbauen
  def self.l_pruefen(model)
    model.definitions.to_a.select { |d| d.get_attribute(L_DICT, L_GEBAUT) }.each do |d|
      gebaut = d.get_attribute(L_DICT, L_GEBAUT)
      d.instances.to_a.each do |inst|
        neu = L_MASSE.map { |k| dc_cm(inst, k).round(2) }
        neu_aufbauen(model, inst, neu) unless neu.zip(gebaut).all? { |x, y| (x - y).abs < 0.01 }
      end
    end
  end

  def self.neu_aufbauen(model, inst, masse_neu)
    alt = inst.definition
    gebaut = alt.get_attribute(L_DICT, L_GEBAUT)
    p = DEFAULTS.merge(L_MASSE.zip(masse_neu).to_h)
    FEST.each_key { |k| p[k] = dc_cm(inst, k) unless dc_wert(inst, k).nil? }
    begin
      masse(p)
    rescue ArgumentError => e
      # ungültig: alte Maße zurück
      L_MASSE.zip(gebaut).each do |k, v|
        [inst, alt].each { |ent| ent.set_attribute(DICT, k.downcase, inch(v)) unless ent.get_attribute(DICT, k.downcase).nil? }
      end
      UI.messagebox("Eck-Oberschrank: #{e.message}. Die alten Maße bleiben.")
      return nil
    end
    p['Hoehe'] = dc_cm(inst, 'Hoehe')
    p['Anz_Einlegeboeden'] = dc_wert(inst, 'Anz_Einlegeboeden').to_f
    p['Kuerzel'] = alt.get_attribute(JT_DICT, 'schrank')
    # Frontmaterial und Griffe (Frontfarbe) der Teile merken
    vorher = alt.entities.grep(Sketchup::ComponentInstance).to_h do |c|
      [c.name, [c.material, c.attribute_dictionary(JT_DICT) && c.attribute_dictionary(JT_DICT).to_h]]
    end
    model.start_operation('Eck-Oberschrank ändern', true, false, true)
    neu = erzeuge(model, p)
    neu.entities.grep(Sketchup::ComponentInstance).each do |c|
      mat, jt = vorher[c.name]
      c.material = mat if mat
      jt.each { |k, v| c.set_attribute(JT_DICT, k, v) if k.start_with?('griff_') } if jt
    end
    inst.definition = neu
    L_MASSE.zip(masse_neu).each { |k, v| inst.set_attribute(DICT, k.downcase, inch(v)) unless inst.get_attribute(DICT, k.downcase).nil? }
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
    class Beobachter < Sketchup::ModelObserver
      def onTransactionCommit(model)
        return if @laeuft
        @laeuft = true
        UI.start_timer(0, false) do
          begin
            EckOberschrank.l_pruefen(model)
          ensure
            @laeuft = false
          end
        end
      end
    end

    class AppBeobachter < Sketchup::AppObserver
      def onNewModel(model)
        EckOberschrank.beobachten(model)
      end

      def onOpenModel(model)
        EckOberschrank.beobachten(model)
      end
    end
  end

  def self.beobachten(model)
    return unless model && defined?(Beobachter)
    @beobachter ||= Beobachter.new
    model.add_observer(@beobachter)
  end

  # ---------------------------------------------------------------------------
  # Erzeugen
  # ---------------------------------------------------------------------------
  # Neuer Schrank: Maße beim Anlegen abfragen. Danach bleiben sie im Fenster
  # Komponentenoptionen änderbar (Schenkel und Tiefe über den Neuaufbau).
  TIEFE_NEU = 35.0 # cm, Vorschlag im Dialog

  def self.dialog
    d = DEFAULTS
    Kuechenplaner::Eingabe.abfragen(['Schenkel A, hinten (mm)', 'Schenkel B, links (mm)', 'Höhe (mm)', 'Tiefe Korpus (mm)'],
                        [d['Schenkel_A'], d['Schenkel_B'], d['Hoehe'], TIEFE_NEU].map { |v| (v * 10).round.to_s },
                        'Eck-Oberschrank L-Form', untertitel: 'Neuer Schrank', ok: 'Einfügen') do |werte|
      a, b, h, t = werte.map { |v| Float(v.to_s.tr(',', '.')) / 10.0 }
      raise ArgumentError, 'Maße müssen größer als 0 sein' if [a, b, h, t].any? { |v| v <= 0 }
      erstellen({ 'Schenkel_A' => a, 'Schenkel_B' => b, 'Hoehe' => h, 'Tiefe' => t })
    end
  rescue ArgumentError => e
    UI.messagebox("Ungültige Eingabe: #{e.message}")
  end

  def self.erstellen(eingabe = {})
    model = Sketchup.active_model
    model.start_operation('Eck-Oberschrank', true)
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
module Kuechenplaner
  GRUPPEN = ['Unterschränke', 'Oberschränke', 'Hochschränke', 'Blenden & Wangen', 'Geräte', 'Raum'].freeze

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
  Kuechenplaner.schrank('Oberschränke', 'Eck-Oberschrank L-Form…') { EckOberschrank.dialog }
  if defined?(EckOberschrank::AppBeobachter)
    Sketchup.add_observer(EckOberschrank::AppBeobachter.new)
    EckOberschrank.beobachten(Sketchup.active_model)
  end
  file_loaded(__FILE__)
end
