# frozen_string_literal: true

class KpiMeasurement < ApplicationRecord
  belongs_to :kpi, inverse_of: :measurements
  belongs_to :author, class_name: "User"

  validates :value, :measured_at, presence: true
  validates :value, numericality: true

  after_create :refresh_kpi_current_value

  private

  def refresh_kpi_current_value
    kpi.refresh_current_value!
  end
end
