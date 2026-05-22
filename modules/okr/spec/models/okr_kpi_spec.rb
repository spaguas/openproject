# frozen_string_literal: true

require "spec_helper"

RSpec.describe OkrKpi do
  describe "value tracking" do
    it "defaults the current value to the baseline on create" do
      kpi = create(:okr_kpi, current_value: nil, baseline_value: 10)

      expect(kpi.current_value).to eq(10)
    end

    it "calculates progress toward a higher target" do
      kpi = build(:okr_kpi, baseline_value: 20, current_value: 50, target_value: 80)

      expect(kpi.progress_percentage).to eq(50)
    end

    it "calculates progress toward a lower target" do
      kpi = build(:okr_kpi, target_direction: "decrease", baseline_value: 80, current_value: 50, target_value: 20)

      expect(kpi.progress_percentage).to eq(50)
    end

    it "does not divide by zero when target and baseline are equal" do
      kpi = build(:okr_kpi, baseline_value: 20, current_value: 20, target_value: 20)

      expect(kpi.progress_percentage).to be_nil
    end
  end
end
