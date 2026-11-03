# Test ohne SketchUp (Mock-API): Abschlussregal in allen Formen, Typen und Zeilenenden,
# Anleimer, Tags, JT_Schrank, Kontur für den TCN-Export, Neuaufbau nach Änderungen.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
load File.expand_path('../src/regal_abschluss/main.rb', __dir__)

R = RegalAbschluss
EPS = 1e-6
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

def neu_model
  Sketchup.active_model = Sketchup::Model.new
end

# Teile eines Regals: Name => { pos (cm), box (cm), inst }
def teile(inst)
  inst.definition.entities.instances.to_h do |c|
    [c.name, { pos: c.transformation.origin.map { |v| v * 2.54 }, box: c.definition.box.map { |v| v * 2.54 }, inst: c }]
  end
end

def kanten_normalen(c)
  c.definition.entities.faces.select { |f| f.material && f.material.name == R::KANTE }.map { |f| f.normal.to_a.map { |v| v.round(4) } }
end

def nah(a, b) = (a - b).abs < 1e-4

# --- alle Formen, Zeilenenden und Typen ---
R::TYPEN.each do |typ, v|
  [0, 1, 2].each do |form|
    [0, 1].each do |ze|
      neu_model
      inst = R.erstellen('Typ' => typ, 'Hoehe' => v[:hoehe], 'Tiefe' => v[:tiefe], 'Form' => form.to_f,
                         'Zeilenende' => ze.to_f, 'Anz_Einlegeboeden' => v[:eb].to_f)
      fall = "#{typ} #{R::FORMEN[form]} #{R::ZEILENENDE[ze]}"
      t = teile(inst)
      soll = %w[SeiteL SeiteR Boden Deckel Rueckwand] + (1..v[:eb]).map { |k| "Einlegeboden#{k}" }
      check(t.keys.sort == soll.sort, "#{fall}: Teile #{t.keys}")
      mk, b, h, tf = 1.9, 30.0, v[:hoehe], v[:tiefe]
      lw = b - 2 * mk
      innen, aussen = ze.zero? ? %w[SeiteL SeiteR] : %w[SeiteR SeiteL]
      ta = case form
           when 0 then tf
           when 1 then 15.0
           else tf - [30.0, lw, tf - 6.0].min
           end
      check(nah(t[innen][:box][1], tf) && nah(t[innen][:pos][1], mk), "#{fall}: Seite innen volle Tiefe")
      check(nah(t[aussen][:box][1], ta) && nah(t[aussen][:pos][1] + ta, mk + tf), "#{fall}: Seite außen #{ta} tief, hinten bündig (#{t[aussen][:box]})")
      check(nah(t[innen][:pos][0], ze.zero? ? 0 : b - mk), "#{fall}: Seite innen am Nachbarn")
      %w[Boden Deckel].each do |n|
        check(nah(t[n][:box][0], lw) && nah(t[n][:box][1], tf) && nah(t[n][:pos][0], mk), "#{fall}: #{n} zwischen den Seiten, volle Tiefe")
      end
      check(nah(t['Deckel'][:pos][2], h - mk) && nah(t['Boden'][:pos][2], 0), "#{fall}: Boden unten, Deckel oben")
      check(nah(t['Rueckwand'][:box][0], b) && nah(t['Rueckwand'][:pos][1], mk + tf), "#{fall}: Rückwand hinter dem Korpus")
      # Einlegeböden: gleich hohe Fächer, verstellbar 10 mm zurückgesetzt
      zs = (1..v[:eb]).map { |k| t["Einlegeboden#{k}"][:pos][2] + mk / 2 }
      faecher = ([mk] + zs + [h - mk]).each_cons(2).map { |a, c| c - a }
      check(faecher.all? { |f| nah(f, faecher[0]) }, "#{fall}: gleich hohe Fächer #{faecher}")
      check(nah(t['Einlegeboden1'][:pos][1], mk + 1.0) && nah(t['Einlegeboden1'][:box][1], tf - 1.0), "#{fall}: Einlegeboden 10 mm zurück")

      # Tags, JT_Schrank, Material
      t.each do |n, x|
        c = x[:inst]
        check(c.layer.name == "RA1_#{n}", "#{fall}: Tag #{c.layer.name}")
        check(c.get_attribute('JT_Schrank', 'kategorie') == typ && c.get_attribute('JT_Schrank', 'typ') == 'Abschlussregal' &&
              c.get_attribute('JT_Schrank', 'schrank') == 'RA1', "#{fall}: JT_Schrank #{n}")
        check(c.get_attribute('JT_Schrank', 'rolle') == R::ROLLEN.fetch(n.sub(/\d+\z/, '')), "#{fall}: Rolle #{n}")
        check(c.material && c.material.name == 'Melamin weiss', "#{fall}: Material #{n}")
        check(c.get_attribute('JT_Schrank', 'frontfarbe').nil?, "#{fall}: Korpusfarbe ohne frontfarbe")
      end
      check(inst.definition.get_attribute('JT_Schrank', 'kategorie') == typ, "#{fall}: Kategorie am Schrank")

      # Anleimer: Seiten vorn, Rückwand an der Außenseite, Böden vorn bzw. an Schräge/Bogen
      %w[SeiteL SeiteR].each { |n| check(kanten_normalen(t[n][:inst]).uniq == [[0, -1, 0]], "#{fall}: #{n} Anleimer vorn") }
      check(kanten_normalen(t['Rueckwand'][:inst]).uniq == [[ze.zero? ? 1 : -1, 0, 0]], "#{fall}: Rückwand Anleimer außen")
      %w[Boden Deckel Einlegeboden1].each do |n|
        kn = kanten_normalen(t[n][:inst])
        schraeg = kn.reject { |x| x.map(&:abs).max > 0.9999 }
        d = t[n][:inst].definition
        case form
        when 0
          check(kn == [[0, -1, 0]] && d.get_attribute('JT_Kontur', 'kante').nil?, "#{fall}: #{n} gerade, Anleimer vorn #{kn}")
        when 1
          check(kn.size == 1 && schraeg.size == 1 && schraeg[0][1] < 0 && (ze.zero? ? schraeg[0][0] > 0 : schraeg[0][0] < 0),
                "#{fall}: #{n} schräg, Anleimer an der Schräge #{kn}")
          k = d.get_attribute('JT_Kontur', 'kante')
          check(k && k.size == 8 && k[0] == 0.0, "#{fall}: #{n} Kontur Gerade #{k.inspect}")
        else
          check(schraeg.size == R::BOGEN_SEGMENTE, "#{fall}: #{n} rund, Anleimer am Bogen (#{schraeg.size} Sehnen)")
          k = d.get_attribute('JT_Kontur', 'kante')
          check(k && k.size == 8 && k[0] == 1.0, "#{fall}: #{n} Kontur Bogen #{k.inspect}")
          # Bogen tangential an der Seite außen: Ende auf der Außenkante, Radius = Abstand zur Mitte
          if k
            x0, y0, x1, y1, cx, cy = k[1, 6].map { |q| q * 2.54 }
            r = Math.hypot(x0 - cx, y0 - cy)
            check(nah(r, Math.hypot(x1 - cx, y1 - cy)) && nah(y0, 0) && nah(x1, ze.zero? ? t[n][:box][0] : 0),
                  "#{fall}: #{n} Bogen von der Vorderkante an die Außenseite")
          end
        end
        u = d.get_attribute('JT_Kontur', 'umriss')
        check(form.zero? || (u && u.size.even? && u.size >= 8), "#{fall}: #{n} Umriss gespeichert")
      end
    end
  end
