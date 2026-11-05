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
# Besondere Felder über listen: ':farbe' zeigt einen Farbwähler (Farbrad mit Helligkeitsregler,
# Vorschau, Wert als #RRGGBB), ':datei' ein Eingabefeld mit Knopf „Datei wählen…“ (Bilder),
# ':programm' ebenso für ein Programm (z. B. blender.exe), ':speichern' mit „Speichern unter…“.
# Abbrechen oder Schließen ruft den Block nicht auf (wie nil/false bei UI.inputbox).
# Ohne UI::HtmlDialog (sehr alte SketchUp-Versionen) wird UI.inputbox benutzt.
# main.rb lädt die Datei mit require (einmal je Sitzung); „Plugins aktualisieren“
# lädt sie neu, wenn sie sich geändert hat.

require 'json'

module Kuechenplaner
  module Eingabe
    # Keine Konstanten: „Plugins aktualisieren“ lädt diese Datei neu, ohne Warnungen
    def self.einheiten
      %w[mm cm m ° Stk %]
    end

    # Feldarten über listen
    def self.arten
      { ':farbe' => :farbe, ':datei' => :datei, ':programm' => :programm, ':speichern' => :speichern }
    end

    # Aussehen wie die Dialoge im Treppenplaner (Farben, Schrift, Gruppen, Fußzeile mit Knöpfen)
    def self.css
      <<~CSS
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
        .row .ctl .muster { flex:0 0 22px; height:22px; border:1px solid #c8c2b7; border-radius:4px; }
        .row .ctl button.datei { padding:3px 8px; white-space:nowrap; }
        .farbwahl { grid-column:1 / -1; display:flex; gap:12px; align-items:center; padding:4px 0 2px; }
        .farbwahl canvas { cursor:crosshair; touch-action:none; }
        .farbwahl .hell { border:1px solid #c8c2b7; border-radius:3px; cursor:ns-resize; }
      CSS
    end

    class << self
      # Das zuletzt geöffnete Fenster (für Tests)
      attr_reader :dialog

      def abfragen(prompts, defaults, *rest, untertitel: nil, ok: 'OK', gruppe: nil, &block)
        titel = rest.pop.to_s
        listen = rest.first || []
        unless defined?(UI::HtmlDialog)
          listen = listen.map { |l| arten.key?(l.to_s) ? '' : l }
          werte = UI.inputbox(prompts, defaults, *(listen.empty? ? [] : [listen]), titel)
          return werte ? block.call(werte) : nil
        end
        felder = felder(prompts, defaults, listen, gruppe)
        @dialog.close if @dialog && @dialog.visible?
        d = UI::HtmlDialog.new(dialog_title: titel, preferences_key: "Kuechenplaner_Eingabe_#{titel}",
                               scrollable: false, resizable: true, width: 480, height: hoehe(felder),
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
        d.add_action_callback('datei') do |_ctx, n, art, wert|
          pfad = datei_waehlen(art.to_s, wert.to_s)
          d.execute_script("KP.setze(#{n.to_i}, #{JSON.generate(pfad.to_s.tr('\\', '/'))})") if pfad
        end
        d.center
        d.show
        @dialog = d
      end

      # Dateiauswahl je Feldart: Bild öffnen, Programm wählen oder Speichern unter
      def datei_waehlen(art, wert = '')
        ordner = wert.empty? ? '' : File.dirname(wert)
        case art
        when 'programm'
          UI.openpanel('Programm wählen', ordner, 'Programme|*.exe;*.app;blender;Blender||')
        when 'speichern'
          UI.savepanel('Speichern unter', ordner, wert.empty? ? '' : File.basename(wert))
        else
          UI.openpanel('Datei wählen', '', 'Bilder|*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff;*.tga||')
        end
      end

      # [{ gruppe:, label:, einheit:, hilfe:, wert:, liste: }, …]
      def felder(prompts, defaults, listen, gruppe = nil)
        roh = prompts.each_with_index.map do |p, i|
          g, rest = p.to_s.split(/:\s+/, 2)
          g, rest = nil, p.to_s unless rest && g.size <= 40 && !g.include?('(')
          label, einheit, hilfe = beschriftung(rest)
          art = arten[listen[i].to_s]
          liste = (art || listen[i].to_s.empty?) ? nil : listen[i].to_s.split('|')
          { gruppe: g, label: label, einheit: einheit, hilfe: hilfe, wert: defaults[i].to_s, liste: liste, art: art }
        end
        standard = gruppe || (roh.all? { |f| f[:einheit] } ? 'Maße' : 'Einstellungen')
        roh.each { |f| f[:gruppe] ||= standard }
      end

      # "Stärke (mm, 0 = Standard 38/40)" -> ['Stärke', 'mm', '0 = Standard 38/40']
      def beschriftung(text)
        m = text.match(/\A(.*?)\s*\(([^()]*)\)\s*\z/)
        return [text, nil, nil] unless m
        teile = m[2].split(/,\s*/, 2)
        if einheiten.include?(teile[0])
          [m[1], teile[0], teile[1]]
        else
          [m[1], nil, m[2]]
        end
      end

      def hoehe(felder)
        gruppen = felder.map { |f| f[:gruppe] }.uniq.size
        h = 145 + gruppen * 38 + felder.size * 33 + felder.count { |f| f[:hilfe] } * 16 +
            felder.count { |f| f[:art] == :farbe } * 135
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
            extra = ''
            case f[:art]
            when :farbe
              # Eingabefeld zuerst (Tests lesen den Wert dort), dann Vorschau und Farbrad
              ctl += %(<span class="muster" id="f#{n}_muster"></span>)
              extra = %(<div class="farbwahl" data-feld="#{n}"><canvas id="f#{n}_rad" width="124" height="124"></canvas>) +
                      %(<canvas class="hell" id="f#{n}_hell" width="18" height="124"></canvas></div>)
            when :datei, :programm, :speichern
              ctl += %(<button type="button" class="datei" title="Datei wählen" ) +
                     %(onclick="sketchup.datei(#{n}, '#{f[:art]}', document.getElementById('f#{n}').value)">…</button>)
            end
            %(<div class="row"><label for="f#{n}">#{h(f[:label])}</label><div class="ctl">#{ctl}#{einheit}</div>#{hilfe}#{extra}</div>)
          end
          %(<fieldset><legend>#{h(g)}</legend>#{zeilen.join}</fieldset>)
        end
        <<~HTML
          <!DOCTYPE html>
          <html lang="de"><head><meta charset="utf-8"><title>#{h(titel)}</title>
          <style>#{css}</style></head>
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
              fehler: function (t) { $('ok').disabled = false; $('status').className = 'err'; $('status').textContent = t; },
              setze: function (n, wert) { var e = $('f' + n); e.value = wert; e.dispatchEvent(new Event('input')); }
            };
            // Farbwähler: Farbrad (Farbton, Sättigung) und Helligkeitsregler, Wert als #RRGGBB im Feld
            var hex2 = function (v) { var s = Math.round(v).toString(16).toUpperCase(); return s.length < 2 ? '0' + s : s; };
            var hsv2rgb = function (h, s, v) {
              var i = Math.floor(h * 6) % 6, f = h * 6 - Math.floor(h * 6), p = v * (1 - s), q = v * (1 - f * s), t = v * (1 - (1 - f) * s);
              var r = [[v, t, p], [q, v, p], [p, v, t], [p, q, v], [t, p, v], [v, p, q]][i];
              return [r[0] * 255, r[1] * 255, r[2] * 255];
            };
            var rgb2hsv = function (r, g, b) {
              r /= 255; g /= 255; b /= 255;
              var mx = Math.max(r, g, b), mn = Math.min(r, g, b), d = mx - mn, h = 0;
              if (d > 0) h = mx === r ? ((g - b) / d + 6) % 6 : mx === g ? (b - r) / d + 2 : (r - g) / d + 4;
              return [h / 6, mx === 0 ? 0 : d / mx, mx];
            };
            var lesen = function (t) {
              var m = String(t).trim().match(/^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i);
              if (m) return [parseInt(m[1], 16), parseInt(m[2], 16), parseInt(m[3], 16)];
              m = String(t).trim().match(/^(\d{1,3})\s*[,; ]\s*(\d{1,3})\s*[,; ]\s*(\d{1,3})$/);
              return m ? [+m[1], +m[2], +m[3]].map(function (x) { return Math.min(255, x); }) : null;
            };
            Array.prototype.forEach.call(document.querySelectorAll('.farbwahl'), function (box) {
              var n = box.getAttribute('data-feld'), feld = $('f' + n), rad = $('f' + n + '_rad'), hell = $('f' + n + '_hell');
              var muster = $('f' + n + '_muster'), cr = rad.getContext('2d'), ch = hell.getContext('2d');
              var R = rad.width / 2, hsv = [0, 0, 1];
              var zeichnen = function () {
                var bild = cr.createImageData(rad.width, rad.height), d = bild.data;
                for (var y = 0; y < rad.height; y++) for (var x = 0; x < rad.width; x++) {
                  var dx = x - R + 0.5, dy = y - R + 0.5, r = Math.sqrt(dx * dx + dy * dy), k = (y * rad.width + x) * 4;
                  if (r > R) continue;
                  var c = hsv2rgb((Math.atan2(-dy, dx) / (2 * Math.PI) + 1) % 1, r / R, hsv[2]);
                  d[k] = c[0]; d[k + 1] = c[1]; d[k + 2] = c[2]; d[k + 3] = r > R - 1 ? 255 * (R - r) : 255;
                }
                cr.putImageData(bild, 0, 0);
                var a = hsv[0] * 2 * Math.PI, mx = R + Math.cos(a) * hsv[1] * R, my = R - Math.sin(a) * hsv[1] * R;
                cr.strokeStyle = hsv[2] > 0.5 ? '#000' : '#fff'; cr.lineWidth = 1.5; cr.strokeRect(mx - 3.5, my - 3.5, 7, 7);
                var voll = hsv2rgb(hsv[0], hsv[1], 1), gr = ch.createLinearGradient(0, 0, 0, hell.height);
                gr.addColorStop(0, 'rgb(' + voll.map(Math.round).join(',') + ')'); gr.addColorStop(1, '#000');
                ch.fillStyle = gr; ch.fillRect(0, 0, hell.width, hell.height);
                var hy = (1 - hsv[2]) * (hell.height - 1);
                ch.fillStyle = hsv[2] > 0.5 ? '#000' : '#fff'; ch.fillRect(0, hy - 1, hell.width, 3);
                muster.style.background = feld.value;
              };
              var schreiben = function () {
                var c = hsv2rgb(hsv[0], hsv[1], hsv[2]);
                feld.value = '#' + hex2(c[0]) + hex2(c[1]) + hex2(c[2]); zeichnen();
              };
              var ausFeld = function () { var c = lesen(feld.value); if (c) { hsv = rgb2hsv(c[0], c[1], c[2]); } zeichnen(); };
              var ziehen = function (el, fn) {
                var aktiv = false;
                el.addEventListener('pointerdown', function (e) { aktiv = true; el.setPointerCapture(e.pointerId); fn(e); });
                el.addEventListener('pointermove', function (e) { if (aktiv) fn(e); });
                el.addEventListener('pointerup', function () { aktiv = false; });
              };
              ziehen(rad, function (e) {
                var b = rad.getBoundingClientRect(), dx = e.clientX - b.left - R, dy = e.clientY - b.top - R;
                hsv[0] = (Math.atan2(-dy, dx) / (2 * Math.PI) + 1) % 1; hsv[1] = Math.min(1, Math.sqrt(dx * dx + dy * dy) / R);
                if (hsv[2] < 0.05) hsv[2] = 1;
                schreiben();
              });
              ziehen(hell, function (e) {
                var b = hell.getBoundingClientRect();
                hsv[2] = Math.max(0, Math.min(1, 1 - (e.clientY - b.top) / b.height)); schreiben();
              });
              feld.addEventListener('input', ausFeld);
              ausFeld();
            });
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
  end
end
