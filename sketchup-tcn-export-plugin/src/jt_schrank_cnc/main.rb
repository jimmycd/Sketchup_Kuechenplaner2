# encoding: UTF-8
# Schrank-CNC – Hauptmodul: lädt die Untermodule und legt das Menü an.

require 'sketchup.rb'

module JTools
  module SchrankCnc
    PATH = File.dirname(__FILE__) unless defined?(PATH)

    %w[schraenke frontfarbe].each { |f| load File.join(PATH, "#{f}.rb") }

    unless file_loaded?(__FILE__)
      menu = UI.menu('Extensions').add_submenu('Schrank-CNC')
      menu.add_item('Frontfarbe und Griffe ändern…') { Frontfarbe.dialog }
      file_loaded(__FILE__)
    end
  end
end
