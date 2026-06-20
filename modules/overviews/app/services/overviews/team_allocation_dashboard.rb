# frozen_string_literal: true

module Overviews
  class TeamAllocationDashboard
    PERIODS = [3, 6, 12].freeze
    DEFAULT_PERIOD = 3
    CAPACITY_WARNING = 80
    CAPACITY_OVERLOAD = 100
    LOW_ALLOCATION = 50

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
        date_range:,
        summary:,
        rows:,
        ranking: rows.first(12),
        insights:,
        chart_max: chart_max,
        time_visible: time_visible?,
        costs_visible: costs_visible?
      }
    end

    private

    def summary
      estimated_costs = rows.pluck(:estimated_cost).compact

      {
        allocation: percentage(total_allocated_hours, total_capacity_hours),
        active_members: rows.count { |row| row[:allocated_hours].positive? },
        total_members: rows.size,
        planned_hours: total_allocated_hours,
        capacity_hours: total_capacity_hours,
        estimated_cost: summary_estimated_cost(estimated_costs)
      }
    end

    def summary_estimated_cost(estimated_costs)
      estimated_costs.sum if costs_visible? && estimated_costs.any?
    end

    def rows
      @rows ||= begin
        member_rows = members.map { |member| row_for(member) }
        member_rows.sort_by { |row| [-row[:allocation], row[:user].name.downcase] }
      end
    end

    def row_for(member)
      user = member[:user]
      member_metrics(user).merge(
        user:,
        roles: member[:roles]
      )
    end

    def member_metrics(user)
      allocated_hours = allocated_hours_by_user.fetch(user.id, 0.0)
      capacity_hours = capacity_for(user)

      {
        allocated_hours: allocated_hours.round(2),
        logged_hours: logged_hours_by_user[user.id]&.round(2),
        capacity_hours: capacity_hours.round(2),
        allocation: percentage(allocated_hours, capacity_hours),
        estimated_cost: estimated_cost_for(user),
        participation: percentage(allocated_hours, total_allocated_hours)
      }
    end

    def members
      @members ||= membership_records
        .group_by(&:user_id)
        .map do |_user_id, records|
          {
            user: records.first.principal,
            roles: records.flat_map(&:roles).uniq(&:id).map(&:name).sort.join(", ")
          }
        end
    end

    def membership_records
      @membership_records ||= begin
        project_memberships = project.members.includes(:roles, :principal).to_a
        ActiveRecord::Associations::Preloader.new(
          records: project_memberships.map(&:principal),
          associations: %i[working_hours non_working_times]
        ).call
        project_memberships
      end
    end

    def allocations
      @allocations ||= ResourceAllocation
        .where(
          entity_type: "ResourcePlanner",
          entity_id: ResourcePlanner.where(project_id: project.id),
          principal_id: member_ids
        )
        .where("start_date <= ? AND end_date >= ?", date_range.end, date_range.begin)
        .includes(:principal)
        .to_a
    end

    def allocated_hours_by_user
      @allocated_hours_by_user ||= allocations
        .select(&:allocated?)
        .group_by(&:principal_id)
        .transform_values { |entries| entries.sum { |allocation| overlapping_hours(allocation) } }
    end

    def requested_allocations
      @requested_allocations ||= allocations.select(&:requested?)
    end

    def overlapping_hours(allocation)
      overlap = allocation_overlap(allocation)
      return 0.0 unless overlap

      total_days = days_between(allocation.start_date, allocation.end_date)
      (allocation.allocated_time / 60.0) * (days_between(overlap.begin, overlap.end).to_f / total_days)
    end

    def allocation_overlap(allocation)
      overlap_start = [allocation.start_date, date_range.begin].max
      overlap_end = [allocation.end_date, date_range.end].min
      overlap_start..overlap_end if overlap_start <= overlap_end
    end

    def days_between(start_date, end_date)
      (end_date - start_date).to_i + 1
    end

    def capacity_for(user)
      schedules = schedules_for(user)
      absences = absences_for(user)

      date_range.sum do |date|
        unavailable_on?(date, absences) ? 0.0 : daily_capacity(schedule_on(date, schedules), date)
      end
    end

    def schedules_for(user)
      user.working_hours
        .select { |schedule| schedule.valid_from <= date_range.end }
        .sort_by(&:valid_from)
    end

    def absences_for(user)
      user.non_working_times.select do |absence|
        absence.start_date <= date_range.end && absence.end_date >= date_range.begin
      end
    end

    def unavailable_on?(date, absences)
      system_non_working_dates.include?(date) ||
        absences.any? { |absence| date.between?(absence.start_date, absence.end_date) }
    end

    def schedule_on(date, schedules)
      schedules.reverse_each.find { |entry| entry.valid_from <= date }
    end

    def daily_capacity(schedule, date)
      if schedule
        day = UserWorkingHours::DAYS.fetch(date.cwday - 1)
        schedule.public_send("#{day}_hours") * (schedule.availability_factor / 100.0)
      elsif Setting.working_days.include?(date.cwday)
        Setting.hours_per_day.to_f
      else
        0.0
      end
    end

    def system_non_working_dates
      @system_non_working_dates ||= NonWorkingDay.where(date: date_range).pluck(:date).to_set
    end

    def logged_hours_by_user
      return {} unless time_visible?

      @logged_hours_by_user ||= project.time_entries
        .where(user_id: member_ids, spent_on: date_range)
        .where(ongoing: false)
        .group(:user_id)
        .sum(:hours)
    end

    def estimated_cost_for(user)
      return nil unless costs_visible?

      user_allocations = allocations.select do |allocation|
        allocation.allocated? && allocation.principal_id == user.id
      end
      return nil if user_allocations.empty?

      costs = user_allocations.map { |allocation| estimated_allocation_cost(user, allocation) }
      costs.sum if costs.all?
    end

    def estimated_allocation_cost(user, allocation)
      rate_date = [allocation.start_date, date_range.begin].max
      rate = user.rate_at(rate_date, project)&.rate
      overlapping_hours(allocation) * rate if rate
    end

    def insights
      {
        overloaded: overloaded_rows,
        near_capacity: near_capacity_rows,
        available: available_rows,
        requested: requested_allocations.size,
        concentrated: rows.size > 3 && top_share >= 60,
        top_share:
      }
    end

    def overloaded_rows
      rows.select { |row| row[:allocation] > CAPACITY_OVERLOAD }
    end

    def near_capacity_rows
      rows.select { |row| row[:allocation].between?(CAPACITY_WARNING, CAPACITY_OVERLOAD) }
    end

    def available_rows
      rows.select { |row| row[:allocation] < LOW_ALLOCATION }
    end

    def top_share
      @top_share ||= rows.first(3).sum { |row| row[:participation] }
    end

    def total_allocated_hours
      @total_allocated_hours ||= allocated_hours_by_user.values.sum
    end

    def member_ids
      @member_ids ||= members.pluck(:user).map(&:id)
    end

    def total_capacity_hours
      @total_capacity_hours ||= rows.sum { |row| row[:capacity_hours] }
    end

    def chart_max
      highest = rows.pluck(:allocation).max.to_f
      ((highest / 25.0).ceil * 25).clamp(125, 200)
    end

    def date_range
      @date_range ||= Time.zone.today.beginning_of_month..(Time.zone.today.beginning_of_month + period.months - 1.day)
    end

    def percentage(value, total)
      return 0.0 if total.to_f.zero?

      ((value.to_f / total) * 100).round(1)
    end

    def time_visible?
      current_user.allowed_in_project?(:view_time_entries, project)
    end

    def costs_visible?
      project.module_enabled?("costs") &&
        current_user.allowed_in_project?(:view_hourly_rates, project)
    end

    def normalized_period(value)
      parsed = value.to_i
      PERIODS.include?(parsed) ? parsed : DEFAULT_PERIOD
    end
  end
end
