# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module RegalAbschluss
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Küchenplaner – Abschlussregal', 'regal_abschluss/main')
    ext.description = 'Offenes Abschlussregal fürs Zeilenende (gerade, schräg oder rund) als Unter-, Ober- oder Hochschrank. Menü: Erweiterungen > Küchenplaner > Unterschränke/Oberschränke/Hochschränke > Abschlussregal'
    ext.version     = '1.0.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
