# frozen_string_literal: true

require "rails_helper"

RSpec.describe Kpi do
  describe ".visible" do
    shared_let(:primary_project) { create(:project, enabled_module_names: %w[kpis]) }
    shared_let(:associated_project) { create(:project, enabled_module_names: %w[kpis]) }
    shared_let(:user) do
      create(:user, member_with_permissions: { associated_project => %i[view_kpis] })
    end
    shared_let(:kpi) { create(:kpi, project: primary_project, projects: [associated_project]) }

    it "includes KPIs shared with a project visible to the user" do
      expect(described_class.visible(user)).to contain_exactly(kpi)
    end
  end

  describe "start date" do
    it "persists the configured start date" do
      kpi = create(:kpi, start_date: Date.new(2026, 6, 1))

      expect(kpi.reload.start_date).to eq Date.new(2026, 6, 1)
    end
  end

  describe "#progress_percentage" do
    it "evaluates an increasing KPI using the latest measurement" do
      kpi = create(:kpi, current_value: 20, target_value: 100, direction: "increase")
      create(:kpi_measurement, kpi:, value: 60)

      expect(kpi.reload.progress_percentage).to eq(60)
    end

    it "evaluates a decreasing KPI using the latest measurement" do
      kpi = create(:kpi, current_value: 100, target_value: 20, direction: "decrease")
      create(:kpi_measurement, kpi:, value: 40)

      expect(kpi.reload.progress_percentage).to eq(50)
    end
  end

  describe "#next_measurement_at" do
    it "uses the configured measurement frequency" do
      kpi = create(:kpi, measurement_frequency: "quarterly")
      measured_at = Time.zone.local(2026, 1, 15, 10, 30)
      create(:kpi_measurement, kpi:, measured_at:)

      expect(kpi.next_measurement_at).to eq(Time.zone.local(2026, 4, 15, 10, 30))
    end
  end
end
