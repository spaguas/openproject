# frozen_string_literal: true

require "spec_helper"

RSpec.describe ContractManagement::InvoiceExtraction::ExtractService do
  let(:extraction) { instance_double(ContractInvoiceExtraction) }
  let(:attachment) { instance_double(Attachment) }
  let(:attachments) { double(first!: attachment) }
  let(:reader) { instance_double(ContractManagement::InvoiceExtraction::DocumentReader) }

  before do
    allow(extraction).to receive(:attachments).and_return(attachments)
    allow(extraction).to receive(:update!)
    allow(extraction).to receive(:update_columns)
  end

  it "stores the extracted fields and completes the draft" do
    text = "Número da Nota: NF-123\nValor total: 1.000,00"
    allow(reader).to receive(:read).with(attachment).and_return(text:, method: "pdf_text")

    result = described_class.new(extraction:, reader:).call

    expect(result).to be_success
    expect(extraction).to have_received(:update!).with(
      status: "completed",
      extracted_data: { "number" => "NF-123", "gross_amount" => 1000.0 },
      extraction_method: "pdf_text"
    )
  end

  it "marks the draft as failed when interpretation raises an error" do
    allow(reader).to receive(:read).and_raise(StandardError, "document unreadable")

    result = described_class.new(extraction:, reader:).call

    expect(result).not_to be_success
    expect(extraction).to have_received(:update_columns).with(
      status: "failed",
      error_message: "document unreadable"
    )
  end
end
