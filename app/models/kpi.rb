# frozen_string_literal: true

class Kpi < ApplicationRecord
  DIRECTIONS = %w[increase decrease].freeze
  STATUSES = %w[not_started on_track at_risk off_track achieved paused].freeze

  belongs_to :project
  belongs_to :owner, class_name: "User", optional: true
  belongs_to :kpi_category, optional: true
  has_and_belongs_to_many :projects
  has_and_belongs_to_many :groups,
                          join_table: "groups_kpis",
                          association_foreign_key: "group_id"

  validates :name, presence: true, length: { maximum: 255 }
  validates :category, length: { maximum: 255 }
  validates :unit, length: { maximum: 50 }
  validates :current_value, :target_value, numericality: true
  validates :direction, inclusion: { in: DIRECTIONS }
  validates :status, inclusion: { in: STATUSES }
  validate :due_date_not_before_start_date

  scope :ordered, -> { order(Arel.sql("due_date ASC NULLS LAST"), :name) }
  scope :associated_with_project, ->(project) {
    left_outer_joins(:projects)
      .where(kpis: { project_id: project.id })
      .or(left_outer_joins(:projects).where(projects: { id: project.id }))
      .distinct
  }
  scope :visible, ->(user = User.current) {
    includes(:project).merge(Project.allowed_to(user, :view_kpis))
  }

  after_save :ensure_primary_project_association

  def visible?(user = User.current)
    user.present? && associated_projects.any? { |associated_project| user.allowed_in_project?(:view_kpis, associated_project) }
  end

  def associated_projects
    ([project] + projects.to_a).uniq
  end

  def category_name
    kpi_category&.name || category
  end

  def progress_percentage
    return 0 if target_value.blank? || target_value.zero?

    percentage =
      if direction == "decrease"
        current_value <= target_value ? 100 : (target_value / current_value) * 100
      else
        (current_value / target_value) * 100
      end

    percentage.clamp(0, 100).round
  end

  def overdue?
    due_date.present? && due_date < Date.current && status != "achieved"
  end

  def display_value(value)
    formatted = ActiveSupport::NumberHelper.number_to_rounded(value, precision: 2, strip_insignificant_zeros: true)
    unit.present? ? "#{formatted} #{unit}" : formatted
  end

  private

  def due_date_not_before_start_date
    return if start_date.blank? || due_date.blank? || due_date >= start_date

    errors.add(:due_date, :greater_than_or_equal_to, count: start_date)
  end

  def ensure_primary_project_association
    projects << project unless projects.exists?(project.id)
  end
end
