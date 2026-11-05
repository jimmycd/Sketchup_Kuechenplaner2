# encoding: UTF-8
# Test ohne SketchUp: PDF-Schreiber (Aufbau, Umlaute, Textbreite, Kürzen, QR-Code)
$LOAD_PATH.unshift(__dir__)
require 'pdf_helfer'
load File.expand_path('../src/jt_schrank_cnc/pdf.rb', __dir__)

P = JTools::SchrankCnc::Pdf
$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

d = P.new(titel: 'Prüfung')
d.seite(210, 297)
d.text(10, 10, 'Größe 808 × 572 – Maß…', groesse: 4, fett: true)
d.text(10, 20, 'Klammern (a) und \\', groesse: 3)
d.text(100, 50, 'gedreht', groesse: 3, drehung: 90, ausrichtung: :mitte)
d.rechteck(5, 5, 50, 20, fuellung: [1, 0.9, 0.8])
d.linie(0, 0, 210, 297, strich: [1, 1])
d.kreis(50, 50, 3)
d.schraffur(10, 100, 40, 20)
d.seite(62, 29).text(1, 5, 'Endlos', groesse: 3)
s = d.to_s
check(PdfHelfer.gueltig?(s), 'PDF-Aufbau gültig (xref, startxref)')
check(PdfHelfer.seiten(s) == 2 && PdfHelfer.formate(s) == [[210.0, 297.0], [62.0, 29.0]], "Seiten und Formate: #{PdfHelfer.formate(s)}")
check(PdfHelfer.texte(s).include?('Größe 808 × 572 – Maß…'), "Umlaute, ×, – und … in Windows-1252: #{PdfHelfer.texte(s).first}")
check(PdfHelfer.texte(s).include?('Klammern (a) und \\'), 'Klammern und Backslash maskiert')
check(s.include?('/Title (Pr'), 'Titel im PDF')
check(s.include?('0 1 -1 0 '), 'gedrehter Text')
check(P.cp1252('a→b') == 'a?b'.encode('Windows-1252'), 'nicht darstellbare Zeichen als ?')

# Textbreite Helvetica: "Hallo" = H 722 + a 556 + l 222 + l 222 + o 556 = 2278/1000 je mm Schriftgröße
check((P.textbreite('Hallo', 10) - 22.78).abs < 1e-6, "Textbreite: #{P.textbreite('Hallo', 10)}")
check(P.textbreite('Hallo', 10, true) > P.textbreite('Hallo', 10), 'fett ist breiter')
k = P.kuerzen('HS1_ZwischenbodenUnten', 20, 4)
check(k.end_with?('…') && P.textbreite(k, 4) <= 20, "Kürzen auf 20 mm: #{k}")
check(P.kuerzen('kurz', 50, 3) == 'kurz', 'kurzer Text bleibt')

# QR-Code: Rechtecke im Inhalt, 21 × 21 Module bei kurzem Text
q = P.new.seite(50, 50)
q.qr(5, 5, 21, 'HS1_Boden.tcn')
inhalt = q.seiten.last[:ops]
check(inhalt.scan(' re').size > 50 && inhalt.include?('0 0 0 rg'), 'QR-Code gezeichnet')
qr = JTools::SchrankCnc::RQRCodeCore::QRCode.new('HS1_Boden.tcn', level: :m)
check(qr.module_count == 21, "QR Version 1 (21 Module): #{qr.module_count}")
# Suchmuster oben links: 7 × 7 Rahmen
check((0..6).all? { |i| qr.checked?(0, i) && qr.checked?(i, 0) && qr.checked?(6, i) } && !qr.checked?(1, 1), 'QR-Suchmuster')

puts $fehler.zero? ? 'OK: PDF' : "#{$fehler} Fehler"
exit($fehler.zero? ? 0 : 1)
