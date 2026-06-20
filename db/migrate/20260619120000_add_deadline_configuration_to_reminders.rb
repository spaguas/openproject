# frozen_string_literal: true

class AddDeadlineConfigurationToReminders < ActiveRecord::Migration[8.0]
  def change
    change_table :reminders, bulk: true do |t|
      t.string :schedule_type, null: false, default: "one_time"
      t.integer :days_before
      t.string :recurrence, null: false, default: "once"
      t.string :delivery_channel, null: false, default: "system_only"
    end

    add_index :reminders, %i[remindable_type remindable_id creator_id schedule_type],
              name: "index_reminders_on_remindable_creator_and_schedule_type"
  end
end
