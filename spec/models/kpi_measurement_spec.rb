# frozen_string_literal: true

require "rails_helper"

RSpec.describe KpiMeasurement do
  describe "KPI current value" do
    it "uses the measurement with the most recent measurement date" do
      kpi = create(:kpi, current_value: 10)

      create(:kpi_measurement, kpi:, value: 40, measured_at: 2.days.ago)
      create(:kpi_measurement, kpi:, value: 25, measured_at: 3.days.ago)

      expect(kpi.reload.current_value).to eq(40)
    end

    it "updates the KPI when a newer measurement is entered" do
      kpi = create(:kpi, current_value: 10)
      create(:kpi_measurement, kpi:, value: 40, measured_at: 2.days.ago)

      create(:kpi_measurement, kpi:, value: 75, measured_at: 1.day.ago)

      expect(kpi.reload.current_value).to eq(75)
    end
  end
end
