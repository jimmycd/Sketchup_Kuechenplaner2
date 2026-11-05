# encoding: UTF-8
# Test-Baustein: PDF aus JTools::SchrankCnc::Pdf prüfen (ohne PDF-Bibliothek)
module PdfHelfer
  module_function

  # Texte aller Seiten (oder einer Seite) als UTF-8, in Zeichenreihenfolge
  def texte(pdf, seite = nil)
    s = pdf.is_a?(String) ? pdf : pdf.to_s
    streams = s.scan(/stream\n(.*?)\nendstream/m).map(&:first)
    streams = [streams[seite]] if seite
    streams.flat_map do |st|
      st.scan(/\(((?:\\.|[^\\)])*)\) Tj/m).map do |(t)|
        t.gsub(/\\(.)/m, '\1').force_encoding('Windows-1252').encode('UTF-8')
      end
    end
  end

  def seiten(pdf)
    pdf.to_s[%r{/Type /Pages /Count (\d+)}, 1].to_i
  end

  # MediaBox der Seiten in mm (gerundet)
  def formate(pdf)
    pdf.to_s.scan(%r{/MediaBox \[0 0 ([\d.]+) ([\d.]+)\]}).map { |w, h| [(w.to_f * 25.4 / 72).round(1), (h.to_f * 25.4 / 72).round(1)] }
  end

  # Aufbau gültig: Kopf, xref-Offsets zeigen auf die Objekte, startxref stimmt
  def gueltig?(pdf)
    s = pdf.to_s.b
    return false unless s.start_with?('%PDF-1.4') && s.end_with?("%%EOF\n")
    xref = s[/startxref\n(\d+)/, 1].to_i
    return false unless s[xref, 4] == 'xref'
    n = s[xref..][/xref\n0 (\d+)/, 1].to_i
    offs = s[xref..].scan(/^(\d{10}) 00000 n $/).flatten.map(&:to_i)
    offs.size == n - 1 && offs.each_with_index.all? { |o, i| s[o, "#{i + 1} 0 obj".size] == "#{i + 1} 0 obj" }
  end
end
