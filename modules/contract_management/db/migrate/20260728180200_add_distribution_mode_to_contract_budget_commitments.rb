# frozen_string_literal: true

class AddDistributionModeToContractBudgetCommitments < ActiveRecord::Migration[8.0]
  def change
    add_column :contract_budget_commitments,
               :distribution_mode,
               :string,
               null: false,
               default: "manual"
  end
end
