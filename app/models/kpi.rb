# frozen_string_literal: true

class Kpi < ApplicationRecord
  DIRECTIONS = %w[increase decrease].freeze
  MEASUREMENT_FREQUENCIES = %w[daily weekly biweekly monthly quarterly semiannual annual].freeze
  STATUSES = %w[not_started on_track at_risk off_track achieved paused].freeze

  belongs_to :project
  belongs_to :owner, class_name: "User", optional: true
  belongs_to :kpi_category, optional: true
  has_many :measurements,
           -> { order(measured_at: :desc, created_at: :desc, id: :desc) },
           class_name: "KpiMeasurement",
           inverse_of: :kpi,
           dependent: :destroy
  has_and_belongs_to_many :projects
  has_and_belongs_to_many :groups,
                          join_table: "groups_kpis",
                          association_foreign_key: "group_id"

  validates :name, presence: true, length: { maximum: 255 }
  validates :category, length: { maximum: 255 }
  validates :unit, length: { maximum: 50 }
  validates :current_value, :target_value, numericality: true
  validates :direction, inclusion: { in: DIRECTIONS }
  validates :measurement_frequency, inclusion: { in: MEASUREMENT_FREQUENCIES }
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
    allowed_project_ids = Project.allowed_to(user, :view_kpis).select(:id)

    left_outer_joins(:projects)
      .where(project_id: allowed_project_ids)
      .or(left_outer_joins(:projects).where(projects: { id: allowed_project_ids }))
      .distinct
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
    progress_for_value(current_value)
  end

  def progress_for_value(value)
    return 0 if target_value.blank? || target_value.zero?

    percentage =
      if direction == "decrease"
        value <= target_value ? 100 : (target_value / value) * 100
      else
        (value / target_value) * 100
      end

    percentage.clamp(0, 100).round
  end

  def latest_measurement
    KpiMeasurement
      .where(kpi_id: id)
      .order(measured_at: :desc, created_at: :desc, id: :desc)
      .first
  end

  def refresh_current_value!
    latest_value = latest_measurement&.value
    update_column(:current_value, latest_value) if latest_value.present? && current_value != latest_value
  end

  def next_measurement_at
    measurement = latest_measurement
    return if measurement.blank?

    measurement.measured_at.advance(**measurement_frequency_advance)
  end

  def overdue?
    due_date.present? && due_date < Date.current && status != "achieved"
  end

  def display_value(value)
    formatted = ActiveSupport::NumberHelper.number_to_rounded(value, precision: 2, strip_insignificant_zeros: true)
    unit.present? ? "#{formatted} #{unit}" : formatted
  end

  private

  def measurement_frequency_advance
    case measurement_frequency
    when "daily" then { days: 1 }
    when "weekly" then { weeks: 1 }
    when "biweekly" then { weeks: 2 }
    when "quarterly" then { months: 3 }
    when "semiannual" then { months: 6 }
    when "annual" then { years: 1 }
    else { months: 1 }
    end
  end

  def due_date_not_before_start_date
    return if start_date.blank? || due_date.blank? || due_date >= start_date

    errors.add(:due_date, :greater_than_or_equal_to, count: start_date)
  end

  def ensure_primary_project_association
    projects << project unless projects.exists?(project.id)
  end
end
