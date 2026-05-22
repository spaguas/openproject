# frozen_string_literal: true

module ::Okr
  class ObjectivesController < BaseController
    before_action :find_objective, only: %i[show edit update destroy]

    def index
      @objectives = OkrObjective
        .visible(current_user)
        .where(project: @project)
        .includes(:kpis)
        .order(target_date: :asc, title: :asc)
    end

    def show
      @kpis = @objective.kpis.includes(:progress_entries).order(:name)
    end

    def new
      @objective = OkrObjective.new(project: @project)
    end

    def edit; end

    def create
      call = OkrObjectives::CreateService
        .new(user: current_user)
        .call(objective_params.merge(project: @project))

      @objective = call.result

      if call.success?
        flash[:notice] = I18n.t(:notice_successful_create)
        redirect_to project_okr_objective_path(@project, @objective)
      else
        render action: :new, status: :unprocessable_entity
      end
    end

    def update
      call = OkrObjectives::UpdateService
        .new(user: current_user, model: @objective)
        .call(objective_params)

      if call.success?
        flash[:notice] = I18n.t(:notice_successful_update)
        redirect_to project_okr_objective_path(@project, @objective)
      else
        @objective = call.result
        render action: :edit, status: :unprocessable_entity
      end
    end

    def destroy
      call = OkrObjectives::DeleteService.new(user: current_user, model: @objective).call
      flash[call.success? ? :notice : :error] = call.success? ? I18n.t(:notice_successful_delete) : call.message

      redirect_to project_okr_objectives_path(@project), status: :see_other
    end

    private

    def find_objective
      @objective = OkrObjective.visible(current_user).where(project: @project).find(params.expect(:id))
    end

    def objective_params
      params.expect(okr_objective: %i[title description start_date target_date])
    end
  end
end
