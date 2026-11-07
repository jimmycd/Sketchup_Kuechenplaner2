# encoding: UTF-8
#
# Wandregal – frei hängendes, offenes Regal an der Wand, als Dynamic Component
#
# Erweiterung (.rbz): Erweiterungen > Küchenplaner > Oberschränke > Wandregal… fragt Breite, Höhe,
# Tiefe, Unterkante über der Arbeitsplatte, Spalten, Reihen und Rückwand ab und baut das Regal.
# Danach sind alle Maße und die Fachaufteilung in den Komponentenoptionen änderbar.
#
# Frei (Jürgen 2026-11-07): das Regal reiht sich nicht an Oberschränke an und wird nicht an
# andere Schränke angedockt. Es hängt mit dem Rücken direkt an einer Wand, gleitet mit der Maus
# an ihr entlang (Tab = andere Wand), die Höhe ist Arbeitsplatte + Unterkante über Arbeitsplatte
# (Pfeil hoch/runter ändert sie beim Platzieren um 10 mm). Kategorie "Wandregal".
#
# Aufbau: Seiten über die volle Höhe (Ober- und Unterkante mit Anleimer, von unten sichtbar),
# Boden und Deckel zwischen den Seiten. Spalten 1–4: zwischen den Spalten eine senkrechte
# Mittelwand vom Boden bis zum Deckel. Jede Spalte hat ihre eigene Zahl Reihen (1–5) und
# eigene Fachhöhen; die Fachböden sind fest (gedübelt) zwischen Seite und Mittelwand.
# Breiten und Höhen: "gleich" oder lichte Maße in mm, z. B. "400;200" (Breiten von links, Höhen
# von unten); fehlende Fächer teilen sich den Rest. Rückwand ja: 8 mm in einer 9-mm-Nut in
# Seiten, Boden und Deckel, 25 mm vor der Hinterkante (Platz für die Aufhängung); Mittelwände
# und Fachböden enden vor ihr. Rückwand nein: alle Teile über die volle Tiefe, hinten mit Anleimer.
# Die Aufteilung lässt sich nicht per DC-Formel umbauen, deshalb baut die Erweiterung das Regal
# nach jeder Änderung in den Komponentenoptionen neu auf (wie das Abschlussregal).
#
# Materialien und Anleimer: Platten "Melamin weiss" (Plattenwerkstoff), sichtbare Kanten
# "Anleimer Melamin weiss" (2 mm). Gezeichnet wird das Endmaß. Jedes Teil hat einen eigenen Tag
# <Kürzel>_<Teil> (z. B. WR1_SeiteL, WR1_Mittelwand1, WR1_Mittelboden2) und das Wörterbuch "JT_Schrank".

require 'sketchup.rb'
require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'eingabe') # Eingabefenster im Treppenplaner-Stil
require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'neuladen') # Neu laden ohne Neustart (Wächter)

