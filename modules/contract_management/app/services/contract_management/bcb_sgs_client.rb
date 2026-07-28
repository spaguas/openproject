# frozen_string_literal: true

require "net/http"
require "json"

module ContractManagement
  class BcbSgsClient
    BASE_URI = URI("https://api.bcb.gov.br").freeze

    class RequestError < StandardError; end

    def values(series_code:, from:, to:)
      uri = BASE_URI.dup
      uri.path = "/dados/serie/bcdata.sgs.#{Integer(series_code)}/dados"
      uri.query = URI.encode_www_form(
        formato: "json",
        dataInicial: from.strftime("%d/%m/%Y"),
        dataFinal: to.strftime("%d/%m/%Y")
      )

      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: true,
        open_timeout: 10,
        read_timeout: 30
      ) { |http| http.get(uri.request_uri, "Accept" => "application/json") }

      raise RequestError, "BCB SGS returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body).map do |entry|
        {
          date: Date.strptime(entry.fetch("data"), "%d/%m/%Y"),
          value: BigDecimal(entry.fetch("valor"))
        }
      end
    rescue JSON::ParserError, KeyError, ArgumentError => e
      raise RequestError, "Invalid BCB SGS response: #{e.message}"
    end
  end
end
