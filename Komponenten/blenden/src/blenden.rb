# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module Blenden
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Küchenplaner – Blenden und Wangen', 'blenden/main')
    ext.description = 'Passblenden, Wangen und Sockelblenden für die Schrankzeilen. Menü: Erweiterungen > Küchenplaner > Blenden & Wangen'
    ext.version     = '1.0.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
