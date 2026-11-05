# encoding: UTF-8
#
# Blenden und Wangen – erzeugt Dynamic Components für Passblenden, Wangen und Sockelblenden
#
# Erweiterung (.rbz): Erweiterungen > Küchenplaner > Blenden & Wangen > Passblende… / Wange… /
# Sockelblende…. Ist ein Schrank ausgewählt, übernehmen Passblende und Wange dessen Typ, Höhe,
# Tiefe, Sockelhöhe und Frontmaterial und werden links oder rechts direkt angesetzt. Die
# Sockelblende deckt alle Unter- und Hochschränke der Küche ab (mit Auswahl nur die gewählten):
# je Zeile eine Blende, an Innenecken stoßen sie aneinander, Wangen schließen die Zeile.
# Maße danach in den Komponentenoptionen ändern.
#
# Material, Kanten, Tags: Jede Platte hat ein Material (Passblende und Wange das Frontmaterial
# des Nachbarschranks, sonst "Melamin weiss"), sichtbare Kanten das Kantenmaterial
# "Anleimer Melamin weiss" (gezeichnet wird das Endmaß, den Abzug rechnet das Plugin
# Schrank-CNC). Jedes Teil hat einen eigenen Tag <Kürzel>_<Teil> (z. B. PB1_Blende, WG1_WangeL,
# SB1_Sockelblende2) und das Wörterbuch "JT_Schrank" für Stückliste, Etiketten, Zuschnitt und
# TCN-Export. Es gibt keine CNC-Bohrungen: Blenden und Wangen werden von innen verschraubt,
# die Sockelblende wird auf die Sockelfüße geclipst.

require 'sketchup.rb'
require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'eingabe') # Eingabefenster im Treppenplaner-Stil
require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'neuladen') # Neu laden ohne Neustart (Wächter)
require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'einstellungen') # Sockelhöhe und Abstände der Küche

