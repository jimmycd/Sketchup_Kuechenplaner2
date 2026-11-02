# encoding: UTF-8
#
# Abschlussregal – offenes Regal am Ende einer Schrankzeile, als Dynamic Component
#
# Erweiterung (.rbz): Erweiterungen > Küchenplaner > Unterschränke | Oberschränke | Hochschränke >
# Abschlussregal… fragt Breite, Höhe, Tiefe, Form und Zeilenende ab und baut das Regal. Danach sind
# alle Maße und Optionen in den Komponentenoptionen änderbar.
#
# Aufbau: Seite innen (am Nachbarschrank) über die volle Tiefe, Seite außen, Boden, Deckel (statt
# Streben, das Regal ist offen), Rückwand hinter dem Korpus und 0–6 Einlegeböden. Form:
#   gerade  alle Böden rechteckig, beide Seiten gleich tief
#   schräg  Böden als Trapez, Vorderkante schräg von der Seite innen (volle Tiefe) zur Seite außen
#           (Tiefe außen)
#   rund    Vorderkante als Viertelkreis (Radius), an der Seite außen tangential; die Seite außen
#           reicht vom Bogenende bis hinten
# Schräg- und Bogenkante bekommen Anleimer; ihren Umriss fräst der TCN-Export (Schrank-CNC) als
# Kontur. Eine Schräge oder ein Bogen lässt sich nicht per DC-Formel umformen, deshalb baut die
# Erweiterung das Regal nach jeder Änderung in den Komponentenoptionen neu auf (wie die L-Form des
# Eckschranks); Frontmaterial bleibt dabei erhalten.
#
# Materialien und Anleimer: Platten "Melamin weiss" (Plattenwerkstoff), sichtbare Kanten
# "Anleimer Melamin weiss" (2 mm). Die Angaben stehen im Wörterbuch "ladb_opencutlist" am
# Material (Format von OpenCutList; Stückliste, Zuschnitt, Etiketten und TCN-Export des eigenen
# Plugins lesen es). Gezeichnet wird das Endmaß. Jedes Teil hat einen eigenen Tag
# <Kürzel>_<Teil> (z. B. RA1_SeiteL, RA1_Einlegeboden2) und das Wörterbuch "JT_Schrank".

require 'sketchup.rb'

