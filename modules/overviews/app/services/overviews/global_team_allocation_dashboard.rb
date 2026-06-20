# frozen_string_literal: true

module Overviews
  class GlobalTeamAllocationDashboard
    attr_reader :current_user, :period

    def initialize(current_user: User.current, period: nil)
      @current_user = current_user
      @period = period
    end

    def call
      {
        period: normalized_period,
        period_options: TeamAllocationDashboard::PERIODS,
        summary:,
        rows:,
        ranking: rows.first(12),
        insights:,
        chart_max:,
        time_visible: project_dashboards.any? { |dashboard| dashboard[:time_visible] },
        costs_visible: project_dashboards.any? { |dashboard| dashboard[:costs_visible] }
      }
    end

    private

    def projects
      @projects ||= Project.visible(current_user).active.order(:lft, :name).to_a
    end

    def project_dashboards
      @project_dashboards ||= projects.map do |project|
        TeamAllocationDashboard.new(project:, current_user:, period: normalized_period).call
      end
    end

    def rows
      @rows ||= project_dashboards
        .flat_map { |dashboard| dashboard[:rows] }
        .group_by { |row| row[:user].id }
        .map { |_user_id, user_rows| combined_row(user_rows) }
        .sort_by { |row| [-row[:allocation], row[:user].name.downcase] }
    end

    def combined_row(user_rows)
      allocated_hours = user_rows.sum { |row| row[:allocated_hours] }
      capacity_hours = user_rows.pluck(:capacity_hours).max.to_f

      combined_row_values(user_rows).merge(
        user: user_rows.first[:user],
        allocated_hours: allocated_hours.round(2),
        capacity_hours: capacity_hours.round(2),
        allocation: percentage(allocated_hours, capacity_hours),
        participation: 0.0
      )
    end

    def combined_row_values(user_rows)
      {
        roles: user_rows.pluck(:roles).compact_blank.uniq.sort.join(", "),
        logged_hours: combined_optional_sum(user_rows, :logged_hours),
        estimated_cost: combined_optional_sum(user_rows, :estimated_cost)
      }
    end

    def combined_optional_sum(user_rows, key)
      values = user_rows.pluck(key)
      values.sum.round(2) if values.any? && values.all?
    end

    def rows_with_participation
      rows.each do |row|
        row[:participation] = percentage(row[:allocated_hours], total_allocated_hours)
      end
    end

    def summary
      rows_with_participation
      estimated_costs = rows.pluck(:estimated_cost)

      {
        allocation: percentage(total_allocated_hours, total_capacity_hours),
        active_members: rows.count { |row| row[:allocated_hours].positive? },
        total_members: rows.size,
        planned_hours: total_allocated_hours,
        capacity_hours: total_capacity_hours,
        estimated_cost: combined_estimated_cost(estimated_costs)
      }
    end

    def combined_estimated_cost(estimated_costs)
      estimated_costs.sum.round(2) if estimated_costs.any? && estimated_costs.all?
    end

    def insights
      rows_with_participation
      top_share = rows.first(3).sum { |row| row[:participation] }

      {
        overloaded: overloaded_rows,
        near_capacity: near_capacity_rows,
        available: available_rows,
        requested: project_dashboards.sum { |dashboard| dashboard.dig(:insights, :requested) },
        concentrated: rows.size > 3 && top_share >= 60,
        top_share:
      }
    end

    def overloaded_rows
      rows.select { |row| row[:allocation] > TeamAllocationDashboard::CAPACITY_OVERLOAD }
    end

    def near_capacity_rows
      rows.select do |row|
        row[:allocation].between?(
          TeamAllocationDashboard::CAPACITY_WARNING,
          TeamAllocationDashboard::CAPACITY_OVERLOAD
        )
      end
    end

    def available_rows
      rows.select { |row| row[:allocation] < TeamAllocationDashboard::LOW_ALLOCATION }
    end

    def total_allocated_hours
      @total_allocated_hours ||= rows.sum { |row| row[:allocated_hours] }
    end

    def total_capacity_hours
      @total_capacity_hours ||= rows.sum { |row| row[:capacity_hours] }
    end

    def chart_max
      highest = rows.pluck(:allocation).max.to_f
      ((highest / 25.0).ceil * 25).clamp(125, 200)
    end

    def normalized_period
      parsed = period.to_i
      TeamAllocationDashboard::PERIODS.include?(parsed) ? parsed : TeamAllocationDashboard::DEFAULT_PERIOD
    end

    def percentage(value, total)
      return 0.0 if total.to_f.zero?

      ((value.to_f / total) * 100).round(1)
    end
  end
end
