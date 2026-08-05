# frozen_string_literal: true

class PublicContract < ApplicationRecord
  belongs_to :project
  belongs_to :contract_adjustment_index, optional: true
  belongs_to :contract_adjustment_index_type, optional: true

  has_many :measurements, class_name: "ContractMeasurement", dependent: :destroy
  has_many :invoices, class_name: "ContractInvoice", dependent: :destroy
  has_many :amendments, class_name: "ContractAmendment", dependent: :destroy
  has_many :responsibilities, class_name: "ContractResponsibility", dependent: :destroy
  has_many :bank_orders, class_name: "ContractBankOrder", dependent: :destroy
  has_many :budget_commitments, class_name: "ContractBudgetCommitment", dependent: :destroy
  has_many :deadline_notifications, class_name: "ContractDeadlineNotification", dependent: :destroy
  has_many :contract_notifications, dependent: :destroy

  normalizes :number, :sei_process_number, :payment_sei_process_number,
             with: ->(value) { OpenProject::RemoveInvisibleCharacters.call(value)&.strip }

  validates :number, :sei_process_number, :start_date, :end_date, :duration_months,
            :description, :amount, presence: true
  validates :number, uniqueness: { scope: :project_id }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :duration_months, numericality: { only_integer: true, greater_than: 0 }
  validates :deadline_notification_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :measurement_evaluation_business_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :end_date_not_before_start_date
  validate :adjustment_index_belongs_to_project
  validate :adjustment_index_type_belongs_to_project
  validate :adjustment_start_date_present_with_index

  scope :visible, ->(user = User.current) {
    includes(:project).references(:projects).merge(Project.allowed_to(user, :view_contracts))
  }

  scope :expiring_between, ->(from, to) { where(end_date: from..to) }

  def total_amount
    amount + amendments.sum(&:amount)
  end

  def measured_amount
    measurements.where(status: "approved").sum(:amount)
  end

  def invoiced_amount
    invoices.sum(:gross_amount)
  end

  def paid_amount
    bank_orders.sum(:amount)
  end

  def balance
    total_amount - paid_amount
  end

  def adjustment_occurrences(on: Date.current)
    return 0 if configured_adjustment_index.blank? || adjustment_start_date.blank? || on < adjustment_start_date

    elapsed_months = ((on.year * 12) + on.month) -
      ((adjustment_start_date.year * 12) + adjustment_start_date.month)
    elapsed_months -= 1 if adjustment_start_date.advance(months: elapsed_months) > on
    (elapsed_months / configured_adjustment_index.period_months) + 1
  end

  def adjustment_amount(on: Date.current)
    return monthly_adjustment_amount(on:) if contract_adjustment_index_type
    return 0.to_d if adjustment_occurrences(on:).zero?

    factor = adjustment_dates(on:).reduce(1.to_d) do |result, date|
      result * (1 + (adjustment_percentage / 100))
    end
    (total_amount * (factor - 1)).round(2)
  end

  def adjusted_total_amount(on: Date.current)
    total_amount + adjustment_amount(on:)
  end

  def physical_execution_percentage
    percentage_of_total(measured_amount)
  end

  def financial_execution_percentage
    percentage_of_total(paid_amount)
  end

  def effective_end_date
    amendment_end_dates = amendments.map { |amendment| amendment.start_date.advance(months: amendment.duration_months) }
    ([end_date] + amendment_end_dates).compact.max
  end

  def visible?(user = User.current)
    user&.allowed_in_project?(:view_contracts, project)
  end

  def manager_or_inspector?(user, on: Date.current)
    responsibilities.active_on(on).exists?(user:)
  end

  private

  def configured_adjustment_index
    contract_adjustment_index_type || contract_adjustment_index
  end

  def adjustment_dates(on:)
    Array.new(adjustment_occurrences(on:)) do |occurrence|
      adjustment_start_date.advance(months: occurrence * configured_adjustment_index.period_months)
    end
  end

  def adjustment_percentage
    contract_adjustment_index.percentage
  end

  def monthly_adjustment_amount(on:)
    final_date = [on, effective_end_date].min
    return 0.to_d if adjustment_start_date.blank? || final_date < adjustment_start_date

    factor = monthly_adjustment_indices(until_date: final_date).reduce(1.to_d) do |result, index|
      result * (1 + (index.percentage / 100))
    end
    (total_amount * (factor - 1)).round(2)
  end

  def monthly_adjustment_indices(until_date:)
    contract_adjustment_index_type.adjustment_indices
      .between_periods(adjustment_start_date, until_date)
      .order(:year, :month)
  end

  def percentage_of_total(value)
    return 0.to_d unless total_amount.positive?

    (value / total_amount) * 100
  end

  def end_date_not_before_start_date
    return if start_date.blank? || end_date.blank? || end_date >= start_date

    errors.add :end_date, :greater_than_or_equal_to_start_date
  end

  def adjustment_index_belongs_to_project
    return if contract_adjustment_index.blank? || project.blank? || contract_adjustment_index.project_id == project.id

    errors.add :contract_adjustment_index, :invalid
  end

  def adjustment_index_type_belongs_to_project
    return if contract_adjustment_index_type.blank? || project.blank? || contract_adjustment_index_type.project_id == project.id

    errors.add :contract_adjustment_index_type, :invalid
  end

  def adjustment_start_date_present_with_index
    return if configured_adjustment_index.blank? || adjustment_start_date.present?

    errors.add :adjustment_start_date, :blank
  end
end
