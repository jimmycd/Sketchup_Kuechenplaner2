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
require File.join(File.dirname(__dir__), 'kuechenplaner_gemeinsam', 'neuladen') # Neu laden ohne Neustart (Wächter)

# Gemeinsames Untermenü "Erweiterungen > Küchenplaner" für alle Komponenten und
# den TCN-Export. Steht wortgleich in jeder Erweiterung (der Test prüft das), damit
# das Untermenü nur einmal angelegt wird, egal welche Erweiterungen geladen sind.
# Schränke kommen über Kuechenplaner.schrank('Unterschränke' | 'Oberschränke' |
# 'Hochschränke' | 'Blenden & Wangen', titel) ins Menü und in die Schrank-Auswahl der Symbolleiste,
# Geräte und Raum in Kuechenplaner.untermenu('Geräte' | 'Raum'), Werkzeuge direkt in Kuechenplaner.menu darunter.
# Darf mehrfach laufen (Neuladen ohne Neustart): die Methoden werden ersetzt, die
# angelegten Menüs bleiben gemerkt.
module Kuechenplaner
  GRUPPEN = ['Unterschränke', 'Oberschränke', 'Hochschränke', 'Blenden & Wangen', 'Geräte', 'Raum'].freeze unless const_defined?(:GRUPPEN, false)

  def self.menu
    @menu ||= UI.menu('Extensions').add_submenu('Küchenplaner')
  end

  # Alle Gruppen beim ersten Aufruf anlegen, damit die Reihenfolge nicht von der
  # Ladereihenfolge der Erweiterungen abhängt.
  def self.untermenu(gruppe)
    @untermenues ||= GRUPPEN.each_with_object({}) { |g, h| h[g] = menu.add_submenu(g) }
    @untermenues[gruppe] ||= menu.add_submenu(gruppe) # neue Gruppe aus einem Update: unten anhängen
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
end # gemeinsames Untermenü

