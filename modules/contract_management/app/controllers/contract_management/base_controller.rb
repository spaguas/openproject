# frozen_string_literal: true

module ContractManagement
  class BaseController < ::ApplicationController
    menu_item :contract_management

    before_action :find_project_by_project_id
    before_action :authorize
  end
end
