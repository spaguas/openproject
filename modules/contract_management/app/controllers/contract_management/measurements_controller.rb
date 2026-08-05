# frozen_string_literal: true

module ContractManagement
  class MeasurementsController < NestedResourcesController
    self.resource_class = ContractMeasurement
    self.association_name = :measurements
    self.permitted_attributes = %i[number measured_on amount status approved_on description]

    def create
      self.resource = resource_class.new(resource_params.merge(public_contract: @contract))
      prepare_approval
      return render_forbidden_approval if approving_without_responsibility?

      if resource.save
        ContractManagement::NotificationService.new(subject: resource, kind: "measurement_created").call
        flash[:notice] = I18n.t(:notice_successful_create)
        redirect_to contract_path(anchor: association_name)
      else
        prepare_form
        render :new, status: :unprocessable_entity
      end
    end

    def update
      requested_status = resource_params[:status]
      approving = requested_status == "approved" && resource.status != "approved"
      return render_forbidden_approval if approving && !authorized_attester?

      resource.assign_attributes(resource_params)
      prepare_approval if approving || resource.status != "approved"
      super
    end

    private

    def prepare_form
      @measurement_statuses = ContractMeasurement::STATUSES.reject do |status|
        status == "approved" && !authorized_attester? && resource.status != "approved"
      end
    end

    def prepare_approval
      if resource.status == "approved"
        resource.approved_by = current_user
        resource.approved_on ||= Date.current
      else
        resource.approved_by = nil
        resource.approved_on = nil
      end
    end

    def approving_without_responsibility?
      resource.status == "approved" && !authorized_attester?
    end

    def authorized_attester?
      @contract.manager_or_inspector?(current_user)
    end

    def render_forbidden_approval
      render plain: I18n.t("contract_management.measurements.approval_forbidden"), status: :forbidden
    end
  end
end
