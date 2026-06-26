# frozen_string_literal: true

class KpiMeasurement < ApplicationRecord
  belongs_to :kpi, inverse_of: :measurements
  belongs_to :author, class_name: "User", optional: true

  validates :value, :measured_at, presence: true
  validates :value, numericality: true
  validate :measured_at_not_in_future

  after_save :refresh_kpi_current_value
  after_destroy :refresh_kpi_current_value

  private

  def measured_at_not_in_future
    return if measured_at.blank? || measured_at.to_date <= Date.current

    errors.add(:measured_at, :not_in_future)
  end

  def refresh_kpi_current_value
    kpi.refresh_current_value!
  end
end
