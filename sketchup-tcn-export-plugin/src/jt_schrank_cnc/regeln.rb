# encoding: UTF-8
# Schrank-CNC – Bearbeitungsregeln aus Jürgens Beispiel-TCN (beispiele/).
#
# Stöße werden geometrisch gefunden: liegt die Stirnseite eines Bodens, Deckels,
# Zwischenbodens oder einer Strebe (Teil A) an der Fläche einer Seite (Teil B),
# bekommt A eine Dübelreihe in die Stirnseite und B die passende Reihe in die
# Fläche. Die Bearbeitungen entstehen zuerst in Weltkoordinaten (mm) und werden
# erst beim Schreiben in die Werkstückkoordinaten (Fräsmaß) umgerechnet.

module JTools
  module SchrankCnc
    module Regeln
      TOL = 0.1 # mm

      # Bearbeitung: :reihe (p0 -> p1, Raster, verteilt) oder :bohrung (p0) auf einer Weltseite
      Op = Struct.new(:art, :seite, :p0, :p1, :d, :tiefe, :raster, :verteilt, :titel)

      # Dübelreihen je Rolle von A (Abstand vom Rand, Raster; verteilt = #8508/#8509 1/1)
      VERBINDUNGEN = {
        'Boden'         => { rand: 30, raster: 150, verteilt: true },  # Boden.tcn, Seite.tcn
        'Deckel'        => { rand: 30, raster: 150, verteilt: true },  # Deckel.tcn
        'Zwischenboden' => { rand: 30, raster: 150, verteilt: true },
        # Strebe.tcn: 20 … x-20, Raster 60; verteilt, damit es auch bei 98 mm (Anleimer) zwei Dübel bleiben
        'Strebe'        => { rand: 20, raster: 60, verteilt: true, schraube: true }
      }.freeze
      DUEBEL = { d: 8, tiefe_kante: 22, tiefe_flaeche: 12 }.freeze
      SCHRAUBE = { d: 3, tiefe: 21 }.freeze # Seite.tcn: Ø3, 21 tief in der Mitte der Strebe

      def self.anwenden(werkstuecke)
        werkstuecke.each { |w| w.ops.clear }
        meldungen = []
        werkstuecke.group_by { |w| w.teil.pfad.first }.each_value do |teile|
          teile.each do |a|
            regel = VERBINDUNGEN[a.rolle] or next
            teile.each do |b|
              next unless b.rolle == 'Seite'
              stoss(a, b, regel, meldungen)
            end
          end
        end
        meldungen
      end

      def self.stoss(a, b, regel, meldungen)
        k = b.dicke_achse
        return if k == a.dicke_achse
        if (a.lo[k] - b.hi[k]).abs < TOL
          sa, sb, kp = :"#{Geometrie::ACHSEN[k]}min", :"#{Geometrie::ACHSEN[k]}max", b.hi[k]
        elsif (a.hi[k] - b.lo[k]).abs < TOL
          sa, sb, kp = :"#{Geometrie::ACHSEN[k]}max", :"#{Geometrie::ACHSEN[k]}min", b.lo[k]
        else
          return
        end
        andere = (0..2).reject { |i| i == k }
        return unless andere.all? { |i| [a.hi[i], b.hi[i]].min - [a.lo[i], b.lo[i]].max > 1.0 }

        ca = a.dicke_achse
        la = (andere - [ca]).first
        lo = [a.lo_f(la), b.lo_f(la)].max
        hi = [a.hi_f(la), b.hi_f(la)].min
        if hi - lo < 2 * regel[:rand]
          meldungen << "#{a.name} an #{b.name}: Stoß nur #{(hi - lo).round(1)} mm lang, keine Dübel"
          return
        end
        pt = lambda do |l|
          p = [0.0, 0.0, 0.0]
          p[k] = kp
          p[ca] = (a.lo[ca] + a.hi[ca]) / 2.0
          p[la] = l
          p
        end
        p0 = pt.(lo + regel[:rand])
        p1 = pt.(hi - regel[:rand])
        titel = "Duebel #{b.teil.jt('teil')}"
        a.ops << Op.new(:reihe, sa, p0, p1, DUEBEL[:d], DUEBEL[:tiefe_kante], regel[:raster], regel[:verteilt], titel)
        b.ops << Op.new(:reihe, sb, p0, p1, DUEBEL[:d], DUEBEL[:tiefe_flaeche], regel[:raster], regel[:verteilt],
                        "Duebel #{a.teil.jt('teil')}")
        return unless regel[:schraube]
        b.ops << Op.new(:bohrung, sb, pt.((lo + hi) / 2.0), nil, SCHRAUBE[:d], SCHRAUBE[:tiefe], nil, nil,
                        "Schraube #{a.teil.jt('teil')}")
      end

      # Fläche 1 (oben auf der Maschine): die große Fläche mit den meisten Bohrungen,
      # bei Gleichstand die obere bzw. die Seite zur größeren Koordinate
      def self.flaeche1(w)
        a = w.dicke_achse
        mn, mx = :"#{Geometrie::ACHSEN[a]}min", :"#{Geometrie::ACHSEN[a]}max"
        w.ops.count { |o| o.seite == mn } > w.ops.count { |o| o.seite == mx } ? mn : mx
      end
    end
  end
end
