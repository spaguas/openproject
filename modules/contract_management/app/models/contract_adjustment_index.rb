# frozen_string_literal: true

class ContractAdjustmentIndex < ApplicationRecord
  PERIODICITIES = %w[monthly annual quarterly semiannual biennial].freeze
  PERIOD_MONTHS = {
    "monthly" => 1,
    "annual" => 12,
    "quarterly" => 3,
    "semiannual" => 6,
    "biennial" => 24
  }.freeze
  KNOWN_BCB_SERIES = {
    "IPCA" => 433,
    "INPC" => 188,
    "IGP-M" => 189,
    "IGPM" => 189
  }.freeze

  belongs_to :project
  belongs_to :contract_adjustment_index_type, optional: true, inverse_of: :adjustment_indices
  has_many :public_contracts, dependent: :restrict_with_error

  normalizes :name, with: ->(value) { OpenProject::RemoveInvisibleCharacters.call(value)&.strip }

  validates :name, :year, :month, :percentage, :periodicity, presence: true
  validates :name, uniqueness: { scope: %i[project_id year month], case_sensitive: false }
  validates :year, numericality: { only_integer: true, greater_than: 1900, less_than: 3000 }
  validates :month, numericality: { only_integer: true, in: 1..12 }
  validates :percentage, numericality: true
  validates :periodicity, inclusion: { in: PERIODICITIES }
  validates :external_series_code, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  scope :between_periods, ->(start_date, end_date) {
    start_period = (start_date.year * 12) + start_date.month
    end_period = (end_date.year * 12) + end_date.month
    where("(year * 12 + month) BETWEEN ? AND ?", start_period, end_period)
  }

  def period_months
    PERIOD_MONTHS.fetch(periodicity)
  end

  def bcb_series_code
    contract_adjustment_index_type&.external_series_code || external_series_code || KNOWN_BCB_SERIES[normalized_name]
  end

  def period
    Date.new(year, month, 1)
  end

  private

  def normalized_name
    name.to_s.upcase.gsub(/[^A-Z0-9-]/, "")
  end
end
