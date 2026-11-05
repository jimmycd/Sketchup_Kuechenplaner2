# Test ohne SketchUp: Maßänderung an angedockten Schränken (Jürgen 2026-11-05) –
# Breite: angedockte Seite bleibt, freie Seite wandert; Tiefe: Rückseite bleibt, Front wandert.
$LOAD_PATH.unshift(__dir__)
require 'sketchup_mock'
komp = File.expand_path('../../Komponenten', __dir__)
load File.join(komp, 'unterschrank_schubladen', 'src', 'unterschrank_schubladen', 'main.rb')
load File.expand_path('../src/jt_schrank_cnc/main.rb', __dir__)

A = JTools::SchrankCnc::Andocken
M = JTools::SchrankCnc::Massaenderung
R = M::Rechnung
V = Math::PI / 2
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

def nah(a, b, eps = 1e-6)
  a = [a].flatten
  b = [b].flatten
  a.size == b.size && a.zip(b).all? { |x, y| (x - y).abs < eps }
end

# --- Rechnung ------------------------------------------------------------------
K = [0, 60, 0, 56, 0, 72].freeze       # 60 breit, Front bei y = 0, Rückseite bei 56
K80 = [0, 80, 0, 56, 0, 72].freeze     # breiter
KT = [0, 60, 0, 66, 0, 72].freeze      # tiefer
null = [0, 0, 0, 0]
nachbar = ->(x) { [[0, x, 0, 0], [0, 60, 0, 56], [0, 72], :schrank] }
wand_hinten = [[0, -100, 56, 0], [0, 400, 0, 24], nil, :wand] # Wand entlang x, Rückseite bei y = 56

check(!R.geaendert?(K, K.dup) && R.geaendert?(K, K80) && R.geaendert?(K, KT), 'Änderung am Grundriss erkannt')
check(!R.geaendert?(K, [0, 60, 0, 56, 0, 90]), 'nur Höhe geändert: nichts zu tun')
check(!R.geaendert?(nil, K), 'noch nicht gemerkt: keine Änderung')

check(R.anliegend?(K, null, [nachbar.call(60)], :rechts) && !R.anliegend?(K, null, [nachbar.call(60)], :links),
      'Nachbar rechts erkannt')
check(R.anliegend?(K, null, [nachbar.call(-60)], :links) && !R.anliegend?(K, null, [nachbar.call(-60)], :rechts),
      'Nachbar links erkannt')
check(!R.anliegend?(K, null, [nachbar.call(70)], :rechts), 'Nachbar mit Lücke ist nicht angedockt')
check(!R.anliegend?(K, null, [wand_hinten], :links) && !R.anliegend?(K, null, [wand_hinten], :rechts),
      'Wand hinter dem Schrank dockt keine Seite an')
seitenwand = [[V, 0, -100, 0], [0, 400, 0, 24], nil, :wand] # Wand bei x <= 0 (Ecke links)
check(R.anliegend?(K, null, [seitenwand], :links), 'Seitenwand in der Ecke zählt als angedockt')

# nur rechts angedockt: wächst nach links
r = R.anpassen(K, K80, null, [nachbar.call(60)])
check(nah(r[:lage], [0, -20, 0, 0]) && !r[:kollision], "nur rechts angedockt: rechte Seite bleibt (#{r[:lage]})")
# nur links angedockt: wächst nach rechts, Lage bleibt
r = R.anpassen(K, K80, null, [nachbar.call(-60)])
check(nah(r[:lage], null) && !r[:kollision], "links angedockt: linke Seite bleibt (#{r[:lage]})")
# frei: linke Seite bleibt
check(nah(R.anpassen(K, K80, null, [])[:lage], null), 'frei stehend: linke Seite bleibt')
# beidseitig: links bleibt, Kollision gemeldet; schmaler: keine Kollision
r = R.anpassen(K, K80, null, [nachbar.call(-60), nachbar.call(60)])
check(nah(r[:lage], null) && r[:kollision] && r[:links] && r[:rechts], 'beidseitig angedockt und breiter: linke Seite bleibt, Kollision')
r = R.anpassen(K, [0, 50, 0, 56, 0, 72], null, [nachbar.call(-60), nachbar.call(60)])
check(nah(r[:lage], null) && !r[:kollision], 'beidseitig angedockt und schmaler: keine Kollision')
# Tiefe: Rückseite bleibt, Front wandert nach vorne (-y)
r = R.anpassen(K, KT, null, [wand_hinten])
check(nah(r[:lage], [0, 0, -10, 0]) && !r[:kollision], "tiefer: Rückseite bleibt an der Wand (#{r[:lage]})")
r = R.anpassen(KT, K, [0, 0, -10, 0], [wand_hinten])
check(nah(r[:lage], null), 'flacher: Front wandert zurück, Rückseite bleibt')
# gedrehter Schrank (an der rechten Wand, -90°): Verschiebung im Schranksystem
l = [-V, 400, 300, 0]
r = R.anpassen(K, KT, l, [])
bx, by = A::Rechnung.welt(l, 0, 56)
nx, ny = A::Rechnung.welt(r[:lage], 0, 66)
check(nah([bx, by], [nx, ny]), 'gedreht: hintere Ecke steht an derselben Stelle')
# rechts angedockt im gedrehten System
nl = [-V, 400, 300, 0]
nb = [[nl[0], *A::Rechnung.welt(nl, 60, 0), 0], [0, 60, 0, 56], [0, 72], :schrank]
r = R.anpassen(K, K80, nl, [nb])
ax, ay = A::Rechnung.welt(nl, 60, 0)
cx, cy = A::Rechnung.welt(r[:lage], 80, 0)
check(nah([ax, ay], [cx, cy]), 'gedreht, rechts angedockt: rechte Seite bleibt')

