# frozen_string_literal: true

class CreateKpis < ActiveRecord::Migration[8.0]
  def change
    create_table :kpis do |t|
      t.references :project, null: false, foreign_key: { on_delete: :cascade }
      t.references :owner, null: true, foreign_key: { to_table: :users, on_delete: :nullify }

      t.string :name, null: false
      t.text :description
      t.string :category
      t.string :unit
      t.decimal :current_value, precision: 15, scale: 4, null: false, default: 0
      t.decimal :target_value, precision: 15, scale: 4, null: false
      t.string :direction, null: false, default: "increase"
      t.string :status, null: false, default: "not_started"
      t.date :start_date
      t.date :due_date

      t.timestamps
    end

    add_index :kpis, %i[project_id status]
    add_index :kpis, %i[project_id due_date]
  end
end
