# encoding: UTF-8
# Schrank-CNC – Hauptmodul: lädt die Untermodule und legt das Menü an.

require 'sketchup.rb'

# Gemeinsames Untermenü "Erweiterungen > Küchenplaner" für alle Komponenten und
# den TCN-Export. Steht wortgleich in jeder Erweiterung (der Test prüft das), damit
# das Untermenü nur einmal angelegt wird, egal welche Erweiterungen geladen sind.
# Schränke kommen über Kuechenplaner.schrank('Unterschränke' | 'Oberschränke' |
# 'Hochschränke', titel) ins Menü und in die Schrank-Auswahl der Symbolleiste,
# Geräte und Raum in Kuechenplaner.untermenu('Geräte' | 'Raum'), Werkzeuge direkt in Kuechenplaner.menu darunter.
module Kuechenplaner
  GRUPPEN = ['Unterschränke', 'Oberschränke', 'Hochschränke', 'Geräte', 'Raum'].freeze

  def self.menu
    @menu ||= UI.menu('Extensions').add_submenu('Küchenplaner')
  end

  # Alle Gruppen beim ersten Aufruf anlegen, damit die Reihenfolge nicht von der
  # Ladereihenfolge der Erweiterungen abhängt.
  def self.untermenu(gruppe)
    @untermenues ||= GRUPPEN.each_with_object({}) { |g, h| h[g] = menu.add_submenu(g) }
    @untermenues.fetch(gruppe)
  end

  # Schrank in seiner Gruppe ins Menü eintragen und für die Symbolleiste merken
  def self.schrank(gruppe, titel, &aktion)
    untermenu(gruppe).add_item(titel, &aktion)
    schraenke << [gruppe, titel, aktion]
  end

  # Alle eingetragenen Schränke als [gruppe, titel, aktion]
  def self.schraenke
    @schraenke ||= []
  end
end unless defined?(Kuechenplaner.schrank)

module JTools
  module SchrankCnc
    PATH = File.dirname(__FILE__) unless defined?(PATH)

    %w[einstellungen schraenke andocken frontfarbe geometrie regeln tcn arbeitsplatte fraesliste export stueckliste etiketten].each { |f| load File.join(PATH, "#{f}.rb") }

    unless file_loaded?(__FILE__)
      # Unten im Küchenplaner-Menü, nach den Komponenten: der Timer läuft erst,
      # wenn SketchUp alle Erweiterungen geladen hat
      UI.start_timer(0, false) do
        menu = Kuechenplaner.menu
        menu.add_separator
        menu.add_item('TCN exportieren…') { Export.dialog }
        menu.add_item('Stückliste…') { Stueckliste.dialog }
        menu.add_item('Etiketten…') { Etiketten.dialog }
        menu.add_item('Frontfarbe und Griffe ändern…') { Frontfarbe.dialog }
        menu.add_item('Schrank andocken…') { Andocken.starten }
        menu.add_item('Einstellungen…') { Einstellungen.dialog }
      end
      file_loaded(__FILE__)
    end
  end
end
