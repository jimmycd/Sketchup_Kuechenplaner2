# encoding: UTF-8
# Schrank-CNC – Werkzeuge für die Schränke aus Komponenten/ (Küchenplaner 2):
# TCN-Export für TpaCAD, Stückliste, Etiketten, Zuschnittplan, Frontfarbe ändern, Griffkatalog.
# Lizenz GPL-3.0 (QR-Codes mit rqrcode_core, MIT, siehe THIRD_PARTY.md).

require 'sketchup.rb'
require 'extensions.rb'

module JTools
  module SchrankCnc
    EXT_VERSION = '0.29.0'.freeze unless defined?(EXT_VERSION)

    unless defined?(@extension) && @extension
      ext = SketchupExtension.new('Küchenplaner – Schrank-CNC (TCN-Export)', File.join(File.dirname(File.expand_path(__FILE__)), 'jt_schrank_cnc', 'main'))
      ext.description = 'Schränke aus dem Küchenplaner: TCN-Export für TpaCAD, Stückliste, Etiketten, Zuschnittplan für die Formatsäge, ' \
                        'Andocken neuer Schränke sowie Frontfarbe für alle, Ober-, Unter- oder Hochschränke ändern, Griffkatalog mit Griffen je Schrank. ' \
                        'Menü: Erweiterungen > Küchenplaner. Lizenz GPL-3.0.'
      ext.version = EXT_VERSION
      ext.creator = 'JTools'
      ext.copyright = '2026, GPL-3.0'
      @extension = ext
      Sketchup.register_extension(ext, true)
    end
  end
end
