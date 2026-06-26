# frozen_string_literal: true

require "json"
require "net/http"
require "base64"

module Meetings
  module AiAnalysis
    class Client
      class ConfigurationError < StandardError; end

      def initialize(provider:, model:)
        @provider = provider
        @model = model.presence || Settings.model_for(provider)
        @api_token = Settings.api_token_for(provider)
      end

      def analyze(prompt)
        raise ConfigurationError, I18n.t("meeting.ai_analysis.errors.missing_token") if @api_token.blank?

        response = case @provider
                   when "gemini" then gemini_response(prompt)
                   else openai_response(prompt)
                   end

        JSON.parse(response)
      rescue JSON::ParserError
        { "insights" => response.to_s, "conclusions" => "", "next_steps" => "" }
      end

      def transcribe(recording_file)
        raise ConfigurationError, I18n.t("meeting.ai_analysis.errors.missing_token") if @api_token.blank?

        case @provider
        when "gemini" then gemini_transcription(recording_file)
        else openai_transcription(recording_file)
        end
      end

      private

      def openai_response(prompt)
        uri = URI("https://api.openai.com/v1/responses")
        response = post_json(
          uri,
          {
            model: @model,
            input: prompt
          },
          "Authorization" => "Bearer #{@api_token}"
        )

        body = JSON.parse(response.body)
        body["output_text"].presence || body.dig("output", 0, "content", 0, "text").to_s
      end

      def gemini_response(prompt)
        uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{@model}:generateContent")
        response = post_json(
          uri,
          {
            contents: [
              {
                parts: [
                  { text: prompt }
                ]
              }
            ],
            generationConfig: {
              responseMimeType: "application/json"
            }
          },
          "x-goog-api-key" => @api_token
        )

        body = JSON.parse(response.body)
        body.dig("candidates", 0, "content", "parts", 0, "text").to_s
      end

      def openai_transcription(recording_file)
        uri = URI("https://api.openai.com/v1/audio/transcriptions")
        request = Net::HTTP::Post.new(uri)
        request["Authorization"] = "Bearer #{@api_token}"
        request.set_form(
          [
            ["model", Settings.openai_transcription_model],
            ["file", recording_io(recording_file), { filename: recording_file.original_filename }]
          ],
          "multipart/form-data"
        )

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
        raise ConfigurationError, I18n.t("meeting.ai_analysis.errors.provider_error", status: response.code) unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body)["text"].to_s
      ensure
        recording_io(recording_file).rewind if recording_file.respond_to?(:tempfile)
      end

      def gemini_transcription(recording_file)
        io = recording_io(recording_file)
        io.rewind
        encoded_audio = Base64.strict_encode64(io.read)
        io.rewind

        uri = URI("https://generativelanguage.googleapis.com/v1beta/models/#{@model}:generateContent")
        response = post_json(
          uri,
          {
            contents: [
              {
                parts: [
                  { text: I18n.t("meeting.ai_analysis.transcription_prompt") },
                  {
                    inline_data: {
                      mime_type: recording_file.content_type,
                      data: encoded_audio
                    }
                  }
                ]
              }
            ]
          },
          "x-goog-api-key" => @api_token
        )

        body = JSON.parse(response.body)
        body.dig("candidates", 0, "content", "parts", 0, "text").to_s
      end

      def recording_io(recording_file)
        recording_file.respond_to?(:tempfile) ? recording_file.tempfile : recording_file
      end

      def post_json(uri, body, headers)
        request = Net::HTTP::Post.new(uri)
        request["Content-Type"] = "application/json"
        headers.each { |key, value| request[key] = value }
        request.body = JSON.dump(body)

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |http| http.request(request) }
        return response if response.is_a?(Net::HTTPSuccess)

        raise ConfigurationError, I18n.t("meeting.ai_analysis.errors.provider_error", status: response.code)
      end
    end
  end

  AIAnalysis = AiAnalysis unless const_defined?(:AIAnalysis, false)
end
