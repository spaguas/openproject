# frozen_string_literal: true

require "rails_helper"

RSpec.describe KpiMeasurement do
  describe "validations" do
    it "does not allow a measurement date in the future" do
      measurement = build(:kpi_measurement, measured_at: Date.tomorrow)

      expect(measurement).not_to be_valid
      expect(measurement.errors.details[:measured_at]).to include(error: :not_in_future)
    end

    it "allows a measurement date in the past" do
      measurement = build(:kpi_measurement, measured_at: Date.yesterday)

      expect(measurement).to be_valid
    end
  end

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

    it "updates the KPI when the newest measurement is edited" do
      kpi = create(:kpi, current_value: 10)
      measurement = create(:kpi_measurement, kpi:, value: 40, measured_at: 1.day.ago)

      measurement.update!(value: 55)

      expect(kpi.reload.current_value).to eq(55)
    end

    it "updates the KPI when the newest measurement is deleted" do
      kpi = create(:kpi, current_value: 10)
      create(:kpi_measurement, kpi:, value: 40, measured_at: 2.days.ago)
      measurement = create(:kpi_measurement, kpi:, value: 75, measured_at: 1.day.ago)

      measurement.destroy!

      expect(kpi.reload.current_value).to eq(40)
    end
  end
end
