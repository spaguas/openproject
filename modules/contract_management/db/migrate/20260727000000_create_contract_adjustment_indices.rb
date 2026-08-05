# frozen_string_literal: true

class CreateContractAdjustmentIndices < ActiveRecord::Migration[8.0]
  def change
    create_table :contract_adjustment_indices do |t|
      t.references :project, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.integer :year, null: false
      t.decimal :percentage, precision: 9, scale: 4, null: false
      t.string :periodicity, null: false
      t.timestamps
    end

    add_index :contract_adjustment_indices,
              %i[project_id name year],
              unique: true,
              name: "index_contract_adjustment_indices_unique"

    add_reference :public_contracts,
                  :contract_adjustment_index,
                  foreign_key: true,
                  index: true
    add_column :public_contracts, :adjustment_start_date, :date
  end
end
