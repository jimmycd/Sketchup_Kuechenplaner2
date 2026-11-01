# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module Geraete
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Küchenplaner – Geräte', 'geraete/main')
    ext.description = 'Geräte (Spüler, Kochfeld, Spüle, Backofen …) für Planung und Rendering in die Nischen der Schränke setzen. Menü: Erweiterungen > Küchenplaner > Geräte'
    ext.version     = '1.0.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
