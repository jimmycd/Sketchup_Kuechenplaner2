# encoding: UTF-8
#
# Arbeitsplatte – Platten in SketchUp zeichnen
#
# Aufbau wie bei den Schränken: eine Komponente "Arbeitsplatte APL<n>" (Kürzel APL,
# JT_Schrank schrank/typ/kategorie an der Definition), darin je Platte eine eigene
# Komponente mit Tag APL<n>_Platte<k> und JT_Schrank (teil Platte<k>, rolle
# Arbeitsplatte). Die Platte wird im Endmaß gezeichnet: Unterseite, Oberseite und
# je Umrisskante eine Seitenfläche.
#
# OpenCutList: Schichtstoff ist Plattenwerkstoff (Typ 2), Massivholz Massivholz
# (Typ 1). Bei Schichtstoff bekommt die Vorderkante das Kantenmaterial "Anleimer
# Arbeitsplatte ab Werk" (Typ 4, wird nicht abgezogen, die Platte kommt bekantet),
# freie Enden "Anleimer Arbeitsplatte" (Typ 4, 2 mm, wird in OCL abgezogen).
# Wand-, Stoß- und Hochschrankkanten bleiben ohne. Massivholz hat keine Anleimer.
#
# Für "neu berechnen" und den TCN-Export stehen im Wörterbuch JT_Arbeitsplatte
# an der Definition die Einstellungen, die Schrank-Kürzel und die Stöße (JSON),
# an jeder Platte Umriss und Kantenarten.

require 'json'

