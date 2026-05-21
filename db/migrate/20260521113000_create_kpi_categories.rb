# frozen_string_literal: true

class CreateKpiCategories < ActiveRecord::Migration[8.0]
  def up
    create_table :kpi_categories do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :kpi_categories, :name, unique: true
    add_reference :kpis, :kpi_category, foreign_key: { on_delete: :nullify }, index: true

    migrate_existing_kpi_categories
  end

  def down
    remove_reference :kpis, :kpi_category, foreign_key: true
    drop_table :kpi_categories
  end

  private

  def migrate_existing_kpi_categories
    categories = select_values(<<~SQL.squish)
      SELECT DISTINCT category
      FROM kpis
      WHERE category IS NOT NULL AND category <> ''
      ORDER BY category
    SQL

    categories.each_with_index do |category, index|
      quoted_category = quote(category)
      execute <<~SQL.squish
        INSERT INTO kpi_categories (name, position, active, created_at, updated_at)
        VALUES (#{quoted_category}, #{index + 1}, TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      SQL

      execute <<~SQL.squish
        UPDATE kpis
        SET kpi_category_id = (
          SELECT id
          FROM kpi_categories
          WHERE name = #{quoted_category}
        )
        WHERE category = #{quoted_category}
      SQL
    end
  end
end
