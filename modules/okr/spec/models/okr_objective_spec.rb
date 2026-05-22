# frozen_string_literal: true

require "spec_helper"

RSpec.describe OkrObjective do
  shared_let(:project) { create(:project, enabled_module_names: %w[okr]) }
  shared_let(:viewer) { create(:user, member_with_permissions: { project => %i[view_okrs] }) }

  describe "date range validation" do
    it "accepts a target date on or after the start date" do
      objective = build(:okr_objective, project:, start_date: Date.new(2026, 1, 1), target_date: Date.new(2026, 1, 1))

      expect(objective).to be_valid
    end

    it "rejects a target date before the start date" do
      objective = build(:okr_objective, project:, start_date: Date.new(2026, 1, 2), target_date: Date.new(2026, 1, 1))

      expect(objective).not_to be_valid
      expect(objective.errors.symbols_for(:target_date)).to include(:greater_than_or_equal_to_start_date)
    end
  end

  describe "#visible?" do
    let(:objective) { create(:okr_objective, project:) }

    it "uses the OKR view permission on the project" do
      expect(objective.visible?(viewer)).to be(true)
      expect(objective.visible?(create(:user))).to be(false)
    end
  end
end
