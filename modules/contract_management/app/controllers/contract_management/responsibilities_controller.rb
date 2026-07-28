# frozen_string_literal: true

module ContractManagement
  class ResponsibilitiesController < NestedResourcesController
    self.resource_class = ContractResponsibility
    self.association_name = :responsibilities
    self.permitted_attributes = %i[user_id role starts_on ends_on notify]

    private

    def prepare_form
      @users = @project.users.active.distinct.order(:lastname, :firstname)
    end
  end
end
