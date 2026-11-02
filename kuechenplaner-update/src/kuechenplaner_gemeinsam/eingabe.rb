# encoding: UTF-8
#
# Küchenplaner – Eingabefenster im Stil des Treppenplaners (UI::HtmlDialog)
#
# Ersetzt UI.inputbox in allen Erweiterungen. Diese Datei liegt wortgleich in jeder
# Erweiterung unter src/kuechenplaner_gemeinsam/eingabe.rb; die Vorlage ist
# gemeinsam/eingabe.rb im Hauptordner, ./build_rbz.sh verteilt sie, der Test prüft das.
#
#   Kuechenplaner::Eingabe.abfragen(['Breite (mm)', 'Höhe (mm)'], ['600', '720'], 'Unterschrank mit Tür',
#                                   untertitel: 'Neuer Schrank', ok: 'Einfügen') do |werte|
#     # werte: Array von Strings wie bei UI.inputbox
#     raise ArgumentError, 'Breite zu klein' if werte[0].to_f < 100  # Fenster bleibt offen, Meldung unten
#   end
#
# Argumente wie UI.inputbox (prompts, defaults[, listen], titel), nur kommt das Ergebnis
# in den Block, weil HtmlDialog nicht wartet. Ein Fehler im Block (z. B. ArgumentError
# bei ungültiger Eingabe) lässt das Fenster mit den Eingaben offen und zeigt die Meldung.
# Beschriftungen wie bei UI.inputbox: „Breite (mm)“ zeigt „Breite“ mit Einheit mm,
# „Stärke (mm, 0 = Standard)“ zusätzlich den Hinweis „0 = Standard“. „Ecke 1: Stoß“
# kommt in die Gruppe „Ecke 1“. listen: 'a|b|c' wird eine Auswahl, '' ein Eingabefeld.
# Abbrechen oder Schließen ruft den Block nicht auf (wie nil/false bei UI.inputbox).
# Ohne UI::HtmlDialog (sehr alte SketchUp-Versionen) wird UI.inputbox benutzt.

require 'json'

