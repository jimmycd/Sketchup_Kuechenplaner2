# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module UnterschrankInsel
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Küchenplaner – Inselschrank', 'unterschrank_insel/main')
    ext.description = 'Unterschrank für eine Kücheninsel: Türen oder Schubladen, verkleidete Rückseite, Wangen, erhöhte Theke. Menü: Erweiterungen > Küchenplaner > Unterschränke > Inselschrank'
    ext.version     = '1.0.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
