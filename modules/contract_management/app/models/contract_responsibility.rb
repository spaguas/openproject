# frozen_string_literal: true

class ContractResponsibility < ApplicationRecord
  ROLES = %w[manager inspector].freeze

  belongs_to :public_contract
  belongs_to :user

  validates :role, :starts_on, presence: true
  validates :role, inclusion: { in: ROLES }
  validates :user_id, uniqueness: { scope: %i[public_contract_id role starts_on] }
  validate :ends_on_not_before_starts_on

  scope :active_on, ->(date) { where(starts_on: ..date).where("ends_on IS NULL OR ends_on >= ?", date) }
  scope :notifiable, -> { where(notify: true) }

  private

  def ends_on_not_before_starts_on
    return if starts_on.blank? || ends_on.blank? || ends_on >= starts_on

    errors.add :ends_on, :greater_than_or_equal_to_starts_on
  end
end
