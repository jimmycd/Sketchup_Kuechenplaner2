# encoding: UTF-8
#
# Hochschrank Geräte – erzeugt eine Dynamic Component
#
# Erweiterung (.rbz): Erweiterungen > Küchenplaner > Hochschränke > Hochschrank Geräte baut den Schrank im
# aktuellen Modell. Maße und Optionen danach in den Komponentenoptionen einstellen.
#
# Aufbau von unten nach oben:
#   Unten:    1–6 Schubladen, Aufteilung über Anteil_U1..U6 (1 = oben)
#   Nische 1: Einbaugerät (Backofen 60, Kompaktgerät 45, Mikrowelle 38,
#             Wärmeschublade 14 oder freie lichte Höhe)
#   Nische 2: wie Nische 1, zusätzlich "keine"
#   Oben:     offenes Fach oder mit Tür, 0–3 Einlegeböden
#
# Jedes Gerät steht auf einem festen Zwischenboden (ZwischenbodenUnten unter
# Nische 1, ZwischenbodenMitte unter Nische 2, ZwischenbodenOben schließt das
# obere Fach ab). Die Rückwand geht durch. Korpus und Schubladen wie beim
# Hochschrank (19 mm Korpus, 8 mm Rückwand, 2 mm Fugen, Blum LEGRABOX).
#
# OpenCutList: Platten haben das Material "Melamin weiss" (Plattenwerkstoff),
# sichtbare Kanten das Material "Anleimer Melamin weiss" (Kante, 2 mm, wird nur
# in OCL abgezogen; gezeichnet wird das Endmaß). Jedes Teil hat einen eigenen Tag
# <Kürzel>_<Bereich>_<Teil> (z. B. HG1_SeiteL, HG1_U1_Front) und das Wörterbuch
# "JT_Schrank" für den TCN-Export. Die Geräte-Platzhalter liegen auf dem Tag
# "Geraete_Plan", haben kein Plattenmaterial und kein JT_Schrank. Jede Nische
# steht im Wörterbuch "JT_Nische_N1" bzw. "JT_Nische_N2" am Schrank (für die
# Geräte-Komponenten). Anderes Kürzel: HochschrankGeraete.erstellen({ 'Kuerzel' => 'HG2' }, ziel)

require 'sketchup.rb'