module KuechenplanerSymbolleiste
  ICONS = File.join(File.dirname(__FILE__), 'icons').freeze
  NAME  = 'Küchenplaner'.freeze
  SCHRANK_GRUPPEN = { 'Unterschränke' => 'unterschrank', 'Oberschränke' => 'oberschrank', 'Hochschränke' => 'hochschrank',
                      'Blenden & Wangen' => 'blende' }.freeze
  # Befehle der Erweiterung „Raum“ (Komponenten/raum): [Titel, Methode von ::Raum]
  RAUM = [['Raum anlegen', :raum_anlegen_dialog], ['Wände aus Linien', :waende_aus_linien],
          ['Fenster/Tür einsetzen', :einsetzen_dialog], ['Öffnung bearbeiten', :oeffnung_bearbeiten_dialog],
          ['Raum bearbeiten', :raum_bearbeiten_dialog]].freeze

  # [Icon, Titel, Hilfetext, verfügbar?, Aktion, eingeschaltet? (optional, Icon gedrückt)]
  BEFEHLE = [
    ['schrank', 'Schrank einfügen', 'Schranktyp auswählen und einfügen (Unter-, Ober- und Hochschränke, Blenden und Wangen)',
     -> { !Kuechenplaner.schraenke.empty? }, -> { KuechenplanerSymbolleiste.schrank_auswahl }],
    ['andocken', 'Schrank andocken', 'Gewählten Schrank an einen Nachbarschrank oder eine Wand andocken',
     -> { defined?(JTools::SchrankCnc::Andocken) }, -> { JTools::SchrankCnc::Andocken.starten }],
    ['arbeitsplatte', 'Arbeitsplatte', 'Arbeitsplatte über den Unterschränken erzeugen; ist eine Arbeitsplatte gewählt, wird sie neu berechnet',
     -> { defined?(::Arbeitsplatte) }, -> { KuechenplanerSymbolleiste.arbeitsplatte }],
    ['raum', 'Raum', 'Raum anlegen und bearbeiten: Wände, Fenster, Türen, Durchgänge',
     -> { defined?(::Raum) }, -> { KuechenplanerSymbolleiste.raum_auswahl }],
    ['beschriftung', 'Schrank-Beschriftung', 'Kürzel der Schränke (wie auf den Etiketten) in den Szenen Planung und Zuschnitt ein- und ausblenden',
     -> { defined?(JTools::SchrankCnc::Beschriftung) }, -> { JTools::SchrankCnc::Beschriftung.umschalten },
     -> { JTools::SchrankCnc::Beschriftung.an? }],
    ['geraete', 'Geräte einsetzen/entfernen', 'Schalter: Geräte (Spüle, Kochfeld, Backofen, Kühlschrank, Spüler …) in alle Schränke einsetzen bzw. alle wieder entfernen',
     -> { defined?(::Geraete) && ::Geraete.respond_to?(:umschalten) }, -> { ::Geraete.umschalten },
     -> { ::Geraete.eingesetzt? }],
    ['beschlag', 'Beschläge zeigen', 'Schalter: Beschläge (LEGRABOX-Zargen und Schienen, Topfbänder, AVENTOS) im Modell zeigen bzw. ausblenden; nicht in Stückliste und TCN',
     -> { defined?(JTools::SchrankCnc::Beschlagmodell) }, -> { JTools::SchrankCnc::Beschlagmodell.umschalten },
     -> { JTools::SchrankCnc::Beschlagmodell.an? }],
    ['frontfarbe', 'Frontfarbe und Griffe', 'Frontfarbe und Griffe der gewählten Schränke ändern',
     -> { defined?(JTools::SchrankCnc::Frontfarbe) }, -> { JTools::SchrankCnc::Frontfarbe.dialog }],
    ['tcn', 'Export', 'Export: Stückliste (mit Beschlagliste), Etiketten, Zuschnittplan und TCN-Dateien in einen Zielordner, je einzeln an- und abwählbar',
     -> { defined?(JTools::SchrankCnc::Export) }, -> { JTools::SchrankCnc::Export.dialog }],
    ['rendern', 'Rendern', 'Küche fotorealistisch mit Blender rendern (Sichtbarkeit wie Szene Kunde, Kamera wie Ansicht)',
     -> { defined?(JTools::SchrankCnc::Rendern) }, -> { JTools::SchrankCnc::Rendern.dialog }],
    ['materialien', 'Materialien', 'Material-Konfigurator: Platten und Anleimer anlegen und bearbeiten, Maserrichtung',
     -> { defined?(JTools::SchrankCnc::Materialdialog) }, -> { JTools::SchrankCnc::Materialdialog.dialog }],
    ['einstellungen', 'Einstellungen', 'Generelle Einstellungen: Sockelhöhe, Wandabstand, Abstand Arbeitsplatte–Oberschrank und CNC-Werte',
     -> { defined?(JTools::SchrankCnc::Einstellungen) }, -> { JTools::SchrankCnc::Einstellungen.dialog }]
  ].freeze

  class << self
    # Windows: SVG (scharf in jeder Größe); Mac kann kein SVG, dort PNG
    def icon(name)
      File.join(ICONS, "#{name}.#{Sketchup.platform == :platform_osx ? 'png' : 'svg'}")
    end

    # Icon i: Aktion und Prüfung holen den Eintrag erst beim Klick aus BEFEHLE, damit
    # nach dem Neuladen (ohne Neustart) die neue Fassung gilt.
    def befehl(i)
      ikon, titel, hilfe, = BEFEHLE[i]
      cmd = UI::Command.new(titel) { KuechenplanerSymbolleiste.ausfuehren(i) }
      cmd.small_icon = cmd.large_icon = icon(ikon)
      cmd.tooltip = titel
      cmd.status_bar_text = hilfe
      cmd.set_validation_proc { KuechenplanerSymbolleiste.zustand(i) }
      cmd
    end

    def ausfuehren(i)
      BEFEHLE[i][4].call
    end

    def verfuegbar?(i)
      BEFEHLE[i][3].call ? true : false
    end

    # ausgegraut ohne Erweiterung; Schalter (z. B. Beschriftung) erscheinen eingeschaltet gedrückt
    def zustand(i)
      return MF_GRAYED unless verfuegbar?(i)
      an = BEFEHLE[i][5]
      an && an.call ? MF_CHECKED : MF_ENABLED
    end

    # Legt die Symbolleiste einmal an; nach dem Neuladen kommen neue Icons hinten dazu
    # (entfernen kann SketchUp Icons erst beim nächsten Start).
    def symbolleiste
      neu = @symbolleiste.nil?
      @symbolleiste ||= UI::Toolbar.new(NAME)
      @icons ||= 0
      while @icons < BEFEHLE.size
        @symbolleiste.add_item(befehl(@icons))
        @icons += 1
      end
      # Beim ersten Start einblenden, danach so, wie der Benutzer sie verlassen hat
      (@symbolleiste.get_last_state == TB_NEVER_SHOWN ? @symbolleiste.show : @symbolleiste.restore) if neu
      @symbolleiste
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

  symbolleiste # mehrfach aufrufbar: beim Neuladen nur neue Icons ergänzen
  file_loaded(__FILE__) unless file_loaded?(__FILE__)
end
