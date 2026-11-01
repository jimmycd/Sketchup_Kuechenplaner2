# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module UnterschrankAbfall
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Küchenplaner – Unterschrank Mülltrennung', 'unterschrank_abfall/main')
    ext.description = 'Unterschrank mit Müllauszug (1–4 Abfallbehälter), wahlweise Schublade oben. Menü: Erweiterungen > Küchenplaner > Unterschränke > Unterschrank Mülltrennung'
    ext.version     = '1.0.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
