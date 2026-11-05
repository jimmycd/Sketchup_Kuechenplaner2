# encoding: UTF-8
#
# Arbeitsplatte – Erweiterung (.rbz): Erweiterungen > Küchenplaner
#   Arbeitsplatte erzeugen…       Unterschränke markieren (oder alle), Einstellungen
#                                 im Dialog, Platten werden als APL<n> gezeichnet
#   Arbeitsplatte neu berechnen   APL<n> (markiert, sonst alle) mit denselben
#                                 Einstellungen über den Schränken neu aufbauen
#
# Plan: docs/plaene/arbeitsplatte.md. Stand Schritt 4: Platten mit Material,
# Anleimer, Tags und Ausschnitten für Spüle und Kochfeld; Verbindungsfräsung/TCN
# (Schritt 5) folgt.
#
#   erkennung.rb  Zeilen und Ecken aus Grundriss-Rechtecken (ohne SketchUp, getestet)
#   ausschnitte.rb  Spüle und Kochfeld aus den Schränken, Prüfungen
#   layout.rb     Platten zuschneiden: Überstände, Ecken, Stoßarten, Teilung, Format
#   modell.rb     Schränke aus dem Modell lesen (JT_Schrank)
#   dialog.rb     Einstellungen abfragen
#   ausgabe.rb    Platten zeichnen (Material, Anleimer, Tags, JT_Arbeitsplatte)

require 'sketchup.rb'
require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'eingabe') # Eingabefenster im Treppenplaner-Stil
require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'neuladen') # Neu laden ohne Neustart (Wächter)
require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'einstellungen') # Sockelhöhe und Abstände der Küche
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
    'Rueckwand' => 'Rueckwand', 'RueckwandOben' => 'Rueckwand', 'RueckwandUnten' => 'Rueckwand',
    'Einlegeboden' => 'Einlegeboden', 'Front' => 'Front',
    'Tuer' => 'Tuer', 'TuerL' => 'Tuer', 'TuerR' => 'Tuer', 'TuerUnten' => 'Tuer', 'TuerOben' => 'Tuer',
    'Klappe' => 'Front', 'KlappeO' => 'Front', 'KlappeU' => 'Front',
    'KastenBoden' => 'KastenBoden', 'KastenRueckwand' => 'KastenRueckwand',
    'Innenfront' => 'Innenfront',
    'Auflageleiste' => 'Leiste',
    'Blende' => 'Front',
    'WangeL' => 'Wange', 'WangeR' => 'Wange',
    'Winkelleiste' => 'Leiste', 'Sockelblende' => 'Sockel', 'SockelSeiteL' => 'Sockel', 'SockelSeiteR' => 'Sockel',
    'Platte' => 'Arbeitsplatte',
    'Verkleidung' => 'Verkleidung', 'Theke' => 'Theke'
  }.freeze

  %w[erkennung ausschnitte layout modell dialog ausgabe].each { |f| load File.join(PATH, "#{f}.rb") }

  def self.meldung(erg, lay, kz)
    ["Arbeitsplatte #{kz}", '', Erkennung.zusammenfassung(erg), '', Layout.zusammenfassung(lay)].join("\n")
  end

  # optionen: Layout-Optionen; nil = Eingabefenster (dann wird nach „Erzeugen“ gebaut)
  def self.erzeugen(model = Sketchup.active_model, optionen: nil)
    erg = Modell.erkenne(model)
    if erg[:zeilen].empty?
      UI.messagebox('Keine Unterschränke gefunden. Unterschränke markieren oder nichts markieren (dann alle im Modell).')
      return nil
    end
    return bauen(model, erg, optionen) if optionen
    Dialog.abfragen(erg) { |o| bauen(model, erg, o) }
  end

  # Abstand Schrankrückseite – Wand aus Küchenplaner › Einstellungen (immer der aktuelle Wert)
  def self.mit_wandabstand(model, o)
    return o unless defined?(Kuechenplaner::Einstellungen)
    o.merge(schrank_wandabstand: Kuechenplaner::Einstellungen.wandabstand(model))
  end

  def self.bauen(model, erg, optionen)
    lay = Layout.berechne(erg, mit_wandabstand(model, optionen))
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
      lay = Layout.berechne(erg, mit_wandabstand(model, o))
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
