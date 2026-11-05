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
require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'eingabe') # Eingabefenster im Treppenplaner-Stil

# Gemeinsames Untermenü "Erweiterungen > Küchenplaner" für alle Komponenten und
# den TCN-Export. Steht wortgleich in jeder Erweiterung (der Test prüft das), damit
# das Untermenü nur einmal angelegt wird, egal welche Erweiterungen geladen sind.
# Schränke kommen über Kuechenplaner.schrank('Unterschränke' | 'Oberschränke' |
# 'Hochschränke' | 'Blenden & Wangen', titel) ins Menü und in die Schrank-Auswahl der Symbolleiste,
# Geräte und Raum in Kuechenplaner.untermenu('Geräte' | 'Raum'), Werkzeuge direkt in Kuechenplaner.menu darunter.
module Kuechenplaner
  GRUPPEN = ['Unterschränke', 'Oberschränke', 'Hochschränke', 'Blenden & Wangen', 'Geräte', 'Raum'].freeze

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
  SCHRANK_GRUPPEN = { 'Unterschränke' => 'unterschrank', 'Oberschränke' => 'oberschrank', 'Hochschränke' => 'hochschrank',
                      'Blenden & Wangen' => 'blende' }.freeze
  # Befehle der Erweiterung „Raum“ (Komponenten/raum): [Titel, Methode von ::Raum]
  RAUM = [['Raum anlegen', :raum_anlegen_dialog], ['Wände aus Linien', :waende_aus_linien],
          ['Fenster/Tür einsetzen', :einsetzen_dialog], ['Öffnung bearbeiten', :oeffnung_bearbeiten_dialog],
          ['Raum bearbeiten', :raum_bearbeiten_dialog]].freeze

  # [Icon, Titel, Hilfetext, verfügbar?, Aktion]
  BEFEHLE = [
    ['schrank', 'Schrank einfügen', 'Schranktyp auswählen und einfügen (Unter-, Ober- und Hochschränke, Blenden und Wangen)',
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
     -> { defined?(JTools::SchrankCnc::Export) }, -> { JTools::SchrankCnc::Export.dialog }],
    ['stueckliste', 'Stückliste', 'Stückliste der Teile mit Maßen, Material und Kanten (CSV/HTML)',
     -> { defined?(JTools::SchrankCnc::Stueckliste) }, -> { JTools::SchrankCnc::Stueckliste.dialog }],
    ['etiketten', 'Etiketten', 'Etiketten für die Teile drucken (Bogen oder Endlos)',
     -> { defined?(JTools::SchrankCnc::Etiketten) }, -> { JTools::SchrankCnc::Etiketten.dialog }],
    ['zuschnitt', 'Zuschnittplan', 'Zuschnittplan je Platte für die Formatsäge',
     -> { defined?(JTools::SchrankCnc::Zuschnitt) }, -> { JTools::SchrankCnc::Zuschnitt.dialog }]
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
                             width: 560, height: 460, resizable: true, style: UI::HtmlDialog::STYLE_DIALOG)
      d.set_html(html(titel, gruppen))
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
      einmal_spaeter { aktion.call }
    end

    # SketchUp-Eigenheit: öffnet ein Timer-Block ein modales Fenster (z. B.
    # UI.messagebox), feuert auch ein einmaliger Timer immer wieder, solange das Fenster
    # offen ist – jedes OK legte dann noch einen Schrank/Raum an. Deshalb den Timer
    # als Erstes im Block anhalten.
    def einmal_spaeter(&blk)
      id = UI.start_timer(0, false) do
        UI.stop_timer(id)
        blk.call
      end
    end

    # Gleiches Aussehen wie die Eingabefenster (Kuechenplaner::Eingabe, Stil Treppenplaner)
    def html(titel, gruppen)
      teile = gruppen.map do |gruppe, bild, eintraege|
        next if eintraege.empty?
        svg = File.read(File.join(ICONS, "#{bild}.svg"), encoding: 'UTF-8').strip
        knoepfe = eintraege.map do |t, aktion|
          @aktionen << aktion
          %(<button class="kachel" onclick="sketchup.waehlen(#{@aktionen.size - 1})">#{svg}<span>#{h(t)}</span></button>)
        end
        %(<fieldset><legend>#{h(gruppe)}</legend><div class="raster">#{knoepfe.join}</div></fieldset>)
      end
      <<~HTML
        <!DOCTYPE html><html lang="de"><head><meta charset="utf-8"><style>#{Kuechenplaner::Eingabe.css}
        .raster{display:grid;grid-template-columns:repeat(auto-fill,minmax(120px,1fr));gap:8px;padding:4px 0 2px}
        button.kachel{display:flex;flex-direction:column;align-items:center;gap:6px;padding:10px 6px;border:1px solid var(--line);
          border-radius:6px;background:#fff;color:inherit}
        button.kachel:hover,button.kachel:focus{border-color:var(--accent);background:#eef3f9;outline:none}
        button.kachel svg{width:40px;height:40px}
        </style></head><body>
        <header><h1>#{h(titel)}</h1><span class="sub">anklicken zum Einfügen</span></header>
        <main>#{teile.compact.join}</main>
        <footer><span id="status"></span><span class="spacer"></span><button onclick="sketchup.schliessen()">Schließen</button></footer>
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
