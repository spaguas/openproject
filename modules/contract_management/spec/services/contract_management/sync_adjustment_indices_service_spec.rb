# frozen_string_literal: true

require "spec_helper"

RSpec.describe ContractManagement::SyncAdjustmentIndicesService do
  let(:project) { create(:project) }
  let(:client) { instance_double(ContractManagement::BcbSgsClient) }
  let(:today) { Date.new(2026, 7, 28) }

  before do
    ContractAdjustmentIndexType.create!(
      project:,
      name: "IPCA",
      external_series_code: 433,
      periodicity: "annual"
    )
  end

  it "synchronizes each official monthly variation without annual aggregation" do
    allow(client).to receive(:values).with(
      series_code: 433,
      from: Date.new(2023, 1, 1),
      to: today
    ).and_return(
      [
        { date: Date.new(2023, 1, 1), value: 1.to_d },
        { date: Date.new(2023, 2, 1), value: 2.to_d },
        { date: Date.new(2024, 1, 1), value: 3.to_d },
        { date: Date.new(2025, 1, 1), value: 4.to_d },
        { date: Date.new(2026, 1, 1), value: 5.to_d }
      ]
    )

    result = described_class.new(client:, today:).call

    expect(result[:failed]).to be_empty
    expect(result[:synchronized]).to eq(1)
    expect(ContractAdjustmentIndex.where(project:, name: "IPCA").count).to eq(5)
    expect(
      ContractAdjustmentIndex.find_by!(project:, name: "IPCA", year: 2023, month: 2).percentage
    ).to eq(2)
    expect(
      ContractAdjustmentIndex.find_by!(project:, name: "IPCA", year: 2026, month: 1).source
    ).to eq(described_class::SOURCE)
  end

  it "continues synchronizing other indices when one request fails" do
    ContractAdjustmentIndexType.create!(
      project:,
      name: "INPC",
      external_series_code: 188,
      periodicity: "annual"
    )
    allow(client).to receive(:values).with(series_code: 433, from: anything, to: today)
      .and_raise(ContractManagement::BcbSgsClient::RequestError, "Unavailable")
    allow(client).to receive(:values).with(series_code: 188, from: anything, to: today)
      .and_return([{ date: Date.new(2026, 1, 1), value: 1.to_d }])

    result = described_class.new(client:, today:).call

    expect(result[:synchronized]).to eq(1)
    expect(result[:failed].size).to eq(1)
    expect(ContractAdjustmentIndex.find_by!(project:, name: "INPC", year: 2026, month: 1).percentage).to eq(1)
  end
end
