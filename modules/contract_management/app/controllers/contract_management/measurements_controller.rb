# frozen_string_literal: true

module ContractManagement
  class MeasurementsController < NestedResourcesController
    self.resource_class = ContractMeasurement
    self.association_name = :measurements
    self.permitted_attributes = %i[number measured_on amount status approved_on description invoice_id]

    private

    def prepare_form
      @invoices = @contract.invoices.order(:number)
    end
  end
end
