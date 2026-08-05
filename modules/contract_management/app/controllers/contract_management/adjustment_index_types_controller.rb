# frozen_string_literal: true

module ContractManagement
  class AdjustmentIndexTypesController < BaseController
    skip_before_action :authorize
    authorize_with_permission :view_contracts, only: %i[index]
    authorize_with_permission :manage_contracts, except: %i[index]

    before_action :find_adjustment_index_type, only: %i[edit update destroy]

    def index
      @adjustment_index_types = adjustment_index_types.order(:name)
    end

    def new
      @adjustment_index_type = adjustment_index_types.new(periodicity: "annual", active: true)
    end

    def edit; end

    def create
      @adjustment_index_type = adjustment_index_types.new(adjustment_index_type_params)
      persist(:new, :notice_successful_create)
    end

    def update
      @adjustment_index_type.assign_attributes(adjustment_index_type_params)
      persist(:edit, :notice_successful_update)
    end

    def destroy
      if @adjustment_index_type.destroy
        flash[:notice] = I18n.t(:notice_successful_delete)
      else
        flash[:error] = @adjustment_index_type.errors.full_messages.to_sentence
      end

      redirect_to project_contract_management_adjustment_index_types_path(@project), status: :see_other
    end

    def synchronize
      ContractManagement::SyncAdjustmentIndicesJob.perform_later(@project.id)
      flash[:notice] = I18n.t("contract_management.adjustment_index_types.sync_scheduled")
      redirect_to project_contract_management_adjustment_index_types_path(@project), status: :see_other
    end

    private

    def adjustment_index_types
      ContractAdjustmentIndexType.where(project: @project)
    end

    def find_adjustment_index_type
      @adjustment_index_type = adjustment_index_types.find(params.expect(:id))
    end

    def adjustment_index_type_params
      params.expect(contract_adjustment_index_type: %i[name external_series_code periodicity active])
    end

    def persist(action, notice)
      if @adjustment_index_type.save
        flash[:notice] = I18n.t(notice)
        redirect_to project_contract_management_adjustment_index_types_path(@project)
      else
        render action:, status: :unprocessable_entity
      end
    end
  end
end
