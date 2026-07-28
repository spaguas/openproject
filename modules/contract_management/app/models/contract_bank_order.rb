# frozen_string_literal: true

class ContractBankOrder < ApplicationRecord
  belongs_to :public_contract
  belongs_to :budget_commitment, class_name: "ContractBudgetCommitment", optional: true
  has_many :bank_order_invoices, class_name: "ContractBankOrderInvoice", foreign_key: :bank_order_id, dependent: :destroy
  has_many :invoices, through: :bank_order_invoices, source: :invoice

  validates :number, :issued_on, :amount, presence: true
  validates :number, uniqueness: { scope: :public_contract_id }
  validates :amount, numericality: { greater_than: 0 }
  validate :invoices_belong_to_contract
  validate :budget_commitment_belongs_to_contract
  validate :amount_within_commitment_balance

  private

  def invoices_belong_to_contract
    return if invoices.all? { |invoice| invoice.public_contract_id == public_contract_id }

    errors.add :invoices, :invalid
  end

  def budget_commitment_belongs_to_contract
    return if budget_commitment.blank? || budget_commitment.public_contract_id == public_contract_id

    errors.add :budget_commitment, :invalid
  end

  def amount_within_commitment_balance
    return if budget_commitment.blank? || amount.blank?

    previous_amount = persisted? ? amount_was.to_d : 0.to_d
    return if amount <= budget_commitment.remaining_amount + previous_amount

    errors.add :amount, :less_than_or_equal_to, count: budget_commitment.remaining_amount
  end
end
