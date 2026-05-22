# frozen_string_literal: true

class OkrObjective < ApplicationRecord
  belongs_to :project

  has_many :kpis,
           class_name: "OkrKpi",
           foreign_key: :objective_id,
           inverse_of: :objective,
           dependent: :destroy

  normalizes :title, with: OpenProject::RemoveInvisibleCharacters

  validates :title, presence: true, length: { maximum: 255 }
  validate :target_date_not_before_start_date

  scope :visible, ->(user = User.current) {
    includes(:project)
      .references(:projects)
      .merge(Project.allowed_to(user, :view_okrs))
  }

  def visible?(user = User.current)
    user&.allowed_in_project?(:view_okrs, project)
  end

  private

  def target_date_not_before_start_date
    return if start_date.blank? || target_date.blank?
    return if target_date >= start_date

    errors.add :target_date, :greater_than_or_equal_to_start_date
  end
end
