# frozen_string_literal: true

require "spec_helper"

RSpec.describe PublicContract do
  subject(:contract) do
    described_class.new(
      project:,
      number: "001/2026",
      sei_process_number: "006.000001/2026-01",
      start_date: Date.new(2026, 1, 1),
      end_date: Date.new(2026, 12, 31),
      duration_months: 12,
      description: "Public service contract",
      amount: 100_000,
      deadline_notification_days: 30
    )
  end

  let(:project) { create(:project) }

  it "is valid with the required public contract information" do
    expect(contract).to be_valid
  end

  it "rejects an end date before the start date" do
    contract.end_date = Date.new(2025, 12, 31)

    expect(contract).not_to be_valid
    expect(contract.errors[:end_date]).to be_present
  end

  it "includes amendment values in the total amount" do
    contract.amendments.build(
      number: "A1",
      start_date: Date.new(2027, 1, 1),
      duration_months: 6,
      amount: 10_000,
      description: "Extension"
    )

    expect(contract.total_amount).to eq(110_000)
  end

  it "calculates physical and financial execution against the updated total" do
    allow(contract).to receive_messages(
      total_amount: 120_000.to_d,
      measured_amount: 60_000.to_d,
      paid_amount: 30_000.to_d
    )

    expect(contract.physical_execution_percentage).to eq(50)
    expect(contract.financial_execution_percentage).to eq(25)
  end

  it "returns zero execution percentages for a zero-value contract" do
    contract.amount = 0

    expect(contract.physical_execution_percentage).to be_zero
    expect(contract.financial_execution_percentage).to be_zero
  end

  it "starts calculating adjustments on the configured adjustment date" do
    index = ContractAdjustmentIndex.new(
      project:,
      name: "IPCA",
      year: 2026,
      month: 7,
      percentage: 10,
      periodicity: "annual"
    )
    contract.contract_adjustment_index = index
    contract.adjustment_start_date = Date.new(2026, 7, 1)

    expect(contract.adjustment_amount(on: Date.new(2026, 6, 30))).to be_zero
    expect(contract.adjustment_amount(on: Date.new(2026, 7, 1))).to eq(10_000)
    expect(contract.adjusted_total_amount(on: Date.new(2027, 7, 1))).to eq(121_000)
  end

  it "uses the index periodicity for subsequent adjustments" do
    contract.contract_adjustment_index = ContractAdjustmentIndex.new(
      project:,
      name: "IPCA",
      year: 2026,
      month: 1,
      percentage: 2,
      periodicity: "quarterly"
    )
    contract.adjustment_start_date = Date.new(2026, 1, 31)

    expect(contract.adjustment_occurrences(on: Date.new(2026, 4, 1))).to eq(1)
    expect(contract.adjustment_occurrences(on: Date.new(2026, 4, 30))).to eq(2)
  end

  it "compounds synchronized monthly values from the adjustment start month" do
    index_type = ContractAdjustmentIndexType.create!(
      project:,
      name: "IPCA",
      external_series_code: 433,
      periodicity: "annual"
    )
    { 6 => 9, 7 => 1, 8 => 2, 9 => 8 }.each do |month, percentage|
      index_type.adjustment_indices.create!(
        project:,
        name: "IPCA",
        year: 2026,
        month:,
        percentage:,
        periodicity: "monthly"
      )
    end
    contract.contract_adjustment_index_type = index_type
    contract.adjustment_start_date = Date.new(2026, 7, 1)

    expect(contract.adjusted_total_amount(on: Date.new(2026, 8, 31))).to eq(103_020)
  end
end
