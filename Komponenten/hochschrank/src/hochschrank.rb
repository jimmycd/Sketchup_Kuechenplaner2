# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module Hochschrank
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Küchenplaner – Hochschrank', 'hochschrank/main')
    ext.description = 'Hochschrank mit Schubladen unten, offenem Fach oder Schubladen in der Mitte und Tür/Einlegeböden oben. Menü: Erweiterungen > Küchenplaner > Hochschränke > Hochschrank'
    ext.version     = '1.0.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
