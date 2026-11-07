# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module Wandregal
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Küchenplaner – Wandregal', 'wandregal/main')
    ext.description = 'Frei hängendes, offenes Wandregal mit Spalten, Mittelwänden und festen Fachböden. Menü: Erweiterungen > Küchenplaner > Oberschränke > Wandregal'
    ext.version     = '1.0.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
