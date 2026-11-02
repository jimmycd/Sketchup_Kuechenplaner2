# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module OberschrankDunstabzug
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Küchenplaner – Oberschrank Dunstabzug', 'oberschrank_dunstabzug/main')
    ext.description = 'Oberschrank für eine Flachschirmhaube: unten offen, Haubenboden mit Ausschnitt für das Abluftrohr. Menü: Erweiterungen > Küchenplaner > Oberschränke > Oberschrank Dunstabzug'
    ext.version     = '1.0.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
