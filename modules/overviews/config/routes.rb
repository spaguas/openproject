# frozen_string_literal: true

Rails.application.routes.draw do
  get "team_allocation",
      to: "homescreen#team_allocation",
      as: :global_team_allocation
  get "budget_monitoring",
      to: "homescreen#budget_monitoring",
      as: :global_budget_monitoring
  get "kpi_monitoring",
      to: "homescreen#kpi_monitoring",
      as: :global_kpi_monitoring

  constraints(Constraints::ProjectIdentifier) do
    scope "projects/:project_id", as: "project" do
      scope module: "overviews" do
        resource :overview, path: "/", only: [:show] do
          get :dashboard, on: :member
          get :kpis, on: :member
          get :budget, on: :member
          get :team_allocation, on: :member
        end

        controller :overviews do
          get "project_custom_fields_sidebar" => :project_custom_fields_sidebar, as: :custom_fields_sidebar
          get "project_life_cycle_sidebar" => :project_life_cycle_sidebar, as: :life_cycle_sidebar
        end
      end
    end
  end

  resources :project_phases, controller: "overviews/project_phases", only: %i[edit update] do
    put :preview, on: :member
  end
end
