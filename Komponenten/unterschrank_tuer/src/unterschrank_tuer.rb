# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module UnterschrankTuer
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Küchenplaner – Unterschrank mit Tür', 'unterschrank_tuer/main')
    ext.description = 'Fügt den Unterschrank mit Tür und 0–3 Einlegeböden als Dynamic Component ein. Menü: Erweiterungen > Küchenplaner > Unterschränke > Unterschrank mit Tür'
    ext.version     = '1.0.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
