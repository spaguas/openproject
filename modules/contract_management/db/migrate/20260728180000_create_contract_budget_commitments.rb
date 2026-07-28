# frozen_string_literal: true

class CreateContractBudgetCommitments < ActiveRecord::Migration[8.0]
  # rubocop:disable Metrics/AbcSize
  def change
    create_table :contract_budget_commitments do |t|
      t.references :public_contract, null: false, foreign_key: true, index: true
      t.references :responsible, null: false, foreign_key: { to_table: :users }, index: true
      t.references :source_commitment,
                   foreign_key: { to_table: :contract_budget_commitments },
                   index: true
      t.string :kind, null: false
      t.string :number, null: false
      t.date :issued_on, null: false
      t.integer :fiscal_year, null: false
      t.decimal :total_amount, precision: 18, scale: 2, null: false
      t.string :status, null: false, default: "active"
      t.jsonb :monthly_distribution, null: false, default: {}
      t.timestamps
    end

    add_index :contract_budget_commitments,
              %i[public_contract_id kind number],
              unique: true,
              name: "index_contract_budget_commitments_unique"

    add_reference :contract_bank_orders,
                  :budget_commitment,
                  foreign_key: { to_table: :contract_budget_commitments },
                  index: true

    create_table :contract_project_settings do |t|
      t.references :project, null: false, foreign_key: true, index: { unique: true }
      t.decimal :commitment_consumption_alert_percentage,
                precision: 5,
                scale: 2,
                null: false,
                default: 80
      t.timestamps
    end
  end
  # rubocop:enable Metrics/AbcSize
end
