# frozen_string_literal: true

module ProjectInitiationRequests
  class UpdateStatusService
    ALLOWED_TRANSITIONS = {
      "draft" => %w[submitted],
      "submitted" => %w[under_review],
      "under_review" => %w[needs_info approved rejected],
      "needs_info" => %w[submitted],
      "approved" => [],
      "rejected" => []
    }.freeze

    def initialize(user:, request:)
      @user = user
      @request = request
    end

    def call(to_status:, rejection_reason: nil)
      to_status = to_status.to_s

      return failure(:status, :invalid) unless transition_allowed?(to_status)
      return failure(:base, :error_unauthorized) unless user_allowed_for?(to_status)
      return failure(:rejection_reason, :blank) if reason_required?(to_status, rejection_reason)

      return approve if to_status == "approved"

      request.status = to_status
      request.rejection_reason = rejection_reason.presence if %w[needs_info rejected].include?(to_status)
      request.rejection_reason = nil if to_status == "submitted"

      validate_and_save
    end

    private

    attr_reader :user, :request

    def transition_allowed?(to_status)
      ALLOWED_TRANSITIONS.fetch(request.status, []).include?(to_status)
    end

    def user_allowed_for?(to_status)
      return user == request.author if to_status == "submitted"

      user.allowed_globally?(:approve_project_initiation_requests)
    end

    def reason_required?(to_status, rejection_reason)
      %w[needs_info rejected].include?(to_status) && rejection_reason.blank?
    end

    def approve
      ApproveService.new(user: user, request: request).call
    end

    def validate_and_save
      contract = OpenProject::ProjectInitiationRequest::Contract.new(request, user)

      return ServiceResult.failure(result: request, errors: request.errors) unless contract.valid?

      ServiceResult.new(success: request.save, result: request, errors: request.errors)
    end

    def failure(attribute, error)
      request.errors.add(attribute, error)
      ServiceResult.failure(result: request, errors: request.errors)
    end
  end
end
