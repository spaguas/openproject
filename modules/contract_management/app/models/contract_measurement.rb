# frozen_string_literal: true

class ContractMeasurement < ApplicationRecord
  STATUSES = %w[pending approved rejected].freeze

  belongs_to :public_contract
  belongs_to :invoice, class_name: "ContractInvoice", optional: true
  belongs_to :approved_by, class_name: "User", optional: true
  has_many :contract_notifications, as: :subject, dependent: :destroy

  validates :number, :measured_on, :amount, :status, presence: true
  validates :number, uniqueness: { scope: :public_contract_id }
  validates :amount, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: STATUSES }
  validates :approved_on, presence: true, if: -> { status == "approved" }
  validates :approved_by, presence: true, if: -> { status == "approved" }
  validate :invoice_belongs_to_contract
  validate :approved_by_is_contract_responsible

  before_create :set_evaluation_due_on

  def pending_evaluation?
    status == "pending"
  end

  private

  def set_evaluation_due_on
    self.evaluation_due_on ||= ContractManagement::BusinessDayCalculator.add(
      Date.current,
      public_contract.measurement_evaluation_business_days
    )
  end

  def invoice_belongs_to_contract
    return if invoice.nil? || invoice.public_contract_id == public_contract_id

    errors.add :invoice, :invalid
  end

  def approved_by_is_contract_responsible
    return unless status == "approved" && approved_by.present? && public_contract.present?
    return if public_contract.manager_or_inspector?(approved_by, on: approved_on || Date.current)

    errors.add :approved_by, :not_contract_responsible
  end
end
