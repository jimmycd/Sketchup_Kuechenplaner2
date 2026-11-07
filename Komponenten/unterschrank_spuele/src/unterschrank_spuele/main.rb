# encoding: UTF-8
#
# Spülenschrank – erzeugt eine Dynamic Component
#
# Erweiterung (.rbz): Erweiterungen > Küchenplaner > Unterschränke > Spülenschrank baut den Schrank im
# aktuellen Modell. Maße und Optionen danach in den Komponentenoptionen einstellen.
#
# Aufbau: Korpus wie der Unterschrank mit Tür (Seiten, Boden, Streben oben),
# aber mit Installationsebene: die Rückwand steht 50 mm vor der Rückseite in
# einer Nut der Seiten, auf dem Boden, und hat einen rechteckigen Ausschnitt für
# die Wasser- und Abwasseranschlüsse. Keine Einlegeböden. Die Rückseite liegt immer in
# einer Flucht mit dem Unterschrank (Tiefe + Rückwand): Seiten und Boden sind dann um die
# Rückwandstärke länger. Installationsebene 0 = Rückwand wie beim Unterschrank hinter dem Korpus.
# Fronten: Türen (eine oder zwei) oder oben eine feste Blende (Spülbecken) und
# darunter ein Auszug Blum LEGRABOX für den Abfallsammler. Über dem Kasten
# bleibt unter der Blende Platz für den Siphon (Siphon_Freiraum).
#
# Material: Platten haben das Material "Melamin weiss" (Plattenwerkstoff),
# sichtbare Kanten das Material "Anleimer Melamin weiss" (Kante, 2 mm, wird nur
# in Stückliste/Zuschnitt abgezogen; gezeichnet wird das Endmaß). Jedes Teil hat einen eigenen Tag
# <Kürzel>_<Bereich>_<Teil> (z. B. USP1_SeiteL, USP1_A_Front) und das Wörterbuch
# "JT_Schrank" für den TCN-Export. Anderes Kürzel:
#   Spuelenschrank.erstellen({ 'Kuerzel' => 'USP2' }, ziel)

require 'sketchup.rb'
require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'eingabe') # Eingabefenster im Treppenplaner-Stil
require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'neuladen') # Neu laden ohne Neustart (Wächter)
require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'schubkasten') # Schubladenauszug der Küche

