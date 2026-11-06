# encoding: UTF-8
# Küchenplaner – Symbolleiste: die wichtigsten Befehle des Küchenplaners als Icons.
require 'sketchup.rb'
require 'extensions.rb'

module KuechenplanerSymbolleiste
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Küchenplaner – Symbolleiste', 'kuechenplaner_symbolleiste/main')
    ext.description = 'Symbolleiste „Küchenplaner“: Schrank einfügen (Auswahl aller Schranktypen), Schrank andocken, ' \
                      'Arbeitsplatte, Raum, Frontfarbe und Griffe, Export (Stückliste, Etiketten, Zuschnitt, TCN). Ein-/Ausblenden über Ansicht > Symbolleisten.'
    ext.version     = '1.0.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
