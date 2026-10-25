# encoding: UTF-8
require 'sketchup.rb'
require 'extensions.rb'

module UnterschrankSchubladen
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Unterschrank mit Schubladen', 'unterschrank_schubladen/main')
    ext.description = 'Erzeugt einen Unterschrank mit konfigurierbaren Schubladen als Dynamic Component.'
    ext.version     = '1.2.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
