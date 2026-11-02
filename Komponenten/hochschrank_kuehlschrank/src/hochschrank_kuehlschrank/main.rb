# encoding: UTF-8
#
# Hochschrank Kühlschrank – erzeugt eine Dynamic Component
#
# Erweiterung (.rbz): Erweiterungen > Küchenplaner > Hochschränke > Hochschrank Kühlschrank baut den
# Schrank im aktuellen Modell. Maße und Optionen danach in den Komponentenoptionen einstellen.
#
# Aufbau von unten nach oben:
#   Unten:  0–4 Schubladen (0 = das Gerät steht auf dem Boden), Aufteilung über Anteil_U1..U4
#   Nische: Einbau-Kühlschrank, Gefrierschrank oder Kühl-Gefrier-Kombi, lichte Höhe aus dem
#           Raster 880 … 1940 mm oder frei; davor eine Möbeltür (Kombi: zwei Türen),
#           Schlepptür oder Festtür, Anschlag links oder rechts
#   Oben:   offenes Fach oder mit Tür, 0–2 Einlegeböden
#
# Lüftung "Schacht hinten" (Standard): die Nische hat keine Rückwand, alle Böden und der Deckel
# enden um Schacht + Rückwand vor der Hinterkante; oberes Fach und Schubladenbereich haben eigene
# Rückwände (RueckwandOben/RueckwandUnten) in einer Nut der Seiten. Dahinter bleibt ein Schacht
# über die ganze Höhe: Zuluft unten durch das Sockelgitter, Abluft oben. Lüftung "Front/Sockel":
# Rückwand durchgehend, Böden in voller Tiefe (wie Hochschrank Geräte).
#
# Platten haben das Material "Melamin weiss", sichtbare Kanten das Kantenmaterial "Anleimer
# Melamin weiss" (2 mm, für Stückliste, Etiketten und Zuschnitt im Küchenplaner-Plugin; gezeichnet
# wird das Endmaß). Jedes Teil hat einen eigenen Tag <Kürzel>_<Bereich>_<Teil> (z. B. HK1_SeiteL,
# HK1_N_Tuer, HK1_U1_Front) und das Wörterbuch "JT_Schrank" für den TCN-Export. Der Geräte-
# Platzhalter liegt auf dem Tag "Geraete_Plan", hat kein Plattenmaterial und kein JT_Schrank. Die
# Nische steht im Wörterbuch "JT_Nische_N1" am Schrank (für die Geräte-Komponenten).
# Anderes Kürzel: HochschrankKuehlschrank.erstellen({ 'Kuerzel' => 'HK2' }, ziel)

require 'sketchup.rb'
require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'eingabe') # Eingabefenster im Treppenplaner-Stil

