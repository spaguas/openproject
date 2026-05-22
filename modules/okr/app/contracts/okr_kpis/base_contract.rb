# frozen_string_literal: true

module OkrKpis
  class BaseContract < ::ModelContract
    def self.model
      OkrKpi
    end

    attribute :objective
    attribute :name
    attribute :description
    attribute :update_frequency
    attribute :unit
    attribute :baseline_value
    attribute :current_value
    attribute :target_value
    attribute :target_direction

    validate :user_allowed_to_manage

    private

    def user_allowed_to_manage
      return if model.project.nil?
      return if user.allowed_in_project?(:manage_okrs, model.project)

      errors.add :base, :error_unauthorized
    end
  end
end
