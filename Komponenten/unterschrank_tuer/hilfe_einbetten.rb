# encoding: UTF-8
#
# Bettet die Kurzhilfe in den bestehenden "Unterschrank" (mit Tür) ein.
# Die Unterschrank.skp wurde von Hand gebaut und hat keinen Generator,
# deshalb einmalig so:
#   1. Unterschrank.skp in ein Modell einfügen und anklicken (auswählen).
#   2. Ruby-Konsole: load 'C:/Pfad/zu/hilfe_einbetten.rb'
#   3. Rechtsklick auf den Unterschrank → "Speichern unter…" → Unterschrank.skp ersetzen.
# Danach steht die Hilfe oben im Fenster "Komponentenoptionen".

require 'sketchup.rb'

module UnterschrankTuerHilfe

  DICT = 'dynamic_attributes'.freeze
  DOKU_URL = 'https://github.com/jimmycd/sketchup_kuechenplaner2/tree/main/Komponenten/unterschrank_tuer'.freeze
  HILFE_KURZ = 'Unterschrank mit Tür und 0–3 Einlegeböden, OpenCutList-fähig'.freeze
  HILFE = [
    'Breite, Höhe, Tiefe (Korpus ohne Front/Rückwand), Tür ja/nein und Anzahl Einlegeböden (0–3) hier ändern.',
    'Korpus 19 mm, Rückwand 8 mm, Streben 100 mm, Fugen 2 mm.',
    'Material „Melamin weiss“; OpenCutList erstellt daraus die Zuschnittliste.',
    'Feste Maße (Materialstärken, Streben, Spalt): Fenster „Komponentenattribute“.',
    "Doku: #{DOKU_URL}"
  ].join(' ').freeze

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

  def self.einbetten(model = Sketchup.active_model)
    ziele = model.selection.grep(Sketchup::ComponentInstance)
    if ziele.empty?
      UI.messagebox('Bitte zuerst den Unterschrank auswählen.')
      return []
    end
    model.start_operation('Kurzhilfe einbetten', true)
    ziele.map(&:definition).uniq.each { |d| hilfe(d) }
    model.commit_operation
    UI.messagebox('Kurzhilfe eingebettet. Jetzt Rechtsklick → "Speichern unter…" und Unterschrank.skp ersetzen.')
    ziele
  end
end

UnterschrankTuerHilfe.einbetten unless defined?($HILFE_TEST)
