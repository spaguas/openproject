# frozen_string_literal: true

module Overviews
  class GlobalKpiDashboard
    PERIODS = KpiDashboard::PERIODS
    DEFAULT_PERIOD = KpiDashboard::DEFAULT_PERIOD
    TREND_COLORS = KpiDashboard::TREND_COLORS

    attr_reader :current_user, :period

    def initialize(current_user: User.current, period: nil)
      @current_user = current_user
      @period = normalized_period(period)
    end

    def call
      {
        period:,
        period_options: PERIODS,
        kpis:,
        summary:,
        ranking:,
        status_chart:,
        trend_chart:,
        overdue_measurements:,
        risky_kpis:,
        project_rows:
      }
    end

    private

    def kpis
      @kpis ||= Kpi
        .visible(current_user)
        .includes(:project, :owner, :kpi_category, measurements: :author)
        .ordered
        .to_a
    end

    def summary
      {
        total: kpis.size,
        projects: project_rows.size,
        average_progress: average_progress,
        at_risk: risky_kpis.size,
        overdue_measurements: overdue_measurements.size
      }
    end

    def project_rows
      @project_rows ||= kpis
        .group_by(&:project)
        .map { |project, project_kpis| combined_project_row(project, project_kpis) }
        .sort_by { |row| [-row[:at_risk], row[:average_progress], row[:project].name.downcase] }
    end

    def combined_project_row(project, project_kpis)
      risky_count = project_kpis.count { |kpi| risky_status?(kpi.status) }
      overdue_count = project_kpis.count { |kpi| measurement_overdue?(kpi) }

      {
        project:,
        total: project_kpis.size,
        average_progress: average_progress_for(project_kpis),
        at_risk: risky_count,
        overdue_measurements: overdue_count
      }
    end

    def average_progress
      average_progress_for(kpis)
    end

    def average_progress_for(records)
      return 0 if records.empty?

      (records.sum(&:progress_percentage).to_f / records.size).round
    end

    def ranking
      kpis
        .sort_by { |kpi| [-kpi.progress_percentage, kpi.name.downcase] }
        .first(15)
    end

    def risky_kpis
      @risky_kpis ||= kpis
        .select { |kpi| risky_status?(kpi.status) }
        .sort_by { |kpi| [kpi.progress_percentage, kpi.name.downcase] }
    end

    def overdue_measurements
      @overdue_measurements ||= kpis
        .select { |kpi| measurement_overdue?(kpi) }
        .sort_by(&:next_measurement_at)
    end

    def status_chart
      statuses = Kpi::STATUSES.index_with { 0 }
      kpis.each { |kpi| statuses[kpi.status] += 1 }
      visible_statuses = statuses.select { |_status, count| count.positive? }

      {
        type: "doughnut",
        labels: visible_statuses.keys.map { |status| I18n.t("kpis.statuses.#{status}") },
        datasets: [
          {
            data: visible_statuses.values,
            backgroundColor: visible_statuses.keys.map { |status| status_color(status) }
          }
        ]
      }
    end

    def trend_chart
      {
        type: "line",
        labels: month_starts.map { |month| I18n.l(month, format: "%b/%y") },
        datasets: trend_kpis.each_with_index.map { |kpi, index| trend_dataset(kpi, index) }
      }
    end

    def trend_kpis
      @trend_kpis ||= kpis
        .select { |kpi| kpi.measurements.any? { |measurement| measurement.measured_at >= month_starts.first } }
        .first(TREND_COLORS.size)
    end

    def trend_dataset(kpi, index)
      {
        label: kpi.name,
        data: month_starts.map { |month| monthly_progress(kpi, month) },
        borderColor: TREND_COLORS[index],
        backgroundColor: TREND_COLORS[index]
      }
    end

    def monthly_progress(kpi, month)
      measurement = kpi.measurements
        .select { |entry| entry.measured_at.to_date.beginning_of_month == month }
        .max_by(&:measured_at)

      kpi.progress_for_value(measurement.value) if measurement
    end

    def month_starts
      @month_starts ||= Array.new(period) { |offset| Time.zone.today.beginning_of_month - offset.months }.reverse
    end

    def measurement_overdue?(kpi)
      kpi.next_measurement_at.present? && kpi.next_measurement_at < Time.current
    end

    def risky_status?(status)
      %w[at_risk off_track].include?(status)
    end

    def status_color(status)
      {
        "not_started" => "#8c959f",
        "on_track" => "#1a7f37",
        "at_risk" => "#bf8700",
        "off_track" => "#cf222e",
        "achieved" => "#2da44e",
        "paused" => "#6e7781"
      }.fetch(status)
    end

    def normalized_period(value)
      parsed = value.to_i
      PERIODS.include?(parsed) ? parsed : DEFAULT_PERIOD
    end
  end
end
