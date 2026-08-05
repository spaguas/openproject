# frozen_string_literal: true

class CreateContractManagement < ActiveRecord::Migration[8.0]
  def change
    create_table :public_contracts do |t|
      t.references :project, null: false, foreign_key: true, index: true
      t.string :number, null: false
      t.string :sei_process_number, null: false
      t.string :payment_sei_process_number
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.integer :duration_months, null: false
      t.text :description, null: false
      t.decimal :amount, precision: 18, scale: 2, null: false
      t.string :adjustment_index
      t.integer :deadline_notification_days, null: false, default: 30
      t.timestamps
    end
    add_index :public_contracts, %i[project_id number], unique: true

    create_table :contract_invoices do |t|
      t.references :public_contract, null: false, foreign_key: true, index: true
      t.string :number, null: false
      t.decimal :gross_amount, precision: 18, scale: 2, null: false
      t.date :issued_on, null: false
      t.date :due_on, null: false
      t.decimal :tax_percentage, precision: 7, scale: 4, null: false, default: 0
      t.decimal :net_amount, precision: 18, scale: 2, null: false
      t.string :status, null: false, default: "pending"
      t.timestamps
    end
    add_index :contract_invoices, %i[public_contract_id number], unique: true

    create_table :contract_measurements do |t|
      t.references :public_contract, null: false, foreign_key: true, index: true
      t.references :invoice, foreign_key: { to_table: :contract_invoices }, index: true
      t.string :number, null: false
      t.date :measured_on, null: false
      t.decimal :amount, precision: 18, scale: 2, null: false
      t.string :status, null: false, default: "pending"
      t.date :approved_on
      t.text :description
      t.timestamps
    end
    add_index :contract_measurements, %i[public_contract_id number], unique: true

    create_table :contract_amendments do |t|
      t.references :public_contract, null: false, foreign_key: true, index: true
      t.string :number, null: false
      t.date :start_date, null: false
      t.integer :duration_months, null: false
      t.decimal :amount, precision: 18, scale: 2, null: false, default: 0
      t.text :description, null: false
      t.timestamps
    end
    add_index :contract_amendments, %i[public_contract_id number], unique: true

    create_table :contract_responsibilities do |t|
      t.references :public_contract, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      t.string :role, null: false
      t.date :starts_on, null: false
      t.date :ends_on
      t.boolean :notify, null: false, default: true
      t.timestamps
    end
    add_index :contract_responsibilities,
              %i[public_contract_id user_id role starts_on],
              unique: true,
              name: "index_contract_responsibilities_unique"

    create_table :contract_bank_orders do |t|
      t.references :public_contract, null: false, foreign_key: true, index: true
      t.string :number, null: false
      t.date :issued_on, null: false
      t.decimal :amount, precision: 18, scale: 2, null: false
      t.text :description
      t.timestamps
    end
    add_index :contract_bank_orders, %i[public_contract_id number], unique: true

    create_table :contract_bank_order_invoices do |t|
      t.references :bank_order, null: false, foreign_key: { to_table: :contract_bank_orders }, index: true
      t.references :invoice, null: false, foreign_key: { to_table: :contract_invoices }, index: true
      t.timestamps
    end
    add_index :contract_bank_order_invoices,
              %i[bank_order_id invoice_id],
              unique: true,
              name: "index_contract_bank_orders_invoices_unique"

    create_table :contract_deadline_notifications do |t|
      t.references :public_contract, null: false, foreign_key: true, index: true
      t.references :invoice, foreign_key: { to_table: :contract_invoices }, index: true
      t.string :deadline_type, null: false
      t.date :deadline_on, null: false
      t.date :sent_on, null: false
      t.timestamps
    end
    add_index :contract_deadline_notifications,
              %i[public_contract_id deadline_type deadline_on],
              unique: true,
              where: "invoice_id IS NULL",
              name: "index_contract_deadline_notifications_contract_unique"
    add_index :contract_deadline_notifications,
              %i[invoice_id deadline_type deadline_on],
              unique: true,
              where: "invoice_id IS NOT NULL",
              name: "index_contract_deadline_notifications_invoice_unique"
  end
end