end

# --- feste Einlegeböden: Mittelboden (Rolle Zwischenboden), nicht zurückgesetzt ---
neu_model
t = teile(R.erstellen('Boeden_Art' => 1.0, 'Anz_Einlegeboeden' => 3.0, 'Form' => 1.0))
check((1..3).all? { |k| t["Mittelboden#{k}"] } && t.keys.none? { |n| n.start_with?('Einlegeboden') }, "fest: Mittelböden #{t.keys}")
check(nah(t['Mittelboden1'][:pos][1], 1.9) && nah(t['Mittelboden1'][:box][1], 52.0), 'fest: volle Tiefe')
check(t['Mittelboden2'][:inst].get_attribute('JT_Schrank', 'rolle') == 'Zwischenboden', 'fest: Rolle Zwischenboden (Dübel)')

# --- Frontfarbe: alle Teile tragen JT_Schrank/frontfarbe ---
neu_model
fi = R.erstellen('Farbe' => 1.0)
check(teile(fi).values.all? { |x| x[:inst].get_attribute('JT_Schrank', 'frontfarbe') == true }, 'Frontfarbe: alle Teile markiert')

# --- ungültige Maße ---
[{ 'Breite' => 12.0 }, { 'Form' => 1.0, 'Tiefe_Aussen' => 51.0 }, { 'Form' => 1.0, 'Tiefe_Aussen' => 3.0 },
 { 'Form' => 2.0, 'Radius' => 2.0 }, { 'Tiefe' => 10.0 }].each do |e|
  fehler = begin
    R.berechne(R::DEFAULTS.merge(e))
    nil
  rescue ArgumentError => x
    x.message
  end
  check(fehler, "ungültig erkannt: #{e}")
end

