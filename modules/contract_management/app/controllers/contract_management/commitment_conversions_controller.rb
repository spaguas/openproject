# frozen_string_literal: true

module ContractManagement
  class CommitmentConversionsController < BaseController
    before_action :find_contract
    before_action :find_future_commitment

    def new
      @conversion = ContractBudgetCommitment.new(
        public_contract: @contract,
        source_commitment: @future_commitment,
        kind: "appropriation",
        issued_on: Date.current,
        fiscal_year: Date.current.year,
        total_amount: @future_commitment.remaining_amount,
        distribution_mode: "manual",
        responsible: current_user,
        monthly_distribution: @future_commitment.monthly_distribution
      )
      @users = User.active.order(:lastname, :firstname, :login).distinct
    end

    def create
      @conversion = ContractBudgetCommitment.new(conversion_params.merge(
                                                   public_contract: @contract,
                                                   source_commitment: @future_commitment,
                                                   kind: "appropriation"
                                                 ))
      ContractBudgetCommitment.transaction do
        @conversion.save!
        converted = @future_commitment.remaining_amount <= @conversion.total_amount
        @future_commitment.update!(status: converted ? "converted" : "active")
      end
      redirect_to project_contract_management_contract_path(@project, @contract, anchor: "budget_commitments"),
                  notice: I18n.t("contract_management.commitments.converted")
    rescue ActiveRecord::RecordInvalid
      @users = User.active.order(:lastname, :firstname, :login).distinct
      render :new, status: :unprocessable_entity
    end

    private

    def find_contract
      @contract = PublicContract.visible(current_user).where(project: @project).find(params.expect(:contract_id))
    end

    def find_future_commitment
      @future_commitment = @contract.budget_commitments.future_commitments.find(params.expect(:budget_commitment_id))
    end

    def conversion_params
      params.expect(contract_budget_commitment: [
                      :number, :issued_on, :fiscal_year, :total_amount, :distribution_mode,
                      :distribution_start_month, :distribution_end_month, :responsible_id,
                      { monthly_distribution: {} }
                    ])
    end
  end
end
