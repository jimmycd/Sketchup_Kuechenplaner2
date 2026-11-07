# encoding: UTF-8
# Test ohne SketchUp: Jedes Modell im Beschlag-Katalog wird mit dem Schalter „Beschläge ein/aus“ gezeichnet
# (Jürgen, 2026-11-07: „stelle sicher, dass alle Beschläge gezeichnet werden, die aktuell unterstützt werden“).
# Für jeden Katalogeintrag steht unten ein Fall: Schrank, in dem das Modell sitzt, und die Körper, die es
# zeichnen muss. Ein neuer Katalogeintrag ohne Fall (also ohne Zeichenroutine) lässt den Test scheitern.
# Dazu Maßprüfungen für AVENTOS HF top und SERVO-DRIVE.
$LOAD_PATH.unshift(__dir__)
require 'beschlag_helfer'

komp = File.expand_path('../../Komponenten', __dir__)
%w[unterschrank_schubladen oberschrank oberschrank_klappe hochschrank_vorrat hochschrank_kuehlschrank eckschrank
   unterschrank_handtuch].each do |k|
  load File.join(komp, "#{k}/src/#{k}/main.rb")
end
load File.expand_path('../src/jt_schrank_cnc/main.rb', __dir__)

S = JTools::SchrankCnc
B = S::Beschlagmodell
K = S::Beschlagkatalog
MM = 25.4
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

USS = { 'Breite' => 60.0, 'Tiefe' => 52.0, 'Anz_Schubladen' => 3, 'Anteil_1' => 1.0, 'Anteil_2' => 1.0, 'Anteil_3' => 2.0 }.freeze
schubladen = -> { UnterschrankSchubladen.erstellen(USS) }
auszug = [/\AZarge /, /\AKorpusschiene /, /\AFronthalter /, /\ARückwandhalter /]

# kennung => [Beschlagart, Schrank, Körper (Namen), die gezeichnet sein müssen]
FAELLE = {
  'blum-legrabox-free' => ['schubladen', schubladen, auszug + [/\ASeiteneinsatz /, /\ASeitenstabilisierung /]],
  'blum-legrabox-pure' => ['schubladen', schubladen, auszug],
  'blum-merivobox' => ['schubladen', schubladen, auszug],
  'blum-tandembox-antaro' => ['schubladen', schubladen, auszug],
  'blum-clip-top' => ['topfband', -> { Oberschrank.erstellen({}) }, [/Topf\z/, /Arm\z/, /\AMontageplatte/]],
  'blum-clip-top-155' => ['topfband_innen', -> { HochschrankVorrat.erstellen({}) }, [/Topf\z/, /Arm\z/, /\AMontageplatte/]],
  'blum-clip-top-170' => ['topfband_innen', -> { HochschrankVorrat.erstellen({}) }, [/Topf\z/, /Arm\z/, /\AMontageplatte/]],
  'blum-modul-kuehlschrank' => ['topfband_kuehlschrank', -> { HochschrankKuehlschrank.erstellen({}) }, [/Topf\z/, /Arm\z/, /\AMontageplatte/]],
  'blum-clip-top-falttuer' => ['falttuer', -> { Eckschrank.erstellen({}, l_form: true) },
                               [/\AFalttürscharnier \d+ Topf\z/, /\AFalttürscharnier \d+ Montageplatte\z/]],
  'blum-aventos-hk-top' => ['klappe', -> { OberschrankKlappe.erstellen({}) },
                            [/\AKraftspeicher AVENTOS HK-top\z/, /\AHebelarm AVENTOS HK-top\z/, /\AFrontbeschlag AVENTOS HK-top\z/]],
  'blum-aventos-hs-top' => ['klappe', -> { OberschrankKlappe.erstellen({}) }, [/\AKraftspeicher AVENTOS HS top\z/, /\AHebel AVENTOS HS top\z/]],
  'blum-aventos-hl-top' => ['klappe', -> { OberschrankKlappe.erstellen({}) }, [/\AKraftspeicher AVENTOS HL top\z/, /\AHebel AVENTOS HL top\z/]],
  'haefele-free-slim-1.12' => ['klappe', -> { OberschrankKlappe.erstellen({}) }, [/\AMechanismus Free Slim\z/, /\AArm Free Slim\z/]],
  'blum-aventos-hf-top' => ['faltklappe', -> { OberschrankKlappe.erstellen({ 'Art_Klappe' => 2.0, 'Hoehe' => 72.0 }) },
                            [/\AKraftspeicher AVENTOS HF top\z/, /\AHebel AVENTOS HF top\z/, /\AHebelhalter AVENTOS HF top\z/,
                             /\AScharnier AVENTOS HF top \d+ Topf\z/, /\AScharnier AVENTOS HF top \d+ Montageplatte\z/,
                             /\AScharnier AVENTOS HF top \d+ Arm\z/]],
  'haefele-hu-slim-base' => ['hochauszug', -> { UnterschrankHandtuch.erstellen({}) }, [/\ASchiene HU Slim Base/, /\AKorb HU Slim Base/]],
  'kesseboehmer-lemans-ii' => ['eckauszug', -> { Eckschrank.erstellen({ 'Variante' => 2.0 }) }, [/\ASäule LeMans\z/, /\ATablar LeMans/]],
  # Öffnung: TIP-ON an Türen und Schubladen, SERVO-DRIVE an Schubladen (Türen dort mit TIP-ON);
  # „Griffe“ ist kein Beschlag im Modell (Griffbohrungen kommen ins TCN)
  'blum-tip-on' => ['oeffnung', -> { [schubladen.(), Oberschrank.erstellen({})] }, [/TIP-ON/]],
  'blum-servo-drive' => ['oeffnung', -> { [schubladen.(), Oberschrank.erstellen({})] },
                         [/\ASERVO-DRIVE Trägerprofil/, /\ASERVO-DRIVE Antriebseinheit/, /\ASERVO-DRIVE Distanzpuffer/, /TIP-ON/]],
  'griffe' => ['oeffnung', -> { [schubladen.()] }, []]
}.freeze

