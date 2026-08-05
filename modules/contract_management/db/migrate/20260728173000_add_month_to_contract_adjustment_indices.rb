# frozen_string_literal: true

class AddMonthToContractAdjustmentIndices < ActiveRecord::Migration[8.0]
  OLD_INDEX = "index_contract_adjustment_indices_unique"
  NEW_INDEX = "index_contract_adjustment_indices_by_month_unique"

  def up
    add_column :contract_adjustment_indices, :month, :integer
    remove_index :contract_adjustment_indices, name: OLD_INDEX
    add_index :contract_adjustment_indices,
              %i[project_id name year month],
              unique: true,
              name: NEW_INDEX

    execute <<~SQL.squish
      UPDATE contract_adjustment_indices
      SET month = 12
      WHERE month IS NULL
    SQL
  end

  def down
    remove_index :contract_adjustment_indices, name: NEW_INDEX
    add_index :contract_adjustment_indices,
              %i[project_id name year],
              unique: true,
              name: OLD_INDEX
    remove_column :contract_adjustment_indices, :month
  end
end
