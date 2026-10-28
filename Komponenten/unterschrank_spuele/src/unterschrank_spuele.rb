# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module Spuelenschrank
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Küchenplaner – Spülenschrank', 'unterschrank_spuele/main')
    ext.description = 'Unterschrank für die Spüle mit Installationsebene. Menü: Erweiterungen > Küchenplaner > Unterschränke > Spülenschrank'
    ext.version     = '1.0.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
