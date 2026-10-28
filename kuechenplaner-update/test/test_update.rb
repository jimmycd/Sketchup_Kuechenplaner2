# Test ohne SketchUp: "Plugins aktualisieren" holt den Stand aus dem Repo (GitHub
# wird durch dieses Arbeitsverzeichnis ersetzt), schreibt nur geänderte Dateien in
# einen leeren Plugins-Ordner und lädt die betroffenen Erweiterungen neu.
require 'tmpdir'
require 'json'
require 'uri'
haupt = File.expand_path('../..', __dir__)
$LOAD_PATH.unshift(File.join(haupt, 'sketchup-tcn-export-plugin/test'))
require 'sketchup_mock'

$fehler = 0
def check(bed, msg)
  return if bed
  $fehler += 1
  puts "FEHLER: #{msg}"
end

# leere sketchup.rb / extensions.rb für die Lade-Dateien
stubs = Dir.mktmpdir
%w[sketchup.rb extensions.rb].each { |f| File.write(File.join(stubs, f), "# mock\n") }
$LOAD_PATH.unshift(stubs)

PLUGINS = Dir.mktmpdir
MB_YESNO = 4
IDYES = 6

module UI
  @meldungen = []
  @antwort = IDYES
  class << self
    attr_accessor :meldungen, :antwort
    def messagebox(text, _typ = nil)
      @meldungen << text
      @antwort
    end
  end
end

# Erweiterungen wie in SketchUp: registrieren und (eingeschaltet) laden
class SketchupExtension
  attr_accessor :description, :version, :creator, :copyright
  attr_reader :name, :extension_path
  def initialize(name, pfad)
    @name = name
    @extension_path = File.expand_path("#{pfad}.rb", PLUGINS)
  end

  def loaded? = @geladen
  def laden!
    @geladen = true
    load @extension_path
  end
end

