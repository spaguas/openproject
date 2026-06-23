# frozen_string_literal: true

require "rails_helper"

RSpec.describe Overviews::BudgetDashboard do
  let(:project) { create(:project, enabled_module_names: %w[budgets costs]) }
  let(:user) { create(:admin) }

  current_user { user }

  describe "#call" do
    subject(:dashboard) { described_class.new(project:, current_user: user, period:).call }

    let(:period) { 3 }
    let!(:budget) { create(:budget, :with_base_amount, project:, author: user) }

    it "returns project budget totals and the requested period", :aggregate_failures do
      expect(dashboard[:period]).to eq(3)
      expect(dashboard[:summary][:planned]).to eq(250_000)
      expect(dashboard[:summary][:spent]).to eq(0)
      expect(dashboard[:summary][:remaining]).to eq(250_000)
      expect(dashboard[:rows].first[:budget]).to eq(budget)
      expect(dashboard[:insights][:highest_consumption][:budget]).to eq(budget)
      expect(dashboard[:consumption_chart]).to include(
        type: "bar",
        valueType: "percentage",
        labels: [budget.subject]
      )
      expect(dashboard[:trend_chart][:labels]).to have_attributes(size: 3)
    end

    context "with an unsupported period" do
      let(:period) { 9 }

      it "uses the default period" do
        expect(dashboard[:period]).to eq(12)
      end
    end

    context "with a budget near its limit" do
      before do
        allow_any_instance_of(Budget).to receive(:spent).and_return(212_500) # rubocop:disable RSpec/AnyInstance
      end

      it "adds the budget to the attention list" do
        expect(dashboard[:alerts][:near_limit].first[:budget]).to eq(budget)
      end
    end
  end
end
