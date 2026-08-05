# frozen_string_literal: true

require "spec_helper"

RSpec.describe ContractManagement::BusinessDayCalculator do
  describe ".add" do
    it "skips weekends" do
      friday = Date.new(2026, 8, 7)

      expect(described_class.add(friday, 1)).to eq(Date.new(2026, 8, 10))
      expect(described_class.add(friday, 5)).to eq(Date.new(2026, 8, 14))
    end

    it "returns the starting date for a zero-day deadline" do
      date = Date.new(2026, 8, 8)

      expect(described_class.add(date, 0)).to eq(date)
    end
  end
end
