# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module HochschrankVorrat
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Küchenplaner – Hochschrank Vorrat', 'hochschrank_vorrat/main')
    ext.description = 'Vorrats-Hochschrank: Tür außen (ganz oder geteilt, ein oder zwei Flügel), dahinter LEGRABOX-Innenschubkästen und Einlegeböden. Menü: Erweiterungen > Küchenplaner > Hochschränke > Hochschrank Vorrat'
    ext.version     = '1.0.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
