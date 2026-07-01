# frozen_string_literal: true

class ProjectInitiationRequestsController < ApplicationController
  before_action :authorize_global
  before_action :find_request, only: %i[show edit update submit review request_info reject approve]
  before_action :ensure_editable, only: %i[edit update]

  menu_item :project_initiation_requests

  def index
    @project_initiation_requests = ProjectInitiationRequest
      .visible_to(current_user)
      .includes(:author, :template_project, :created_project)
      .order(created_at: :desc)
  end

  def show; end

  def new
    @project_initiation_request = ProjectInitiationRequest.new(author: current_user, status: "draft")
    prepare_template_projects
  end

  def edit
    prepare_template_projects
  end

  def create
    @project_initiation_request = ProjectInitiationRequest.new(request_params.merge(author: current_user, status: "draft"))
    @project_initiation_request.identifier = next_request_identifier(@project_initiation_request.title)

    if save_request
      flash[:notice] = I18n.t(:notice_successful_create)
      redirect_to project_initiation_request_path(@project_initiation_request)
    else
      prepare_template_projects
      render action: :new, status: :unprocessable_entity
    end
  end

  def update
    @project_initiation_request.assign_attributes(request_params)
    if @project_initiation_request.title_changed?
      @project_initiation_request.identifier = next_request_identifier(@project_initiation_request.title)
    end

    if save_request
      flash[:notice] = I18n.t(:notice_successful_update)
      redirect_to project_initiation_request_path(@project_initiation_request)
    else
      prepare_template_projects
      render action: :edit, status: :unprocessable_entity
    end
  end

  def submit
    update_status("submitted")
  end

  def review
    update_status("under_review")
  end

  def request_info
    update_status("needs_info", rejection_reason: status_reason)
  end

  def reject
    update_status("rejected", rejection_reason: status_reason)
  end

  def approve
    update_status("approved")
  end

  private

  def find_request
    @project_initiation_request = ProjectInitiationRequest.visible_to(current_user).find(params.expect(:id))
  end

  def ensure_editable
    return if @project_initiation_request.author == current_user &&
              ProjectInitiationRequest::EDITABLE_STATUSES.include?(@project_initiation_request.status)

    render_403
  end

  def request_params
    params.expect(
      project_initiation_request: %i[
        title
        description
        business_case
        estimated_budget
        target_start_date
        target_end_date
        template_project_id
      ]
    )
  end

  def save_request
    contract = OpenProject::ProjectInitiationRequest::Contract.new(@project_initiation_request, current_user)

    contract.valid? && @project_initiation_request.save
  end

  def update_status(to_status, rejection_reason: nil)
    call = ProjectInitiationRequests::UpdateStatusService
      .new(user: current_user, request: @project_initiation_request)
      .call(to_status: to_status, rejection_reason: rejection_reason)

    if call.success?
      flash[:notice] = I18n.t("project_initiation_requests.status_updated")
      redirect_to project_initiation_request_path(@project_initiation_request)
    else
      flash.now[:error] = call.errors.full_messages.to_sentence
      render action: :show, status: :unprocessable_entity
    end
  end

  def status_reason
    params.dig(:project_initiation_request, :rejection_reason)
  end

  def next_request_identifier(title)
    relation =
      if @project_initiation_request&.persisted?
        ProjectInitiationRequest.where.not(id: @project_initiation_request.id)
      else
        ProjectInitiationRequest.all
      end

    ProjectInitiationRequests::IdentifierService.call(title, relation: relation)
  end

  def prepare_template_projects
    @template_projects = Project.visible(current_user).active.templated.order(:name)
  end
end
