# frozen_string_literal: true

class FixKpisStartDateColumn < ActiveRecord::Migration[8.0]
  def up
    return unless column_exists?(:kpis, :start_date3436)

    if column_exists?(:kpis, :start_date)
      execute <<~SQL.squish
        UPDATE kpis
        SET start_date = start_date3436
        WHERE start_date IS NULL
      SQL
      remove_column :kpis, :start_date3436
    else
      rename_column :kpis, :start_date3436, :start_date
    end
  end

  def down
    return unless column_exists?(:kpis, :start_date)
    return if column_exists?(:kpis, :start_date3436)

    rename_column :kpis, :start_date, :start_date3436
  end
end
