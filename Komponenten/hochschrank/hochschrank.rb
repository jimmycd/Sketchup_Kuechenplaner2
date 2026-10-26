# encoding: UTF-8
#
# Hochschrank – erzeugt eine Dynamic Component und speichert sie als .skp
#
# Kein Plugin: einmal in der Ruby-Konsole laden, z. B.
#   load 'C:/Users/<Name>/Downloads/hochschrank.rb'
# Das Skript baut den Hochschrank im aktuellen Modell und speichert ihn als
# "Hochschrank.skp" neben diese Datei. Danach wird das Skript nicht mehr
# gebraucht, die .skp ist eine normale Dynamic Component.
#
# Aufbau von unten nach oben:
#   Unten: 1–6 Schubladen, Aufteilung über Anteil_U1..U6 (1 = oben)
#   Mitte: offenes Fach (z. B. Backofen, lichte Höhe einstellbar) oder 1–4 Schubladen
#   Oben:  offenes Fach oder mit Tür, 0–3 Einlegeböden
#
# Korpus und Schubladen wie beim Unterschrank (19 mm Korpus, 8 mm Rückwand,
# 2 mm Fugen). Ausgeblendete Teile werden im Korpus geparkt, damit sie den
# Auswahlrahmen nicht vergrößern.
#
# OpenCutList: Platten haben das Material "Melamin weiss" (Plattenwerkstoff),
# sichtbare Kanten das Material "Anleimer Melamin weiss" (Kante, 2 mm, wird nur
# in OCL abgezogen; gezeichnet wird das Endmaß). Jedes Teil hat einen eigenen Tag
# <Kürzel>_<Bereich>_<Teil> (z. B. HS1_SeiteL, HS1_U1_Front) und das Wörterbuch
# "JT_Schrank" für den TCN-Export. Anderes Kürzel: Hochschrank.erstellen({ 'Kuerzel' => 'HS2' }, ziel)

require 'sketchup.rb'

