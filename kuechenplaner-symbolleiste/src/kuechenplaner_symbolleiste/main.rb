# encoding: UTF-8
# Küchenplaner – Symbolleiste
#
# Eine Symbolleiste „Küchenplaner“ mit wenigen Icons. Alle Schranktypen stecken
# hinter einem Icon „Schrank einfügen“: es öffnet eine Auswahl, gegliedert wie das
# Menü (Unter-, Ober-, Hochschränke). Jeder Schrank, der sich über
# Kuechenplaner.schrank ins Menü einträgt, erscheint dort automatisch.
# Die übrigen Icons rufen die Befehle der anderen Erweiterungen auf; fehlt eine
# Erweiterung, ist ihr Icon ausgegraut.
require 'sketchup.rb'

# Gemeinsames Untermenü "Erweiterungen > Küchenplaner" für alle Komponenten und
# den TCN-Export. Steht wortgleich in jeder Erweiterung (der Test prüft das), damit
# das Untermenü nur einmal angelegt wird, egal welche Erweiterungen geladen sind.
# Schränke kommen über Kuechenplaner.schrank('Unterschränke' | 'Oberschränke' |
# 'Hochschränke', titel) ins Menü und in die Schrank-Auswahl der Symbolleiste,
# Geräte und Raum in Kuechenplaner.untermenu('Geräte' | 'Raum'), Werkzeuge direkt in Kuechenplaner.menu darunter.
module Kuechenplaner
  GRUPPEN = ['Unterschränke', 'Oberschränke', 'Hochschränke', 'Geräte', 'Raum'].freeze

  def self.menu
    @menu ||= UI.menu('Extensions').add_submenu('Küchenplaner')
  end

  # Alle Gruppen beim ersten Aufruf anlegen, damit die Reihenfolge nicht von der
  # Ladereihenfolge der Erweiterungen abhängt.
  def self.untermenu(gruppe)
    @untermenues ||= GRUPPEN.each_with_object({}) { |g, h| h[g] = menu.add_submenu(g) }
    @untermenues.fetch(gruppe)
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
end unless defined?(Kuechenplaner.schrank)

