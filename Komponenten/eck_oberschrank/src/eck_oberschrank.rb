# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module EckOberschrank
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Küchenplaner – Eck-Oberschrank', 'eck_oberschrank/main')
    ext.description = 'Eck-Oberschrank L-Form mit Falttür. Menü: Erweiterungen > Küchenplaner > Oberschränke > Eck-Oberschrank L-Form'
    ext.version     = '1.0.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