module Spuelenschrank

  DICT     = 'dynamic_attributes'.freeze
  NAME     = 'Spuelenschrank'.freeze
  MATERIAL = 'Melamin weiss'.freeze
  KANTE    = 'Anleimer Melamin weiss'.freeze
  OCL_DICT = 'ladb_opencutlist'.freeze
  KUERZEL  = 'USP'.freeze

  # Tag-Schema für den TCN-Export (gleich in allen Komponenten, der Test prüft das):
  # Tag <Kürzel>_<Bereich>_<Teil>, dazu am Teil das Wörterbuch JT_Schrank.
  JT_DICT   = 'JT_Schrank'.freeze
  TYP       = 'Spuelenschrank'.freeze
  KATEGORIE = 'Unterschrank'.freeze # Unterschrank, Oberschrank oder Hochschrank
  ROLLEN = {
    'SeiteL' => 'Seite', 'SeiteR' => 'Seite', 'Boden' => 'Boden', 'Deckel' => 'Deckel',
    'StrebeVorn' => 'Strebe', 'StrebeHinten' => 'Strebe',
    'ZwischenbodenUnten' => 'Zwischenboden', 'ZwischenbodenMitte' => 'Zwischenboden', 'ZwischenbodenOben' => 'Zwischenboden',
    'Mittelboden' => 'Zwischenboden', 'Mittelwand' => 'Seite',
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

  # Schubladenauszug der Küche (gemeinsam/schubkasten.rb, gewählt in Küchenplaner › Einstellungen):
  # Zargen mit Holzrückwand, Nennlängen, Abzüge für Kastenboden und Holzrückwand stehen als Attribute
  # Ausz_* am Schrank; wechselt das System, setzt das Plugin sie neu. Standard Blum LEGRABOX free.
  SK = Kuechenplaner::Schubkasten

  # Holzrückwand der höchsten Zarge, die in kc passt (cm)
  def self.hrw_zarge(kc, soll, p = nil)
    SK.hrw(kc, soll, p)
  end

  # dieselbe Wahl als DC-Formel; q = Teil mit den Attributen Ausz_* (nil = eigene)
  def self.f_hrw_zarge(kc, soll, q)
    SK.f_hrw(kc, soll, q)
  end

  # Standardwerte in cm
  DEFAULTS = {
    'Breite'                    => 80.0,
    'Hoehe'                     => 70.0,
    'Tiefe'                     => 80.0,  # Korpus ohne Front (wie Unterschrank mit Tür)
    'Frontvariante'             => 1.0,   # 0 = Türen, 1 = Blende + Auszug
    'Art_Tuer'                  => 2.0,   # 1 = eine Tür (Anschlag links), 2 = zwei Türen
    'Hoehe_Blende'              => 20.0,
    'Siphon_Freiraum'           => 20.0,  # Unterkante Blende -> Oberkante Kasten, mindestens
    'Rueckwand_Versatz'         => 5.0,   # Installationsebene: Rückseite Schrank -> Rückseite Rückwand (0 = hinter dem Korpus)
    'Ausschnitt_Unten'          => 25.0,  # Rückwand-Ausschnitt: Unterkante über Unterkante Korpus
    'Ausschnitt_Hoehe'          => 40.0,  # 0 = kein Ausschnitt
    'Ausschnitt_Rand'           => 5.0,   # Steg links, rechts und oben
    'Materialstaerke_Korpus'    => 1.9,
    'Materialstarke_Rueckwand'  => 0.8,
    'Nuttiefe'                  => 0.9,
    'BreiteStreben'             => 10.0,
    'Spaltbreite'               => 0.2,
    # Auszug Blum LEGRABOX free wie im Unterschrank mit Schubladen
    'Materialstaerke_Kastenboden'     => 1.6,
    'Materialstaerke_Kastenrueckwand' => 1.6,
    'Hoehe_Kastenrueckwand'     => 14.8,
    'Hoehenoffset_Schiene'      => 0.0,
    'Lochraster_Start'          => 3.5,
    'Lochraster'                => 3.2,
    'Kasten_Abstand_unten'      => 3.0,
    'Auszug_Anteil'             => 0.8,
    # Griffkante (setzt Schrank-CNC nach der Öffnung der Küche): Türen bzw. Auszugsfront oben so viel kürzer
    'Griff_Front'               => 0.0
  }.merge(SK.attribute(SK::STANDARD)).freeze

  # Kurzhilfe in der Komponente (Kurzfassung der README.md), steht oben im Fenster "Komponentenoptionen".
  DOKU_URL = 'https://github.com/jimmycd/sketchup_kuechenplaner2/tree/main/Komponenten/unterschrank_spuele'.freeze
  HILFE_KURZ = 'Spülenschrank mit Türen oder Blende + Auszug (Abfallsammler), Installationsebene'.freeze

  # ---------------------------------------------------------------------------
  # Installationsebene (Jürgen 2026-11-05: die Rückseite muss mit den anderen Unterschränken
  # durchgehen). Die Rückseite des Schranks liegt wie beim Unterschrank bei Tiefe + Rückwand
  # hinter dem Korpusanfang.
  #   Versatz 0: Rückwand wie beim Unterschrank, volle Breite und Höhe hinter Seiten und Boden.
  #   Versatz > 0: Seiten und Boden reichen bis zur Rückseite (Tiefe + Rückwand), die Rückwand
  #   steckt in der Seitennut, ihre Rückseite liegt Versatz vor der Rückseite des Schranks.
  #   Hinter der Nut bleiben mindestens VERSATZ_MIN (kleinere Werte werden darauf angehoben).
  # ---------------------------------------------------------------------------
  VERSATZ_MIN = 1.0 # cm

  def self.versatz(p)
    v = p['Rueckwand_Versatz']
    v > 0 ? [v, VERSATZ_MIN].max : 0.0
  end

  # dieselbe Regel als DC-Formel (pre = "Name!" für Teile im Schrank)
  def self.f_versatz(pre = '')
    "IF(#{pre}Rueckwand_Versatz>0,MAX(#{pre}Rueckwand_Versatz,#{VERSATZ_MIN}),0)"
  end

  # Seiten und Boden: Tiefe, mit Installationsebene + Rückwandstärke
  def self.f_korpus_tiefe(pre = '')
    "#{pre}Tiefe+IF(#{pre}Rueckwand_Versatz>0,#{pre}Materialstarke_Rueckwand,0)"
  end

  # ---------------------------------------------------------------------------
  # Reine Berechnung (ohne SketchUp), spiegelt die DC-Formeln. Werte in cm.
  # ---------------------------------------------------------------------------
  def self.berechne(p)
    mk, rw, sp = p['Materialstaerke_Korpus'], p['Materialstarke_Rueckwand'], p['Spaltbreite']
    b, h, t = p['Breite'], p['Hoehe'], p['Tiefe']
    t_innen = t - versatz(p)
    rand = p['Ausschnitt_Rand']
    a_unten = [p['Ausschnitt_Unten'], mk + rand].max
    ab = kasten_unten(p)
    z_max = h - p['Hoehe_Blende'] - p['Siphon_Freiraum'] # höchste Oberkante Kasten
    {
      t_innen: t_innen,                                  # Vorderkante Korpus -> Vorderseite Rückwand
      t_korpus: p['Rueckwand_Versatz'] > 0 ? t + rw : t, # Länge Seiten und Boden
      b_tuer1: b - sp,
      b_tuer2: b / 2.0 - sp,
      h_auszug: h - p['Hoehe_Blende'] - sp - p['Griff_Front'].to_f, # Front des Auszugs
      nl: nennlaenge(t_innen),
      ab: ab,                                            # Unterkante Kasten
      hrw: [[z_max - ab - p['Materialstaerke_Kastenboden'],
            hrw_zarge(z_max - ab, p['Hoehe_Kastenrueckwand'])].min, 2.0].max, # höchste Zarge, die passt
      a_unten: a_unten,
      a_hoehe: [[p['Ausschnitt_Hoehe'], h - rand - a_unten].min, 0.0].max,
      a_breite: b - 2 * mk - 2 * rand
    }
  end

  # Nennlänge der Schiene (cm): größte des Auszugssystems mit NL + Abstand <= Tiefe; passt keine,
  # bleibt es bei der kürzesten, der TCN-Export meldet dann zu wenig Tiefe.
  def self.nennlaenge(tiefe, p = nil)
    SK.nl(tiefe, p)
  end

  # dieselbe Wahl als DC-Formel (Attribute Ausz_NL_* am eigenen Teil bzw. an q)
  def self.f_nennlaenge(tiefe, q = nil)
    SK.f_nl(tiefe, q)
  end

  # Unterkante Kasten über Unterkante Front (= Unterkante Korpus): mindestens Kasten_Abstand_unten
  #, Schienenbohrung mind. 38 mm über dem Korpusboden, kein Lochraster (wie Unterschrank mit Schubladen)
  def self.kasten_unten(p)
    off = p['Hoehenoffset_Schiene']
    [p['Kasten_Abstand_unten'] + off, p['Materialstaerke_Korpus'] + p['Ausz_Ueber_Boden']].max - off
  end

  def self.f_kasten_unten
    u = NAME
    "MAX(#{u}!Kasten_Abstand_unten+#{u}!Hoehenoffset_Schiene,#{u}!Materialstaerke_Korpus+#{u}!Ausz_Ueber_Boden)" \
      "-#{u}!Hoehenoffset_Schiene"
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

  # Freies Kürzel für die Tags, z. B. USP1, USP2 …
  def self.freies_kuerzel(model)
    n = 1
    n += 1 while model.layers.to_a.any? { |l| l.name.start_with?("#{KUERZEL}#{n}_") }
    "#{KUERZEL}#{n}"
  end

  def self.tag(model, name)
    model.layers[name] || model.layers.add(name)
  end

  # Tag <Kürzel>_<Bereich>_<Teil> (z. B. USP1_A_Front) und JT_Schrank am Teil
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
    'Front'           => %i[xmin xmax zmin zmax], # Blende und Auszug
    'Tür'             => %i[xmin xmax zmin zmax],
    'KastenBoden'     => [],
    'KastenRueckwand' => %i[zmax]
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
    p = SK.vorgaben(DEFAULTS, model).merge(eingabe)
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
    attribut(haupt, 'Tiefe', p['Tiefe'], access: 'TEXTBOX', formlabel: 'Tiefe (Korpus ohne Front)')
    attribut(haupt, 'Frontvariante', p['Frontvariante'], laenge: false, access: 'LIST', formlabel: 'Fronten',
             units: 'INTEGER', options: '&T%C3%BCren=0&Blende%20%2B%20Auszug=1&')
    attribut(haupt, 'Art_Tuer', p['Art_Tuer'], laenge: false, access: 'LIST', formlabel: 'Türen (bei Fronten = Türen)',
             units: 'INTEGER', options: '&Eine%20T%C3%BCr%20(Anschlag%20links)=1&Zwei%20T%C3%BCren=2&')
    attribut(haupt, 'Hoehe_Blende', p['Hoehe_Blende'], access: 'TEXTBOX', formlabel: 'Höhe Blende (bei Auszug)')
    attribut(haupt, 'Siphon_Freiraum', p['Siphon_Freiraum'], access: 'TEXTBOX',
             formlabel: 'Siphon-Freiraum unter der Blende (bei Auszug)')
    attribut(haupt, 'Rueckwand_Versatz', p['Rueckwand_Versatz'], access: 'TEXTBOX',
             formlabel: 'Installationsebene (Rückwand vor der Rückseite, 0 = hinten)')
    attribut(haupt, 'Ausschnitt_Unten', p['Ausschnitt_Unten'], access: 'TEXTBOX',
             formlabel: 'Rückwand-Ausschnitt: Unterkante über Korpus-Unterkante')
    attribut(haupt, 'Ausschnitt_Hoehe', p['Ausschnitt_Hoehe'], access: 'TEXTBOX',
             formlabel: 'Rückwand-Ausschnitt: Höhe (0 = keiner)')
    attribut(haupt, 'Ausschnitt_Rand', p['Ausschnitt_Rand'], access: 'TEXTBOX',
             formlabel: 'Rückwand-Ausschnitt: Steg seitlich und oben')

    # --- Feste Maße (über Komponentenattribute änderbar) ---
    %w[Materialstaerke_Korpus Materialstarke_Rueckwand Nuttiefe BreiteStreben Spaltbreite
       Materialstaerke_Kastenboden Materialstaerke_Kastenrueckwand Hoehe_Kastenrueckwand Hoehenoffset_Schiene
       Lochraster_Start Lochraster Kasten_Abstand_unten Griff_Front].each do |n|
      attribut(haupt, n, p[n], units: 'STRING')
    end
    attribut(haupt, 'Auszug_Anteil', p['Auszug_Anteil'], laenge: false, units: 'STRING')

    # --- Abgeleitete Werte ---
    attribut(haupt, 'T_Innen', r[:t_innen], units: 'STRING', formula: "Tiefe-#{f_versatz}")
    attribut(haupt, 'B_Tuer2', r[:b_tuer2], units: 'STRING', formula: 'Breite/2-Spaltbreite')
    attribut(haupt, 'H_Auszug', r[:h_auszug], units: 'STRING', formula: 'Hoehe-Hoehe_Blende-Spaltbreite-Griff_Front')
    # Nennlänge der LEGRABOX-Schiene aus der lichten Tiefe bis zur Rückwand
    # (Formeln am selben Bauteil nie auf andere Formel-Attribute stützen: SketchUp rechnet sie nur
    # einmal und der Reihe nach, NL käme sonst vor T_Innen dran und bliebe nach einer Tiefenänderung alt)
    # Schubladenauszug der Küche (Attribute Ausz_*, setzt das Plugin bei einem Systemwechsel neu)
    SK::NAMEN.each { |n| attribut(haupt, n, p[n], units: 'STRING') }
    attribut(haupt, 'NL', r[:nl], units: 'STRING',
             formula: f_nennlaenge("(Tiefe-#{f_versatz})"))
    attribut(haupt, 'A_Unten', r[:a_unten], units: 'STRING',
             formula: 'MAX(Ausschnitt_Unten,Materialstaerke_Korpus+Ausschnitt_Rand)')
    attribut(haupt, 'A_Hoehe', r[:a_hoehe], units: 'STRING',
             formula: 'MAX(MIN(Ausschnitt_Hoehe,Hoehe-Ausschnitt_Rand-MAX(Ausschnitt_Unten,Materialstaerke_Korpus+Ausschnitt_Rand)),0)')

    mk = p['Materialstaerke_Korpus']
    b, h, t = p['Breite'], p['Hoehe'], p['Tiefe']
    rw, sp, nut, bs = p['Materialstarke_Rueckwand'], p['Spaltbreite'], p['Nuttiefe'], p['BreiteStreben']
    e = haupt.entities
    innen_b = "#{u}!Breite-2*#{u}!Materialstaerke_Korpus"

    # --- Korpus (beginnt wie die anderen Schränke bei y = Materialstärke) ---
    tk, f_tk = r[:t_korpus], f_korpus_tiefe("#{u}!")
    seite = platte(model, 'Seite', 'Seite', [mk, tk, h],
                   ["#{u}!Materialstaerke_Korpus", f_tk, "#{u}!Hoehe"])
    einsetzen(e, seite, 'SeiteL', [0, mk, 0], [nil, nil, nil], mat: mat, kz: t_.('SeiteL'))
    einsetzen(e, seite, 'SeiteR', [b - mk, mk, 0],
              ["#{u}!Breite-#{u}!Materialstaerke_Korpus", nil, nil], mat: mat, kz: t_.('SeiteR'))

    boden = platte(model, 'Boden', 'Boden', [b - 2 * mk, tk, mk], [innen_b, f_tk, "#{u}!Materialstaerke_Korpus"])
    einsetzen(e, boden, 'Boden', [mk, mk, 0], ["#{u}!Materialstaerke_Korpus", nil, nil], mat: mat, kz: t_.('Boden'))

    strebe_formeln = [innen_b, "#{u}!BreiteStreben", "#{u}!Materialstaerke_Korpus"]
    strebe_v = platte(model, 'StrebeV', 'StrebeVorn', [b - 2 * mk, bs, mk], strebe_formeln)
    einsetzen(e, strebe_v, 'StrebeVorn', [mk, mk, h - mk],
              ["#{u}!Materialstaerke_Korpus", nil, "#{u}!Hoehe-#{u}!Materialstaerke_Korpus"],
              mat: mat, kz: t_.('StrebeVorn'))
    # Strebe hinten endet an der Rückwand
    strebe_h = platte(model, 'StrebeH', 'StrebeHinten', [b - 2 * mk, bs, mk], strebe_formeln)
    einsetzen(e, strebe_h, 'StrebeHinten', [mk, mk + r[:t_innen] - bs, h - mk],
              ['StrebeVorn!X', "#{u}!Materialstaerke_Korpus+#{u}!T_Innen-#{u}!BreiteStreben", 'StrebeVorn!Z'],
              mat: mat, kz: t_.('StrebeHinten'))

    rueckwand(model, e, p, r, mat, kz)
    tueren(model, e, p, r, mat, t_)
    blende_und_auszug(model, e, p, r, mat, kz)
    haupt
  end

  # Installationsebene: Rückwand in der Nut beider Seiten, steht auf dem Boden, oben bündig.
  # Versatz 0: wie beim Unterschrank volle Breite und Höhe hinter dem Korpus (keine Nut).
  # Der Ausschnitt steht als Attribut an der Rückwand (Lage in der Rückwand, cm),
  # daraus fräst der TCN-Export die Kontur; sichtbar ist er als Umriss davor.
  def self.rueckwand(model, e, p, r, mat, kz)
    u = NAME
    mk, rw, nut, rand = p['Materialstaerke_Korpus'], p['Materialstarke_Rueckwand'], p['Nuttiefe'], p['Ausschnitt_Rand']
    b, h = p['Breite'], p['Hoehe']
    nutz = p['Rueckwand_Versatz'] > 0 # Rückwand in der Nut
    ein = ->(ja, nein) { "IF(#{u}!Rueckwand_Versatz>0,#{ja},#{nein})" }
    x0, z0 = nutz ? [mk - nut, mk] : [0.0, 0.0]
    d = platte(model, 'Rückwand', 'Rückwand', [b - 2 * x0, rw, h - z0],
               [ein.("#{u}!Breite-2*#{u}!Materialstaerke_Korpus+2*#{u}!Nuttiefe", "#{u}!Breite"),
                "#{u}!Materialstarke_Rueckwand",
                ein.("#{u}!Hoehe-#{u}!Materialstaerke_Korpus", "#{u}!Hoehe")])
    attribut(d, 'Ausschnitt_X', mk + rand - x0, units: 'STRING',
             formula: ein.("#{u}!Nuttiefe+#{u}!Ausschnitt_Rand", "#{u}!Materialstaerke_Korpus+#{u}!Ausschnitt_Rand"))
    attribut(d, 'Ausschnitt_Z', r[:a_unten] - z0, units: 'STRING',
             formula: ein.("#{u}!A_Unten-#{u}!Materialstaerke_Korpus", "#{u}!A_Unten"))
    attribut(d, 'Ausschnitt_B', r[:a_breite], units: 'STRING', formula: "#{u}!Breite-2*#{u}!Materialstaerke_Korpus-2*#{u}!Ausschnitt_Rand")
    attribut(d, 'Ausschnitt_H', r[:a_hoehe], units: 'STRING', formula: "#{u}!A_Hoehe")
    y_rw = mk + r[:t_innen]
    einsetzen(e, d, 'Rückwand', [x0, y_rw, z0],
              [ein.("#{u}!Materialstaerke_Korpus-#{u}!Nuttiefe", '0'), "#{u}!Materialstaerke_Korpus+#{u}!T_Innen",
               ein.("#{u}!Materialstaerke_Korpus", '0')], mat: mat, kz: [model, kz, 'Rueckwand'])

    # Umriss des Ausschnitts (nur Kanten, keine Fläche: kein Teil für die Stückliste)
    a = model.definitions.add('Rückwand Ausschnitt')
    stempel(a)
    a.set_attribute(DICT, '_name', 'Ausschnitt')
    # ohne Ausschnitt (Höhe 0) wird ein flacher Umriss gezeichnet und ausgeblendet
    lx, lz = inch(r[:a_breite]), inch([r[:a_hoehe], 1.0].max)
    a.entities.add_line([0, 0, 0], [lx, 0, 0])
    a.entities.add_line([lx, 0, 0], [lx, 0, lz])
    a.entities.add_line([lx, 0, lz], [0, 0, lz])
    a.entities.add_line([0, 0, lz], [0, 0, 0])
    { 'lenx' => [r[:a_breite], "#{u}!Breite-2*#{u}!Materialstaerke_Korpus-2*#{u}!Ausschnitt_Rand"],
      'lenz' => [r[:a_hoehe], "#{u}!A_Hoehe"] }.each do |k, (wert, f)|
      a.set_attribute(DICT, k, inch(wert))
      a.set_attribute(DICT, "_#{k}_formula", f)
      a.set_attribute(DICT, "_#{k}_label", k.capitalize)
    end
    sichtbarkeit(a, r[:a_hoehe] > 0, "IF(#{u}!A_Hoehe>0,0,1)")
    ia = einsetzen(e, a, 'Ausschnitt', [mk + rand, y_rw - 0.05, r[:a_unten]],
                   ["#{u}!Materialstaerke_Korpus+#{u}!Ausschnitt_Rand", "#{u}!Materialstaerke_Korpus+#{u}!T_Innen-0.05",
                    "#{u}!A_Unten"], layer: tag(model, "#{kz}_Rueckwand_Ausschnitt"))
    ia.hidden = r[:a_hoehe] <= 0
  end

  # Türen über die volle Höhe (wie die Fronten im Unterschrank mit Schubladen):
  # eine (Anschlag links) oder zwei, nur bei Frontvariante 0
  def self.tueren(model, e, p, r, mat, t_)
    u = NAME
    sp, mk, b = p['Spaltbreite'], p['Materialstaerke_Korpus'], p['Breite']
    h = p['Hoehe'] - p['Griff_Front'].to_f
    tuer = p['Frontvariante'].to_i == 0
    art = p['Art_Tuer'].to_i
    h_f = "#{u}!Hoehe-#{u}!Griff_Front"

    t1 = platte(model, 'Tür', 'Tür', [r[:b_tuer1], mk, h],
                ["#{u}!Breite-#{u}!Spaltbreite", "#{u}!Materialstaerke_Korpus", h_f])
    tuer_drehen(t1, tuer && art == 1, "IF(AND(#{u}!Frontvariante=0,#{u}!Art_Tuer=1),0,1)", -100)
    i1 = einsetzen(e, t1, 'Tür', [sp / 2.0, -sp, 0],
                   ["#{u}!Spaltbreite/2", "-#{u}!Spaltbreite", nil], mat: mat, kz: t_.('Tuer'))
    i1.hidden = !(tuer && art == 1)

    zwei = "IF(AND(#{u}!Frontvariante=0,#{u}!Art_Tuer=2),0,1)"
    tl = platte(model, 'Tür links', 'TürL', [r[:b_tuer2], mk, h],
                ["#{u}!B_Tuer2", "#{u}!Materialstaerke_Korpus", h_f], art: 'Tür')
    tuer_drehen(tl, tuer && art == 2, zwei, -100)
    il = einsetzen(e, tl, 'TürL', [sp / 2.0, -sp, 0],
                   ["#{u}!Spaltbreite/2", "-#{u}!Spaltbreite", nil], mat: mat, kz: t_.('TuerL'))
    il.hidden = !(tuer && art == 2)

    # rechts: Drehpunkt muss rechts liegen, deshalb steckt die Tür in einem
    # Halter am Scharnier und liegt darin bei x = -Breite der Tür
    halter = model.definitions.add('Tür rechts Halter')
    stempel(halter)
    halter.set_attribute(DICT, '_name', 'TuerRHalter')
    attribut(halter, 'B_Tuer', r[:b_tuer2], units: 'STRING', formula: "#{u}!B_Tuer2")
    attribut(halter, 'H_Tuer', h, units: 'STRING', formula: h_f)
    attribut(halter, 'Mk', mk, units: 'STRING', formula: "#{u}!Materialstaerke_Korpus")
    tuer_drehen(halter, tuer && art == 2, zwei, 100)
    hn = 'TuerRHalter'
    tr = platte(model, 'Tür rechts', 'TürR', [r[:b_tuer2], mk, h],
                ["#{hn}!B_Tuer", "#{hn}!Mk", "#{hn}!H_Tuer"], art: 'Tür')
    einsetzen(halter.entities, tr, 'TürR', [-r[:b_tuer2], 0, 0], ["-#{hn}!B_Tuer", nil, nil], mat: mat, kz: t_.('TuerR'))
    ih = einsetzen(e, halter, hn, [b - sp / 2.0, -sp, 0],
                   ["#{u}!Breite-#{u}!Spaltbreite/2", "-#{u}!Spaltbreite", nil])
    ih.hidden = !(tuer && art == 2)
  end

  def self.tuer_drehen(d, sichtbar, formel, winkel)
    sichtbarkeit(d, sichtbar, formel)
    d.set_attribute(DICT, 'rotz', 0.0)
    d.set_attribute(DICT, 'onclick', "ANIMATE(\"ROTZ\",0,#{winkel})")
    d.set_attribute(DICT, '_onclick_label', 'onClick')
  end

  # Frontvariante 1: oben feste Blende (Bereich B), darunter ein Auszug (Bereich A) mit
  # Blum LEGRABOX: Front, Boden (LW-35 x NL-10) und Holzrückwand (LW-38, höchstens 148 mm
  # und so, dass unter der Blende Siphon_Freiraum frei bleibt); die Zargen sind aus Metall.
  def self.blende_und_auszug(model, e, p, r, mat, kz)
    u = NAME
    sp, mk, b, h = p['Spaltbreite'], p['Materialstaerke_Korpus'], p['Breite'], p['Hoehe']
    auszug = p['Frontvariante'].to_i == 1
    hb = p['Hoehe_Blende']
    formel = "IF(#{u}!Frontvariante=1,0,1)"

    bl = platte(model, 'Blende', 'Blende', [b - sp, mk, hb],
                ["#{u}!Breite-#{u}!Spaltbreite", "#{u}!Materialstaerke_Korpus", "#{u}!Hoehe_Blende"], art: 'Front')
    sichtbarkeit(bl, auszug, formel)
    ib = einsetzen(e, bl, 'Blende', [sp / 2.0, -sp, h - hb],
                   ["#{u}!Spaltbreite/2", "-#{u}!Spaltbreite", "#{u}!Hoehe-#{u}!Hoehe_Blende"],
                   mat: mat, kz: [model, kz, 'Front', 'B'])
    ib.hidden = !auszug

    s = 'Auszug'
    mb, mrw, nl = p['Materialstaerke_Kastenboden'], p['Materialstaerke_Kastenrueckwand'], r[:nl]
    lw = b - 2 * mk
    d = model.definitions.add(s)
    stempel(d)
    d.set_attribute(DICT, '_name', s)
    # Lokale Kopien der Werte vom Schrank (Formeln können nur Eltern/Geschwister ansprechen)
    attribut(d, 'Breite', b, units: 'STRING', formula: "#{u}!Breite")
    attribut(d, 'Hoehe_Front', r[:h_auszug], units: 'STRING', formula: "#{u}!H_Auszug")
    attribut(d, 'Mk', mk, units: 'STRING', formula: "#{u}!Materialstaerke_Korpus")
    attribut(d, 'Spalt', sp, units: 'STRING', formula: "#{u}!Spaltbreite")
    attribut(d, 'Mb', mb, units: 'STRING', formula: "#{u}!Materialstaerke_Kastenboden")
    attribut(d, 'Mrw', mrw, units: 'STRING', formula: "#{u}!Materialstaerke_Kastenrueckwand")
    attribut(d, 'NL', nl, units: 'STRING', formula: "#{u}!NL")
    SK::NAMEN.each { |n| attribut(d, n, p[n], units: 'STRING', formula: "#{u}!#{n}") }
    attribut(d, 'Ab_unten', r[:ab], units: 'STRING', formula: f_kasten_unten)
    # Höhe Holzrückwand: höchstens Hoehe_Kastenrueckwand, Oberkante Kasten Siphon_Freiraum unter der Blende
    kh = "#{u}!Hoehe-#{u}!Hoehe_Blende-#{u}!Siphon_Freiraum-(#{f_kasten_unten})"
    attribut(d, 'Hrw', r[:hrw], units: 'STRING',
             formula: "MAX(MIN(#{kh}-#{u}!Materialstaerke_Kastenboden,#{f_hrw_zarge(kh, "#{u}!Hoehe_Kastenrueckwand", u)}),2)")
    attribut(d, 'Auszug', nl * p['Auszug_Anteil'], units: 'STRING', formula: "#{u}!NL*#{u}!Auszug_Anteil")
    sichtbarkeit(d, auszug, formel)
    # Mit "Interagieren" anklicken -> Auszug fährt heraus
    d.set_attribute(DICT, 'onclick', 'ANIMATE("Y",0,-Auszug)')
    d.set_attribute(DICT, '_onclick_label', 'onClick')

    de = d.entities
    st = ->(teil) { [model, kz, teil, 'A'] }
    front = platte(model, 'Front Auszug', 'Front', [b - sp, mk, r[:h_auszug]],
                   ["#{s}!Breite-#{s}!Spalt", "#{s}!Mk", "#{s}!Hoehe_Front"])
    einsetzen(de, front, 'Front', [sp / 2.0, -sp, 0], ["#{s}!Spalt/2", "-#{s}!Spalt", nil], mat: mat, kz: st.('Front'))

    kbod = platte(model, 'Kasten Boden Auszug', 'KastenBoden', [lw - p['Ausz_Boden_B'], nl - p['Ausz_Boden_T'], mb],
                  ["#{s}!Breite-2*#{s}!Mk-#{s}!Ausz_Boden_B", "#{s}!NL-#{s}!Ausz_Boden_T", "#{s}!Mb"])
    einsetzen(de, kbod, 'KastenBoden', [mk + p['Ausz_Boden_B'] / 2.0, mk, r[:ab]],
              ["#{s}!Mk+#{s}!Ausz_Boden_B/2", "#{s}!Mk", "#{s}!Ab_unten"], mat: mat, kz: st.('KastenBoden'))

    krw = platte(model, 'Kasten Rueckwand Auszug', 'KastenRueckwand', [lw - p['Ausz_RW_B'], mrw, r[:hrw]],
                 ["#{s}!Breite-2*#{s}!Mk-#{s}!Ausz_RW_B", "#{s}!Mrw", "#{s}!Hrw"])
    einsetzen(de, krw, 'KastenRueckwand', [mk + p['Ausz_RW_B'] / 2.0, mk + nl - p['Ausz_Boden_T'] - mrw, r[:ab] + mb],
              ["#{s}!Mk+#{s}!Ausz_RW_B/2", "#{s}!Mk+#{s}!NL-#{s}!Ausz_Boden_T-#{s}!Mrw", "#{s}!Ab_unten+#{s}!Mb"],
              mat: mat, kz: st.('KastenRueckwand'))

    inst = einsetzen(e, d, s, [0, 0, 0], [nil, nil, nil], layer: tag(model, "#{kz}_A_Auszug"))
    inst.hidden = !auszug
    inst
  end

  # ---------------------------------------------------------------------------
  # Erzeugen (mit ziel zusätzlich als .skp speichern)
  # ---------------------------------------------------------------------------
  # Neuer Schrank: Maße beim Anlegen abfragen, Tiefe = Korpus ohne Front/Rückwand. Danach bleiben sie im
  # Fenster Komponentenoptionen änderbar; alle abhängigen Teile folgen dort per Formel.
  TIEFE_NEU = 52.0 # cm, Vorschlag im Dialog

  def self.tiefe_min
    SK.nl_min + versatz(DEFAULTS)
  end

  def self.dialog
    Kuechenplaner::Eingabe.abfragen(['Breite (mm)', 'Höhe (mm)', 'Tiefe Korpus (mm)'],
                      [(DEFAULTS['Breite'] * 10).round.to_s, (DEFAULTS['Hoehe'] * 10).round.to_s, (TIEFE_NEU * 10).round.to_s], 'Spülenschrank', untertitel: 'Neuer Schrank', ok: 'Einfügen') do |res|
      w = res.map { |v| v.to_s.tr(',', '.').to_f / 10.0 }
      eingabe = { 'Breite' => w[0], 'Hoehe' => w[1], 'Tiefe' => w[2] }
      t = eingabe['Tiefe']
      if t < tiefe_min - 0.000001
        raise ArgumentError, "Tiefe #{(t * 10).round} mm ist zu klein (kürzeste Schiene braucht #{(SK.nl_min * 10).round} mm vor der Installationsebene, mindestens #{(tiefe_min * 10).round} mm)"
      end
      raise ArgumentError, 'Maße müssen größer als 0 sein' if eingabe.values.any? { |v| v <= 0 }
      erstellen(eingabe)
    end
  rescue ArgumentError => e
    UI.messagebox("Ungültige Eingabe: #{e.message}")
  end

  def self.erstellen(eingabe = {}, ziel = nil)
    model = Sketchup.active_model
    model.start_operation('Spülenschrank', true)
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
        UI.messagebox('Automatisches Speichern ging nicht. Rechtsklick auf den Spülenschrank → "Speichern unter…"')
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
  Kuechenplaner.schrank('Unterschränke', 'Spülenschrank…') { Spuelenschrank.dialog }
  file_loaded(__FILE__)
end
