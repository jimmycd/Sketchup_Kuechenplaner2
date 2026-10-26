# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module UnterschrankKochfeld
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Küchenplaner – Unterschrank Kochfeld mit Abzug', 'unterschrank_kochfeld/main')
    ext.description = 'Erzeugt einen Unterschrank für ein Kochfeld mit integriertem Abzug (Blende, Schubladen, Kanal) als Dynamic Component. Menü: Erweiterungen > Küchenplaner'
    ext.version     = '1.1.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
