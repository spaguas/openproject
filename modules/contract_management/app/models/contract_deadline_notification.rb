# frozen_string_literal: true

class ContractDeadlineNotification < ApplicationRecord
  TYPES = %w[contract invoice].freeze

  belongs_to :public_contract
  belongs_to :invoice, class_name: "ContractInvoice", optional: true

  validates :deadline_type, inclusion: { in: TYPES }
  validates :deadline_on, :sent_on, presence: true
end
