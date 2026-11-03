# encoding: UTF-8
# Schrank-CNC – Fenster „Materialien…“ (Material-Konfigurator, ersetzt die Materialien aus
# OpenCutList).
#
# Liste aller Platten und Anleimer aus Modell und Bibliothek, mit Neu, Bearbeiten und
# Löschen. Platten: Name, Verwendung (Korpus, Front, Rückwand), Farbe, Texturbild, Stärke,
# Plattenformat, Maserung, passender Anleimer. Anleimer: Name, Farbe, Dicke, Breite.
# Dazu „Maserrichtung…“ für die ausgewählten Teile. Die Formulare laufen über
# Kuechenplaner::Eingabe (Treppenplaner-Stil); die Liste ist ein eigenes HtmlDialog-Fenster
# mit demselben Aussehen. Die Daten liest und schreibt nur Materialien.

require 'json'

module JTools
  module SchrankCnc
    module Materialdialog
      module_function

      AUTO = '(automatisch)'.freeze

      def zahl(text, was)
        v = Float(text.to_s.tr(',', '.').strip)
        raise ArgumentError, "#{was} muss größer 0 sein" unless v > 0
        v
      rescue ArgumentError, TypeError => e
        raise e if e.message.include?('größer 0')
        raise ArgumentError, "#{was}: „#{text}“ ist keine Zahl"
      end

      def n(v)
        v = v.to_f.round(1)
        (v == v.to_i ? v.to_i : v).to_s.tr('.', ',')
      end

      # Daten eines Materials aus Modell oder Bibliothek (nil wenn unbekannt)
      def eintrag(model, name)
        m = model.materials[name]
        return Materialien.daten(m) if m && (Materialien.platte?(m) || Materialien.kante?(m))
        Materialien.bibliothek.find { |e| e['name'] == name }
      end

      # ------------------------------------------------------------------
      # Formulare
      # ------------------------------------------------------------------
      # Platte anlegen (name nil) oder bearbeiten; danach wird nach dem Speichern aufgerufen
      def platte_formular(model, name: nil, verwendung: 'Korpus', &danach)
        e = name ? eintrag(model, name) : nil
        e ||= { 'name' => verwendung == 'Front' ? 'Front ' : '', 'verwendung' => verwendung, 'farbe' => '#FFFFFF',
                'staerke' => 19.0, 'format' => Materialien::STANDARD_FORMAT, 'maserung' => false }
        kanten = Materialien.kanten(model).map { |k| k.name.to_s } +
                 Materialien.bibliothek.select { |x| x['typ'] == 'kante' }.map { |x| x['name'] }
        kanten = kanten.uniq.sort
        kante = e['kante'].to_s.empty? ? AUTO : e['kante']
        prompts = ['Name', 'Verwendung', 'Farbe (#RRGGBB oder R,G,B)', 'Texturbild (Datei, leer = nur Farbe)',
                   'Texturbreite (mm, Bildbreite in der Natur)',
                   'Platte: Stärke (mm)', 'Platte: Format Länge (mm)', 'Platte: Format Breite (mm)',
                   'Platte: Maserung (Faser in Plattenlänge)', 'Platte: Anleimer (automatisch = Anleimer <Dekor>)']
        format = e['format'] || Materialien::STANDARD_FORMAT
        defaults = [e['name'], e['verwendung'] || verwendung, e['farbe'].to_s, e['textur'].to_s, '1000',
                    n(e['staerke'] || 19), n(format[0]), n(format[1]), e['maserung'] ? 'Ja' : 'Nein', kante]
        listen = ['', Materialien::VERWENDUNGEN.join('|'), '', '', '', '', '', '', 'Ja|Nein', ([AUTO] + kanten).join('|')]
        titel = name ? "Platte „#{name}“ bearbeiten" : 'Neue Platte'
        Kuechenplaner::Eingabe.abfragen(prompts, defaults, listen, titel, untertitel: 'Materialien',
                                        ok: 'Speichern', gruppe: 'Material') do |w|
          staerke = zahl(w[5], 'Stärke')
          format = [zahl(w[6], 'Format Länge'), zahl(w[7], 'Format Breite')]
          model.start_operation('Material speichern', true)
          begin
            Materialien.holen(model, name) if name # aus der Bibliothek ins Modell, damit umbenannt werden kann
            Materialien.holen(model, w[9]) unless w[9] == AUTO
            Materialien.platte_setzen(model, name: w[0], verwendung: w[1], farbe: w[2], textur: w[3],
                                             textur_breite: w[4].to_s.tr(',', '.').to_f, staerke: staerke,
                                             format: format, maserung: w[8] == 'Ja',
                                             kante: w[9] == AUTO ? '' : w[9], alt: name)
            model.commit_operation
          rescue StandardError
            model.abort_operation
            raise
          end
          danach&.call
        end
      end

      def kante_formular(model, name: nil, &danach)
        e = (name && eintrag(model, name)) || { 'name' => 'Anleimer ', 'farbe' => '#FFFFFF', 'dicke' => 2.0, 'breite' => 23.0 }
        prompts = ['Name', 'Farbe (#RRGGBB oder R,G,B)', 'Dicke (mm, wird in Stückliste und TCN abgezogen)', 'Breite (mm)']
        defaults = [e['name'], e['farbe'].to_s, n(e['dicke']), n(e['breite'])]
        titel = name ? "Anleimer „#{name}“ bearbeiten" : 'Neuer Anleimer'
        Kuechenplaner::Eingabe.abfragen(prompts, defaults, titel, untertitel: 'Materialien', ok: 'Speichern',
                                                                  gruppe: 'Anleimer') do |w|
          dicke = zahl(w[2], 'Dicke')
          breite = zahl(w[3], 'Breite')
          model.start_operation('Anleimer speichern', true)
          begin
            Materialien.holen(model, name) if name
            Materialien.kante_setzen(model, name: w[0], farbe: w[1], dicke: dicke, breite: breite, alt: name)
            model.commit_operation
          rescue StandardError
            model.abort_operation
            raise
          end
          danach&.call
        end
      end

      def loeschen(model, name, &danach)
        frage = "„#{name}“ aus Modell und Bibliothek löschen?\n\nTeile mit diesem Material bekommen das Standardmaterial."
        return unless UI.messagebox(frage, MB_OKCANCEL) == IDOK
        model.start_operation('Material löschen', true)
        Materialien.loeschen(model, name)
        model.commit_operation
        danach&.call
      end

      # Maserrichtung der ausgewählten Teile (oder aller Teile der ausgewählten Schränke)
      def maserung_dialog(model = Sketchup.active_model)
        auswahl = model.selection.to_a
        teile = Schraenke.teile(model).select { |t| t.pfad.any? { |i| auswahl.include?(i) } }
        if teile.empty?
          UI.messagebox('Bitte zuerst Schränke oder einzelne Teile auswählen.')
          return
        end
        jetzt = teile.map { |t| t.jt('maserung').to_s }.uniq
        vorgabe = jetzt.size == 1 && !jetzt.first.empty? ? jetzt.first : Materialien::MASERUNGEN.first
        prompts = ['Maserrichtung (automatisch: Fronten senkrecht, sonst längere Seite)']
        Kuechenplaner::Eingabe.abfragen(prompts, [vorgabe], [Materialien::MASERUNGEN.join('|')],
                                        "Maserrichtung für #{teile.size} #{teile.size == 1 ? 'Teil' : 'Teile'}",
                                        untertitel: 'Materialien', ok: 'Übernehmen', gruppe: 'Maserung') do |w|
          model.start_operation('Maserrichtung', true)
          Materialien.maserung_setzen(teile, w[0])
          model.commit_operation
        end
      end

      # ------------------------------------------------------------------
      # Liste
      # ------------------------------------------------------------------
      # Zeilen für die Liste: Modell und Bibliothek zusammen, Platten zuerst
      def zeilen(model)
        im_modell = (Materialien.platten(model) + Materialien.kanten(model)).map { |m| Materialien.daten(m) }
        namen = im_modell.map { |e| e['name'] }
        bib = Materialien.bibliothek
        alle = im_modell.map { |e| e.merge('ort' => bib.any? { |b| b['name'] == e['name'] } ? 'Modell + Bibliothek' : 'Modell') } +
               bib.reject { |e| namen.include?(e['name']) }.map { |e| e.merge('ort' => 'Bibliothek') }
        alle.sort_by { |e| [e['typ'] == 'platte' ? 0 : 1, e['name']] }
      end

      def h(t)
        Kuechenplaner::Eingabe.h(t)
      end

      def html(model)
        z = zeilen(model)
        platten = z.select { |e| e['typ'] == 'platte' }
        kanten = z.select { |e| e['typ'] == 'kante' }
        knopf = lambda do |e|
          j = h(JSON.generate(e['name']))
          %(<button onclick="sketchup.bearbeiten(#{j})">Bearbeiten</button> <button onclick="sketchup.loeschen(#{j})">Löschen</button>)
        end
        farbe = ->(e) { %(<span class="fa" style="background:#{h(e['farbe'].to_s.empty? ? '#fff' : e['farbe'])}"></span>) }
        tp = platten.map do |e|
          f = e['format'] || []
          %(<tr><td>#{farbe.call(e)}#{h(e['name'])}</td><td>#{h(e['verwendung'])}</td><td class="z">#{n(e['staerke'])}</td>) +
            %(<td class="z">#{f.map { |v| n(v) }.join(' × ')}</td><td>#{e['maserung'] ? 'ja' : 'nein'}</td>) +
            %(<td>#{h(e['kante'].to_s.empty? ? 'automatisch' : e['kante'])}</td><td class="ort">#{h(e['ort'])}</td><td class="k">#{knopf.call(e)}</td></tr>)
        end
        tk = kanten.map do |e|
          %(<tr><td>#{farbe.call(e)}#{h(e['name'])}</td><td class="z">#{n(e['dicke'])}</td><td class="z">#{n(e['breite'])}</td>) +
            %(<td class="ort">#{h(e['ort'])}</td><td class="k">#{knopf.call(e)}</td></tr>)
        end
        leer = ->(n_sp, t) { %(<tr><td colspan="#{n_sp}" class="ort">#{t}</td></tr>) }
        <<~HTML
          <!DOCTYPE html>
          <html lang="de"><head><meta charset="utf-8"><title>Materialien</title>
          <style>#{Kuechenplaner::Eingabe.css}
            table { width:100%; border-collapse:collapse; }
            th, td { text-align:left; padding:4px 6px; border-top:1px dashed #eee; vertical-align:middle; }
            th { color:var(--muted); font-weight:600; border-top:0; }
            td.z { text-align:right; font-variant-numeric:tabular-nums; white-space:nowrap; }
            td.ort { color:var(--muted); font-size:12px; }
            td.k { white-space:nowrap; text-align:right; }
            td.k button { padding:2px 8px; }
            .fa { display:inline-block; width:12px; height:12px; border:1px solid #b9b2a6; border-radius:2px; margin-right:6px; vertical-align:-1px; }
          </style></head>
          <body>
          <header><h1>Materialien</h1><span class="sub">Platten und Anleimer für Stückliste, Zuschnitt und TCN</span></header>
          <main>
          <fieldset><legend>Platten</legend><table>
          <tr><th>Name</th><th>Verwendung</th><th>Stärke mm</th><th>Format mm</th><th>Maserung</th><th>Anleimer</th><th></th><th></th></tr>
          #{tp.empty? ? leer.call(8, 'noch keine Platten') : tp.join("\n")}
          </table></fieldset>
          <fieldset><legend>Anleimer</legend><table>
          <tr><th>Name</th><th>Dicke mm</th><th>Breite mm</th><th></th><th></th></tr>
          #{tk.empty? ? leer.call(5, 'noch keine Anleimer') : tk.join("\n")}
          </table></fieldset>
          </main>
          <footer><button onclick="sketchup.neu('platte')" class="primary">Neue Platte</button>
            <button onclick="sketchup.neu('kante')">Neuer Anleimer</button>
            <button onclick="sketchup.maserung()">Maserrichtung…</button>
            <span class="spacer"></span><span id="status">Gespeicherte Materialien stehen über die Bibliothek in jedem Modell bereit.</span>
            <button onclick="sketchup.schliessen()">Schließen</button></footer>
          </body></html>
        HTML
      end

      class << self
        attr_reader :liste # das offene Listenfenster (für Tests)
      end

      def aktualisieren(model)
        @liste.set_html(html(model)) if @liste && @liste.visible?
      end

      def bearbeiten(model, name)
        e = eintrag(model, name)
        return unless e
        neu_laden = -> { aktualisieren(model) }
        if e['typ'] == 'kante'
          kante_formular(model, name: name, &neu_laden)
        else
          platte_formular(model, name: name, &neu_laden)
        end
      end

      def dialog(model = Sketchup.active_model)
        unless defined?(UI::HtmlDialog)
          UI.messagebox('Das Fenster „Materialien“ braucht SketchUp 2017 oder neuer.')
          return
        end
        @liste.close if @liste && @liste.visible?
        d = UI::HtmlDialog.new(dialog_title: 'Materialien', preferences_key: 'Kuechenplaner_Materialien',
                               scrollable: false, resizable: true, width: 820, height: 560,
                               min_width: 560, min_height: 300, style: UI::HtmlDialog::STYLE_DIALOG)
        neu_laden = -> { aktualisieren(model) }
        d.add_action_callback('neu') do |_c, art|
          art == 'kante' ? kante_formular(model, &neu_laden) : platte_formular(model, &neu_laden)
        end
        d.add_action_callback('bearbeiten') { |_c, name| bearbeiten(model, name.to_s) }
        d.add_action_callback('loeschen') { |_c, name| loeschen(model, name.to_s, &neu_laden) }
        d.add_action_callback('maserung') { |_c| maserung_dialog(model) }
        d.add_action_callback('schliessen') { |_c| d.close }
        @liste = d
        d.set_html(html(model))
        d.center
        d.show
        d
      end
    end
  end
end
