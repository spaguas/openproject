# frozen_string_literal: true

module ProjectInitiationRequests
  class ApproveService
    def initialize(user:, request:)
      @user = user
      @request = request
    end

    def call
      return unauthorized unless user.allowed_globally?(:approve_project_initiation_requests)

      ProjectInitiationRequest.transaction do
        copy_call = copy_project

        unless copy_call.success?
          request.status = "under_review"
          request.errors.add(:base, copy_error_message(copy_call))
          raise ActiveRecord::Rollback
        end

        request.created_project = copy_call.result
        request.status = "approved"
        request.rejection_reason = nil

        contract = OpenProject::ProjectInitiationRequest::Contract.new(request, user)
        unless contract.valid? && request.save
          request.status = "under_review"
          raise ActiveRecord::Rollback
        end

        return ServiceResult.success(result: request)
      end

      ServiceResult.failure(result: request, errors: request.errors)
    end

    private

    attr_reader :user, :request

    def copy_project
      source_project = Project.find(request.template_project_id)
      copy_service = ::Projects::CopyService.new(
        user: user,
        source: source_project,
        contract_options: { skip_custom_field_validation: true }
      )

      copy_service.call(
        target_project_params: {
          name: request.title,
          identifier: unique_project_identifier,
          description: request.description
        },
        send_notifications: true,
        only: copyable_dependency_identifiers
      )
    end

    def unique_project_identifier
      @unique_project_identifier ||= IdentifierService.call(request.title, relation: Project)
    end

    def copyable_dependency_identifiers
      ::Projects::CopyService.copyable_dependencies.pluck(:identifier)
    end

    def unauthorized
      request.errors.add(:base, :error_unauthorized)
      ServiceResult.failure(result: request, errors: request.errors)
    end

    def copy_error_message(copy_call)
      copy_call.errors.full_messages.to_sentence.presence || I18n.t("project_initiation_requests.copy_failed")
    end
  end
end
