# frozen_string_literal: true

class KpisController < ApplicationController
  include PaginationHelper

  menu_item :kpis

  before_action :find_project
  before_action :find_kpi, only: %i[show edit update destroy]
  before_action :authorize
  before_action :authorize_project_management, only: %i[new create edit update destroy]
  before_action :set_form_options, only: %i[new edit create update]

  def index
    @kpis = Kpi
      .associated_with_project(@project)
      .includes(:owner, :project, :projects, :groups, :kpi_category)
      .ordered
      .page(page_param)
      .per_page(per_page_param)

    @summary = build_summary(Kpi.associated_with_project(@project))
  end

  def show
    set_measurements
  end

  def new
    @kpi = @project.kpis.build(
      status: Setting.kpis_default_status,
      direction: Setting.kpis_default_direction
    )
  end

  def edit; end

  def create
    @kpi = @project.kpis.build(kpi_params)

    if save_kpi_with_initial_measurement
      flash[:notice] = I18n.t(:notice_successful_create)
      redirect_to project_kpi_path(@project, @kpi)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @kpi.update(kpi_params)
      flash[:notice] = I18n.t(:notice_successful_update)
      redirect_to project_kpi_path(@project, @kpi)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @kpi.destroy

    flash[:notice] = I18n.t(:notice_successful_delete)
    redirect_to project_kpis_path(@project), status: :see_other
  end

  private

  def find_project
    @project = Project.find(params[:project_id])
  end

  def find_kpi
    @kpi = Kpi.associated_with_project(@project).find(params[:id])
  end

  def set_form_options
    project_user_ids = @project.users.active.select(:id)
    @owner_options = User
      .where(id: project_user_ids)
      .or(User.where(id: @kpi&.owner_id))
      .order(:lastname, :firstname, :login)
    @project_options = Project
      .allowed_to(User.current, :manage_kpis)
      .active
      .order(:name)
    @group_options = Group
      .not_builtin
      .order(:lastname)
    @kpi_category_options = available_kpi_categories
  end

  def kpi_params
    permitted = params
      .require(:kpi)
      .permit(
        :name,
        :description,
        :category,
        :kpi_category_id,
        :unit,
        :current_value,
        :target_value,
        :direction,
        :measurement_frequency,
        :status,
        :start_date,
        :due_date,
        :owner_id,
        project_ids: [],
        group_ids: []
      )

    permitted.delete(:current_value) if @kpi&.persisted?
    permitted[:project_ids] = (Array(permitted[:project_ids]).compact_blank.map(&:to_i) | [@project.id])
    permitted
  end

  def save_kpi_with_initial_measurement
    saved = false

    Kpi.transaction do
      unless @kpi.save
        raise ActiveRecord::Rollback
      end

      measurement = @kpi.measurements.build(
        value: @kpi.current_value,
        measured_at: Time.current,
        author: current_user
      )

      unless measurement.save
        measurement.errors.full_messages.each { |message| @kpi.errors.add(:base, message) }
        raise ActiveRecord::Rollback
      end

      saved = true
    end

    saved
  end

  def set_measurements
    @measurements = @kpi.measurements.includes(:author)
    @measurement = @kpi.measurements.build(measured_at: Time.current)
  end

  def available_kpi_categories
    scope = KpiCategory.active
    current_category_id = @kpi&.kpi_category_id

    if current_category_id
      scope = scope.or(KpiCategory.where(id: current_category_id))
    end

    scope.ordered
  end

  def authorize_project_management
    deny_access unless User.current.allowed_in_project?(:manage_kpis, @project) &&
                       User.current.allowed_in_project?(:edit_project, @project)
  end

  def build_summary(scope)
    total = scope.count
    achieved = scope.where(status: "achieved").count
    overdue = scope.where.not(status: "achieved").where("due_date < ?", Date.current).count
    average_progress = total.zero? ? 0 : scope.to_a.sum(&:progress_percentage) / total

    {
      total:,
      achieved:,
      overdue:,
      average_progress:
    }
  end
end
