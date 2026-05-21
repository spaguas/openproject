# frozen_string_literal: true

class EnableKpisProjectModule < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      INSERT INTO enabled_modules (project_id, name)
      SELECT projects.id, 'kpis'
      FROM projects
      WHERE NOT EXISTS (
        SELECT 1
        FROM enabled_modules
        WHERE enabled_modules.project_id = projects.id
          AND enabled_modules.name = 'kpis'
      )
    SQL

    setting = Setting.find_by(name: "default_projects_modules")
    return unless setting

    Setting.default_projects_modules = (Setting.default_projects_modules + ["kpis"]).uniq
  end

  def down
    execute "DELETE FROM enabled_modules WHERE name = 'kpis'"

    setting = Setting.find_by(name: "default_projects_modules")
    return unless setting

    Setting.default_projects_modules = Setting.default_projects_modules - ["kpis"]
  end
end
