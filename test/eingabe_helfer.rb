# Test-Baustein: Vorgabewerte aus dem HTML eines Eingabefensters (Kuechenplaner::Eingabe)
# lesen und „OK“ drücken, wie es der Benutzer im HtmlDialog tut.
require 'json'

module EingabeHelfer
  module_function

  # [[Beschriftung, Wert], …] in der Reihenfolge der Felder
  def felder(html)
    html.scan(%r{<label for="f(\d+)">(.*?)</label><div class="ctl">(<input[^>]*value="([^"]*)"|<select[^>]*>(.*?)</select>)}m).map do |_, label, _, wert, opts|
      wert ||= opts[%r{<option selected>(.*?)</option>}, 1] || opts[%r{<option>(.*?)</option>}, 1]
      [entities(label), entities(wert)]
    end
  end

  def entities(t)
    t.to_s.gsub('&lt;', '<').gsub('&gt;', '>').gsub('&quot;', '"').gsub('&amp;', '&')
  end

  # OK im Dialog d mit den Vorgaben, einzelne Werte über aendern { label => wert } ersetzt
  def ok(d, aendern = {})
    werte = felder(d.html).map { |l, w| aendern.fetch(l, w) }
    d.callbacks['ok'].call(nil, JSON.generate(werte))
  end
end