module Kuechenplaner
  module Eingabe
    EINHEITEN = %w[mm cm m ° Stk %].freeze
    BREITE = 480

    # Aussehen wie die Dialoge im Treppenplaner (Farben, Schrift, Gruppen, Fußzeile mit Knöpfen)
    CSS = <<~CSS.freeze
      :root { --bg:#f4f2ee; --panel:#fff; --line:#d9d4ca; --text:#2a2723; --muted:#7a736a;
        --accent:#2f6fb3; --accent2:#245a92; --ok:#2e7d4f; --warn:#b26a00; --err:#b3261e; }
      * { box-sizing:border-box; }
      html, body { margin:0; height:100%; background:var(--bg); color:var(--text);
        font:13px/1.35 "Segoe UI", -apple-system, "Helvetica Neue", Arial, sans-serif; }
      body { display:flex; flex-direction:column; }
      header { padding:10px 16px; border-bottom:1px solid var(--line); background:var(--panel); display:flex; gap:12px; align-items:baseline; }
      header h1 { font-size:16px; margin:0; font-weight:600; }
      header .sub { color:var(--muted); }
      main { flex:1; min-height:0; overflow-y:auto; padding:10px 12px 12px; }
      fieldset { border:1px solid var(--line); border-radius:6px; background:var(--panel); margin:0 0 10px; padding:6px 10px 8px; }
      legend { font-weight:600; padding:0 4px; }
      .row { display:grid; grid-template-columns:1fr 170px; gap:8px; align-items:center; padding:4px 0; border-top:1px dashed #eee; }
      .row:first-of-type { border-top:0; }
      .row .ctl { display:flex; align-items:center; gap:4px; }
      .row input, .row select { width:100%; padding:4px 6px; border:1px solid #c8c2b7; border-radius:4px; font:inherit; background:#fff; }
      .row input.zahl { text-align:right; font-variant-numeric:tabular-nums; }
      .row input:focus, .row select:focus { outline:none; border-color:var(--accent); box-shadow:0 0 0 2px rgba(47,111,179,.18); }
      .unit { color:var(--muted); min-width:26px; font-size:12px; }
      .help { grid-column:1 / -1; color:var(--muted); font-size:11.5px; margin-top:-2px; }
      footer { border-top:1px solid var(--line); background:var(--panel); padding:8px 12px; display:flex; gap:8px; align-items:center; }
      footer .spacer { flex:1; }
      #status { color:var(--muted); }
      #status.err { color:var(--err); }
      button { font:inherit; padding:6px 14px; border-radius:4px; border:1px solid #b9b2a6; background:#fff; cursor:pointer; }
      button:hover { background:#f1eee9; }
      button.primary { background:var(--accent); color:#fff; border-color:var(--accent2); }
      button.primary:hover { background:var(--accent2); }
      button:disabled { opacity:.6; cursor:default; }
    CSS

    class << self
      # Das zuletzt geöffnete Fenster (für Tests)
      attr_reader :dialog

      def abfragen(prompts, defaults, *rest, untertitel: nil, ok: 'OK', gruppe: nil, &block)
        titel = rest.pop.to_s
        listen = rest.first || []
        unless defined?(UI::HtmlDialog)
          werte = UI.inputbox(prompts, defaults, *(listen.empty? ? [] : [listen]), titel)
          return werte ? block.call(werte) : nil
        end
        felder = felder(prompts, defaults, listen, gruppe)
        @dialog.close if @dialog && @dialog.visible?
        d = UI::HtmlDialog.new(dialog_title: titel, preferences_key: "Kuechenplaner_Eingabe_#{titel}",
                               scrollable: false, resizable: true, width: BREITE, height: hoehe(felder),
                               min_width: 380, min_height: 220, style: UI::HtmlDialog::STYLE_DIALOG)
        d.set_html(html(titel, untertitel, felder, ok))
        fertig = false
        d.add_action_callback('ok') do |_ctx, json|
          next if fertig # Doppelklick: nur einmal ausführen
          fertig = true
          begin
            block.call(JSON.parse(json.to_s))
            d.close
          rescue StandardError => e
            # Eingabe ungültig o. ä.: Fenster bleibt mit den Eingaben offen, Meldung unten links
            fertig = false
            text = e.is_a?(ArgumentError) ? "Ungültige Eingabe: #{e.message}" : "Fehler: #{e.message}"
            d.execute_script("KP.fehler(#{JSON.generate(text)})")
          end
        end
        d.add_action_callback('abbrechen') { |_ctx| d.close }
        d.center
        d.show
        @dialog = d
      end

      # [{ gruppe:, label:, einheit:, hilfe:, wert:, liste: }, …]
      def felder(prompts, defaults, listen, gruppe = nil)
        roh = prompts.each_with_index.map do |p, i|
          g, rest = p.to_s.split(/:\s+/, 2)
          g, rest = nil, p.to_s unless rest && g.size <= 40 && !g.include?('(')
          label, einheit, hilfe = beschriftung(rest)
          liste = listen[i].to_s.empty? ? nil : listen[i].to_s.split('|')
          { gruppe: g, label: label, einheit: einheit, hilfe: hilfe, wert: defaults[i].to_s, liste: liste }
        end
        standard = gruppe || (roh.all? { |f| f[:einheit] } ? 'Maße' : 'Einstellungen')
        roh.each { |f| f[:gruppe] ||= standard }
      end

      # "Stärke (mm, 0 = Standard 38/40)" -> ['Stärke', 'mm', '0 = Standard 38/40']
      def beschriftung(text)
        m = text.match(/\A(.*?)\s*\(([^()]*)\)\s*\z/)
        return [text, nil, nil] unless m
        teile = m[2].split(/,\s*/, 2)
        if EINHEITEN.include?(teile[0])
          [m[1], teile[0], teile[1]]
        else
          [m[1], nil, m[2]]
        end
      end

      def hoehe(felder)
        gruppen = felder.map { |f| f[:gruppe] }.uniq.size
        h = 145 + gruppen * 38 + felder.size * 33 + felder.count { |f| f[:hilfe] } * 16
        [[h, 240].max, 820].min
      end

      def h(text)
        text.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub('"', '&quot;')
      end

      def html(titel, untertitel, felder, ok)
        n = -1
        form = felder.chunk { |f| f[:gruppe] }.map do |g, fs|
          zeilen = fs.map do |f|
            n += 1
            ctl = if f[:liste]
                    opts = (f[:liste].include?(f[:wert]) ? f[:liste] : [f[:wert]] + f[:liste]).map do |o|
                      %(<option#{o == f[:wert] ? ' selected' : ''}>#{h(o)}</option>)
                    end
                    %(<select id="f#{n}">#{opts.join}</select>)
                  else
                    %(<input type="text" id="f#{n}" value="#{h(f[:wert])}"#{f[:einheit] ? ' class="zahl" inputmode="decimal"' : ''}>)
                  end
            einheit = f[:einheit] ? %(<span class="unit">#{h(f[:einheit])}</span>) : ''
            hilfe = f[:hilfe] ? %(<div class="help">#{h(f[:hilfe])}</div>) : ''
            %(<div class="row"><label for="f#{n}">#{h(f[:label])}</label><div class="ctl">#{ctl}#{einheit}</div>#{hilfe}</div>)
          end
          %(<fieldset><legend>#{h(g)}</legend>#{zeilen.join}</fieldset>)
        end
        <<~HTML
          <!DOCTYPE html>
          <html lang="de"><head><meta charset="utf-8"><title>#{h(titel)}</title>
          <style>#{CSS}</style></head>
          <body>
          <header><h1>#{h(titel)}</h1>#{untertitel ? %(<span class="sub">#{h(untertitel)}</span>) : ''}</header>
          <main>#{form.join}</main>
          <footer><span id="status"></span><span class="spacer"></span>
            <button id="ok" class="primary">#{h(ok)}</button><button id="abbrechen">Abbrechen</button></footer>
          <script>
          (function () {
            'use strict';
            var $ = function (id) { return document.getElementById(id); };
            var KP = window.KP = {
              n: #{felder.size},
              werte: function () { var w = []; for (var i = 0; i < this.n; i++) w.push($('f' + i).value); return w; },
              ok: function () { if ($('ok').disabled) return; $('ok').disabled = true; $('status').className = '';
                $('status').textContent = 'bitte warten …'; sketchup.ok(JSON.stringify(this.werte())); },
              fehler: function (t) { $('ok').disabled = false; $('status').className = 'err'; $('status').textContent = t; }
            };
            $('ok').onclick = function () { KP.ok(); };
            $('abbrechen').onclick = function () { sketchup.abbrechen(); };
            document.addEventListener('keydown', function (e) {
              if (e.key === 'Enter' && e.target.tagName !== 'BUTTON') { e.preventDefault(); KP.ok(); }
              if (e.key === 'Escape') sketchup.abbrechen();
            });
            var erstes = $('f0'); if (erstes) { erstes.focus(); if (erstes.select) erstes.select(); }
          })();
          </script>
          </body></html>
        HTML
      end
    end
  end unless defined?(Kuechenplaner::Eingabe)
end
