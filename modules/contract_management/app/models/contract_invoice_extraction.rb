# frozen_string_literal: true

class ContractInvoiceExtraction < ApplicationRecord
  STATUSES = %w[pending processing completed failed].freeze

  belongs_to :public_contract
  belongs_to :user
  delegate :project, to: :public_contract

  acts_as_attachable view_permission: :view_contracts,
                     delete_permission: :manage_contracts,
                     add_permission: :manage_contracts

  validates :status, inclusion: { in: STATUSES }
end
