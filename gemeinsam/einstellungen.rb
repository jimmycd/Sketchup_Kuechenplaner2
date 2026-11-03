# encoding: UTF-8
# Küchenplaner – generelle Einstellungen der Küche (Sockel und Abstände).
#
# Gemeinsame Datei: ./build_rbz.sh kopiert sie nach src/kuechenplaner_gemeinsam/ in
# jede Erweiterung (wie eingabe.rb); wer sie braucht, lädt sie mit
#   require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'einstellungen')
#
# Die Werte gehören zur geplanten Küche und werden deshalb im Modell gespeichert
# (Wörterbuch Kuechenplaner_Einstellungen). Ein neues Modell übernimmt die zuletzt
# eingegebenen Werte dieses Rechners, sonst die Standardwerte. Alle Werte in mm.
# Eingabe: Erweiterungen › Küchenplaner › Einstellungen…
#
#   sockelhoehe            Fußboden bis Unterkante Korpus von Unter- und Hochschränken.
#                          Der Sockel besteht aus Stellfüßen: keine Zuschnitt- oder
#                          Holzteile, nur die Sockelblende davor.
#   wandabstand            Rückseite Schrank bis Wand (Unter-, Hoch- und Oberschränke);
#                          die Arbeitsplatte reicht trotzdem bis an die Wand.
#   abstand_oberschrank    lichter Abstand Oberkante Arbeitsplatte bis Unterkante Oberschrank
#   arbeitsplatte_staerke  Stärke der Arbeitsplatte für die Höhe der Oberschränke
#   unterschrank_hoehe     Korpushöhe der Unterschränke für die Höhe der Oberschränke

module Kuechenplaner
  module Einstellungen
    module_function

    DICT = 'Kuechenplaner_Einstellungen'.freeze
    SEKTION = 'Kuechenplaner_Einstellungen'.freeze

    # Schlüssel => [Beschriftung im Dialog, Standard, kleinster, größter Wert]
    WERTE = {
      'sockelhoehe' => ['Sockelhöhe – Stellfüße (mm)', 100.0, 0.0, 300.0],
      'wandabstand' => ['Abstand Schrankrückseite – Wand (mm)', 0.0, 0.0, 200.0],
      'abstand_oberschrank' => ['Lichter Abstand Arbeitsplatte – Oberschrank (mm)', 550.0, 0.0, 1500.0],
      'arbeitsplatte_staerke' => ['Stärke Arbeitsplatte (mm)', 40.0, 0.0, 200.0],
      'unterschrank_hoehe' => ['Korpushöhe Unterschrank (mm)', 700.0, 100.0, 1500.0]
    }.freeze

    def modell(model = nil)
      model || (defined?(Sketchup) && Sketchup.respond_to?(:active_model) ? Sketchup.active_model : nil)
    end

    def zahl(v)
      return nil if v.nil? || v.to_s.strip.empty?
      v.to_s.tr(',', '.').to_f
    end

    # Wert in mm: Modell, sonst zuletzt auf diesem Rechner eingegeben, sonst Standard
    def wert(schluessel, model = nil)
      std = WERTE.fetch(schluessel)[1]
      m = modell(model)
      v = zahl(m.get_attribute(DICT, schluessel)) if m.respond_to?(:get_attribute)
      v ||= zahl(Sketchup.read_default(SEKTION, schluessel, nil)) if defined?(Sketchup) && Sketchup.respond_to?(:read_default)
      v || std
    end

    # Wert prüfen und im Modell (und als Vorschlag für neue Modelle) speichern
    def setzen(schluessel, v, model = nil)
      _, _, min, max = WERTE.fetch(schluessel)
      v = zahl(v)
      raise ArgumentError, "#{WERTE[schluessel][0]}: bitte eine Zahl eingeben." if v.nil?
      raise ArgumentError, "#{WERTE[schluessel][0].sub(/ \(mm\)\z/, '')}: erlaubt sind #{min.round}–#{max.round} mm." if v < min || v > max
      m = modell(model)
      m.set_attribute(DICT, schluessel, v) if m.respond_to?(:set_attribute)
      Sketchup.write_default(SEKTION, schluessel, v) if defined?(Sketchup) && Sketchup.respond_to?(:write_default)
      v
    end

    def sockelhoehe(model = nil)
      wert('sockelhoehe', model)
    end

    def wandabstand(model = nil)
      wert('wandabstand', model)
    end

    def abstand_oberschrank(model = nil)
      wert('abstand_oberschrank', model)
    end

    def arbeitsplatte_staerke(model = nil)
      wert('arbeitsplatte_staerke', model)
    end

    def unterschrank_hoehe(model = nil)
      wert('unterschrank_hoehe', model)
    end

    # Oberkante Arbeitsplatte über dem Fußboden (boden = Höhe des Fußbodens, mm)
    def arbeitsplatte_oberkante(model = nil, boden = 0.0)
      boden + sockelhoehe(model) + unterschrank_hoehe(model) + arbeitsplatte_staerke(model)
    end

    # Unterkante Oberschrank über dem Fußboden (mm)
    def oberschrank_unterkante(model = nil, boden = 0.0)
      arbeitsplatte_oberkante(model, boden) + abstand_oberschrank(model)
    end

    GRUPPE = 'Küche – dieses Modell'.freeze

    # Für den Dialog: Beschriftungen und aktuelle Werte (Gruppe „Küche – dieses Modell“)
    def prompts
      WERTE.values.map { |w| "#{GRUPPE}: #{w[0]}" }
    end

    def vorgaben(model = nil)
      WERTE.keys.map { |k| format_mm(wert(k, model)) }
    end

    def format_mm(v)
      v == v.round ? v.round.to_s : v.round(1).to_s
    end

    # Eingaben aus dem Dialog (gleiche Reihenfolge wie prompts) prüfen und speichern;
    # erst alle prüfen, dann speichern, damit ein Fehler nichts halb übernimmt
    def uebernehmen(eingaben, model = nil)
      paare = WERTE.keys.zip(eingaben)
      paare.each do |k, v|
        z = zahl(v)
        _, _, min, max = WERTE[k]
        raise ArgumentError, "#{WERTE[k][0]}: bitte eine Zahl eingeben." if z.nil? || v.to_s.strip !~ /\A-?\d+([.,]\d+)?\z/
        raise ArgumentError, "#{WERTE[k][0].sub(/ \(mm\)\z/, '')}: erlaubt sind #{min.round}–#{max.round} mm." if z < min || z > max
      end
      paare.each { |k, v| setzen(k, v, model) }
      true
    end
  end
end
