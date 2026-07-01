# frozen_string_literal: true

Rails.application.routes.draw do
  resources :project_initiation_requests do
    member do
      post :submit
      post :review
      post :request_info
      post :reject
      post :approve
    end
  end
end
