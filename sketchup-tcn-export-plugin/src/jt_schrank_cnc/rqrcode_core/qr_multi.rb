# frozen_string_literal: true
#
# Aus rqrcode_core 2.1.0 übernommen (https://github.com/whomwah/rqrcode_core, MIT-Lizenz,
# Copyright (c) 2008 Duncan Robertson, siehe THIRD_PARTY.md). Geändert: Namensraum
# JTools::SchrankCnc::RQRCodeCore statt RQRCodeCore.

module JTools; module SchrankCnc; module RQRCodeCore
  class QRMulti
    def initialize(data)
      @data = data
    end

    def write(buffer)
      @data.each { |seg| seg.writer.write(buffer) }
    end
  end
end
end; end
