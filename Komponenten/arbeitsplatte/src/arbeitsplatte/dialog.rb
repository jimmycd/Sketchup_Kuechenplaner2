# encoding: UTF-8
#
# Arbeitsplatte – Einstellungen abfragen (UI.inputbox)
#
# felder liefert Beschriftungen, Vorgaben und Auswahllisten, optionen wandelt die
# Antworten in Layout-Optionen. Beides ohne SketchUp testbar; nur abfragen ruft
# UI.inputbox auf.

module Arbeitsplatte
  module Dialog
    ARTEN   = { 'Schichtstoff (Anleimer ab Werk)' => :schichtstoff, 'Massivholz' => :massivholz }.freeze
    STOESSE = { 'Gehrungsansatz' => :gehrungsansatz, 'stumpf' => :stumpf, 'Gehrung 45°' => :gehrung }.freeze
    AUTO    = 'automatisch nach Tiefe'.freeze
    EIGENES = 'eigenes (Feld darunter)'.freeze

    def self.format_text(f)
      "#{f[0].round} × #{f[1].round}"
    end

    def self.zeile_text(z)
      "Zeile #{z[:nr]} (#{z[:elemente].first[:kz]}–#{z[:elemente].last[:kz]})"
    end

    def self.zahl(v)
      v.to_s.tr(',', '.').to_f
    end

    # [beschriftungen, vorgaben, listen] für Ergebnis erg und Vorgabe-Optionen o
    def self.felder(erg, o = {})
      o = Layout::OPTIONEN.merge(o)
      formate = Layout::STANDARDFORMATE.map { |f| format_text(f) }
      f = [
        ['Plattenart', ARTEN.key(o[:art].to_sym), ARTEN.keys.join('|')],
        ['Stärke (mm, 0 = Standard 38/40)', (o[:staerke] || 0).to_s, ''],
        ['Überstand vorn (mm)', o[:ueberstand_vorn].to_s, ''],
        ['Überstand seitlich an freien Enden (mm)', o[:ueberstand_seite].to_s, ''],
        ['Wandabstand (mm)', o[:wandabstand].to_s, ''],
        ['Fuge zum Hochschrank (mm)', o[:fuge_hochschrank].to_s, ''],
        ['Format', o[:format] ? (formate.include?(format_text(o[:format])) ? format_text(o[:format]) : EIGENES) : AUTO,
         ([AUTO] + formate + [EIGENES]).join('|')],
        ['Eigenes Format Länge × Breite (mm)', o[:format] ? format_text(o[:format]).sub(' × ', ' x ') : '4100 x 900', ''],
        ['Gehrungsansatz: Gehrungstiefe (mm)', o[:gehrungstiefe].to_s, ''],
        ['Gehrungsansatz: Radius Übergang (mm)', o[:radius].to_s, '']
      ]
      erg[:ecken].each do |e|
        eo = o[:ecken][e[:nr]] || {}
        a, b = e[:zeilen].map { |nr| erg[:zeilen].find { |z| z[:nr] == nr } }
        durch = eo[:durchlaufend] || Layout.standard_durchlaufend(a, b)
        f << ["Ecke #{e[:nr]}: Stoß", STOESSE.key((eo[:stoss] || o[:stoss]).to_sym), STOESSE.keys.join('|')]
        f << ["Ecke #{e[:nr]}: durchlaufende Platte", zeile_text(durch == a[:nr] ? a : b), [a, b].map { |z| zeile_text(z) }.join('|')]
      end
      f.transpose
    end

    # Antworten -> Layout-Optionen
    def self.optionen(erg, werte)
      w = werte.map(&:to_s)
      art = ARTEN.fetch(w[0])
      o = { art: art, staerke: zahl(w[1]).positive? ? zahl(w[1]) : nil,
            ueberstand_vorn: zahl(w[2]), ueberstand_seite: zahl(w[3]), wandabstand: zahl(w[4]),
            fuge_hochschrank: zahl(w[5]), gehrungstiefe: zahl(w[8]), radius: zahl(w[9]), ecken: {} }
      o[:format] = case w[6]
                   when AUTO then nil
                   when EIGENES
                     masse = w[7].split(/\s*[x×*]\s*/i).map { |v| zahl(v) }
                     raise ArgumentError, "Format „#{w[7]}“: bitte Länge x Breite in mm" unless masse.size == 2 && masse.all?(&:positive?)
                     masse
                   else
                     Layout::STANDARDFORMATE.find { |f| format_text(f) == w[6] }
                   end
      erg[:ecken].each_with_index do |e, i|
        stoss = STOESSE.fetch(w[10 + 2 * i])
        durch = e[:zeilen].find { |nr| w[11 + 2 * i].start_with?("Zeile #{nr} ") }
        o[:ecken][e[:nr]] = { stoss: stoss, durchlaufend: durch }
      end
      o
    end

    # nil bei Abbruch
    def self.abfragen(erg, o = {}, titel = 'Arbeitsplatte')
      beschriftung, vorgabe, listen = felder(erg, o)
      werte = UI.inputbox(beschriftung, vorgabe, listen, titel)
      werte ? optionen(erg, werte) : nil
    end
  end
end
