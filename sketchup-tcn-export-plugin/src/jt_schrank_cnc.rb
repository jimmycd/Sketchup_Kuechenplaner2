# encoding: UTF-8
# Schrank-CNC – Werkzeuge für die Schränke aus Komponenten/ (Küchenplaner 2):
# TCN-Export für TpaCAD, Frontfarbe und Griffe ändern.

require 'sketchup.rb'
require 'extensions.rb'

module JTools
  module SchrankCnc
    EXT_VERSION = '0.2.0'.freeze unless defined?(EXT_VERSION)

    unless defined?(@extension) && @extension
      ext = SketchupExtension.new('Küchenplaner – Schrank-CNC (TCN-Export)', File.join(File.dirname(File.expand_path(__FILE__)), 'jt_schrank_cnc', 'main'))
      ext.description = 'Schränke aus dem Küchenplaner: TCN-Export für TpaCAD sowie Frontfarbe und Griffe für alle, ' \
                        'Ober-, Unter- oder Hochschränke ändern (Materialien aus OpenCutList). ' \
                        'Menü: Erweiterungen > Küchenplaner'
      ext.version = EXT_VERSION
      ext.creator = 'JTools'
      ext.copyright = '2026'
      @extension = ext
      Sketchup.register_extension(ext, true)
    end
  end
end
