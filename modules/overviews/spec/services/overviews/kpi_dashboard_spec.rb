# frozen_string_literal: true

require "rails_helper"

RSpec.describe Overviews::KpiDashboard do
  shared_let(:project) { create(:project, enabled_module_names: %w[kpis]) }

  describe "#call" do
    around do |example|
      travel_to(Time.zone.local(2026, 6, 18, 12)) { example.run }
    end

    let!(:healthy) do
      create(
        :kpi,
        project:,
        name: "Availability",
        current_value: 90,
        target_value: 100,
        status: "on_track",
        measurement_frequency: "monthly"
      )
    end
    let!(:risky) do
      create(
        :kpi,
        project:,
        name: "Incidents",
        current_value: 50,
        target_value: 25,
        direction: "decrease",
        status: "at_risk",
        measurement_frequency: "monthly"
      )
    end
    let!(:healthy_measurements) do
      [
        create(:kpi_measurement, kpi: healthy, value: 80, measured_at: 2.months.ago),
        create(:kpi_measurement, kpi: healthy, value: 90, measured_at: 1.month.ago - 1.day)
      ]
    end
    let!(:risky_measurement) do
      create(:kpi_measurement, kpi: risky, value: 50, measured_at: 2.months.ago)
    end

    it "summarizes progress, risk, overdue measurements, and historical series" do
      dashboard = described_class.new(project:, period: 6).call

      expect(dashboard[:summary]).to eq(
        total: 2,
        average_progress: 70,
        at_risk: 1,
        overdue_measurements: 2
      )
      expect(dashboard[:ranking]).to eq([healthy, risky])
      expect(dashboard[:trend_chart][:datasets].pluck(:label))
        .to contain_exactly("Availability", "Incidents")
    end

    it "falls back to six months for an unsupported period" do
      dashboard = described_class.new(project:, period: 99).call

      expect(dashboard[:period]).to eq(6)
      expect(dashboard[:trend_chart][:labels].size).to eq(6)
    end
  end
end
