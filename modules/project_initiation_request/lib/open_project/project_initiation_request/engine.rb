# frozen_string_literal: true

require "open_project/plugins"

module OpenProject::ProjectInitiationRequest
  class Engine < ::Rails::Engine
    engine_name :openproject_project_initiation_request

    include OpenProject::Plugins::ActsAsOpEngine

    register "openproject-project_initiation_request",
             author_url: "https://www.spaguas.sp.gov.br",
             bundled: true do
      project_module nil do
        permission :view_project_initiation_requests,
                   { project_initiation_requests: %i[index show] },
                   permissible_on: :global,
                   require: :loggedin

        permission :create_project_initiation_requests,
                   { project_initiation_requests: %i[new create edit update submit] },
                   permissible_on: :global,
                   require: :loggedin,
                   dependencies: %i[view_project_initiation_requests]

        permission :approve_project_initiation_requests,
                   { project_initiation_requests: %i[review request_info reject approve] },
                   permissible_on: :global,
                   require: :loggedin,
                   dependencies: %i[view_project_initiation_requests]
      end

      should_render = ->(*) { User.current.allowed_globally?(:view_project_initiation_requests) }

      menu :top_menu,
           :project_initiation_requests,
           { controller: "/project_initiation_requests", action: :index },
           context: :modules,
           caption: :"project_initiation_requests.label_plural",
           icon: "project",
           after: :projects,
           if: should_render

      menu :global_menu,
           :project_initiation_requests,
           { controller: "/project_initiation_requests", action: :index },
           caption: :"project_initiation_requests.label_plural",
           icon: "project",
           after: :projects,
           if: should_render
    end
  end
end
