# frozen_string_literal: true

class OkrProgressEntry < ApplicationRecord
  belongs_to :kpi,
             class_name: "OkrKpi",
             inverse_of: :progress_entries
  belongs_to :author, class_name: "User"

  validates :recorded_on, :value, presence: true
  validates :value, numericality: true

  after_create :update_kpi_current_value

  delegate :project, to: :kpi

  private

  def update_kpi_current_value
    kpi.update_column(:current_value, value)
  end
end
