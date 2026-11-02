# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module UnterschrankKuehlschrank
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Küchenplaner – Unterschrank Kühlschrank', 'unterschrank_kuehlschrank/main')
    ext.description = 'Nische für Unterbau-Kühlschrank oder Weinkühler (mit Möbelfront oder eigener Tür). Menü: Erweiterungen > Küchenplaner > Unterschränke > Unterschrank Kühlschrank'
    ext.version     = '1.0.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
