# frozen_string_literal: true

class AddDistributionPeriodToContractBudgetCommitments < ActiveRecord::Migration[8.0]
  def change
    add_column :contract_budget_commitments, :distribution_start_month, :integer
    add_column :contract_budget_commitments, :distribution_end_month, :integer
  end
end
