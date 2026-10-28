# encoding: UTF-8
# Küchenplaner – Plugins aktualisieren: neue Versionen aller Küchenplaner-Erweiterungen
# direkt aus SketchUp laden (GitHub oder lokaler Repo-Ordner), ohne Extension Manager.
require 'sketchup.rb'
require 'extensions.rb'

module KuechenplanerUpdate
  unless file_loaded?(__FILE__)
    ext = SketchupExtension.new('Küchenplaner – Plugins aktualisieren', 'kuechenplaner_update/main')
    ext.description = 'Lädt den aktuellen Stand aller Küchenplaner-Erweiterungen von GitHub (Zweig main) oder aus einem ' \
                      'lokalen Repo-Ordner und lädt sie sofort neu, ohne Extension Manager und ohne Neustart. ' \
                      'Menü: Erweiterungen > Küchenplaner > Plugins aktualisieren'
    ext.version     = '1.0.0'
    ext.creator     = 'Jürgen'
    Sketchup.register_extension(ext, true)
    file_loaded(__FILE__)
  end
end
