# frozen_string_literal: true

class AddKpiAssociations < ActiveRecord::Migration[8.0]
  def change
    create_table :kpis_projects, id: false do |t|
      t.references :kpi, null: false, foreign_key: { on_delete: :cascade }
      t.references :project, null: false, foreign_key: { on_delete: :cascade }
    end

    add_index :kpis_projects, %i[kpi_id project_id], unique: true
    add_index :kpis_projects, %i[project_id kpi_id], unique: true

    create_table :groups_kpis, id: false do |t|
      t.references :group, null: false, foreign_key: { to_table: :users, on_delete: :cascade }
      t.references :kpi, null: false, foreign_key: { on_delete: :cascade }
    end

    add_index :groups_kpis, %i[group_id kpi_id], unique: true
    add_index :groups_kpis, %i[kpi_id group_id], unique: true

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          INSERT INTO kpis_projects (kpi_id, project_id)
          SELECT id, project_id
          FROM kpis
        SQL
      end
    end
  end
end
