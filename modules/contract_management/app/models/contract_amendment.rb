# frozen_string_literal: true

class ContractAmendment < ApplicationRecord
  belongs_to :public_contract

  validates :number, :start_date, :duration_months, :amount, :description, presence: true
  validates :number, uniqueness: { scope: :public_contract_id }
  validates :duration_months, numericality: { only_integer: true, greater_than: 0 }
  validates :amount, numericality: true
end
