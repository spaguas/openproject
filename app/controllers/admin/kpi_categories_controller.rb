# frozen_string_literal: true

module Admin
  class KpiCategoriesController < ApplicationController
    before_action :require_admin
    before_action :find_category, only: %i[edit update destroy]

    authorization_checked! :index, :new, :edit, :create, :update, :destroy

    layout "admin"
    menu_item :admin_kpis

    def index
      redirect_to admin_kpis_path
    end

    def new
      @category = KpiCategory.new(active: true, position: next_position)
    end

    def edit; end

    def create
      @category = KpiCategory.new(category_params)

      if @category.save
        flash[:notice] = I18n.t(:notice_successful_create)
        redirect_to admin_kpis_path
      else
        render :new, status: :unprocessable_entity
      end
    end

    def update
      if @category.update(category_params)
        flash[:notice] = I18n.t(:notice_successful_update)
        redirect_to admin_kpis_path
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @category.destroy

      flash[:notice] = I18n.t(:notice_successful_delete)
      redirect_to admin_kpis_path, status: :see_other
    end

    private

    def find_category
      @category = KpiCategory.find(params[:id])
    end

    def category_params
      params.require(:kpi_category).permit(:name, :description, :active, :position)
    end

    def next_position
      KpiCategory.maximum(:position).to_i + 1
    end
  end
end
