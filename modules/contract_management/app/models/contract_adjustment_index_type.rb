# frozen_string_literal: true

class ContractAdjustmentIndexType < ApplicationRecord
  PERIODICITIES = ContractAdjustmentIndex::PERIODICITIES
  PERIOD_MONTHS = ContractAdjustmentIndex::PERIOD_MONTHS

  belongs_to :project
  has_many :adjustment_indices,
           class_name: "ContractAdjustmentIndex",
           dependent: :restrict_with_error,
           inverse_of: :contract_adjustment_index_type
  has_many :public_contracts, dependent: :restrict_with_error

  normalizes :name, with: ->(value) { OpenProject::RemoveInvisibleCharacters.call(value)&.strip }

  validates :name, :external_series_code, :periodicity, presence: true
  validates :name, uniqueness: { scope: :project_id, case_sensitive: false }
  validates :external_series_code,
            numericality: { only_integer: true, greater_than: 0 },
            uniqueness: { scope: :project_id }
  validates :periodicity, inclusion: { in: PERIODICITIES }

  scope :active, -> { where(active: true) }

  def period_months
    PERIOD_MONTHS.fetch(periodicity)
  end
end
