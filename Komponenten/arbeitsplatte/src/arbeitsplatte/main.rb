# encoding: UTF-8
#
# Arbeitsplatte – Erweiterung (.rbz): Erweiterungen > Küchenplaner
#   Arbeitsplatte erzeugen…       Unterschränke markieren (oder alle), Einstellungen
#                                 im Dialog, Platten werden als APL<n> gezeichnet
#   Arbeitsplatte neu berechnen   APL<n> (markiert, sonst alle) mit denselben
#                                 Einstellungen über den Schränken neu aufbauen
#
# Plan: docs/plaene/arbeitsplatte.md. Stand Schritt 3: Platten mit Material,
# Anleimer und Tags; Ausschnitte (Schritt 4) und Verbindungsfräsung/TCN (Schritt 5)
# folgen.
#
#   erkennung.rb  Zeilen und Ecken aus Grundriss-Rechtecken (ohne SketchUp, getestet)
#   layout.rb     Platten zuschneiden: Überstände, Ecken, Stoßarten, Teilung, Format
#   modell.rb     Schränke aus dem Modell lesen (JT_Schrank)
#   dialog.rb     Einstellungen abfragen
#   ausgabe.rb    Platten zeichnen (OCL-Material, Anleimer, Tags, JT_Arbeitsplatte)

require 'sketchup.rb'
require 'json'

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
    'WangeL' => 'Wange', 'WangeR' => 'Wange',
    'Platte' => 'Arbeitsplatte'
  }.freeze

  %w[erkennung layout modell dialog ausgabe].each { |f| load File.join(PATH, "#{f}.rb") }

  def self.meldung(erg, lay, kz)
    ["Arbeitsplatte #{kz}", '', Erkennung.zusammenfassung(erg), '', Layout.zusammenfassung(lay)].join("\n")
  end

  # optionen: Layout-Optionen; nil = Dialog
  def self.erzeugen(model = Sketchup.active_model, optionen: nil)
    erg = Modell.erkenne(model)
    if erg[:zeilen].empty?
      UI.messagebox('Keine Unterschränke gefunden. Unterschränke markieren oder nichts markieren (dann alle im Modell).')
      return nil
    end
    optionen ||= Dialog.abfragen(erg) or return nil
    lay = Layout.berechne(erg, optionen)
    model.start_operation('Arbeitsplatte erzeugen', true)
    inst = Ausgabe.bauen(model, erg, lay)
    model.commit_operation
    UI.messagebox(meldung(erg, lay, inst.name))
    inst
  rescue StandardError => e
    model.abort_operation if inst.nil? && model.respond_to?(:abort_operation)
    UI.messagebox("Fehler beim Erzeugen der Arbeitsplatte: #{e.message}")
    raise
  end

  # Gespeicherte Arbeitsplatte(n) neu aufbauen: gleiche Schränke, gleiche Einstellungen
  def self.neu_berechnen(model = Sketchup.active_model)
    alte = Ausgabe.arbeitsplatten(model)
    if alte.empty?
      UI.messagebox('Keine Arbeitsplatte gefunden. Zuerst „Arbeitsplatte erzeugen…“.')
      return []
    end
    model.start_operation('Arbeitsplatte neu berechnen', true)
    neu = alte.map do |alt|
      d = alt.definition
      kz = d.get_attribute(Ausgabe::JT_DICT, 'schrank')
      o = Ausgabe.optionen_lesen(d.get_attribute(Ausgabe::AP_DICT, 'optionen'))
      kzs = JSON.parse(d.get_attribute(Ausgabe::AP_DICT, 'schraenke'))
      warn = []
      els = Modell.instanzen(model, alle: true).select { |i| kzs.include?(i.definition.get_attribute(Modell::JT_DICT, 'schrank')) }
                  .flat_map { |i| Modell.elemente(i, warn) }
      erg = Erkennung.erkenne(els)
      erg[:warnungen] = warn + erg[:warnungen]
      # Ecken-Einstellungen gelten nur, solange die Ecken gleich nummeriert sind
      o[:ecken] = o[:ecken].select { |nr, _| erg[:ecken].any? { |e| e[:nr] == nr } }
      lay = Layout.berechne(erg, o)
      model.entities.erase_entities(alt)
      [erg, lay, Ausgabe.bauen(model, erg, lay, kz: kz)]
    end
    model.commit_operation
    UI.messagebox(neu.map { |erg, lay, inst| meldung(erg, lay, inst.name) }.join("\n\n"))
    neu.map(&:last)
  rescue StandardError => e
    model.abort_operation if model.respond_to?(:abort_operation)
    UI.messagebox("Fehler beim Neuberechnen: #{e.message}")
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
    menu.add_item('Arbeitsplatte neu berechnen') { Arbeitsplatte.neu_berechnen }
  end
  file_loaded(__FILE__)
end
