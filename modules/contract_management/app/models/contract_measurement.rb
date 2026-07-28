# frozen_string_literal: true

class ContractMeasurement < ApplicationRecord
  STATUSES = %w[pending approved rejected].freeze

  belongs_to :public_contract
  belongs_to :invoice, class_name: "ContractInvoice", optional: true

  validates :number, :measured_on, :amount, :status, presence: true
  validates :number, uniqueness: { scope: :public_contract_id }
  validates :amount, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: STATUSES }
  validates :approved_on, presence: true, if: -> { status == "approved" }
  validate :invoice_belongs_to_contract

  private

  def invoice_belongs_to_contract
    return if invoice.nil? || invoice.public_contract_id == public_contract_id

    errors.add :invoice, :invalid
  end
end
