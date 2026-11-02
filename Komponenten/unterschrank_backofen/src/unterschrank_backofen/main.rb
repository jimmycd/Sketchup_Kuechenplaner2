# encoding: UTF-8
#
# Herdumbauschrank (Unterschrank für einen Backofen unter dem Kochfeld) –
# Generator für eine Dynamic Component
#
# Aufbau wie die anderen Unterschränke (Seiten, Boden, Rückwand), aber:
#   * oben die Nische für einen Einbaubackofen (Front 595 mm), das Kochfeld liegt
#     darüber in der Arbeitsplatte,
#   * der Ofen steht auf einem Einbauboden; hinten bleibt ein Lüftungsspalt,
#   * keine Streben oben (Ofenfront reicht bis zur Korpusoberkante, der
#     Kochfeldausschnitt liegt fast über der ganzen Tiefe),
#   * Rückwand nur unterhalb des Einbaubodens (oben Lüftung und Gerätetiefe),
#   * unter dem Einbauboden eine flache Schublade (Blum LEGRABOX), wenn die lichte
#     Höhe reicht, sonst eine feste Blende (Jürgen, 2026-11-02).
# Alle Maße bleiben über "Komponentenoptionen" änderbar.

require 'sketchup.rb'
require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'eingabe') # Eingabefenster im Treppenplaner-Stil

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

