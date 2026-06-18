# frozen_string_literal: true

class AddMeasurementsToKpis < ActiveRecord::Migration[8.0]
  def up
    add_column :kpis, :measurement_frequency, :string, null: false, default: "monthly"

    create_table :kpi_measurements do |t|
      t.references :kpi, null: false, foreign_key: { on_delete: :cascade }
      t.references :author, null: true, foreign_key: { to_table: :users, on_delete: :nullify }
      t.decimal :value, precision: 15, scale: 4, null: false
      t.datetime :measured_at, null: false
      t.text :note

      t.timestamps
    end

    add_index :kpi_measurements, %i[kpi_id measured_at]

    execute <<~SQL.squish
      INSERT INTO kpi_measurements (kpi_id, author_id, value, measured_at, created_at, updated_at)
      SELECT id, NULL, current_value, COALESCE(updated_at, created_at), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM kpis
    SQL
  end

  def down
    drop_table :kpi_measurements
    remove_column :kpis, :measurement_frequency
  end
end
