# frozen_string_literal: true

module ::Okr
  class ProgressEntriesController < BaseController
    before_action :find_objective
    before_action :find_kpi

    def create
      call = OkrProgressEntries::CreateService
        .new(user: current_user)
        .call(progress_entry_params.merge(kpi: @kpi))

      if call.success?
        flash[:notice] = I18n.t(:notice_successful_create)
        redirect_to project_okr_objective_kpi_path(@project, @objective, @kpi)
      else
        @progress_entry = call.result
        @progress_entries = @kpi.progress_entries.includes(:author).order(recorded_on: :desc, created_at: :desc)
        render "okr/kpis/show", status: :unprocessable_entity
      end
    end

    private

    def find_objective
      @objective = OkrObjective.visible(current_user).where(project: @project).find(params.expect(:okr_objective_id))
    end

    def find_kpi
      @kpi = @objective.kpis.find(params.expect(:kpi_id))
    end

    def progress_entry_params
      params.expect(okr_progress_entry: %i[value recorded_on note])
    end
  end
end
