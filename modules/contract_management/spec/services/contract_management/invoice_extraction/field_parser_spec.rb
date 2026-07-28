# frozen_string_literal: true

require "spec_helper"

RSpec.describe ContractManagement::InvoiceExtraction::FieldParser do
  subject(:data) { described_class.new(text).call }

  let(:text) do
    <<~TEXT
      Número da Nota/Série
      2.245.442/NFE
      Data e Hora de Emissão
      20/07/2026 10:49:42
      VENCIMENTO 19/08/2026
      VALOR TOTAL DA NOTA = R$ 6.102,35
      PIS DEV 1,65% COFINS DEV 7,60% IR (R) 4,80%
    TEXT
  end

  it "extracts labeled fields without an AI service" do
    expect(data).to eq(
      "number" => "2.245.442/NFE",
      "gross_amount" => 6102.35,
      "issued_on" => "2026-07-20",
      "due_on" => "2026-08-19",
      "tax_percentage" => 4.8
    )
  end

  it "calculates the IR percentage when only the withheld amount is shown" do
    invoice = <<~TEXT
      Número da Nota: NF-789
      VALOR TOTAL DA NOTA = R$ 6.102,35
      RETENCAO NA FONTE IRRF: 292,91
    TEXT

    expect(described_class.new(invoice).call["tax_percentage"]).to eq(4.8)
  end

  it "recognizes a JSON QR code payload" do
    payload = '{"numero":"NF-456","valorTotal":"1234.56","dataEmissao":"21/07/2026"}'

    expect(described_class.new(payload).call).to include(
      "number" => "NF-456",
      "gross_amount" => 1234.56,
      "issued_on" => "2026-07-21"
    )
  end
end