module RegalAbschluss

  DICT     = 'dynamic_attributes'.freeze
  NAME     = 'Abschlussregal'.freeze
  MATERIAL = 'Melamin weiss'.freeze
  KANTE    = 'Anleimer Melamin weiss'.freeze
  OCL_DICT = 'ladb_opencutlist'.freeze
  KUERZEL  = 'RA'.freeze
  MAX_EB   = 6

  # Tag-Schema für den TCN-Export (gleich in allen Komponenten, der Test prüft das):
  # Tag <Kürzel>_<Teil>, dazu am Teil das Wörterbuch JT_Schrank.
  JT_DICT = 'JT_Schrank'.freeze
  TYP     = 'Abschlussregal'.freeze
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

  # Umriss der Böden für den TCN-Export (Zoll, lokal in der Bodenebene):
  #   umriss  geschlossener Linienzug x0, y0, x1, y1, … (Bogen in Sehnen)
  #   kante   Schräg- bzw. Bogenkante mit Anleimer, je Stück 8 Zahlen:
  #           Art (0 Gerade, 1 Bogen), x0, y0, x1, y1, Mitte x, Mitte y, Drehsinn (+1 gegen den Uhrzeigersinn)
  KONTUR_DICT = 'JT_Kontur'.freeze
  # Maße, mit denen das Regal gebaut ist (für den Neuaufbau nach einer Änderung)
  R_DICT   = 'JT_Regal'.freeze
  R_GEBAUT = 'gebaut'.freeze

  FORMEN     = %w[gerade schräg rund].freeze
  GERADE, SCHRAEG, RUND = 0, 1, 2
  ZEILENENDE = %w[rechts links].freeze # rechts: die Seite außen ist rechts, der Nachbar steht links

  # Schranktyp beim Anlegen: Kategorie, Menügruppe, Vorschläge im Dialog (cm)
  TYPEN = {
    'Unterschrank' => { gruppe: 'Unterschränke', hoehe: 70.0, tiefe: 52.0, eb: 1 },
    'Oberschrank'  => { gruppe: 'Oberschränke', hoehe: 70.0, tiefe: 40.0, eb: 1 },
    'Hochschrank'  => { gruppe: 'Hochschränke', hoehe: 210.0, tiefe: 52.0, eb: 4 }
  }.freeze

  FEST = {
    'Materialstaerke_Korpus'    => 1.9,
    'Materialstarke_Rueckwand'  => 0.8,
    'Rueckversatz_Einlegeboden' => 1.0   # verstellbare Einlegeböden vorne zurückgesetzt
  }.freeze
  # Standardwerte in cm
  DEFAULTS = FEST.merge(
    'Breite'            => 30.0,
    'Hoehe'             => 70.0,
    'Tiefe'             => 52.0,  # Korpus ohne Rückwand, wie die anderen Schränke
    'Form'              => 0.0,   # 0 gerade, 1 schräg, 2 rund
    'Zeilenende'        => 0.0,   # 0 rechts, 1 links
    'Tiefe_Aussen'      => 15.0,  # schräg: Tiefe der Seite außen
    'Radius'            => 30.0,  # rund: wird auf die lichte Breite begrenzt
    'Anz_Einlegeboeden' => 1.0,
    'Boeden_Art'        => 0.0,   # 0 verstellbar (Bodenträger), 1 fest (gedübelt)
    'Farbe'             => 0.0    # 0 Korpusfarbe, 1 Frontfarbe (geht mit „Frontfarbe ändern“ mit)
  ).freeze

  LAENGEN  = %w[Breite Hoehe Tiefe Tiefe_Aussen Radius Materialstaerke_Korpus Materialstarke_Rueckwand
                Rueckversatz_Einlegeboden].freeze
  OPTIONEN = %w[Form Zeilenende Anz_Einlegeboeden Boeden_Art Farbe].freeze
  MASSE    = (LAENGEN + OPTIONEN).freeze

  # Kurzhilfe in der Komponente (Kurzfassung der README.md). SketchUp zeigt
  # "summary" und "description" oben im Fenster "Komponentenoptionen".
  DOKU_URL = 'https://github.com/jimmycd/sketchup_kuechenplaner2/tree/main/Komponenten/regal_abschluss'.freeze
  HILFE_KURZ = 'Offenes Abschlussregal fürs Zeilenende: gerade, schräg oder rund, als Unter-, Ober- oder Hochschrank'.freeze
  HILFE = [
    'Breite, Höhe, Tiefe, Form (gerade, schräg, rund), Zeilenende (Seite außen rechts oder links), Tiefe außen (schräg), Radius (rund),',
    'Anzahl und Art der Einlegeböden (verstellbar auf Bodenträgern oder fest gedübelt) und Farbe hier ändern.',
    'Nach jeder Änderung baut die Erweiterung das Regal neu auf (eine Schräge oder ein Bogen lässt sich nicht per Formel umformen).',
    'Farbe „Frontfarbe“: alle Teile des Regals bekommen bei „Frontfarbe und Griffe ändern“ das Frontmaterial (ohne Griffe).',
    'Schräg- und Bogenkante haben Anleimer; die Kontur fräst der TCN-Export, zugeschnitten wird das Rechteck.',
    'Gezeichnet ist das Endmaß; den Anleimer (2 mm) ziehen Stückliste und TCN-Export ab.',
    'Jedes Teil hat einen eigenen Tag <Kürzel>_<Teil>, z. B. RA1_SeiteL, RA1_Einlegeboden1.',
    "Doku: #{DOKU_URL}"
  ].join(' ').freeze

  # ---------------------------------------------------------------------------
  # Reine Berechnung (ohne SketchUp). Werte in cm, Regal-Koordinaten:
  # x links -> rechts, y vorne -> hinten (Korpus ab y = Materialstärke wie bei den
  # anderen Schränken), z unten -> oben.
  # ---------------------------------------------------------------------------
  BOGEN_SEGMENTE = 24 # Sehnen je Viertelkreis

  def self.zahl(p, k)
    p[k].to_f
  end

  def self.form(p)
    p['Form'].to_f.round.clamp(0, 2)
  end

  def self.rechts?(p)
    p['Zeilenende'].to_f.round != 1
  end

  def self.anz_eb(p)
    p['Anz_Einlegeboeden'].to_f.round.clamp(0, MAX_EB)
  end

  def self.fest?(p)
    p['Boeden_Art'].to_f.round == 1
  end

  def self.frontfarbe?(p)
    p['Farbe'].to_f.round == 1
  end

  # Prüft die Maße; Ergebnis: lichte Breite lw, Tiefe der Seite außen ta, Radius r (rund)
  def self.masse(p)
    mk, b, h, t = zahl(p, 'Materialstaerke_Korpus'), zahl(p, 'Breite'), zahl(p, 'Hoehe'), zahl(p, 'Tiefe')
    rv = zahl(p, 'Rueckversatz_Einlegeboden')
    lw = b - 2 * mk
    raise ArgumentError, "Breite #{mm(b)} mm ist zu klein (lichte Breite mindestens 100 mm)" if lw < 10.0 - 1e-6
    raise ArgumentError, "Tiefe #{mm(t)} mm ist zu klein (mindestens 200 mm)" if t < 20.0 - 1e-6
    raise ArgumentError, "Höhe #{mm(h)} mm ist zu klein (mindestens 200 mm)" if h < 20.0 - 1e-6
    ta, r = t, nil
    case form(p)
    when SCHRAEG
      ta = zahl(p, 'Tiefe_Aussen')
      min = 5.0 + (fest?(p) ? 0.0 : rv)
      if ta < min - 1e-6 || ta > t - 2.0 + 1e-6
        raise ArgumentError, "Tiefe außen #{mm(ta)} mm geht nicht (#{mm(min)} mm bis Tiefe − 20 mm)"
      end
    when RUND
      r = [zahl(p, 'Radius'), lw, t - 5.0 - rv].min
      raise ArgumentError, "Radius #{mm(r)} mm ist zu klein (mindestens 50 mm)" if r < 5.0 - 1e-6
      ta = t - r
    end
    { lw: lw, ta: ta, r: r, mk: mk, b: b, h: h, t: t, rv: rv }
  end

  def self.mm(cm)
    (cm.to_f * 10).round
  end

  # Umriss eines Bodens (lw breit, t tief, Vorderkante bei y = 0, Seite außen bei x = lw)
  # als [Punkte gegen den Uhrzeigersinn, Kantenstücke mit Anleimer (ohne die gerade Vorderkante)]
  def self.umriss_rechts(form, lw, t, ta, r)
    case form
    when SCHRAEG
      d = t - ta
      [[[0.0, 0.0], [lw, d], [lw, t], [0.0, t]], [[:linie, [0.0, 0.0], [lw, d]]]]
    when RUND
      c = [lw - r, r]
      pts = [[0.0, 0.0]]
      pts << [lw - r, 0.0] if lw - r > 1e-6
      (1..BOGEN_SEGMENTE).each do |i|
        w = -Math::PI / 2 + Math::PI / 2 * i / BOGEN_SEGMENTE
        pts << [c[0] + r * Math.cos(w), c[1] + r * Math.sin(w)]
      end
      pts[-1] = [lw, r]
      pts << [lw, t] if t - r > 1e-6
      pts << [0.0, t]
      [pts, [[:bogen, [lw - r, 0.0], [lw, r], c, 1]]]
    else
      [[[0.0, 0.0], [lw, 0.0], [lw, t], [0.0, t]], []]
    end
  end

  # Zeilenende links: gespiegelt (x -> lw - x), Umlaufsinn bleibt gegen den Uhrzeigersinn
  def self.umriss(form, lw, t, ta, r, rechts)
    pts, kante = umriss_rechts(form, lw, t, ta, r)
    return [pts, kante] if rechts
    sp = ->(q) { [lw - q[0], q[1]] }
    [pts.map(&sp).reverse,
     kante.map { |s| s[0] == :linie ? [:linie, sp.(s[1]), sp.(s[2])] : [:bogen, sp.(s[1]), sp.(s[2]), sp.(s[3]), -s[4]] }]
  end

  # Alle Teile: { teil:, art:, pos: [x, y, z], box: [lx, ly, lz] } für Quader,
  # Böden mit umriss:/kante:/dicke: statt box. Kanten-Art siehe KANTEN.
  def self.berechne(p)
    m = masse(p)
    mk, b, h, t, lw, ta, r, rv = m.values_at(:mk, :b, :h, :t, :lw, :ta, :r, :rv)
    rw = zahl(p, 'Materialstarke_Rueckwand')
    f = form(p)
    re = rechts?(p)
    teile = []
    x_aussen = re ? b - mk : 0.0
    x_innen = re ? 0.0 : b - mk
    teile << { teil: re ? 'SeiteL' : 'SeiteR', art: 'Seite', pos: [x_innen, mk, 0.0], box: [mk, t, h] }
    teile << { teil: re ? 'SeiteR' : 'SeiteL', art: 'Seite', pos: [x_aussen, mk + t - ta, 0.0], box: [mk, ta, h] }

    boden = ->(teil, z, tiefe, y0) do
      pts, kante = umriss(f, lw, tiefe, ta - (t - tiefe), r, re)
      { teil: teil, art: 'Boden', pos: [mk, y0, z], umriss: pts, kante: kante, dicke: mk }
    end
    teile << boden.('Boden', 0.0, t, mk)
    teile << boden.('Deckel', h - mk, t, mk)
    n = anz_eb(p)
    (1..n).each do |k|
      z = mk + (h - 2 * mk) * k / (n + 1) - mk / 2.0
      if fest?(p)
        teile << boden.("Mittelboden#{k}", z, t, mk)
      else
        teile << boden.("Einlegeboden#{k}", z, t - rv, mk + rv)
      end
    end
    teile << { teil: 'Rueckwand', art: re ? 'RueckwandR' : 'RueckwandL', pos: [0.0, mk + t, 0.0], box: [b, rw, h] }
    teile
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
                    units: nil, formulaunits: nil, options: nil)
    k = name.downcase
    ent.set_attribute(DICT, k, laenge ? inch(wert) : wert)
    ent.set_attribute(DICT, "_#{k}_label", name)
    ent.set_attribute(DICT, "_#{k}_access", access)
    ent.set_attribute(DICT, "_#{k}_formlabel", formlabel || name)
    ent.set_attribute(DICT, "_#{k}_units", units || (laenge ? 'MILLIMETERS' : 'FLOAT'))
    ent.set_attribute(DICT, "_#{k}_formulaunits", formulaunits || (laenge ? 'CENTIMETERS' : 'FLOAT'))
    ent.set_attribute(DICT, "_#{k}_options", options || '')
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

  # Materialtyp und Maße im Wörterbuch "ladb_opencutlist" am Material (das eigene Plugin liest
  # daraus Plattenwerkstoff, Anleimer und Plattenformat). Vorhandene Angaben bleiben unverändert.
  def self.platten_material(model, name, farbe, attribute)
    m = model.materials[name] || model.materials.add(name)
    m.color = Sketchup::Color.new(*farbe) unless m.texture || m.get_attribute(OCL_DICT, 'type')
    if m.get_attribute(OCL_DICT, 'type').to_i == 0
      attribute.each { |k, v| m.set_attribute(OCL_DICT, k, v) }
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
                              'edge_decremented' => true) # gezeichnet ist das Endmaß
  end

  # Freies Kürzel für die Tags, z. B. RA1, RA2 …
  def self.freies_kuerzel(model)
    n = 1
    n += 1 while model.layers.to_a.any? { |l| l.name.start_with?("#{KUERZEL}#{n}_") }
    "#{KUERZEL}#{n}"
  end

  def self.tag(model, name)
    model.layers[name] || model.layers.add(name)
  end

  # Tag <Kürzel>_<Teil> und JT_Schrank am Teil; frontfarbe: das Teil geht mit „Frontfarbe ändern“ mit
  def self.kennzeichnen(model, inst, kz, teil, kategorie, frontfarbe)
    inst.layer = tag(model, "#{kz}_#{teil}")
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => kategorie, 'bereich' => '',
      'teil' => teil, 'rolle' => ROLLEN.fetch(teil.sub(/\d+\z/, '')) }.each { |k, v| inst.set_attribute(JT_DICT, k, v) }
    inst.set_attribute(JT_DICT, 'frontfarbe', true) if frontfarbe
    inst
  end

  SEITEN = { xmin: [0, -1], xmax: [0, 1], ymin: [1, -1], ymax: [1, 1], zmin: [2, -1], zmax: [2, 1] }.freeze

  # Sichtbare Kanten je Teil, bekommen Anleimer. ymin = vorne, xmin/xmax = links/rechts,
  # :kontur = Schräg- bzw. Bogenkante der Böden. Die Rückwand ist am Zeilenende von der Seite
  # sichtbar und bekommt dort eine Kante.
  KANTEN = {
    'Seite'      => %i[ymin],
    'Boden'      => %i[ymin kontur],
    'RueckwandR' => %i[xmax],
    'RueckwandL' => %i[xmin]
  }.freeze

  # Seite einer Fläche nach ihrer Normalen; nil, wenn sie nicht achsparallel ist (Schräge, Bogen)
  def self.seite(n)
    SEITEN.find { |_, (ax, vz)| n[ax] * vz > 0.9999 }&.first
  end

  def self.kanten_setzen(ents, kanten)
    return if kanten.empty?
    ents.grep(Sketchup::Face).each do |face|
      s = seite(face.normal.to_a)
      face.material = @kante if s ? kanten.include?(s) : kanten.include?(:kontur)
    end
  end

  # Quader in Endmaß
  def self.quader(ents, lx, ly, lz, kanten)
    f = ents.add_face([0, 0, 0], [inch(lx), 0, 0], [inch(lx), inch(ly), 0], [0, inch(ly), 0])
    f.reverse! if f.normal.z < 0
    f.pushpull(inch(lz))
    kanten_setzen(ents, kanten)
  end

  # Platte mit Umriss (cm, in der xy-Ebene), Stärke nach oben; die Kanten zwischen den
  # Sehnen eines Bogens werden weich, damit er rund aussieht
  def self.umriss_platte(ents, pts, dicke, kanten)
    f = ents.add_face(*pts.map { |x, y| [inch(x), inch(y), 0] })
    f.reverse! if f.normal.z < 0
    f.pushpull(inch(dicke))
    kanten_setzen(ents, kanten)
    return unless defined?(Sketchup::Edge)
    ents.grep(Sketchup::Edge).each do |e|
      fl = e.faces
      next unless fl.size == 2 && fl.none? { |x| seite(x.normal.to_a) }
      e.soft = true
      e.smooth = true
    end
  end

  def self.platte(model, defname, teil_def)
    d = model.definitions.add(defname)
    kanten = KANTEN.fetch(teil_def[:art], [])
    if teil_def[:umriss]
      umriss_platte(d.entities, teil_def[:umriss], teil_def[:dicke], kanten)
      kontur_merken(d, teil_def)
    else
      quader(d.entities, *teil_def[:box], kanten)
    end
    stempel(d)
    d.set_attribute(DICT, '_name', teil_def[:teil])
    d
  end

  # Umriss und Schräg-/Bogenkante für den TCN-Export an der Definition (Zoll, lokal)
  def self.kontur_merken(d, teil_def)
    return if teil_def[:kante].empty?
    d.set_attribute(KONTUR_DICT, 'umriss', teil_def[:umriss].flatten.map { |v| inch(v) })
    d.set_attribute(KONTUR_DICT, 'kante', teil_def[:kante].flat_map do |s|
      if s[0] == :linie then [0.0, *s[1], *s[2], 0.0, 0.0, 0.0].map(&:to_f)
      else [1.0, *s[1], *s[2], *s[3], s[4]].map(&:to_f)
      end
    end.each_with_index.map { |v, i| [0, 7].include?(i % 8) ? v : inch(v) })
  end

  def self.einsetzen(ents, defn, name, pos, mat, kz)
    tr = Geom::Transformation.translation(Geom::Vector3d.new(*pos.map { |v| inch(v) }))
    inst = ents.add_instance(defn, tr)
    inst.name = name
    inst.material = mat
    kennzeichnen(kz[0], inst, *kz[1..-1]) if kz
    inst.set_attribute(DICT, '_has_movetool_behaviors', 1.0)
    inst.set_attribute(DICT, '_hasbehaviors', 1.0)
    inst.set_attribute(DICT, '_iscollapsed', false)
    inst.set_attribute(DICT, '_lengthunits', 'CENTIMETERS')
    inst.set_attribute(DICT, '_name', name)
    inst
  end

  # ---------------------------------------------------------------------------
  # Aufbau
  # ---------------------------------------------------------------------------
  def self.listen_optionen(namen)
    '&' + namen.each_with_index.map { |n, i| "#{n.gsub(' ', '%20').gsub('ä', '%C3%A4').gsub('ü', '%C3%BC')}=#{i}" }.join('&') + '&'
  end

  def self.erzeuge(model, eingabe = {})
    typ = eingabe['Typ'] || 'Unterschrank'
    TYPEN.fetch(typ)
    p = DEFAULTS.merge(eingabe)
    teile = berechne(p)
    mat = material(model)
    kanten_material(model)
    kz = p['Kuerzel'] || freies_kuerzel(model)
    ff = frontfarbe?(p)

    haupt = model.definitions.add(NAME)
    stempel(haupt)
    haupt.set_attribute(DICT, '_name', NAME)
    hilfe(haupt)
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => typ }.each { |k, v| haupt.set_attribute(JT_DICT, k, v) }
    haupt.set_attribute(R_DICT, 'typ', typ)

    # --- Parameter (Komponentenoptionen) ---
    attribut(haupt, 'Breite', p['Breite'], access: 'TEXTBOX', formlabel: 'Breite')
    attribut(haupt, 'Hoehe', p['Hoehe'], access: 'TEXTBOX', formlabel: 'Höhe')
    attribut(haupt, 'Tiefe', p['Tiefe'], access: 'TEXTBOX', formlabel: 'Tiefe (Korpus ohne Rückwand)')
    attribut(haupt, 'Form', form(p).to_f, laenge: false, access: 'LIST', formlabel: 'Form',
             units: 'INTEGER', options: listen_optionen(FORMEN))
    attribut(haupt, 'Zeilenende', rechts?(p) ? 0.0 : 1.0, laenge: false, access: 'LIST',
             formlabel: 'Zeilenende (Seite außen)', units: 'INTEGER', options: listen_optionen(ZEILENENDE))
    attribut(haupt, 'Tiefe_Aussen', p['Tiefe_Aussen'], access: 'TEXTBOX', formlabel: 'Tiefe außen (bei schräg)')
    attribut(haupt, 'Radius', p['Radius'], access: 'TEXTBOX', formlabel: 'Radius (bei rund, höchstens lichte Breite)')
    attribut(haupt, 'Anz_Einlegeboeden', anz_eb(p).to_f, laenge: false, access: 'LIST', formlabel: 'Anzahl Einlegeböden',
             units: 'INTEGER', options: listen_optionen((0..MAX_EB).map(&:to_s)))
    attribut(haupt, 'Boeden_Art', fest?(p) ? 1.0 : 0.0, laenge: false, access: 'LIST', formlabel: 'Einlegeböden',
             units: 'INTEGER', options: listen_optionen(['verstellbar (Bodenträger)', 'fest (gedübelt)']))
    attribut(haupt, 'Farbe', ff ? 1.0 : 0.0, laenge: false, access: 'LIST', formlabel: 'Farbe',
             units: 'INTEGER', options: listen_optionen(%w[Korpusfarbe Frontfarbe]))
    FEST.each_key { |k| attribut(haupt, k, p[k], units: 'STRING') }
    haupt.set_attribute(R_DICT, R_GEBAUT, gebaut_werte(p))

    teile.each do |td|
      d = platte(model, "#{NAME} #{td[:teil]}", td)
      einsetzen(haupt.entities, d, td[:teil], td[:pos], mat, [model, kz, td[:teil], typ, ff])
    end
    haupt
  end

  # [Breite, Höhe, …] in cm bzw. als Zahl, in der Reihenfolge von MASSE
  def self.gebaut_werte(p)
    werte = p.merge('Form' => form(p), 'Zeilenende' => rechts?(p) ? 0 : 1, 'Anz_Einlegeboeden' => anz_eb(p),
                    'Boeden_Art' => fest?(p) ? 1 : 0, 'Farbe' => frontfarbe?(p) ? 1 : 0)
    MASSE.map { |k| werte[k].to_f.round(4) }
  end

  # ---------------------------------------------------------------------------
  # Nach einer Änderung in den Komponentenoptionen neu aufbauen
  # ---------------------------------------------------------------------------
  # Wert wie die DC ihn sieht: zuerst an der Instanz (dort schreibt das Fenster
  # Komponentenoptionen hin), sonst an der Definition
  def self.dc_wert(inst, k)
    v = inst.get_attribute(DICT, k.downcase)
    v = inst.definition.get_attribute(DICT, k.downcase) if v.nil?
    v
  end

  # Eingabe aus den aktuellen Werten am Schrank (cm)
  def self.eingabe_aus(inst)
    MASSE.each_with_object({}) do |k, h|
      v = dc_wert(inst, k)
      next if v.nil?
      h[k] = LAENGEN.include?(k) ? v.to_f * 2.54 : v.to_f
    end
  end

  def self.pruefen(model)
    model.definitions.to_a.select { |d| d.get_attribute(R_DICT, R_GEBAUT) }.each do |d|
      gebaut = d.get_attribute(R_DICT, R_GEBAUT)
      d.instances.to_a.each do |inst|
        neu = gebaut_werte(DEFAULTS.merge(eingabe_aus(inst)))
        neu_aufbauen(model, inst) unless neu.zip(gebaut).all? { |x, y| (x - y).abs < 0.001 }
      end
    end
  end

  def self.neu_aufbauen(model, inst)
    alt = inst.definition
    gebaut = alt.get_attribute(R_DICT, R_GEBAUT)
    p = eingabe_aus(inst)
    begin
      berechne(DEFAULTS.merge(p))
    rescue ArgumentError => e
      # ungültig: alte Werte zurück
      MASSE.zip(gebaut).each do |k, v|
        w = LAENGEN.include?(k) ? inch(v) : v.to_f
        [inst, alt].each { |ent| ent.set_attribute(DICT, k.downcase, w) unless ent.get_attribute(DICT, k.downcase).nil? }
      end
      UI.messagebox("Abschlussregal: #{e.message}. Die alten Werte bleiben.")
      return nil
    end
    p['Typ'] = alt.get_attribute(R_DICT, 'typ') || 'Unterschrank'
    p['Kuerzel'] = alt.get_attribute(JT_DICT, 'schrank')
    # Frontmaterial (Frontfarbe) der Teile merken: Material und Anleimer
    vorher = alt.entities.grep(Sketchup::ComponentInstance).each_with_object({}) do |c, h|
      kante = c.definition.entities.grep(Sketchup::Face).map(&:material).compact
               .find { |m| m.get_attribute(OCL_DICT, 'type').to_i == 4 }
      h[c.name] = [c.material, kante]
    end
    model.start_operation('Abschlussregal ändern', true, false, true)
    neu = erzeuge(model, p)
    if frontfarbe?(p)
      standard = vorher.values.find { |m, _| m && m.name != MATERIAL }
      neu.entities.grep(Sketchup::ComponentInstance).each do |c|
        m, k = vorher[c.name] || standard
        next unless m && m.name != MATERIAL
        c.material = m
        c.set_attribute(DICT, 'material', m.name)
        c.definition.entities.grep(Sketchup::Face).each { |f| f.material = k if k && f.material }
      end
    end
    inst.definition = neu
    MASSE.each do |k|
      inst.set_attribute(DICT, k.downcase, neu.get_attribute(DICT, k.downcase)) unless inst.get_attribute(DICT, k.downcase).nil?
    end
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
            RegalAbschluss.pruefen(model)
          ensure
            @laeuft = false
          end
        end
      end
    end

    class AppBeobachter < Sketchup::AppObserver
      def onNewModel(model)
        RegalAbschluss.beobachten(model)
      end

      def onOpenModel(model)
        RegalAbschluss.beobachten(model)
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
  # Neues Regal: Maße, Form und Zeilenende beim Anlegen abfragen (mm); Tiefe = Korpus ohne Rückwand.
  # Danach bleiben alle Werte im Fenster Komponentenoptionen änderbar.
  def self.dialog(typ = 'Unterschrank')
    v = TYPEN.fetch(typ)
    res = UI.inputbox(['Breite (mm)', 'Höhe (mm)', 'Tiefe Korpus (mm)', 'Form', 'Zeilenende (Seite außen)'],
                      [mm(DEFAULTS['Breite']).to_s, mm(v[:hoehe]).to_s, mm(v[:tiefe]).to_s, FORMEN[0], ZEILENENDE[0]],
                      ['', '', '', FORMEN.join('|'), ZEILENENDE.join('|')], "Abschlussregal (#{typ})")
    return unless res
    w = res[0, 3].map { |x| Float(x.to_s.tr(',', '.')) / 10.0 }
    eingabe = { 'Typ' => typ, 'Breite' => w[0], 'Hoehe' => w[1], 'Tiefe' => w[2],
                'Form' => (FORMEN.index(res[3].to_s) || 0).to_f, 'Zeilenende' => (ZEILENENDE.index(res[4].to_s) || 0).to_f,
                'Anz_Einlegeboeden' => v[:eb].to_f }
    eingabe['Tiefe_Aussen'] = [DEFAULTS['Tiefe_Aussen'], w[2] - 2.0].min
    berechne(DEFAULTS.merge(eingabe)) # prüft die Maße
    erstellen(eingabe)
  rescue ArgumentError => e
    UI.messagebox("Ungültige Eingabe: #{e.message}")
  end

  def self.erstellen(eingabe = {})
    model = Sketchup.active_model
    model.start_operation('Abschlussregal', true)
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
  RegalAbschluss::TYPEN.each do |typ, v|
    Kuechenplaner.schrank(v[:gruppe], 'Abschlussregal…') { RegalAbschluss.dialog(typ) }
  end
  if defined?(RegalAbschluss::AppBeobachter)
    Sketchup.add_observer(RegalAbschluss::AppBeobachter.new)
    RegalAbschluss.beobachten(Sketchup.active_model)
  end
  file_loaded(__FILE__)
end