# --- Jedes Katalogmodell hat einen Fall (und damit eine geprüfte Zeichenroutine) ---
K.eintraege.each do |e|
  check(FAELLE.key?(e['kennung']), "#{e['kennung']}: kein Fall – wird das Modell im Beschlagmodell gezeichnet? (Zeichenroutine + Fall ergänzen)")
end
FAELLE.each_key { |k| check(K.eintrag(k), "Fall #{k}: nicht im Katalog") }

def zeichnen(art, kennung, bau)
  Sketchup.defaults.clear # Wahl der Küche nicht aus dem vorigen Fall übernehmen
  model = Sketchup.active_model = Sketchup::Model.new
  K.waehlen(art, kennung, model)
  schraenke = Array(bau.())
  B.setzen(model, true)
  [model, schraenke, koerper(model)]
end

ergebnisse = {}
FAELLE.each do |kennung, (art, bau, erwartet)|
  model, schraenke, k = zeichnen(art, kennung, bau)
  ergebnisse[kennung] = [model, schraenke, k]
  namen = k.map { |x| x[:name] }
  erwartet.each { |re| check(namen.any? { |n| n =~ re }, "#{kennung}: kein Körper #{re.inspect} (#{namen.uniq.first(12)})") }
  check(k.all? { |x| x[:layer] == 'Beschlag' && x[:mat].to_s.start_with?('Beschlag ') }, "#{kennung}: Tag und Material Beschlag")
  # alles innerhalb des Schranks (Komponentengrenzen)
  ws = []
  S::Export.erzeugen(model, alle_ws: ws)
  schraenke.each do |s|
    teile = ws.select { |w| w.teil.pfad.first == s }
    lo = (0..2).map { |a| teile.map { |w| w.lo[a] }.min }
    hi = (0..2).map { |a| teile.map { |w| w.hi[a] }.max }
    k.select { |x| x[:pfad].first == s }.each do |x|
      g = grenzen(x[:pts])
      check((0..2).all? { |a| g[a][0] >= lo[a] - 0.01 && g[a][1] <= hi[a] + 0.01 }, "#{kennung}: #{x[:name]} innerhalb des Schranks (#{g})")
    end
  end
end

beruehrt = ->(g, h) { (0..2).all? { |a| g[a][0] <= h[a][1] + 0.01 && h[a][0] <= g[a][1] + 0.01 } }
ueber = ->(g, p) { (0..2).all? { |a| p[a].between?(g[a][0] - 0.01, g[a][1] + 0.01) } }

# --- AVENTOS HF top: Kraftspeicher über den Bohrungen (Katalog S. 24: 30 stark, A/B je Korpushöhe),
# Hebel zum Hebelhalter an der unteren Klappe, 4 Scharniere mit Topf, Montageplatte und Arm ---
hf_faelle = [ergebnisse['blum-aventos-hf-top'],
             zeichnen('faltklappe', 'blum-aventos-hf-top', -> { OberschrankKlappe.erstellen({ 'Art_Klappe' => 2.0, 'Hoehe' => 50.0 }) })]