module Blenden

  DICT     = 'dynamic_attributes'.freeze
  MATERIAL = 'Melamin weiss'.freeze
  KANTE    = 'Anleimer Melamin weiss'.freeze
  OCL_DICT = 'ladb_opencutlist'.freeze # Materialtyp (Platte/Kante), liest auch das Plugin Schrank-CNC

  # Tag-Schema für den TCN-Export (gleich in allen Komponenten, der Test prüft das):
  # Tag <Kürzel>_<Bereich>_<Teil>, dazu am Teil das Wörterbuch JT_Schrank.
  JT_DICT   = 'JT_Schrank'.freeze
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

  KATEGORIEN = %w[Unterschrank Oberschrank Hochschrank].freeze
  SOCKEL_KATEGORIE = 'Sockel'.freeze # Sockelblende: kein Schrank für Arbeitsplatte und Frontfarbe

  # Korpusmaße ohne Auswahl (cm), wie die Schränke
  HOEHE_STANDARD = { 'Unterschrank' => 70.0, 'Oberschrank' => 70.0, 'Hochschrank' => 210.0 }.freeze
  TIEFE_STANDARD = { 'Unterschrank' => 52.0, 'Oberschrank' => 40.0, 'Hochschrank' => 52.0 }.freeze

  # Je Befehl: Kürzel für die Tags, typ in JT_Schrank, DC-Name, Standardwerte (cm)
  ARTEN = {
    passblende: {
      kuerzel: 'PB', typ: 'Passblende', name: 'Passblende',
      defaults: { 'Breite' => 5.0, 'Hoehe' => 70.0, 'Winkelleiste' => 0.0, 'Staerke' => 1.9,
                  'Spaltbreite' => 0.2, 'Tiefe_Leiste' => 8.0 }
    },
    wange: {
      kuerzel: 'WG', typ: 'Wange', name: 'Wange',
      defaults: { 'Hoehe' => 70.0, 'Tiefe' => 80.0, 'Staerke' => 1.9, 'Sockelhoehe' => 10.0, 'Ueberstand' => 0.0,
                  'Materialstaerke_Korpus' => 1.9, 'Materialstarke_Rueckwand' => 0.8, 'Spaltbreite' => 0.2 }
    },
    sockelblende: {
      kuerzel: 'SB', typ: 'Sockelblende', name: 'Sockelblende',
      defaults: { 'Laenge' => 60.0, 'Sockelhoehe' => 10.0, 'Tiefe' => 80.0, 'Art_Seite' => 0.0, 'Staerke' => 1.6,
                  'Ruecksprung' => 5.0, 'Luft' => 0.3, 'Max_Laenge' => 280.0,
                  'Materialstaerke_Korpus' => 1.9, 'Materialstarke_Rueckwand' => 0.8 }
    }
  }.freeze
  MAX_STUECKE = 5 # Sockelblende: höchstens 5 Stücke à 2800 mm

  # Sichtbare Kanten je Teil (bekommen das Kantenmaterial).
  # ymin = vorne, zmin/zmax = unten/oben, xmin/xmax = links/rechts.
  KANTEN = {
    'Blende'       => %i[xmin xmax zmin zmax], # rundum wie eine Front
    'Winkelleiste' => %i[ymin],                # nur die Kante hinter der Blende
    'Wange'        => %i[ymin zmax],           # vorne und oben; unten Boden, hinten Wand
    'WangeOber'    => %i[ymin zmin zmax],      # Oberschrank: auch unten sichtbar
    'Sockelblende' => %i[zmax],                # oben; unten Luft zum Boden
    'SockelSeite'  => %i[ymin zmax]            # Stirnseite vorne und oben
  }.freeze

  DOKU_URL = 'https://github.com/jimmycd/sketchup_kuechenplaner2/tree/main/Komponenten/blenden'.freeze
  HILFE_KURZ = {
    passblende: 'Passblende in Frontmaterial für Restmaße, optional mit Winkelleiste',
    wange: 'Seitenwange am Zeilenende, bündig mit der Front, bis zum Boden',
    sockelblende: 'Sockelblende unter allen Unter- und Hochschränken, je Zeile, geteilt ab 2800 mm'
  }.freeze

  # ---------------------------------------------------------------------------
  # Reine Berechnung (ohne SketchUp), spiegelt die DC-Formeln. Werte in cm,
  # Quader [x0, x1, y0, y1, z0, z1] im Koordinatensystem der Komponente:
  # Ursprung = Schrankkante (Passblende, Wange) bzw. linke Außenkante der Zeile
  # (Sockelblende), auf Höhe der Korpusunterkante; y = 0 an der Fronthinterkante
  # wie bei den Schränken (Front liegt bei -Spalt … Korpusvorderkante bei 19 mm).
  # ---------------------------------------------------------------------------
  def self.links?(p)
    p['Seite'].to_s == 'links'
  end

  def self.passblende_masse(p)
    b, st, sp = p['Breite'], p['Staerke'], p['Spaltbreite']
    x0 = links?(p) ? -b : 0.0
    lx = links?(p) ? -st : 0.0
    { 'Blende' => [x0, x0 + b, -sp, -sp + st, 0.0, p['Hoehe']],
      'Winkelleiste' => p['Winkelleiste'].to_i == 1 ? [lx, lx + st, st - sp, st - sp + p['Tiefe_Leiste'], 0.0, p['Hoehe']] : nil }
  end

  def self.wange_masse(p)
    st = p['Staerke']
    x0 = links?(p) ? -st : 0.0
    y0 = -p['Spaltbreite'] - p['Ueberstand']
    y1 = p['Materialstaerke_Korpus'] + p['Tiefe'] + p['Materialstarke_Rueckwand']
    { (links?(p) ? 'WangeL' : 'WangeR') => [x0, x0 + st, y0, y1, -p['Sockelhoehe'], p['Hoehe']] }
  end

  def self.sockel_seiten(p)
    a = p['Art_Seite'].to_i
    [[1, 3].include?(a), [2, 3].include?(a)]
  end

  def self.sockel_stuecke(p)
    l, r = sockel_seiten(p)
    eff = p['Laenge'] - p['Staerke'] * ((l ? 1 : 0) + (r ? 1 : 0))
    [(eff / p['Max_Laenge'] - 1e-9).ceil, eff]
  end

  def self.sockelblende_masse(p)
    st = p['Staerke']
    l, r = sockel_seiten(p)
    n, eff = sockel_stuecke(p)
    y0 = p['Materialstaerke_Korpus'] + p['Ruecksprung']
    z0 = -p['Sockelhoehe'] + p['Luft']
    x = l ? st : 0.0
    m = {}
    n.times { |i| m["Sockelblende#{i + 1}"] = [x + i * eff / n, x + (i + 1) * eff / n, y0, y0 + st, z0, 0.0] }
    y1 = p['Materialstaerke_Korpus'] + p['Tiefe'] + p['Materialstarke_Rueckwand']
    m['SockelSeiteL'] = [0.0, st, y0, y1, z0, 0.0] if l
    m['SockelSeiteR'] = [p['Laenge'] - st, p['Laenge'], y0, y1, z0, 0.0] if r
    m
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
  def self.hilfe(d, art)
    kurz = HILFE_KURZ.fetch(art)
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

  # Materialtyp und Maße im Wörterbuch "ladb_opencutlist" am Material (Typ 2 = Platte,
  # 4 = Kante). Bereits eingestellte Materialien werden nicht verändert.
  def self.typ_material(model, name, farbe, attribute)
    m = model.materials[name] || model.materials.add(name)
    m.color = Sketchup::Color.new(*farbe) unless m.texture || m.get_attribute(OCL_DICT, 'type')
    if m.get_attribute(OCL_DICT, 'type').to_i == 0
      attribute.each { |k, v| m.set_attribute(OCL_DICT, k, v) }
    end
    m
  end

  def self.material(model)
    typ_material(model, MATERIAL, [255, 255, 255],
                 'type' => 2, 'std_thicknesses' => '8mm;16mm;19mm', 'std_sizes' => '2800mm x 2070mm',
                 'grained' => false)
  end

  def self.kanten_material(model)
    typ_material(model, KANTE, [245, 245, 240],
                 'type' => 4, 'thickness' => '2mm', 'std_widths' => '23mm', 'std_lengths' => '75m',
                 'edge_decremented' => true)
  end

  # Freies Kürzel für die Tags, z. B. PB1, PB2 …
  def self.freies_kuerzel(model, praefix)
    n = 1
    n += 1 while model.layers.to_a.any? { |l| l.name.start_with?("#{praefix}#{n}_") }
    "#{praefix}#{n}"
  end

  # Tag <Kürzel>_<Teil> und JT_Schrank am Teil
  def self.kennzeichnen(model, inst, kz, teil, typ, kategorie)
    inst.layer = model.layers["#{kz}_#{teil}"] || model.layers.add("#{kz}_#{teil}")
    { 'schrank' => kz, 'typ' => typ, 'kategorie' => kategorie, 'bereich' => '',
      'teil' => teil, 'rolle' => ROLLEN.fetch(teil.sub(/\d+\z/, '')) }.each { |k, v| inst.set_attribute(JT_DICT, k, v) }
    inst
  end

  SEITEN = { xmin: [0, -1], xmax: [0, 1], ymin: [1, -1], ymax: [1, 1], zmin: [2, -1], zmax: [2, 1] }.freeze

  # Quader in Endmaß zeichnen; die in "kanten" genannten Flächen bekommen das Kantenmaterial
  def self.quader(ents, lx, ly, lz, kanten, kante)
    f = ents.add_face([0, 0, 0], [inch(lx), 0, 0], [inch(lx), inch(ly), 0], [0, inch(ly), 0])
    f.reverse! if f.normal.z < 0
    f.pushpull(inch(lz))
    return if kanten.empty?
    ents.grep(Sketchup::Face).each do |face|
      n = face.normal.to_a
      seite = SEITEN.find { |_, (ax, vz)| n[ax] * vz > 0.5 }
      face.material = kante if seite && kanten.include?(seite.first)
    end
  end

  # q = Quader [x0, x1, y0, y1, z0, z1]; formeln = [x, y, z, lenx, leny, lenz] (nil = fest)
  def self.teil(model, eltern, ctx, teil, art, q, formeln, sichtbar: true, hidden_formel: nil)
    groesse = [q[1] - q[0], q[3] - q[2], q[5] - q[4]]
    d = model.definitions.add("#{ctx[:typ]} #{teil}")
    quader(d.entities, *groesse, KANTEN.fetch(art), ctx[:kante])
    stempel(d)
    d.set_attribute(DICT, '_name', teil)
    %w[x y z].each_with_index do |ax, i|
      d.set_attribute(DICT, "len#{ax}", inch(groesse[i]))
      next unless formeln[3 + i]
      d.set_attribute(DICT, "_len#{ax}_formula", formeln[3 + i])
      d.set_attribute(DICT, "_len#{ax}_label", "Len#{ax.upcase}")
    end
    sichtbarkeit(d, sichtbar, hidden_formel) if hidden_formel

    tr = Geom::Transformation.translation(Geom::Vector3d.new(inch(q[0]), inch(q[2]), inch(q[4])))
    inst = eltern.entities.add_instance(d, tr)
    inst.name = teil
    inst.material = ctx[:mat]
    inst.set_attribute(DICT, 'material', ctx[:mat].name) if ctx[:front]
    kennzeichnen(model, inst, ctx[:kz], teil, ctx[:typ], ctx[:kategorie])
    inst.set_attribute(JT_DICT, 'frontfarbe', true) if ctx[:front] # Frontfarbe färbt mit um
    inst.hidden = !sichtbar
    inst.set_attribute(DICT, '_has_movetool_behaviors', 1.0)
    inst.set_attribute(DICT, '_hasbehaviors', 1.0)
    inst.set_attribute(DICT, '_iscollapsed', false)
    inst.set_attribute(DICT, '_lengthunits', 'CENTIMETERS')
    inst.set_attribute(DICT, '_name', teil)
    %w[x y z].each_with_index do |ax, i|
      next unless formeln[i]
      inst.set_attribute(DICT, ax, inch(q[2 * i]))
      inst.set_attribute(DICT, "_#{ax}_formula", formeln[i])
      inst.set_attribute(DICT, "_#{ax}_label", ax.upcase)
    end
    inst
  end

  # Hauptdefinition mit Hilfe und JT_Schrank
  def self.haupt(model, art, ctx, extra = {})
    a = ARTEN.fetch(art)
    d = model.definitions.add(a[:name])
    stempel(d)
    d.set_attribute(DICT, '_name', a[:name])
    hilfe(d, art)
    { 'schrank' => ctx[:kz], 'typ' => a[:typ], 'kategorie' => ctx[:kategorie] }.merge(extra)
                                                                              .each { |k, v| d.set_attribute(JT_DICT, k, v) }
    d
  end

  def self.kontext(model, art, p, kategorie, front_mat)
    a = ARTEN.fetch(art)
    mat = material(model)
    kante = kanten_material(model)
    mat, kante = front_mat if front_mat && front_mat[0]
    { kz: p['Kuerzel'] || freies_kuerzel(model, a[:kuerzel]), typ: a[:typ], kategorie: kategorie,
      mat: mat, kante: kante || kanten_material(model), front: art != :sockelblende }
  end

  # Sockelhöhe der Küche (Küchenplaner › Einstellungen, Standard 100 mm) in cm
  def self.sockel_standard(model)
    return 10.0 unless defined?(Kuechenplaner::Einstellungen)
    Kuechenplaner::Einstellungen.sockelhoehe(model) / 10.0
  end

  def self.kategorie_von(p)
    k = p['Kategorie'].to_s
    KATEGORIEN.include?(k) ? k : 'Unterschrank'
  end

  # ---------------------------------------------------------------------------
  # Aufbau
  # ---------------------------------------------------------------------------
  def self.erzeuge_passblende(model, eingabe = {}, front_mat = nil)
    p = ARTEN[:passblende][:defaults].merge(eingabe)
    kat = kategorie_von(p)
    ctx = kontext(model, :passblende, p, kat, front_mat)
    u = 'Passblende'
    d = haupt(model, :passblende, ctx, 'seite' => links?(p) ? 'links' : 'rechts')
    attribut(d, 'Breite', p['Breite'], access: 'TEXTBOX', formlabel: 'Breite')
    attribut(d, 'Hoehe', p['Hoehe'], access: 'TEXTBOX', formlabel: 'Höhe (wie Korpus)')
    attribut(d, 'Winkelleiste', p['Winkelleiste'], laenge: false, access: 'LIST', formlabel: 'Winkelleiste',
             units: 'INTEGER', options: '&Nein=0&Ja=1&')
    %w[Staerke Spaltbreite Tiefe_Leiste].each { |n| attribut(d, n, p[n], units: 'STRING') }

    m = passblende_masse(p)
    l = links?(p)
    teil(model, d, ctx, 'Blende', 'Blende', m['Blende'],
         [l ? "-#{u}!Breite" : nil, "-#{u}!Spaltbreite", nil, "#{u}!Breite", "#{u}!Staerke", "#{u}!Hoehe"])
    st, sp = p['Staerke'], p['Spaltbreite']
    q = m['Winkelleiste'] || [l ? -st : 0.0, l ? 0.0 : st, st - sp, st - sp + p['Tiefe_Leiste'], 0.0, p['Hoehe']]
    leiste_ctx = ctx.merge(mat: material(model), kante: kanten_material(model), front: false)
    teil(model, d, leiste_ctx, 'Winkelleiste', 'Winkelleiste', q,
         [l ? "-#{u}!Staerke" : nil, "#{u}!Staerke-#{u}!Spaltbreite", nil, "#{u}!Staerke", "#{u}!Tiefe_Leiste", "#{u}!Hoehe"],
         sichtbar: !m['Winkelleiste'].nil?, hidden_formel: "IF(#{u}!Winkelleiste=1,0,1)")
    d
  end

  def self.erzeuge_wange(model, eingabe = {}, front_mat = nil)
    p = ARTEN[:wange][:defaults].merge('Sockelhoehe' => sockel_standard(model)).merge(eingabe)
    kat = kategorie_von(p)
    p = p.merge('Sockelhoehe' => 0.0) if kat == 'Oberschrank'
    ctx = kontext(model, :wange, p, kat, front_mat)
    u = 'Wange'
    extra = { 'seite' => links?(p) ? 'links' : 'rechts' }
    extra['sockel_unter_korpus'] = true unless kat == 'Oberschrank' # Andocken: Unterkante = Korpus
    d = haupt(model, :wange, ctx, extra)
    attribut(d, 'Hoehe', p['Hoehe'], access: 'TEXTBOX', formlabel: 'Höhe Korpus')
    attribut(d, 'Tiefe', p['Tiefe'], access: 'TEXTBOX', formlabel: 'Tiefe Korpus (ohne Front)')
    attribut(d, 'Staerke', p['Staerke'], access: 'LIST', formlabel: 'Stärke',
             options: '&19%20mm=1.9&25%20mm=2.5&38%20mm=3.8&')
    if kat == 'Oberschrank'
      attribut(d, 'Sockelhoehe', 0.0, units: 'STRING')
    else
      attribut(d, 'Sockelhoehe', p['Sockelhoehe'], access: 'TEXTBOX', formlabel: 'Sockelhöhe (Wange bis Boden)')
    end
    attribut(d, 'Ueberstand', p['Ueberstand'], access: 'TEXTBOX', formlabel: 'Überstand vor der Front')
    %w[Materialstaerke_Korpus Materialstarke_Rueckwand Spaltbreite].each { |n| attribut(d, n, p[n], units: 'STRING') }

    name, q = wange_masse(p).first
    teil(model, d, ctx, name, kat == 'Oberschrank' ? 'WangeOber' : 'Wange', q,
         [links?(p) ? "-#{u}!Staerke" : nil, "-#{u}!Spaltbreite-#{u}!Ueberstand", "-#{u}!Sockelhoehe",
          "#{u}!Staerke",
          "#{u}!Ueberstand+#{u}!Spaltbreite+#{u}!Materialstaerke_Korpus+#{u}!Tiefe+#{u}!Materialstarke_Rueckwand",
          "#{u}!Hoehe+#{u}!Sockelhoehe"])
    d
  end

  def self.erzeuge_sockelblende(model, eingabe = {})
    p = ARTEN[:sockelblende][:defaults].merge('Sockelhoehe' => sockel_standard(model)).merge(eingabe)
    ctx = kontext(model, :sockelblende, p, SOCKEL_KATEGORIE, nil)
    u = 'Sockelblende'
    d = haupt(model, :sockelblende, ctx)
    attribut(d, 'Laenge', p['Laenge'], access: 'TEXTBOX', formlabel: 'Länge (gesamt)')
    attribut(d, 'Sockelhoehe', p['Sockelhoehe'], access: 'TEXTBOX', formlabel: 'Sockelhöhe')
    attribut(d, 'Tiefe', p['Tiefe'], access: 'TEXTBOX', formlabel: 'Tiefe Korpus (für Seitenstücke)')
    attribut(d, 'Art_Seite', p['Art_Seite'], laenge: false, access: 'LIST', formlabel: 'Seitenstücke',
             units: 'INTEGER', options: '&Keine=0&Links=1&Rechts=2&Beide=3&')
    attribut(d, 'Staerke', p['Staerke'], access: 'LIST', formlabel: 'Stärke', options: '&16%20mm=1.6&19%20mm=1.9&')
    attribut(d, 'Ruecksprung', p['Ruecksprung'], access: 'TEXTBOX', formlabel: 'Rücksprung hinter Korpusvorderkante')
    %w[Luft Max_Laenge Materialstaerke_Korpus Materialstarke_Rueckwand].each { |n| attribut(d, n, p[n], units: 'STRING') }

    li = ->(pre) { "IF(OR(#{pre}Art_Seite=1,#{pre}Art_Seite=3),1,0)" }
    re = ->(pre) { "IF(OR(#{pre}Art_Seite=2,#{pre}Art_Seite=3),1,0)" }
    eff = ->(pre) { "(#{pre}Laenge-#{pre}Staerke*(#{li.(pre)}+#{re.(pre)}))" }
    n, = sockel_stuecke(p)
    attribut(d, 'N', n.to_f, laenge: false, units: 'STRING', formula: "CEILING(#{eff.('')}/Max_Laenge,1)")

    m = sockelblende_masse(p)
    y0 = "#{u}!Materialstaerke_Korpus+#{u}!Ruecksprung"
    z0 = "-#{u}!Sockelhoehe+#{u}!Luft"
    hz = "#{u}!Sockelhoehe-#{u}!Luft"
    l_st = "#{eff.("#{u}!")}/#{u}!N"
    q0 = m['Sockelblende1']
    MAX_STUECKE.times do |i|
      name = "Sockelblende#{i + 1}"
      # ausgeblendete Stücke liegen auf dem ersten, damit sie nicht über die Komponente hinausragen
      q = m[name] || q0
      teil(model, d, ctx, name, 'Sockelblende', q,
           ["#{u}!Staerke*#{li.("#{u}!")}+IF(#{u}!N>=#{i + 1},#{i},0)*#{l_st}", y0, z0, l_st, "#{u}!Staerke", hz],
           sichtbar: !m[name].nil?, hidden_formel: "IF(#{u}!N>=#{i + 1},0,1)")
    end
    l, r = sockel_seiten(p)
    tiefe = "#{u}!Tiefe+#{u}!Materialstarke_Rueckwand-#{u}!Ruecksprung"
    st = p['Staerke']
    y = p['Materialstaerke_Korpus'] + p['Ruecksprung']
    y1 = p['Materialstaerke_Korpus'] + p['Tiefe'] + p['Materialstarke_Rueckwand']
    teil(model, d, ctx, 'SockelSeiteL', 'SockelSeite', m['SockelSeiteL'] || [0.0, st, y, y1, q0[4], 0.0],
         [nil, y0, z0, "#{u}!Staerke", tiefe, hz], sichtbar: l, hidden_formel: "IF(#{li.("#{u}!")}=1,0,1)")
    teil(model, d, ctx, 'SockelSeiteR', 'SockelSeite', m['SockelSeiteR'] || [p['Laenge'] - st, p['Laenge'], y, y1, q0[4], 0.0],
         ["#{u}!Laenge-#{u}!Staerke", y0, z0, "#{u}!Staerke", tiefe, hz], sichtbar: r,
         hidden_formel: "IF(#{re.("#{u}!")}=1,0,1)")
    d
  end

  # ---------------------------------------------------------------------------
  # Nachbarschränke (Auswahl)
  # ---------------------------------------------------------------------------
  def self.definition(inst)
    inst.respond_to?(:definition) ? inst.definition : inst.entities.parent
  end

  def self.kategorie(inst)
    definition(inst).get_attribute(JT_DICT, 'kategorie')
  end

  # DC-Länge in cm: zuerst an der Instanz (Komponentenoptionen), dann an der Definition
  def self.dc_cm(inst, k)
    v = inst.get_attribute(DICT, k)
    v = definition(inst).get_attribute(DICT, k) if v.nil?
    v.nil? ? nil : v.to_f * 2.54
  end

  # Schränke in der Auswahl (Unter-, Ober-, Hochschränke, auch Wangen und Passblenden)
  def self.schraenke(model)
    model.selection.to_a.select do |e|
      (e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)) &&
        definition(e).get_attribute(JT_DICT, 'schrank') && KATEGORIEN.include?(kategorie(e))
    end
  end

  # x-Bereich der sichtbaren Teile in Schrankkoordinaten (Zoll)
  def self.x_bereich(inst)
    d = definition(inst)
    bb = Geom::BoundingBox.new
    d.entities.each { |e| bb.add(e.bounds) if e.respond_to?(:bounds) && !(e.respond_to?(:hidden?) && e.hidden?) }
    bb = d.bounds if bb.empty?
    [bb.min.x.to_f, bb.max.x.to_f]
  end

  # Material und Kantenmaterial der ersten Front oder Tür im Schrank
  def self.front_material(inst)
    definition(inst).entities.each do |e|
      next unless e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)
      if %w[Front Tuer].include?(e.get_attribute(JT_DICT, 'rolle')) && e.material
        kante = definition(e).entities.grep(Sketchup::Face).map(&:material)
                             .find { |m| m && m.get_attribute(OCL_DICT, 'type').to_i == 4 }
        return [e.material, kante]
      end
      r = front_material(e)
      return r if r
    end
    nil
  end

  # Vorschläge für den Dialog aus dem gewählten Schrank (cm)
  def self.vorschlag(nachbar)
    return {} unless nachbar
    { 'Kategorie' => kategorie(nachbar), 'Hoehe' => dc_cm(nachbar, 'hoehe'), 'Tiefe' => dc_cm(nachbar, 'tiefe'),
      'Sockelhoehe' => dc_cm(nachbar, 'sockelhoehe') }.reject { |_, v| v.nil? }
  end

  # ---------------------------------------------------------------------------
  # Erzeugen
  # ---------------------------------------------------------------------------
  def self.einfuegen(model, defn, name, nachbar, x_zoll)
    tr = if nachbar
           nachbar.transformation * Geom::Transformation.translation(Geom::Vector3d.new(x_zoll, 0, 0))
         else
           x = model.entities.length > 0 ? model.bounds.max.x + 10.cm : 0
           Geom::Transformation.translation([x, 0, 0])
         end
    inst = model.entities.add_instance(defn, tr)
    inst.name = name
    inst.set_attribute(DICT, '_name', name)
    inst
  end

  def self.fertig(model, inst, andocken)
    model.commit_operation
    if defined?($dc_observers) && $dc_observers
      $dc_observers.get_latest_class.redraw_with_undo(inst)
    end
    # Andock-Werkzeug (Schrank-CNC): ohne gewählten Nachbarn an Schrank oder Wand setzen
    if andocken
      Kuechenplaner.neuer_schrank(inst) if Kuechenplaner.respond_to?(:neuer_schrank)
    end
    model.selection.clear
    model.selection.add(inst)
    inst
  end

  # Passblende oder Wange: nachbar = gewählter Schrank (links oder rechts angesetzt) oder nil
  def self.erstellen(art, eingabe = {}, nachbar = nil)
    model = Sketchup.active_model
    model.start_operation(ARTEN.fetch(art)[:name], true)
    front = nachbar && front_material(nachbar)
    defn = art == :wange ? erzeuge_wange(model, eingabe, front) : erzeuge_passblende(model, eingabe, front)
    x = nachbar ? x_bereich(nachbar)[links?(eingabe) ? 0 : 1] : 0
    inst = einfuegen(model, defn, ARTEN[art][:name], nachbar, x)
    fertig(model, inst, nachbar.nil?)
  rescue StandardError => e
    model.abort_operation
    UI.messagebox("Fehler beim Erzeugen: #{e.message}")
    raise
  end

  # ---------------------------------------------------------------------------
  # Sockelblende für die ganze Küche: Unter- und Hochschränke (und Passblenden)
  # in Zeilen gleicher Flucht sammeln, Lücken trennen die Zeilen, an Innenecken
  # stoßen die Blenden zweier Zeilen stumpf aneinander. Rechnen in Zoll.
  # ---------------------------------------------------------------------------
  FLUCHT_TOL = 2.0 / 2.54   # Versatz der Front, der noch als gleiche Zeile zählt
  LUECKE     = 2.0 / 2.54   # größere Lücke zwischen Schränken = neue Zeile
  ECKE_TOL   = 70.0 / 2.54  # so nah muss das Zeilenende an der Blende der Querzeile liegen

  def self.punkt(tr, x, y)
    tr * Geom::Point3d.new(x, y, 0)
  end

  # Punkt (x, y) aus dem Koordinatensystem der Instanz a in das von b (b_inv = Inverse)
  def self.umrechnen(a_tr, b_inv, x, y)
    b_inv * punkt(a_tr, x, y)
  end

  def self.eigener_typ?(e)
    ARTEN.values.map { |a| a[:typ] }.include?(definition(e).get_attribute(JT_DICT, 'typ'))
  end

  # Was unter der Sockelblende steht: Unter- und Hochschränke und Passblenden.
  # Wangen nicht, sie reichen bis zum Boden und schließen die Zeile seitlich.
  def self.sockel_teile(liste)
    liste.select do |e|
      (e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)) &&
        definition(e).get_attribute(JT_DICT, 'schrank') && %w[Unterschrank Hochschrank].include?(kategorie(e)) &&
        definition(e).get_attribute(JT_DICT, 'typ') != 'Wange'
    end
  end

  def self.gleiche_flucht?(ref, e)
    a = ref.transformation.xaxis.to_a
    b = e.transformation.xaxis.to_a
    return false if a.zip(b).sum { |u, v| u * v } < 0.999
    o = ref.transformation.inverse * e.transformation.origin
    o.y.abs < FLUCHT_TOL && o.z.abs < FLUCHT_TOL
  end

  # Zeilen [{ref:, x0:, x1: (Zoll, in ref-Koordinaten), tiefe:, sockel: (cm)}]
  def self.zeilen(teile)
    gruppen = []
    teile.each do |e|
      g = gruppen.find { |z| gleiche_flucht?(z[:ref], e) }
      g ? g[:teile] << e : gruppen << { ref: e, teile: [e] }
    end
    gruppen.flat_map do |g|
      inv = g[:ref].transformation.inverse
      bereiche = g[:teile].map do |e|
        o = inv * e.transformation.origin
        x0, x1 = x_bereich(e)
        [o.x + x0, o.x + x1, e]
      end.sort_by(&:first)
      stuecke = []
      bereiche.each do |b|
        if stuecke.last && b[0] <= stuecke.last[:x1] + LUECKE
          stuecke.last[:x1] = [stuecke.last[:x1], b[1]].max
          stuecke.last[:teile] << b[2]
        else
          stuecke << { x0: b[0], x1: b[1], teile: [b[2]] }
        end
      end
      stuecke.map do |s|
        korpus = s[:teile].reject { |e| eigener_typ?(e) }
        { ref: g[:ref], x0: s[:x0], x1: s[:x1], tiefe: korpus.map { |e| dc_cm(e, 'tiefe') }.compact.max,
          sockel: korpus.map { |e| dc_cm(e, 'sockelhoehe') }.compact.first }
      end
    end
  end

  # Innenecken: Die Zeile, die hinter die Blende der Querzeile läuft, endet an deren
  # Rückseite, die andere wird bis an ihre Vorderseite verlängert. So schließen die
  # Blenden die Ecke ohne Lücke und ohne Überlappung.
  def self.ecken(zeilen, p)
    y_vorn = inch(p['Materialstaerke_Korpus'] + p['Ruecksprung'])
    st = inch(p['Staerke'])
    neu = zeilen.map { |z| [z[:x0], z[:x1]] }
    zeilen.each_with_index do |r, i|
      rt = r[:ref].transformation
      ri = rt.inverse
      zeilen.each do |q|
        next if q.equal?(r)
        qt = q[:ref].transformation
        a = umrechnen(qt, ri, 0, 0)
        b = umrechnen(qt, ri, 1, 0)
        next unless (b.x - a.x).abs < 0.01 # nur rechtwinklige Zeilen
        cf = umrechnen(qt, ri, q[:x0], y_vorn).x
        cb = umrechnen(qt, ri, q[:x0], y_vorn + st).x
        mitte = (cf + cb) / 2
        vorn = umrechnen(qt, ri, 0, -1).x - a.x # Blickrichtung der Querzeile in r
        linie = umrechnen(rt, qt.inverse, mitte, y_vorn + st / 2) # Blendenlinie von r bei der Querzeile
        next unless linie.x.between?(q[:x0] - ECKE_TOL, q[:x1] + ECKE_TOL)
        lo, hi = [cf, cb].minmax
        if vorn > 0.5 && (r[:x0] - mitte).abs < ECKE_TOL
          neu[i][0] = r[:x0] < mitte ? lo : hi
        elsif vorn < -0.5 && (r[:x1] - mitte).abs < ECKE_TOL
          neu[i][1] = r[:x1] > mitte ? hi : lo
        end
      end
    end
    zeilen.each_with_index.map { |z, i| z.merge(x0: neu[i][0], x1: neu[i][1], laenge: (neu[i][1] - neu[i][0]) * 2.54) }
  end

  # Sockelblende unter den gewählten Unter- und Hochschränken, ohne Auswahl unter allen
  def self.kueche(model)
    gewaehlt = sockel_teile(model.selection.to_a)
    teile = gewaehlt.empty? ? sockel_teile(model.entities.to_a) : gewaehlt
    { teile: teile, auswahl: !gewaehlt.empty?, alte: model.entities.to_a.select { |e| sockelblende?(e) } }
  end

  def self.sockelblende?(e)
    (e.is_a?(Sketchup::ComponentInstance) || e.is_a?(Sketchup::Group)) &&
      definition(e).get_attribute(JT_DICT, 'typ') == ARTEN[:sockelblende][:typ]
  end

  # Erste Zeile (für Aufrufer, die nur eine Zeile brauchen)
  def self.zeile(model)
    z = zeilen(sockel_teile(model.selection.to_a)).first
    z && z.merge(laenge: (z[:x1] - z[:x0]) * 2.54)
  end

  def self.erstellen_sockelblende(eingabe = {}, z = nil)
    model = Sketchup.active_model
    model.start_operation('Sockelblende', true)
    defn = erzeuge_sockelblende(model, eingabe)
    inst = einfuegen(model, defn, 'Sockelblende', z && z[:ref], z ? z[:x0] : 0)
    fertig(model, inst, false)
  rescue StandardError => e
    model.abort_operation
    UI.messagebox("Fehler beim Erzeugen: #{e.message}")
    raise
  end

  # Je Zeile eine Sockelblende (über 14 m in mehrere geteilt); alte Sockelblenden ersetzen
  def self.erstellen_sockelblenden(eingabe, zeilen, alte = [])
    model = Sketchup.active_model
    model.start_operation('Sockelblenden', true)
    model.entities.erase_entities(alte) unless alte.empty?
    max = ARTEN[:sockelblende][:defaults]['Max_Laenge'] * MAX_STUECKE
    neu = zeilen.flat_map do |z|
      n = (z[:laenge] / max - 1e-9).ceil
      Array.new(n) do |k|
        l = z[:laenge] / n
        defn = erzeuge_sockelblende(model, eingabe.merge('Laenge' => l, 'Tiefe' => z[:tiefe] || TIEFE_STANDARD['Unterschrank']))
        einfuegen(model, defn, 'Sockelblende', z[:ref], z[:x0] + inch(k * l))
      end
    end
    model.commit_operation
    if defined?($dc_observers) && $dc_observers
      neu.each { |inst| $dc_observers.get_latest_class.redraw_with_undo(inst) }
    end
    model.selection.clear
    neu.each { |inst| model.selection.add(inst) }
    neu
  rescue StandardError => e
    model.abort_operation
    UI.messagebox("Fehler beim Erzeugen: #{e.message}")
    raise
  end

  # ---------------------------------------------------------------------------
  # Dialoge
  # ---------------------------------------------------------------------------
  def self.mm(cm)
    cm.nil? ? '' : (cm * 10).round(1).to_s.sub(/\.0\z/, '')
  end

  def self.zahl(s)
    t = s.to_s.strip.tr(',', '.')
    t.empty? ? nil : t.to_f / 10.0
  end

  def self.einzelner_nachbar(model)
    s = schraenke(model)
    s.size == 1 ? s.first : nil
  end

  def self.dialog_passblende
    model = Sketchup.active_model
    n = einzelner_nachbar(model)
    v = vorschlag(n)
    Kuechenplaner::Eingabe.abfragen(['Schranktyp', 'Seite am Schrank', 'Breite (mm)', 'Höhe (mm, leer = wie Schrank)', 'Winkelleiste'],
                                    [v['Kategorie'] || 'Unterschrank', 'rechts', '50', mm(v['Hoehe']), 'nein'],
                                    [KATEGORIEN.join('|'), 'rechts|links', '', '', 'nein|ja'], 'Passblende',
                                    untertitel: n ? 'Neue Passblende am gewählten Schrank' : 'Neue Passblende', ok: 'Einfügen') do |res|
      kat = res[0]
      eingabe = { 'Kategorie' => kat, 'Seite' => res[1], 'Breite' => zahl(res[2]),
                  'Hoehe' => zahl(res[3]) || v['Hoehe'] || HOEHE_STANDARD[kat], 'Winkelleiste' => res[4] == 'ja' ? 1.0 : 0.0 }
      raise ArgumentError, 'Breite 10 bis 300 mm' unless eingabe['Breite'] && eingabe['Breite'].between?(1.0, 30.0)
      raise ArgumentError, 'Höhe muss größer als 0 sein' unless eingabe['Hoehe'] > 0
      erstellen(:passblende, eingabe, n)
    end
  rescue ArgumentError => e
    UI.messagebox("Ungültige Eingabe: #{e.message}")
  end

  def self.dialog_wange
    model = Sketchup.active_model
    n = einzelner_nachbar(model)
    v = vorschlag(n)
    Kuechenplaner::Eingabe.abfragen(['Schranktyp', 'Seite am Schrank', 'Stärke (mm)', 'Höhe Korpus (mm, leer = wie Schrank)',
                                     'Tiefe Korpus (mm, leer = wie Schrank)', 'Sockelhöhe (mm)', 'Überstand vorne (mm)'],
                                    [v['Kategorie'] || 'Unterschrank', 'rechts', '19', mm(v['Hoehe']), mm(v['Tiefe']),
                                     mm(v['Sockelhoehe'] || sockel_standard(model)), '0'],
                                    [KATEGORIEN.join('|'), 'rechts|links', '19|25|38', '', '', '', ''], 'Wange',
                                    untertitel: n ? 'Neue Wange am gewählten Schrank' : 'Neue Wange', ok: 'Einfügen') do |res|
      kat = res[0]
      eingabe = { 'Kategorie' => kat, 'Seite' => res[1], 'Staerke' => zahl(res[2]),
                  'Hoehe' => zahl(res[3]) || v['Hoehe'] || HOEHE_STANDARD[kat],
                  'Tiefe' => zahl(res[4]) || v['Tiefe'] || TIEFE_STANDARD[kat],
                  'Sockelhoehe' => zahl(res[5]) || 0.0, 'Ueberstand' => zahl(res[6]) || 0.0 }
      raise ArgumentError, 'Höhe und Tiefe müssen größer als 0 sein' unless eingabe['Hoehe'] > 0 && eingabe['Tiefe'] > 0
      raise ArgumentError, 'Sockelhöhe 0 bis 300 mm' unless eingabe['Sockelhoehe'].between?(0, 30)
      raise ArgumentError, 'Überstand 0 bis 50 mm' unless eingabe['Ueberstand'].between?(0, 5)
      erstellen(:wange, eingabe, n)
    end
  rescue ArgumentError => e
    UI.messagebox("Ungültige Eingabe: #{e.message}")
  end

  # Ohne Unter- und Hochschränke im Modell: eine freie Sockelblende mit Länge
  def self.dialog_sockelblende
    model = Sketchup.active_model
    k = kueche(model)
    return dialog_sockelblende_frei if k[:teile].empty?
    zl = zeilen(k[:teile])
    alte = k[:auswahl] ? [] : k[:alte]
    prompts = ['Sockelhöhe (mm)', 'Stärke (mm)']
    defaults = [mm(sockel_standard(model)), '16']
    listen = ['', '16|19']
    unless alte.empty?
      prompts << "Vorhandene Sockelblenden (#{alte.size}) ersetzen"
      defaults << 'ja'
      listen << 'ja|nein'
    end
    wo = k[:auswahl] ? 'unter den gewählten Schränken' : 'unter allen Unter- und Hochschränken'
    Kuechenplaner::Eingabe.abfragen(prompts, defaults, listen, 'Sockelblende',
                                    untertitel: "#{zl.size} #{zl.size == 1 ? 'Zeile' : 'Zeilen'} #{wo}",
                                    ok: 'Einfügen') do |res|
      p = ARTEN[:sockelblende][:defaults].merge('Sockelhoehe' => zahl(res[0]), 'Staerke' => zahl(res[1]))
      raise ArgumentError, 'Sockelhöhe 30 bis 300 mm' unless p['Sockelhoehe'] && p['Sockelhoehe'].between?(3.0, 30.0)
      raise ArgumentError, 'Stärke 16 oder 19 mm' unless [1.6, 1.9].include?(p['Staerke'])
      erstellen_sockelblenden(p.select { |n, _| %w[Sockelhoehe Staerke].include?(n) }, ecken(zl, p),
                              res[2] == 'nein' ? [] : alte)
    end
  rescue ArgumentError => e
    UI.messagebox("Ungültige Eingabe: #{e.message}")
  end

  def self.dialog_sockelblende_frei
    model = Sketchup.active_model
    Kuechenplaner::Eingabe.abfragen(['Länge (mm)', 'Sockelhöhe (mm)', 'Tiefe Korpus (mm)', 'Seitenstücke'],
                                    ['600', mm(sockel_standard(model)), '520', 'keine'],
                                    ['', '', '', 'keine|links|rechts|beide'], 'Sockelblende',
                                    untertitel: 'Neue Sockelblende (keine Unter- oder Hochschränke gefunden)',
                                    ok: 'Einfügen') do |res|
      eingabe = { 'Laenge' => zahl(res[0]), 'Sockelhoehe' => zahl(res[1]), 'Tiefe' => zahl(res[2]),
                  'Art_Seite' => %w[keine links rechts beide].index(res[3]).to_f }
      max = ARTEN[:sockelblende][:defaults]['Max_Laenge'] * MAX_STUECKE
      raise ArgumentError, "Länge 10 bis #{(max * 10).round} mm" unless eingabe['Laenge'] && eingabe['Laenge'].between?(1.0, max)
      raise ArgumentError, 'Sockelhöhe 30 bis 300 mm' unless eingabe['Sockelhoehe'] && eingabe['Sockelhoehe'].between?(3.0, 30.0)
      raise ArgumentError, 'Tiefe muss größer als 0 sein' unless eingabe['Tiefe'] && eingabe['Tiefe'] > 0
      erstellen_sockelblende(eingabe)
    end
  rescue ArgumentError => e
    UI.messagebox("Ungültige Eingabe: #{e.message}")
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
  Kuechenplaner.schrank('Blenden & Wangen', 'Passblende…') { Blenden.dialog_passblende }
  Kuechenplaner.schrank('Blenden & Wangen', 'Wange…') { Blenden.dialog_wange }
  Kuechenplaner.schrank('Blenden & Wangen', 'Sockelblende…') { Blenden.dialog_sockelblende }
  file_loaded(__FILE__)
end
