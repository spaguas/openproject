# frozen_string_literal: true

class CreateOkrTracking < ActiveRecord::Migration[8.1]
  def change
    create_objectives
    create_kpis
    create_progress_entries
  end

  private

  def create_objectives
    create_table :okr_objectives do |t|
      t.references :project, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.date :start_date
      t.date :target_date

      t.timestamps

      t.index %i[project_id title]
    end
  end

  def create_kpis
    create_table :okr_kpis do |t|
      t.references :objective, null: false, foreign_key: { to_table: :okr_objectives }
      t.string :name, null: false
      t.text :description
      t.string :update_frequency, null: false
      t.string :unit
      t.decimal :baseline_value, null: false, precision: 18, scale: 4
      t.decimal :current_value, null: false, precision: 18, scale: 4
      t.decimal :target_value, null: false, precision: 18, scale: 4
      t.string :target_direction, null: false

      t.timestamps

      t.index :update_frequency
    end
  end

  def create_progress_entries
    create_table :okr_progress_entries do |t|
      t.references :kpi, null: false, foreign_key: { to_table: :okr_kpis }
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.decimal :value, null: false, precision: 18, scale: 4
      t.date :recorded_on, null: false
      t.text :note

      t.timestamps

      t.index %i[kpi_id recorded_on]
    end
  end
end
