# frozen_string_literal: true

require "spec_helper"

RSpec.describe ContractInvoice do
  subject(:invoice) do
    described_class.new(
      public_contract: build(:public_contract),
      number: "NF-10",
      gross_amount: 1_000,
      issued_on: Date.new(2026, 7, 1),
      due_on: Date.new(2026, 7, 31),
      tax_percentage: 10,
      status: "pending"
    )
  end

  it "calculates the net amount after tax compensation" do
    invoice.validate

    expect(invoice.net_amount).to eq(900)
  end

  it "rounds the calculated net amount to monetary precision" do
    invoice.gross_amount = 6102.35
    invoice.tax_percentage = 4.8

    invoice.recalculate_net_amount

    expect(invoice.net_amount).to eq(5809.44)
  end

  it "rejects a due date before the issue date" do
    invoice.due_on = Date.new(2026, 6, 30)

    expect(invoice).not_to be_valid
    expect(invoice.errors[:due_on]).to be_present
  end
end
