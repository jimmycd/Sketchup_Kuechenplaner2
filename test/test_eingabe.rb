# Test ohne SketchUp: gemeinsames Eingabefenster Kuechenplaner::Eingabe (HtmlDialog im Stil des Treppenplaners)
haupt = File.expand_path('..', __dir__)
require_relative 'eingabe_helfer'

$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

module UI
  class << self
    attr_accessor :inputbox_antwort, :inputbox_aufrufe
  end
  def self.inputbox(*args)
    (@inputbox_aufrufe ||= []) << args
    inputbox_antwort
  end
end

load File.join(haupt, 'gemeinsam/eingabe.rb')
E = Kuechenplaner::Eingabe

# Beschriftungen wie bei UI.inputbox zerlegen
check(E.beschriftung('Breite (mm)') == ['Breite', 'mm', nil], 'Einheit mm')
check(E.beschriftung('Stärke (mm, 0 = Standard 38/40)') == ['Stärke', 'mm', '0 = Standard 38/40'], 'Einheit mit Hinweis')
check(E.beschriftung('Aufteilung von oben (Anteile oder mm, z. B. 1;1)') == ['Aufteilung von oben', nil, 'Anteile oder mm, z. B. 1;1'], 'nur Hinweis')
check(E.beschriftung('Kürzel') == ['Kürzel', nil, nil], 'ohne Klammer')
f = E.felder(['Breite (mm)', 'Ecke 1: Stoß', 'Ecke 1: durchlaufende Platte', 'Griff: Höhe ab Unterkante Front (mm)'],
             %w[600 stumpf Z1 35], ['', 'a|stumpf', '', ''])
check(f.map { |x| x[:gruppe] } == ['Einstellungen', 'Ecke 1', 'Ecke 1', 'Griff'], "Gruppen aus „Gruppe: Feld“: #{f.map { |x| x[:gruppe] }}")
check(f[1][:liste] == %w[a stumpf] && f[1][:label] == 'Stoß', 'Auswahlliste')
check(E.felder(['Breite (mm)', 'Höhe (mm)'], %w[1 2], []).map { |x| x[:gruppe] }.uniq == ['Maße'], 'nur Maße -> Gruppe Maße')

# Ohne HtmlDialog: UI.inputbox wie bisher, Block bekommt die Antwort
UI.inputbox_antwort = %w[1 2]
r = E.abfragen(['A (mm)', 'B (mm)'], %w[5 6], 'Titel') { |w| w.map(&:to_i).sum }
check(r == 3 && UI.inputbox_aufrufe.last == [['A (mm)', 'B (mm)'], %w[5 6], 'Titel'], "ohne HtmlDialog: UI.inputbox (#{UI.inputbox_aufrufe.last.inspect})")
UI.inputbox_antwort = %w[x]
E.abfragen(['A'], %w[5], ['x|y'], 'T') { |_| }
check(UI.inputbox_aufrufe.last == [['A'], %w[5], ['x|y'], 'T'], 'ohne HtmlDialog: Listen werden weitergegeben')
UI.inputbox_antwort = false
gerufen = false
E.abfragen(['A'], %w[5], 'T') { gerufen = true }
check(!gerufen, 'Abbrechen ruft den Block nicht')

# Mit HtmlDialog
module UI
  class HtmlDialog
    STYLE_DIALOG = 0
    attr_reader :html, :callbacks, :optionen, :skripte
    def initialize(opt) = (@optionen, @callbacks, @skripte = opt, {}, [])
    def set_html(h) = @html = h
    def add_action_callback(n, &blk) = @callbacks[n] = blk
    def center = nil
    def show = @offen = true
    def visible? = @offen
    def close = @offen = false
    def execute_script(js) = @skripte << js
  end
end
UI.inputbox_aufrufe = []
erhalten = []
d = E.abfragen(['Breite (mm)', 'Art', 'Name <b>"x"</b>'], ['600', 'B', 'a&b'], ['', 'A|B', ''], 'Testschrank',
               untertitel: 'Neuer Schrank', ok: 'Einfügen') do |w|
  raise ArgumentError, 'Breite zu klein' if w[0].to_f < 100
  erhalten << w
