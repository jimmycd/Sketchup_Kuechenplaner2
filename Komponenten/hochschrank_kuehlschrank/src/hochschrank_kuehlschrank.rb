# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module HochschrankKuehlschrank
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Küchenplaner – Hochschrank Kühlschrank', 'hochschrank_kuehlschrank/main')
    ext.description = 'Hochschrank für Einbau-Kühl- und Gefriergeräte. Menü: Erweiterungen > Küchenplaner > Hochschränke > Hochschrank Kühlschrank'
    ext.version     = '1.0.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
