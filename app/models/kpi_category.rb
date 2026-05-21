# frozen_string_literal: true

class KpiCategory < ApplicationRecord
  has_many :kpis, dependent: :nullify

  validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 255 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }
end
