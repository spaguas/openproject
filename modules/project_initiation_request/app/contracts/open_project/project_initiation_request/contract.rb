# frozen_string_literal: true

module OpenProject::ProjectInitiationRequest
  class Contract < ::ModelContract
    CORE_FIELDS = %w[
      title
      identifier
      description
      business_case
      estimated_budget
      target_start_date
      target_end_date
      template_project_id
    ].freeze

    def self.model
      ::ProjectInitiationRequest
    end

    attribute :title
    attribute :identifier
    attribute :description
    attribute :business_case
    attribute :estimated_budget
    attribute :target_start_date
    attribute :target_end_date
    attribute :status
    attribute :rejection_reason
    attribute :author
    attribute :template_project
    attribute :created_project

    validates :title, presence: true, length: { minimum: 5, maximum: 255 }
    validates :identifier, presence: true, length: { maximum: 255 }
    validates :description, presence: true
    validates :business_case, presence: true
    validates :estimated_budget,
              presence: true,
              numericality: { greater_than_or_equal_to: 0, less_than: 10_000_000_000 }
    validates :target_start_date, presence: true
    validates :target_end_date, presence: true
    validates :status, inclusion: { in: ::ProjectInitiationRequest::STATUSES }
    validates :template_project, presence: true

    validate :target_end_date_not_before_start
    validate :user_allowed_to_save
    validate :core_fields_mutable_only_in_editable_states
    validate :status_mutation_allowed

    private

    def target_end_date_not_before_start
      return if model.target_start_date.blank? || model.target_end_date.blank?
      return if model.target_end_date >= model.target_start_date

      errors.add :target_end_date, :greater_than_or_equal_to, count: model.target_start_date
    end

    def user_allowed_to_save
      return if can_create_request? || can_approve_requests?

      errors.add :base, :error_unauthorized
    end

    def core_fields_mutable_only_in_editable_states
      return if model.new_record?
      return if changed_core_fields.empty?
      return if author_can_edit_core_fields?

      changed_core_fields.each { |field| errors.add field, :error_readonly }
    end

    def status_mutation_allowed
      return if model.new_record?
      return unless model.status_changed?

      previous_status = model.status_was
      next_status = model.status

      return if author_resubmission?(previous_status, next_status)
      return if reviewer_transition?(next_status)

      errors.add :status, :error_unauthorized
    end

    def changed_core_fields
      model.changed & CORE_FIELDS
    end

    def author_can_edit_core_fields?
      user == model.author && ::ProjectInitiationRequest::EDITABLE_STATUSES.include?(model.status_was)
    end

    def author_resubmission?(previous_status, next_status)
      user == model.author &&
        %w[draft needs_info].include?(previous_status) &&
        next_status == "submitted"
    end

    def reviewer_transition?(next_status)
      can_approve_requests? && %w[under_review needs_info approved rejected].include?(next_status)
    end

    def can_create_request?
      user.allowed_globally?(:create_project_initiation_requests)
    end

    def can_approve_requests?
      user.allowed_globally?(:approve_project_initiation_requests)
    end
  end
end
