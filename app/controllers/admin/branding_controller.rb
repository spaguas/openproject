# frozen_string_literal: true

module Admin
  class BrandingController < ApplicationController
    layout "admin"
    menu_item :branding

    UNGUARDED_ACTIONS = %i[light_logo_download dark_logo_download].freeze

    before_action :require_admin, except: UNGUARDED_ACTIONS
    skip_before_action :check_if_login_required, only: UNGUARDED_ACTIONS
    no_authorization_required!(*UNGUARDED_ACTIONS)

    def show
      @branding_setting = BrandingSetting.current_or_initialize
    end

    def update
      @branding_setting = get_or_create_branding_setting

      if @branding_setting.update(branding_setting_params)
        flash[:notice] = I18n.t(:notice_successful_update)
        redirect_to admin_branding_path
      else
        flash[:error] = @branding_setting.errors.full_messages
        render :show, status: :unprocessable_entity
      end
    end

    def light_logo_download
      file_download(:light_logo_path)
    end

    def dark_logo_download
      file_download(:dark_logo_path)
    end

    def light_logo_delete
      file_delete(:remove_light_logo)
    end

    def dark_logo_delete
      file_delete(:remove_dark_logo)
    end

    private

    def branding_setting_params
      params.fetch(:branding_setting, {}).permit(:light_logo, :dark_logo)
    end

    def get_or_create_branding_setting
      BrandingSetting.current || BrandingSetting.create!
    end

    def file_download(path_method)
      branding_setting = BrandingSetting.current
      path = branding_setting&.public_send(path_method)

      if path
        expires_in 1.year, public: true, must_revalidate: false
        send_file(path)
      else
        head :not_found
      end
    end

    def file_delete(remove_method)
      branding_setting = BrandingSetting.current

      return render_404 if branding_setting.nil?

      branding_setting.public_send("#{remove_method}!")
      redirect_to admin_branding_path, status: :see_other
    end
  end
end
