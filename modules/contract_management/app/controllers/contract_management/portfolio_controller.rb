# frozen_string_literal: true

module ContractManagement
  class PortfolioController < ::ApplicationController
    layout "global"

    no_authorization_required! :index, :new
    before_action :require_login

    menu_item :contract_portfolio

    def index
      @portfolio = ContractManagement::ContractPortfolioQuery.new(
        user: current_user,
        filters: params.permit(:status, :project_id, :query, :ending_from, :ending_to)
      )
    end

    def new
      @projects = Project
        .allowed_to(current_user, :manage_contracts)
        .active
        .order(:name)

      return if params[:project_id].blank?

      project = @projects.find(params.expect(:project_id))
      redirect_to new_project_contract_management_contract_path(project)
    end
  end
end
