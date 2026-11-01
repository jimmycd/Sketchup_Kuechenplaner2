# encoding: UTF-8
# Schrank-CNC – Werkzeuge für die Schränke aus Komponenten/ (Küchenplaner 2):
# TCN-Export für TpaCAD, Stückliste, Etiketten, Zuschnittplan, Frontfarbe und Griffe ändern.
# Lizenz GPL-3.0 (enthält BinPacking2D aus OpenCutList, siehe THIRD_PARTY.md).

require 'sketchup.rb'
require 'extensions.rb'

module JTools
  module SchrankCnc
    EXT_VERSION = '0.5.0'.freeze unless defined?(EXT_VERSION)

    unless defined?(@extension) && @extension
      ext = SketchupExtension.new('Küchenplaner – Schrank-CNC (TCN-Export)', File.join(File.dirname(File.expand_path(__FILE__)), 'jt_schrank_cnc', 'main'))
      ext.description = 'Schränke aus dem Küchenplaner: TCN-Export für TpaCAD, Stückliste, Etiketten, Zuschnittplan für die Formatsäge, ' \
                        'Andocken neuer Schränke sowie Frontfarbe und Griffe für alle, Ober-, Unter- oder Hochschränke ändern. ' \
                        'Menü: Erweiterungen > Küchenplaner. Lizenz GPL-3.0, Zuschnitt-Optimierer aus OpenCutList (L\'Air du Bois).'
      ext.version = EXT_VERSION
      ext.creator = 'JTools'
      ext.copyright = '2026, GPL-3.0'
      @extension = ext
      Sketchup.register_extension(ext, true)
    end
  end
end
