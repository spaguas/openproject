# frozen_string_literal: true

module Overviews
  class KpiDashboard
    PERIODS = [3, 6, 12].freeze
    DEFAULT_PERIOD = 6
    TREND_COLORS = %w[#0969da #1a7f37 #8250df #bf8700 #cf222e #57606a].freeze

    attr_reader :project, :period

    def initialize(project:, period: nil)
      @project = project
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
        risky_kpis:
      }
    end

    private

    def kpis
      @kpis ||= Kpi
        .associated_with_project(project)
        .includes(:owner, :kpi_category, measurements: :author)
        .ordered
        .to_a
    end

    def summary
      {
        total: kpis.size,
        average_progress: average_progress,
        at_risk: risky_kpis.size,
        overdue_measurements: overdue_measurements.size
      }
    end

    def average_progress
      return 0 if kpis.empty?

      (kpis.sum(&:progress_percentage).to_f / kpis.size).round
    end

    def ranking
      kpis
        .sort_by { |kpi| [-kpi.progress_percentage, kpi.name.downcase] }
        .first(12)
    end

    def risky_kpis
      @risky_kpis ||= kpis
        .select { |kpi| %w[at_risk off_track].include?(kpi.status) }
        .sort_by { |kpi| [kpi.progress_percentage, kpi.name.downcase] }
    end

    def overdue_measurements
      @overdue_measurements ||= kpis
        .select { |kpi| kpi.next_measurement_at.present? && kpi.next_measurement_at < Time.current }
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

    def month_starts
      @month_starts ||= Array.new(period) { |offset| Time.zone.today.beginning_of_month - offset.months }.reverse
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

    def normalized_period(value)
      parsed = value.to_i
      PERIODS.include?(parsed) ? parsed : DEFAULT_PERIOD
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
  end
end