hf_faelle.each do |model, schraenke, k|
  hf = schraenke.first
  ws = B.werkstuecke(model, hf)
  lo = (0..2).map { |i| ws.map { |w| w.lo[i] }.min }
  hi = (0..2).map { |i| ws.map { |w| w.hi[i] }.max }
  k.each { |x| check(grenzen(x[:pts]).each_with_index.all? { |(l, h), i| l >= lo[i] - 0.01 && h <= hi[i] + 0.01 }, "HF: #{x[:name]} im Schrank") }
  kh = ws.select { |w| w.rolle == 'Seite' }.map { |w| w.mass(2) }.max
  kraft = k.select { |x| x[:name] == 'Kraftspeicher AVENTOS HF top' }
  check(kraft.size == 2 && kraft.all? { |x| x[:pfad] == [hf] }, "HF: 2 Kraftspeicher fest im Schrank (#{kraft.size})")
  a, b = kh <= 519 ? [66.5, 171.5] : [89.0, 194.0]
  oben = ws.select { |w| w.rolle == 'Seite' }.map { |w| w.hi[2] }.max
  kraft.each do |x|
    g = grenzen(x[:pts])
    check((g[2][1] - (oben - a)).abs < 0.01 && (g[2][1] - g[2][0] - b).abs < 0.01, "HF: Kraftspeicher A #{a} unter Oberkante, B #{b} hoch (#{g[2]}, KH #{kh})")
    dicke = g.map { |lo, hi| hi - lo }.min
    check((dicke - 30).abs < 0.01, "HF: Kraftspeicher 30 stark (#{dicke})")
  end
  loecher = ws.flat_map(&:ops).select { |o| o.titel == 'Kraftspeicher AVENTOS HF top' }
  check(loecher.size == 8 && loecher.all? { |o| kraft.any? { |x| ueber.(grenzen(x[:pts]), o.p0) } }, "HF: Kraftspeicher über allen 8 Bohrungen (#{loecher.size})")
  halter = k.select { |x| x[:name] == 'Hebelhalter AVENTOS HF top' }
  check(halter.size == 2 && halter.all? { |x| x[:pfad].map(&:name).any? { |n| n.to_s.include?('KlappeU') } }, 'HF: 2 Hebelhalter gehen mit der unteren Klappe')
  k.select { |x| x[:name] == 'Hebel AVENTOS HF top' }.each do |x|
    g = grenzen(x[:pts])
    check(kraft.any? { |y| beruehrt.(g, grenzen(y[:pts])) } && halter.any? { |y| beruehrt.(g, grenzen(y[:pts])) }, "HF: Hebel verbindet Kraftspeicher und Hebelhalter (#{g})")
  end
  toepfe = ws.flat_map(&:ops).select { |o| o.titel == 'Scharnier AVENTOS HF top' }
  tk = k.select { |x| x[:name] =~ /\AScharnier AVENTOS HF top \d+ Topf\z/ }
  check(toepfe.size == 4 && tk.size == 4, "HF: 4 Scharniertöpfe (#{toepfe.size} Bohrungen, #{tk.size} Körper)")
  toepfe.each { |o| check(tk.any? { |x| ueber.(grenzen(x[:pts]), o.p0) }, "HF: Topf an der Bohrung #{o.p0}") }
  pl = ws.flat_map(&:ops).select { |o| o.titel == 'Montageplatte AVENTOS HF top' }
  pk = k.select { |x| x[:name] =~ /Montageplatte\z/ && x[:name].include?('HF') }
  check(pl.size == 8 && pk.size == 4, "HF: 4 Montageplatten über 8 Löchern (#{pl.size}/#{pk.size})")
  pl.each { |o| check(pk.any? { |x| ueber.(grenzen(x[:pts]), o.p0) }, "HF: Montageplatte über dem Loch #{o.p0}") }
  deckel = ws.find { |w| w.rolle == 'Deckel' }
  unter_deckel = pk.select { |x| (grenzen(x[:pts])[2][1] - deckel.lo[2]).abs < 0.01 }
  check(unter_deckel.size == 2 && unter_deckel.all? { |x| x[:pfad] == [hf] }, 'HF: 2 Montageplatten unter dem Deckel, fest im Schrank')
  check(k.count { |x| x[:name] =~ /\AScharnier AVENTOS HF top \d+ Arm\z/ } == 4, 'HF: 4 Scharnierarme')
end

