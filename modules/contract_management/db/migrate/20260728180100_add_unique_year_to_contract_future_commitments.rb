# frozen_string_literal: true

class AddUniqueYearToContractFutureCommitments < ActiveRecord::Migration[8.0]
  def change
    add_index :contract_budget_commitments,
              %i[public_contract_id kind fiscal_year],
              unique: true,
              where: "kind = 'future'",
              name: "index_contract_future_commitments_year_unique"
  end
end
