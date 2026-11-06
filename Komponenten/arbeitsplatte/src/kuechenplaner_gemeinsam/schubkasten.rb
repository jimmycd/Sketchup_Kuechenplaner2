# encoding: UTF-8
# Küchenplaner – Schubladenauszug der Küche (Beschlag-Katalog, Beschlagart „schubladen“).
#
# Gemeinsame Datei: ./build_rbz.sh kopiert sie nach src/kuechenplaner_gemeinsam/ in jede
# Erweiterung; wer sie braucht, lädt sie mit
#   require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'schubkasten')
#
# Das Auszugssystem wird einmal für die ganze Küche gewählt (Küchenplaner › Einstellungen…,
# Beschläge). Das Plugin Schrank-CNC schreibt die Maße, die die Schränke brauchen, als JSON in
# das Modell (Wörterbuch Kuechenplaner_Einstellungen, Schlüssel schubkasten, Werte in cm) und als
# Vorschlag für neue Modelle auf diesen Rechner. Fehlt beides (Plugin nicht installiert), gilt
# Blum LEGRABOX free.
#
# Jeder Schrank mit Schubladen trägt die Werte als DC-Attribute Ausz_* (siehe ATTRIBUTE); die
# Formeln für Kastenboden, Holzrückwand, Zarge und Nennlänge rechnen damit. Wechselt das
# System, setzt das Plugin die Attribute neu und zeichnet die Schränke neu.
#
#   zargen       Zargenhöhen mit Holzrückwand [Zarge, Rückwand], höchste zuerst (bis 5)
#   std          Rückwand der Standardzarge (= Hoehe_Kastenrueckwand im Schrank)
#   ueber_boden  Schiene mindestens so weit über dem festen Boden darunter
#   nl_*         Nennlängen nl_min … nl_max in Schritten nl_schritt, NL + nl_abstand <= lichte Tiefe
#   boden_b/_t   Kastenboden = lichte Weite − boden_b, Nennlänge − boden_t
#   rw_b         Holzrückwand = lichte Weite − rw_b

require 'json'

