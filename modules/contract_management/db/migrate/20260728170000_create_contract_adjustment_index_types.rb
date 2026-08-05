# frozen_string_literal: true

class CreateContractAdjustmentIndexTypes < ActiveRecord::Migration[8.0]
  class AdjustmentIndex < ApplicationRecord
    self.table_name = "contract_adjustment_indices"
  end

  class AdjustmentIndexType < ApplicationRecord
    self.table_name = "contract_adjustment_index_types"
  end

  class PublicContractRecord < ApplicationRecord
    self.table_name = "public_contracts"
  end

  def up
    create_table :contract_adjustment_index_types do |t|
      t.references :project, null: false, foreign_key: true, index: true
      t.string :name, null: false
      t.integer :external_series_code, null: false
      t.string :periodicity, null: false, default: "annual"
      t.boolean :active, null: false, default: true
      t.datetime :last_synced_at
      t.text :last_sync_error
      t.timestamps
    end

    add_index :contract_adjustment_index_types,
              %i[project_id name],
              unique: true,
              name: "index_contract_adjustment_index_types_unique"
    add_index :contract_adjustment_index_types,
              %i[project_id external_series_code],
              unique: true,
              name: "index_contract_adjustment_index_types_series_unique"

    add_reference :contract_adjustment_indices,
                  :contract_adjustment_index_type,
                  foreign_key: true,
                  index: { name: "index_contract_indices_on_type_id" }
    add_reference :public_contracts,
                  :contract_adjustment_index_type,
                  foreign_key: true,
                  index: { name: "index_public_contracts_on_adjustment_type_id" }

    migrate_existing_indices
  end

  def down
    remove_reference :public_contracts, :contract_adjustment_index_type, foreign_key: true
    remove_reference :contract_adjustment_indices, :contract_adjustment_index_type, foreign_key: true
    drop_table :contract_adjustment_index_types
  end

  private

  def migrate_existing_indices
    AdjustmentIndex.reset_column_information
    AdjustmentIndexType.reset_column_information
    PublicContractRecord.reset_column_information

    AdjustmentIndex.order(:project_id, :name, year: :desc).group_by { |index| [index.project_id, index.name.downcase] }.each_value do |indices|
      template = indices.first
      series_code = template.external_series_code || known_series_code(template.name)
      next unless series_code

      type = AdjustmentIndexType.find_or_initialize_by(
        project_id: template.project_id,
        external_series_code: series_code
      )
      type.assign_attributes(
        name: type.name.presence || template.name,
        periodicity: template.periodicity,
        last_synced_at: [type.last_synced_at, *indices.filter_map(&:last_synced_at)].compact.max
      )
      type.save!
      AdjustmentIndex.where(id: indices.map(&:id)).update_all(contract_adjustment_index_type_id: type.id)
      PublicContractRecord
        .where(contract_adjustment_index_id: indices.map(&:id))
        .update_all(contract_adjustment_index_type_id: type.id)
    end
  end

  def known_series_code(name)
    {
      "IPCA" => 433,
      "INPC" => 188,
      "IGP-M" => 189,
      "IGPM" => 189
    }[name.to_s.upcase.gsub(/[^A-Z0-9-]/, "")]
  end
end
