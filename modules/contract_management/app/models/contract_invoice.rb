# frozen_string_literal: true

class ContractInvoice < ApplicationRecord
  STATUSES = %w[pending paid overdue cancelled].freeze

  belongs_to :public_contract
  delegate :project, to: :public_contract
  acts_as_attachable view_permission: :view_contracts,
                     delete_permission: :manage_contracts,
                     add_permission: :manage_contracts
  has_many :measurements,
           class_name: "ContractMeasurement",
           foreign_key: :invoice_id,
           dependent: :nullify,
           inverse_of: :invoice
  has_many :bank_order_invoices,
           class_name: "ContractBankOrderInvoice",
           foreign_key: :invoice_id,
           dependent: :destroy,
           inverse_of: :invoice
  has_many :bank_orders, through: :bank_order_invoices, source: :bank_order

  validates :number, :gross_amount, :net_amount, :issued_on, :due_on, :status, presence: true
  validates :number, uniqueness: { scope: :public_contract_id }
  validates :status, inclusion: { in: STATUSES }
  validates :gross_amount, :net_amount, numericality: { greater_than_or_equal_to: 0 }
  validates :tax_percentage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validate :due_on_not_before_issued_on
  validate :net_amount_matches_tax

  before_validation :recalculate_net_amount, if: -> { gross_amount.present? && tax_percentage.present? }

  scope :due_between, ->(from, to) { where(status: "pending", due_on: from..to) }

  def tax_amount
    gross_amount - net_amount
  end

  def recalculate_net_amount
    return if gross_amount.blank? || tax_percentage.blank?

    self.net_amount = (gross_amount * (1 - (tax_percentage / 100))).round(2)
  end

  private

  def due_on_not_before_issued_on
    return if issued_on.blank? || due_on.blank? || due_on >= issued_on

    errors.add :due_on, :greater_than_or_equal_to_issued_on
  end

  def net_amount_matches_tax
    return if gross_amount.blank? || net_amount.blank? || net_amount <= gross_amount

    errors.add :net_amount, :less_than_or_equal_to_gross_amount
  end
end
