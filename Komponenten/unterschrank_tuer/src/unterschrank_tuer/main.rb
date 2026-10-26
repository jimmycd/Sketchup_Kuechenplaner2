# encoding: UTF-8
#
# Unterschrank mit Tür: fügt die von Hand gebaute Unterschrank.skp (liegt in der
# Erweiterung) über Erweiterungen > Küchenplaner > Unterschrank mit Tür ins Modell
# ein und richtet sie ein: Kurzhilfe, ein eigener Tag je Teil (<Kürzel>_<Teil>,
# z. B. UST1_SeiteL, UST1_Einlegeboden2, UST1_Tuer), das Wörterbuch "JT_Schrank"
# für den TCN-Export und die Formeln der Einlegeböden. Jeder eingefügte Schrank
# bekommt ein eigenes Kürzel (UST1, UST2 …).

require 'sketchup.rb'

module UnterschrankTuer

  DICT = 'dynamic_attributes'.freeze
  KUERZEL = 'UST'.freeze
  DOKU_URL = 'https://github.com/jimmycd/sketchup_kuechenplaner2/tree/main/Komponenten/unterschrank_tuer'.freeze
  HILFE_KURZ = 'Unterschrank mit Tür und 0–3 Einlegeböden, OpenCutList-fähig'.freeze
  HILFE = [
    'Breite, Höhe, Tiefe (Korpus ohne Front/Rückwand), Tür ja/nein und Anzahl Einlegeböden (0–3) hier ändern.',
    'Korpus 19 mm, Rückwand 8 mm, Streben 100 mm, Fugen 2 mm.',
    'Material „Melamin weiss“; OpenCutList erstellt daraus die Zuschnittliste.',
    'Jedes Teil hat einen eigenen Tag <Kürzel>_<Teil>, z. B. UST1_SeiteL, UST1_Tuer.',
    'Feste Maße (Materialstärken, Streben, Spalt): Fenster „Komponentenattribute“.',
    "Doku: #{DOKU_URL}"
  ].join(' ').freeze

  # Tag-Schema für den TCN-Export (gleich in allen Komponenten, der Test prüft das):
  # Tag <Kürzel>_<Bereich>_<Teil>, dazu am Teil das Wörterbuch JT_Schrank.
  JT_DICT   = 'JT_Schrank'.freeze
  TYP       = 'Unterschrank_Tuer'.freeze
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

  # Namen der Teile in Unterschrank.skp (Instanz- oder Definitionsname) -> Teil
  TEILE = {
    'SeiteL' => 'SeiteL', 'SeiteR' => 'SeiteR', 'Boden' => 'Boden',
    'StrebeVorn' => 'StrebeVorn', 'StrebeV' => 'StrebeVorn',
    'StrebeHinten' => 'StrebeHinten', 'StrebeH' => 'StrebeHinten',
    'Rückwand' => 'Rueckwand', 'Rueckwand' => 'Rueckwand',
    'Front' => 'Tuer', 'Tür' => 'Tuer', 'Tuer' => 'Tuer',
    'Einlegeboden1' => 'Einlegeboden1', 'Einlegeboden2' => 'Einlegeboden2', 'Einlegeboden3' => 'Einlegeboden3',
    'Boden#1' => 'Einlegeboden1', 'Boden#2' => 'Einlegeboden2', 'Boden#3' => 'Einlegeboden3'
  }.freeze

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

  # Freies Kürzel für die Tags, z. B. UST1, UST2 …
  def self.freies_kuerzel(model)
    n = 1
    n += 1 while model.layers.to_a.any? { |l| l.name.start_with?("#{KUERZEL}#{n}_") }
    "#{KUERZEL}#{n}"
  end

  # Tag <Kürzel>_<Bereich>_<Teil> und JT_Schrank am Teil
  def self.kennzeichnen(model, inst, kz, teil, bereich = nil)
    name = [kz, bereich, teil].compact.join('_')
    inst.layer = model.layers[name] || model.layers.add(name)
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE, 'bereich' => bereich.to_s,
      'teil' => teil, 'rolle' => ROLLEN.fetch(teil.sub(/\d+\z/, '')) }.each { |k, v| inst.set_attribute(JT_DICT, k, v) }
    inst
  end

  # Teil zuerst am Instanznamen erkennen, dann Einlegeböden an ihrer Sichtbarkeitsformel,
  # zuletzt am Definitionsnamen (SketchUp hängt bei Kopien "#2" usw. an)
  def self.teil_von(inst)
    d = inst.definition
    [inst.get_attribute(DICT, '_name'), inst.name].each { |n| return TEILE[n] if TEILE[n] }
    f = d.get_attribute(DICT, '_hidden_formula') || inst.get_attribute(DICT, '_hidden_formula')
    # alte Form "Anz_Einlegeboeden>0" = Boden 1, neue Form "Anz_Einlegeboeden>=1" = Boden 1
    return "Einlegeboden#{$2.to_i + ($1 == '>=' ? 0 : 1)}" if f.to_s =~ /Anz_Einlegeboeden\s*(>=?)\s*(\d)/
    [d.get_attribute(DICT, '_name'), d.name, d.name.sub(/#\d+\z/, '')].each { |n| return TEILE[n] if TEILE[n] }
    nil
  end

  # Einlegeböden: Formeln für Sichtbarkeit und Höhe. In der von Hand gebauten
  # Unterschrank.skp hatten die Böden nur eine Sichtbarkeitsformel in der Form
  # " IF (…)" (mit Leerzeichen, wird nicht zuverlässig ausgewertet) und gar keine
  # Formel für die Höhe – sie standen fest bei 14/26/40,5 cm. Jetzt teilen die
  # sichtbaren Böden den Innenraum zwischen Boden und Streben in gleich hohe Fächer;
  # ausgeblendete Böden liegen auf dem Boden.
  def self.einlegeboden_formeln(u, k)
    n = "#{u}!Anz_Einlegeboeden"
    mk = "#{u}!Materialstaerke_Korpus"
    {
      hidden: "IF(#{n}>=#{k},0,1)",
      z: "IF(#{n}>=#{k},#{mk}+#{k}*(#{u}!Hoehe-(#{n}+2)*#{mk})/(#{n}+1)+#{k - 1}*#{mk},#{mk})"
    }
  end

  def self.einlegeboden_reparieren(d, inst, k)
    u = d.get_attribute(DICT, '_name') || 'Unterschrank'
    f = einlegeboden_formeln(u, k)
    # Sichtbarkeit an der Definition (dort stand die alte Formel) und an der Instanz
    [inst.definition, inst].each do |e|
      e.set_attribute(DICT, '_hidden_formula', f[:hidden])
      e.set_attribute(DICT, '_hidden_label', 'Hidden')
      e.set_attribute(DICT, '_hidden_formlabel', 'Hidden')
      e.set_attribute(DICT, '_hidden_units', 'BOOLEAN')
      e.set_attribute(DICT, '_hidden_error', '')
    end
    inst.set_attribute(DICT, '_name', "Einlegeboden#{k}")
    inst.set_attribute(DICT, '_z_formula', f[:z])
    inst.set_attribute(DICT, '_z_label', 'Z')
    inst.hidden = d.get_attribute(DICT, 'anz_einlegeboeden').to_i < k
  end

  # Tags und JT_Schrank an allen Teilen; gibt die nicht erkannten Teilnamen zurück
  def self.tags_setzen(model, d)
    kz = d.get_attribute(JT_DICT, 'schrank') || freies_kuerzel(model)
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE }.each { |k, v| d.set_attribute(JT_DICT, k, v) }
    unbekannt = []
    d.entities.grep(Sketchup::ComponentInstance).each do |inst|
      teil = teil_von(inst)
      einlegeboden_reparieren(d, inst, $1.to_i) if teil.to_s =~ /\AEinlegeboden(\d)\z/
      teil ? kennzeichnen(model, inst, kz, teil) : unbekannt << (inst.name.to_s.empty? ? inst.definition.name : inst.name)
    end
    unbekannt
  end

  def self.einrichten(model = Sketchup.active_model)
    ziele = model.selection.grep(Sketchup::ComponentInstance)
    if ziele.empty?
      UI.messagebox('Bitte zuerst den Unterschrank auswählen.')
      return []
    end
    model.start_operation('Unterschrank einrichten', true)
    unbekannt = ziele.map(&:definition).uniq.flat_map do |d|
      hilfe(d)
      tags_setzen(model, d)
    end
    model.commit_operation
    # Dynamic Components neu berechnen, damit die Einlegeböden sofort richtig stehen
    ziele.each { |i| $dc_observers.get_latest_class.redraw_with_undo(i) } if defined?($dc_observers) && $dc_observers
    hinweis = unbekannt.empty? ? '' : "\nOhne Tag (nicht erkannt): #{unbekannt.uniq.join(', ')}"
    UI.messagebox('Kurzhilfe und Tags gesetzt.' + hinweis)
    ziele
  end

  SKP = File.join(File.dirname(__FILE__), 'Unterschrank.skp').freeze

  # Unterschrank.skp einfügen und einrichten. Ab dem zweiten Exemplar im Modell
  # bekommt der Schrank eine eigene Definition, damit seine Teile eigene Tags haben.
  def self.einfuegen(model = Sketchup.active_model, pfad = SKP)
    model.start_operation('Unterschrank mit Tür', true)
    d = model.definitions.load(pfad)
    x = model.entities.length > 0 ? model.bounds.max.x + 10.cm : 0
    inst = model.entities.add_instance(d, Geom::Transformation.translation([x, 0, 0]))
    inst.make_unique if d.instances.length > 1
    d = inst.definition
    d.delete_attribute(JT_DICT, 'schrank') # neues Kürzel
    hilfe(d)
    unbekannt = tags_setzen(model, d)
    model.commit_operation
    $dc_observers.get_latest_class.redraw_with_undo(inst) if defined?($dc_observers) && $dc_observers
    model.selection.clear
    model.selection.add(inst)
    puts "Unterschrank mit Tür: ohne Tag (nicht erkannt): #{unbekannt.uniq.join(', ')}" unless unbekannt.empty?
    inst
  rescue StandardError => e
    model.abort_operation
    UI.messagebox("Fehler beim Einfügen: #{e.message}")
    raise
  end
end

# Gemeinsames Untermenü "Erweiterungen > Küchenplaner" für alle Komponenten und
# den TCN-Export. Steht wortgleich in jeder Erweiterung (der Test prüft das), damit
# das Untermenü nur einmal angelegt wird, egal welche Erweiterungen geladen sind.
module Kuechenplaner
  def self.menu
    @menu ||= UI.menu('Extensions').add_submenu('Küchenplaner')
  end
end unless defined?(Kuechenplaner.menu)

unless file_loaded?(__FILE__)
  Kuechenplaner.menu.add_item('Unterschrank mit Tür…') { UnterschrankTuer.einfuegen }
  file_loaded(__FILE__)
end
