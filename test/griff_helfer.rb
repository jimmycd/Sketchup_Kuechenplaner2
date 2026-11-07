# Gemeinsamer Test-Baustein (von den Komponenten-Tests der Unterschränke geladen): Griffkante.
#
# Bei der Öffnung „Griffkante 45°“ setzt Schrank-CNC am Schrank Griff_Front (cm) und zeichnet ihn
# neu. Dann muss über jeder Front (Tür, Schubladenfront, Klappe) mindestens Griff_Front Luft
# sein, bis zur nächsten Front darüber oder bis zur Oberkante des Schranks; der Korpus bleibt,
# und nachträglich gesetzt sieht der Schrank aus wie gleich mit Griff_Front erzeugt.
# Blenden sind feste Teile ohne Griff: sie zählen nur als Front darüber.
require_relative 'tiefe_helfer'

module GriffHelfer
  EPS = 1e-6
  FRONT = /\A(Front|Tür|Klappe)/.freeze
  BLENDE = /\ABlende/.freeze
  KORPUS = /\A(Seite|Boden|Rückwand|Strebe)/.freeze

  def self.name(pfad)
    pfad.split('/').last.sub(/#\d+\z/, '')
  end

  def self.sichtbar(k)
    TiefeHelfer.blaetter(k).reject { |_, (_, l, vs)| vs || l.any?(&:nil?) }
  end

  # Luft über jeder sichtbaren Front (cm), Pfad => Luft
  # oben: ->(sichtbare Teile) { Grenze }, wenn über den Fronten nicht die Schrankoberkante ist
  # (Backofen: Nische über der Schublade)
  def self.luft(k, oben = nil)
    s = sichtbar(k)
    hoehe = oben ? oben.call(s) : k.wert('Hoehe')
    fronten = s.select { |p, _| name(p) =~ FRONT || name(p) =~ BLENDE }
    fronten.select { |p, _| name(p) =~ FRONT }.to_h do |p, (o, l, _)|
      x0, x1 = [o[0], o[0] + l[0]].minmax
      top = o[2] + l[2]
      ueber = fronten.filter_map do |q, (o2, l2, _)|
        next if q == p
        a, b = [o2[0], o2[0] + l2[0]].minmax
        next unless a < x1 - EPS && b > x0 + EPS && o2[2] >= top - EPS
        o2[2]
      end
      [p, (ueber + [hoehe]).min - top]
    end
  end

  # erzeugen: ->(eingabe) { Instanz }. Liefert die Liste der Fehler (leer = gut).
  def self.pruefen(knoten, dict, erzeugen, eingabe = {}, gf = 2.5, oben: nil)
    fehler = []
    Sketchup.active_model = Sketchup::Model.new
    i0 = erzeugen.call(eingabe)
    k0 = knoten.new(i0, i0.definition, nil)
    k0.redraw
    Sketchup.active_model = Sketchup::Model.new
    i1 = erzeugen.call(eingabe)
    i1.definition.set_attribute(dict, 'griff_front', gf / 2.54)
    k1 = knoten.new(i1, i1.definition, nil)
    k1.redraw
    Sketchup.active_model = Sketchup::Model.new
    i2 = erzeugen.call(eingabe.merge('Griff_Front' => gf))
    k2 = knoten.new(i2, i2.definition, nil)
    k2.redraw
    fehler << 'keine Front gefunden' if luft(k0, oben).empty?
    luft(k0, oben).each { |p, v| fehler << "#{p}: ohne Griffkante schon #{v.round(2)} Luft" if v >= gf - EPS }
    luft(k1, oben).each { |p, v| fehler << "#{p}: nur #{v.round(2)} statt #{gf} Luft" if v < gf - EPS }
    a, b = sichtbar(k0), sichtbar(k1)
    a.each do |p, w|
      next unless name(p) =~ KORPUS
      fehler << "#{p}: Korpus geändert" unless b[p] && (0..1).all? { |j| w[j].zip(b[p][j]).all? { |x, y| (x - y).abs < EPS } }
    end
    fehler + TiefeHelfer.abweichungen(k1, k2).map { |f| "nachträglich: #{f}" }
  end
end