module HochschrankGeraete

  DICT     = 'dynamic_attributes'.freeze
  NAME     = 'Hochschrank Geraete'.freeze
  DC_NAME  = 'HochschrankGeraete'.freeze # Name in den DC-Formeln (ohne Leerzeichen)
  MAX_U    = 6
  MAX_EB   = 3
  PARK_HOEHE = 10.0 # cm
  MATERIAL = 'Melamin weiss'.freeze
  KANTE    = 'Anleimer Melamin weiss'.freeze
  GERAET_MATERIAL = 'Geraet Plan'.freeze
  GERAET_TAG = 'Geraete_Plan'.freeze
  OCL_DICT = 'ladb_opencutlist'.freeze
  KUERZEL  = 'HG'.freeze

  # Tag-Schema für den TCN-Export (gleich in allen Komponenten, der Test prüft das):
  # Tag <Kürzel>_<Bereich>_<Teil>, dazu am Teil das Wörterbuch JT_Schrank.
  JT_DICT   = 'JT_Schrank'.freeze
  TYP       = 'Hochschrank_Geraete'.freeze
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
    'WangeL' => 'Wange', 'WangeR' => 'Wange',
    'Platte' => 'Arbeitsplatte'
  }.freeze

  # Nischen für die Geräte-Komponenten (Thread "Geräte in Schränken darstellen"):
  # Wörterbuch JT_Nische_N1 / JT_Nische_N2 am Schrank
  NISCHE_DICT = 'JT_Nische'.freeze

  # Auswahl Gerät je Nische: Wert => [Kennung, lichte Nischenhöhe cm]. 0 = frei (eigene Höhe),
  # 5 = keine (nur Nische 2). Übliche Einbaumaße (Bosch/Siemens/Neff/Miele), bei Bedarf "frei".
  GERAETE = {
    1 => ['Backofen60', 59.0], 2 => ['Kompakt45', 45.0], 3 => ['Mikrowelle38', 38.0],
    4 => ['Waermeschublade14', 14.0], 0 => ['frei', nil], 5 => ['keine', 0.0]
  }.freeze
  KEINE = 5

  # Standardwerte in cm
  DEFAULTS = {
    'Breite'                      => 60.0,
    'Hoehe'                       => 210.0,
    'Tiefe'                       => 80.0,
    'H_Unten'                     => 70.0,  # Oberkante Zwischenboden unter Nische 1
    'Geraet_N1'                   => 1.0,   # Backofen 60
    'Geraet_N2'                   => 2.0,   # Kompaktgerät 45
    'H_N1_frei'                   => 59.0,  # lichte Höhe bei Gerät "frei"
    'H_N2_frei'                   => 45.0,
    'Art_Oben'                    => 1.0,   # 0 = offenes Fach, 1 = Tür
    'Anz_Schubladen_Unten'        => 3.0,
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
    'Rueckversatz_Einlegeboden'   => 1.0,  # Einlegeböden vorne zurückgesetzt
    'Geraet_Tiefe'                => 55.0  # Tiefe des Platzhalters (höchstens Korpustiefe)
  }.merge((1..MAX_U).to_h { |i| ["Anteil_U#{i}", 1.0] }).freeze

  # Kurzhilfe in der Komponente (Kurzfassung der README.md). SketchUp zeigt
  # "summary" und "description" oben im Fenster "Komponentenoptionen".
  DOKU_URL = 'https://github.com/jimmycd/sketchup_kuechenplaner2/tree/main/Komponenten/hochschrank_geraete'.freeze
  HILFE_KURZ = 'Hochschrank für zwei Einbaugeräte: unten Schubladen, zwei Gerätenischen, oben offenes Fach oder Tür'.freeze
  HILFE = [
    'Unten: Höhe bis Oberkante Zwischenboden, 1–6 Schubladen (Anteile: 1/1/2 = unterste doppelt so hoch, 1 = oben).',
    'Nische 1 und 2: Gerät wählen, das setzt die lichte Höhe (Backofen 590, Kompaktgerät 450, Mikrowelle 380,',
    'Wärmeschublade 140 mm) oder „frei“ mit eigener Höhe; Nische 2 auch „keine“. Lichte Breite mind. 560 mm.',
    'Oben: offenes Fach oder Tür, 0–3 Einlegeböden; die Höhe ergibt sich aus dem Rest.',
    'Gezeichnet ist das Endmaß; den Anleimer (2 mm) zieht nur OpenCutList ab.',
    'Jedes Teil hat einen eigenen Tag <Kürzel>_<Bereich>_<Teil>, z. B. HG1_SeiteL, HG1_U1_Front, HG1_O_Tuer.',
    'Die Geräte-Platzhalter liegen auf dem Tag „Geraete_Plan“.',
    'Feste Maße (Materialstärken, Abstände): Fenster „Komponentenattribute“.',
    "Doku: #{DOKU_URL}"
  ].join(' ').freeze

  # Bereich mit Schubladen: Präfix, Anzahl-Attribut, Max, Unterkante, Oberkante Fronten
  def self.bereiche
    { 'U' => { anz: 'Anz_Schubladen_Unten', max: MAX_U, z0: '0', top: '(H_Unten-Spaltbreite)' } }
  end

  # ---------------------------------------------------------------------------
  # Reine Berechnung (ohne SketchUp), spiegelt die DC-Formeln. Werte in cm.
  # ---------------------------------------------------------------------------
  def self.nischenhoehe(p, n)
    g = p["Geraet_N#{n}"].to_i
    GERAETE.fetch(g)[1] || p["H_N#{n}_frei"]
  end

  def self.zwei_nischen?(p)
    p['Geraet_N2'].to_i != KEINE
  end

  def self.berechne(p)
    mk, sp = p['Materialstaerke_Korpus'], p['Spaltbreite']
    h1, h2 = nischenhoehe(p, 1), nischenhoehe(p, 2)
    z_n2 = p['H_Unten'] + h1 + mk                         # Unterkante Nische 2
    z_oben = p['H_Unten'] + h1 + mk + (zwei_nischen?(p) ? h2 + mk : 0.0) # Oberkante ZwischenbodenOben
    erg = { h_n1: h1, h_n2: h2, z_n2: z_n2, z_oben: z_oben, h_oben: p['Hoehe'] - z_oben }
    z0, top = 0.0, p['H_Unten'] - sp
    n = p['Anz_Schubladen_Unten'].to_i
    ant = (1..MAX_U).map { |i| p["Anteil_U#{i}"].to_f }
    summe = ant.first(n).sum
    netto = top - z0 - (n - 1) * sp
    erg['U'] = (1..MAX_U).map do |i|
      if i <= n
        { h: netto * ant[i - 1] / summe, z: top - netto * ant.first(i).sum / summe - (i - 1) * sp }
      else
        { h: PARK_HOEHE, z: z0 + mk }
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
    u = DC_NAME
    "#{u}!Lochraster_Start+#{u}!Lochraster*(-INT(-((#{z_front}+#{u}!Kasten_Abstand_unten+#{u}!Hoehenoffset_Schiene" \
      "-#{u}!Lochraster_Start)/#{u}!Lochraster-0.0001)))-#{u}!Hoehenoffset_Schiene-#{z_front}"
  end

  # ---------------------------------------------------------------------------
  # Formeln (am Schrank selbst, nur nicht berechnete Attribute verwenden)
  # ---------------------------------------------------------------------------
  # lichte Höhe Nische n aus der Geräteauswahl
  def self.f_h_nische(n)
    g = "Geraet_N#{n}"
    GERAETE.reject { |_, (_, h)| h.nil? }.reverse_each.inject("H_N#{n}_frei") do |rest, (wert, (_, h))|
      "IF(#{g}=#{wert},#{h},#{rest})"
    end
  end

  def self.f_z_oben
    "(H_Unten+#{f_h_nische(1)}+Materialstaerke_Korpus+IF(Geraet_N2=#{KEINE},0,#{f_h_nische(2)}+Materialstaerke_Korpus))"
  end

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
    "IF(#{DC_NAME}!#{bereiche[b][:anz]}>=#{i},0,1)"
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

  # Auswahlliste Gerät für Nische n (Nische 2 auch "keine")
  def self.geraete_liste(n)
    texte = { 1 => 'Backofen 60 (590 mm)', 2 => 'Kompaktgerät 45 (450 mm)', 3 => 'Mikrowelle 38 (380 mm)',
              4 => 'Wärmeschublade 14 (140 mm)', 0 => 'frei (eigene Höhe)', 5 => 'keine' }
    werte = n == 1 ? [1, 2, 3, 4, 0] : [1, 2, 3, 4, 0, 5]
    kodiert = ->(t) { t.gsub(/[^A-Za-z0-9]/) { |c| c.bytes.map { |x| format('%%%02X', x) }.join } }
    '&' + werte.map { |w| "#{kodiert.(texte[w])}=#{w}" }.join('&') + '&'
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

  # Halbtransparentes Material für die Geräte-Platzhalter (kein OCL-Typ)
  def self.geraet_material(model)
    m = model.materials[GERAET_MATERIAL]
    return m if m
    m = model.materials.add(GERAET_MATERIAL)
    m.color = Sketchup::Color.new(90, 140, 200)
    m.alpha = 0.4 if m.respond_to?(:alpha=)
    m
  end

  # Freies Kürzel für die Tags, z. B. HG1, HG2 …
  def self.freies_kuerzel(model)
    n = 1
    n += 1 while model.layers.to_a.any? { |l| l.name.start_with?("#{KUERZEL}#{n}_") }
    "#{KUERZEL}#{n}"
  end

  # Tag <Kürzel>_<Bereich>_<Teil> (z. B. HG1_SeiteL, HG1_U1_Front) und JT_Schrank am Teil
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

  # Nischen für die Geräte-Komponenten: lichte Maße und Einfügepunkt (vorne links auf
  # der Oberkante des Zwischenbodens, an der Korpusvorderkante) in mm, Stand beim Erzeugen
  def self.nischen(d, p, r)
    mk = p['Materialstaerke_Korpus']
    [[1, p['H_Unten'], r[:h_n1]], [2, r[:z_n2], r[:h_n2]]].each do |n, z, h|
      next if n == 2 && !zwei_nischen?(p)
      { 'nische' => "N#{n}", 'geraet' => GERAETE.fetch(p["Geraet_N#{n}"].to_i)[0],
        'breite' => ((p['Breite'] - 2 * mk) * 10).round(1), 'hoehe' => (h * 10).round(1),
        'tiefe' => (p['Tiefe'] * 10).round(1),
        'x' => (mk * 10).round(1), 'y' => (mk * 10).round(1), 'z' => (z * 10).round(1) }
        .each { |k, v| d.set_attribute("#{NISCHE_DICT}_N#{n}", k, v) }
    end
  end

  # ---------------------------------------------------------------------------
  # Aufbau
  # ---------------------------------------------------------------------------
  def self.erzeuge(model, eingabe = {})
    p = DEFAULTS.merge(eingabe)
    r = berechne(p)
    u = DC_NAME
    mat = material(model)
    kanten_material(model)
    kz = p['Kuerzel'] || freies_kuerzel(model)
    t_ = ->(teil, bereich = nil) { [model, kz, teil, bereich] }

    haupt = model.definitions.add(NAME)
    stempel(haupt)
    haupt.set_attribute(DICT, '_name', u)
    hilfe(haupt)
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE }.each { |k, v| haupt.set_attribute(JT_DICT, k, v) }
    nischen(haupt, p, r)

    # --- Parameter (Komponentenoptionen) ---
    attribut(haupt, 'Breite', p['Breite'], access: 'TEXTBOX', formlabel: 'Breite')
    attribut(haupt, 'Hoehe', p['Hoehe'], access: 'TEXTBOX', formlabel: 'Höhe')
    attribut(haupt, 'Tiefe', p['Tiefe'], access: 'TEXTBOX', formlabel: 'Tiefe (Korpus ohne Front/Rückwand)')
    attribut(haupt, 'Lichte_Breite', p['Breite'] - 2 * p['Materialstaerke_Korpus'], access: 'VIEW',
             formlabel: 'Lichte Breite Nischen (Geräte brauchen meist mind. 560 mm)',
             formula: 'Breite-2*Materialstaerke_Korpus')
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

    [1, 2].each do |n|
      attribut(haupt, "Geraet_N#{n}", p["Geraet_N#{n}"], laenge: false, access: 'LIST',
               formlabel: "Nische #{n}: Gerät", units: 'INTEGER', options: geraete_liste(n))
      attribut(haupt, "H_N#{n}_frei", p["H_N#{n}_frei"], access: 'TEXTBOX',
               formlabel: "Nische #{n}: lichte Höhe bei „frei“")
      attribut(haupt, "H_N#{n}", r[:"h_n#{n}"], access: 'VIEW', formlabel: "Nische #{n}: lichte Höhe",
               formula: f_h_nische(n))
    end

    attribut(haupt, 'Art_Oben', p['Art_Oben'], laenge: false, access: 'LIST', formlabel: 'Oben: Ausführung',
             units: 'INTEGER', options: '&Offenes%20Fach=0&T%C3%BCr=1&')
    attribut(haupt, 'Anz_Einlegeboeden_Oben', p['Anz_Einlegeboeden_Oben'], laenge: false, access: 'LIST',
             formlabel: 'Oben: Anzahl Einlegeböden', units: 'INTEGER', options: liste(0, MAX_EB))
    attribut(haupt, 'H_Oben', r[:h_oben], access: 'VIEW', formlabel: 'Oben: Höhe Bereich (ergibt sich)',
             formula: "Hoehe-#{f_z_oben}")

    # --- Feste Maße (über Komponentenattribute änderbar) ---
    %w[Materialstaerke_Korpus Materialstarke_Rueckwand Spaltbreite
       Materialstaerke_Kastenrueckwand Hoehe_Kastenrueckwand Kasten_Abstand_unten Kasten_Abstand_oben
       Rueckversatz_Einlegeboden Lochraster_Start Lochraster Geraet_Tiefe].each do |n|
      attribut(haupt, n, p[n], units: 'STRING')
    end
    attribut(haupt, 'Auszug_Anteil', p['Auszug_Anteil'], laenge: false, units: 'STRING')
    # Blum-Nennlänge (cm) aus der Korpustiefe, steuert Kastenlänge und Schienenbohrungen
    attribut(haupt, 'NL', nennlaenge(p['Tiefe']), units: 'STRING', formula: f_nennlaenge('Tiefe'))

    # --- Abgeleitete Werte ---
    attribut(haupt, 'Z_N2', r[:z_n2], units: 'STRING', formula: "H_Unten+#{f_h_nische(1)}+Materialstaerke_Korpus")
    attribut(haupt, 'Z_Oben', r[:z_oben], units: 'STRING', formula: f_z_oben)
    r['U'].each_with_index do |fr, idx|
      i = idx + 1
      attribut(haupt, "H_Front_U#{i}", fr[:h], units: 'STRING', formula: f_h_front('U', i))
      attribut(haupt, "Z_Front_U#{i}", fr[:z], units: 'STRING', formula: f_z_front('U', i))
    end
    (1..MAX_EB).each do |k|
      f = "IF(Anz_Einlegeboeden_Oben>=#{k},#{f_z_oben}+(Hoehe-Materialstaerke_Korpus-#{f_z_oben})*#{k}/" \
          "(Anz_Einlegeboeden_Oben+1)-Materialstaerke_Korpus/2,#{f_z_oben})"
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
    # Zwischenböden: unter Nische 1 (Oberkante H_Unten), unter Nische 2, über der obersten Nische
    zu = einsetzen(e, boden, 'ZwischenbodenUnten', [mk, mk, p['H_Unten'] - mk],
                   ["#{u}!Materialstaerke_Korpus", nil, "#{u}!H_Unten-#{u}!Materialstaerke_Korpus"],
                   mat: mat, kz: t_.('ZwischenbodenUnten'))
    # Gerät steht auf diesem Boden: Schrank-CNC bohrt im Fach darüber keine Lochreihe
    zu.set_attribute(JT_DICT, 'nische', 'N1')
    # eigene Definition, weil er bei Nische 2 = keine ausgeblendet wird
    mitte = platte(model, 'Zwischenboden Mitte', 'ZwischenbodenMitte', [b - 2 * mk, t, mk], innen, kanten: %i[ymin])
    sichtbarkeit(mitte, zwei_nischen?(p), "IF(#{u}!Geraet_N2=#{KEINE},1,0)")
    m_inst = einsetzen(e, mitte, 'ZwischenbodenMitte', [mk, mk, r[:z_n2] - mk],
                       ["#{u}!Materialstaerke_Korpus", nil, "#{u}!Z_N2-#{u}!Materialstaerke_Korpus"],
                       mat: mat, kz: t_.('ZwischenbodenMitte'))
    m_inst.set_attribute(JT_DICT, 'nische', 'N2')
    m_inst.hidden = !zwei_nischen?(p)
    einsetzen(e, boden, 'ZwischenbodenOben', [mk, mk, r[:z_oben] - mk],
              ["#{u}!Materialstaerke_Korpus", nil, "#{u}!Z_Oben-#{u}!Materialstaerke_Korpus"],
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
                  ["#{u}!Breite-#{u}!Spaltbreite", "#{u}!Materialstaerke_Korpus", "#{u}!Hoehe-#{u}!Z_Oben"],
                  kanten: %i[xmin xmax zmin zmax])
    sichtbarkeit(tuer, p['Art_Oben'].to_i == 1, "IF(#{u}!Art_Oben=1,0,1)")
    tuer.set_attribute(DICT, 'rotz', 0.0)
    tuer.set_attribute(DICT, 'onclick', 'ANIMATE("ROTZ",0,-100)')
    tuer.set_attribute(DICT, '_onclick_label', 'onClick')
    t_inst = einsetzen(e, tuer, 'Tür', [sp / 2.0, -sp, r[:z_oben]],
                       ["#{u}!Spaltbreite/2", "-#{u}!Spaltbreite", "#{u}!Z_Oben"], mat: mat, kz: t_.('Tuer', 'O'))
    t_inst.hidden = p['Art_Oben'].to_i != 1

    # --- Schubladen ---
    (1..MAX_U).each { |i| schublade(model, e, p, r['U'][i - 1], 'U', i, mat, kz) }

    # --- Geräte-Platzhalter (kein Schrankteil: kein Plattenmaterial, kein JT_Schrank) ---
    tag = model.layers[GERAET_TAG] || model.layers.add(GERAET_TAG)
    gt = [p['Geraet_Tiefe'], t].min
    [[1, p['H_Unten'], "#{u}!H_Unten"], [2, r[:z_n2], "#{u}!Z_N2"]].each do |n, z, fz|
      hn = [r[:"h_n#{n}"], 1.0].max # Nische "keine": ausgeblendet, 1 cm hoch
      g = platte(model, "Geraet Platzhalter N#{n}", "GeraetN#{n}", [b - 2 * mk, gt, hn],
                 ["#{u}!Breite-2*#{u}!Materialstaerke_Korpus", "MIN(#{u}!Geraet_Tiefe,#{u}!Tiefe)",
                  "MAX(#{u}!H_N#{n},1)"])
      sichtbarkeit(g, n == 1 || zwei_nischen?(p), n == 1 ? '0' : "IF(#{u}!Geraet_N2=#{KEINE},1,0)")
      gi = einsetzen(e, g, "GeraetN#{n}", [mk, mk, z], ["#{u}!Materialstaerke_Korpus", nil, fz],
                     mat: geraet_material(model), layer: tag)
      gi.hidden = n == 2 && !zwei_nischen?(p)
    end

    haupt
  end

  # Größte LEGRABOX-Nennlänge (cm, 5er-Schritte, max. 65), für die die Einbautiefe reicht (LT >= NL + 3 mm)
  def self.nennlaenge(tiefe)
    [65.0, ((tiefe - 0.3) / 5.0 + 0.000001).floor * 5.0].min
  end

  def self.f_nennlaenge(tiefe)
    "MIN(65,INT((#{tiefe}-0.3)/5+0.000001)*5)"
  end

  def self.schublade(model, ents, p, fr, bb, i, mat, kz)
    u  = DC_NAME
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
    sichtbar = i <= p[bereiche[bb][:anz]].to_i

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
    sichtbarkeit(d, sichtbar, f_hidden(bb, i))
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
    inst.hidden = !sichtbar
    inst
  end

  # ---------------------------------------------------------------------------
  # Erzeugen (mit ziel zusätzlich als .skp speichern)
  # ---------------------------------------------------------------------------
  def self.erstellen(eingabe = {}, ziel = nil)
    model = Sketchup.active_model
    model.start_operation('Hochschrank Geräte', true)
    defn = erzeuge(model, eingabe)
    x = model.entities.length > 0 ? model.bounds.max.x + 10.cm : 0
    inst = model.entities.add_instance(defn, Geom::Transformation.translation([x, 0, 0]))
    inst.name = NAME
    inst.set_attribute(DICT, '_name', DC_NAME)
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
  Kuechenplaner.untermenu('Hochschränke').add_item('Hochschrank Geräte…') { HochschrankGeraete.erstellen }
  file_loaded(__FILE__)
end