module UnterschrankBackofen

  DICT     = 'dynamic_attributes'.freeze
  NAME     = 'Unterschrank_Backofen'.freeze
  MATERIAL = 'Melamin weiss'.freeze
  ANLEIMER = 'Anleimer weiss'.freeze
  OCL_DICT = 'ladb_opencutlist'.freeze # Materialeinstellungen (Plattenmaterial/Kante) für Stückliste und Zuschnitt

  # Tag-Schema für den TCN-Export (gleich in allen Komponenten, der Test prüft das):
  # Tag <Kürzel>_<Bereich>_<Teil>, dazu am Teil das Wörterbuch JT_Schrank.
  JT_DICT   = 'JT_Schrank'.freeze
  TYP       = 'Unterschrank_Backofen'.freeze
  KATEGORIE = 'Unterschrank'.freeze # Unterschrank, Oberschrank oder Hochschrank
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

  # Nischen für die Geräte-Komponenten (Thread "Geräte in Schränken darstellen")
  NISCHE_DICT = 'JT_Nische'.freeze
  UNTEN = %w[automatisch Blende].freeze # automatisch: Schublade, wenn die lichte Höhe reicht

  # Materialeinstellungen, falls die Materialien im Modell noch fehlen (Werte wie in
  # Unterschrank.skp; Stückliste und Zuschnitt lesen Plattenmaterial und Kante daraus).
  # Vorhandene Einstellungen bleiben unangetastet.
  OCL_MATERIALIEN = {
    MATERIAL => {
      'type' => 2, # Plattenmaterial
      'thickness' => '0', 'length_increase' => '10 mm', 'width_increase' => '10 mm',
      'thickness_increase' => '0', 'grained' => true, 'edge_decremented' => false,
      'std_thicknesses' => '8 mm;10 mm;15 mm;16 mm;18 mm;19 mm;22 mm',
      'std_sizes' => '2800 mm x 2070 mm;2500 mm x 1250 mm;2440 mm x 1220 mm',
      'description' => 'Span Melamin weiss'
    },
    ANLEIMER => {
      'type' => 4, # Kante
      'thickness' => '2 mm', 'length_increase' => '0', 'width_increase' => '0',
      'thickness_increase' => '0', 'grained' => false, 'edge_decremented' => true,
      'std_widths' => '19 mm;23 mm;28 mm;33 mm;35 mm;43 mm', 'std_lengths' => '75 m'
    }
  }.freeze

  # Sichtbare Kanten je Teil bekommen einen Anleimer.
  # Richtungen im Schrank: ymin = vorne, zmax = oben, xmin/xmax = links/rechts.
  # SketchUp zeigt Endmaße; den Abzug für den Anleimer rechnen Stückliste und Zuschnitt.
  KANTEN = {
    'Seite'        => %i[ymin],                  # Vorderkante
    'Boden'        => %i[ymin],
    'Einbauboden'  => %i[ymin],                  # wie Boden/Einlegeboden: vorne
    'Rückwand'     => [],
    'Blende'       => %i[xmin xmax zmin zmax],   # rundum wie die Fronten
    'Front'        => %i[xmin xmax zmin zmax],
    'KastenRueckwand' => %i[zmax],               # Oberkante
    'KastenBoden'  => []
  }.freeze

  # Unterkante Kasten über Unterkante Front (cm): mindestens Kasten_Abstand_unten und so, dass
  # die Schienenbohrung (Unterkante Kasten + Höhenoffset) auf dem Lochraster der Seite liegt
  # (Lochraster_Start + n * Lochraster, gemessen ab Unterkante Seite). Die Front beginnt hier bei 0.
  def self.kasten_unten(p)
    st, ra, off = p['Lochraster_Start'], p['Lochraster'], p['Hoehenoffset_Schiene']
    n = ((p['Kasten_Abstand_unten'] + off - st) / ra - 0.0001).ceil
    st + ra * n - off
  end

  # dieselbe Rechnung als DC-Formel (INT rundet ab, -INT(-x) also auf)
  def self.f_kasten_unten
    u = NAME
    "#{u}!Lochraster_Start+#{u}!Lochraster*(-INT(-((#{u}!Kasten_Abstand_unten+#{u}!Hoehenoffset_Schiene" \
      "-#{u}!Lochraster_Start)/#{u}!Lochraster-0.0001)))-#{u}!Hoehenoffset_Schiene"
  end

  # Standardwerte in cm. Gerätemaße sind Richtwerte, je Gerät mit der Einbauanleitung prüfen.
  DEFAULTS = {
    'Breite'                      => 60.0,
    'Hoehe'                       => 70.0,
    'Tiefe'                       => 80.0,
    'Nischenhoehe'                => 60.0, # lichte Höhe Einbauboden bis Korpusoberkante (Ofen 595 hoch)
    'Lueftungsspalt'              => 5.0,  # Einbauboden hinten kürzer
    'Unten'                       => 0.0,  # 0 = automatisch (Schublade, wenn Platz), 1 = Blende
    'Min_Lichte_Schublade'        => 8.5,  # lichte Höhe unter dem Einbauboden für LEGRABOX N (Richtwert)
    'Arbeitsplatte'               => 4.0,  # Stärke, nur für die Lage der Geräte
    'Materialstaerke_Korpus'      => 1.9,
    'Materialstarke_Rueckwand'    => 0.8,
    'Spaltbreite'                 => 0.2,
    # Schubkasten Blum LEGRABOX free (Montageanleitung MD-015/4): Metallzargen, aus Holz nur
    # Boden (LW-35 x NL-10, 16 mm) und Holzrückwand (LW-38, höchstens bis unter den Einbauboden)
    'Materialstaerke_Kastenboden' => 1.6,
    'Materialstaerke_Kastenrueckwand' => 1.6,
    'Hoehe_Kastenrueckwand'       => 14.8,
    'Hoehenoffset_Schiene'        => 0.0,  # Schienenbohrung über Unterkante Kasten
    'Lochraster_Start'            => 3.5,  # erste Rasterbohrung über Unterkante Seite
    'Lochraster'                  => 3.2,
    'Kasten_Abstand_unten'        => 3.0,  # Unterkante Front -> Unterkante Kasten
    'Kasten_Abstand_oben'         => 1.0,  # Oberkante Kasten -> Unterkante Einbauboden
    'Auszug_Anteil'               => 0.8   # Animation: Auszugsweg = Kastentiefe * Anteil
  }.freeze

  # Kurzhilfe in der Komponente (Kurzfassung der README.md). SketchUp zeigt
  # "summary" und "description" oben im Fenster "Komponentenoptionen".
  DOKU_URL = 'https://github.com/jimmycd/sketchup_kuechenplaner2/tree/main/Komponenten/unterschrank_backofen'.freeze
  HILFE_KURZ = 'Herdumbauschrank: Backofen unter dem Kochfeld, darunter Schublade (Blum LEGRABOX) oder Blende'.freeze
  HILFE = [
    'Für einen Einbaubackofen (Front 595 mm) unter dem Kochfeld: Der Ofen steht auf einem Einbauboden, oben gibt es keine Streben.',
    'Unter dem Einbauboden kommt eine flache Schublade, wenn die lichte Höhe reicht (Min. lichte Höhe Schublade), sonst eine feste Blende.',
    'Bei 700 mm Korpus und 600 mm Nische reicht der Platz nicht, es wird eine Blende.',
    'Nischenhöhe, Lüftungsspalt hinten und „Unten“ (automatisch/Blende) hier ändern.',
    'Maße sind Richtwerte – mit der Einbauanleitung des Geräts prüfen.',
    'Gezeichnet ist das Endmaß; den Anleimer (2 mm) ziehen Stückliste und Zuschnitt ab.',
    'Jedes Teil hat einen eigenen Tag <Kürzel>_<Bereich>_<Teil>, z. B. USB1_ZwischenbodenUnten, USB1_S1_Front.',
    'Feste Maße (Materialstärken, Abstände): Fenster „Komponentenattribute“.',
    "Doku: #{DOKU_URL}"
  ].join(' ').freeze

  # ---------------------------------------------------------------------------
  # Reine Berechnung (ohne SketchUp), spiegelt exakt die DC-Formeln. Werte in cm.
  # ---------------------------------------------------------------------------
  def self.berechne(p)
    mk = p['Materialstaerke_Korpus']
    z_eb = p['Hoehe'] - p['Nischenhoehe']        # Oberkante Einbauboden
    lichte = z_eb - 2 * mk                       # zwischen Boden und Einbauboden
    schublade = p['Unten'].round.zero? && lichte >= p['Min_Lichte_Schublade'] - 0.000001
    { z_einbauboden: z_eb, lichte_unten: lichte, h_front: z_eb - p['Spaltbreite'],
      schublade: schublade, nl: nennlaenge(p['Tiefe']) }
  end

  # Formeln am Schrank stützen sich nur auf Eingabe-Attribute (echte DC rechnet einmal der
  # Reihe nach); die Teile lesen sie dann als Eltern-Attribut.
  def self.f_schublade
    'IF(Unten>0.5,0,IF(Hoehe-Nischenhoehe-2*Materialstaerke_Korpus>=Min_Lichte_Schublade-0.000001,1,0))'
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

  # Benutzerdefiniertes Attribut am Hauptbauteil bzw. an einer Schublade.
  # laenge: true  -> Wert in cm, wird intern in Zoll gespeichert
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

  # Auswahlliste "&Text=Wert&…&" für die Komponentenoptionen
  def self.liste(namen)
    '&' + namen.each_with_index.map { |n, i| "#{n}=#{i}" }.join('&') + '&'
  end

  # Sichtbarkeit über das DC-Attribut hidden (Formel), dazu der Stand beim Erzeugen
  def self.sichtbarkeit(d, sichtbar, formel)
    d.set_attribute(DICT, 'hidden', sichtbar ? 0.0 : 1.0)
    d.set_attribute(DICT, '_hidden_formula', formel)
    d.set_attribute(DICT, '_hidden_label', 'Hidden')
    d.set_attribute(DICT, '_hidden_formlabel', 'Hidden')
    d.set_attribute(DICT, '_hidden_units', 'BOOLEAN')
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

  def self.material(model, name = MATERIAL)
    m = model.materials[name] || begin
      neu = model.materials.add(name)
      neu.color = Sketchup::Color.new(255, 255, 255)
      neu
    end
    if m.get_attribute(OCL_DICT, 'type').nil?
      OCL_MATERIALIEN[name].each { |k, v| m.set_attribute(OCL_DICT, k, v) }
    end
    m
  end

  # Eindeutiges Kürzel für die Tags, z. B. USB1, USB2 …
  def self.freies_kuerzel(model)
    n = 1
    n += 1 while model.layers.to_a.any? { |l| l.name.start_with?("USB#{n}_") }
    "USB#{n}"
  end

  def self.tag(model, name)
    model.layers[name] || model.layers.add(name)
  end

  # Tag <Kürzel>_<Bereich>_<Teil> (z. B. USB1_Blende, USB1_S1_Front) und JT_Schrank am Teil
  def self.kennzeichnen(model, inst, kz, teil, bereich = nil)
    inst.layer = tag(model, [kz, bereich, teil].compact.join('_'))
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE, 'bereich' => bereich.to_s,
      'teil' => teil, 'rolle' => ROLLEN.fetch(teil.sub(/\d+\z/, '')) }.each { |k, v| inst.set_attribute(JT_DICT, k, v) }
    inst
  end

  def self.quader(ents, lx, ly, lz)
    f = ents.add_face([0, 0, 0], [inch(lx), 0, 0], [inch(lx), inch(ly), 0], [0, inch(ly), 0])
    f.reverse! if f.normal.z < 0
    f.pushpull(inch(lz))
  end

  # Richtung einer Quaderfläche anhand ihrer Normalen
  def self.seite_von(face)
    n = face.normal
    return n.x > 0 ? :xmax : :xmin if n.x.abs > 0.5
    return n.y > 0 ? :ymax : :ymin if n.y.abs > 0.5
    n.z > 0 ? :zmax : :zmin
  end

  # Kantenflächen mit dem Anleimer-Material belegen (so erkennen Stückliste und Zuschnitt die Kanten)
  def self.anleimer_setzen(defn, kanten, anleimer)
    defn.entities.grep(Sketchup::Face).each do |f|
      f.material = anleimer if kanten.include?(seite_von(f))
    end
  end

  # Legt eine Platten-Definition an (Quader lx*ly*lz cm) mit LenX/Y/Z-Formeln.
  def self.platte(model, defname, dc_name, groesse, len_formeln)
    d = model.definitions.add(defname)
    quader(d.entities, *groesse)
    anleimer_setzen(d, KANTEN.fetch(dc_name), material(model, ANLEIMER))
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

  # Setzt eine Instanz an pos (cm) mit Positionsformeln.
  # kz: [Modell, Kürzel, Teil, Bereich] -> Tag und JT_Schrank (siehe kennzeichnen)
  def self.einsetzen(ents, defn, inst_name, pos, pos_formeln, mat: nil, layer: nil, kz: nil)
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

  # Nischen für die Geräte-Komponenten (Maße in mm, Stand beim Erzeugen):
  # JT_Nische_N1 Backofen, Einfügepunkt vorne links auf dem Einbauboden;
  # JT_Nische_KF Kochfeld, Einfügepunkt vorne links auf der Korpusoberkante.
  def self.nischen(d, p, r)
    mm = ->(cm) { (cm * 10).round(1) }
    mk = p['Materialstaerke_Korpus']
    lw = mm.(p['Breite'] - 2 * mk)
    { "#{NISCHE_DICT}_N1" => { 'nische' => 'N1', 'geraet' => 'Backofen60', 'breite' => lw,
                               'hoehe' => mm.(p['Nischenhoehe']), 'tiefe' => mm.(p['Tiefe']),
                               'x' => mm.(mk), 'y' => mm.(mk), 'z' => mm.(r[:z_einbauboden]) },
      "#{NISCHE_DICT}_KF" => { 'nische' => 'KF', 'geraet' => "Kochfeld#{p['Breite'].round}", 'breite' => lw,
                               'hoehe' => 0.0, 'tiefe' => mm.(p['Tiefe']),
                               'x' => mm.(mk), 'y' => mm.(mk), 'z' => mm.(p['Hoehe']),
                               'arbeitsplatte' => mm.(p['Arbeitsplatte']) } }
      .each { |dict, werte| werte.each { |k, v| d.set_attribute(dict, k, v) } }
  end

  # ---------------------------------------------------------------------------
  # Aufbau
  # ---------------------------------------------------------------------------
  def self.erzeuge(model, eingabe)
    p = DEFAULTS.merge(eingabe)
    r = berechne(p)
    u = NAME
    mat = material(model)
    kz = p['Kuerzel'] || freies_kuerzel(model)
    t_ = ->(teil, bereich = nil) { [model, kz, teil, bereich] } # ein Tag je Teil für die CAD/CAM-Zuordnung

    haupt = model.definitions.add('Unterschrank Backofen (Herdumbau)')
    stempel(haupt)
    haupt.set_attribute(DICT, '_name', u)
    hilfe(haupt)

    # --- Parameter (sichtbar in den Komponentenoptionen) ---
    attribut(haupt, 'Breite', p['Breite'], access: 'TEXTBOX', formlabel: 'Breite')
    attribut(haupt, 'Hoehe', p['Hoehe'], access: 'TEXTBOX', formlabel: 'Hoehe')
    attribut(haupt, 'Tiefe', p['Tiefe'], access: 'TEXTBOX', formlabel: 'Tiefe (Korpus ohne Front/Rückwand)')
    attribut(haupt, 'Nischenhoehe', p['Nischenhoehe'], access: 'TEXTBOX',
             formlabel: 'Nischenhöhe Backofen (Einbauboden bis Korpusoberkante)')
    attribut(haupt, 'Lueftungsspalt', p['Lueftungsspalt'], access: 'TEXTBOX', formlabel: 'Lüftungsspalt hinten im Einbauboden')
    attribut(haupt, 'Unten', p['Unten'].to_f, laenge: false, access: 'LIST',
             formlabel: 'Unten (Schublade, wenn Platz)', units: 'INTEGER', options: liste(UNTEN))
    attribut(haupt, 'Min_Lichte_Schublade', p['Min_Lichte_Schublade'], access: 'TEXTBOX',
             formlabel: 'Min. lichte Höhe für die Schublade')
    attribut(haupt, 'Arbeitsplatte', p['Arbeitsplatte'], access: 'TEXTBOX', formlabel: 'Stärke Arbeitsplatte (für Geräte)')
    attribut(haupt, 'Materialstaerke_Kastenboden', p['Materialstaerke_Kastenboden'], access: 'TEXTBOX',
             formlabel: 'Stärke Kastenboden')
    attribut(haupt, 'Hoehenoffset_Schiene', p['Hoehenoffset_Schiene'], access: 'TEXTBOX',
             formlabel: 'Höhenoffset Schiene (Bohrung über Unterkante Kasten)')

    # --- Feste Maße (wie beim Unterschrank mit Tür über Attribute änderbar) ---
    %w[Materialstaerke_Korpus Materialstarke_Rueckwand Spaltbreite
       Materialstaerke_Kastenrueckwand Hoehe_Kastenrueckwand Kasten_Abstand_unten Kasten_Abstand_oben
       Lochraster_Start Lochraster].each do |n|
      attribut(haupt, n, p[n], units: 'STRING')
    end
    # Nennlänge der LEGRABOX-Schiene: größte NL (35 … 65 cm, 5er-Schritte) mit NL + 3 mm <= Tiefe
    attribut(haupt, 'NL', r[:nl], units: 'STRING', formula: f_nennlaenge('Tiefe'))
    attribut(haupt, 'Auszug_Anteil', p['Auszug_Anteil'], laenge: false, units: 'STRING')
    # abgeleitet (nur aus Eingaben): Fronthöhe unten, Schublade ja/nein
    attribut(haupt, 'H_Front', r[:h_front], units: 'STRING', formula: 'Hoehe-Nischenhoehe-Spaltbreite')
    attribut(haupt, 'Schublade', r[:schublade] ? 1.0 : 0.0, laenge: false, units: 'STRING', formula: f_schublade)

    mk = p['Materialstaerke_Korpus']
    b, h, t = p['Breite'], p['Hoehe'], p['Tiefe']
    rw, sp = p['Materialstarke_Rueckwand'], p['Spaltbreite']
    z_eb = r[:z_einbauboden]
    e = haupt.entities

    # --- Korpus: Seiten und Boden wie beim Unterschrank, keine Streben ---
    seite = platte(model, 'Seite', 'Seite', [mk, t, h],
                   ["#{u}!Materialstaerke_Korpus", "#{u}!Tiefe", "#{u}!Hoehe"])
    einsetzen(e, seite, 'SeiteL', [0, mk, 0], [nil, nil, nil], mat: mat, kz: t_.('SeiteL'))
    einsetzen(e, seite, 'SeiteR', [b - mk, mk, 0],
              ["#{u}!Breite-#{u}!Materialstaerke_Korpus", nil, nil], mat: mat, kz: t_.('SeiteR'))

    boden = platte(model, 'Boden', 'Boden', [b - 2 * mk, t, mk],
                   ["#{u}!Breite-2*#{u}!Materialstaerke_Korpus", "#{u}!Tiefe", "#{u}!Materialstaerke_Korpus"])
    einsetzen(e, boden, 'Boden', [mk, mk, 0], ["#{u}!Materialstaerke_Korpus", nil, nil],
              mat: mat, kz: t_.('Boden'))

    # Einbauboden: der Ofen steht darauf; hinten Lüftungsspalt. Rolle Zwischenboden, mit
    # JT_Schrank/nische, damit der TCN-Export in der Nische keine Lochreihe bohrt.
    eb = platte(model, 'Einbauboden', 'Einbauboden', [b - 2 * mk, t - p['Lueftungsspalt'], mk],
                ["#{u}!Breite-2*#{u}!Materialstaerke_Korpus", "#{u}!Tiefe-#{u}!Lueftungsspalt", "#{u}!Materialstaerke_Korpus"])
    eb_inst = einsetzen(e, eb, 'ZwischenbodenUnten', [mk, mk, z_eb - mk],
                        ["#{u}!Materialstaerke_Korpus", nil, "#{u}!Hoehe-#{u}!Nischenhoehe-#{u}!Materialstaerke_Korpus"],
                        mat: mat, kz: t_.('ZwischenbodenUnten'))
    eb_inst.set_attribute(JT_DICT, 'nische', 'N1')

    # Rückwand nur unterhalb des Einbaubodens (bis zu seiner Oberkante)
    rueck = platte(model, 'Rückwand', 'Rückwand', [b, rw, z_eb],
                   ["#{u}!Breite", "#{u}!Materialstarke_Rueckwand", "#{u}!Hoehe-#{u}!Nischenhoehe"])
    einsetzen(e, rueck, 'Rückwand', [0, t + mk, 0],
              [nil, "#{u}!Tiefe+#{u}!Materialstaerke_Korpus", nil], mat: mat, kz: t_.('Rueckwand'))

    # --- Unten: Blende (fest) oder Schublade, je nach lichter Höhe ---
    bl_def = platte(model, 'Blende', 'Blende', [b - sp, mk, r[:h_front]],
                    ["#{u}!Breite-#{u}!Spaltbreite", "#{u}!Materialstaerke_Korpus", "#{u}!H_Front"])
    sichtbarkeit(bl_def, !r[:schublade], "IF(#{u}!Schublade>0.5,1,0)")
    bl = einsetzen(e, bl_def, 'Blende', [sp / 2.0, -sp, 0], ["#{u}!Spaltbreite/2", "-#{u}!Spaltbreite", nil],
                   mat: mat, kz: t_.('Blende'))
    bl.hidden = r[:schublade]
    schublade(model, e, p, r, mat, kz)

    haupt.set_attribute(OCL_DICT, 'kuerzel', kz)
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE }.each { |k, v| haupt.set_attribute(JT_DICT, k, v) }
    nischen(haupt, p, r)
    haupt
  end

  # LEGRABOX gibt es nur in festen Nennlängen (cm). Gewählt wird die größte mit NL + 3 mm <= Tiefe;
  # passt keine (Tiefe < 353 mm), bleibt es bei der kürzesten, der TCN-Export meldet dann zu wenig Tiefe.
  NENNLAENGEN = [35.0, 40.0, 45.0, 50.0, 55.0, 60.0, 65.0].freeze

  def self.nennlaenge(tiefe)
    NENNLAENGEN.select { |nl| nl + 0.3 <= tiefe + 0.000001 }.max || NENNLAENGEN.first
  end

  # dieselbe Wahl als DC-Formel (die Nennlängen liegen im 5-cm-Raster)
  def self.f_nennlaenge(tiefe)
    "MAX(35,MIN(65,INT((#{tiefe}-0.3)/5+0.000001)*5))"
  end

  # Flache Schublade mit Blum LEGRABOX free unter dem Einbauboden: Front, Boden (LW-35 x NL-10)
  # und Holzrückwand (LW-38, höchstens Hoehe_Kastenrueckwand und bis Kasten_Abstand_oben unter
  # den Einbauboden); die Zargen sind aus Metall.
  def self.schublade(model, ents, p, r, mat, kz)
    u  = NAME
    s  = 'Schublade1'
    mk = p['Materialstaerke_Korpus']
    sp = p['Spaltbreite']
    b  = p['Breite']
    mb   = p['Materialstaerke_Kastenboden']
    mrw  = p['Materialstaerke_Kastenrueckwand']
    nl   = r[:nl]
    hf   = r[:h_front]
    lw   = b - 2 * mk
    ab   = kasten_unten(p)
    kh   = [r[:z_einbauboden] - mk - p['Kasten_Abstand_oben'] - ab, 2.0].max # Kastenhöhe, mind. 2 cm
    hrw  = [p['Hoehe_Kastenrueckwand'], kh - mb].min
    st = ->(teil) { [model, kz, teil, 'S1'] }

    d = model.definitions.add(s)
    stempel(d)
    d.set_attribute(DICT, '_name', s)
    # Lokale Kopien der Werte vom Schrank (Formeln können nur Eltern/Geschwister ansprechen)
    attribut(d, 'Breite', b, units: 'STRING', formula: "#{u}!Breite")
    attribut(d, 'Hoehe_Front', hf, units: 'STRING', formula: "#{u}!H_Front")
    attribut(d, 'Mk', mk, units: 'STRING', formula: "#{u}!Materialstaerke_Korpus")
    attribut(d, 'Spalt', sp, units: 'STRING', formula: "#{u}!Spaltbreite")
    attribut(d, 'Mb', mb, units: 'STRING', formula: "#{u}!Materialstaerke_Kastenboden")
    attribut(d, 'Mrw', mrw, units: 'STRING', formula: "#{u}!Materialstaerke_Kastenrueckwand")
    attribut(d, 'Hrw', p['Hoehe_Kastenrueckwand'], units: 'STRING', formula: "#{u}!Hoehe_Kastenrueckwand")
    attribut(d, 'NL', nl, units: 'STRING', formula: "#{u}!NL")
    attribut(d, 'Ab_unten', ab, units: 'STRING', formula: f_kasten_unten)
    roh_kh = "#{u}!Hoehe-#{u}!Nischenhoehe-#{u}!Materialstaerke_Korpus-#{u}!Kasten_Abstand_oben-(#{f_kasten_unten})"
    attribut(d, 'Kh', kh, units: 'STRING', formula: "MAX(#{roh_kh},2)")
    attribut(d, 'Auszug', nl * p['Auszug_Anteil'], units: 'STRING', formula: "#{u}!NL*#{u}!Auszug_Anteil")
    sichtbarkeit(d, r[:schublade], "IF(#{u}!Schublade>0.5,0,1)")
    # Mit "Interagieren" anklicken -> Schublade fährt heraus
    d.set_attribute(DICT, 'onclick', 'ANIMATE("Y",0,-Auszug)')
    d.set_attribute(DICT, '_onclick_label', 'onClick')

    de = d.entities
    # Front (wie Tür: Spalt/2 seitlich, -Spalt vor dem Korpus)
    front = platte(model, 'Front S1', 'Front', [b - sp, mk, hf],
                   ["#{s}!Breite-#{s}!Spalt", "#{s}!Mk", "#{s}!Hoehe_Front"])
    einsetzen(de, front, 'Front', [sp / 2.0, -sp, 0], ["#{s}!Spalt/2", "-#{s}!Spalt", nil],
              mat: mat, kz: st.('Front'))

    # Boden LW-35 x NL-10, mittig, vorne an der Korpusvorderkante
    kbod = platte(model, 'Kasten Boden S1', 'KastenBoden', [lw - 3.5, nl - 1.0, mb],
                  ["#{s}!Breite-2*#{s}!Mk-3.5", "#{s}!NL-1", "#{s}!Mb"])
    einsetzen(de, kbod, 'KastenBoden', [mk + 1.75, mk, ab],
              ["#{s}!Mk+1.75", "#{s}!Mk", "#{s}!Ab_unten"], mat: mat, kz: st.('KastenBoden'))

    # Holzrückwand LW-38, hinten auf dem Boden
    krw = platte(model, 'Kasten Rueckwand S1', 'KastenRueckwand', [lw - 3.8, mrw, hrw],
                 ["#{s}!Breite-2*#{s}!Mk-3.8", "#{s}!Mrw", "MIN(#{s}!Hrw,#{s}!Kh-#{s}!Mb)"])
    einsetzen(de, krw, 'KastenRueckwand', [mk + 1.9, mk + nl - 1.0 - mrw, ab + mb],
              ["#{s}!Mk+1.9", "#{s}!Mk+#{s}!NL-1-#{s}!Mrw", "#{s}!Ab_unten+#{s}!Mb"],
              mat: mat, kz: st.('KastenRueckwand'))

    inst = einsetzen(ents, d, s, [0, 0, 0], [nil, nil, nil], layer: tag(model, "#{kz}_S1_Schublade"))
    inst.hidden = !r[:schublade]
    inst
  end

  # ---------------------------------------------------------------------------
  # Eingabe
  # ---------------------------------------------------------------------------
  def self.mm(text)
    text.to_s.tr(',', '.').to_f / 10.0
  end

  TIEFE_NEU = 52.0 # cm, Vorschlag im Dialog

  def self.dialog
    prompts = ['Breite (mm)', 'Höhe (mm)', 'Tiefe Korpus (mm)', 'Nischenhöhe Backofen (mm)', 'Unten',
               'Kürzel für Tags (eindeutig je Schrank)']
    defaults = ['600', '700', (TIEFE_NEU * 10).round.to_s, '600', UNTEN.first, freies_kuerzel(Sketchup.active_model)]
    lists = ['', '', '', '', UNTEN.join('|'), '']
    Kuechenplaner::Eingabe.abfragen(prompts, defaults, lists, 'Unterschrank Backofen (Herdumbau)', untertitel: 'Neuer Schrank', ok: 'Einfügen') do |res|
      eingabe = {
        'Breite' => mm(res[0]), 'Hoehe' => mm(res[1]), 'Tiefe' => mm(res[2]), 'Nischenhoehe' => mm(res[3]),
        'Unten' => UNTEN.index(res[4]).to_f, 'Kuerzel' => res[5].strip
      }
      raise ArgumentError, 'Kürzel darf nicht leer sein' if eingabe['Kuerzel'].empty?
      if Sketchup.active_model.layers.to_a.any? { |l| l.name.start_with?("#{eingabe['Kuerzel']}_") }
        raise ArgumentError, "Kürzel #{eingabe['Kuerzel']} ist schon vergeben"
      end
      p = DEFAULTS.merge(eingabe)
      if p['Nischenhoehe'] > p['Hoehe'] - 2 * p['Materialstaerke_Korpus']
        raise ArgumentError, 'Nischenhöhe zu groß für die Schrankhöhe (Boden und Einbauboden brauchen Platz)'
      end
      warnungen(p).each { |w| UI.messagebox(w) }
      erstellen(eingabe)
    end
  rescue ArgumentError => e
    UI.messagebox("Ungültige Eingabe: #{e.message}")
  end

  # Hinweise vor dem Erzeugen (der Schrank wird trotzdem gebaut)
  def self.warnungen(p)
    r = berechne(p)
    w = []
    lw = (p['Breite'] - 2 * p['Materialstaerke_Korpus']) * 10
    w << "Lichte Breite #{lw.round} mm: Einbaubacköfen brauchen meist 560–568 mm." if lw < 560 - 0.001
    if p['Unten'].round.zero? && !r[:schublade]
      w << "Unter dem Einbauboden sind nur #{(r[:lichte_unten] * 10).round} mm frei, " \
           "für die Schublade braucht es #{(p['Min_Lichte_Schublade'] * 10).round} mm. Es wird eine feste Blende."
    end
    w
  end

  def self.erstellen(eingabe)
    model = Sketchup.active_model
    model.start_operation('Unterschrank Backofen (Herdumbau)', true)
    defn = erzeuge(model, eingabe)
    # Rechts neben vorhandene Geometrie setzen, damit nichts überlappt
    x = model.entities.length > 0 ? model.bounds.max.x + 10.cm : 0
    inst = model.entities.add_instance(defn, Geom::Transformation.translation([x, 0, 0]))
    inst.name = NAME
    inst.set_attribute(DICT, '_name', NAME)
    model.commit_operation

    # Formeln einmal durch das Dynamic-Components-Plugin auswerten lassen
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

  unless file_loaded?(__FILE__)
    Kuechenplaner.schrank('Unterschränke', 'Unterschrank Backofen (Herdumbau)…') { dialog }
    file_loaded(__FILE__)
  end
end
