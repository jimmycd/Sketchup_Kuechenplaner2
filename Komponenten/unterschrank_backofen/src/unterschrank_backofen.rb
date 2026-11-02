# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module UnterschrankBackofen
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Küchenplaner – Unterschrank Backofen (Herdumbau)', 'unterschrank_backofen/main')
    ext.description = 'Erzeugt einen Herdumbauschrank (Backofen unter dem Kochfeld, darunter Schublade oder Blende) als Dynamic Component. Menü: Erweiterungen > Küchenplaner'
    ext.version     = '1.0.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
