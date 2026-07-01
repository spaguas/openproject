# frozen_string_literal: true

class CreateProjectInitiationRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :project_initiation_requests do |t|
      t.string :title, limit: 255, null: false
      t.string :identifier, null: false
      t.text :description
      t.text :business_case
      t.decimal :estimated_budget, precision: 12, scale: 2
      t.date :target_start_date
      t.date :target_end_date
      t.string :status, default: "draft", null: false
      t.text :rejection_reason
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.references :template_project, null: false, foreign_key: { to_table: :projects }
      t.references :created_project, null: true, foreign_key: { to_table: :projects }

      t.timestamps
    end

    add_index :project_initiation_requests, :identifier, unique: true
    add_index :project_initiation_requests, :status
  end
end
