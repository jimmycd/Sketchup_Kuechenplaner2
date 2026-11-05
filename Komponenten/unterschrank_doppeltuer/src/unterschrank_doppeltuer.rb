# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module UnterschrankDoppeltuer
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Küchenplaner – Unterschrank mit Doppeltür', 'unterschrank_doppeltuer/main')
    ext.description = 'Unterschrank mit zwei Türen und 0–3 Einlegeböden. Menü: Erweiterungen > Küchenplaner > Unterschränke > Unterschrank mit Doppeltür'
    ext.version     = '1.0.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