# --- Neuaufbau nach Änderung in den Komponentenoptionen (Werte an der Instanz) ---
vergleich = lambda do |a, b|
  ta, tb = teile(a), teile(b)
  ta.keys.sort == tb.keys.sort && ta.all? do |n, x|
    y = tb[n]
    (0..2).all? { |i| nah(x[:pos][i], y[:pos][i]) && nah(x[:box][i], y[:box][i]) } &&
      kanten_normalen(x[:inst]).sort == kanten_normalen(y[:inst]).sort &&
      x[:inst].definition.get_attribute('JT_Kontur', 'kante') == y[:inst].definition.get_attribute('JT_Kontur', 'kante')
  end
end
aenderungen = [
  [{}, { 'Tiefe' => 61.0 }],
  [{ 'Form' => 1.0 }, { 'Tiefe' => 40.0 }],
  [{}, { 'Form' => 2.0 }],
  [{ 'Form' => 2.0 }, { 'Zeilenende' => 1.0, 'Breite' => 45.0 }],
  [{ 'Form' => 1.0 }, { 'Tiefe_Aussen' => 25.0, 'Anz_Einlegeboeden' => 3.0 }],
  [{}, { 'Boeden_Art' => 1.0, 'Hoehe' => 80.0 }]
]
aenderungen.each do |vorher, aenderung|
  m = neu_model
  inst = R.erstellen(vorher)
  alt = inst.definition
  aenderung.each do |k, v|
    inst.set_attribute(R::DICT, k.downcase, R::LAENGEN.include?(k) ? v / 2.54 : v)
  end
  R.pruefen(m)
  neu_model
  frisch = R.erstellen(vorher.merge(aenderung))
  check(inst.definition != alt, "#{aenderung}: neu aufgebaut")
  check(vergleich.(inst, frisch), "#{aenderung}: wie frisch erzeugt")
  check(inst.definition.get_attribute('JT_Schrank', 'schrank') == 'RA1', "#{aenderung}: Kürzel bleibt")
  check(m.definitions.to_a.none? { |d| d == alt }, "#{aenderung}: alte Definition entfernt")
  g = inst.definition.get_attribute(R::R_DICT, R::R_GEBAUT)
  check(g == R.gebaut_werte(R::DEFAULTS.merge(vorher).merge(aenderung)), "#{aenderung}: gebaute Maße gemerkt")
  # nochmal prüfen: nichts geändert -> kein neuer Aufbau
  d2 = inst.definition
  R.pruefen(m)
  check(inst.definition == d2, "#{aenderung}: ohne Änderung kein Neuaufbau")
end

# Typ (Oberschrank) bleibt beim Neuaufbau erhalten
m = neu_model
inst = R.erstellen('Typ' => 'Oberschrank', 'Tiefe' => 35.0)
inst.set_attribute(R::DICT, 'breite', 40.0 / 2.54)
R.pruefen(m)
check(inst.definition.get_attribute('JT_Schrank', 'kategorie') == 'Oberschrank' &&
      teile(inst)['SeiteL'][:inst].get_attribute('JT_Schrank', 'kategorie') == 'Oberschrank', 'Typ bleibt beim Neuaufbau')

# Ungültige Änderung: alte Werte zurück, kein Neuaufbau
m = neu_model
inst = R.erstellen('Form' => 1.0)
alt = inst.definition
inst.set_attribute(R::DICT, 'tiefe_aussen', 60.0 / 2.54)
R.pruefen(m)
check(inst.definition == alt && nah(inst.get_attribute(R::DICT, 'tiefe_aussen') * 2.54, 15.0), 'ungültig: alte Werte bleiben')

# Frontmaterial bleibt beim Neuaufbau (Farbe Frontfarbe)
m = neu_model
inst = R.erstellen('Farbe' => 1.0)
front = m.materials.add('Front Eiche 19mm')
kante = m.materials.add('Anleimer Eiche')
kante.set_attribute('ladb_opencutlist', 'type', 4)
teile(inst).each_value do |x|
  x[:inst].material = front
  x[:inst].definition.entities.faces.each { |f| f.material = kante if f.material }
end
inst.set_attribute(R::DICT, 'tiefe', 60.0 / 2.54)
R.pruefen(m)
t = teile(inst)
check(t.values.all? { |x| x[:inst].material == front }, 'Frontmaterial bleibt beim Neuaufbau')
check(t.values.all? { |x| x[:inst].definition.entities.faces.select(&:material).all? { |f| f.material == kante } }, 'Front-Anleimer bleibt')
# zurück auf Korpusfarbe: Melamin
inst.set_attribute(R::DICT, 'farbe', 0.0)
R.pruefen(m)
check(teile(inst).values.all? { |x| x[:inst].material.name == 'Melamin weiss' && x[:inst].get_attribute('JT_Schrank', 'frontfarbe').nil? },
      'Korpusfarbe: wieder Melamin weiss')

