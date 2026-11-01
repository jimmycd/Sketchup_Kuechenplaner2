# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module UnterschrankHandtuch
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Küchenplaner – Unterschrank Handtuchauszug', 'unterschrank_handtuch/main')
    ext.description = 'Schmaler Unterschrank mit Hochauszug (Häfele HU Slim Base). Menü: Erweiterungen > Küchenplaner > Unterschränke > Unterschrank Handtuchauszug'
    ext.version     = '1.0.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