# --- SERVO-DRIVE an Schubladen (Katalog S. 364–366) ---
model, (uss, os), k = ergebnisse['blum-servo-drive']
ws = B.werkstuecke(model, uss)
uk = k.select { |x| x[:pfad].first == uss }
prof = uk.select { |x| x[:name].start_with?('SERVO-DRIVE Trägerprofil') }
check(prof.size == 1 && prof[0][:pfad] == [uss], "SERVO-DRIVE: ein Trägerprofil fest im Schrank (#{prof.size})")
unten = ws.select { |w| w.rolle == 'Boden' }.map { |w| w.hi[2] }.max
lh = ws.select { |w| w.rolle == 'Seite' }.map { |w| w.hi[2] }.max - unten
lh = ws.select { |w| S::Regeln::FESTE_BOEDEN.include?(w.rolle) && w.lo[2] > unten + 0.1 }.map { |w| w.lo[2] }.min.to_f - unten if
  ws.any? { |w| S::Regeln::FESTE_BOEDEN.include?(w.rolle) && w.lo[2] > unten + 0.1 }
soll_pl = ((lh - 10) / 10.0).floor * 10
if (p = prof[0])
  g = grenzen(p[:pts])
  check((g[2][1] - g[2][0] - soll_pl).abs < 0.01, "SERVO-DRIVE: Trägerprofil PL = LH − 10 abgerundet = #{soll_pl} (#{g[2][1] - g[2][0]})")
  check(p[:name] == "SERVO-DRIVE Trägerprofil #{soll_pl}", "SERVO-DRIVE: Name mit Länge (#{p[:name]})")
  rw = ws.find { |w| w.rolle == 'Rueckwand' }
  check(beruehrt.(g, [[rw.lo[0], rw.hi[0]], [rw.lo[1], rw.hi[1]], [rw.lo[2], rw.hi[2]]]), 'SERVO-DRIVE: Trägerprofil an der Rückwand')
end
an = uk.select { |x| x[:name].start_with?('SERVO-DRIVE Antriebseinheit') }
kaesten = S::Regeln.kaesten(ws)
check(an.size == kaesten.size, "SERVO-DRIVE: eine Antriebseinheit je Auszug (#{an.size}/#{kaesten.size})")
zargen = uk.select { |x| x[:name].start_with?('Zarge') }.map { |x| grenzen(x[:pts]) }
an.each do |x|
  g = grenzen(x[:pts])
  bez = x[:name].split.last
  sch = ws.flat_map(&:ops).select { |o| o.titel == "Schiene #{bez}" }.map { |o| o.p0[2] }.min
  check(sch && (g[2][0] - (sch - 10 + 45)).abs < 0.01, "SERVO-DRIVE #{bez}: Unterkante A = 45 über Unterkante Korpusschiene (#{g[2][0]}, Schiene #{sch})")
  check(zargen.none? { |h| (0..2).all? { |a| g[a][0] < h[a][1] - 0.01 && h[a][0] < g[a][1] - 0.01 } }, "SERVO-DRIVE #{bez}: Antriebseinheit hinter den Zargen")
  check(prof[0] && beruehrt.(g, grenzen(prof[0][:pts])), "SERVO-DRIVE #{bez}: Antriebseinheit am Trägerprofil")
end
kaesten.each do |kasten|
  f = S::Regeln.front_zu(kasten, ws)
  bez = kasten.find { |w| w.rolle == 'KastenBoden' }.teil.jt('bereich')
  pu = uk.select { |x| x[:name] == "SERVO-DRIVE Distanzpuffer #{bez}" }
  soll = f.mass(2) <= 300 ? 2 : 4
  check(pu.size == soll, "SERVO-DRIVE #{bez}: #{soll} Distanzpuffer bei FH #{f.mass(2).round} (#{pu.size})")
  check(pu.all? { |x| x[:pfad].last.name.to_s.start_with?('Schublade') }, "SERVO-DRIVE #{bez}: Puffer fahren mit der Schublade")
  pu.each do |x|
    g = grenzen(x[:pts])
    d = f.dicke_achse
    check((g[d][0] - f.hi[d]).abs < 0.01 || (g[d][1] - f.lo[d]).abs < 0.01, "SERVO-DRIVE #{bez}: Puffer auf der Innenseite der Front (#{g})")
  end
end
# Türen haben bei SERVO-DRIVE kein Trägerprofil, Griffe/TIP-ON zeichnen kein SERVO-DRIVE
check(k.none? { |x| x[:pfad].first == os && x[:name].start_with?('SERVO-DRIVE') }, 'SERVO-DRIVE: nicht am Oberschrank mit Türen')
%w[griffe blum-tip-on].each do |kn|
  check(ergebnisse[kn][2].none? { |x| x[:name].start_with?('SERVO-DRIVE') }, "#{kn}: kein SERVO-DRIVE")
end

if $fehler.zero?
  puts 'Beschlagmodell (alle Katalogmodelle): alle Tests OK'
else
  puts "Beschlagmodell (alle Katalogmodelle): #{$fehler} Fehler"
  exit 1
end
