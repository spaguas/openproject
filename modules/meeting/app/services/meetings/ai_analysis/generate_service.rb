# frozen_string_literal: true

module Meetings
  module AiAnalysis
    class GenerateService
      def initialize(user:, model:)
        @user = user
        @model = model
      end

      def call(attributes)
        @meeting = attributes.delete(:meeting)
        recording_file = attributes.delete("recording_file") || attributes.delete(:recording_file)
        provider = attributes["provider"].presence || Settings.provider
        model_name = attributes["model"].presence || Settings.model_for(provider)
        client = Client.new(provider: provider, model: model_name)

        if attributes["transcript"].blank? && recording_file.present?
          attributes["transcript"] = client.transcribe(recording_file)
          attributes["recording_reference"] = recording_file.original_filename if attributes["recording_reference"].blank?
        end

        model.assign_attributes(attributes.merge(provider: provider, model: model_name, generated_by: user, status: "processing"))
        return ServiceResult.failure(result: model, errors: model.errors) unless model.valid?

        result = client.analyze(prompt_for(model))
        model.assign_attributes(
          insights: result["insights"],
          conclusions: result["conclusions"],
          next_steps: result["next_steps"],
          status: "completed",
          error_message: nil
        )
        model.save!

        ServiceResult.success(result: model)
      rescue StandardError => e
        model.assign_attributes(status: "failed", error_message: e.message)
        model.save(validate: false) if model.meeting.present?
        ServiceResult.failure(result: model, message: e.message)
      end

      private

      attr_reader :user, :model

      def prompt_for(analysis)
        <<~PROMPT
          Analise a transcrição da reunião abaixo e responda somente em JSON válido com as chaves:
          insights, conclusions e next_steps. Use português do Brasil, seja objetivo e foque em decisões,
          riscos, dependências, encaminhamentos e próximos passos acionáveis.

          Projeto: #{@meeting.project&.name}
          Reunião: #{@meeting.title}
          Gravação/referência: #{analysis.recording_reference}

          Transcrição:
          #{analysis.transcript}
        PROMPT
      end
    end
  end

  AIAnalysis = AiAnalysis unless const_defined?(:AIAnalysis, false)
end
