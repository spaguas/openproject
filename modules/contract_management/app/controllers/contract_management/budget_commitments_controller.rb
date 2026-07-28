# frozen_string_literal: true

module ContractManagement
  class BudgetCommitmentsController < NestedResourcesController
    self.resource_class = ContractBudgetCommitment
    self.association_name = :budget_commitments
    self.permitted_attributes = [
      :kind, :number, :issued_on, :fiscal_year, :total_amount, :distribution_mode,
      :distribution_start_month, :distribution_end_month, :status, :responsible_id,
      { monthly_distribution: {} }
    ]

    def new
      super
      @budget_commitment.kind = params.fetch(:kind, nil).presence_in(ContractBudgetCommitment::KINDS) || "appropriation"
      @budget_commitment.responsible = current_user
      @budget_commitment.issued_on = Date.current
      @budget_commitment.fiscal_year = Date.current.year
      set_default_distribution_period
    end

    def create
      super
      return unless performed? && resource.persisted? && resource.appropriation?

      ContractManagement::FutureCommitmentGenerator.new(resource).call
    end

    private

    def set_default_distribution_period
      @budget_commitment.distribution_start_month =
        @contract.start_date.year == Date.current.year ? @contract.start_date.month : 1
      @budget_commitment.distribution_end_month =
        @contract.effective_end_date.year == Date.current.year ? @contract.effective_end_date.month : 12
    end

    def prepare_form
      @users = User.active.order(:lastname, :firstname, :login).distinct
    end
  end
end