end
check(UI.inputbox_aufrufe.empty?, 'mit HtmlDialog kein UI.inputbox')
check(d.visible? && d.optionen[:dialog_title] == 'Testschrank' && d.optionen[:style] == UI::HtmlDialog::STYLE_DIALOG, 'Fenster offen, Titel')
h = d.html
check(h.include?('<h1>Testschrank</h1>') && h.include?('<span class="sub">Neuer Schrank</span>'), 'Kopfzeile mit Titel und Untertitel')
check(%w[#f4f2ee #2f6fb3 Segoe <fieldset> <legend> <footer> button.primary].all? { |t| h.include?(t) }, 'Stil wie Treppenplaner')
check(h.include?('<button id="ok" class="primary">Einfügen</button>') && h.include?('Abbrechen</button>'), 'Knöpfe Einfügen/Abbrechen')
check(h.include?('<span class="unit">mm</span>') && h.include?('<option selected>B</option>'), 'Einheit und Auswahl')
check(h.include?('Name &lt;b&gt;&quot;x&quot;&lt;/b&gt;') && h.include?('value="a&amp;b"') && !h.include?('<b>'), 'Texte maskiert')
check(EingabeHelfer.felder(h) == [['Breite', '600'], ['Art', 'B'], ['Name <b>"x"</b>', 'a&b']], "Felder lesbar: #{EingabeHelfer.felder(h).inspect}")
check(d.optionen[:height].between?(240, 820), 'Höhe passt sich an')

# ungültige Eingabe: Fenster bleibt offen, Meldung im Fenster
EingabeHelfer.ok(d, 'Breite' => '50')
check(d.visible? && erhalten.empty? && d.skripte.last.include?('KP.fehler') && d.skripte.last.include?('Breite zu klein'),
      "ungültige Eingabe bleibt im Fenster: #{d.skripte.inspect}")
# gültig: Block einmal, Fenster zu; zweiter Klick (Doppelklick) ändert nichts
EingabeHelfer.ok(d, 'Breite' => '700')
EingabeHelfer.ok(d, 'Breite' => '700')
check(erhalten == [%w[700 B a&b]] && !d.visible?, "Block genau einmal, Fenster zu: #{erhalten.inspect}")

# andere Fehler: Meldung im Fenster
d2 = E.abfragen(['A'], ['1'], 'T') { raise 'kaputt' }
EingabeHelfer.ok(d2)
check(d2.visible? && d2.skripte.last.include?('Fehler: kaputt'), 'Fehler bleibt im Fenster')
# Abbrechen
gerufen = false
d3 = E.abfragen(['A'], ['1'], 'T') { gerufen = true }
check(!d2.visible?, 'neues Fenster schließt das vorige')
d3.callbacks['abbrechen'].call(nil)
check(!d3.visible? && !gerufen, 'Abbrechen schließt ohne Block')

# Farbwähler und Dateiauswahl
module UI
  class << self
    attr_accessor :openpanel_antwort
    def openpanel(*) = openpanel_antwort
  end
end
farbe = nil
d4 = E.abfragen(['Name', 'Farbe', 'Texturbild (leer = nur Farbe)'], ['x', '#B08850', ''], ['', ':farbe', ':datei'], 'Neue Platte') { |w| farbe = w }
h4 = d4.html
check(h4.include?('class="farbwahl"') && h4.include?('id="f1_rad"') && h4.include?('id="f1_hell"') && h4.include?('id="f1_muster"'),
      'Farbfeld mit Farbrad, Helligkeitsregler und Vorschau')
check(h4.include?('sketchup.datei(2)') && !h4.include?('sketchup.datei(1)'), 'Dateifeld mit Knopf')
check(EingabeHelfer.felder(h4) == [%w[Name x], ['Farbe', '#B08850'], ['Texturbild', '']], "Farb-/Dateifeld lesbar: #{EingabeHelfer.felder(h4).inspect}")
check(!h4.include?(':farbe') && !h4.include?('<select id="f1"'), 'keine Auswahlliste für :farbe')
check(d4.optionen[:height] > E.hoehe(E.felder(['Name', 'Farbe', 'T'], %w[x y z], [], nil)) + 100, 'Fenster höher für das Farbrad')
UI.openpanel_antwort = 'C:\\Bilder\\eiche.jpg'
d4.callbacks['datei'].call(nil, '2')
check(d4.skripte.last == 'KP.setze(2, "C:/Bilder/eiche.jpg")', "gewählte Datei ins Feld: #{d4.skripte.last}")
UI.openpanel_antwort = nil
n_skripte = d4.skripte.size
d4.callbacks['datei'].call(nil, '2')
check(d4.skripte.size == n_skripte, 'Datei-Abbrechen ändert nichts')
EingabeHelfer.ok(d4, 'Farbe' => '#2F6FB3')
check(farbe == ['x', '#2F6FB3', ''], 'Farbe kommt als Text an')
# ohne HtmlDialog: Feldarten werden zu Eingabefeldern
hd = UI.send(:remove_const, :HtmlDialog)
UI.inputbox_antwort = %w[x #FFFFFF]
E.abfragen(['Name', 'Farbe'], %w[x #FFFFFF], ['', ':farbe'], 'T') { |_| }
check(UI.inputbox_aufrufe.last == [%w[Name Farbe], %w[x #FFFFFF], ['', ''], 'T'], "ohne HtmlDialog: :farbe wird Eingabefeld (#{UI.inputbox_aufrufe.last.inspect})")
UI.const_set(:HtmlDialog, hd)

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
