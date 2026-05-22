# frozen_string_literal: true

require "open_project/plugins"

module OpenProject::Okr
  class Engine < ::Rails::Engine
    engine_name :openproject_okr

    include OpenProject::Plugins::ActsAsOpEngine

    register "openproject-okr",
             author_url: "https://www.openproject.org",
             bundled: true do
      project_module :okr do
        permission :view_okrs,
                   {
                     "okr/objectives": %i[index show],
                     "okr/kpis": %i[show]
                   },
                   permissible_on: :project

        permission :manage_okrs,
                   {
                     "okr/objectives": %i[new create edit update destroy],
                     "okr/kpis": %i[new create edit update destroy],
                     "okr/progress_entries": %i[create]
                   },
                   permissible_on: :project,
                   require: :loggedin,
                   dependencies: %i[view_okrs]
      end

      menu :project_menu,
           :okr,
           { controller: "/okr/objectives", action: :index },
           caption: :"okr.label_plural",
           after: :work_packages,
           icon: "graph"
    end
  end
end
