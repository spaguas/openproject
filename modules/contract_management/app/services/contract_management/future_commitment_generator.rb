# frozen_string_literal: true

module ContractManagement
  class FutureCommitmentGenerator
    def initialize(appropriation)
      @appropriation = appropriation
      @contract = appropriation.public_contract
    end

    # rubocop:disable Metrics/AbcSize
    def call
      remaining = @contract.total_amount - covered_amount
      return if remaining <= 0

      dates = future_months
      return if dates.empty?

      monthly_amounts = amounts_by_month(remaining, dates)
      dates.group_by(&:year).each do |year, year_dates|
        distribution = (1..12).index_with { 0.to_d }
        year_dates.each { |date| distribution[date.month] = monthly_amounts.fetch(date) }
        save_future_commitment(year, distribution)
      end
    end
    # rubocop:enable Metrics/AbcSize

    private

    def covered_amount
      @contract.budget_commitments
        .where.not(id: @contract.budget_commitments.future_commitments.select(:id))
        .sum(:total_amount)
    end

    def amounts_by_month(amount, dates)
      base = (amount / dates.size).round(2)
      amounts = dates.index_with { base }
      amounts[dates.last] += amount - amounts.values.sum
      amounts
    end

    def save_future_commitment(year, distribution)
      future = @contract.budget_commitments.future_commitments.find_or_initialize_by(fiscal_year: year)
      future.assign_attributes(
        responsible: @appropriation.responsible,
        number: future.number.presence || "NCF-#{@contract.number}-#{year}",
        issued_on: @appropriation.issued_on,
        total_amount: distribution.values.sum,
        distribution_mode: "manual",
        status: "active",
        monthly_distribution: distribution.transform_keys(&:to_s).transform_values(&:to_s)
      )
      future.save!
    end

    def future_months
      start_on = [@appropriation.issued_on.end_of_year.next_day, @contract.start_date].max
      return [] if start_on > @contract.effective_end_date

      current = start_on.beginning_of_month
      finish = @contract.effective_end_date.beginning_of_month
      dates = []
      while current <= finish
        dates << current
        current = current.next_month
      end
      dates
    end
  end
end
