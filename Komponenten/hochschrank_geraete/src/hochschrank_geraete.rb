# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module HochschrankGeraete
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Küchenplaner – Hochschrank Geräte', 'hochschrank_geraete/main')
    ext.description = 'Hochschrank für zwei Einbaugeräte übereinander. Menü: Erweiterungen > Küchenplaner > Hochschränke > Hochschrank Geräte'
    ext.version     = '1.0.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