module KuechenplanerSymbolleiste
  ICONS = File.join(File.dirname(__FILE__), 'icons').freeze
  NAME  = 'Küchenplaner'.freeze
  SCHRANK_GRUPPEN = { 'Unterschränke' => 'unterschrank', 'Oberschränke' => 'oberschrank', 'Hochschränke' => 'hochschrank' }.freeze
  # Befehle der Erweiterung „Raum“ (Komponenten/raum): [Titel, Methode von ::Raum]
  RAUM = [['Raum anlegen', :raum_anlegen_dialog], ['Wände aus Linien', :waende_aus_linien],
          ['Fenster/Tür einsetzen', :einsetzen_dialog], ['Öffnung bearbeiten', :oeffnung_bearbeiten_dialog],
          ['Raum bearbeiten', :raum_bearbeiten_dialog]].freeze

  # [Icon, Titel, Hilfetext, verfügbar?, Aktion]
  BEFEHLE = [
    ['schrank', 'Schrank einfügen', 'Schranktyp auswählen und einfügen (Unter-, Ober- und Hochschränke)',
     -> { !Kuechenplaner.schraenke.empty? }, -> { KuechenplanerSymbolleiste.schrank_auswahl }],
    ['andocken', 'Schrank andocken', 'Gewählten Schrank an einen Nachbarschrank oder eine Wand andocken',
     -> { defined?(JTools::SchrankCnc::Andocken) }, -> { JTools::SchrankCnc::Andocken.starten }],
    ['arbeitsplatte', 'Arbeitsplatte', 'Arbeitsplatte über den Unterschränken erzeugen; ist eine Arbeitsplatte gewählt, wird sie neu berechnet',
     -> { defined?(::Arbeitsplatte) }, -> { KuechenplanerSymbolleiste.arbeitsplatte }],
    ['raum', 'Raum', 'Raum anlegen und bearbeiten: Wände, Fenster, Türen, Durchgänge',
     -> { defined?(::Raum) }, -> { KuechenplanerSymbolleiste.raum_auswahl }],
    ['frontfarbe', 'Frontfarbe und Griffe', 'Frontfarbe und Griffe der gewählten Schränke ändern',
     -> { defined?(JTools::SchrankCnc::Frontfarbe) }, -> { JTools::SchrankCnc::Frontfarbe.dialog }],
    ['tcn', 'TCN exportieren', 'CNC-Programme (TCN) für die Schränke exportieren',
     -> { defined?(JTools::SchrankCnc::Export) }, -> { JTools::SchrankCnc::Export.dialog }]
  ].freeze

  class << self
    # Windows: SVG (scharf in jeder Größe); Mac kann kein SVG, dort PNG
    def icon(name)
      File.join(ICONS, "#{name}.#{Sketchup.platform == :platform_osx ? 'png' : 'svg'}")
    end

    def befehl(icon, titel, hilfe, verfuegbar, aktion)
      cmd = UI::Command.new(titel) { aktion.call }
      cmd.small_icon = cmd.large_icon = icon(icon)
      cmd.tooltip = titel
      cmd.status_bar_text = hilfe
      cmd.set_validation_proc { verfuegbar.call ? MF_ENABLED : MF_GRAYED }
      cmd
    end

    def symbolleiste
      @symbolleiste ||= begin
        tb = UI::Toolbar.new(NAME)
        BEFEHLE.each { |b| tb.add_item(befehl(*b)) }
        # Beim ersten Start einblenden, danach so, wie der Benutzer sie verlassen hat
        tb.get_last_state == TB_NEVER_SHOWN ? tb.show : tb.restore
        tb
      end
    end

    # Ist eine Arbeitsplatte gewählt: neu berechnen, sonst neue erzeugen
    def arbeitsplatte(model = Sketchup.active_model)
      gewaehlt = !model.selection.to_a.empty? && !::Arbeitsplatte::Ausgabe.arbeitsplatten(model).empty?
      gewaehlt ? ::Arbeitsplatte.neu_berechnen(model) : ::Arbeitsplatte.erzeugen(model)
    end

    # ---------- Auswahl-Fenster ----------

    # Schränke aus dem Menü, gegliedert nach Unter-, Ober- und Hochschränken
    def schrank_auswahl
      gruppen = SCHRANK_GRUPPEN.map do |gruppe, bild|
        eintraege = Kuechenplaner.schraenke.select { |g, _, _| g == gruppe }.sort_by { |_, t, _| t.downcase }
        [gruppe, bild, eintraege.map { |_, t, aktion| [t.sub(/…\z/, ''), aktion] }]
      end
      auswahl('Schrank einfügen', gruppen)
    end

    def raum_auswahl
      eintraege = RAUM.select { |_, m| ::Raum.respond_to?(m) }.map { |t, m| [t, -> { ::Raum.public_send(m) }] }
      auswahl('Raum', [['Raum', 'raum', eintraege]])
    end

    # gruppen: [[Überschrift, Bild, [[Titel, Aktion], …]], …]
    def auswahl(titel, gruppen)
      @dialog.close if @dialog && @dialog.visible?
      @aktionen = []
      d = UI::HtmlDialog.new(dialog_title: titel, preferences_key: "Kuechenplaner_Auswahl_#{titel}",
                             width: 560, height: 420, resizable: true, style: UI::HtmlDialog::STYLE_DIALOG)
      d.set_html(html(gruppen))
      d.add_action_callback('waehlen') { |_ctx, i| waehlen(i.to_i) }
      d.add_action_callback('schliessen') { |_ctx| d.close }
      d.center
      d.show
      @dialog = d
    end

    # Dialog schließen, dann die Aktion wie aus dem Menü (z. B. Maße abfragen, erzeugen,
    # andocken) – per Timer, damit deren Eingabefenster nicht im HTML-Dialog hängt
    def waehlen(i)
      aktion = (@aktionen || [])[i] or return
      @dialog.close if @dialog
      UI.start_timer(0, false) { aktion.call }
    end

    def html(gruppen)
      teile = gruppen.map do |gruppe, bild, eintraege|
        next if eintraege.empty?
        svg = File.read(File.join(ICONS, "#{bild}.svg"), encoding: 'UTF-8').strip
        knoepfe = eintraege.map do |titel, aktion|
          @aktionen << aktion
          %(<button onclick="sketchup.waehlen(#{@aktionen.size - 1})">#{svg}<span>#{h(titel)}</span></button>)
        end
        %(<section><h2>#{h(gruppe)}</h2><div class="raster">#{knoepfe.join}</div></section>)
      end
      <<~HTML
        <!DOCTYPE html><html lang="de"><head><meta charset="utf-8"><style>
        body{font:13px "Segoe UI",Helvetica,Arial,sans-serif;margin:12px;background:#fafafa;color:#222}
        h2{font-size:13px;margin:10px 0 6px;color:#555;text-transform:uppercase;letter-spacing:.04em}
        .raster{display:grid;grid-template-columns:repeat(auto-fill,minmax(120px,1fr));gap:8px}
        button{display:flex;flex-direction:column;align-items:center;gap:6px;padding:10px 6px;border:1px solid #ccc;
          border-radius:6px;background:#fff;cursor:pointer;font:inherit;color:inherit}
        button:hover,button:focus{border-color:#2e7d32;background:#eef6ee;outline:none}
        button svg{width:40px;height:40px}
        </style></head><body>#{teile.compact.join}
        <script>document.addEventListener('keydown',function(e){if(e.key==='Escape')sketchup.schliessen()})</script>
        </body></html>
      HTML
    end

    def h(text)
      text.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub('"', '&quot;')
    end
  end

  unless file_loaded?(__FILE__)
    symbolleiste
    file_loaded(__FILE__)
  end
end
