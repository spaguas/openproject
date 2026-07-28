# frozen_string_literal: true

module ContractManagement
  class InvoicesController < NestedResourcesController
    skip_before_action :authorize
    authorize_with_permission :view_contracts, only: %i[index]
    authorize_with_permission :manage_contracts, except: %i[index]

    self.resource_class = ContractInvoice
    self.association_name = :invoices
    self.permitted_attributes = %i[number gross_amount issued_on due_on tax_percentage net_amount status]

    def new
      return render_upload if params[:extraction_id].blank?

      prepare_invoice_from_extraction
    end

    def extract
      uploaded_file = params[:invoice_file]
      return redirect_to_upload(I18n.t("contract_management.invoice_extraction.errors.file_required")) if uploaded_file.blank?

      extraction = create_extraction(uploaded_file)
      return if performed?

      result = InvoiceExtraction::ExtractService.new(extraction:).call
      return redirect_to_upload(result.message) unless result.success?

      redirect_to_review(extraction)
    end

    def create
      self.resource = resource_class.new(resource_params.merge(public_contract: @contract))
      return render_invalid_invoice unless resource.save

      claim_extraction_attachment
      flash[:notice] = I18n.t(:notice_successful_create)
      redirect_to contract_path(anchor: association_name)
    end

    private

    def render_upload
      self.resource = resource_class.new(public_contract: @contract)
      render :upload
    end

    def prepare_invoice_from_extraction
      @invoice_extraction = find_extraction(params[:extraction_id])
      return redirect_to_upload(@invoice_extraction.error_message) unless @invoice_extraction.status == "completed"

      self.resource = resource_class.new(invoice_attributes_from_extraction)
      resource.recalculate_net_amount
    end

    def invoice_attributes_from_extraction
      {
        public_contract: @contract,
        status: "pending",
        tax_percentage: 0,
        **@invoice_extraction.extracted_data.symbolize_keys.compact
      }
    end

    def create_extraction(uploaded_file)
      extraction = ContractInvoiceExtraction.create!(
        public_contract: @contract,
        user: current_user,
        status: "pending"
      )
      attachment = extraction.attachments.create(author: current_user, file: uploaded_file)
      return extraction if attachment.persisted?

      redirect_to_upload(attachment.errors.full_messages.to_sentence)
      extraction.destroy!
      nil
    end

    def redirect_to_review(extraction)
      redirect_to new_project_contract_management_contract_invoice_path(
        @project,
        @contract,
        extraction_id: extraction.id
      )
    end

    def render_invalid_invoice
      @invoice_extraction = find_extraction(params[:extraction_id]) if params[:extraction_id].present?
      render :new, status: :unprocessable_entity
    end

    def find_extraction(id)
      ContractInvoiceExtraction.where(public_contract: @contract, user: current_user).find(id)
    end

    def claim_extraction_attachment
      return if params[:extraction_id].blank?

      extraction = find_extraction(params[:extraction_id])
      extraction.attachments.each { |attachment| attachment.update!(container: resource) }
      extraction.destroy!
    end

    def redirect_to_upload(message)
      flash[:error] = message
      redirect_to new_project_contract_management_contract_invoice_path(@project, @contract)
    end
  end
end
