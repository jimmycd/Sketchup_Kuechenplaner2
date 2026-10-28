# encoding: UTF-8
#
# Arbeitsplatte – Erweiterung (.rbz): Erweiterungen > Küchenplaner > Arbeitsplatte erzeugen
#
# Legt nach dem Stellen der Unterschränke die Arbeitsplatte darüber (Plan:
# docs/plaene/arbeitsplatte.md). Stand Schritt 2: Zeilen, Ecken (L/U) und
# Begrenzungen werden erkannt und die Platten berechnet und angezeigt; gezeichnet
# werden sie ab Schritt 3.
#
#   erkennung.rb  Zeilen und Ecken aus Grundriss-Rechtecken (ohne SketchUp, getestet)
#   layout.rb     Platten zuschneiden: Überstände, Ecken, Stoßarten, Teilung, Format
#   modell.rb     Schränke aus dem Modell lesen (JT_Schrank)

require 'sketchup.rb'

module Arbeitsplatte
  PATH = File.dirname(__FILE__) unless defined?(PATH)
  DOKU_URL = 'https://github.com/jimmycd/sketchup_kuechenplaner2/tree/main/Komponenten/arbeitsplatte'.freeze

  # Tag-Schema wie bei den Schränken: Teil -> Rolle (in allen Komponenten gleich)
  ROLLEN = {
    'SeiteL' => 'Seite', 'SeiteR' => 'Seite', 'Boden' => 'Boden', 'Deckel' => 'Deckel',
    'StrebeVorn' => 'Strebe', 'StrebeHinten' => 'Strebe',
    'ZwischenbodenUnten' => 'Zwischenboden', 'ZwischenbodenMitte' => 'Zwischenboden', 'ZwischenbodenOben' => 'Zwischenboden',
    'Mittelboden' => 'Zwischenboden',
    'Rueckwand' => 'Rueckwand', 'Einlegeboden' => 'Einlegeboden', 'Front' => 'Front',
    'Tuer' => 'Tuer', 'TuerL' => 'Tuer', 'TuerR' => 'Tuer',
    'KastenBoden' => 'KastenBoden', 'KastenRueckwand' => 'KastenRueckwand',
    'Blende' => 'Front',
    'WangeL' => 'Wange', 'WangeR' => 'Wange'
  }.freeze

  %w[erkennung layout modell].each { |f| load File.join(PATH, "#{f}.rb") }

  def self.erzeugen(model = Sketchup.active_model)
    erg = Modell.erkenne(model)
    lay = Layout.berechne(erg)
    UI.messagebox("Arbeitsplatte – erkannte Schrankzeilen\n\n#{Erkennung.zusammenfassung(erg)}\n\n" \
                  "Platten\n\n#{Layout.zusammenfassung(lay)}\n\n" \
                  'Gezeichnet werden die Platten ab dem nächsten Ausbauschritt.')
    erg.merge(layout: lay)
  rescue StandardError => e
    UI.messagebox("Fehler beim Erkennen der Schrankzeilen: #{e.message}")
    raise
  end
end

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

unless file_loaded?(__FILE__)
  # Nach den Schrank-Untermenüs: der Timer läuft erst, wenn SketchUp alle
  # Erweiterungen geladen hat
  UI.start_timer(0, false) do
    menu = Kuechenplaner.menu
    menu.add_separator
    menu.add_item('Arbeitsplatte erzeugen…') { Arbeitsplatte.erzeugen }
  end
  file_loaded(__FILE__)
end
