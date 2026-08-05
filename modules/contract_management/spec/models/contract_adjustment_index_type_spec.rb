# frozen_string_literal: true

require "spec_helper"

RSpec.describe ContractAdjustmentIndexType do
  subject(:index_type) do
    described_class.new(
      project: build(:project),
      name: "IPCA",
      external_series_code: 433,
      periodicity: "annual",
      active: true
    )
  end

  it "is valid with its search configuration" do
    expect(index_type).to be_valid
  end

  it "requires a positive BCB SGS series code" do
    index_type.external_series_code = 0

    expect(index_type).to be_invalid
    expect(index_type.errors[:external_series_code]).to be_present
  end

  it "maps its update frequency to months" do
    index_type.periodicity = "quarterly"

    expect(index_type.period_months).to eq(3)
  end
end
