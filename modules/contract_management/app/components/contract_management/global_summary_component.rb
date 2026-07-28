# frozen_string_literal: true

module ContractManagement
  class GlobalSummaryComponent < ApplicationComponent
    def initialize(user:)
      super()
      @portfolio = ContractManagement::ContractPortfolioQuery.new(user:)
    end

    def render?
      @portfolio.total_contracts.positive?
    end
  end
end
