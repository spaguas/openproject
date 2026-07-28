# frozen_string_literal: true

class ContractBankOrderInvoice < ApplicationRecord
  belongs_to :bank_order, class_name: "ContractBankOrder"
  belongs_to :invoice, class_name: "ContractInvoice"

  validates :invoice_id, uniqueness: { scope: :bank_order_id }
end
