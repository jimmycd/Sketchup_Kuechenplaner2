# encoding: UTF-8
# Schrank-CNC – Hauptmodul: lädt die Untermodule und legt das Menü an.

require 'sketchup.rb'

# Gemeinsames Untermenü "Erweiterungen > Küchenplaner" für alle Komponenten und
# den TCN-Export. Steht wortgleich in jeder Erweiterung (der Test prüft das), damit
# das Untermenü nur einmal angelegt wird, egal welche Erweiterungen geladen sind.
# Schränke kommen in Kuechenplaner.untermenu('Unterschränke' | 'Oberschränke' |
# 'Hochschränke'), Geräte in 'Geräte', Werkzeuge direkt in Kuechenplaner.menu darunter.
module Kuechenplaner
  GRUPPEN = ['Unterschränke', 'Oberschränke', 'Hochschränke', 'Geräte'].freeze

  def self.menu
    @menu ||= UI.menu('Extensions').add_submenu('Küchenplaner')
  end

  # Alle Gruppen beim ersten Aufruf anlegen, damit die Reihenfolge nicht von der
  # Ladereihenfolge der Erweiterungen abhängt.
  def self.untermenu(gruppe)
    @untermenues ||= GRUPPEN.each_with_object({}) { |g, h| h[g] = menu.add_submenu(g) }
    @untermenues.fetch(gruppe)
  end
end unless defined?(Kuechenplaner.untermenu)

module JTools
  module SchrankCnc
    PATH = File.dirname(__FILE__) unless defined?(PATH)

    %w[schraenke frontfarbe geometrie regeln tcn export].each { |f| load File.join(PATH, "#{f}.rb") }

    unless file_loaded?(__FILE__)
      # Unten im Küchenplaner-Menü, nach den Komponenten: der Timer läuft erst,
      # wenn SketchUp alle Erweiterungen geladen hat
      UI.start_timer(0, false) do
        menu = Kuechenplaner.menu
        menu.add_separator
        menu.add_item('TCN exportieren…') { Export.dialog }
        menu.add_item('Frontfarbe und Griffe ändern…') { Frontfarbe.dialog }
      end
      file_loaded(__FILE__)
    end
  end
end
