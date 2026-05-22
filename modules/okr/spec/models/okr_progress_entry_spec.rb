# frozen_string_literal: true

require "spec_helper"

RSpec.describe OkrProgressEntry do
  describe "KPI snapshot" do
    it "updates the KPI current value while keeping the progress entry" do
      kpi = create(:okr_kpi, current_value: 20)
      entry = create(:okr_progress_entry, kpi:, value: 45)

      expect(kpi.reload.current_value).to eq(45)
      expect(entry.reload.value).to eq(45)
    end
  end
end
