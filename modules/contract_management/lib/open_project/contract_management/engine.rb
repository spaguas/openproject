# frozen_string_literal: true

require "open_project/plugins"

module OpenProject::ContractManagement
  class Engine < ::Rails::Engine
    engine_name :openproject_contract_management

    include OpenProject::Plugins::ActsAsOpEngine

    register "openproject-contract_management",
             author_url: "https://www.spaguas.sp.gov.br",
             bundled: true do
      project_module :contract_management do
        permission :view_contracts,
                   {
                     "contract_management/contracts": %i[index show],
                     "contract_management/adjustment_indices": %i[index],
                     "contract_management/adjustment_index_types": %i[index],
                     "contract_management/measurements": %i[index],
                     "contract_management/invoices": %i[index],
                     "contract_management/amendments": %i[index],
                     "contract_management/responsibilities": %i[index],
                     "contract_management/bank_orders": %i[index],
                     "contract_management/budget_commitments": %i[index]
                   },
                   permissible_on: :project

        permission :manage_contracts,
                   {
                     "contract_management/contracts": %i[new create edit update destroy],
                     "contract_management/adjustment_indices": %i[new create edit update destroy],
                     "contract_management/adjustment_index_types": %i[new create edit update destroy synchronize],
                     "contract_management/measurements": %i[new create edit update destroy],
                     "contract_management/invoices": %i[new create edit update destroy extract],
                     "contract_management/amendments": %i[new create edit update destroy],
                     "contract_management/responsibilities": %i[new create edit update destroy],
                     "contract_management/bank_orders": %i[new create edit update destroy],
                     "contract_management/budget_commitments": %i[new create edit update destroy],
                     "contract_management/commitment_conversions": %i[new create],
                     "contract_management/settings": %i[edit update]
                   },
                   permissible_on: :project,
                   require: :loggedin,
                   dependencies: %i[view_contracts]
      end

      menu :project_menu,
           :contract_management,
           { controller: "/contract_management/contracts", action: :index },
           caption: :"contract_management.label_plural",
           after: :budgets,
           icon: "law"

      show_portfolio = ->(*) {
        User.current.logged? && Project.allowed_to(User.current, :view_contracts).exists?
      }

      menu :top_menu,
           :contract_portfolio,
           { controller: "/contract_management/portfolio", action: :index },
           context: :modules,
           caption: :"contract_management.portfolio.menu",
           icon: "law",
           after: :projects,
           if: show_portfolio

      menu :global_menu,
           :contract_portfolio,
           { controller: "/contract_management/portfolio", action: :index },
           caption: :"contract_management.portfolio.menu",
           icon: "law",
           after: :projects,
           if: show_portfolio
    end

    initializer "contract_management.good_job_cron" do |app|
      app.config.good_job.cron ||= {}
      app.config.good_job.cron["ContractManagement::DeadlineNotificationJob"] = {
        cron: "30 7 * * *",
        class: "ContractManagement::DeadlineNotificationJob"
      }
      app.config.good_job.cron["ContractManagement::SyncAdjustmentIndicesJob"] = {
        cron: "15 6 * * 1",
        class: "ContractManagement::SyncAdjustmentIndicesJob"
      }
    end

    config.after_initialize do
      require "open_project/hook"
      require "open_project/contract_management/hooks"
    end
  end
end
