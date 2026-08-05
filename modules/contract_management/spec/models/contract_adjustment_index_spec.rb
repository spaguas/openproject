# frozen_string_literal: true

require "spec_helper"

RSpec.describe ContractAdjustmentIndex do
  subject(:adjustment_index) do
    described_class.new(
      project: build(:project),
      name: "IPCA",
      year: 2026,
      month: 7,
      percentage: 4.5,
      periodicity: "annual"
    )
  end

  it "is valid with the required index information" do
    expect(adjustment_index).to be_valid
  end

  it "maps each periodicity to its number of months" do
    expect(described_class::PERIOD_MONTHS).to eq(
      "monthly" => 1,
      "annual" => 12,
      "quarterly" => 3,
      "semiannual" => 6,
      "biennial" => 24
    )
  end

  it "supports monthly periodicity" do
    adjustment_index.periodicity = "monthly"

    expect(adjustment_index).to be_valid
    expect(adjustment_index.period_months).to eq(1)
  end

  it "recognizes the official BCB series for common indices" do
    expect(adjustment_index.bcb_series_code).to eq(433)

    adjustment_index.name = "IGP-M"
    expect(adjustment_index.bcb_series_code).to eq(189)
  end

  it "uses the explicitly configured BCB series code" do
    adjustment_index.external_series_code = 999

    expect(adjustment_index.bcb_series_code).to eq(999)
  end
end
