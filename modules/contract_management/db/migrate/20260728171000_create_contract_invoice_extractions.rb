# frozen_string_literal: true

class CreateContractInvoiceExtractions < ActiveRecord::Migration[8.0]
  def change
    create_table :contract_invoice_extractions do |t|
      t.references :public_contract, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      t.string :status, null: false, default: "pending"
      t.jsonb :extracted_data, null: false, default: {}
      t.text :error_message
      t.string :model
      t.timestamps
    end
  end
end
