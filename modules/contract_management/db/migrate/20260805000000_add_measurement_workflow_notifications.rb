# frozen_string_literal: true

class AddMeasurementWorkflowNotifications < ActiveRecord::Migration[8.0]
  def change
    add_column :public_contracts, :measurement_evaluation_business_days, :integer, null: false, default: 5

    add_reference :contract_invoices,
                  :measurement,
                  foreign_key: { to_table: :contract_measurements },
                  index: { unique: true }
    reversible do |direction|
      direction.up do
        execute <<~SQL.squish
          UPDATE contract_invoices
          SET measurement_id = linked_measurements.id
          FROM (
            SELECT DISTINCT ON (invoice_id) id, invoice_id
            FROM contract_measurements
            WHERE invoice_id IS NOT NULL
            ORDER BY invoice_id, id
          ) AS linked_measurements
          WHERE contract_invoices.id = linked_measurements.invoice_id
        SQL
      end
    end

    add_reference :contract_measurements, :approved_by, foreign_key: { to_table: :users }, index: true
    add_column :contract_measurements, :evaluation_due_on, :date

    create_table :contract_notifications do |t|
      t.references :public_contract, null: false, foreign_key: true
      t.references :subject, polymorphic: true, null: false
      t.string :kind, null: false
      t.date :sent_on, null: false
      t.timestamps
    end
    add_index :contract_notifications,
              %i[subject_type subject_id kind],
              unique: true,
              name: "index_contract_notifications_unique_event"
  end
end