# Echte DC: Neuzeichnen skaliert auf die gemerkte Größe (lenx/leny/lenz). Nach dem Neuaufbau
# muss das Regal trotzdem die neue Tiefe haben (Jürgen 2026-11-02: 400 mm eingestellt, 238 gezeichnet)
require_relative '../../../test/dc_groesse_helfer'
DcGroesseHelfer.mit_dc(R::DICT) do
  [[{ 'Tiefe' => 23.0, 'Zeilenende' => 1.0 }, { 'Tiefe' => 40.0 }],
   [{ 'Typ' => 'Oberschrank', 'Tiefe' => 40.0 }, { 'Tiefe' => 30.0, 'Breite' => 45.0, 'Hoehe' => 60.0 }],
   [{}, { 'Form' => 2.0, 'Tiefe' => 35.0 }]].each do |vorher, aenderung|
    m = neu_model
    inst = R.erstellen(vorher)
    aenderung.each { |k, v| inst.set_attribute(R::DICT, k.downcase, R::LAENGEN.include?(k) ? v / 2.54 : v) }
    R.pruefen(m)
    $dc_observers.redraw_with_undo(inst) # nächstes Neuzeichnen durch die DC
    neu_model
    frisch = R.erstellen(vorher.merge(aenderung))
    ist, soll = DcGroesseHelfer.groesse(inst), DcGroesseHelfer.groesse(frisch)
    check(ist.zip(soll).all? { |a, b| nah(a, b) }, "DC #{aenderung}: Größe #{ist.map { |v| v.round(1) }} statt #{soll.map { |v| v.round(1) }}")
    check(nah(soll[1], 0.8 + vorher.merge(aenderung)['Tiefe']), "DC #{aenderung}: Tiefe mit Rückwand #{soll[1]}")
  end
end

# --- zweites Regal bekommt RA2 ---
m = neu_model
R.erstellen
i2 = R.erstellen
check(teile(i2)['Boden'][:inst].layer.name == 'RA2_Boden', 'zweites Regal: Kürzel RA2')

# --- Dialog je Typ: Tiefe-Vorschlag, Form und Zeilenende aus Listen ---
module UI
  class << self
    attr_accessor :antwort, :frage
  end
  def self.inputbox(prompts, defaults, listen, titel)
    @frage = [prompts, defaults, listen, titel]
    @antwort || defaults
  end
end
{ 'Unterschrank' => %w[700 520], 'Oberschrank' => %w[700 400], 'Hochschrank' => %w[2100 520] }.each do |typ, (h, tf)|
  m = neu_model
  UI.antwort = nil
  R.dialog(typ)
  pr, de, li, ti = UI.frage
  check(pr.include?('Tiefe Korpus (mm)') && de == ['300', h, tf, 'gerade', 'rechts'], "Dialog #{typ}: #{de}")
  check(li[3] == 'gerade|schräg|rund' && li[4] == 'rechts|links' && ti.include?(typ), "Dialog #{typ}: Listen #{li}")
  inst = m.entities.instances.last
  check(inst && inst.definition.get_attribute('JT_Schrank', 'kategorie') == typ, "Dialog #{typ}: Regal gebaut")
end
m = neu_model
UI.antwort = ['450', '720', '350', 'rund', 'links']
R.dialog('Oberschrank')
t = teile(m.entities.instances.last)
check(nah(t['SeiteL'][:box][1], 35.0 - 29.0) && nah(t['SeiteR'][:box][1], 35.0),
      "Dialog rund links: Seite außen links #{t['SeiteL'][:box]}")
check(t['Boden'][:inst].definition.get_attribute('JT_Kontur', 'kante')[0] == 1.0, 'Dialog rund: Bogen')
m = neu_model
UI.antwort = ['300', '700', '150', 'schräg', 'rechts']
R.dialog('Unterschrank')
check(m.entities.instances.empty?, 'Dialog: zu kleine Tiefe baut nichts')

# --- Kurzhilfe ---
neu_model
d = R.erstellen.definition
check(d.get_attribute(R::DICT, 'summary') == R::HILFE_KURZ && d.get_attribute(R::DICT, 'description').nil?, 'Kurzhilfe')
%w[breite hoehe tiefe form zeilenende tiefe_aussen radius anz_einlegeboeden boeden_art farbe].each do |k|
  check(%w[TEXTBOX LIST].include?(d.get_attribute(R::DICT, "_#{k}_access")), "Komponentenoption #{k}")
end
src = File.read(File.expand_path('../src/regal_abschluss/main.rb', __dir__), encoding: 'UTF-8')
check(src.include?('Kuechenplaner.neuer_schrank(inst) if Kuechenplaner.respond_to?(:neuer_schrank)'), 'Andock-Haken')

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
