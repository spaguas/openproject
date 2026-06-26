# frozen_string_literal: true

class MeetingAiAnalysis < ApplicationRecord
  PROVIDERS = %w[openai gemini].freeze
  STATUSES = %w[draft processing completed failed].freeze

  belongs_to :meeting
  belongs_to :generated_by, class_name: "User", optional: true

  validates :provider, inclusion: { in: PROVIDERS }
  validates :status, inclusion: { in: STATUSES }
  validates :transcript, presence: true, if: :completed_or_processing?

  def completed?
    status == "completed"
  end

  def failed?
    status == "failed"
  end

  private

  def completed_or_processing?
    %w[processing completed].include?(status)
  end
end

MeetingAIAnalysis = MeetingAiAnalysis unless defined?(MeetingAIAnalysis)
