# frozen_string_literal: true
#
# Aus rqrcode_core 2.1.0 übernommen (https://github.com/whomwah/rqrcode_core, MIT-Lizenz,
# Copyright (c) 2008 Duncan Robertson, siehe THIRD_PARTY.md). Geändert: Namensraum
# JTools::SchrankCnc::RQRCodeCore statt RQRCodeCore.

module JTools; module SchrankCnc; module RQRCodeCore
  NUMERIC = %w[0 1 2 3 4 5 6 7 8 9].freeze

  class QRNumeric
    def initialize(data)
      raise QRCodeArgumentError, "Not a numeric string `#{data}`" unless QRNumeric.valid_data?(data)

      @data = data
    end

    def self.valid_data?(data)
      (data.chars - NUMERIC).empty?
    end

    def write(buffer)
      buffer.numeric_encoding_start(@data.size)

      @data.size.times do |i|
        if i % 3 == 0
          chars = @data[i, 3]
          bit_length = get_bit_length(chars.length)
          buffer.put(get_code(chars), bit_length)
        end
      end
    end

    private

    NUMBER_LENGTH = {
      3 => 10,
      2 => 7,
      1 => 4
    }.freeze

    def get_bit_length(length)
      NUMBER_LENGTH[length]
    end

    def get_code(chars)
      chars.to_i
    end
  end
end
end; end
