# frozen_string_literal: true

module ContractManagement
  class NestedResourcesController < BaseController
    class_attribute :resource_class, :association_name, :permitted_attributes

    before_action :find_contract
    before_action :find_resource, only: %i[edit update destroy]

    def index
      redirect_to contract_path(anchor: association_name)
    end

    def new
      self.resource = resource_class.new(public_contract: @contract)
      prepare_form
    end

    def edit
      prepare_form
    end

    def create
      self.resource = resource_class.new(resource_params.merge(public_contract: @contract))
      persist(:new, :notice_successful_create)
    end

    def update
      resource.assign_attributes(resource_params)
      persist(:edit, :notice_successful_update)
    end

    def destroy
      resource.destroy!
      flash[:notice] = I18n.t(:notice_successful_delete)
      redirect_to contract_path(anchor: association_name), status: :see_other
    end

    private

    def find_contract
      @contract = PublicContract.visible(current_user).where(project: @project).find(params.expect(:contract_id))
    end

    def find_resource
      self.resource = @contract.public_send(association_name).find(params.expect(:id))
    end

    def resource
      instance_variable_get(:"@#{association_name.to_s.singularize}")
    end

    def resource=(value)
      instance_variable_set(:"@#{association_name.to_s.singularize}", value)
    end

    def resource_params
      params.expect(resource_class.model_name.param_key => permitted_attributes)
    end

    def persist(action, notice)
      if resource.save
        flash[:notice] = I18n.t(notice)
        redirect_to contract_path(anchor: association_name)
      else
        prepare_form
        render action:, status: :unprocessable_entity
      end
    end

    def contract_path(anchor: nil)
      project_contract_management_contract_path(@project, @contract, anchor:)
    end

    def prepare_form; end
  end
end
