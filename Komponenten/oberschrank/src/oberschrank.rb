# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module Oberschrank
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Küchenplaner – Oberschrank', 'oberschrank/main')
    ext.description = 'Oberschrank offen oder mit einer oder zwei Türen, 0–3 Einlegeböden. Menü: Erweiterungen > Küchenplaner > Oberschrank'
    ext.version     = '1.0.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
