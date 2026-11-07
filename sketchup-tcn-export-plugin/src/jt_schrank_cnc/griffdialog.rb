# encoding: UTF-8
# Schrank-CNC – Fenster „Griffkatalog“ (Küchenplaner › Griffkatalog…): alle Serien des Griffkatalogs mit
# Bild aus dem Katalog, Bauart, Lochabständen, Oberflächen und Artikelnummern. „Für diese Küche wählen“
# setzt Griffserie und Oberfläche der Küche (Griffkatalog.waehlen); danach bekommen alle Fronten
# automatisch Griffe in der vorgeschlagenen Größe (je Schrank änderbar über „Beschläge und Griffe der
# gewählten Schränke…“). „Keine Serie“ schaltet das wieder ab (Griffe nur von Hand).

require 'json'
require 'tmpdir'

module JTools
  module SchrankCnc
    module Griffdialog
      module_function

      def h(text)
        text.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub('"', '&quot;')
      end

      def datei_url(pfad)
        'file:///' + File.expand_path(pfad).tr('\\', '/').sub(%r{\A/+}, '').split('/').map do |t|
          t =~ /\A[A-Za-z]:\z/ ? t : t.gsub(/[^A-Za-z0-9._~-]/) { |c| c.bytes.map { |b| format('%%%02X', b) }.join }
        end.join('/')
      end

      # Tabelle der Größen einer Oberfläche
      def tabelle(s, o)
        zeilen = o['groessen'].map do |g|
          la = g['lochabstand'] ? g['lochabstand'].map { |v| Griffkatalog.zahl(v) }.join(' / ') : '–'
          aus = g['ausfuehrung'] ? " #{g['ausfuehrung']}" : ''
          "<tr><td>#{Griffkatalog.zahl(g['laenge'])} × #{Griffkatalog.zahl(g['hoehe'])}#{h(aus)}</td><td>#{la}</td><td>#{h(g['artikel'])}</td></tr>"
        end
        kopf = Griffkatalog.knopf?(s) ? 'Ø × Höhe' : 'Länge × Höhe'
        "<table data-o=\"#{h(o['name'])}\"><tr><th>#{kopf} (mm)</th><th>Lochabstand</th><th>Artikel-Nr.</th></tr>#{zeilen.join}</table>"
      end

      def karte(s, gewaehlt, ob, bild_url)
        la = Griffkatalog.knopf?(s) ? 'Knopf, eine Schraube' : "Lochabstand #{Griffkatalog.lochabstaende(s).map { |v| Griffkatalog.zahl(v) }.join(' / ')} mm"
        opts = Griffkatalog.oberflaechen(s).map do |o|
          "<option#{gewaehlt && o == ob ? ' selected' : ''}>#{h(o)}</option>"
        end.join
        tabellen = s['oberflaechen'].map { |o| tabelle(s, o) }.join
        <<~HTML
          <div class="karte#{gewaehlt ? ' gewaehlt' : ''}" data-k="#{h(s['kennung'])}" data-b="#{h(s['bauart'])}">
            <img src="#{h(bild_url.call(s))}" alt="#{h(s['kennung'])}" onclick="gross(this.src)">
            <div class="kopf"><b>#{h(s['kennung'])}</b> <span>#{Griffkatalog.knopf?(s) ? 'Knopf' : 'Griff'}</span></div>
            <div class="la">#{h(la)}</div>
            <select onchange="zeig(this)">#{opts}</select>
            <details><summary>Größen und Artikel-Nr.</summary>#{tabellen}</details>
            <div class="quelle">#{h(s['hersteller'])} · Katalogseite #{s['seite']}</div>
            <button onclick="waehle(this)">#{gewaehlt ? 'Gewählt ✓' : 'Für diese Küche wählen'}</button>
          </div>
        HTML
      end

      def html(model = nil, bild_url: ->(s) { datei_url(Griffkatalog.bild(s)) })
        k = Griffkatalog.kueche(model)
        ob = Griffkatalog.oberflaeche(model)
        stand = k ? "Küche: <b>#{h(k['kennung'])}</b>, #{h(ob)}" : 'Küche: keine Griffserie (Griffe nur von Hand)'
        karten = Griffkatalog.serien.map { |s| karte(s, k && k['kennung'] == s['kennung'], ob, bild_url) }.join
        <<~HTML
          <!DOCTYPE html><html lang="de"><head><meta charset="utf-8"><title>Griffkatalog</title>
          <style>#{defined?(Kuechenplaner::Eingabe) ? Kuechenplaner::Eingabe.css : ''}
            header { flex-wrap:wrap; position:sticky; top:0; z-index:2; }
            header .stand { flex-basis:100%; }
            header input, header select { padding:4px 6px; }
            .gitter { flex:1; min-height:0; overflow-y:auto; display:grid; grid-template-columns:repeat(auto-fill, minmax(230px, 1fr)); gap:12px; padding:14px; align-content:start; }
            .karte { background:var(--panel); border:1px solid var(--line); border-radius:6px; padding:8px; display:flex; flex-direction:column; gap:5px; }
            .karte.gewaehlt { border:2px solid var(--accent); }
            .karte img { width:100%; height:200px; object-fit:contain; background:#eee; cursor:zoom-in; border-radius:4px; }
            .kopf b { font-size:15px; } .kopf span, .la, .quelle { color:var(--muted); }
            details table { width:100%; border-collapse:collapse; font-size:12px; margin-top:4px; }
            td, th { border-bottom:1px solid var(--line); padding:2px 3px; text-align:left; }
            button { padding:5px 8px; border:1px solid var(--accent); background:var(--accent); color:#fff; border-radius:4px; cursor:pointer; }
            .gewaehlt button { background:var(--panel); color:var(--accent); }
            #gross { display:none; position:fixed; inset:0; background:rgba(0,0,0,.75); z-index:5; align-items:center; justify-content:center; }
            #gross img { max-width:95%; max-height:95%; background:#fff; }
          </style></head><body>
          <header><div class="stand" id="stand">#{stand}</div>
            <input id="suche" placeholder="Suchen (Kennung, Oberfläche)" oninput="filter()">
            <select id="art" onchange="filter()"><option value="">Griffe und Knöpfe</option><option value="griff">nur Griffe</option><option value="knopf">nur Knöpfe</option></select>
            <button onclick="keine()">Keine Serie (Griffe von Hand)</button>
          </header>
          <div class="gitter">#{karten}</div>
          <div id="gross" onclick="this.style.display='none'"><img></div>
          <script>
            function zeig(sel) { var k = sel.closest('.karte'); k.querySelectorAll('table').forEach(function (t) { t.style.display = t.dataset.o === sel.value ? '' : 'none'; }); }
            document.querySelectorAll('.karte select').forEach(zeig);
            function filter() {
              var q = document.getElementById('suche').value.toLowerCase(), a = document.getElementById('art').value;
              document.querySelectorAll('.karte').forEach(function (k) {
                var ok = (!a || k.dataset.b === a) && (!q || k.textContent.toLowerCase().indexOf(q) >= 0);
                k.style.display = ok ? '' : 'none';
              });
            }
            function gross(src) { var g = document.getElementById('gross'); g.querySelector('img').src = src; g.style.display = 'flex'; }
            function waehle(b) { var k = b.closest('.karte'); sketchup.waehlen(k.dataset.k, k.querySelector('select').value); }
            function keine() { sketchup.waehlen('', ''); }
            function gewaehlt(k, text) {
              document.getElementById('stand').innerHTML = text;
              document.querySelectorAll('.karte').forEach(function (c) {
                var ja = c.dataset.k === k; c.classList.toggle('gewaehlt', ja);
                c.querySelector('button').textContent = ja ? 'Gewählt ✓' : 'Für diese Küche wählen';
              });
            }
          </script></body></html>
        HTML
      end

      # Wahl übernehmen (aus dem Fenster): Serie der Küche setzen und Griffe neu zeichnen
      def waehlen(model, kennung, oberflaeche)
        model.start_operation('Griffserie wählen', true)
        Griffkatalog.waehlen(kennung.to_s.empty? ? nil : kennung, oberflaeche, model)
        Griffmodell.aktualisieren(model)
        model.commit_operation
      rescue StandardError
        model.abort_operation
        raise
      end

      def zeigen(model = Sketchup.active_model)
        @dialog.close if @dialog && @dialog.visible?
        d = UI::HtmlDialog.new(dialog_title: 'Griffkatalog', preferences_key: 'Kuechenplaner_Griffkatalog',
                               scrollable: true, resizable: true, width: 1100, height: 800, style: UI::HtmlDialog::STYLE_DIALOG)
        datei = File.join(Dir.tmpdir, 'kuechenplaner_griffkatalog.html')
        File.write(datei, html(model), encoding: 'UTF-8')
        d.set_file(datei)
        d.add_action_callback('waehlen') do |_ctx, kennung, oberflaeche|
          begin
            waehlen(model, kennung, oberflaeche)
            k = Griffkatalog.kueche(model)
            text = k ? "Küche: <b>#{h(k['kennung'])}</b>, #{h(Griffkatalog.oberflaeche(model))}" : 'Küche: keine Griffserie (Griffe nur von Hand)'
            d.execute_script("gewaehlt(#{JSON.generate(k ? k['kennung'] : '')}, #{JSON.generate(text)})")
          rescue StandardError => e
            UI.messagebox("Fehler: #{e.message}")
          end
        end
        d.center
        d.show
        @dialog = d
      end
    end
  end
end
