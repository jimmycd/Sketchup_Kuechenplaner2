# encoding: UTF-8
# Schrank-CNC – Fräsliste für TpaCAD (Sammelliste .xmlst), mit der alle TCN eines
# Exports im Board zusammen abgearbeitet werden. Aufbau wie im Treppenbau
# (fraesliste.rb) und in csv2tcn (Liste_<Name>.xmlst): UTF-8 mit BOM, CRLF,
# je TCN-Datei eine <Row> mit vollem Windows-Pfad und REPETITIONS = Stückzahl.
# Reihenfolge: nach Größe, die größte Fläche (DL × DH) zuerst, bei gleicher
# Fläche die längere, dann nach Name.
# OFFSET X/Y: halbes OCL-Übermaß des Plattenmaterials (Wörterbuch ladb_opencutlist,
# length_increase/width_increase), damit squad das Rohteil rundum gleich formatiert:
# die TCN ist im Fräsmaß, das Rohteil aus OCL um das Übermaß größer. OFFSET Z = 0.
# COMMENT: Teilname in OCL (Name der Komponentendefinition).

module JTools
  module SchrankCnc
    module Fraesliste
      module_function

      # FIELD in der Liste: 9 wie in csv2tcn (Liste_Regalbad.xmlst) und im Treppenbau
      FIELD = 9

      OCL_DICT = 'ladb_opencutlist'.freeze

      # Längenangabe aus OCL ("10 mm", "1 cm", "0.5\"", "0") in mm
      def mm(v)
        s = v.to_s.strip.tr(',', '.')
        z = s[/-?\d+(\.\d+)?/].to_f
        case s
        when /cm\z/ then z * 10
        when /\bm\z/ then z * 1000
        when /("|in)\z/ then z * 25.4
        else z
        end
      end

      def material(d)
        d.ws.teil.inst.material
      end

      # [OFFSET X, OFFSET Y] in mm: OCL length_increase gilt für die längere Seite
      def offset(d)
        mat = material(d)
        return [0.0, 0.0] unless mat
        li = mm(mat.get_attribute(OCL_DICT, 'length_increase'))
        wi = mm(mat.get_attribute(OCL_DICT, 'width_increase'))
        d.lage.dl >= d.lage.dh ? [li / 2.0, wi / 2.0] : [wi / 2.0, li / 2.0]
      end

      # Teilname wie in OpenCutList (Definition), z. B. "Front S1"
      def ocl_name(d)
        Schraenke.definition(d.ws.teil.inst).name.to_s
      end

      def name(ordner)
        basis = File.basename(ordner.to_s.tr('\\', '/'))
        basis = '' if basis =~ /\A[A-Za-z]:\z/ || basis == '/'
        basis = basis.gsub(/[\\\/:*?"<>|\s]+/, '_')
        basis = 'Export' if basis.empty?
        "Liste_#{basis}.xmlst"
      end

      # Windows-Pfad, wenn der Ordner einer ist (Laufwerk oder UNC), sonst unverändert
      def pfad(ordner, datei)
        p = File.join(ordner, datei)
        ordner.to_s =~ /\A([A-Za-z]:|\\\\|\/\/)/ ? p.tr('/', '\\') : p
      end

      def sortiert(dateien)
        dateien.sort_by { |d| [-(d.lage.dl * d.lage.dh).round(3), -d.lage.dl.round(3), d.name] }
      end

      def text(ordner, dateien)
        liste = name(ordner)
        out = +"﻿<?xml version=\"1.0\" encoding=\"utf-8\"?>\n"
        out << "<List>\n"
        out << "  <Rows Name=\"#{attr(liste)}\" Repetitions=\"1\" TL=\"0\" TH=\"0\" TS=\"0\" Criterion=\"\">\n"
        sortiert(dateien).each_with_index { |d, i| out << row(i + 1, pfad(ordner, "#{d.name}.tcn"), d) }
        out << "  </Rows>\n"
        out << "</List>\n"
        out.gsub("\n", "\r\n")
      end

      def schreiben(ordner, dateien)
        p = File.join(ordner, name(ordner))
        File.binwrite(p, text(ordner, dateien).encode('UTF-8').b)
        p
      end

      def row(index, datei, d)
        q = "\"#{datei}\""
        ox, oy = offset(d)
        cells = [
          ['DRAW', 281, '1'],
          ['ESEC', 165, '1'],
          ['NAME', 161, esc(q)],
          ['REPETITIONS', 164, d.anzahl.to_s],
          ['EXECUTED', 288, '0'],
          ['FIELD', 171, FIELD.to_s],
          ['ROTATION', 286, '1'],
          ['MIRROR', 284, '0'],
          ['HOOKOPTI', 600, '0'],
          ['LENGTH', 168, Tcn.n(d.lage.dl)],
          ['HEIGHT', 169, Tcn.n(d.lage.dh)],
          ['THICKNESS', 170, Tcn.n(d.lage.ds)],
          ['COMMENT', 162, esc(ocl_name(d))],
          ['UNIT', 163, '1'],
          ['HOOK', 282, '0'],
          ['TIME', 223, '00:00:00'],
          ['OFFSET X', 277, Tcn.n(ox)],
          ['OFFSET Y', 278, Tcn.n(oy)],
          ['OFFSET Z', 279, '0']
        ]
        out = +"    <Row Index=\"#{index}\" SavedID=\"1\" FileName=\"#{attr(q)}\">\n"
        cells.each { |n, t, v| out << "      <Cell Name=\"#{n}\" DataType=\"#{t}\">#{v}</Cell>\n" }
        out << "    </Row>\n"
      end

      def esc(s)
        s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
      end

      def attr(s)
        esc(s).gsub('"', '&quot;')
      end
    end
  end
end
