# frozen_string_literal: true

module OkrProgressEntries
  class BaseContract < ::ModelContract
    def self.model
      OkrProgressEntry
    end

    attribute :kpi
    attribute :author
    attribute :value
    attribute :recorded_on
    attribute :note

    validate :user_allowed_to_manage

    private

    def user_allowed_to_manage
      return if model.project.nil?
      return if user.allowed_in_project?(:manage_okrs, model.project)

      errors.add :base, :error_unauthorized
    end
  end
end
