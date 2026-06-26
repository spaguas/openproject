# frozen_string_literal: true

class KpiMeasurementsController < ApplicationController
  authorization_checked! :edit, :create, :update, :destroy

  before_action :find_project
  before_action :find_kpi
  before_action :find_measurement, only: %i[edit update destroy]
  before_action :authorize_project_management

  def edit; end

  def create
    @measurement = @kpi.measurements.build(measurement_params.merge(author: current_user))

    if @measurement.save
      flash[:notice] = I18n.t(:notice_successful_create)
      redirect_to project_kpi_path(@project, @kpi)
    else
      @measurements = @kpi.measurements.includes(:author)
      render "kpis/show", status: :unprocessable_entity
    end
  end

  def update
    if @measurement.update(measurement_params)
      flash[:notice] = I18n.t(:notice_successful_update)
      redirect_to project_kpi_path(@project, @kpi)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @measurement.destroy

    flash[:notice] = I18n.t(:notice_successful_delete)
    redirect_to project_kpi_path(@project, @kpi), status: :see_other
  end

  private

  def find_project
    @project = Project.find(params.expect(:project_id))
  end

  def find_kpi
    @kpi = Kpi.associated_with_project(@project).find(params.expect(:kpi_id))
  end

  def find_measurement
    @measurement = @kpi.measurements.find(params.expect(:id))
  end

  def measurement_params
    params.expect(kpi_measurement: %i[value measured_at note])
  end

  def authorize_project_management
    deny_access unless User.current.allowed_in_project?(:manage_kpis, @project) &&
                       User.current.allowed_in_project?(:edit_project, @project)
  end
end
