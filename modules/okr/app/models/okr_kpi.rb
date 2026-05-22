# frozen_string_literal: true

class OkrKpi < ApplicationRecord
  belongs_to :objective,
             class_name: "OkrObjective",
             inverse_of: :kpis

  has_many :progress_entries,
           class_name: "OkrProgressEntry",
           foreign_key: :kpi_id,
           inverse_of: :kpi,
           dependent: :destroy

  enum :update_frequency, {
    daily: "daily",
    weekly: "weekly",
    monthly: "monthly",
    quarterly: "quarterly"
  }

  enum :target_direction, {
    increase: "increase",
    decrease: "decrease"
  }, prefix: :target

  normalizes :name, with: OpenProject::RemoveInvisibleCharacters

  validates :name, presence: true, length: { maximum: 255 }
  validates :update_frequency, :target_direction, presence: true
  validates :baseline_value, :current_value, :target_value, presence: true, numericality: true

  before_validation :initialize_current_value, on: :create

  delegate :project, to: :objective

  def progress_percentage
    movement = target_value - baseline_value
    return if movement.zero?

    (((current_value - baseline_value) / movement) * 100).round
  end

  private

  def initialize_current_value
    self.current_value = baseline_value if current_value.blank?
  end
end
