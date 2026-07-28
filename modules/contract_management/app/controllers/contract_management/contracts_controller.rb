# frozen_string_literal: true

module ContractManagement
  class ContractsController < BaseController
    before_action :find_contract, only: %i[show edit update destroy]

    def index
      @contracts = PublicContract
        .visible(current_user)
        .where(project: @project)
        .includes(:amendments, :measurements, :bank_orders)
        .order(end_date: :asc)
      @expiring_contracts = @contracts.select do |contract|
        contract.effective_end_date.between?(Date.current, 30.days.from_now.to_date)
      end
      @due_invoices = ContractInvoice
        .joins(:public_contract)
        .where(public_contracts: { project_id: @project.id })
        .due_between(Date.current, 30.days.from_now.to_date)
        .includes(:public_contract)
        .order(:due_on)
    end

    def show
      @measurements = @contract.measurements.includes(:invoice).order(measured_on: :desc)
      @invoices = @contract.invoices.includes(:bank_orders, :attachments).order(due_on: :desc)
      @amendments = @contract.amendments.order(start_date: :desc)
      @responsibilities = @contract.responsibilities.includes(:user).order(starts_on: :desc)
      @bank_orders = @contract.bank_orders.includes(:invoices).order(issued_on: :desc)
      @budget_commitments = @contract.budget_commitments
        .includes(:responsible, :bank_orders)
        .order(fiscal_year: :desc, kind: :asc, issued_on: :desc)
      @contract_setting = ContractProjectSetting.for(@project)
    end

    def new
      @contract = PublicContract.new(project: @project, start_date: Date.current, deadline_notification_days: 30)
      prepare_form
    end

    def edit
      prepare_form
    end

    def create
      @contract = PublicContract.new(contract_params.merge(project: @project))
      persist(:new, :notice_successful_create)
    end

    def update
      @contract.assign_attributes(contract_params)
      persist(:edit, :notice_successful_update)
    end

    def destroy
      @contract.destroy!
      flash[:notice] = I18n.t(:notice_successful_delete)
      redirect_to project_contract_management_contracts_path(@project), status: :see_other
    end

    private

    def find_contract
      @contract = PublicContract.visible(current_user).where(project: @project).find(params.expect(:id))
    end

    def contract_params
      params.expect(
        public_contract: %i[
          number sei_process_number payment_sei_process_number start_date end_date
          duration_months description amount adjustment_index contract_adjustment_index_id
          contract_adjustment_index_type_id
          adjustment_start_date deadline_notification_days
        ]
      )
    end

    def persist(action, notice)
      if @contract.save
        flash[:notice] = I18n.t(notice)
        redirect_to project_contract_management_contract_path(@project, @contract)
      else
        prepare_form
        render action:, status: :unprocessable_entity
      end
    end

    def prepare_form
      @adjustment_indices = ContractAdjustmentIndex.where(project: @project).order(year: :desc, name: :asc)
      @adjustment_index_types = ContractAdjustmentIndexType.active.where(project: @project).order(:name)
    end
  end
end
