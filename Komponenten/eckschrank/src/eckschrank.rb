# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module Eckschrank
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Küchenplaner – Eckschrank', 'eckschrank/main')
    ext.description = 'Eck-Unterschrank: Blindeck (eine Tür, zwei Türen, Le Mans) oder L-Form mit Falttür. Menü: Erweiterungen > Küchenplaner > Eckschrank'
    ext.version     = '1.0.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
