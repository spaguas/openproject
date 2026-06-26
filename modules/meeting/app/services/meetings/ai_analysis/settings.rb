# frozen_string_literal: true

module Meetings
  module AiAnalysis
    class Settings
      DEFAULT_PROVIDER = "openai"
      DEFAULT_OPENAI_MODEL = "gpt-4.1-mini"
      DEFAULT_OPENAI_TRANSCRIPTION_MODEL = "gpt-4o-mini-transcribe"
      DEFAULT_GEMINI_MODEL = "gemini-3.5-flash"

      class << self
        def provider
          plugin_settings["provider"].presence || DEFAULT_PROVIDER
        end

        def model_for(provider)
          key = provider == "gemini" ? "gemini_model" : "openai_model"
          plugin_settings[key].presence || default_model_for(provider)
        end

        def api_token_for(provider)
          key = provider == "gemini" ? "gemini_api_token" : "openai_api_token"
          plugin_settings[key].presence || ENV.fetch(env_key_for(provider), nil)
        end

        def openai_transcription_model
          plugin_settings["openai_transcription_model"].presence || DEFAULT_OPENAI_TRANSCRIPTION_MODEL
        end

        def configured?(provider = self.provider)
          api_token_for(provider).present?
        end

        def default_model_for(provider)
          provider == "gemini" ? DEFAULT_GEMINI_MODEL : DEFAULT_OPENAI_MODEL
        end

        def plugin_settings
          Setting.plugin_openproject_meeting || {}
        end

        private

        def env_key_for(provider)
          provider == "gemini" ? "GEMINI_API_KEY" : "OPENAI_API_KEY"
        end
      end
    end
  end

  AIAnalysis = AiAnalysis unless const_defined?(:AIAnalysis, false)
end
