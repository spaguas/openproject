# frozen_string_literal: true

Rails.application.routes.draw do
  get "contract-management",
      to: "contract_management/portfolio#index",
      as: :contract_management_portfolio
  get "contract-management/new",
      to: "contract_management/portfolio#new",
      as: :new_contract_management_portfolio_contract

  scope "projects/:project_id", as: "project" do
    scope "contracts", module: "contract_management", as: "contract_management" do
      resource :settings, only: %i[edit update]
      resources :adjustment_indices, except: :show
      resources :adjustment_index_types, except: :show do
        post :synchronize, on: :collection
      end
      resources :contracts do
        resources :measurements, except: :show
        resources :invoices, except: :show do
          post :extract, on: :collection
        end
        resources :amendments, except: :show
        resources :responsibilities, except: :show
        resources :bank_orders, except: :show
        resources :budget_commitments, except: :show do
          resource :conversion,
                   only: %i[new create],
                   controller: "commitment_conversions"
        end
      end
    end
  end
end