# --- SketchUp: Breite/Tiefe an echten Komponenten ändern ------------------------------
def o(i) = i.transformation.origin.to_a.map(&:to_f)
model = Sketchup.active_model = Sketchup::Model.new
us1 = UnterschrankSchubladen.erstellen(UnterschrankSchubladen::DEFAULTS)
A.setzen(us1, [0, 0, 0, 0], 'test')
model.select_tool(nil)
model.selection.clear
us2 = UnterschrankSchubladen.erstellen(UnterschrankSchubladen::DEFAULTS) # rechts daneben
check(nah(o(us2)[0], 60.cm), "zweiter Schrank rechts angereiht (#{o(us2)})")
M.nachziehen(model)
check(M.gemerkt(us1) && M.gemerkt(us2), 'Kästen gemerkt')
x1 = o(us1)[0] + A.bezug(us1)[1]

# Breite des linken Schranks (rechts angedockt an us2) 60 → 80: wächst nach links
us1.definition = UnterschrankSchubladen.erzeuge(model, UnterschrankSchubladen::DEFAULTS.merge('Breite' => 80.0))
M.nachziehen(model)
check(nah(o(us1)[0] + A.bezug(us1)[1], x1) && nah(o(us1)[0], -20.cm), "linker Schrank breiter: rechte Seite bleibt am Nachbarn (#{o(us1)})")
check(nah(M.gemerkt(us1)[1] - M.gemerkt(us1)[0], 80.cm), 'neuer Kasten gemerkt')
vorher = o(us1)
M.nachziehen(model)
check(nah(o(us1), vorher), 'zweiter Durchlauf ohne Änderung: bleibt stehen')

# Breite des rechten Schranks (links angedockt) 60 → 90: linke Seite bleibt
us2.definition = UnterschrankSchubladen.erzeuge(model, UnterschrankSchubladen::DEFAULTS.merge('Breite' => 90.0))
M.nachziehen(model)
check(nah(o(us2)[0], 60.cm), "rechter Schrank breiter: linke Seite bleibt (#{o(us2)})")

# Tiefe ändern: Rückseite bleibt, Front wandert
hinten = o(us2)[1] + A.bezug(us2)[3]
vorne_alt = o(us2)[1] + A.bezug(us2)[2]
us2.definition = UnterschrankSchubladen.erzeuge(model, UnterschrankSchubladen::DEFAULTS.merge('Breite' => 90.0, 'Tiefe' => 60.0))
M.nachziehen(model)
check(nah(o(us2)[1] + A.bezug(us2)[3], hinten), "flacher: Rückseite bleibt (#{o(us2)})")
check(o(us2)[1] + A.bezug(us2)[2] > vorne_alt + 19.cm, 'flacher: Front ist nach hinten gewandert')
check(nah(o(us2)[0], 60.cm), 'Tiefe ändert die Seitenlage nicht')

# beidseitig angedockt: Mittelschrank breiter → links bleibt, Meldung
model.selection.clear
model.selection.add(us2)
us3 = UnterschrankSchubladen.erstellen(UnterschrankSchubladen::DEFAULTS) # rechts an us2
M.nachziehen(model)
xm = o(us2)[0]
$meldung = nil
def UI.messagebox(m) = $meldung = m
us2.definition = UnterschrankSchubladen.erzeuge(model, UnterschrankSchubladen::DEFAULTS.merge('Breite' => 100.0, 'Tiefe' => 60.0))
M.nachziehen(model)
check(nah(o(us2)[0], xm), 'beidseitig angedockt: linke Seite bleibt')
check($meldung.to_s.include?('links und rechts angedockt'), "beidseitig angedockt: Kollision gemeldet (#{$meldung.inspect})")

# Arbeitsplatte/Sockel werden nicht angefasst
check(A::KEINE_ZEILE.all? { |k| %w[Arbeitsplatte Sockel].include?(k) }, 'Arbeitsplatte und Sockel ausgenommen')

# Einbindung: Plugin lädt das Modul und startet den Beobachter
main = File.read(File.expand_path('../src/jt_schrank_cnc/main.rb', __dir__))
check(main.include?(' massaenderung ') && main.include?('Massaenderung.app_beobachten'), 'Modul geladen, Beobachter gestartet')

puts $fehler.zero? ? 'Alle Maßänderungs-Tests OK' : "#{$fehler} Fehler"
exit($fehler.zero? ? 0 : 1)
