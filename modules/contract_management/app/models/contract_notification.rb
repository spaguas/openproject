# frozen_string_literal: true

class ContractNotification < ApplicationRecord
  KINDS = %w[measurement_created measurement_evaluation_due commitment_consumption].freeze

  belongs_to :public_contract
  belongs_to :subject, polymorphic: true

  validates :kind, inclusion: { in: KINDS }
  validates :sent_on, presence: true
  validates :kind, uniqueness: { scope: %i[subject_type subject_id] }
end
