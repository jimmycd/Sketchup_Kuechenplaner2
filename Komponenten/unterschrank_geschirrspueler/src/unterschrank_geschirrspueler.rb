# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module UnterschrankGeschirrspueler
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Küchenplaner – Unterschrank Geschirrspüler', 'unterschrank_geschirrspueler/main')
    ext.description = 'Nische mit Möbelfront für einen vollintegrierten Geschirrspüler. Menü: Erweiterungen > Küchenplaner > Unterschrank Geschirrspüler'
    ext.version     = '1.0.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
