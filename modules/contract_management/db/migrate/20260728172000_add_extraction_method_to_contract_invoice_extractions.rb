# frozen_string_literal: true

class AddExtractionMethodToContractInvoiceExtractions < ActiveRecord::Migration[8.0]
  def change
    add_column :contract_invoice_extractions, :extraction_method, :string
  end
end