module Kuechenplaner
  module Schubkasten
    module_function

    # Konstanten nur einmal (mehrere Erweiterungen laden ihre Kopie dieser Datei)
    unless const_defined?(:STANDARD, false)
      DICT = 'Kuechenplaner_Einstellungen'.freeze
      SCHLUESSEL = 'schubkasten'.freeze
      STUFEN = 5
      EPS = 0.0001

      # Blum LEGRABOX free (muss zum Katalogeintrag blum-legrabox-free passen, der Test prüft das)
      STANDARD = {
        'kennung' => 'blum-legrabox-free',
        'zargen' => [[24.1, 21.2], [17.7, 14.8], [12.85, 9.9], [9.05, 6.2], [6.65, 3.7]],
        'std' => 14.8, 'ueber_boden' => 3.8,
        'nl_min' => 35.0, 'nl_max' => 65.0, 'nl_schritt' => 5.0, 'nl_abstand' => 0.3,
        'boden_b' => 3.5, 'boden_t' => 1.0, 'rw_b' => 3.8
      }.freeze
    end

    def modell(model = nil)
      model || (defined?(Sketchup) && Sketchup.respond_to?(:active_model) ? Sketchup.active_model : nil)
    end

    # Werte des gewählten Systems (cm)
    def werte(model = nil)
      m = modell(model)
      roh = m.get_attribute(DICT, SCHLUESSEL) if m.respond_to?(:get_attribute)
      # neues Modell: zuletzt auf diesem Rechner gewählt (wie die anderen Einstellungen)
      roh ||= Sketchup.read_default(DICT, SCHLUESSEL, nil) if defined?(Sketchup) && Sketchup.respond_to?(:read_default)
      w = (JSON.parse(roh) rescue nil) if roh.is_a?(String)
      w.is_a?(Hash) && w['zargen'].is_a?(Array) && !w['zargen'].empty? ? STANDARD.merge(w) : STANDARD
    end

    # DC-Attribute am Schrank (Name => Wert in cm)
    def attribute(w = werte)
      z = w['zargen'].first(STUFEN)
      z += [z.last] * (STUFEN - z.size)
      a = {}
      z.each_with_index do |(zh, rw), i|
        a["Ausz_Z#{i + 1}"] = zh.to_f
        a["Ausz_H#{i + 1}"] = rw.to_f
      end
      { 'Std' => 'std', 'Ueber_Boden' => 'ueber_boden', 'NL_Min' => 'nl_min', 'NL_Max' => 'nl_max',
        'NL_Schritt' => 'nl_schritt', 'NL_Abstand' => 'nl_abstand', 'Boden_B' => 'boden_b',
        'Boden_T' => 'boden_t', 'RW_B' => 'rw_b' }.each { |n, k| a["Ausz_#{n}"] = w[k].to_f }
      a
    end

    NAMEN = attribute(STANDARD).keys.freeze unless const_defined?(:NAMEN, false)

    # Startwerte eines neuen Schranks: Vorgaben des Generators + Auszugssystem des Modells
    def vorgaben(defaults, model = nil)
      w = werte(model)
      defaults.merge(attribute(w)).merge('Hoehe_Kastenrueckwand' => w['std'].to_f)
    end

    # Werte für die Rechnung im Generator: Attribute in p (Ausz_*) oder aus dem Modell
    def aus(p)
      p.is_a?(Hash) && p.key?('Ausz_Z1') ? p : attribute
    end

    # Holzrückwand der höchsten Zarge, die in kc passt (cm). soll = Hoehe_Kastenrueckwand:
    # bei der Standardzarge die gewünschte Rückwand, darunter höchstens soll; höhere Zargen nur,
    # wenn soll nicht unter die Standardrückwand gesenkt ist.
    def hrw(kc, soll, p = nil)
      a = aus(p)
      std = a['Ausz_Std']
      i = (1...STUFEN).find { |j| kc >= a["Ausz_Z#{j}"] - EPS } || STUFEN
      h = a["Ausz_H#{i}"]
      if h > std + EPS then soll >= std - EPS ? h : soll
      elsif h >= std - EPS then soll
      else [soll, h].min
      end
    end

    # dieselbe Wahl als DC-Formel; q = Name des Teils mit den Ausz_*-Attributen (nil = eigene)
    def f_hrw(kc, soll, q = nil)
      r = ->(n) { q ? "#{q}!Ausz_#{n}" : "Ausz_#{n}" }
      std = r.('Std')
      wert = lambda do |i|
        h = r.("H#{i}")
        "IF(#{h}>#{std}+#{EPS},IF(#{soll}>=#{std}-#{EPS},#{h},#{soll}),IF(#{h}>=#{std}-#{EPS},#{soll},MIN(#{soll},#{h})))"
      end
      (1...STUFEN).reverse_each.inject(wert.(STUFEN)) do |sonst, i|
        "IF(#{kc}>=#{r.("Z#{i}")}-#{EPS},#{wert.(i)},#{sonst})"
      end
    end

    # Nennlänge (cm): größte mit NL + nl_abstand <= Tiefe, sonst die kürzeste
    def nl(tiefe, p = nil)
      a = aus(p)
      n = ((tiefe - a['Ausz_NL_Abstand']) / a['Ausz_NL_Schritt'] + 0.000001).floor * a['Ausz_NL_Schritt']
      [a['Ausz_NL_Min'], [a['Ausz_NL_Max'], n].min].max
    end

    def f_nl(tiefe, q = nil)
      r = ->(n) { q ? "#{q}!Ausz_#{n}" : "Ausz_#{n}" }
      "MAX(#{r.('NL_Min')},MIN(#{r.('NL_Max')},INT((#{tiefe}-#{r.('NL_Abstand')})/#{r.('NL_Schritt')}+0.000001)*#{r.('NL_Schritt')}))"
    end

    def nl_min(p = nil)
      a = aus(p)
      a['Ausz_NL_Min'] + a['Ausz_NL_Abstand']
    end
  end
end
