# encoding: UTF-8
# Schrank-CNC – Beschlag-Katalog (Jürgen, 2026-11-06: „konfigurierbar, jede Beschlagart einmal
# für die ganze Küche“).
#
# Jedes Modell ist eine JSON-Datei in katalog/ (eine Datei je Modell). Sie nennt die Beschlagart
# (wo es gewählt wird, z. B. „klappe“) und die Bauart (welcher Rechenweg in Regeln, Beschlagliste
# und Beschlagmodell es auswertet) und enthält alle Zahlen: Bohrbild Korpus und Front mit
# Bezugskanten, Beschlagliste, vereinfachte Modellkörper, Einsatzbereich und Quelle.
# Ein neues Modell einer vorhandenen Bauart ist nur eine neue Datei.
#
# Gewählt wird je Beschlagart einmal für die ganze Küche (Küchenplaner › Einstellungen…,
# Abschnitt Beschläge), gespeichert im Modell im Wörterbuch Kuechenplaner_Einstellungen wie
# Sockelhöhe und Wandabstand; ein neues Modell übernimmt die zuletzt gewählten Beschläge dieses
# Rechners. Alte Küchen ohne Einstellung: ein Oberschrank mit Klappe, der noch die frühere
# Option Free Slim (Art_Klappe 3) trägt, behält Free Slim, bis die Einstellung gespeichert wird.

require 'json'

module JTools
  module SchrankCnc
    module Beschlagkatalog
      module_function

      DICT = 'Kuechenplaner_Einstellungen'.freeze
      SEKTION = 'Kuechenplaner_Einstellungen'.freeze
      ORDNER = File.join(__dir__, 'katalog')

      # Beschlagart => Bezeichnung im Dialog, Standardmodell, Bauarten, die sie annimmt
      ARTEN = {
        'topfband' => { name: 'Topfband (Türen)', standard: 'blum-clip-top', bauarten: %w[topfband_platte] },
        'klappe' => { name: 'Klappe (eine Klappe)', standard: 'blum-aventos-hk-top', bauarten: %w[klappe_seite] }
      }.freeze

      # Pflichtteile je Bauart (der Test prüft jeden Eintrag)
      PFLICHT = {
        'klappe_seite' => %w[seite front liste koerper],
        'topfband_platte' => %w[topf verteilung platte liste koerper]
      }.freeze

      # Frühere Klappen-Option im Oberschrank mit Klappe (Art_Klappe 3 = Free Slim)
      ALT_KLAPPE = { 3 => 'haefele-free-slim-1.12' }.freeze

      def eintraege
        @eintraege ||= Dir.glob(File.join(ORDNER, '*.json')).sort.map do |f|
          JSON.parse(File.read(f, encoding: 'UTF-8')).merge('datei' => File.basename(f))
        end
      end

      def neu_laden
        @eintraege = nil
      end

      def eintrag(kennung)
        eintraege.find { |e| e['kennung'] == kennung }
      end

      def zur_art(art)
        eintraege.select { |e| e['art'] == art }.sort_by { |e| e['name'] }
      end

      # Fehlerliste eines Eintrags (leer = in Ordnung)
      def fehler(e)
        f = []
        %w[kennung name hersteller art bauart quelle].each { |k| f << "#{k} fehlt" if e[k].to_s.strip.empty? }
        f << "Beschlagart #{e['art']} unbekannt" unless ARTEN.key?(e['art'])
        f << "Bauart #{e['bauart']} unbekannt" unless PFLICHT.key?(e['bauart'])
        (PFLICHT[e['bauart']] || []).each { |k| f << "#{k} fehlt" unless e[k] }
        f << "Datei #{e['datei']} passt nicht zur Kennung" if e['datei'] && e['datei'] != "#{e['kennung']}.json"
        f
      end

      def modell(model)
        model || (defined?(Sketchup) && Sketchup.respond_to?(:active_model) ? Sketchup.active_model : nil)
      end

      def schluessel(art)
        "beschlag_#{art}"
      end

      # Im Modell gespeicherte Wahl (Kennung) oder nil
      def gespeichert(art, model = nil)
        m = modell(model)
        k = m.get_attribute(DICT, schluessel(art)) if m.respond_to?(:get_attribute)
        k && eintrag(k) ? k : nil
      end

      # Gewähltes Modell (Eintrag) der Beschlagart für die ganze Küche:
      # Modell, sonst zuletzt auf diesem Rechner gewählt, sonst Standard
      def gewaehlt(art, model = nil)
        k = gespeichert(art, model)
        if k.nil? && defined?(Sketchup) && Sketchup.respond_to?(:read_default)
          v = Sketchup.read_default(SEKTION, schluessel(art), nil)
          k = v if v && eintrag(v)
        end
        eintrag(k || ARTEN.fetch(art)[:standard])
      end

      # Klappenmodell für einen Schrank (Übergang für alte Küchen, siehe oben)
      def klappe_fuer(schrank, model = nil)
        unless gespeichert('klappe', model)
          alt = ALT_KLAPPE[Schraenke.dc(schrank, 'art_klappe').to_f.round] if schrank
          return eintrag(alt) if alt
        end
        gewaehlt('klappe', model)
      end

      # Vorschlag im Dialog: gespeichert, sonst das Klappenmodell, das die meisten Schränke heute haben
      def vorschlag(art, model = nil)
        k = gespeichert(art, model)
        return eintrag(k) if k
        if art == 'klappe' && (m = modell(model)).respond_to?(:entities)
          alt = Schraenke.instanzen(m.entities).map { |s| ALT_KLAPPE[Schraenke.dc(s, 'art_klappe').to_f.round] }.compact
          return eintrag(alt.max_by { |a| alt.count(a) }) unless alt.empty?
        end
        gewaehlt(art, model)
      end

      def waehlen(art, kennung, model = nil)
        e = eintrag(kennung)
        raise ArgumentError, "Unbekannter Beschlag: #{kennung}" unless e && e['art'] == art
        m = modell(model)
        m.set_attribute(DICT, schluessel(art), kennung) if m.respond_to?(:set_attribute)
        Sketchup.write_default(SEKTION, schluessel(art), kennung) if defined?(Sketchup) && Sketchup.respond_to?(:write_default)
        e
      end

      # Für den Fingerabdruck der Beschläge im Modell: ändert sich mit jeder Wahl
      def fingerabdruck(model = nil)
        ARTEN.keys.map { |a| "#{a}=#{gespeichert(a, model)}" }.join(';')
      end

      # Passt das Modell zum Schrank? nil oder Hinweistext (Maße in mm)
      def hinweis(e, korpushoehe: nil, breite: nil)
        ein = e['einsatz'] || {}
        t = []
        { 'korpushoehe' => ['Korpushöhe', korpushoehe], 'breite' => ['Breite', breite] }.each do |k, (name, wert)|
          bereich = ein[k]
          next unless bereich && wert
          next if wert.round >= bereich[0] && wert.round <= bereich[1]
          t << "#{name} #{wert.round} mm (#{e['name']}: #{bereich[0]}–#{bereich[1]} mm)"
        end
        t.empty? ? nil : t.join(', ')
      end
    end
  end
end
