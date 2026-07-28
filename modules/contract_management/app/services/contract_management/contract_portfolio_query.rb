# frozen_string_literal: true

module ContractManagement
  class ContractPortfolioQuery
    STATUSES = %w[active expiring expired].freeze
    EXPIRING_DAYS = 30

    attr_reader :contracts, :projects, :status, :project_id, :query, :ending_from, :ending_to

    def initialize(user:, filters: {})
      @user = user
      @status = filters[:status].presence_in(STATUSES)
      @project_id = filters[:project_id].presence
      @query = filters[:query].to_s.strip
      @ending_from = parse_date(filters[:ending_from])
      @ending_to = parse_date(filters[:ending_to])
      @contracts = load_contracts
      @projects = allowed_projects
    end

    def total_contracts
      contracts.size
    end

    def active_contracts
      contracts.count { |contract| status_for(contract) == "active" }
    end

    def expiring_contracts
      contracts.count { |contract| status_for(contract) == "expiring" }
    end

    def expired_contracts
      contracts.count { |contract| status_for(contract) == "expired" }
    end

    def total_amount
      contracts.sum(&:total_amount)
    end

    def paid_amount
      contracts.sum(&:paid_amount)
    end

    def balance
      contracts.sum(&:balance)
    end

    def overdue_invoices
      contracts.sum { |contract| contract.invoices.count { |invoice| invoice.status == "overdue" } }
    end

    def adjusted_total_amount
      contracts.sum(&:adjusted_total_amount)
    end

    def invoiced_amount
      contracts.sum(&:invoiced_amount)
    end

    def measured_amount
      contracts.sum(&:measured_amount)
    end

    def paid_percentage
      percentage(paid_amount, total_amount)
    end

    def invoiced_percentage
      percentage(invoiced_amount, total_amount)
    end

    def measured_percentage
      percentage(measured_amount, total_amount)
    end

    def status_breakdown
      STATUSES.index_with { |contract_status| contracts.count { |contract| status_for(contract) == contract_status } }
    end

    def project_breakdown
      breakdown = contracts.group_by(&:project).map do |project, project_contracts|
        {
          project:,
          contracts: project_contracts,
          count: project_contracts.size,
          total_amount: project_contracts.sum(&:total_amount),
          paid_amount: project_contracts.sum(&:paid_amount)
        }
      end
      breakdown.sort_by { |item| [-item[:total_amount], item[:project].name] }
    end

    def contracts_for_status(contract_status)
      contracts.select { |contract| status_for(contract) == contract_status }
    end

    def attention_contracts
      contracts.select do |contract|
        status_for(contract) != "active" || contract.invoices.any? { |invoice| invoice.status == "overdue" }
      end
    end

    def status_for(contract)
      deadline = contract.effective_end_date
      return "expired" if deadline < Date.current
      return "expiring" if deadline <= EXPIRING_DAYS.days.from_now.to_date

      "active"
    end

    def manageable?(contract)
      @user.allowed_in_project?(:manage_contracts, contract.project)
    end

    private

    def load_contracts
      relation = PublicContract
        .visible(@user)
        .includes(:amendments, :bank_orders, :invoices, responsibilities: :user)
        .order(end_date: :asc, number: :asc)
      relation = relation.where(project_id:) if project_id
      relation = apply_query(relation) if query.present?

      records = relation.to_a
      records = apply_date_range(records)
      status ? records.select { |contract| status_for(contract) == status } : records
    end

    def allowed_projects
      Project
        .allowed_to(@user, :view_contracts)
        .where(id: PublicContract.select(:project_id))
        .order(:name)
    end

    def apply_query(relation)
      escaped_query = ActiveRecord::Base.sanitize_sql_like(query)
      pattern = "%#{escaped_query}%"

      relation.where(
        "public_contracts.number ILIKE :pattern OR " \
        "public_contracts.sei_process_number ILIKE :pattern OR " \
        "public_contracts.description ILIKE :pattern",
        pattern:
      )
    end

    def apply_date_range(records)
      records.select do |contract|
        deadline = contract.effective_end_date
        (ending_from.blank? || deadline >= ending_from) && (ending_to.blank? || deadline <= ending_to)
      end
    end

    def parse_date(value)
      Date.iso8601(value.to_s) if value.present?
    rescue Date::Error
      nil
    end

    def percentage(value, total)
      return 0.to_d unless total.positive?

      ((value / total) * 100).round(1)
    end
  end
end
