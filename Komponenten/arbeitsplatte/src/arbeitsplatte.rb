# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module Arbeitsplatte
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Küchenplaner – Arbeitsplatte', 'arbeitsplatte/main')
    ext.description = 'Arbeitsplatte über den geplanten Unterschränken: erkennt Zeilen sowie L- und U-Ecken. Menü: Erweiterungen > Küchenplaner > Arbeitsplatte erzeugen'
    ext.version     = '0.2.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
