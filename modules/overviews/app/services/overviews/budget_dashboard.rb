# frozen_string_literal: true

module Overviews
  class BudgetDashboard
    PERIODS = [3, 6, 12].freeze
    DEFAULT_PERIOD = 12
    REQUIRED_PERMISSIONS = %i[
      view_budgets
      view_cost_entries
      view_cost_rates
      view_time_entries
      view_hourly_rates
    ].freeze
    MATERIAL_COLORS = %w[#2da44e #8250df #bf8700 #cf222e #57606a].freeze

    attr_reader :project, :current_user, :period

    def initialize(project:, current_user: User.current, period: nil)
      @project = project
      @current_user = current_user
      @period = normalized_period(period)
    end

    def call
      {
        period:,
        period_options: PERIODS,
        budgets:,
        summary:,
        insights:,
        comparison_chart:,
        consumption_chart:,
        trend_chart:,
        alerts:,
        rows:
      }
    end

    private

    def budgets
      @budgets ||= Budget
        .visible(current_user)
        .where(project_id: project.self_and_descendants)
        .includes(:project, :work_packages, :material_budget_items, :labor_budget_items)
        .order(fixed_date: :desc, subject: :asc)
        .to_a
    end

    def summary
      {
        planned: aggregated_budgets.budgeted_total,
        spent: aggregated_costs_all_time.spent_total,
        remaining: aggregated_budgets.budgeted_total - aggregated_costs_all_time.spent_total,
        ratio: spent_ratio
      }
    end

    def comparison_chart
      {
        type: "bar",
        valueType: "currency",
        labels: comparison_labels,
        datasets: [
          {
            label: I18n.t("overviews.budget.charts.planned"),
            data: planned_comparison_values,
            backgroundColor: "#0969da"
          },
          {
            label: I18n.t("overviews.budget.charts.actual"),
            data: actual_comparison_values,
            backgroundColor: "#2da44e"
          }
        ]
      }
    end

    def consumption_chart
      {
        type: "bar",
        valueType: "percentage",
        labels: rows.map { |row| row[:budget].subject },
        datasets: [
          {
            label: I18n.t("overviews.budget.charts.consumption"),
            data: rows.map { |row| row[:ratio] },
            backgroundColor: rows.map { |row| ratio_color(row[:ratio]) }
          }
        ]
      }
    end

    def comparison_labels
      %w[base labor material].map { |category| I18n.t("overviews.budget.categories.#{category}") }
    end

    def planned_comparison_values
      [
        aggregated_budgets.budgeted_base.to_f,
        aggregated_budgets.budgeted_labor.to_f,
        aggregated_budgets.budgeted_material.to_f
      ]
    end

    def actual_comparison_values
      [0, aggregated_costs_all_time.spent_labor.to_f, aggregated_costs_all_time.spent_material.to_f]
    end

    def trend_chart
      {
        type: "bar",
        valueType: "currency",
        labels: aggregated_costs_period.months.map { |month| I18n.l(month, format: "%b/%y") },
        datasets: [labor_dataset, *material_datasets]
      }
    end

    def labor_dataset
      {
        label: I18n.t("overviews.budget.categories.labor"),
        data: aggregated_costs_period.months.map do |month|
          aggregated_costs_period.spent_labor_by_month.fetch(month, 0).to_f
        end,
        backgroundColor: "#0969da",
        stack: "costs"
      }
    end

    def material_datasets
      aggregated_costs_period.cost_type_names.each_with_index.map do |cost_type_name, index|
        {
          label: cost_type_name,
          data: aggregated_costs_period.months.map do |month|
            aggregated_costs_period.spent_material_by_month_and_type.fetch([month, cost_type_name], 0).to_f
          end,
          backgroundColor: MATERIAL_COLORS[index % MATERIAL_COLORS.size],
          stack: "costs"
        }
      end
    end

    def alerts
      over_budget = rows.select { |row| row[:ratio] > 100 }
      near_limit = rows.select { |row| row[:ratio].between?(80, 100) }
      without_spending = rows.select { |row| row[:spent].zero? }

      { over_budget:, near_limit:, without_spending: }
    end

    def insights
      {
        highest_consumption: rows.max_by { |row| row[:ratio] },
        largest_spend: rows.max_by { |row| row[:spent] },
        average_monthly_spend: average_monthly_spend,
        projected_months_remaining: projected_months_remaining,
        budgets_without_work_packages: rows.count { |row| row[:work_packages].zero? }
      }
    end

    def rows
      @rows ||= budgets.map do |budget|
        planned = budget.budget
        spent = budget.spent

        {
          budget:,
          planned:,
          spent:,
          remaining: planned - spent,
          ratio: planned.zero? ? 0 : ((spent / planned) * 100).round(2),
          work_packages: budget.work_packages.size
        }
      end
    end

    def average_monthly_spend
      return 0 if period.zero?

      (period_spending / period).round(2)
    end

    def projected_months_remaining
      return if average_monthly_spend.zero? || summary[:remaining] <= 0

      (summary[:remaining] / average_monthly_spend).round(1)
    end

    def period_spending
      aggregated_costs_period.spent_total
    end

    def ratio_color(ratio)
      return "#cf222e" if ratio > 100
      return "#bf8700" if ratio >= 80

      "#2da44e"
    end

    def aggregated_budgets
      @aggregated_budgets ||= Budgets::AggregatedBudgets.new(project:, current_user:)
    end

    def aggregated_costs_all_time
      @aggregated_costs_all_time ||= Costs::AggregatedCosts.new(project:, current_user:)
    end

    def aggregated_costs_period
      @aggregated_costs_period ||= Costs::AggregatedCosts.new(
        project:,
        current_user:,
        date_range: first_month.beginning_of_month..Time.zone.today.end_of_month
      )
    end

    def first_month
      Time.zone.today.beginning_of_month - (period - 1).months
    end

    def spent_ratio
      return 0 if aggregated_budgets.budgeted_total.zero?

      ((aggregated_costs_all_time.spent_total / aggregated_budgets.budgeted_total) * 100).round(2)
    end

    def normalized_period(value)
      parsed = value.to_i
      PERIODS.include?(parsed) ? parsed : DEFAULT_PERIOD
    end
  end
end