module HochschrankKuehlschrank

  DICT     = 'dynamic_attributes'.freeze
  NAME     = 'Hochschrank Kuehlschrank'.freeze
  DC_NAME  = 'HochschrankKuehlschrank'.freeze # Name in den DC-Formeln (ohne Leerzeichen)
  MAX_U    = 4
  MAX_EB   = 2
  PARK_HOEHE = 10.0 # cm
  MATERIAL = 'Melamin weiss'.freeze
  KANTE    = 'Anleimer Melamin weiss'.freeze
  GERAET_MATERIAL = 'Geraet Plan'.freeze
  GERAET_TAG = 'Geraete_Plan'.freeze
  OCL_DICT = 'ladb_opencutlist'.freeze # Materialeinstellungen (Typ, Stärke), liest auch das Küchenplaner-Plugin
  KUERZEL  = 'HK'.freeze

  # Tag-Schema für den TCN-Export (gleich in allen Komponenten, der Test prüft das):
  # Tag <Kürzel>_<Bereich>_<Teil>, dazu am Teil das Wörterbuch JT_Schrank.
  JT_DICT   = 'JT_Schrank'.freeze
  TYP       = 'Hochschrank_Kuehlgeraet'.freeze
  KATEGORIE = 'Hochschrank'.freeze # Unterschrank, Oberschrank oder Hochschrank
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

  # Nische für die Geräte-Komponenten: Wörterbuch JT_Nische_N1 am Schrank
  NISCHE_DICT = 'JT_Nische'.freeze

  # Auswahl Nische: Wert => [Kennung, lichte Nischenhöhe cm]; 0 = frei (eigene Höhe).
  # Übliche Rastermaße der Einbau-Kühlgeräte (Bosch, Siemens, Neff, Miele, Liebherr).
  NISCHEN = {
    1 => ['Kuehlgeraet88', 88.0], 2 => ['Kuehlgeraet102', 102.0], 3 => ['Kuehlgeraet122', 122.0],
    4 => ['Kuehlgeraet140', 140.0], 5 => ['Kuehlgeraet158', 158.0], 6 => ['Kuehlgeraet178', 178.0],
    7 => ['Kuehlgeraet194', 194.0], 0 => ['Kuehlgeraet', nil]
  }.freeze
  # Geräteart: Wert => [Kennung für JT_Nische/art, Text]; 3 = Kombi mit zwei Türen
  ARTEN = { 1 => %w[Kuehlschrank Kühlschrank], 2 => %w[Gefrierschrank Gefrierschrank],
            3 => ['KuehlGefrier', 'Kühl-Gefrier-Kombi'] }.freeze
  KOMBI = 3
  TUERTECHNIK = { 1 => 'Schlepptuer', 2 => 'Festtuer' }.freeze

  # Standardwerte in cm
  DEFAULTS = {
    'Breite'                      => 60.0,
    'Hoehe'                       => 210.0,
    'Tiefe'                       => 56.0,
    'H_Unten'                     => 70.0,  # Oberkante Zwischenboden unter der Nische (nur mit Schubladen)
    'Anz_Schubladen_Unten'        => 0.0,
    'Geraet'                      => 6.0,   # Nische 1780
    'H_N_frei'                    => 178.0, # lichte Höhe bei "frei"
    'Art_Geraet'                  => 1.0,   # 1 Kühlschrank, 2 Gefrierschrank, 3 Kombi
    'Lueftung'                    => 1.0,   # 1 = Schacht hinten, 0 = über Sockel und Front
    'Schacht'                     => 4.0,   # Tiefe Lüftungsschacht (Hinterkante Seite -> Rückwand)
    'Tuertechnik'                 => 1.0,   # 1 = Schlepptür, 2 = Festtür
    'Anschlag'                    => 1.0,   # 0 = links, 1 = rechts
    'H_Tuer_Unten'                => 72.0,  # Kombi: Höhe der unteren Tür
    'Art_Oben'                    => 1.0,   # 0 = offenes Fach, 1 = Tür
    'Anz_Einlegeboeden_Oben'      => 0.0,
    'Materialstaerke_Korpus'      => 1.9,
    'Materialstarke_Rueckwand'    => 0.8,
    'Nuttiefe'                    => 0.9,   # Nut der Rückwände bei Lüftungsschacht
    'Spaltbreite'                 => 0.2,
    # Schubkasten Blum LEGRABOX free (Montageanleitung MD-015/4): Metallzargen, aus Holz nur
    # Boden (LW-35 x NL-10, 16 mm) und Holzrückwand (LW-38 x 148, auf dem Boden)
    'Materialstaerke_Kastenboden' => 1.6,
    'Materialstaerke_Kastenrueckwand' => 1.6,
    'Hoehe_Kastenrueckwand'       => 14.8,
    'Hoehenoffset_Schiene'        => 0.0,
    'Lochraster_Start'            => 3.5,
    'Lochraster'                  => 3.2,
    'Kasten_Abstand_unten'        => 3.0,
    'Kasten_Abstand_oben'         => 3.0,
    'Auszug_Anteil'               => 0.8,
    'Rueckversatz_Einlegeboden'   => 1.0,
    'Geraet_Tiefe'                => 55.0  # Tiefe des Platzhalters (höchstens Korpustiefe)
  }.merge((1..MAX_U).to_h { |i| ["Anteil_U#{i}", 1.0] }).freeze

  # Kurzhilfe in der Komponente (Kurzfassung der README.md). SketchUp zeigt
  # "summary" und "description" oben im Fenster "Komponentenoptionen".
  DOKU_URL = 'https://github.com/jimmycd/sketchup_kuechenplaner2/tree/main/Komponenten/hochschrank_kuehlschrank'.freeze
  HILFE_KURZ = 'Hochschrank für Einbau-Kühl- und Gefriergeräte: Nische mit Möbeltür, unten optional Schubladen, oben Fach'.freeze
  HILFE = [
    'Nische: lichte Höhe 880/1020/1220/1400/1580/1780/1940 mm oder „frei“; Geräte brauchen meist 560 mm lichte Breite und 550 mm Tiefe.',
    'Kühl-Gefrier-Kombi: zwei Türen, Höhe der unteren Tür laut Einbauskizze des Geräts einstellen.',
    'Schlepptür (Möbeltür an Topfbändern, Gerätetür läuft mit) oder Festtür (Möbeltür auf der Gerätetür), Anschlag links/rechts.',
    'Lüftung „Schacht hinten“: Nische ohne Rückwand, hinten durchgehender Schacht; Sockelblende mit Lüftungsgitter vorsehen (ca. 200 cm²).',
    'Unten 0–4 Schubladen (0 = Gerät steht auf dem Boden), oben offenes Fach oder Tür mit 0–2 Einlegeböden.',
    'Gezeichnet ist das Endmaß; den Anleimer (2 mm) zieht das Küchenplaner-Plugin beim Zuschnitt ab.',
    'Jedes Teil hat einen eigenen Tag <Kürzel>_<Bereich>_<Teil>, z. B. HK1_SeiteL, HK1_N_Tuer, HK1_O_Tuer.',
    'Feste Maße (Materialstärken, Schacht, Nut): Fenster „Komponentenattribute“.',
    "Doku: #{DOKU_URL}"
  ].join(' ').freeze

  # Bereich mit Schubladen: Präfix, Anzahl-Attribut, Max, Unterkante, Oberkante Fronten
  def self.bereiche
    { 'U' => { anz: 'Anz_Schubladen_Unten', max: MAX_U, z0: '0', top: '(H_Unten-Spaltbreite)' } }
  end

  # ---------------------------------------------------------------------------
  # Reine Berechnung (ohne SketchUp), spiegelt die DC-Formeln. Werte in cm.
  # ---------------------------------------------------------------------------
  def self.nischenhoehe(p)
    NISCHEN.fetch(p['Geraet'].to_i)[1] || p['H_N_frei']
  end

  def self.schubladen?(p)
    p['Anz_Schubladen_Unten'].to_i > 0
  end

  def self.schacht?(p)
    p['Lueftung'].to_i == 1
  end

  def self.kombi?(p)
    p['Art_Geraet'].to_i == KOMBI
  end

  def self.berechne(p)
    mk, sp = p['Materialstaerke_Korpus'], p['Spaltbreite']
    hn = nischenhoehe(p)
    z_n = schubladen?(p) ? p['H_Unten'] : mk
    z_oben = z_n + hn + mk
    t0 = schubladen?(p) ? p['H_Unten'] : 0.0
    top = z_oben - (p['Art_Oben'].to_i == 1 ? sp : 0.0)
    erg = { h_n: hn, z_n: z_n, z_oben: z_oben, h_oben: p['Hoehe'] - z_oben,
            t_innen: p['Tiefe'] - (schacht?(p) ? p['Schacht'] + p['Materialstarke_Rueckwand'] : 0.0),
            tuer_z0: t0, h_tuer: top - t0, h_tuer_oben: top - t0 - p['H_Tuer_Unten'] - sp }
    z0, ftop = 0.0, p['H_Unten'] - sp
    n = p['Anz_Schubladen_Unten'].to_i
    ant = (1..MAX_U).map { |i| p["Anteil_U#{i}"].to_f }
    summe = n.zero? ? 1.0 : ant.first(n).sum
    netto = ftop - z0 - (n - 1) * sp
    erg['U'] = (1..MAX_U).map do |i|
      if i <= n
        { h: netto * ant[i - 1] / summe, z: ftop - netto * ant.first(i).sum / summe - (i - 1) * sp }
      else
        { h: PARK_HOEHE, z: z0 + mk }
      end
    end
    n_eb = p['Anz_Einlegeboeden_Oben'].to_i
    erg[:eb] = (1..MAX_EB).map { |k| k <= n_eb ? z_oben + (p['Hoehe'] - mk - z_oben) * k / (n_eb + 1) - mk / 2 : z_oben }
    erg
  end

  # Unterkante Kasten über Unterkante Front (cm): mindestens Kasten_Abstand_unten und so, dass
  # die Schienenbohrung (Unterkante Kasten + Höhenoffset) auf dem Lochraster der Seite liegt.
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
  # Formeln am Schrank selbst: nur Eingabe-Attribute verwenden (SketchUp rechnet die Formeln
  # eines Bauteils nur einmal der Reihe nach, siehe test/tiefe_helfer.rb)
  # ---------------------------------------------------------------------------
  def self.f_h_nische
    NISCHEN.reject { |_, (_, h)| h.nil? }.reverse_each.inject('H_N_frei') do |rest, (wert, (_, h))|
      "IF(Geraet=#{wert},#{h},#{rest})"
    end
  end

  def self.f_z_nische
    'IF(Anz_Schubladen_Unten=0,Materialstaerke_Korpus,H_Unten)'
  end

  def self.f_z_oben
    "(#{f_z_nische}+#{f_h_nische}+Materialstaerke_Korpus)"
  end

  def self.f_t_innen
    '(Tiefe-IF(Lueftung=1,Schacht+Materialstarke_Rueckwand,0))'
  end

  def self.f_tuer_z0
    'IF(Anz_Schubladen_Unten=0,0,H_Unten)'
  end

  def self.f_tuer_top
    "(#{f_z_oben}-IF(Art_Oben=1,Spaltbreite,0))"
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

  # auch Schublade 1 kann fehlen (0 Schubladen)
  def self.nur_sichtbar(b, i, formel, park)
    "IF(#{bereiche[b][:anz]}>=#{i},#{formel},#{park})"
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

  def self.kodiert(t)
    t.gsub(/[^A-Za-z0-9]/) { |c| c.bytes.map { |x| format('%%%02X', x) }.join }
  end

  # Auswahlliste aus [Text, Wert]-Paaren, URL-kodiert
  def self.auswahl(paare)
    '&' + paare.map { |t, w| "#{kodiert(t)}=#{w}" }.join('&') + '&'
  end

  def self.nischen_liste
    auswahl(NISCHEN.reject { |w, _| w.zero? }.map { |w, (_, h)| ["#{(h * 10).round} mm", w] } + [['frei (eigene Höhe)', 0]])
  end

  def self.sichtbarkeit(d, wert, formel)
    d.set_attribute(DICT, 'hidden', wert ? 0.0 : 1.0)
    d.set_attribute(DICT, '_hidden_formula', formel)
    d.set_attribute(DICT, '_hidden_label', 'Hidden')
    d.set_attribute(DICT, '_hidden_formlabel', 'Hidden')
    d.set_attribute(DICT, '_hidden_units', 'BOOLEAN')
  end

  # Materialtyp und Maße im Wörterbuch "ladb_opencutlist" am Material (liest das Küchenplaner-
  # Plugin für Stückliste und Zuschnitt). Bereits eingestellte Materialien bleiben unverändert.
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
                          'edge_decremented' => true) # 2 mm werden erst beim Zuschnitt abgezogen
  end

  # Halbtransparentes Material für den Geräte-Platzhalter (kein Plattenwerkstoff)
  def self.geraet_material(model)
    m = model.materials[GERAET_MATERIAL]
    return m if m
    m = model.materials.add(GERAET_MATERIAL)
    m.color = Sketchup::Color.new(90, 140, 200)
    m.alpha = 0.4 if m.respond_to?(:alpha=)
    m
  end

  # Freies Kürzel für die Tags, z. B. HK1, HK2 …
  def self.freies_kuerzel(model)
    n = 1
    n += 1 while model.layers.to_a.any? { |l| l.name.start_with?("#{KUERZEL}#{n}_") }
    "#{KUERZEL}#{n}"
  end

  # Tag <Kürzel>_<Bereich>_<Teil> (z. B. HK1_SeiteL, HK1_N_Tuer) und JT_Schrank am Teil
  def self.kennzeichnen(model, inst, kz, teil, bereich = nil)
    name = [kz, bereich, teil].compact.join('_')
    inst.layer = model.layers[name] || model.layers.add(name)
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE, 'bereich' => bereich.to_s,
      'teil' => teil, 'rolle' => ROLLEN.fetch(teil.sub(/\d+\z/, '')) }.each { |k, v| inst.set_attribute(JT_DICT, k, v) }
    inst
  end

  SEITEN = { xmin: [0, -1], xmax: [0, 1], ymin: [1, -1], ymax: [1, 1], zmin: [2, -1], zmax: [2, 1] }.freeze

  # Quader in Endmaß zeichnen; die in "kanten" genannten Flächen bekommen das Kantenmaterial
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
    groesse = groesse.map { |v| [v, 0.1].max } # ausgeblendete Teile können rechnerisch 0 oder negativ sein
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

  # Nische für die Geräte-Komponenten: lichte Maße und Einfügepunkt (vorne links auf dem Boden
  # unter dem Gerät, an der Korpusvorderkante) in mm, Stand beim Erzeugen
  def self.nischen(d, p, r)
    mk = p['Materialstaerke_Korpus']
    { 'nische' => 'N1', 'geraet' => NISCHEN.fetch(p['Geraet'].to_i)[0], 'art' => ARTEN.fetch(p['Art_Geraet'].to_i)[0],
      'breite' => ((p['Breite'] - 2 * mk) * 10).round(1), 'hoehe' => (r[:h_n] * 10).round(1),
      'tiefe' => (p['Tiefe'] * 10).round(1),
      'x' => (mk * 10).round(1), 'y' => (mk * 10).round(1), 'z' => (r[:z_n] * 10).round(1) }
      .each { |k, v| d.set_attribute("#{NISCHE_DICT}_N1", k, v) }
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
    attribut(haupt, 'Tiefe', p['Tiefe'], access: 'TEXTBOX', formlabel: 'Tiefe (Korpus ohne Front/Rückwand, Gerät braucht mind. 550 mm)')
    attribut(haupt, 'Lichte_Breite', p['Breite'] - 2 * p['Materialstaerke_Korpus'], access: 'VIEW',
             formlabel: 'Lichte Breite Nische (Geräte brauchen meist mind. 560 mm)',
             formula: 'Breite-2*Materialstaerke_Korpus')

    attribut(haupt, 'Geraet', p['Geraet'], laenge: false, access: 'LIST', formlabel: 'Nische: lichte Höhe',
             units: 'INTEGER', options: nischen_liste)
    attribut(haupt, 'H_N_frei', p['H_N_frei'], access: 'TEXTBOX', formlabel: 'Nische: lichte Höhe bei „frei“')
    attribut(haupt, 'H_N', r[:h_n], access: 'VIEW', formlabel: 'Nische: lichte Höhe (ergibt sich)', formula: f_h_nische)
    attribut(haupt, 'Art_Geraet', p['Art_Geraet'], laenge: false, access: 'LIST', formlabel: 'Nische: Gerät',
             units: 'INTEGER', options: auswahl(ARTEN.map { |w, (_, t)| [t, w] }))
    attribut(haupt, 'Lueftung', p['Lueftung'], laenge: false, access: 'LIST', formlabel: 'Nische: Lüftung',
             units: 'INTEGER', options: auswahl([['Schacht hinten', 1], ['über Sockel und Front', 0]]))
    attribut(haupt, 'Tuertechnik', p['Tuertechnik'], laenge: false, access: 'LIST', formlabel: 'Tür: Technik',
             units: 'INTEGER', options: auswahl([['Schlepptür', 1], ['Festtür', 2]]))
    attribut(haupt, 'Anschlag', p['Anschlag'], laenge: false, access: 'LIST', formlabel: 'Tür: Anschlag',
             units: 'INTEGER', options: auswahl([['links', 0], ['rechts', 1]]))
    attribut(haupt, 'H_Tuer_Unten', p['H_Tuer_Unten'], access: 'TEXTBOX',
             formlabel: 'Tür: Höhe untere Tür bei Kühl-Gefrier-Kombi (Einbauskizze)')

    attribut(haupt, 'Anz_Schubladen_Unten', p['Anz_Schubladen_Unten'], laenge: false, access: 'LIST',
             formlabel: 'Unten: Anzahl Schubladen (0 = Gerät steht auf dem Boden)', units: 'INTEGER', options: liste(0, MAX_U))
    attribut(haupt, 'H_Unten', p['H_Unten'], access: 'TEXTBOX', formlabel: 'Unten: Höhe Bereich (bis Oberkante Zwischenboden)')
    (1..MAX_U).each do |i|
      attribut(haupt, "Anteil_U#{i}", p["Anteil_U#{i}"], laenge: false, access: 'TEXTBOX',
               formlabel: "Unten: Anteil Schublade #{i}#{i == 1 ? ' (oben)' : ''}")
    end
    attribut(haupt, 'Materialstaerke_Kastenboden', p['Materialstaerke_Kastenboden'], access: 'TEXTBOX',
             formlabel: 'Unten: Stärke Kastenboden')
    attribut(haupt, 'Hoehenoffset_Schiene', p['Hoehenoffset_Schiene'], access: 'TEXTBOX',
             formlabel: 'Unten: Höhenoffset Schiene (Bohrung über Unterkante Kasten)')

    attribut(haupt, 'Art_Oben', p['Art_Oben'], laenge: false, access: 'LIST', formlabel: 'Oben: Ausführung',
             units: 'INTEGER', options: '&Offenes%20Fach=0&T%C3%BCr=1&')
    attribut(haupt, 'Anz_Einlegeboeden_Oben', p['Anz_Einlegeboeden_Oben'], laenge: false, access: 'LIST',
             formlabel: 'Oben: Anzahl Einlegeböden', units: 'INTEGER', options: liste(0, MAX_EB))
    attribut(haupt, 'H_Oben', r[:h_oben], access: 'VIEW', formlabel: 'Oben: Höhe Bereich (ergibt sich)',
             formula: "Hoehe-#{f_z_oben}")

    # --- Feste Maße (über Komponentenattribute änderbar) ---
    %w[Materialstaerke_Korpus Materialstarke_Rueckwand Nuttiefe Schacht Spaltbreite
       Materialstaerke_Kastenrueckwand Hoehe_Kastenrueckwand Kasten_Abstand_unten Kasten_Abstand_oben
       Rueckversatz_Einlegeboden Lochraster_Start Lochraster Geraet_Tiefe].each do |n|
      attribut(haupt, n, p[n], units: 'STRING')
    end
    attribut(haupt, 'Auszug_Anteil', p['Auszug_Anteil'], laenge: false, units: 'STRING')

    # --- Abgeleitete Werte (nur aus Eingaben gerechnet) ---
    attribut(haupt, 'T_Innen', r[:t_innen], units: 'STRING', formula: f_t_innen)
    # Blum-Nennlänge (cm) aus der lichten Tiefe bis zur Rückwand
    attribut(haupt, 'NL', nennlaenge(r[:t_innen]), units: 'STRING', formula: f_nennlaenge(f_t_innen))
    attribut(haupt, 'Z_N', r[:z_n], units: 'STRING', formula: f_z_nische)
    attribut(haupt, 'Z_Oben', r[:z_oben], units: 'STRING', formula: f_z_oben)
    attribut(haupt, 'Tuer_Z0', r[:tuer_z0], units: 'STRING', formula: f_tuer_z0)
    attribut(haupt, 'H_Tuer', r[:h_tuer], units: 'STRING', formula: "#{f_tuer_top}-#{f_tuer_z0}")
    attribut(haupt, 'Z_Tuer_Oben', r[:tuer_z0] + p['H_Tuer_Unten'] + p['Spaltbreite'], units: 'STRING',
             formula: "#{f_tuer_z0}+H_Tuer_Unten+Spaltbreite")
    attribut(haupt, 'H_Tuer_Oben', r[:h_tuer_oben], units: 'STRING',
             formula: "#{f_tuer_top}-#{f_tuer_z0}-H_Tuer_Unten-Spaltbreite")
    attribut(haupt, 'H_Rueckwand_Oben', p['Hoehe'] - r[:z_oben] + p['Materialstaerke_Korpus'], units: 'STRING',
             formula: "Hoehe-#{f_z_oben}+Materialstaerke_Korpus")
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
    rw, sp, nut = p['Materialstarke_Rueckwand'], p['Spaltbreite'], p['Nuttiefe']
    ti = r[:t_innen]
    e = haupt.entities
    innen = ["#{u}!Breite-2*#{u}!Materialstaerke_Korpus", "#{u}!T_Innen", "#{u}!Materialstaerke_Korpus"]
    schacht = schacht?(p)

    # --- Korpus ---
    seite = platte(model, 'Seite', 'Seite', [mk, t, h],
                   ["#{u}!Materialstaerke_Korpus", "#{u}!Tiefe", "#{u}!Hoehe"], kanten: %i[ymin zmax])
    einsetzen(e, seite, 'SeiteL', [0, mk, 0], [nil, nil, nil], mat: mat, kz: t_.('SeiteL'))
    einsetzen(e, seite, 'SeiteR', [b - mk, mk, 0],
              ["#{u}!Breite-#{u}!Materialstaerke_Korpus", nil, nil], mat: mat, kz: t_.('SeiteR'))

    # Böden enden bei Lüftungsschacht vor der Rückwand (T_Innen)
    boden = platte(model, 'Boden', 'Boden', [b - 2 * mk, ti, mk], innen, kanten: %i[ymin])
    bi = einsetzen(e, boden, 'Boden', [mk, mk, 0], ["#{u}!Materialstaerke_Korpus", nil, nil],
                   mat: mat, kz: t_.('Boden'))
    # ohne Schubladen steht das Gerät auf dem Boden: Schrank-CNC bohrt darüber keine Lochreihe
    bi.set_attribute(JT_DICT, 'nische', 'N1')
    einsetzen(e, boden, 'Deckel', [mk, mk, h - mk],
              ["#{u}!Materialstaerke_Korpus", nil, "#{u}!Hoehe-#{u}!Materialstaerke_Korpus"],
              mat: mat, kz: t_.('Deckel'))
    # Zwischenboden unter dem Gerät, nur mit Schubladen (eigene Definition wegen "hidden")
    unten = platte(model, 'Zwischenboden Unten', 'ZwischenbodenUnten', [b - 2 * mk, ti, mk], innen, kanten: %i[ymin])
    sichtbarkeit(unten, schubladen?(p), "IF(#{u}!Anz_Schubladen_Unten=0,1,0)")
    zu = einsetzen(e, unten, 'ZwischenbodenUnten', [mk, mk, p['H_Unten'] - mk],
                   ["#{u}!Materialstaerke_Korpus", nil, "#{u}!H_Unten-#{u}!Materialstaerke_Korpus"],
                   mat: mat, kz: t_.('ZwischenbodenUnten'))
    zu.set_attribute(JT_DICT, 'nische', 'N1')
    zu.hidden = !schubladen?(p)
    einsetzen(e, boden, 'ZwischenbodenOben', [mk, mk, r[:z_oben] - mk],
              ["#{u}!Materialstaerke_Korpus", nil, "#{u}!Z_Oben-#{u}!Materialstaerke_Korpus"],
              mat: mat, kz: t_.('ZwischenbodenOben'))

    # Rückwand durchgehend hinter den Seiten (Lüftung über Sockel und Front)
    rueck = platte(model, 'Rückwand', 'Rückwand', [b, rw, h],
                   ["#{u}!Breite", "#{u}!Materialstarke_Rueckwand", "#{u}!Hoehe"], kanten: %i[xmin xmax zmax])
    sichtbarkeit(rueck, !schacht, "IF(#{u}!Lueftung=1,1,0)")
    ri = einsetzen(e, rueck, 'Rückwand', [0, t + mk, 0],
                   [nil, "#{u}!Tiefe+#{u}!Materialstaerke_Korpus", nil], mat: mat, kz: t_.('Rueckwand'))
    ri.hidden = schacht
    # Lüftungsschacht: Rückwände oben und unten vor dem Schacht, in einer Nut der Seiten
    rb = ["#{u}!Breite-2*#{u}!Materialstaerke_Korpus+2*#{u}!Nuttiefe", "#{u}!Materialstarke_Rueckwand"]
    rx = "#{u}!Materialstaerke_Korpus-#{u}!Nuttiefe"
    ry = "#{u}!Materialstaerke_Korpus+#{u}!T_Innen"
    ro = platte(model, 'Rückwand Oben', 'RueckwandOben', [b - 2 * mk + 2 * nut, rw, h - r[:z_oben] + mk],
                rb + ["#{u}!H_Rueckwand_Oben"])
    sichtbarkeit(ro, schacht, "IF(#{u}!Lueftung=1,0,1)")
    roi = einsetzen(e, ro, 'RueckwandOben', [mk - nut, mk + ti, r[:z_oben] - mk],
                    [rx, ry, "#{u}!Z_Oben-#{u}!Materialstaerke_Korpus"], mat: mat, kz: t_.('RueckwandOben'))
    roi.hidden = !schacht
    ru = platte(model, 'Rückwand Unten', 'RueckwandUnten', [b - 2 * mk + 2 * nut, rw, p['H_Unten']],
                rb + ["#{u}!H_Unten"])
    sichtbarkeit(ru, schacht && schubladen?(p), "IF(AND(#{u}!Lueftung=1,#{u}!Anz_Schubladen_Unten>0),0,1)")
    rui = einsetzen(e, ru, 'RueckwandUnten', [mk - nut, mk + ti, 0], [rx, ry, nil], mat: mat, kz: t_.('RueckwandUnten'))
    rui.hidden = !(schacht && schubladen?(p))

    # --- Einlegeböden oben ---
    rv = p['Rueckversatz_Einlegeboden']
    (1..MAX_EB).each do |k|
      d = platte(model, "Einlegeboden #{k}", "Einlegeboden#{k}", [b - 2 * mk, ti - rv, mk],
                 ["#{u}!Breite-2*#{u}!Materialstaerke_Korpus", "#{u}!T_Innen-#{u}!Rueckversatz_Einlegeboden",
                  "#{u}!Materialstaerke_Korpus"], kanten: %i[ymin])
      sichtbarkeit(d, k <= p['Anz_Einlegeboeden_Oben'].to_i, "IF(#{u}!Anz_Einlegeboeden_Oben>=#{k},0,1)")
      inst = einsetzen(e, d, "Einlegeboden#{k}", [mk, mk + rv, r[:eb][k - 1]],
                       ["#{u}!Materialstaerke_Korpus", "#{u}!Materialstaerke_Korpus+#{u}!Rueckversatz_Einlegeboden",
                        "#{u}!Z_Einlegeboden_#{k}"], mat: mat, kz: t_.("Einlegeboden#{k}", 'O'))
      inst.hidden = k > p['Anz_Einlegeboeden_Oben'].to_i
    end

    # --- Türen (Anschlag links/rechts, mit "Interagieren" öffnen) ---
    kombi = kombi?(p)
    tuer(model, e, p, 'Tuer', 'N', 'Tür Nische', r[:tuer_z0], r[:h_tuer], "#{u}!Tuer_Z0", "#{u}!H_Tuer",
         !kombi, "IF(#{u}!Art_Geraet=#{KOMBI},1,0)", mat, kz)
    tuer(model, e, p, 'TuerUnten', 'N', 'Tür Nische unten', r[:tuer_z0], p['H_Tuer_Unten'], "#{u}!Tuer_Z0",
         "#{u}!H_Tuer_Unten", kombi, "IF(#{u}!Art_Geraet=#{KOMBI},0,1)", mat, kz)
    tuer(model, e, p, 'TuerOben', 'N', 'Tür Nische oben', r[:tuer_z0] + p['H_Tuer_Unten'] + sp, r[:h_tuer_oben],
         "#{u}!Z_Tuer_Oben", "#{u}!H_Tuer_Oben", kombi, "IF(#{u}!Art_Geraet=#{KOMBI},0,1)", mat, kz)
    tuer(model, e, p, 'Tuer', 'O', 'Tür Oben', r[:z_oben], r[:h_oben], "#{u}!Z_Oben", "#{u}!Hoehe-#{u}!Z_Oben",
         p['Art_Oben'].to_i == 1, "IF(#{u}!Art_Oben=1,0,1)", mat, kz)

    # --- Schubladen ---
    (1..MAX_U).each { |i| schublade(model, e, p, r['U'][i - 1], 'U', i, mat, kz) }

    # --- Geräte-Platzhalter (kein Schrankteil: kein Plattenmaterial, kein JT_Schrank) ---
    tag = model.layers[GERAET_TAG] || model.layers.add(GERAET_TAG)
    g = platte(model, 'Geraet Platzhalter N1', 'GeraetN1', [b - 2 * mk, [p['Geraet_Tiefe'], t].min, r[:h_n]],
               ["#{u}!Breite-2*#{u}!Materialstaerke_Korpus", "MIN(#{u}!Geraet_Tiefe,#{u}!Tiefe)", "#{u}!H_N"])
    einsetzen(e, g, 'GeraetN1', [mk, mk, r[:z_n]], ["#{u}!Materialstaerke_Korpus", nil, "#{u}!Z_N"],
              mat: geraet_material(model), layer: tag)

    haupt
  end

  # Tür vor dem Korpus: Scharnier-Komponente am Anschlag (Drehpunkt), darin die Platte. Bei Anschlag
  # rechts liegt die Platte links vom Drehpunkt. Die Türtechnik steht am Schrank (DC-Attribut).
  def self.tuer(model, ents, p, teil, bereich, defname, z, hoehe, f_z, f_h, sichtbar, f_hidden, mat, kz)
    u = DC_NAME
    sp = p['Spaltbreite']
    bt = p['Breite'] - sp
    rechts = p['Anschlag'].to_i == 1
    s = "Scharnier#{bereich}#{teil}"
    d = model.definitions.add("#{defname} Scharnier")
    stempel(d)
    d.set_attribute(DICT, '_name', s)
    attribut(d, 'Breite', bt, units: 'STRING', formula: "#{u}!Breite-#{u}!Spaltbreite")
    attribut(d, 'Hoehe_Tuer', hoehe, units: 'STRING', formula: f_h)
    attribut(d, 'Mk', p['Materialstaerke_Korpus'], units: 'STRING', formula: "#{u}!Materialstaerke_Korpus")
    attribut(d, 'Anschlag', p['Anschlag'], laenge: false, units: 'STRING', formula: "#{u}!Anschlag")
    attribut(d, 'Winkel', rechts ? 100.0 : -100.0, laenge: false, units: 'STRING', formula: "IF(#{u}!Anschlag=1,100,-100)")
    sichtbarkeit(d, sichtbar, f_hidden)
    d.set_attribute(DICT, 'rotz', 0.0)
    d.set_attribute(DICT, 'onclick', 'ANIMATE("ROTZ",0,Winkel)')
    d.set_attribute(DICT, '_onclick_label', 'onClick')

    platte_d = platte(model, defname, teil, [bt, p['Materialstaerke_Korpus'], hoehe],
                      ["#{s}!Breite", "#{s}!Mk", "#{s}!Hoehe_Tuer"], kanten: %i[xmin xmax zmin zmax])
    einsetzen(d.entities, platte_d, teil, [rechts ? -bt : 0, 0, 0], ["IF(#{s}!Anschlag=1,-#{s}!Breite,0)", nil, nil],
              mat: mat, kz: [model, kz, teil, bereich])

    inst = einsetzen(ents, d, s, [rechts ? p['Breite'] - sp / 2.0 : sp / 2.0, -sp, z],
                     ["IF(#{u}!Anschlag=1,#{u}!Breite-#{u}!Spaltbreite/2,#{u}!Spaltbreite/2)", "-#{u}!Spaltbreite", f_z])
    inst.hidden = !sichtbar
    inst
  end

  # LEGRABOX gibt es nur in festen Nennlängen (cm). Gewählt wird die größte mit NL + 3 mm <= lichte
  # Tiefe; passt keine (unter 353 mm), bleibt es bei der kürzesten, der TCN-Export meldet das.
  NENNLAENGEN = [35.0, 40.0, 45.0, 50.0, 55.0, 60.0, 65.0].freeze

  def self.nennlaenge(tiefe)
    NENNLAENGEN.select { |nl| nl + 0.3 <= tiefe + 0.000001 }.max || NENNLAENGEN.first
  end

  # dieselbe Wahl als DC-Formel (die Nennlängen liegen im 5-cm-Raster)
  def self.f_nennlaenge(tiefe)
    "MAX(35,MIN(65,INT((#{tiefe}-0.3)/5+0.000001)*5))"
  end

  def self.schublade(model, ents, p, fr, bb, i, mat, kz)
    u  = DC_NAME
    s  = "Schublade#{bb}#{i}"
    mk = p['Materialstaerke_Korpus']
    sp = p['Spaltbreite']
    b  = p['Breite']
    mb   = p['Materialstaerke_Kastenboden']
    mrw  = p['Materialstaerke_Kastenrueckwand']
    nl   = nennlaenge(berechne(p)[:t_innen])
    ao   = p['Kasten_Abstand_oben']
    hf   = fr[:h]
    lw   = b - 2 * mk
    ab   = kasten_unten(p, fr[:z])
    hrw  = [p['Hoehe_Kastenrueckwand'], [hf - ab - ao, 2.0].max - mb].min
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
  # Neuer Schrank: Maße beim Anlegen abfragen, Tiefe = Korpus ohne Front/Rückwand. Danach bleiben sie im
  # Fenster Komponentenoptionen änderbar; alle abhängigen Teile folgen dort per Formel.
  # Vorschlag 560 statt 520 mm: Einbau-Kühlgeräte brauchen mindestens 550 mm Nischentiefe.
  TIEFE_NEU = 56.0 # cm, Vorschlag im Dialog
  TIEFE_GERAET = 55.0 # cm, Mindesttiefe der Nische
  BREITE_GERAET = 56.0 # cm, übliche lichte Mindestbreite

  # Mindesttiefe: Schubladen (LEGRABOX NL 350 braucht 353 mm) vor Schacht und Rückwand
  def self.tiefe_min
    35.3 + DEFAULTS['Schacht'] + DEFAULTS['Materialstarke_Rueckwand']
  end

  # Hinweise, wenn das Gerät nicht passt (Anlegen geht trotzdem)
  def self.hinweise(eingabe)
    p = DEFAULTS.merge(eingabe)
    h = []
    h << "Tiefe #{(p['Tiefe'] * 10).round} mm: Einbau-Kühlgeräte brauchen meist mind. #{(TIEFE_GERAET * 10).round} mm." if p['Tiefe'] < TIEFE_GERAET - 0.000001
    lb = p['Breite'] - 2 * p['Materialstaerke_Korpus']
    h << "Lichte Breite #{(lb * 10).round} mm: Einbau-Kühlgeräte brauchen meist mind. #{(BREITE_GERAET * 10).round} mm." if lb < BREITE_GERAET - 0.000001
    z_oben = berechne(p)[:z_oben]
    h << "Höhe #{(p['Hoehe'] * 10).round} mm reicht nicht für die Nische (mind. #{(z_oben * 10).round} mm)." if p['Hoehe'] < z_oben + 0.000001
    h
  end

  def self.dialog
    Kuechenplaner::Eingabe.abfragen(['Breite (mm)', 'Höhe (mm)', 'Tiefe Korpus (mm)'],
                      [(DEFAULTS['Breite'] * 10).round.to_s, (DEFAULTS['Hoehe'] * 10).round.to_s, (TIEFE_NEU * 10).round.to_s], 'Hochschrank Kühlschrank', untertitel: 'Neuer Schrank', ok: 'Einfügen') do |res|
      w = res.map { |v| v.to_s.tr(',', '.').to_f / 10.0 }
      eingabe = { 'Breite' => w[0], 'Hoehe' => w[1], 'Tiefe' => w[2] }
      t = eingabe['Tiefe']
      if t < tiefe_min - 0.000001
        raise ArgumentError, "Tiefe #{(t * 10).round} mm ist zu klein (mindestens #{(tiefe_min * 10).round} mm)"
      end
      raise ArgumentError, 'Maße müssen größer als 0 sein' if eingabe.values.any? { |v| v <= 0 }
      h = hinweise(eingabe)
      UI.messagebox("Hinweis:\n#{h.join("\n")}") unless h.empty?
      erstellen(eingabe)
    end
  rescue ArgumentError => e
    UI.messagebox("Ungültige Eingabe: #{e.message}")
  end

  def self.erstellen(eingabe = {}, ziel = nil)
    model = Sketchup.active_model
    model.start_operation('Hochschrank Kühlschrank', true)
    defn = erzeuge(model, eingabe)
    x = model.entities.length > 0 ? model.bounds.max.x + 10.cm : 0
    inst = model.entities.add_instance(defn, Geom::Transformation.translation([x, 0, 0]))
    inst.name = NAME
    inst.set_attribute(DICT, '_name', DC_NAME)
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
  Kuechenplaner.schrank('Hochschränke', 'Hochschrank Kühlschrank…') { HochschrankKuehlschrank.dialog }
  file_loaded(__FILE__)
end
