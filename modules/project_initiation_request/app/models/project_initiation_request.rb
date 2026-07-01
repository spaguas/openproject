# frozen_string_literal: true

class ProjectInitiationRequest < ApplicationRecord
  STATUSES = %w[draft submitted under_review needs_info approved rejected].freeze
  EDITABLE_STATUSES = %w[draft needs_info].freeze

  belongs_to :author, class_name: "User"
  belongs_to :template_project, class_name: "Project"
  belongs_to :created_project, class_name: "Project", optional: true

  scope :visible_to, lambda { |user|
    if user.allowed_globally?(:approve_project_initiation_requests)
      all
    else
      where(author: user)
    end
  }
end
