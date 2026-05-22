# frozen_string_literal: true

Rails.application.routes.draw do
  scope "projects/:project_id", as: "project" do
    resources :okr_objectives, path: "okrs", controller: "okr/objectives" do
      resources :kpis, controller: "okr/kpis", except: :index do
        resources :progress_entries,
                  controller: "okr/progress_entries",
                  only: :create
      end
    end
  end
end
