# frozen_string_literal: true

class CreateMeetingAIAnalyses < ActiveRecord::Migration[8.0]
  def change
    create_table :meeting_ai_analyses do |t|
      t.references :meeting, null: false, foreign_key: true, index: { unique: true }
      t.references :generated_by, null: true, foreign_key: { to_table: :users }
      t.string :provider, null: false, default: "openai"
      t.string :model
      t.string :recording_reference
      t.text :transcript
      t.text :insights
      t.text :conclusions
      t.text :next_steps
      t.string :status, null: false, default: "draft"
      t.text :error_message
      t.timestamps null: false
    end
  end
end