module Wandregal

  DICT     = 'dynamic_attributes'.freeze
  NAME     = 'Wandregal'.freeze
  MATERIAL = 'Melamin weiss'.freeze
  KANTE    = 'Anleimer Melamin weiss'.freeze
  OCL_DICT = 'ladb_opencutlist'.freeze
  KUERZEL  = 'WR'.freeze
  MAX_SPALTEN = 4
  MAX_REIHEN  = 5
  MIN_FACH    = 5.0 # cm, kleinstes lichtes Fach

  # Tag-Schema für den TCN-Export (gleich in allen Komponenten, der Test prüft das):
  # Tag <Kürzel>_<Teil>, dazu am Teil das Wörterbuch JT_Schrank.
  JT_DICT   = 'JT_Schrank'.freeze
  TYP       = 'Wandregal'.freeze
  KATEGORIE = 'Wandregal'.freeze # eigene Kategorie: keine Zeile mit Oberschränken, kein Andocken
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

  # Maße, mit denen das Regal gebaut ist (für den Neuaufbau nach einer Änderung)
  R_DICT   = 'JT_Regal'.freeze
  R_GEBAUT = 'gebaut'.freeze
  GLEICH   = 'gleich'.freeze
  RUECKWAND = %w[ja nein].freeze

  FEST = {
    'Materialstarke_Rueckwand' => 0.8,
    'Rueckwand_Versatz'        => 2.5, # Hinterkante Seite -> Rückseite Rückwand (Platz für die Aufhängung)
    'Nuttiefe'                 => 0.9
  }.freeze
  # Standardwerte in cm
  DEFAULTS = FEST.merge(
    'Breite'                 => 60.0,
    'Hoehe'                  => 35.0,
    'Tiefe'                  => 25.0, # Tiefe der Seiten (mit Rückwand)
    'Abstand_AP'             => 50.0, # Unterkante Regal über Oberkante Arbeitsplatte
    'Materialstaerke_Korpus' => 1.9,
    'Spalten'                => 1.0,
    'Breiten'                => GLEICH,
    'Rueckwand'              => 0.0, # 0 ja, 1 nein
    'Farbe'                  => 0.0  # 0 Korpusfarbe, 1 Frontfarbe (geht mit „Frontfarbe ändern“ mit)
  ).merge((1..MAX_SPALTEN).flat_map { |c| [["Reihen_#{c}", 2.0], ["Hoehen_#{c}", GLEICH]] }.to_h).freeze

  LAENGEN  = (%w[Breite Hoehe Tiefe Abstand_AP Materialstaerke_Korpus] + FEST.keys).freeze
  TEXTE    = (['Breiten'] + (1..MAX_SPALTEN).map { |c| "Hoehen_#{c}" }).freeze
  OPTIONEN = (%w[Spalten Rueckwand Farbe] + (1..MAX_SPALTEN).map { |c| "Reihen_#{c}" }).freeze
  MASSE    = (LAENGEN + OPTIONEN + TEXTE).freeze

  # Kurzhilfe in der Komponente (Kurzfassung der README.md), steht oben im Fenster "Komponentenoptionen".
  DOKU_URL = 'https://github.com/jimmycd/sketchup_kuechenplaner2/tree/main/Komponenten/wandregal'.freeze
  HILFE_KURZ = 'Frei hängendes Wandregal: Spalten mit Mittelwand, je Spalte eigene Reihen und Fachhöhen ("gleich" oder z. B. 150;250 mm), feste Fachböden'.freeze

  # ---------------------------------------------------------------------------
  # Reine Berechnung (ohne SketchUp). Werte in cm, Regal-Koordinaten:
  # x links -> rechts, y vorne -> hinten (Korpus ab y = Materialstärke wie bei den
  # anderen Schränken), z unten -> oben.
  # ---------------------------------------------------------------------------
  def self.zahl(p, k)
    p[k].to_f
  end

  def self.spalten(p)
    p['Spalten'].to_f.round.clamp(1, MAX_SPALTEN)
  end

  def self.reihen(p, c)
    (p["Reihen_#{c}"] || DEFAULTS["Reihen_#{c}"]).to_f.round.clamp(1, MAX_REIHEN)
  end

  def self.rueckwand?(p)
    p['Rueckwand'].to_f.round != 1
  end

  def self.frontfarbe?(p)
    p['Farbe'].to_f.round == 1
  end

  def self.mm(cm)
    (cm.to_f * 10).round
  end

  def self.text(v)
    s = v.to_s.strip
    s.empty? ? GLEICH : s
  end

  # Aufteilung "gleich" oder lichte Maße in mm ("400;200"), Ergebnis: n lichte Maße in cm.
  # gesamt = lichtes Maß ohne die (n - 1) Trennplatten der Stärke mk. Fehlende Werte teilen sich
  # den Rest; bei n oder mehr Werten ergibt sich der letzte aus dem Rest.
  def self.aufteilung(wert, n, gesamt, mk, was)
    s = text(wert)
    werte = s.downcase == GLEICH ? [] : s.split(/[;\s]+/).reject(&:empty?).map do |x|
      Float(x.tr(',', '.')) / 10.0
    rescue ArgumentError
      raise ArgumentError, "#{was} „#{s}“: bitte „gleich“ oder Maße in mm wie 400;200"
    end
    werte = werte.first(n - 1) if werte.size >= n
    frei = gesamt - (n - 1) * mk
    rest = frei - werte.sum
    m = n - werte.size
    liste = werte + [rest / m] * m
    if liste.any? { |x| x < MIN_FACH - 1e-6 }
      raise ArgumentError, "#{was}: Fach #{mm(liste.min)} mm ist zu klein (lichte Maße zusammen #{mm(frei)} mm, je Fach mindestens #{mm(MIN_FACH)} mm)"
    end
    liste
  end

  # Prüft die Maße; Ergebnis mit den lichten Breiten je Spalte und den lichten Höhen je Spalte
  def self.masse(p)
    mk, b, h, t = zahl(p, 'Materialstaerke_Korpus'), zahl(p, 'Breite'), zahl(p, 'Hoehe'), zahl(p, 'Tiefe')
    raise ArgumentError, "Materialstärke #{mm(mk)} mm geht nicht (16 bis 30 mm)" unless mk.between?(1.6 - 1e-6, 3.0 + 1e-6)
    raise ArgumentError, "Tiefe #{mm(t)} mm geht nicht (100 bis 800 mm)" unless t.between?(10.0 - 1e-6, 80.0 + 1e-6)
    raise ArgumentError, "Höhe #{mm(h)} mm ist zu klein (mindestens 100 mm)" if h < 10.0 - 1e-6
    raise ArgumentError, "Breite #{mm(b)} mm ist zu klein (mindestens 100 mm)" if b < 10.0 - 1e-6
    rw, vs = zahl(p, 'Materialstarke_Rueckwand'), zahl(p, 'Rueckwand_Versatz')
    ti = rueckwand?(p) ? t - vs - rw : t
    raise ArgumentError, "Tiefe #{mm(t)} mm ist zu klein für die Rückwand" if ti < 5.0
    s = spalten(p)
    breiten = aufteilung(p['Breiten'], s, b - 2 * mk, mk, 'Breiten')
    hoehen = (1..s).map { |c| aufteilung(p["Hoehen_#{c}"], reihen(p, c), h - 2 * mk, mk, "Höhen Spalte #{c}") }
    { mk: mk, b: b, h: h, t: t, ti: ti, rw: rw, breiten: breiten, hoehen: hoehen }
  end

  # Alle Teile: { teil:, art:, pos: [x, y, z], box: [lx, ly, lz] }. Kanten-Art siehe KANTEN.
  def self.berechne(p)
    m = masse(p)
    mk, b, h, t, ti, rw = m.values_at(:mk, :b, :h, :t, :ti, :rw)
    offen = rueckwand?(p) ? '' : 'Offen'
    teile = []
    teile << { teil: 'SeiteL', art: "Seite#{offen}", pos: [0.0, mk, 0.0], box: [mk, t, h] }
    teile << { teil: 'SeiteR', art: "Seite#{offen}", pos: [b - mk, mk, 0.0], box: [mk, t, h] }
    teile << { teil: 'Boden', art: "Platte#{offen}", pos: [mk, mk, 0.0], box: [b - 2 * mk, t, mk] }
    teile << { teil: 'Deckel', art: "Platte#{offen}", pos: [mk, mk, h - mk], box: [b - 2 * mk, t, mk] }
    x = mk
    nb = 0
    m[:breiten].each_with_index do |w, i|
      if i > 0
        teile << { teil: "Mittelwand#{i}", art: "Platte#{offen}", pos: [x, mk, mk], box: [mk, ti, h - 2 * mk] }
        x += mk
      end
      z = mk
      m[:hoehen][i][0..-2].each do |fh|
        z += fh
        nb += 1
        teile << { teil: "Mittelboden#{nb}", art: "Platte#{offen}", pos: [x, mk, z], box: [w, ti, mk], spalte: i + 1 }
        z += mk
      end
      x += w
    end
    if rueckwand?(p)
      nut = zahl(p, 'Nuttiefe')
      teile << { teil: 'Rueckwand', art: 'Rueckwand', pos: [mk - nut, mk + ti, mk - nut],
                 box: [b - 2 * mk + 2 * nut, rw, h - 2 * mk + 2 * nut] }
    end
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
    ent.set_attribute(DICT, "_#{k}_options", dc_optionen(options))
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

  # Freies Kürzel für die Tags, z. B. WR1, WR2 …
  def self.freies_kuerzel(model)
    n = 1
    n += 1 while model.layers.to_a.any? { |l| l.name.start_with?("#{KUERZEL}#{n}_") }
    "#{KUERZEL}#{n}"
  end

  def self.tag(model, name)
    model.layers[name] || model.layers.add(name)
  end

  # Tag <Kürzel>_<Teil> und JT_Schrank am Teil; frontfarbe: das Teil geht mit „Frontfarbe ändern“ mit
  def self.kennzeichnen(model, inst, kz, teil, frontfarbe)
    inst.layer = tag(model, "#{kz}_#{teil}")
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE, 'bereich' => '',
      'teil' => teil, 'rolle' => ROLLEN.fetch(teil.sub(/\d+\z/, '')) }.each { |k, v| inst.set_attribute(JT_DICT, k, v) }
    inst.set_attribute(JT_DICT, 'frontfarbe', true) if frontfarbe
    inst
  end

  SEITEN = { xmin: [0, -1], xmax: [0, 1], ymin: [1, -1], ymax: [1, 1], zmin: [2, -1], zmax: [2, 1] }.freeze

  # Sichtbare Kanten je Teil, bekommen Anleimer. ymin = vorne, ymax = hinten (nur ohne Rückwand),
  # zmin/zmax = Unter- und Oberkante der Seiten (das Regal hängt, beide sind zu sehen).
  KANTEN = {
    'Seite'       => %i[ymin zmin zmax],
    'SeiteOffen'  => %i[ymin ymax zmin zmax],
    'Platte'      => %i[ymin],
    'PlatteOffen' => %i[ymin ymax]
  }.freeze

  def self.seite(n)
    SEITEN.find { |_, (ax, vz)| n[ax] * vz > 0.9999 }&.first
  end

  def self.kanten_setzen(ents, kanten)
    return if kanten.empty?
    ents.grep(Sketchup::Face).each do |face|
      s = seite(face.normal.to_a)
      face.material = @kante if s && kanten.include?(s)
    end
  end

  # Quader in Endmaß
  def self.quader(ents, lx, ly, lz, kanten)
    f = ents.add_face([0, 0, 0], [inch(lx), 0, 0], [inch(lx), inch(ly), 0], [0, inch(ly), 0])
    f.reverse! if f.normal.z < 0
    f.pushpull(inch(lz))
    kanten_setzen(ents, kanten)
  end

  def self.platte(model, defname, teil_def)
    d = model.definitions.add(defname)
    quader(d.entities, *teil_def[:box], KANTEN.fetch(teil_def[:art], []))
    stempel(d)
    d.set_attribute(DICT, '_name', teil_def[:teil])
    d
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

  # Werte wie gebaut (Zahlen gerundet, Texte bereinigt); Spalten über der Anzahl zählen nicht
  def self.normal(p)
    s = spalten(p)
    MASSE.each_with_object({}) do |k, h|
      c = k[/_(\d)\z/, 1].to_i
      h[k] = if c > s && (k.start_with?('Reihen_') || k.start_with?('Hoehen_')) then nil
             elsif TEXTE.include?(k) then text(p[k])
             elsif k.start_with?('Reihen_') then reihen(p, c)
             elsif k == 'Spalten' then s
             elsif k == 'Rueckwand' then rueckwand?(p) ? 0 : 1
             elsif k == 'Farbe' then frontfarbe?(p) ? 1 : 0
             else p[k].to_f.round(4)
             end
    end
  end

  def self.gebaut_werte(p)
    n = normal(p)
    MASSE.map { |k| n[k].nil? ? '' : n[k].to_s }
  end

  def self.erzeuge(model, eingabe = {})
    p = DEFAULTS.merge(eingabe)
    teile = berechne(p)
    mat = material(model)
    kanten_material(model)
    kz = p['Kuerzel'] || freies_kuerzel(model)
    ff = frontfarbe?(p)
    s = spalten(p)

    haupt = model.definitions.add(NAME)
    stempel(haupt)
    haupt.set_attribute(DICT, '_name', NAME)
    hilfe(haupt)
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE }.each { |k, v| haupt.set_attribute(JT_DICT, k, v) }

    # --- Parameter (Komponentenoptionen) ---
    attribut(haupt, 'Breite', p['Breite'], access: 'TEXTBOX', formlabel: 'Breite')
    attribut(haupt, 'Hoehe', p['Hoehe'], access: 'TEXTBOX', formlabel: 'Höhe')
    attribut(haupt, 'Tiefe', p['Tiefe'], access: 'TEXTBOX', formlabel: 'Tiefe')
    attribut(haupt, 'Abstand_AP', p['Abstand_AP'], access: 'TEXTBOX', formlabel: 'Unterkante über Arbeitsplatte')
    attribut(haupt, 'Materialstaerke_Korpus', p['Materialstaerke_Korpus'], access: 'TEXTBOX', formlabel: 'Materialstärke')
    attribut(haupt, 'Rueckwand', rueckwand?(p) ? 0.0 : 1.0, laenge: false, access: 'LIST', formlabel: 'Rückwand',
             units: 'INTEGER', options: listen_optionen(RUECKWAND))
    attribut(haupt, 'Farbe', ff ? 1.0 : 0.0, laenge: false, access: 'LIST', formlabel: 'Farbe',
             units: 'INTEGER', options: listen_optionen(%w[Korpusfarbe Frontfarbe]))
    attribut(haupt, 'Spalten', s.to_f, laenge: false, access: 'LIST', formlabel: 'Spalten (mit Mittelwand)',
             units: 'INTEGER', options: listen_optionen((1..MAX_SPALTEN).map(&:to_s)))
    attribut(haupt, 'Breiten', text(p['Breiten']), laenge: false, access: 'TEXTBOX', units: 'STRING', formulaunits: 'STRING',
             formlabel: 'Breiten lichte mm von links (gleich oder z. B. 400;200)')
    # nur die vorhandenen Spalten; mehr Spalten -> Neuaufbau legt die Felder an
    (1..s).each do |c|
      attribut(haupt, "Reihen_#{c}", reihen(p, c).to_f, laenge: false, access: 'LIST', formlabel: "Spalte #{c}: Reihen",
               units: 'INTEGER', options: listen_optionen((1..MAX_REIHEN).map(&:to_s)))
      attribut(haupt, "Hoehen_#{c}", text(p["Hoehen_#{c}"]), laenge: false, access: 'TEXTBOX', units: 'STRING',
               formulaunits: 'STRING', formlabel: "Spalte #{c}: Höhen lichte mm von unten (gleich oder z. B. 150;250)")
    end
    FEST.each_key { |k| attribut(haupt, k, p[k], units: 'STRING') }
    haupt.set_attribute(R_DICT, R_GEBAUT, gebaut_werte(p))

    teile.each do |td|
      d = platte(model, "#{NAME} #{td[:teil]}", td)
      c = einsetzen(haupt.entities, d, td[:teil], td[:pos], mat, [model, kz, td[:teil], ff])
      c.set_attribute(JT_DICT, 'spalte', td[:spalte]) if td[:spalte]
    end
    haupt
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

  # Eingabe aus den aktuellen Werten am Regal (cm)
  def self.eingabe_aus(inst)
    MASSE.each_with_object({}) do |k, h|
      v = dc_wert(inst, k)
      next if v.nil?
      h[k] = if LAENGEN.include?(k) then v.to_f * 2.54
             elsif TEXTE.include?(k) then v.to_s
             else v.to_f
             end
    end
  end

  def self.pruefen(model)
    model.definitions.to_a.select { |d| d.get_attribute(R_DICT, R_GEBAUT) && d.get_attribute(JT_DICT, 'typ') == TYP }.each do |d|
      gebaut = d.get_attribute(R_DICT, R_GEBAUT)
      d.instances.to_a.each do |inst|
        neu = gebaut_werte(DEFAULTS.merge(eingabe_aus(inst)))
        neu_aufbauen(model, inst) unless neu == gebaut && !groesse_falsch?(inst)
      end
    end
  end

  # Die DC merkt sich die Größe an der Instanz (lenx/leny/lenz) und skaliert beim Neuzeichnen
  # darauf. Nach dem Tausch der Definition deshalb die neue Größe eintragen und eine Skalierung
  # der Instanz zurücknehmen (wie beim Abschlussregal).
  def self.groesse_uebernehmen(inst)
    t = inst.transformation.to_a
    achsen = [t[0, 3], t[4, 3], t[8, 3]].map do |a|
      l = Math.sqrt(a.sum { |v| v * v })
      l > 1e-9 ? a.map { |v| v / l } : a
    end
    skaliert = [t[0, 3], t[4, 3], t[8, 3]].any? { |a| (Math.sqrt(a.sum { |v| v * v }) - 1.0).abs > 1e-6 }
    if skaliert
      inst.transformation = Geom::Transformation.new(achsen[0] + [0.0] + achsen[1] + [0.0] + achsen[2] + [0.0] + t[12, 3] + [1.0])
    end
    bb = inst.definition.bounds
    return unless bb.respond_to?(:width)
    groesse = [bb.width, bb.height, bb.depth].map(&:to_f)
    %w[lenx leny lenz].zip(groesse).each do |k, v|
      [inst, inst.definition].each do |e|
        e.set_attribute(DICT, k, v)
        e.set_attribute(DICT, "_#{k}_nominal", v)
        e.set_attribute(DICT, "_#{k}_formula", format('%.4f', v * 2.54))
      end
    end
    inst.definition.set_attribute(GROESSE_DICT, 'zoll', groesse)
  end

  GROESSE_DICT = 'JT_Groesse'.freeze
  def self.groesse_falsch?(inst)
    soll = inst.definition.get_attribute(GROESSE_DICT, 'zoll')
    bb = inst.definition.bounds
    return false unless bb.respond_to?(:width)
    return true unless soll.is_a?(Array) && soll.size == 3
    [bb.width, bb.height, bb.depth].zip(soll).any? { |a, b| (a.to_f - b.to_f).abs > 0.02 }
  end

  # Unterkante über Arbeitsplatte geändert: das Regal um die Differenz (Zoll) heben oder senken
  def self.hoehe_nachfuehren(inst, d)
    return if d.abs < 1e-9
    t = inst.transformation.to_a
    t[14] += d
    inst.transformation = Geom::Transformation.new(t)
  end

  # Andock-Werkzeug hat die Höhe beim Platzieren geändert: Unterkante über Arbeitsplatte (Zoll)
  # am Regal und in den gebauten Werten eintragen, damit kein Neuaufbau es wieder verschiebt
  def self.abstand_setzen(inst, zoll)
    k = 'abstand_ap'
    [inst, inst.definition].each { |e| e.set_attribute(DICT, k, zoll.to_f) }
    gebaut = inst.definition.get_attribute(R_DICT, R_GEBAUT)
    return unless gebaut.is_a?(Array)
    gebaut = gebaut.dup
    gebaut[MASSE.index('Abstand_AP')] = (zoll.to_f * 2.54).round(4).to_s
    inst.definition.set_attribute(R_DICT, R_GEBAUT, gebaut)
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
        next if v.to_s.empty?
        w = if LAENGEN.include?(k) then inch(v.to_f)
            elsif TEXTE.include?(k) then v.to_s
            else v.to_f
            end
        [inst, alt].each { |ent| ent.set_attribute(DICT, k.downcase, w) unless ent.get_attribute(DICT, k.downcase).nil? }
      end
      UI.messagebox("Wandregal: #{e.message}. Die alten Werte bleiben.")
      return nil
    end
    p['Kuerzel'] = alt.get_attribute(JT_DICT, 'schrank')
    abstand_alt = gebaut[MASSE.index('Abstand_AP')].to_f
    # Frontmaterial (Frontfarbe) der Teile merken: Material und Anleimer
    vorher = alt.entities.grep(Sketchup::ComponentInstance).each_with_object({}) do |c, h|
      kante = c.definition.entities.grep(Sketchup::Face).map(&:material).compact
               .find { |m| m.get_attribute(OCL_DICT, 'type').to_i == 4 }
      h[c.name] = [c.material, kante]
    end
    model.start_operation('Wandregal ändern', true, false, true)
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
    groesse_uebernehmen(inst)
    hoehe_nachfuehren(inst, inch(DEFAULTS.merge(p)['Abstand_AP'].to_f - abstand_alt))
    # Felder an der Instanz auf die neuen Werte; Spalten, die es nicht mehr gibt, entfernen
    MASSE.each do |k|
      next if inst.get_attribute(DICT, k.downcase).nil?
      v = neu.get_attribute(DICT, k.downcase)
      v.nil? ? inst.delete_attribute(DICT, k.downcase) : inst.set_attribute(DICT, k.downcase, v)
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
        # Timer sofort anhalten: sonst feuert er erneut, solange eine Meldung
        # (UI.messagebox beim Neuaufbau) offen ist
        id = UI.start_timer(0, false) do
          UI.stop_timer(id)
          begin
            Wandregal.pruefen(model)
          ensure
            @laeuft = false
          end
        end
      end
    end

    class AppBeobachter < Sketchup::AppObserver
      def onNewModel(model)
        Wandregal.beobachten(model)
      end

      def onOpenModel(model)
        Wandregal.beobachten(model)
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
  # Neues Regal: Maße, Höhe über der Arbeitsplatte, Spalten, Reihen und Rückwand abfragen (mm).
  # Breiten und Höhen der Fächer sind zuerst gleich, alles Weitere in den Komponentenoptionen.
  def self.dialog
    Kuechenplaner::Eingabe.abfragen(['Breite (mm)', 'Höhe (mm)', 'Tiefe Korpus (mm)', 'Unterkante über Arbeitsplatte (mm)',
                                     'Spalten', 'Reihen je Spalte', 'Rückwand'],
                                    [mm(DEFAULTS['Breite']).to_s, mm(DEFAULTS['Hoehe']).to_s, mm(DEFAULTS['Tiefe']).to_s,
                                     mm(DEFAULTS['Abstand_AP']).to_s, '1', '2', RUECKWAND[0]],
                                    ['', '', '', '', (1..MAX_SPALTEN).to_a.join('|'), (1..MAX_REIHEN).to_a.join('|'),
                                     RUECKWAND.join('|')], 'Wandregal', untertitel: 'Neuer Schrank', ok: 'Einfügen') do |res|
      w = res[0, 4].map { |x| Float(x.to_s.tr(',', '.')) / 10.0 }
      r = res[5].to_f
      eingabe = { 'Breite' => w[0], 'Hoehe' => w[1], 'Tiefe' => w[2], 'Abstand_AP' => w[3], 'Spalten' => res[4].to_f,
                  'Rueckwand' => (RUECKWAND.index(res[6].to_s) || 0).to_f }
      (1..MAX_SPALTEN).each { |c| eingabe["Reihen_#{c}"] = r }
      berechne(DEFAULTS.merge(eingabe)) # prüft die Maße
      erstellen(eingabe)
    end
  rescue ArgumentError => e
    UI.messagebox("Ungültige Eingabe: #{e.message}")
  end

  def self.erstellen(eingabe = {})
    model = Sketchup.active_model
    model.start_operation('Wandregal', true)
    defn = erzeuge(model, eingabe)
    x = model.entities.length > 0 ? model.bounds.max.x + 10.cm : 0
    inst = model.entities.add_instance(defn, Geom::Transformation.translation([x, 0, 0]))
    inst.name = NAME
    inst.set_attribute(DICT, '_name', NAME)
    groesse_uebernehmen(inst)
    model.commit_operation

    if defined?($dc_observers) && $dc_observers
      $dc_observers.get_latest_class.redraw_with_undo(inst)
    end
    # Andock-Werkzeug (Schrank-CNC): das Wandregal hängt frei an der Wand, kein Anreihen
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
  Kuechenplaner.schrank('Oberschränke', 'Wandregal…') { Wandregal.dialog }
  if defined?(Wandregal::AppBeobachter)
    Sketchup.add_observer(Wandregal::AppBeobachter.new)
    Wandregal.beobachten(Sketchup.active_model)
  end
  file_loaded(__FILE__)
end