module Hochschrank

  DICT     = 'dynamic_attributes'.freeze
  NAME     = 'Hochschrank'.freeze
  MAX_U    = 6
  MAX_M    = 4
  MAX_EB   = 3
  PARK_HOEHE = 10.0 # cm
  MATERIAL = 'Melamin weiss'.freeze
  KANTE    = 'Anleimer Melamin weiss'.freeze
  OCL_DICT = 'ladb_opencutlist'.freeze
  KUERZEL  = 'HS'.freeze

  # Tag-Schema für den TCN-Export (gleich in allen Komponenten, der Test prüft das):
  # Tag <Kürzel>_<Bereich>_<Teil>, dazu am Teil das Wörterbuch JT_Schrank.
  JT_DICT   = 'JT_Schrank'.freeze
  TYP       = 'Hochschrank'.freeze
  KATEGORIE = 'Hochschrank'.freeze # Unterschrank, Oberschrank oder Hochschrank
  ROLLEN = {
    'SeiteL' => 'Seite', 'SeiteR' => 'Seite', 'Boden' => 'Boden', 'Deckel' => 'Deckel',
    'StrebeVorn' => 'Strebe', 'StrebeHinten' => 'Strebe',
    'ZwischenbodenUnten' => 'Zwischenboden', 'ZwischenbodenOben' => 'Zwischenboden',
    'Rueckwand' => 'Rueckwand', 'Einlegeboden' => 'Einlegeboden', 'Front' => 'Front',
    'Tuer' => 'Tuer', 'TuerL' => 'Tuer', 'TuerR' => 'Tuer',
    'KastenBoden' => 'KastenBoden', 'KastenRueckwand' => 'KastenRueckwand',
    'Blende' => 'Front'
  }.freeze

  # Standardwerte in cm
  DEFAULTS = {
    'Breite'                      => 60.0,
    'Hoehe'                       => 210.0,
    'Tiefe'                       => 80.0,
    'H_Unten'                     => 70.0,  # Oberkante Zwischenboden unten
    'H_Mitte'                     => 60.0,  # lichte Höhe Mittelfach
    'Art_Mitte'                   => 0.0,   # 0 = offenes Fach, 1 = Schubladen
    'Art_Oben'                    => 1.0,   # 0 = offenes Fach, 1 = Tür
    'Anz_Schubladen_Unten'        => 3.0,
    'Anz_Schubladen_Mitte'        => 2.0,
    'Anz_Einlegeboeden_Oben'      => 1.0,
    'Materialstaerke_Korpus'      => 1.9,
    'Materialstarke_Rueckwand'    => 0.8,
    'Spaltbreite'                 => 0.2,
    # Schubkasten Blum LEGRABOX free (Montageanleitung MD-015/4): Metallzargen, aus Holz nur
    # Boden (LW-35 x NL-10, 16 mm) und Holzrückwand (LW-38 x 148, auf dem Boden)
    'Materialstaerke_Kastenboden' => 1.6,
    'Materialstaerke_Kastenrueckwand' => 1.6,
    'Hoehe_Kastenrueckwand'       => 14.8,
    'Hoehenoffset_Schiene'        => 0.0,  # Schienenbohrung über Unterkante Kasten
    'Lochraster_Start'            => 3.5,  # erste Rasterbohrung über Unterkante Seite
    'Lochraster'                  => 3.2,
    'Kasten_Abstand_unten'        => 3.0,
    'Kasten_Abstand_oben'         => 3.0,
    'Auszug_Anteil'               => 0.8,
    'Rueckversatz_Einlegeboden'   => 1.0   # Einlegeböden vorne zurückgesetzt
  }.merge((1..MAX_U).to_h { |i| ["Anteil_U#{i}", 1.0] })
   .merge((1..MAX_M).to_h { |i| ["Anteil_M#{i}", 1.0] }).freeze

  # Kurzhilfe in der Komponente (Kurzfassung der README.md). SketchUp zeigt
  # "summary" und "description" oben im Fenster "Komponentenoptionen".
  DOKU_URL = 'https://github.com/jimmycd/sketchup_kuechenplaner2/tree/main/Komponenten/hochschrank'.freeze
  HILFE_KURZ = 'Hochschrank: unten Schubladen, Mitte offenes Fach oder Schubladen, oben offenes Fach oder Tür'.freeze
  HILFE = [
    'Unten: Höhe bis Oberkante Zwischenboden, 1–6 Schubladen. Mitte: offenes Fach (lichte Höhe, z. B. Backofen) oder 1–4 Schubladen.',
    'Oben: offenes Fach oder Tür, 0–3 Einlegeböden; die Höhe ergibt sich aus dem Rest.',
    'Anteile: 1/1/2 = unterste doppelt so hoch, Schublade 1 = oben; mm-Werte werden auf die Bereichshöhe skaliert.',
    'Mit „Interagieren“ fahren Schubladen heraus, die Tür öffnet sich.',
    'Gezeichnet ist das Endmaß; den Anleimer (2 mm) zieht nur OpenCutList ab.',
    'Jedes Teil hat einen eigenen Tag <Kürzel>_<Bereich>_<Teil>, z. B. HS1_SeiteL, HS1_U1_Front, HS1_O_Tuer.',
    'Feste Maße (Materialstärken, Abstände): Fenster „Komponentenattribute“.',
    "Doku: #{DOKU_URL}"
  ].join(' ').freeze

  # Bereiche mit Schubladen: Präfix, Anzahl-Attribut, Max, Unterkante, Oberkante Fronten, Sichtbarkeit
  def self.bereiche
    {
      'U' => { anz: 'Anz_Schubladen_Unten', max: MAX_U,
               z0: '0', top: '(H_Unten-Spaltbreite)', bed: nil },
      'M' => { anz: 'Anz_Schubladen_Mitte', max: MAX_M,
               z0: 'H_Unten', top: '(H_Unten+H_Mitte+Materialstaerke_Korpus-Spaltbreite)', bed: 'Art_Mitte=1' }
    }
  end

  # ---------------------------------------------------------------------------
  # Reine Berechnung (ohne SketchUp), spiegelt die DC-Formeln. Werte in cm.
  # ---------------------------------------------------------------------------
  def self.berechne(p)
    mk, sp = p['Materialstaerke_Korpus'], p['Spaltbreite']
    z_oben = p['H_Unten'] + p['H_Mitte'] + mk
    erg = { z_oben: z_oben, h_oben: p['Hoehe'] - z_oben }
    { 'U' => [0.0, p['H_Unten'] - sp], 'M' => [p['H_Unten'], z_oben - sp] }.each do |b, (z0, top)|
      cfg = bereiche[b]
      n = p[cfg[:anz]].to_i
      ant = (1..cfg[:max]).map { |i| p["Anteil_#{b}#{i}"].to_f }
      summe = ant.first(n).sum
      netto = top - z0 - (n - 1) * sp
      erg[b] = (1..cfg[:max]).map do |i|
        if i <= n
          { h: netto * ant[i - 1] / summe,
            z: top - netto * ant.first(i).sum / summe - (i - 1) * sp }
        else
          { h: PARK_HOEHE, z: z0 + mk }
        end
      end
    end
    n_eb = p['Anz_Einlegeboeden_Oben'].to_i
    erg[:eb] = (1..MAX_EB).map { |k| k <= n_eb ? z_oben + (p['Hoehe'] - mk - z_oben) * k / (n_eb + 1) - mk / 2 : z_oben }
    erg
  end

  # Unterkante Kasten über Unterkante Front (cm): mindestens Kasten_Abstand_unten und so, dass
  # die Schienenbohrung (Unterkante Kasten + Höhenoffset) auf dem Lochraster der Seite liegt
  # (Lochraster_Start + n * Lochraster, gemessen ab Unterkante Seite).
  def self.kasten_unten(p, z_front)
    st, ra, off = p['Lochraster_Start'], p['Lochraster'], p['Hoehenoffset_Schiene']
    n = ((z_front + p['Kasten_Abstand_unten'] + off - st) / ra - 0.0001).ceil
    st + ra * n - off - z_front
  end

  # dieselbe Rechnung als DC-Formel (INT rundet ab, -INT(-x) also auf)
  def self.f_kasten_unten(z_front)
    u = NAME
    "#{u}!Lochraster_Start+#{u}!Lochraster*(-INT(-((#{z_front}+#{u}!Kasten_Abstand_unten+#{u}!Hoehenoffset_Schiene" \
      "-#{u}!Lochraster_Start)/#{u}!Lochraster-0.0001)))-#{u}!Hoehenoffset_Schiene-#{z_front}"
  end

  # ---------------------------------------------------------------------------
  # Formeln (am Hochschrank selbst, nur nicht berechnete Attribute verwenden)
  # ---------------------------------------------------------------------------
  def self.f_summe(b)
    cfg = bereiche[b]
    terms = ["Anteil_#{b}1"] + (2..cfg[:max]).map { |i| "IF(#{cfg[:anz]}>=#{i},Anteil_#{b}#{i},0)" }
    "(#{terms.join('+')})"
  end

  def self.f_netto(b)
    cfg = bereiche[b]
    "(#{cfg[:top]}-#{cfg[:z0]}-(#{cfg[:anz]}-1)*Spaltbreite)"
  end

  def self.nur_sichtbar(b, i, formel, park)
    i == 1 ? formel : "IF(#{bereiche[b][:anz]}>=#{i},#{formel},#{park})"
  end

  def self.f_h_front(b, i)
    nur_sichtbar(b, i, "#{f_netto(b)}*Anteil_#{b}#{i}/#{f_summe(b)}", PARK_HOEHE)
  end

  def self.f_z_front(b, i)
    cfg = bereiche[b]
    teil = (1..i).map { |j| "Anteil_#{b}#{j}" }.join('+')
    nur_sichtbar(b, i, "#{cfg[:top]}-#{f_netto(b)}*(#{teil})/#{f_summe(b)}-#{i - 1}*Spaltbreite",
                 "#{cfg[:z0]}+Materialstaerke_Korpus")
  end

  def self.f_hidden(b, i)
    cfg = bereiche[b]
    bed = "#{NAME}!#{cfg[:anz]}>=#{i}"
    bed = "AND(#{NAME}!#{cfg[:bed]},#{bed})" if cfg[:bed]
    "IF(#{bed},0,1)"
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

  # Freies Kürzel für die Tags, z. B. HS1, HS2 …
  def self.freies_kuerzel(model)
    n = 1
    n += 1 while model.layers.to_a.any? { |l| l.name.start_with?("#{KUERZEL}#{n}_") }
    "#{KUERZEL}#{n}"
  end

  # Tag <Kürzel>_<Bereich>_<Teil> (z. B. HS1_SeiteL, HS1_U1_Front) und JT_Schrank am Teil
  def self.kennzeichnen(model, inst, kz, teil, bereich = nil)
    name = [kz, bereich, teil].compact.join('_')
    inst.layer = model.layers[name] || model.layers.add(name)
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE, 'bereich' => bereich.to_s,
      'teil' => teil, 'rolle' => ROLLEN.fetch(teil.sub(/\d+\z/, '')) }.each { |k, v| inst.set_attribute(JT_DICT, k, v) }
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

  # kz: [Modell, Kürzel, Teil, Bereich] -> Tag und JT_Schrank (siehe kennzeichnen)
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
    attribut(haupt, 'Materialstaerke_Kastenboden', p['Materialstaerke_Kastenboden'], access: 'TEXTBOX',
             formlabel: 'Stärke Kastenboden')
    attribut(haupt, 'Hoehenoffset_Schiene', p['Hoehenoffset_Schiene'], access: 'TEXTBOX',
             formlabel: 'Höhenoffset Schiene (Bohrung über Unterkante Kasten)')

    attribut(haupt, 'H_Unten', p['H_Unten'], access: 'TEXTBOX', formlabel: 'Unten: Höhe Bereich (bis Oberkante Zwischenboden)')
    attribut(haupt, 'Anz_Schubladen_Unten', p['Anz_Schubladen_Unten'], laenge: false, access: 'LIST',
             formlabel: 'Unten: Anzahl Schubladen', units: 'INTEGER', options: liste(1, MAX_U))
    (1..MAX_U).each do |i|
      attribut(haupt, "Anteil_U#{i}", p["Anteil_U#{i}"], laenge: false, access: 'TEXTBOX',
               formlabel: "Unten: Anteil Schublade #{i}#{i == 1 ? ' (oben)' : ''}")
    end

    attribut(haupt, 'Art_Mitte', p['Art_Mitte'], laenge: false, access: 'LIST', formlabel: 'Mitte: Ausführung',
             units: 'INTEGER', options: '&Offenes%20Fach=0&Schubladen=1&')
    attribut(haupt, 'H_Mitte', p['H_Mitte'], access: 'TEXTBOX', formlabel: 'Mitte: lichte Höhe (z. B. Backofen)')
    attribut(haupt, 'Anz_Schubladen_Mitte', p['Anz_Schubladen_Mitte'], laenge: false, access: 'LIST',
             formlabel: 'Mitte: Anzahl Schubladen', units: 'INTEGER', options: liste(1, MAX_M))
    (1..MAX_M).each do |i|
      attribut(haupt, "Anteil_M#{i}", p["Anteil_M#{i}"], laenge: false, access: 'TEXTBOX',
               formlabel: "Mitte: Anteil Schublade #{i}#{i == 1 ? ' (oben)' : ''}")
    end

    attribut(haupt, 'Art_Oben', p['Art_Oben'], laenge: false, access: 'LIST', formlabel: 'Oben: Ausführung',
             units: 'INTEGER', options: '&Offenes%20Fach=0&T%C3%BCr=1&')
    attribut(haupt, 'Anz_Einlegeboeden_Oben', p['Anz_Einlegeboeden_Oben'], laenge: false, access: 'LIST',
             formlabel: 'Oben: Anzahl Einlegeböden', units: 'INTEGER', options: liste(0, MAX_EB))
    attribut(haupt, 'H_Oben', r[:h_oben], access: 'VIEW', formlabel: 'Oben: Höhe Bereich (ergibt sich)',
             formula: 'Hoehe-H_Unten-H_Mitte-Materialstaerke_Korpus')

    # --- Feste Maße (über Komponentenattribute änderbar) ---
    %w[Materialstaerke_Korpus Materialstarke_Rueckwand Spaltbreite
       Materialstaerke_Kastenrueckwand Hoehe_Kastenrueckwand Kasten_Abstand_unten Kasten_Abstand_oben
       Rueckversatz_Einlegeboden Lochraster_Start Lochraster].each do |n|
      attribut(haupt, n, p[n], units: 'STRING')
    end
    attribut(haupt, 'Auszug_Anteil', p['Auszug_Anteil'], laenge: false, units: 'STRING')
    # Blum-Nennlänge (cm) aus der Korpustiefe, steuert Kastenlänge und Schienenbohrungen
    attribut(haupt, 'NL', nennlaenge(p['Tiefe']), units: 'STRING', formula: f_nennlaenge('Tiefe'))

    # --- Abgeleitete Werte ---
    attribut(haupt, 'Z_Oben', r[:z_oben], units: 'STRING', formula: 'H_Unten+H_Mitte+Materialstaerke_Korpus')
    %w[U M].each do |b|
      r[b].each_with_index do |fr, idx|
        i = idx + 1
        attribut(haupt, "H_Front_#{b}#{i}", fr[:h], units: 'STRING', formula: f_h_front(b, i))
        attribut(haupt, "Z_Front_#{b}#{i}", fr[:z], units: 'STRING', formula: f_z_front(b, i))
      end
    end
    (1..MAX_EB).each do |k|
      z_ob = '(H_Unten+H_Mitte+Materialstaerke_Korpus)'
      f = "IF(Anz_Einlegeboeden_Oben>=#{k},#{z_ob}+(Hoehe-Materialstaerke_Korpus-#{z_ob})*#{k}/" \
          "(Anz_Einlegeboeden_Oben+1)-Materialstaerke_Korpus/2,#{z_ob})"
      attribut(haupt, "Z_Einlegeboden_#{k}", r[:eb][k - 1], units: 'STRING', formula: f)
    end

    mk = p['Materialstaerke_Korpus']
    b, h, t = p['Breite'], p['Hoehe'], p['Tiefe']
    rw, sp = p['Materialstarke_Rueckwand'], p['Spaltbreite']
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
    # Zwischenböden: Oberkante bei H_Unten bzw. H_Unten+H_Mitte+Mk
    einsetzen(e, boden, 'ZwischenbodenUnten', [mk, mk, p['H_Unten'] - mk],
              ["#{u}!Materialstaerke_Korpus", nil, "#{u}!H_Unten-#{u}!Materialstaerke_Korpus"],
              mat: mat, kz: t_.('ZwischenbodenUnten'))
    einsetzen(e, boden, 'ZwischenbodenOben', [mk, mk, r[:z_oben] - mk],
              ["#{u}!Materialstaerke_Korpus", nil, "#{u}!H_Unten+#{u}!H_Mitte"],
              mat: mat, kz: t_.('ZwischenbodenOben'))

    rueck = platte(model, 'Rückwand', 'Rückwand', [b, rw, h],
                   ["#{u}!Breite", "#{u}!Materialstarke_Rueckwand", "#{u}!Hoehe"], kanten: %i[xmin xmax zmax])
    einsetzen(e, rueck, 'Rückwand', [0, t + mk, 0],
              [nil, "#{u}!Tiefe+#{u}!Materialstaerke_Korpus", nil], mat: mat, kz: t_.('Rueckwand'))

    # --- Einlegeböden oben ---
    rv = p['Rueckversatz_Einlegeboden']
    (1..MAX_EB).each do |k|
      # eigene Definition je Boden, damit "hidden" einzeln gesteuert werden kann
      d = platte(model, "Einlegeboden #{k}", "Einlegeboden#{k}", [b - 2 * mk, t - rv, mk],
                 ["#{u}!Breite-2*#{u}!Materialstaerke_Korpus", "#{u}!Tiefe-#{u}!Rueckversatz_Einlegeboden",
                  "#{u}!Materialstaerke_Korpus"], kanten: %i[ymin])
      sichtbarkeit(d, k <= p['Anz_Einlegeboeden_Oben'].to_i, "IF(#{u}!Anz_Einlegeboeden_Oben>=#{k},0,1)")
      inst = einsetzen(e, d, "Einlegeboden#{k}", [mk, mk + rv, r[:eb][k - 1]],
                       ["#{u}!Materialstaerke_Korpus", "#{u}!Materialstaerke_Korpus+#{u}!Rueckversatz_Einlegeboden",
                        "#{u}!Z_Einlegeboden_#{k}"], mat: mat, kz: t_.("Einlegeboden#{k}", 'O'))
      inst.hidden = k > p['Anz_Einlegeboeden_Oben'].to_i
    end

    # --- Tür oben (Anschlag links, mit "Interagieren" öffnen) ---
    tuer = platte(model, 'Tür', 'Tür', [b - sp, mk, r[:h_oben]],
                  ["#{u}!Breite-#{u}!Spaltbreite", "#{u}!Materialstaerke_Korpus", "#{u}!Hoehe-#{u}!Z_Oben"], kanten: %i[xmin xmax zmin zmax])
    sichtbarkeit(tuer, p['Art_Oben'].to_i == 1, "IF(#{u}!Art_Oben=1,0,1)")
    tuer.set_attribute(DICT, 'rotz', 0.0)
    tuer.set_attribute(DICT, 'onclick', 'ANIMATE("ROTZ",0,-100)')
    tuer.set_attribute(DICT, '_onclick_label', 'onClick')
    t_inst = einsetzen(e, tuer, 'Tür', [sp / 2.0, -sp, r[:z_oben]],
                       ["#{u}!Spaltbreite/2", "-#{u}!Spaltbreite", "#{u}!Z_Oben"], mat: mat, kz: t_.('Tuer', 'O'))
    t_inst.hidden = p['Art_Oben'].to_i != 1

    # --- Schubladen ---
    %w[U M].each do |bb|
      (1..bereiche[bb][:max]).each { |i| schublade(model, e, p, r[bb][i - 1], bb, i, mat, kz) }
    end

    haupt
  end

  def self.sichtbar?(p, b, i)
    cfg = bereiche[b]
    return false if cfg[:bed] && p['Art_Mitte'].to_i != 1
    i <= p[cfg[:anz]].to_i
  end

  # Größte LEGRABOX-Nennlänge (cm, 5er-Schritte, max. 65), für die die Einbautiefe reicht (LT >= NL + 3 mm)
  def self.nennlaenge(tiefe)
    [65.0, ((tiefe - 0.3) / 5.0 + 0.000001).floor * 5.0].min
  end

  def self.f_nennlaenge(tiefe)
    "MIN(65,INT((#{tiefe}-0.3)/5+0.000001)*5)"
  end

  def self.schublade(model, ents, p, fr, bb, i, mat, kz)
    u  = NAME
    s  = "Schublade#{bb}#{i}"
    mk = p['Materialstaerke_Korpus']
    sp = p['Spaltbreite']
    b  = p['Breite']
    mb   = p['Materialstaerke_Kastenboden']
    mrw  = p['Materialstaerke_Kastenrueckwand']
    nl   = nennlaenge(p['Tiefe'])
    ao   = p['Kasten_Abstand_oben']
    hf   = fr[:h]
    lw   = b - 2 * mk                   # lichte Weite
    ab   = kasten_unten(p, fr[:z])      # Unterkante Kasten im Lochraster
    kh   = [hf - ab - ao, 2.0].max      # Höhe Kasten gesamt, mind. 2 cm
    hrw  = [p['Hoehe_Kastenrueckwand'], kh - mb].min
    bt   = ->(teil) { [model, kz, teil, "#{bb}#{i}"] }

    d = model.definitions.add(s)
    stempel(d)
    d.set_attribute(DICT, '_name', s)
    attribut(d, 'Breite', b, units: 'STRING', formula: "#{u}!Breite")
    attribut(d, 'Hoehe_Front', hf, units: 'STRING', formula: "#{u}!H_Front_#{bb}#{i}")
    attribut(d, 'Mk', mk, units: 'STRING', formula: "#{u}!Materialstaerke_Korpus")
    attribut(d, 'Spalt', sp, units: 'STRING', formula: "#{u}!Spaltbreite")
    attribut(d, 'Mb', mb, units: 'STRING', formula: "#{u}!Materialstaerke_Kastenboden")
    attribut(d, 'Mrw', mrw, units: 'STRING', formula: "#{u}!Materialstaerke_Kastenrueckwand")
    attribut(d, 'Hrw', p['Hoehe_Kastenrueckwand'], units: 'STRING', formula: "#{u}!Hoehe_Kastenrueckwand")
    attribut(d, 'NL', nl, units: 'STRING', formula: "#{u}!NL")
    attribut(d, 'Ab_unten', ab, units: 'STRING', formula: f_kasten_unten("#{u}!Z_Front_#{bb}#{i}"))
    attribut(d, 'Ab_oben', ao, units: 'STRING', formula: "#{u}!Kasten_Abstand_oben")
    attribut(d, 'Auszug', nl * p['Auszug_Anteil'], units: 'STRING', formula: "#{u}!NL*#{u}!Auszug_Anteil")
    sichtbarkeit(d, sichtbar?(p, bb, i), f_hidden(bb, i))
    d.set_attribute(DICT, 'onclick', 'ANIMATE("Y",0,-Auszug)')
    d.set_attribute(DICT, '_onclick_label', 'onClick')

    de = d.entities
    front = platte(model, "Front #{bb}#{i}", 'Front', [b - sp, mk, hf],
                   ["#{s}!Breite-#{s}!Spalt", "#{s}!Mk", "#{s}!Hoehe_Front"], kanten: %i[xmin xmax zmin zmax])
    einsetzen(de, front, 'Front', [sp / 2.0, -sp, 0], ["#{s}!Spalt/2", "-#{s}!Spalt", nil],
              mat: mat, kz: bt.('Front'))

    # Boden LW-35 x NL-10, mittig, vorne an der Korpusvorderkante
    kbod = platte(model, "Kasten Boden #{bb}#{i}", 'KastenBoden', [lw - 3.5, nl - 1.0, mb],
                  ["#{s}!Breite-2*#{s}!Mk-3.5", "#{s}!NL-1", "#{s}!Mb"])
    einsetzen(de, kbod, 'KastenBoden', [mk + 1.75, mk, ab],
              ["#{s}!Mk+1.75", "#{s}!Mk", "#{s}!Ab_unten"], mat: mat, kz: bt.('KastenBoden'))

    # Holzrückwand LW-38 x 148 (höchstens bis Kasten_Abstand_oben unter die Frontoberkante), hinten auf dem Boden
    roh_kh = "#{s}!Hoehe_Front-#{s}!Ab_unten-#{s}!Ab_oben"
    f_kh   = "IF(#{roh_kh}>2,#{roh_kh},2)"
    krw = platte(model, "Kasten Rueckwand #{bb}#{i}", 'KastenRueckwand', [lw - 3.8, mrw, hrw],
                 ["#{s}!Breite-2*#{s}!Mk-3.8", "#{s}!Mrw", "MIN(#{s}!Hrw,#{f_kh}-#{s}!Mb)"], kanten: %i[zmax])
    einsetzen(de, krw, 'KastenRueckwand', [mk + 1.9, mk + nl - 1.0 - mrw, ab + mb],
              ["#{s}!Mk+1.9", "#{s}!Mk+#{s}!NL-1-#{s}!Mrw", "#{s}!Ab_unten+#{s}!Mb"],
              mat: mat, kz: bt.('KastenRueckwand'))

    inst = einsetzen(ents, d, s, [0, 0, fr[:z]], [nil, nil, "#{u}!Z_Front_#{bb}#{i}"])
    inst.hidden = !sichtbar?(p, bb, i)
    inst
  end

  # ---------------------------------------------------------------------------
  # Erzeugen + als .skp speichern
  # ---------------------------------------------------------------------------
  def self.erstellen(eingabe = {}, ziel = nil)
    model = Sketchup.active_model
    model.start_operation('Hochschrank', true)
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
        UI.messagebox('Automatisches Speichern ging nicht. Rechtsklick auf den Hochschrank → "Speichern unter…"')
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
unless defined?($HOCHSCHRANK_TEST)
  Hochschrank.erstellen({}, File.join(File.dirname(File.expand_path(__FILE__)), 'Hochschrank.skp'))
end
