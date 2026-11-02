# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module OberschrankKlappe
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Küchenplaner – Oberschrank mit Klappe', 'oberschrank_klappe/main')
    ext.description = 'Oberschrank mit Klappe Blum AVENTOS HK-top oder HF (Faltklappe), 0–2 Einlegeböden. Menü: Erweiterungen > Küchenplaner > Oberschränke > Oberschrank mit Klappe'
    ext.version     = '1.0.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
