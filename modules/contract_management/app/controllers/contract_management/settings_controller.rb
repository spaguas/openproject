# frozen_string_literal: true

module ContractManagement
  class SettingsController < BaseController
    authorize_with_permission :manage_contracts

    def edit
      @contract_setting = ContractProjectSetting.for(@project)
    end

    def update
      @contract_setting = ContractProjectSetting.for(@project)
      if @contract_setting.update(setting_params)
        redirect_to edit_project_contract_management_settings_path(@project), notice: I18n.t(:notice_successful_update)
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def setting_params
      params.expect(contract_project_setting: [:commitment_consumption_alert_percentage])
    end
  end
end
