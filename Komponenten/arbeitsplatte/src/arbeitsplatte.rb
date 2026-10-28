# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module Arbeitsplatte
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Küchenplaner – Arbeitsplatte', 'arbeitsplatte/main')
    ext.description = 'Arbeitsplatte über den geplanten Unterschränken: legt die Platten mit Eckverbindung (Gehrungsansatz, stumpf, Gehrung) an, OpenCutList-fähig. Menü: Erweiterungen > Küchenplaner > Arbeitsplatte erzeugen'
    ext.version     = '0.4.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
