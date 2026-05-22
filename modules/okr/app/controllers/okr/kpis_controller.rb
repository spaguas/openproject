# frozen_string_literal: true

module ::Okr
  class KpisController < BaseController
    before_action :find_objective
    before_action :find_kpi, only: %i[show edit update destroy]

    def show
      @progress_entries = @kpi.progress_entries.includes(:author).order(recorded_on: :desc, created_at: :desc)
      @progress_entry = OkrProgressEntry.new(kpi: @kpi)
    end

    def new
      @kpi = @objective.kpis.build
    end

    def edit; end

    def create
      call = OkrKpis::CreateService
        .new(user: current_user)
        .call(kpi_params.merge(objective: @objective))

      @kpi = call.result

      if call.success?
        flash[:notice] = I18n.t(:notice_successful_create)
        redirect_to project_okr_objective_kpi_path(@project, @objective, @kpi)
      else
        render action: :new, status: :unprocessable_entity
      end
    end

    def update
      call = OkrKpis::UpdateService
        .new(user: current_user, model: @kpi)
        .call(kpi_params)

      if call.success?
        flash[:notice] = I18n.t(:notice_successful_update)
        redirect_to project_okr_objective_kpi_path(@project, @objective, @kpi)
      else
        @kpi = call.result
        render action: :edit, status: :unprocessable_entity
      end
    end

    def destroy
      call = OkrKpis::DeleteService.new(user: current_user, model: @kpi).call
      flash[call.success? ? :notice : :error] = call.success? ? I18n.t(:notice_successful_delete) : call.message

      redirect_to project_okr_objective_path(@project, @objective), status: :see_other
    end

    private

    def find_objective
      @objective = OkrObjective.visible(current_user).where(project: @project).find(params.expect(:okr_objective_id))
    end

    def find_kpi
      @kpi = @objective.kpis.find(params.expect(:id))
    end

    def kpi_params
      params.expect(
        okr_kpi: %i[
          name description update_frequency unit baseline_value current_value target_value target_direction
        ]
      )
    end
  end
end
