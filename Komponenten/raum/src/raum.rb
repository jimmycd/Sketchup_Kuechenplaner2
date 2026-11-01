# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module Raum
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Küchenplaner – Raum', 'raum/main')
    ext.description = 'Raum gestalten: Wände, Fenster, Türen und Durchgänge als Planungshilfe; Schränke docken an die Wände an. Menü: Erweiterungen > Küchenplaner > Raum'
    ext.version     = '1.0.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
