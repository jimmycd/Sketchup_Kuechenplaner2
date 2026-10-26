# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module Apothekerschrank
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Küchenplaner – Apothekerschrank', 'apothekerschrank/main')
    ext.description = 'Hochschrank mit Vollauszug (2–6 Innenkästen, eine oder zwei Fronten). Menü: Erweiterungen > Küchenplaner > Apothekerschrank'
    ext.version     = '1.0.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
