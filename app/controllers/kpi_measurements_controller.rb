# frozen_string_literal: true

class KpiMeasurementsController < ApplicationController
  before_action :find_project
  before_action :find_kpi
  before_action :authorize

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

  private

  def find_project
    @project = Project.find(params.expect(:project_id))
  end

  def find_kpi
    @kpi = Kpi.associated_with_project(@project).find(params.expect(:kpi_id))
  end

  def measurement_params
    params.expect(kpi_measurement: %i[value measured_at note])
  end
end
