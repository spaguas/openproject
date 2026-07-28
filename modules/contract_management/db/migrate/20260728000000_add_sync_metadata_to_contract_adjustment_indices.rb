# frozen_string_literal: true

class AddSyncMetadataToContractAdjustmentIndices < ActiveRecord::Migration[8.0]
  def change
    add_column :contract_adjustment_indices, :external_series_code, :integer
    add_column :contract_adjustment_indices, :source, :string
    add_column :contract_adjustment_indices, :last_synced_at, :datetime
    add_index :contract_adjustment_indices, :external_series_code
  end
end
