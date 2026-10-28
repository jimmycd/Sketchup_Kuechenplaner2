# encoding: UTF-8
#
# Unterschrank für ein Kochfeld mit integriertem Abzug – Generator für eine Dynamic Component
#
# Aufbau wie der "Unterschrank mit Schubladen", aber für ein Kochfeld mit
# Muldenlüfter (Downdraft): Unter dem Kochfeld sitzt das Lüftermodul, dahinter
# läuft der Kanal senkrecht nach unten in den Sockel (Umluftfilter im Sockel oder
# Abluft nach außen). Deshalb:
#   * oben eine feste Blende statt einer Schublade (Höhe = Einbauraum des Geräts),
#   * darunter 1–3 Schubladen (Blum LEGRABOX), kürzer um die Installationstiefe,
#   * hinten ein freier Installationsraum für den Kanal,
#   * ein Ausschnitt im Boden für den Kanal (nur in den CNC-Daten, siehe README),
#   * Strebe vorn hochkant (Kochfeldausschnitt bleibt frei), keine Strebe hinten.
# Anzahl, Aufteilung und alle Maße bleiben über "Komponentenoptionen" änderbar.

require 'sketchup.rb'

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

module UnterschrankKochfeld

  DICT     = 'dynamic_attributes'.freeze
  NAME     = 'Unterschrank_Kochfeld'.freeze
  MAX_SCHUBLADEN = 3
  PARK_HOEHE = 10.0 # cm
  MATERIAL = 'Melamin weiss'.freeze
  ANLEIMER = 'Anleimer weiss'.freeze
  OCL_DICT = 'ladb_opencutlist'.freeze

  # Tag-Schema für den TCN-Export (gleich in allen Komponenten, der Test prüft das):
  # Tag <Kürzel>_<Bereich>_<Teil>, dazu am Teil das Wörterbuch JT_Schrank.
  JT_DICT   = 'JT_Schrank'.freeze
  TYP       = 'Unterschrank_Kochfeld'.freeze
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

  # Nische für die Geräte-Komponenten (Thread "Geräte in Schränken darstellen")
  NISCHE_DICT = 'JT_Nische'.freeze
  LUEFTUNG = %w[Umluft Abluft].freeze
  KANAL_LAGE = %w[links mittig rechts].freeze

  # OpenCutList-Einstellungen, falls die Materialien im Modell noch fehlen
  # (Werte wie in Unterschrank.skp). Vorhandene OCL-Einstellungen bleiben unangetastet.
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

  # Sichtbare Kanten je Teil, bekommen in OCL einen Anleimer.
  # Richtungen im Schrank: ymin = vorne, zmax = oben, xmin/xmax = links/rechts.
  # SketchUp zeigt Endmaße; den Abzug für den Anleimer rechnet nur OCL.
  KANTEN = {
    'Seite'        => %i[ymin],                  # Vorderkante
    'Boden'        => %i[ymin],
    'StrebeVorn'   => [],                        # verdeckt hinter der Blende
    'Rückwand'     => [],
    'Blende'       => %i[xmin xmax zmin zmax],   # rundum wie die Fronten
    'Front'        => %i[xmin xmax zmin zmax],
    'KastenRueckwand' => %i[zmax],               # Oberkante
    'KastenBoden'  => []
  }.freeze

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

  # Standardwerte in cm. Gerätemaße sind Richtwerte (Jürgen, 2026-10-26), je Gerät prüfen.
  DEFAULTS = {
    'Breite'                      => 80.0,
    'Hoehe'                       => 70.0,
    'Tiefe'                       => 80.0,
    'Anz_Schubladen'              => 2,
    'Anteil_1'                    => 1.0,
    'Anteil_2'                    => 1.0,
    'Anteil_3'                    => 1.0,
    'Hoehe_Blende'                => 20.0, # Einbauraum für Kochfeld und Lüftermodul unter der Korpusoberkante
    'Installationstiefe'          => 15.0, # hinten frei für den Kanal
    'Kanal_Breite'                => 30.0, # Breite des Bodenausschnitts
    'Kanal_Lage'                  => 1.0,  # 0 = links, 1 = mittig, 2 = rechts
    'Lueftung'                    => 0.0,  # 0 = Umluft (Filter im Sockel), 1 = Abluft
    'Strebe_Vorn'                 => 0.0,  # 0 = hochkant, 1 = flach
    'Arbeitsplatte'               => 4.0,  # Stärke, nur für die Lage der Geräte
    'Kanal_Rand'                  => 10.0, # Ausschnitt links/rechts: Abstand zur Seite (frei von den Sockelfüßen)
    'Kanal_Steg'                  => 2.0,  # Steg hinter und vor dem Ausschnitt
    'Materialstaerke_Korpus'      => 1.9,
    'Materialstarke_Rueckwand'    => 0.8,
    'BreiteStreben'               => 10.0,
    'Spaltbreite'                 => 0.2,
    # Schubkasten Blum LEGRABOX free (Montageanleitung MD-015/4): Metallzargen, aus Holz nur
    # Boden (LW-35 x NL-10, 16 mm) und Holzrückwand (LW-38 x 148, auf dem Boden)
    'Materialstaerke_Kastenboden' => 1.6,
    'Materialstaerke_Kastenrueckwand' => 1.6,
    'Hoehe_Kastenrueckwand'       => 14.8,
    'Hoehenoffset_Schiene'        => 0.0,  # Schienenbohrung über Unterkante Kasten
    'Lochraster_Start'            => 3.5,  # erste Rasterbohrung über Unterkante Seite
    'Lochraster'                  => 3.2,
    'Kasten_Abstand_unten'        => 3.0,  # Unterkante Front -> Unterkante Kasten
    'Kasten_Abstand_oben'         => 3.0,  # Oberkante Kasten -> Oberkante Front
    'Auszug_Anteil'               => 0.8   # Animation: Auszugsweg = Kastentiefe * Anteil
  }.freeze

  # Kurzhilfe in der Komponente (Kurzfassung der README.md). SketchUp zeigt
  # "summary" und "description" oben im Fenster "Komponentenoptionen".
  DOKU_URL = 'https://github.com/jimmycd/sketchup_kuechenplaner2/tree/main/Komponenten/unterschrank_kochfeld'.freeze
  HILFE_KURZ = 'Unterschrank für Kochfeld mit Abzug: Blende, 1–3 Schubladen (Blum LEGRABOX), OpenCutList-fähig'.freeze
  HILFE = [
    'Für Kochfelder mit integriertem Abzug: oben feste Blende (Einbauraum Kochfeld + Lüfter), darunter 1–3 Schubladen.',
    'Höhe Blende, Installationstiefe (hinten frei für den Kanal), Kanalausschnitt im Boden (Breite, Lage) und Umluft/Abluft hier ändern.',
    'Maße sind Richtwerte – mit der Einbauanleitung des Geräts prüfen.',
    'Schubkästen: Blum LEGRABOX free, Nennlänge NL aus Tiefe minus Installationstiefe.',
    'Der Bodenausschnitt ist nur in den CNC-Daten (TCN), in SketchUp ist der Boden voll gezeichnet.',
    'Gezeichnet ist das Endmaß; den Anleimer (2 mm) zieht nur OpenCutList ab.',
    'Jedes Teil hat einen eigenen Tag <Kürzel>_<Bereich>_<Teil>, z. B. USK1_Blende, USK1_S2_Front.',
    'Feste Maße (Materialstärken, Abstände): Fenster „Komponentenattribute“.',
    "Doku: #{DOKU_URL}"
  ].join(' ').freeze

  # ---------------------------------------------------------------------------
  # Reine Berechnung (ohne SketchUp), spiegelt exakt die DC-Formeln.
  # Alle Werte in cm.
  # ---------------------------------------------------------------------------
  def self.berechne(p)
    n      = p['Anz_Schubladen'].to_i
    anteil = (1..MAX_SCHUBLADEN).map { |i| p["Anteil_#{i}"].to_f }
    summe  = anteil.first(n).sum
    oben   = p['Hoehe'] - p['Hoehe_Blende'] - p['Spaltbreite'] # Oberkante oberste Schubladenfront
    netto  = oben - (n - 1) * p['Spaltbreite']
    fronten = (1..MAX_SCHUBLADEN).map do |i|
      if i <= n
        h = netto * anteil[i - 1] / summe
        z = oben - netto * anteil.first(i).sum / summe - (i - 1) * p['Spaltbreite']
      else
        # ausgeblendete Schubladen im Korpus parken, damit sie die Bounding Box nicht vergrößern
        h = PARK_HOEHE
        z = 0.0
      end
      { h: h, z: z }
    end
    { summe: summe, netto: netto, fronten: fronten, ausschnitt: ausschnitt(p) }
  end

  # Kanalausschnitt im Boden (cm): Abstand vom linken Rand des Bodens, Breite,
  # Abstand von der Hinterkante des Bodens, Tiefe
  def self.ausschnitt(p)
    lw = p['Breite'] - 2 * p['Materialstaerke_Korpus']
    kb = p['Kanal_Breite']
    links = case p['Kanal_Lage'].round
            when 0 then p['Kanal_Rand']
            when 2 then lw - kb - p['Kanal_Rand']
            else (lw - kb) / 2.0
            end
    { links: links, breite: kb, hinten: p['Kanal_Steg'], tiefe: p['Installationstiefe'] - 2 * p['Kanal_Steg'] }
  end

  # ---------------------------------------------------------------------------
  # Formeln
  # ---------------------------------------------------------------------------
  def self.f_summe
    terms = ['Anteil_1'] + (2..MAX_SCHUBLADEN).map { |i| "IF(Anz_Schubladen>=#{i},Anteil_#{i},0)" }
    "(#{terms.join('+')})"
  end

  def self.f_oben
    '(Hoehe-Hoehe_Blende-Spaltbreite)'
  end

  def self.f_netto
    "(#{f_oben}-(Anz_Schubladen-1)*Spaltbreite)"
  end

  # Ausgeblendete Schubladen (i > Anzahl) werden mit dieser Höhe bei z=0 geparkt
  def self.nur_sichtbar(i, formel, park)
    i == 1 ? formel : "IF(Anz_Schubladen>=#{i},#{formel},#{park})"
  end

  def self.f_h_front(i)
    nur_sichtbar(i, "#{f_netto}*Anteil_#{i}/#{f_summe}", PARK_HOEHE)
  end

  def self.f_z_front(i)
    teil = (1..i).map { |j| "Anteil_#{j}" }.join('+')
    nur_sichtbar(i, "#{f_oben}-#{f_netto}*(#{teil})/#{f_summe}-#{i - 1}*Spaltbreite", 0)
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

  # Eindeutiges Kürzel für die Tags, z. B. USK1, USK2 …
  def self.freies_kuerzel(model)
    n = 1
    n += 1 while model.layers.to_a.any? { |l| l.name.start_with?("USK#{n}_") }
    "USK#{n}"
  end

  def self.tag(model, name)
    model.layers[name] || model.layers.add(name)
  end

  # Tag <Kürzel>_<Bereich>_<Teil> (z. B. USK1_Blende, USK1_S2_Front) und JT_Schrank am Teil
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

  # Kantenflächen mit dem Anleimer-Material belegen (so erkennt OCL die Kanten)
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

  # Nische für die Geräte-Komponenten: Einbauraum unter dem Kochfeld (lichte Weite x
  # Höhe Blende x Tiefe) und Einfügepunkt vorne links auf der Korpusoberkante, in mm,
  # Stand beim Erzeugen; dazu Lüftung, Kanal und Arbeitsplattenstärke.
  def self.nische(d, p, r)
    mm = ->(cm) { (cm * 10).round(1) }
    mk = p['Materialstaerke_Korpus']
    a = r[:ausschnitt]
    { 'nische' => 'KF', 'geraet' => "KochfeldAbzug#{p['Breite'].round}",
      'breite' => mm.(p['Breite'] - 2 * mk), 'hoehe' => mm.(p['Hoehe_Blende']), 'tiefe' => mm.(p['Tiefe']),
      'x' => mm.(mk), 'y' => mm.(mk), 'z' => mm.(p['Hoehe']),
      'lueftung' => LUEFTUNG[p['Lueftung'].round], 'installationstiefe' => mm.(p['Installationstiefe']),
      'kanal_breite' => mm.(a[:breite]), 'kanal_lage' => KANAL_LAGE[p['Kanal_Lage'].round],
      'kanal_x' => mm.(mk + a[:links]), 'arbeitsplatte' => mm.(p['Arbeitsplatte']) }
      .each { |k, v| d.set_attribute(NISCHE_DICT, k, v) }
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

    haupt = model.definitions.add('Unterschrank Kochfeld mit Abzug')
    stempel(haupt)
    haupt.set_attribute(DICT, '_name', u)
    hilfe(haupt)

    # --- Parameter (sichtbar in den Komponentenoptionen) ---
    attribut(haupt, 'Breite', p['Breite'], access: 'TEXTBOX', formlabel: 'Breite')
    attribut(haupt, 'Hoehe', p['Hoehe'], access: 'TEXTBOX', formlabel: 'Hoehe')
    attribut(haupt, 'Tiefe', p['Tiefe'], access: 'TEXTBOX', formlabel: 'Tiefe (Korpus ohne Front/Rückwand)')
    attribut(haupt, 'Hoehe_Blende', p['Hoehe_Blende'], access: 'TEXTBOX',
             formlabel: 'Höhe Blende (Einbauraum Kochfeld + Lüfter)')
    opts = '&' + (1..MAX_SCHUBLADEN).map { |i| "#{i}=#{i}" }.join('&') + '&'
    attribut(haupt, 'Anz_Schubladen', p['Anz_Schubladen'].to_f, laenge: false, access: 'LIST',
             formlabel: 'Anzahl Schubladen', units: 'INTEGER', options: opts)
    (1..MAX_SCHUBLADEN).each do |i|
      lage = i == 1 ? ' (oben)' : ''
      attribut(haupt, "Anteil_#{i}", p["Anteil_#{i}"].to_f, laenge: false, access: 'TEXTBOX',
               formlabel: "Anteil Schublade #{i}#{lage}")
    end
    attribut(haupt, 'Installationstiefe', p['Installationstiefe'], access: 'TEXTBOX',
             formlabel: 'Installationstiefe hinten (Kanal)')
    attribut(haupt, 'Kanal_Breite', p['Kanal_Breite'], access: 'TEXTBOX', formlabel: 'Breite Kanalausschnitt im Boden')
    attribut(haupt, 'Kanal_Lage', p['Kanal_Lage'].to_f, laenge: false, access: 'LIST',
             formlabel: 'Lage Kanalausschnitt', units: 'INTEGER', options: liste(KANAL_LAGE))
    attribut(haupt, 'Lueftung', p['Lueftung'].to_f, laenge: false, access: 'LIST',
             formlabel: 'Lüftung', units: 'INTEGER', options: liste(LUEFTUNG))
    attribut(haupt, 'Strebe_Vorn', p['Strebe_Vorn'].to_f, laenge: false, access: 'LIST',
             formlabel: 'Strebe vorn', units: 'INTEGER', options: liste(%w[hochkant flach]))
    attribut(haupt, 'Arbeitsplatte', p['Arbeitsplatte'], access: 'TEXTBOX', formlabel: 'Stärke Arbeitsplatte (für Geräte)')
    attribut(haupt, 'Materialstaerke_Kastenboden', p['Materialstaerke_Kastenboden'], access: 'TEXTBOX',
             formlabel: 'Stärke Kastenboden')
    attribut(haupt, 'Hoehenoffset_Schiene', p['Hoehenoffset_Schiene'], access: 'TEXTBOX',
             formlabel: 'Höhenoffset Schiene (Bohrung über Unterkante Kasten)')

    # --- Feste Maße (wie beim Unterschrank mit Tür über Attribute änderbar) ---
    %w[Materialstaerke_Korpus Materialstarke_Rueckwand BreiteStreben Spaltbreite
       Materialstaerke_Kastenrueckwand Hoehe_Kastenrueckwand Kasten_Abstand_unten Kasten_Abstand_oben
       Lochraster_Start Lochraster Kanal_Rand Kanal_Steg].each do |n|
      attribut(haupt, n, p[n], units: 'STRING')
    end
    # Nennlänge der LEGRABOX-Schiene: größte NL (35 … 65 cm, 5er-Schritte) mit NL + 3 mm <= Tiefe − Installationstiefe
    attribut(haupt, 'NL', nennlaenge(p['Tiefe'] - p['Installationstiefe']), units: 'STRING',
             formula: f_nennlaenge('Tiefe-Installationstiefe'))
    attribut(haupt, 'Auszug_Anteil', p['Auszug_Anteil'], laenge: false, units: 'STRING')

    # Kanalausschnitt im Boden (für den TCN-Export): ab linkem Rand und ab Hinterkante des Bodens
    a = r[:ausschnitt]
    attribut(haupt, 'Ausschnitt_Links', a[:links], units: 'STRING',
             formula: 'IF(Kanal_Lage<0.5,Kanal_Rand,IF(Kanal_Lage<1.5,(Breite-2*Materialstaerke_Korpus-Kanal_Breite)/2,' \
                      'Breite-2*Materialstaerke_Korpus-Kanal_Breite-Kanal_Rand))')
    attribut(haupt, 'Ausschnitt_Breite', a[:breite], units: 'STRING', formula: 'Kanal_Breite')
    attribut(haupt, 'Ausschnitt_Hinten', a[:hinten], units: 'STRING', formula: 'Kanal_Steg')
    attribut(haupt, 'Ausschnitt_Tiefe', a[:tiefe], units: 'STRING', formula: 'Installationstiefe-2*Kanal_Steg')

    # --- Abgeleitete Werte je Schublade ---
    r[:fronten].each_with_index do |fr, idx|
      i = idx + 1
      attribut(haupt, "H_Front_#{i}", fr[:h], units: 'STRING', formula: f_h_front(i))
      attribut(haupt, "Z_Front_#{i}", fr[:z], units: 'STRING', formula: f_z_front(i))
    end

    mk = p['Materialstaerke_Korpus']
    b, h, t = p['Breite'], p['Hoehe'], p['Tiefe']
    bs, rw, sp = p['BreiteStreben'], p['Materialstarke_Rueckwand'], p['Spaltbreite']
    hb = p['Hoehe_Blende']
    e = haupt.entities

    # --- Korpus (wie beim Unterschrank mit Tür, ohne Strebe hinten) ---
    seite = platte(model, 'Seite', 'Seite', [mk, t, h],
                   ["#{u}!Materialstaerke_Korpus", "#{u}!Tiefe", "#{u}!Hoehe"])
    einsetzen(e, seite, 'SeiteL', [0, mk, 0], [nil, nil, nil], mat: mat, kz: t_.('SeiteL'))
    einsetzen(e, seite, 'SeiteR', [b - mk, mk, 0],
              ["#{u}!Breite-#{u}!Materialstaerke_Korpus", nil, nil], mat: mat, kz: t_.('SeiteR'))

    boden = platte(model, 'Boden', 'Boden', [b - 2 * mk, t, mk],
                   ["#{u}!Breite-2*#{u}!Materialstaerke_Korpus", "#{u}!Tiefe", "#{u}!Materialstaerke_Korpus"])
    einsetzen(e, boden, 'Boden', [mk, mk, 0], ["#{u}!Materialstaerke_Korpus", nil, nil],
              mat: mat, kz: t_.('Boden'))

    # Strebe vorn: hochkant direkt hinter der Blende (Standard) oder flach wie beim Unterschrank
    flach = p['Strebe_Vorn'].round == 1
    sy, sz = flach ? [bs, mk] : [mk, bs]
    w_flach = "#{u}!Strebe_Vorn>0.5"
    strebe_v = platte(model, 'StrebeV', 'StrebeVorn', [b - 2 * mk, sy, sz],
                      ["#{u}!Breite-2*#{u}!Materialstaerke_Korpus",
                       "IF(#{w_flach},#{u}!BreiteStreben,#{u}!Materialstaerke_Korpus)",
                       "IF(#{w_flach},#{u}!Materialstaerke_Korpus,#{u}!BreiteStreben)"])
    einsetzen(e, strebe_v, 'StrebeVorn', [mk, mk, h - sz],
              ["#{u}!Materialstaerke_Korpus", nil,
               "#{u}!Hoehe-IF(#{w_flach},#{u}!Materialstaerke_Korpus,#{u}!BreiteStreben)"],
              mat: mat, kz: t_.('StrebeVorn'))

    rueck = platte(model, 'Rückwand', 'Rückwand', [b, rw, h],
                   ["#{u}!Breite", "#{u}!Materialstarke_Rueckwand", "#{u}!Hoehe"])
    einsetzen(e, rueck, 'Rückwand', [0, t + mk, 0],
              [nil, "#{u}!Tiefe+#{u}!Materialstaerke_Korpus", nil], mat: mat, kz: t_.('Rueckwand'))

    # --- Blende: feste Front oben vor dem Einbauraum des Geräts ---
    blende = platte(model, 'Blende', 'Blende', [b - sp, mk, hb],
                    ["#{u}!Breite-#{u}!Spaltbreite", "#{u}!Materialstaerke_Korpus", "#{u}!Hoehe_Blende"])
    einsetzen(e, blende, 'Blende', [sp / 2.0, -sp, h - hb],
              ["#{u}!Spaltbreite/2", "-#{u}!Spaltbreite", "#{u}!Hoehe-#{u}!Hoehe_Blende"],
              mat: mat, kz: t_.('Blende'))

    # --- Schubladen ---
    (1..MAX_SCHUBLADEN).each do |i|
      schublade(model, e, p, r[:fronten][i - 1], i, mat, kz)
    end

    haupt.set_attribute(OCL_DICT, 'kuerzel', kz)
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE }.each { |k, v| haupt.set_attribute(JT_DICT, k, v) }
    nische(haupt, p, r)
    haupt
  end

  # Nennlänge der LEGRABOX-Schiene (cm) zur lichten Tiefe (cm)
  def self.nennlaenge(tiefe)
    [65.0, ((tiefe - 0.3) / 5.0 + 0.000001).floor * 5.0].min
  end

  def self.f_nennlaenge(tiefe)
    "MIN(65,INT((#{tiefe}-0.3)/5+0.000001)*5)"
  end

  # Schublade mit Blum LEGRABOX free: Front, Boden (LW-35 x NL-10) und Holzrückwand
  # (LW-38 x 148, steht hinten auf dem Boden); die Zargen sind aus Metall.
  def self.schublade(model, ents, p, fr, i, mat, kz)
    u  = NAME
    s  = "Schublade#{i}"
    mk = p['Materialstaerke_Korpus']
    sp = p['Spaltbreite']
    b  = p['Breite']
    mb   = p['Materialstaerke_Kastenboden']
    mrw  = p['Materialstaerke_Kastenrueckwand']
    nl   = nennlaenge(p['Tiefe'] - p['Installationstiefe'])
    ao   = p['Kasten_Abstand_oben']
    hf   = fr[:h]
    lw   = b - 2 * mk                   # lichte Weite
    ab   = kasten_unten(p, fr[:z])      # Unterkante Kasten im Lochraster
    kh   = [hf - ab - ao, 2.0].max      # Höhe Kasten gesamt, mind. 2 cm
    hrw  = [p['Hoehe_Kastenrueckwand'], kh - mb].min
    st = ->(teil) { [model, kz, teil, "S#{i}"] }

    d = model.definitions.add(s)
    stempel(d)
    d.set_attribute(DICT, '_name', s)
    # Lokale Kopien der Werte vom Unterschrank (Formeln können nur Eltern/Geschwister ansprechen)
    attribut(d, 'Breite', b, units: 'STRING', formula: "#{u}!Breite")
    attribut(d, 'Hoehe_Front', hf, units: 'STRING', formula: "#{u}!H_Front_#{i}")
    attribut(d, 'Mk', mk, units: 'STRING', formula: "#{u}!Materialstaerke_Korpus")
    attribut(d, 'Spalt', sp, units: 'STRING', formula: "#{u}!Spaltbreite")
    attribut(d, 'Mb', mb, units: 'STRING', formula: "#{u}!Materialstaerke_Kastenboden")
    attribut(d, 'Mrw', mrw, units: 'STRING', formula: "#{u}!Materialstaerke_Kastenrueckwand")
    attribut(d, 'Hrw', p['Hoehe_Kastenrueckwand'], units: 'STRING', formula: "#{u}!Hoehe_Kastenrueckwand")
    attribut(d, 'NL', nl, units: 'STRING', formula: "#{u}!NL")
    attribut(d, 'Ab_unten', ab, units: 'STRING', formula: f_kasten_unten("#{u}!Z_Front_#{i}"))
    attribut(d, 'Ab_oben', ao, units: 'STRING', formula: "#{u}!Kasten_Abstand_oben")
    attribut(d, 'Auszug', nl * p['Auszug_Anteil'], units: 'STRING', formula: "#{u}!NL*#{u}!Auszug_Anteil")
    # Sichtbarkeit (wie Einlegeböden beim Unterschrank mit Tür)
    d.set_attribute(DICT, 'hidden', i <= p['Anz_Schubladen'].to_i ? 0.0 : 1.0)
    d.set_attribute(DICT, '_hidden_formula', "IF(#{u}!Anz_Schubladen>=#{i},0,1)")
    d.set_attribute(DICT, '_hidden_label', 'Hidden')
    d.set_attribute(DICT, '_hidden_formlabel', 'Hidden')
    d.set_attribute(DICT, '_hidden_units', 'BOOLEAN')
    # Mit "Interagieren" anklicken -> Schublade fährt heraus
    d.set_attribute(DICT, 'onclick', 'ANIMATE("Y",0,-Auszug)')
    d.set_attribute(DICT, '_onclick_label', 'onClick')

    de = d.entities
    # Front (wie Tür: Spalt/2 seitlich, -Spalt vor dem Korpus)
    front = platte(model, "Front S#{i}", 'Front', [b - sp, mk, hf],
                   ["#{s}!Breite-#{s}!Spalt", "#{s}!Mk", "#{s}!Hoehe_Front"])
    einsetzen(de, front, 'Front', [sp / 2.0, -sp, 0], ["#{s}!Spalt/2", "-#{s}!Spalt", nil],
              mat: mat, kz: st.('Front'))

    # Boden LW-35 x NL-10, mittig, vorne an der Korpusvorderkante
    kbod = platte(model, "Kasten Boden S#{i}", 'KastenBoden', [lw - 3.5, nl - 1.0, mb],
                  ["#{s}!Breite-2*#{s}!Mk-3.5", "#{s}!NL-1", "#{s}!Mb"])
    einsetzen(de, kbod, 'KastenBoden', [mk + 1.75, mk, ab],
              ["#{s}!Mk+1.75", "#{s}!Mk", "#{s}!Ab_unten"], mat: mat, kz: st.('KastenBoden'))

    # Holzrückwand LW-38 x 148 (höchstens bis Kasten_Abstand_oben unter die Frontoberkante), hinten auf dem Boden
    roh_kh = "#{s}!Hoehe_Front-#{s}!Ab_unten-#{s}!Ab_oben"
    f_kh   = "IF(#{roh_kh}>2,#{roh_kh},2)"
    krw = platte(model, "Kasten Rueckwand S#{i}", 'KastenRueckwand', [lw - 3.8, mrw, hrw],
                 ["#{s}!Breite-2*#{s}!Mk-3.8", "#{s}!Mrw", "MIN(#{s}!Hrw,#{f_kh}-#{s}!Mb)"])
    einsetzen(de, krw, 'KastenRueckwand', [mk + 1.9, mk + nl - 1.0 - mrw, ab + mb],
              ["#{s}!Mk+1.9", "#{s}!Mk+#{s}!NL-1-#{s}!Mrw", "#{s}!Ab_unten+#{s}!Mb"],
              mat: mat, kz: st.('KastenRueckwand'))

    inst = einsetzen(ents, d, s, [0, 0, fr[:z]], [nil, nil, "#{u}!Z_Front_#{i}"], layer: tag(model, "#{kz}_S#{i}_Schublade"))
    inst.hidden = i > p['Anz_Schubladen'].to_i
    inst
  end

  # ---------------------------------------------------------------------------
  # Eingabe
  # ---------------------------------------------------------------------------
  # "1;1;2", "1/1/2", "140 140 416" -> [1.0, 1.0, 2.0]
  def self.parse_aufteilung(text, anzahl)
    werte = text.to_s.split(%r{[;/\s]+}).reject(&:empty?).map { |w| w.tr(',', '.').to_f }
    werte = werte.first(anzahl)
    werte << 1.0 while werte.size < anzahl
    raise ArgumentError, 'Anteile müssen größer als 0 sein' if werte.any? { |w| w <= 0 }
    werte
  end

  def self.mm(text)
    text.to_s.tr(',', '.').to_f / 10.0
  end

  def self.dialog
    prompts = ['Breite (mm)', 'Höhe (mm)', 'Tiefe Korpus (mm)', 'Höhe Blende (mm)', 'Anzahl Schubladen',
               'Aufteilung von oben (Anteile oder mm, z. B. 1;1)', 'Installationstiefe hinten (mm)',
               'Lüftung', 'Lage Kanalausschnitt', 'Kürzel für Tags (eindeutig je Schrank)']
    defaults = ['800', '700', '800', '200', '2', '1;1', '150', LUEFTUNG.first, KANAL_LAGE[1],
                freies_kuerzel(Sketchup.active_model)]
    lists = ['', '', '', '', (1..MAX_SCHUBLADEN).to_a.join('|'), '', '', LUEFTUNG.join('|'), KANAL_LAGE.join('|'), '']
    res = UI.inputbox(prompts, defaults, lists, 'Unterschrank Kochfeld mit Abzug')
    return unless res

    anz = res[4].to_i
    eingabe = {
      'Breite' => mm(res[0]), 'Hoehe' => mm(res[1]), 'Tiefe' => mm(res[2]),
      'Hoehe_Blende' => mm(res[3]), 'Anz_Schubladen' => anz, 'Installationstiefe' => mm(res[6]),
      'Lueftung' => LUEFTUNG.index(res[7]).to_f, 'Kanal_Lage' => KANAL_LAGE.index(res[8]).to_f,
      'Kuerzel' => res[9].strip
    }
    raise ArgumentError, 'Kürzel darf nicht leer sein' if eingabe['Kuerzel'].empty?
    if Sketchup.active_model.layers.to_a.any? { |l| l.name.start_with?("#{eingabe['Kuerzel']}_") }
      raise ArgumentError, "Kürzel #{eingabe['Kuerzel']} ist schon vergeben"
    end
    if eingabe['Installationstiefe'] < 2 * DEFAULTS['Kanal_Steg'] + 1
      raise ArgumentError, 'Installationstiefe zu klein für den Kanalausschnitt'
    end
    parse_aufteilung(res[5], anz).each_with_index { |w, idx| eingabe["Anteil_#{idx + 1}"] = w }
    (anz + 1..MAX_SCHUBLADEN).each { |i| eingabe["Anteil_#{i}"] = 1.0 }
    erstellen(eingabe)
  rescue ArgumentError => e
    UI.messagebox("Ungültige Eingabe: #{e.message}")
  end

  def self.erstellen(eingabe)
    model = Sketchup.active_model
    model.start_operation('Unterschrank Kochfeld mit Abzug', true)
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
    model.selection.clear
    model.selection.add(inst)
    inst
  rescue StandardError => e
    model.abort_operation
    UI.messagebox("Fehler beim Erzeugen: #{e.message}")
    raise
  end

  unless file_loaded?(__FILE__)
    Kuechenplaner.untermenu('Unterschränke').add_item('Unterschrank Kochfeld mit Abzug…') { dialog }
    file_loaded(__FILE__)
  end
end
