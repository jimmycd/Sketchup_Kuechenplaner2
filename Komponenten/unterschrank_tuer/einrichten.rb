# encoding: UTF-8
#
# Richtet den bestehenden "Unterschrank" (mit Tür) ein: Kurzhilfe, ein eigener
# Tag je Teil (<Kürzel>_<Teil>, z. B. UST1_SeiteL, UST1_Einlegeboden2, UST1_Tuer)
# und das Wörterbuch "JT_Schrank" für den TCN-Export.
# Die Unterschrank.skp wurde von Hand gebaut und hat keinen Generator,
# deshalb einmalig so:
#   1. Unterschrank.skp in ein Modell einfügen und anklicken (auswählen).
#   2. Ruby-Konsole: load 'C:/Pfad/zu/einrichten.rb'
#   3. Rechtsklick auf den Unterschrank → "Speichern unter…" → Unterschrank.skp ersetzen.
# Danach steht die Hilfe oben im Fenster "Komponentenoptionen". Ein zweiter Lauf
# behält das Kürzel bei.

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
    'ZwischenbodenUnten' => 'Zwischenboden', 'ZwischenbodenOben' => 'Zwischenboden',
    'Rueckwand' => 'Rueckwand', 'Einlegeboden' => 'Einlegeboden', 'Front' => 'Front',
    'Tuer' => 'Tuer', 'TuerL' => 'Tuer', 'TuerR' => 'Tuer',
    'KastenBoden' => 'KastenBoden', 'KastenRueckwand' => 'KastenRueckwand',
    'Blende' => 'Front'
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
    return "Einlegeboden#{$1.to_i + 1}" if f.to_s =~ /Anz_Einlegeboeden\s*>\s*(\d)/
    [d.get_attribute(DICT, '_name'), d.name, d.name.sub(/#\d+\z/, '')].each { |n| return TEILE[n] if TEILE[n] }
    nil
  end

  # Tags und JT_Schrank an allen Teilen; gibt die nicht erkannten Teilnamen zurück
  def self.tags_setzen(model, d)
    kz = d.get_attribute(JT_DICT, 'schrank') || freies_kuerzel(model)
    { 'schrank' => kz, 'typ' => TYP, 'kategorie' => KATEGORIE }.each { |k, v| d.set_attribute(JT_DICT, k, v) }
    unbekannt = []
    d.entities.grep(Sketchup::ComponentInstance).each do |inst|
      teil = teil_von(inst)
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
    hinweis = unbekannt.empty? ? '' : "\nOhne Tag (nicht erkannt): #{unbekannt.uniq.join(', ')}"
    UI.messagebox('Kurzhilfe und Tags gesetzt. Jetzt Rechtsklick → "Speichern unter…" und Unterschrank.skp ersetzen.' +
                  hinweis)
    ziele
  end
end

UnterschrankTuer.einrichten unless defined?($EINRICHTEN_TEST)
