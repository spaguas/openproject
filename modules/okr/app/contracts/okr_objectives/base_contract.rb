# frozen_string_literal: true

module OkrObjectives
  class BaseContract < ::ModelContract
    include UnchangedProject

    def self.model
      OkrObjective
    end

    attribute :project
    attribute :title
    attribute :description
    attribute :start_date
    attribute :target_date

    validate :user_allowed_to_manage

    private

    def user_allowed_to_manage
      return if model.project.nil?
      return validate_new_record_permission if model.new_record?

      validate_existing_project_permission
      validate_destination_project_permission
    end

    def validate_new_record_permission
      errors.add :base, :error_unauthorized unless user.allowed_in_project?(:manage_okrs, model.project)
    end

    def validate_existing_project_permission
      with_unchanged_project_id do
        errors.add :base, :error_unauthorized unless user.allowed_in_project?(:manage_okrs, model.project)
      end
    end

    def validate_destination_project_permission
      return unless model.project_id_changed?
      return if user.allowed_in_project?(:manage_okrs, model.project)

      errors.add :base, :error_unauthorized
    end
  end
end
