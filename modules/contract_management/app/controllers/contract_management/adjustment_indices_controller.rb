# frozen_string_literal: true

module ContractManagement
  class AdjustmentIndicesController < BaseController
    skip_before_action :authorize
    authorize_with_permission :view_contracts, only: %i[index]
    authorize_with_permission :manage_contracts, except: %i[index]

    before_action :find_adjustment_index, only: %i[edit update destroy]

    def index
      @adjustment_indices = adjustment_indices.order(year: :desc, month: :desc, name: :asc)
    end

    def new
      @adjustment_index = adjustment_indices.new(
        year: Date.current.year,
        month: Date.current.month,
        periodicity: "monthly"
      )
    end

    def edit; end

    def create
      @adjustment_index = adjustment_indices.new(adjustment_index_params)
      persist(:new, :notice_successful_create)
    end

    def update
      @adjustment_index.assign_attributes(adjustment_index_params)
      persist(:edit, :notice_successful_update)
    end

    def destroy
      if @adjustment_index.destroy
        flash[:notice] = I18n.t(:notice_successful_delete)
      else
        flash[:error] = @adjustment_index.errors.full_messages.to_sentence
      end

      redirect_to project_contract_management_adjustment_indices_path(@project), status: :see_other
    end

    private

    def adjustment_indices
      ContractAdjustmentIndex.where(project: @project)
    end

    def find_adjustment_index
      @adjustment_index = adjustment_indices.find(params.expect(:id))
    end

    def adjustment_index_params
      params.expect(contract_adjustment_index: %i[name year month percentage periodicity external_series_code])
    end

    def persist(action, notice)
      if @adjustment_index.save
        flash[:notice] = I18n.t(notice)
        redirect_to project_contract_management_adjustment_indices_path(@project)
      else
        render action:, status: :unprocessable_entity
      end
    end
  end
end
