# Test ohne SketchUp: Kurzhilfe, Tags und JT_Schrank werden in die ausgewählte Komponente geschrieben.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
load File.expand_path('../src/unterschrank_tuer/main.rb', __dir__)

T = UnterschrankTuer
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

# Nachbau der Teile aus Unterschrank.skp: Instanzname bzw. nur Definitionsname
def unterschrank(model)
  d = model.definitions.add('Unterschrank')
  d.set_attribute(T::DICT, '_name', 'Unterschrank')
  d.set_attribute(T::DICT, 'anz_einlegeboeden', '1') # wie in der .skp als Text gespeichert
  seite = model.definitions.add('Seite')
  { 'SeiteL' => seite, 'SeiteR' => seite, 'Boden' => model.definitions.add('Boden'),
    'StrebeVorn' => model.definitions.add('StrebeV'), 'StrebeHinten' => model.definitions.add('StrebeH'),
    'Rückwand' => model.definitions.add('Rückwand'), 'Front' => model.definitions.add('Front') }.each do |n, defn|
    i = d.entities.add_instance(defn, Geom::Transformation.translation([0, 0, 0]))
    i.name = n
  end
  (1..3).each do |k|
    eb = model.definitions.add("Boden##{k}")
    eb.set_attribute(T::DICT, '_hidden_formula', " IF (Unterschrank!Anz_Einlegeboeden>#{k - 1},0,1)")
    d.entities.add_instance(eb, Geom::Transformation.translation([0, 0, 0]))
  end
  d.entities.add_instance(model.definitions.add('Griff'), Geom::Transformation.translation([0, 0, 0]))
  model.entities.add_instance(d, Geom::Transformation.translation([0, 0, 0]))
end

model = Sketchup.active_model = Sketchup::Model.new
check(T.einrichten(model).empty?, 'ohne Auswahl passiert nichts')

inst = unterschrank(model)
d = inst.definition
model.selection.add(inst)
check(T.einrichten(model) == [inst], 'Auswahl wird bearbeitet')
check(d.description == T::HILFE_KURZ, 'Beschreibung der Definition')
check(d.get_attribute(T::DICT, 'summary') == T::HILFE_KURZ, 'summary')
check(d.get_attribute(T::DICT, 'description') == T::HILFE, 'description')
check(%w[summary description].all? { |k| d.get_attribute(T::DICT, "_#{k}_access") == 'VIEW' }, 'nur anzeigen')
check(T::HILFE.include?(T::DOKU_URL), 'Link zur Doku')
check(File.exist?(File.expand_path('../README.md', __dir__)), 'README.md vorhanden')

# Tags und JT_Schrank
teile = d.entities.instances.reject { |i| i.definition.name == 'Griff' }
tags = teile.map { |i| i.layer&.name }
soll = %w[SeiteL SeiteR Boden StrebeVorn StrebeHinten Rueckwand Tuer Einlegeboden1 Einlegeboden2 Einlegeboden3]
check(tags == soll.map { |t| "UST1_#{t}" }, "Tags #{tags.inspect}")
teile.each do |i|
  jt = %w[schrank typ kategorie bereich teil rolle].to_h { |k| [k, i.get_attribute(T::JT_DICT, k)] }
  check(jt['schrank'] == 'UST1' && jt['typ'] == T::TYP && jt['kategorie'] == 'Unterschrank' && jt['bereich'] == '',
        "JT_Schrank #{jt.inspect}")
  check(i.layer.name == "UST1_#{jt['teil']}", "Tag passt zu JT_Schrank #{jt.inspect}")
  check(T::ROLLEN.value?(jt['rolle']), "Rolle #{jt['rolle'].inspect}")
end
griff = d.entities.instances.find { |i| i.definition.name == 'Griff' }
check(griff.layer.nil? && griff.get_attribute(T::JT_DICT, 'teil').nil?, 'unbekanntes Teil bleibt ohne Tag')
check(d.get_attribute(T::JT_DICT, 'kategorie') == 'Unterschrank', 'JT_Schrank am Schrank')

# Einlegeböden: Formeln für Sichtbarkeit und Höhe (Fehler: Anzahl Einlegeböden wirkte nicht)
# Kleiner Formel-Auswerter für die DC-Formeln: Unterschrank!X, IF(), + - * / >=
def dc_wert(formel, attr)
  ruby = formel.gsub(/Unterschrank!(\w+)/) { attr.fetch($1).to_s }.gsub('IF(', 'wenn(')
  Object.new.tap { |o| o.define_singleton_method(:wenn) { |b, a, c| b ? a : c } }.instance_eval(ruby).to_f
end

