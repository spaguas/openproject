# frozen_string_literal: true

module Overviews
  class GlobalBudgetDashboard
    PERIODS = BudgetDashboard::PERIODS
    DEFAULT_PERIOD = BudgetDashboard::DEFAULT_PERIOD
    MATERIAL_COLORS = BudgetDashboard::MATERIAL_COLORS

    attr_reader :current_user, :period

    def initialize(current_user: User.current, period: nil)
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
        rows:,
        project_rows:
      }
    end

    private

    def budgets
      @budgets ||= Budget
        .visible(current_user)
        .includes(:project, :work_packages, material_budget_items: :cost_type, labor_budget_items: :user)
        .order(fixed_date: :desc, subject: :asc)
        .to_a
    end

    def rows
      @rows ||= budgets.map do |budget|
        planned = budget.budget
        spent = budget.spent

        {
          budget:,
          project: budget.project,
          planned:,
          spent:,
          remaining: planned - spent,
          ratio: planned.zero? ? 0 : ((spent / planned) * 100).round(2),
          work_packages: budget.work_packages.size
        }
      end
    end

    def project_rows
      @project_rows ||= rows
        .group_by { |row| row[:project] }
        .map { |project, project_budget_rows| combined_project_row(project, project_budget_rows) }
        .sort_by { |row| [-row[:spent], row[:project].name.downcase] }
    end

    def combined_project_row(project, project_budget_rows)
      planned = project_budget_rows.sum { |row| row[:planned] }
      spent = project_budget_rows.sum { |row| row[:spent] }

      {
        project:,
        budgets: project_budget_rows.size,
        planned:,
        spent:,
        remaining: planned - spent,
        ratio: planned.zero? ? 0 : ((spent / planned) * 100).round(2)
      }
    end

    def summary
      {
        planned: total_planned,
        spent: total_spent,
        remaining: total_planned - total_spent,
        ratio: total_planned.zero? ? 0 : ((total_spent / total_planned) * 100).round(2),
        projects: project_rows.size
      }
    end

    def comparison_chart
      {
        type: "bar",
        valueType: "currency",
        labels: %w[base labor material].map { |category| I18n.t("overviews.budget.categories.#{category}") },
        datasets: [
          {
            label: I18n.t("overviews.budget.charts.planned"),
            data: [planned_base.to_f, planned_labor.to_f, planned_material.to_f],
            backgroundColor: "#0969da"
          },
          {
            label: I18n.t("overviews.budget.charts.actual"),
            data: [0, spent_labor.to_f, spent_material.to_f],
            backgroundColor: "#2da44e"
          }
        ]
      }
    end

    def consumption_chart
      {
        type: "bar",
        valueType: "percentage",
        labels: consumption_rows.map { |row| row[:budget].subject },
        datasets: [
          {
            label: I18n.t("overviews.budget.charts.consumption"),
            data: consumption_rows.pluck(:ratio),
            backgroundColor: consumption_rows.map { |row| ratio_color(row[:ratio]) }
          }
        ]
      }
    end

    def consumption_rows
      @consumption_rows ||= rows
        .sort_by { |row| [-row[:ratio], -row[:spent], row[:budget].subject.downcase] }
        .first(15)
    end

    def trend_chart
      {
        type: "bar",
        valueType: "currency",
        labels: month_starts.map { |month| I18n.l(month, format: "%b/%y") },
        datasets: [labor_dataset, *material_datasets]
      }
    end

    def labor_dataset
      {
        label: I18n.t("overviews.budget.categories.labor"),
        data: month_starts.map { |month| spent_labor_by_month.fetch(month, 0).to_f },
        backgroundColor: "#0969da",
        stack: "costs"
      }
    end

    def material_datasets
      cost_type_names.each_with_index.map do |cost_type_name, index|
        {
          label: cost_type_name,
          data: month_starts.map { |month| spent_material_by_month_and_type.fetch([month, cost_type_name], 0).to_f },
          backgroundColor: MATERIAL_COLORS[index % MATERIAL_COLORS.size],
          stack: "costs"
        }
      end
    end

    def alerts
      {
        over_budget: rows.select { |row| row[:ratio] > 100 },
        near_limit: rows.select { |row| row[:ratio].between?(80, 100) },
        without_spending: rows.select { |row| row[:spent].zero? }
      }
    end

    def insights
      {
        highest_consumption: rows.max_by { |row| row[:ratio] },
        largest_spend: rows.max_by { |row| row[:spent] },
        average_monthly_spend: average_monthly_spend,
        projected_months_remaining: projected_months_remaining,
        top_projects:,
        concentrated: project_rows.size > 3 && top_share >= 60,
        top_share:
      }
    end

    def top_projects
      @top_projects ||= project_rows.first(3)
    end

    def top_share
      return 0 if total_spent.zero?

      ((top_projects.sum { |row| row[:spent] } / total_spent) * 100).round(1)
    end

    def total_planned
      @total_planned ||= rows.sum { |row| row[:planned] }
    end

    def total_spent
      @total_spent ||= rows.sum { |row| row[:spent] }
    end

    def planned_base
      @planned_base ||= budgets.sum(&:base_amount)
    end

    def planned_material
      @planned_material ||= budgets.sum(&:material_budget)
    end

    def planned_labor
      @planned_labor ||= budgets.sum(&:labor_budget)
    end

    def spent_material
      @spent_material ||= budgets.sum(&:spent_material)
    end

    def spent_labor
      @spent_labor ||= budgets.sum(&:spent_labor)
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
      spent_labor_by_month.values.sum + spent_material_by_month_and_type.values.sum
    end

    def spent_labor_by_month
      @spent_labor_by_month ||= time_entries_by_month.effective_costs_sum.transform_keys(&:to_date)
    end

    def spent_material_by_month_and_type
      @spent_material_by_month_and_type ||= cost_entries_by_month_and_type.effective_costs_sum
        .transform_keys { |(month, name)| [month.to_date, name] }
    end

    def cost_type_names
      spent_material_by_month_and_type.keys.map(&:last).uniq
    end

    def time_entries_by_month
      time_entries.group("date_trunc('month', time_entries.spent_on)")
    end

    def cost_entries_by_month_and_type
      cost_entries
        .joins(:cost_type)
        .group("date_trunc('month', cost_entries.spent_on)", "cost_types.name")
        .order("cost_types.name ASC")
    end

    def time_entries
      TimeEntry
        .on_work_packages(budgeted_work_packages)
        .visible_costs(current_user)
        .where(spent_on: date_range)
    end

    def cost_entries
      CostEntry
        .on_work_packages(budgeted_work_packages)
        .visible_costs(current_user)
        .where(spent_on: date_range)
    end

    def budgeted_work_packages
      WorkPackage.where(budget_id: budgets.map(&:id))
    end

    def month_starts
      @month_starts ||= Array.new(period) { |offset| Time.zone.today.beginning_of_month - offset.months }.reverse
    end

    def date_range
      month_starts.first.beginning_of_month..Time.zone.today.end_of_month
    end

    def ratio_color(ratio)
      return "#cf222e" if ratio > 100
      return "#bf8700" if ratio >= 80

      "#2da44e"
    end

    def normalized_period(value)
      parsed = value.to_i
      PERIODS.include?(parsed) ? parsed : DEFAULT_PERIOD
    end
  end
end