# Netz: GitHub = dieses Arbeitsverzeichnis
module Sketchup
  @erweiterungen = []
  @abrufe = []
  @verfaelschen = nil
  class << self
    attr_accessor :status_text, :erweiterungen, :abrufe, :verfaelschen
    def extensions = @erweiterungen
    def register_extension(ext, laden)
      @erweiterungen << ext
      ext.laden! if laden
    end
    def read_default(*) = nil
    def write_default(*) = nil
  end

  module Http
    GET = 'GET'.freeze
    Antwort = Struct.new(:status_code, :body)
    class Request
      attr_accessor :headers
      def initialize(url, _methode) = @url = url
      def start
        Sketchup.abrufe << @url
        yield self, Antwort.new(*Http.antworten(@url))
      end
    end

    def self.antworten(url)
      haupt = File.expand_path('../..', __dir__)
      dateien = Dir.chdir(haupt) { Dir.glob('**/*', File::FNM_DOTMATCH).reject { |f| f.start_with?('.git/') || File.directory?(f) } }
      case url
      when %r{/commits/main\z}
        [200, JSON.generate('sha' => 'abc123', 'commit' => { 'message' => "Test\n\nmehr", 'committer' => { 'date' => '2026-10-28T10:00:00Z' } })]
      when %r{/git/trees/abc123\?recursive=1\z}
        baum = dateien.map { |f| { 'path' => f, 'type' => 'blob', 'sha' => KuechenplanerUpdate.blob_sha(File.binread(File.join(haupt, f))) } }
        [200, JSON.generate('tree' => baum, 'truncated' => false)]
      when %r{\Ahttps://raw\.githubusercontent\.com/jimmycd/sketchup_kuechenplaner2/abc123/(.+)\z}
        pfad = Regexp.last_match(1).split('/').map { |s| URI.decode_www_form_component(s) }.join('/')
        daten = File.binread(File.join(haupt, pfad))
        daten = "#{daten}x" if Sketchup.verfaelschen == pfad
        [200, daten]
      else [404, '']
      end
    end
  end
end

Sketchup.active_model = Sketchup::Model.new
$VERBOSE = nil # neu laden überschreibt Konstanten

# Die Erweiterung selbst installieren wie SketchUp beim Start: nur sie ist da
src = File.join(haupt, 'kuechenplaner-update/src')
Dir.chdir(src) { Dir['**/*'].each { |f| File.directory?(f) ? FileUtils.mkdir_p(File.join(PLUGINS, f)) : FileUtils.cp(f, File.join(PLUGINS, f)) } }
load File.join(PLUGINS, 'kuechenplaner_update.rb')
KuechenplanerUpdate.plugins_ordner = PLUGINS
check(KuechenplanerUpdate.plugins_ordner == PLUGINS, 'Plugins-Ordner')

alle = IO.popen(['zipinfo', '-1', File.join(haupt, 'Kuechenplaner_alle.rbz')], &:read).split("\n").reject { |f| f.end_with?('/') }.sort
im_ordner = -> { Dir.chdir(PLUGINS) { Dir['**/*'].reject { |f| File.directory?(f) }.sort } }

# 1) Erstinstallation von GitHub: alle Dateien aus Kuechenplaner_alle.rbz, alle Erweiterungen geladen
UI.meldungen.clear
KuechenplanerUpdate.von_github
check(UI.meldungen.size == 2 && UI.meldungen.first.include?('Neue Version gefunden (GitHub main, Stand 2026-10-28 – Test)'),
      "Rückfrage mit Stand: #{UI.meldungen.first.inspect}")
check(UI.meldungen.last.to_s.start_with?('Aktualisiert'), "Abschluss: #{UI.meldungen.last.inspect}")
check(im_ordner.() == alle, "Plugins-Ordner = Kuechenplaner_alle.rbz: fehlt #{alle - im_ordner.()}, zu viel #{im_ordner.() - alle}")
alle.each { |f| check(File.binread(File.join(PLUGINS, f)) == IO.popen(['unzip', '-p', File.join(haupt, 'Kuechenplaner_alle.rbz'), f], &:read).b, "Inhalt #{f}") }
lader = alle.reject { |f| f.include?('/') }
check(Sketchup.erweiterungen.map { |e| File.basename(e.extension_path, '.rb') }.size == lader.size, "alle #{lader.size} Erweiterungen registriert")
check(Sketchup.erweiterungen.all?(&:loaded?), 'alle Erweiterungen geladen')
check(!Sketchup.abrufe.grep(/raw\.githubusercontent/).empty? && Sketchup.abrufe.grep(/raw\.githubusercontent/).all? { |u| u.include?('/abc123/') },
      'Download über den Commit, nicht über den Zweig')

# Menü: Komponenten, TCN-Export, dann Aktualisieren ganz unten
UI.timer_ablaufen if UI.respond_to?(:timer_ablaufen)

# 2) Nichts geändert: keine Rückfrage, keine Downloads
UI.meldungen.clear
Sketchup.abrufe.clear
KuechenplanerUpdate.von_github
check(UI.meldungen.size == 1 && UI.meldungen.first.start_with?('Alles aktuell'), "aktuell: #{UI.meldungen.inspect}")
check(Sketchup.abrufe.grep(/raw\.githubusercontent/).empty?, 'keine Downloads, wenn aktuell')

# 3) Eine Datei veraltet: nur sie wird geholt, nur ihre Erweiterung neu geladen
hs = File.join(PLUGINS, 'hochschrank/main.rb')
File.write(hs, File.read(hs) + "\n# alt\n")
UI.meldungen.clear
Sketchup.abrufe.clear
geladen = nil
KuechenplanerUpdate.define_singleton_method(:fertig) { |g, _q| geladen = g }
KuechenplanerUpdate.von_github
check(Sketchup.abrufe.grep(/raw\.githubusercontent/).map { |u| u[%r{abc123/(.+)}, 1] } == ['Komponenten/hochschrank/src/hochschrank/main.rb'],
      "nur hochschrank/main.rb geladen: #{Sketchup.abrufe.inspect}")
check(geladen == ['hochschrank'], "nur Hochschrank neu geladen: #{geladen.inspect}")
check(!File.read(hs).include?('# alt'), 'Datei ersetzt')

# 4) Ausgeschaltete Erweiterung wird nicht geladen
File.write(hs, File.read(hs) + "\n# alt\n")
Sketchup.erweiterungen.find { |e| e.extension_path.end_with?('hochschrank/main.rb') }.instance_variable_set(:@geladen, false)
KuechenplanerUpdate.von_github
check(geladen == [], "ausgeschaltet -> nicht laden: #{geladen.inspect}")
check(!File.read(hs).include?('# alt'), 'Datei trotzdem ersetzt')
Sketchup.erweiterungen.find { |e| e.extension_path.end_with?('hochschrank/main.rb') }.instance_variable_set(:@geladen, true)

# 5) Nein bei der Rückfrage: nichts ändern
File.write(hs, File.read(hs) + "\n# alt\n")
UI.antwort = 7
geladen = :nicht_aufgerufen
KuechenplanerUpdate.von_github
check(geladen == :nicht_aufgerufen && File.read(hs).include?('# alt'), 'Nein -> nichts geändert')
UI.antwort = IDYES

# 6) Falsche Prüfsumme: nichts schreiben
File.write(hs, File.read(hs) + "\n# alt\n")
apo = File.join(PLUGINS, 'apothekerschrank/main.rb')
File.write(apo, File.read(apo) + "\n# alt\n")
Sketchup.verfaelschen = 'Komponenten/hochschrank/src/hochschrank/main.rb'
UI.meldungen.clear
geladen = :nicht_aufgerufen
KuechenplanerUpdate.von_github
check(geladen == :nicht_aufgerufen && UI.meldungen.last.include?('Prüfsumme falsch'), "Prüfsumme: #{UI.meldungen.inspect}")
check(File.read(hs).include?('# alt') && File.read(apo).include?('# alt'), 'bei Fehler keine Datei geschrieben')
Sketchup.verfaelschen = nil

# 7) Aus lokalem Repo-Ordner: gleiche Dateien wie GitHub, auch die .skp (binär)
FileUtils.rm(File.join(PLUGINS, 'unterschrank_tuer/Unterschrank.skp'))
Sketchup.abrufe.clear
KuechenplanerUpdate.von_ordner(haupt)
check(Sketchup.abrufe.empty?, 'Ordner: kein Netz')
check(geladen == %w[apothekerschrank hochschrank unterschrank_tuer], "Ordner: neu geladen #{geladen.inspect}")
check(im_ordner.() == alle, 'Ordner: alle Dateien da')
check(File.binread(File.join(PLUGINS, 'unterschrank_tuer/Unterschrank.skp')) ==
      File.binread(File.join(haupt, 'Komponenten/unterschrank_tuer/src/unterschrank_tuer/Unterschrank.skp')), 'Ordner: .skp binär gleich')
UI.meldungen.clear
KuechenplanerUpdate.von_ordner(haupt)
check(UI.meldungen.last.to_s.start_with?('Alles aktuell'), 'Ordner: danach aktuell')
UI.meldungen.clear
KuechenplanerUpdate.von_ordner(stubs)
check(UI.meldungen.last.to_s.include?('keine Küchenplaner-Erweiterungen'), 'falscher Ordner wird gemeldet')

# 8) Neue Erweiterung (Lade-Datei fehlte) wird registriert und geladen
FileUtils.rm_r([File.join(PLUGINS, 'oberschrank.rb'), File.join(PLUGINS, 'oberschrank')])
Sketchup.erweiterungen.reject! { |e| e.extension_path.include?('/oberschrank/') }
$loaded.delete_if { |k, _| k.include?('oberschrank') } if defined?($loaded)
KuechenplanerUpdate.von_ordner(haupt)
check(geladen == ['oberschrank'], "neue Erweiterung geladen: #{geladen.inspect}")
check(Sketchup.erweiterungen.any? { |e| e.extension_path.end_with?('/oberschrank/main.rb') && e.loaded? }, 'neue Erweiterung registriert')

# 9) Mit Fehler beim Abruf: Meldung statt Absturz
def (Sketchup::Http).antworten(_url) = [500, '']
UI.meldungen.clear
KuechenplanerUpdate.von_github
check(UI.meldungen.last.to_s.include?('GitHub nicht erreichbar (HTTP 500)'), "Netzfehler: #{UI.meldungen.inspect}")

FileUtils.rm_rf([PLUGINS, stubs])
puts $fehler.zero? ? 'ALLE TESTS OK' : "#{$fehler} FEHLER"
exit($fehler.zero? ? 0 : 1)
