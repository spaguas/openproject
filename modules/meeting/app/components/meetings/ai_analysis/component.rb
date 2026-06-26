# frozen_string_literal: true

module Meetings
  module AiAnalysis
    class Component < ApplicationComponent
      include OpPrimer::ComponentHelpers

      def initialize(meeting:)
        super

        @meeting = meeting
        @project = meeting.project
        @analysis = meeting.ai_analysis || meeting.build_ai_analysis(
          provider: Settings.provider,
          model: Settings.model_for(Settings.provider)
        )
      end

      private

      def provider_options
        MeetingAiAnalysis::PROVIDERS.map do |provider|
          [I18n.t("meeting.ai_analysis.providers.#{provider}"), provider]
        end
      end

      def configured?
        Settings.configured?(@analysis.provider)
      end

      def render_result(icon, key, value)
        render(Primer::Beta::BorderBox.new(classes: "meeting-ai-analysis--result")) do |box|
          box.with_body do
            flex_layout(align_items: :flex_start) do |result|
              result.with_column(mr: 2) { render(Primer::Beta::Octicon.new(icon: icon, color: :accent)) }
              result.with_column(classes: "meeting-ai-analysis--result-content") do
                concat render(Primer::Beta::Text.new(font_weight: :bold)) { t("meeting.ai_analysis.results.#{key}") }
                concat tag.div(value.presence || t("meeting.ai_analysis.results.empty"), class: "mt-2")
              end
            end
          end
        end
      end
    end
  end

  AIAnalysis = AiAnalysis unless const_defined?(:AIAnalysis, false)
end
