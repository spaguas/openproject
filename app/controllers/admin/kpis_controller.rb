# frozen_string_literal: true

module Admin
  class KpisController < ::Admin::SettingsController
    menu_item :admin_kpis

    def show
      @categories = KpiCategory.ordered
    end

    private

    def success_callback(_call)
      flash[:notice] = t(:notice_successful_update)
      redirect_to admin_kpis_path
    end

    def failure_callback(call)
      flash[:error] = call.message || I18n.t(:notice_internal_server_error)
      redirect_to admin_kpis_path
    end
  end
end