module Arbeitsplatte
  module Ausgabe
    MM        = 25.4
    KUERZEL   = 'APL'.freeze
    TYP       = 'Arbeitsplatte'.freeze
    KATEGORIE = 'Arbeitsplatte'.freeze
    JT_DICT   = 'JT_Schrank'.freeze
    AP_DICT   = 'JT_Arbeitsplatte'.freeze
    OCL_DICT  = 'ladb_opencutlist'.freeze

    MATERIALIEN = {
      schichtstoff: ['Arbeitsplatte Schichtstoff', [214, 205, 190],
                     { 'type' => 2, 'std_thicknesses' => '38mm',
                       'std_sizes' => '4100mm x 600mm;4100mm x 650mm;4100mm x 900mm;4100mm x 1200mm', 'grained' => false }],
      massivholz: ['Arbeitsplatte Massivholz', [196, 154, 108],
                   { 'type' => 1, 'std_thicknesses' => '40mm', 'grained' => true }]
    }.freeze
    KANTE_WERK = ['Anleimer Arbeitsplatte ab Werk', [200, 190, 175],
                  { 'type' => 4, 'thickness' => '2mm', 'edge_decremented' => false }].freeze
    KANTE      = ['Anleimer Arbeitsplatte', [200, 190, 175],
                  { 'type' => 4, 'thickness' => '2mm', 'std_widths' => '45mm', 'edge_decremented' => true }].freeze

    def self.inch(mm)
      mm.to_f / MM
    end

    # wie ocl_material in den Schrank-Komponenten: von OCL eingestellte Materialien bleiben
    def self.ocl_material(model, name, farbe, attribute)
      m = model.materials[name] || model.materials.add(name)
      m.color = Sketchup::Color.new(*farbe) unless m.texture || m.get_attribute(OCL_DICT, 'type')
      if m.get_attribute(OCL_DICT, 'type').to_i == 0
        attribute.each { |k, v| m.set_attribute(OCL_DICT, k, v) }
      end
      m
    end

    def self.freies_kuerzel(model)
      n = 1
      n += 1 while model.layers.to_a.any? { |l| l.name.start_with?("#{KUERZEL}#{n}_") }
      "#{KUERZEL}#{n}"
    end

    # Kantenmaterial je Kantenart (nil = ohne)
    def self.kanten_materialien(model, art)
      return {} if art.to_sym == :massivholz
      { vorne: ocl_material(model, *KANTE_WERK), frei: ocl_material(model, *KANTE) }
    end

    # Werte für JSON: Symbole als Text, Ecken-Schlüssel als Text
    def self.json(v)
      JSON.generate(v)
    end

    def self.optionen_speichern(o)
      o.reject { |k, _| k == :formate }.merge(ecken: o[:ecken].map { |k, v| [k.to_s, v] }.to_h)
    end

    # gespeicherte Einstellungen zurück in Layout-Optionen
    def self.optionen_lesen(text)
      h = JSON.parse(text)
      o = h.map { |k, v| [k.to_sym, v] }.to_h
      o[:art] = o[:art].to_sym if o[:art]
      o[:stoss] = o[:stoss].to_sym if o[:stoss]
      o[:ecken] = (o[:ecken] || {}).map do |k, v|
        e = v.map { |kk, vv| [kk.to_sym, vv] }.to_h
        e[:stoss] = e[:stoss].to_sym if e[:stoss]
        [k.to_i, e]
      end.to_h
      o
    end

    # Eine Platte als Komponente: Umriss in Weltkoordinaten (mm), lokal ab der
    # linken unteren Ecke des Umrisses
    def self.platte(model, ents, kz, p, mat, kanten_mat)
      teil = "Platte#{p[:nr]}"
      name = "#{kz}_#{teil}"
      x0 = p[:punkte].map(&:first).min
      y0 = p[:punkte].map(&:last).min
      lokal = p[:punkte].map { |x, y| [inch(x - x0), inch(y - y0)] }
      h = inch(p[:staerke])
      d = model.definitions.add(name)
      e = d.entities
      unten = e.add_face(*lokal.map { |x, y| [x, y, 0.0] })
      unten.reverse! if unten.normal.z > 0
      oben = e.add_face(*lokal.map { |x, y| [x, y, h] })
      oben.reverse! if oben.normal.z < 0
      lokal.each_with_index do |(xa, ya), i|
        xb, yb = lokal[(i + 1) % lokal.size]
        f = e.add_face([xa, ya, 0.0], [xb, yb, 0.0], [xb, yb, h], [xa, ya, h])
        km = kanten_mat[p[:kanten][i]]
        f.material = km if km
      end
      inst = ents.add_instance(d, Geom::Transformation.translation(Geom::Vector3d.new(inch(x0), inch(y0), inch(p[:z]))))
      inst.name = name
      inst.material = mat
      inst.layer = model.layers[name] || model.layers.add(name)
      { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE, 'bereich' => '',
        'teil' => teil, 'rolle' => ROLLEN.fetch('Platte') }.each { |k, v| inst.set_attribute(JT_DICT, k, v) }
      { 'nr' => p[:nr], 'zeile' => p[:zeile], 'punkte' => json(p[:punkte]), 'kanten' => json(p[:kanten]),
        'format' => json(p[:format]), 'laenge' => p[:laenge], 'breite' => p[:breite] }
        .each { |k, v| inst.set_attribute(AP_DICT, k, v) }
      inst
    end

    # Ganze Arbeitsplatte bauen; liefert die Instanz "APL<n>"
    def self.bauen(model, erg, lay, kz: nil)
      o = lay[:optionen]
      kz ||= freies_kuerzel(model)
      mat = ocl_material(model, *MATERIALIEN.fetch(o[:art].to_sym))
      kanten_mat = kanten_materialien(model, o[:art])
      haupt = model.definitions.add("Arbeitsplatte #{kz}")
      haupt.description = "Arbeitsplatte #{kz}: #{lay[:platten].size} Platten. Doku: #{DOKU_URL}"
      { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE }.each { |k, v| haupt.set_attribute(JT_DICT, k, v) }
      schraenke = erg[:zeilen].flat_map { |z| z[:elemente].map { |e| e[:kz] } }.uniq
      { 'optionen' => json(optionen_speichern(o)), 'schraenke' => json(schraenke), 'stoesse' => json(lay[:stoesse]),
        'version' => 1 }.each { |k, v| haupt.set_attribute(AP_DICT, k, v) }
      lay[:platten].each { |p| platte(model, haupt.entities, kz, p, mat, kanten_mat) }
      inst = model.entities.add_instance(haupt, Geom::Transformation.translation(Geom::Vector3d.new(0, 0, 0)))
      inst.name = kz
      inst
    end

    def self.arbeitsplatten(model)
      quelle = model.selection.to_a.empty? ? model.entities.to_a : model.selection.to_a
      quelle.grep(Sketchup::ComponentInstance).select { |i| i.definition.get_attribute(JT_DICT, 'typ') == TYP }
    end
  end
end
