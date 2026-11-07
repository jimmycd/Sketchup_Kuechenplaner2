# encoding: UTF-8
# Schrank-CNC – Hauptmodul: lädt die Untermodule und legt das Menü an.

require 'sketchup.rb'
require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'eingabe') # Eingabefenster im Treppenplaner-Stil
require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'neuladen') # Neu laden ohne Neustart (Wächter)
require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'einstellungen') # Sockelhöhe und Abstände der Küche
require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'schubkasten') # Schubladenauszug der Küche (Werte für die Schränke)

# Gemeinsames Untermenü "Erweiterungen > Küchenplaner" für alle Komponenten und
# den TCN-Export. Steht wortgleich in jeder Erweiterung (der Test prüft das), damit
# das Untermenü nur einmal angelegt wird, egal welche Erweiterungen geladen sind.
# Schränke kommen über Kuechenplaner.schrank('Unterschränke' | 'Oberschränke' |
# 'Hochschränke' | 'Blenden & Wangen', titel) ins Menü und in die Schrank-Auswahl der Symbolleiste,
# Geräte und Raum in Kuechenplaner.untermenu('Geräte' | 'Raum'), Werkzeuge direkt in Kuechenplaner.menu darunter.
# Darf mehrfach laufen (Neuladen ohne Neustart): die Methoden werden ersetzt, die
# angelegten Menüs bleiben gemerkt.
module Kuechenplaner
  GRUPPEN = ['Unterschränke', 'Oberschränke', 'Hochschränke', 'Blenden & Wangen', 'Geräte', 'Raum'].freeze unless const_defined?(:GRUPPEN, false)

  def self.menu
    @menu ||= UI.menu('Extensions').add_submenu('Küchenplaner')
  end

  # Alle Gruppen beim ersten Aufruf anlegen, damit die Reihenfolge nicht von der
  # Ladereihenfolge der Erweiterungen abhängt.
  def self.untermenu(gruppe)
    @untermenues ||= GRUPPEN.each_with_object({}) { |g, h| h[g] = menu.add_submenu(g) }
    @untermenues[gruppe] ||= menu.add_submenu(gruppe) # neue Gruppe aus einem Update: unten anhängen
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
end # gemeinsames Untermenü

module JTools
  module SchrankCnc
    PATH = File.dirname(__FILE__) unless defined?(PATH)

    %w[einstellungen materialien schraenke beschlagkatalog griffkatalog andocken massaenderung kopien frontfarbe korpus materialdialog geometrie regeln griffmulde grifflos tcn arbeitsplatte fraesliste export beschlaege stueckliste pdf etiketten guillotine zuschnitt ausgabe beschriftung beschlagmodell griffmodell schrankbeschlag griffdialog rendern freier_schrank freier_korpus freier_bibliothek].each { |f| load File.join(PATH, "#{f}.rb") }

    unless file_loaded?(__FILE__)
      # Unten im Küchenplaner-Menü, nach den Komponenten: der Timer läuft erst,
      # wenn SketchUp alle Erweiterungen geladen hat
      UI.start_timer(0, false) do
        menu = Kuechenplaner.menu
        menu.add_separator
        menu.add_item('Export (Stückliste, Etiketten, Zuschnitt, TCN)…') { Ausgabe.dialog }
        menu.add_item('Schrank-Beschriftung ein/aus') { Beschriftung.umschalten }
        menu.add_item('Beschläge ein/aus') { Beschlagmodell.umschalten }
        menu.add_item('Rendern (Blender)…') { Rendern.dialog }
        menu.add_item('Materialien…') { Materialdialog.dialog }
        menu.add_item('Griffkatalog…') { Griffdialog.zeigen }
        menu.add_item('Frontfarbe ändern…') { Frontfarbe.dialog }
        menu.add_item('Beschläge und Griffe der gewählten Schränke…') { Schrankbeschlag.dialog }
        menu.add_item('Korpusmaterial ändern…') { Korpusmaterial.dialog }
        menu.add_item('Schrank andocken…') { Andocken.starten }
        # Freier Schrank in den Schrankgruppen (Menü und Schrank-Auswahl der Symbolleiste)
        { 'Unterschränke' => 'Unterschrank', 'Oberschränke' => 'Oberschrank', 'Hochschränke' => 'Hochschrank' }.each do |g, kat|
          Kuechenplaner.schrank(g, 'Freier Schrank…') { FreierSchrank.anlegen_dialog(kategorie: kat) }
        end
        frei = menu.add_submenu('Freier Schrank')
        frei.add_item('Freien Schrank anlegen…') { FreierSchrank.anlegen_dialog }
        frei.add_item('Mittelwand einsetzen…') { FreierSchrank.einsetzen_dialog('Mittelwand') }
        frei.add_item('Einlegeboden einsetzen…') { FreierSchrank.einsetzen_dialog('Einlegeboden') }
        frei.add_item('Zwischenboden einsetzen…') { FreierSchrank.einsetzen_dialog('Zwischenboden') }
        frei.add_item('Tür einsetzen…') { FreierSchrank.front_dialog('Tür') }
        frei.add_item('Schublade einsetzen…') { FreierSchrank.front_dialog('Schublade') }
        frei.add_item('Blende einsetzen…') { FreierSchrank.front_dialog('Blende') }
        frei.add_separator
        frei.add_item('Als eigenen Schrank speichern…') { FreierSchrank.speichern_dialog }
        frei.add_item('Eigenen Schrank einfügen…') { FreierSchrank.einfuegen_dialog }
        frei.add_item('Bibliotheksordner…') { FreierSchrank.ordner_dialog }
        frei.add_item('Schrank lösen (frei bearbeiten)…') { FreierSchrank.loesen_dialog }
        frei.add_separator
        frei.add_item('Als freien Schrank kennzeichnen…') { FreierSchrank.kennzeichnen_dialog }
        frei.add_item('Teil zuweisen…') { FreierSchrank.teil_dialog }
        frei.add_item('Schrank prüfen') { FreierSchrank.pruefen_dialog }
        if UI.respond_to?(:add_context_menu_handler)
          UI.add_context_menu_handler do |kontext|
            model = Sketchup.active_model
            unless Schrankbeschlag.schraenke(model).empty?
              kontext.add_item('Beschläge und Griffe dieses Schranks…') { Schrankbeschlag.dialog }
            end
            s = FreierSchrank.schrank_zur_auswahl(model)
            next unless s && FreierSchrank.frei?(s) && !model.selection.to_a.empty?
            kontext.add_item('Freier Schrank: Teil zuweisen…') { FreierSchrank.teil_dialog }
          end
        end
        menu.add_item('Einstellungen…') { Einstellungen.dialog }
      end
      file_loaded(__FILE__)
    end
    Beschlagmodell.app_beobachten # Beschläge folgen Änderungen am Schrank
    Griffmodell.app_beobachten # Griffe der Fronten (Griffkatalog) folgen Änderungen am Schrank
    Beschriftung.app_beobachten # einmal je SketchUp-Sitzung, auch nach dem Neuladen
    Massaenderung.app_beobachten # angedockte Schränke bei Breite/Tiefe richtig verschieben
    Kopien.app_beobachten # kopierte Schränke: Schubladen/Türen öffnen nur im angeklickten Schrank
  end
end
