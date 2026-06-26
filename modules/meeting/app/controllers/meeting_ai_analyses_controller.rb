# frozen_string_literal: true

class MeetingAIAnalysesController < ApplicationController
  include OpTurbo::FlashStreamHelper

  load_and_authorize_with_permission_in_project :edit_meetings

  before_action :set_meeting

  def update
    attributes = analysis_params
    if (message = pre_validation_error_message(attributes))
      flash[:error] = message
      redirect_to project_meeting_path(@project, @meeting, anchor: "meeting-ai-analysis")
      return
    end

    analysis = @meeting.ai_analysis || @meeting.build_ai_analysis
    call = Meetings::AiAnalysis::GenerateService
      .new(user: User.current, model: analysis)
      .call(attributes.merge(meeting: @meeting))

    flash[call.success? ? :notice : :error] =
      call.success? ? t("meeting.ai_analysis.notice.generated") : error_message(call)
    redirect_to project_meeting_path(@project, @meeting, anchor: "meeting-ai-analysis")
  end

  private

  def set_meeting
    @meeting = @project.meetings.visible.find(params[:meeting_id])
  end

  def analysis_params
    params.fetch(:meeting_ai_analysis, {})
      .permit(:provider, :model, :recording_reference, :recording_file, :transcript)
      .to_h
  end

  def error_message(call)
    call.message.presence ||
      call.errors.full_messages.to_sentence.presence ||
      t(:notice_internal_server_error)
  end

  def pre_validation_error_message(attributes)
    provider = attributes["provider"].presence || Meetings::AiAnalysis::Settings.provider

    if MeetingAiAnalysis::PROVIDERS.exclude?(provider)
      return t("meeting.ai_analysis.errors.invalid_provider")
    end

    unless Meetings::AiAnalysis::Settings.configured?(provider)
      return t("meeting.ai_analysis.errors.missing_token")
    end

    if attributes["transcript"].blank? && attributes["recording_file"].blank?
      return t("meeting.ai_analysis.errors.missing_input")
    end

    nil
  end
end

MeetingAiAnalysesController = MeetingAIAnalysesController unless defined?(MeetingAiAnalysesController)
