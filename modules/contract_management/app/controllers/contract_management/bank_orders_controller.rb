# frozen_string_literal: true

module ContractManagement
  class BankOrdersController < NestedResourcesController
    self.resource_class = ContractBankOrder
    self.association_name = :bank_orders
    self.permitted_attributes = [:number, :issued_on, :amount, :budget_commitment_id, :description, { invoice_ids: [] }]

    private

    def prepare_form
      @invoices = @contract.invoices.order(:number)
      @budget_commitments = @contract.budget_commitments.appropriations.active.order(fiscal_year: :desc, number: :asc)
    end
  end
end