boeden = (1..3).map { |k| teile.find { |i| i.layer.name == "UST1_Einlegeboden#{k}" } }
boeden.each_with_index do |b, idx|
  k = idx + 1
  check(b.get_attribute(T::DICT, '_name') == "Einlegeboden#{k}", "Name Einlegeboden#{k}")
  [b, b.definition].each do |e|
    f = e.get_attribute(T::DICT, '_hidden_formula')
    check(f == "IF(Unterschrank!Anz_Einlegeboeden>=#{k},0,1)", "Sichtbarkeitsformel #{k}: #{f.inspect}")
  end
  check(b.get_attribute(T::DICT, '_z_formula').to_s.include?('Anz_Einlegeboeden'), "Höhenformel #{k}")
  check(b.hidden == (k > 1), "Einlegeboden#{k} sofort richtig sichtbar bei Anzahl 1")
end
h, mk = 70.0, 1.9
(0..3).each do |n|
  attr = { 'Hoehe' => h, 'Materialstaerke_Korpus' => mk, 'Anz_Einlegeboeden' => n }
  sichtbar = boeden.select { |b| dc_wert(b.get_attribute(T::DICT, '_hidden_formula'), attr).zero? }
  check(sichtbar == boeden.first(n), "Anzahl #{n}: #{sichtbar.size} Böden sichtbar")
  zs = sichtbar.map { |b| dc_wert(b.get_attribute(T::DICT, '_z_formula'), attr) }
  # lichte Fächer zwischen Boden (Oberkante mk), den Einlegeböden und den Streben (Unterkante h-mk)
  kanten = [mk] + zs.flat_map { |z| [z, z + mk] } + [h - mk]
  faecher = kanten.each_slice(2).map { |a, b| (b - a).round(6) }
  check(faecher.uniq.size == 1 && faecher.first > 0, "Anzahl #{n}: gleich hohe Fächer #{faecher.inspect}")
  (boeden - sichtbar).each do |b|
    check(dc_wert(b.get_attribute(T::DICT, '_z_formula'), attr) == mk, "Anzahl #{n}: ausgeblendeter Boden liegt unten")
  end
end

# Zweiter Lauf behält das Kürzel, ein zweiter Schrank bekommt UST2
T.einrichten(model)
check(teile.first.layer.name == 'UST1_SeiteL', 'zweiter Lauf behält UST1')
inst2 = unterschrank(model)
model.selection.clear
model.selection.add(inst2)
T.einrichten(model)
tags2 = inst2.definition.entities.instances.map { |i| i.layer&.name }
check(tags2 == soll.map { |t| "UST2_#{t}" } + [nil], "zweiter Schrank UST2 (Definitionen mit #1): #{tags2.inspect}")

# Menü: Unterschrank.skp einfügen, jedes Exemplar mit eigenem Kürzel und eigener Definition
class Sketchup::Definitions
  attr_accessor :geladen
  def load(pfad) = (@geladen ||= {})[pfad] ||= yield_load(pfad)
  def yield_load(pfad)
    raise "falscher Pfad #{pfad}" unless File.exist?(pfad)
    m = Sketchup.active_model
    tmp = unterschrank(m) # baut die Definition im Modell, Instanz wieder entfernen
    m.entities.instances.delete(tmp)
    tmp.definition
  end
end
class Sketchup::ComponentDefinition
  def instances = Sketchup.active_model.entities.instances.select { |i| i.definition == self }
  def delete_attribute(d, k) = dicts[d]&.delete(k)
end
class Sketchup::ComponentInstance
  def make_unique
    neu = Sketchup.active_model.definitions.add(@definition.name)
    @definition.dicts.each { |d, h| h.each { |k, v| neu.set_attribute(d, k, v) } }
    @definition.entities.instances.each do |i|
      c = neu.entities.add_instance(i.definition, i.transformation)
      c.name = i.name
      c.layer = i.layer
      i.dicts.each { |d, h| h.each { |k, v| c.set_attribute(d, k, v) } }
    end
    @definition = neu
    self
  end
end
check(File.exist?(T::SKP), 'Unterschrank.skp liegt in der Erweiterung')
model = Sketchup.active_model = Sketchup::Model.new
e1 = T.einfuegen(model)
e2 = T.einfuegen(model)
tags_e = [e1, e2].map { |e| e.definition.entities.instances.map { |i| i.layer&.name }.compact.map { |t| t[/\A[A-Z]+\d+/] }.uniq }
check(tags_e == [['UST1'], ['UST2']], "eingefügte Schränke UST1/UST2: #{tags_e.inspect}")
check(e1.definition != e2.definition, 'zweiter Schrank hat eigene Definition')
check(e2.definition.description == T::HILFE_KURZ, 'Kurzhilfe am eingefügten Schrank')
check(e2.definition.get_attribute(T::JT_DICT, 'schrank') == 'UST2', 'JT_Schrank am zweiten Schrank')
check(model.selection.to_a == [e2], 'eingefügter Schrank ist ausgewählt')

puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
