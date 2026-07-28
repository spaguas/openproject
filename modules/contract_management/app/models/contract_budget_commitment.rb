# frozen_string_literal: true

class ContractBudgetCommitment < ApplicationRecord
  MONTHS = (1..12)
  KINDS = %w[appropriation future].freeze
  STATUSES = %w[active exhausted cancelled converted].freeze
  DISTRIBUTION_MODES = %w[automatic manual].freeze

  belongs_to :public_contract
  belongs_to :responsible, class_name: "User"
  belongs_to :source_commitment, class_name: "ContractBudgetCommitment", optional: true
  has_many :conversions,
           class_name: "ContractBudgetCommitment",
           foreign_key: :source_commitment_id,
           inverse_of: :source_commitment,
           dependent: :restrict_with_error
  has_many :bank_orders,
           class_name: "ContractBankOrder",
           foreign_key: :budget_commitment_id,
           inverse_of: :budget_commitment,
           dependent: :nullify

  normalizes :number, with: ->(value) { OpenProject::RemoveInvisibleCharacters.call(value)&.strip }

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }
  validates :distribution_mode, inclusion: { in: DISTRIBUTION_MODES }
  validates :distribution_start_month,
            :distribution_end_month,
            inclusion: { in: MONTHS },
            if: :automatic_distribution?
  validates :number, :issued_on, :fiscal_year, :total_amount, presence: true
  validates :number, uniqueness: { scope: %i[public_contract_id kind] }
  validates :fiscal_year,
            uniqueness: { scope: %i[public_contract_id kind] },
            if: :future?
  validates :total_amount, numericality: { greater_than: 0 }
  validate :monthly_distribution_matches_total
  validate :responsible_is_active
  validate :source_is_future_commitment
  validate :source_has_available_balance
  validate :distribution_period_order

  scope :appropriations, -> { where(kind: "appropriation") }
  scope :future_commitments, -> { where(kind: "future") }
  scope :active, -> { where(status: "active") }

  before_validation :set_fiscal_year
  before_validation :calculate_distribution

  def appropriation?
    kind == "appropriation"
  end

  def future?
    kind == "future"
  end

  def automatic_distribution?
    distribution_mode == "automatic"
  end

  def consumed_amount
    appropriation? ? bank_orders.sum(:amount) : conversions.sum(:total_amount)
  end

  def remaining_amount
    [total_amount - consumed_amount, 0.to_d].max
  end

  def execution_percentage
    return 0.to_d unless total_amount.positive?

    ((consumed_amount / total_amount) * 100).round(2)
  end

  def alert?
    appropriation? && execution_percentage >= project_setting.commitment_consumption_alert_percentage
  end

  def month_amount(month)
    monthly_distribution.fetch(month.to_s, 0).to_d
  end

  private

  def project_setting
    ContractProjectSetting.for(public_contract.project)
  end

  def calculate_distribution
    normalized = MONTHS.to_h do |month|
      [month.to_s, monthly_distribution.to_h[month.to_s].to_d.round(2)]
    end

    if automatic_distribution?
      distribute_total_automatically
    else
      self.monthly_distribution = normalized.transform_values(&:to_s)
      self.total_amount = normalized.values.sum
    end
  end

  def set_fiscal_year
    self.fiscal_year ||= issued_on&.year
  end

  # The cent adjustment keeps the monthly sum identical to the entered total.
  # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity
  def distribute_total_automatically
    return if total_amount.blank? || fiscal_year.blank? || public_contract.blank?

    months = applicable_months
    return if months.empty?

    total_cents = (total_amount * 100).round.to_i
    base_cents, remainder = total_cents.divmod(months.size)
    values = MONTHS.index_with { 0.to_d }
    months.each_with_index do |month, index|
      values[month] = (base_cents + (index < remainder ? 1 : 0)) / 100.to_d
    end
    self.monthly_distribution = values.transform_keys(&:to_s).transform_values(&:to_s)
  end
  # rubocop:enable Metrics/AbcSize, Metrics/PerceivedComplexity

  def applicable_months
    first_month = distribution_start_month.to_i
    last_month = distribution_end_month.to_i
    return [] if first_month > last_month

    (first_month..last_month).to_a
  end

  def distribution_period_order
    return unless automatic_distribution?
    return if distribution_start_month.blank? || distribution_end_month.blank?
    return if distribution_start_month <= distribution_end_month

    errors.add :distribution_end_month, :greater_than_or_equal_to, count: distribution_start_month
  end

  def monthly_distribution_matches_total
    return if total_amount.blank?

    distributed = MONTHS.sum { |month| month_amount(month) }
    return if distributed == total_amount

    errors.add :monthly_distribution, :distribution_total_mismatch
  end

  def responsible_is_active
    return if responsible.blank? || responsible.active?

    errors.add :responsible, :invalid
  end

  def source_is_future_commitment
    return if source_commitment.blank? || source_commitment.future?

    errors.add :source_commitment, :invalid
  end

  def source_has_available_balance
    return if source_commitment.blank? || total_amount.blank?
    return if total_amount <= source_commitment.remaining_amount + persisted_source_amount

    errors.add :total_amount, :less_than_or_equal_to, count: source_commitment.remaining_amount
  end

  def persisted_source_amount
    persisted? ? total_amount_was.to_d : 0.to_d
  end
end
