# frozen_string_literal: true

module ContractManagement
  class AmendmentsController < NestedResourcesController
    self.resource_class = ContractAmendment
    self.association_name = :amendments
    self.permitted_attributes = %i[number start_date duration_months amount description]
  end
end
