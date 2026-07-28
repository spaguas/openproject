# frozen_string_literal: true

require "date"
require "json"
require "uri"

module ContractManagement
  module InvoiceExtraction
    class FieldParser
      IR_PERCENTAGE_PATTERN =
        /(?:IRRF\b|IR\s*\(\s*R\s*\))[^\n%]{0,24}?([\d.,]+)\s*%/i
      IR_WITHHELD_AMOUNT_PATTERN =
        /RETEN[CÇ][AÃ]O\s+NA\s+FONTE\s+IRRF\s*[:-]?\s*R?\$?\s*([\d.,]+)/i

      FIELD_KEYS = {
        "numero" => "Número",
        "number" => "Número",
        "numnf" => "Número",
        "valor" => "Valor total",
        "valortotal" => "Valor total",
        "gross_amount" => "Valor total",
        "emissao" => "Data de emissão",
        "dataemissao" => "Data de emissão",
        "issued_on" => "Data de emissão",
        "vencimento" => "Vencimento",
        "due_on" => "Vencimento",
        "percentualimposto" => "IR (R)",
        "tax_percentage" => "IR (R)"
      }.freeze

      def initialize(raw_text)
        @text = normalize_payload(raw_text.to_s)
      end

      def call
        {
          "number" => invoice_number,
          "gross_amount" => gross_amount,
          "issued_on" => issued_on,
          "due_on" => due_on,
          "tax_percentage" => tax_percentage
        }.compact
      end

      def summary?
        data = call
        data["number"].present? && (data["gross_amount"].present? || data["issued_on"].present?)
      end

      private

      attr_reader :text

      def invoice_number
        capture(
          /N[uú]mero\s+da\s+Nota(?:\s*\/\s*S[eé]rie)?\s*[:-]?\s*\n?\s*([A-Z0-9.\/-]+)/i,
          /N[uú]mero\s*[:-]\s*([A-Z0-9.\/-]+)/i,
          /(?:NFS?-?e|Nota\s+Fiscal)\s*(?:n[º°o.]*)?\s*[:-]?\s*([A-Z0-9.\/-]+)/i
        )
      end

      def gross_amount
        value = capture(
          /VALOR\s+TOTAL\s+DA\s+NOTA\s*=\s*R?\$?\s*([\d.,]+)/i,
          /VALOR\s+TOTAL\s*[:-]?\s*R?\$?\s*([\d.,]+)/i,
          /VALOR\s+DA\s+NOTA\s*[:-]?\s*R?\$?\s*([\d.,]+)/i
        )
        decimal(value)
      end

      def issued_on
        value = capture(
          /Data(?:\s+e\s+Hora)?\s+de\s+Emiss[aã]o\s*[:-]?\s*\n?\s*(\d{2}\/\d{2}\/\d{4})/i,
          /Emitid[ao]\s+em\s*[:-]?\s*(\d{2}\/\d{2}\/\d{4})/i
        )
        date(value)
      end

      def due_on
        date(capture(/VENCIMENTO\s*[:-]?\s*(\d{2}\/\d{2}\/\d{4})/i))
      end

      def tax_percentage
        explicit_percentage = decimal(capture(IR_PERCENTAGE_PATTERN))
        return explicit_percentage if explicit_percentage

        withheld_amount = decimal(capture(IR_WITHHELD_AMOUNT_PATTERN))
        total = gross_amount
        (withheld_amount / total * 100).round(4) if withheld_amount && total&.positive?
      end

      def capture(*patterns)
        patterns.each do |pattern|
          value = text.match(pattern)&.captures&.first
          return value.strip if value.present?
        end
        nil
      end

      def decimal(value)
        return if value.blank?

        normalized = value.delete(" ")
        normalized = normalized.delete(".").tr(",", ".") if normalized.include?(",")
        BigDecimal(normalized).to_f
      rescue ArgumentError
        nil
      end

      def date(value)
        Date.strptime(value, "%d/%m/%Y").iso8601 if value.present?
      rescue Date::Error
        nil
      end

      def normalize_payload(raw)
        json = JSON.parse(raw)
        labeled_text(json) if json.is_a?(Hash)
      rescue JSON::ParserError
        query_as_text(raw) || raw
      end

      def query_as_text(raw)
        uri = URI.parse(raw.strip)
        return if uri.query.blank?

        labeled_text(URI.decode_www_form(uri.query).to_h)
      rescue URI::InvalidURIError
        nil
      end

      def labeled_text(values)
        values.filter_map do |key, value|
          normalized_key = key.to_s.downcase.gsub(/[^a-z_]/, "")
          label = FIELD_KEYS[normalized_key]
          "#{label}: #{value}" if label
        end.join("\n")
      end
    end
  end
end
