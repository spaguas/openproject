# frozen_string_literal: true

require "rails_helper"

RSpec.describe Overviews::TeamAllocationDashboard do
  let(:project) { create(:project, enabled_module_names: %w[resource_management]) }
  let(:viewer) { create(:admin) }
  let(:period_start) { Time.zone.today.beginning_of_month }
  let(:period_end) { period_start + 3.months - 1.day }
  let(:period_days) { (period_end - period_start).to_i + 1 }
  let(:first_user) do
    create(
      :user,
      password: "ValidPassword1!",
      member_with_permissions: { project => %i[view_project view_resource_planners] }
    )
  end
  let(:second_user) do
    create(
      :user,
      password: "ValidPassword1!",
      member_with_permissions: { project => %i[view_project view_resource_planners] }
    )
  end
  let!(:first_hours) do
    create(
      :user_working_hours,
      user: first_user,
      valid_from: period_start,
      monday: 60,
      tuesday: 60,
      wednesday: 60,
      thursday: 60,
      friday: 60,
      saturday: 60,
      sunday: 60
    )
  end
  let!(:second_hours) do
    create(
      :user_working_hours,
      user: second_user,
      valid_from: period_start,
      monday: 60,
      tuesday: 60,
      wednesday: 60,
      thursday: 60,
      friday: 60,
      saturday: 60,
      sunday: 60
    )
  end
  let(:planner) { create(:resource_planner, project:, principal: viewer) }

  subject(:dashboard) do
    described_class.new(project:, current_user: viewer, period: 3).call
  end

  before do
    create(
      :resource_allocation,
      :allocated,
      entity: planner,
      principal: first_user,
      start_date: period_start,
      end_date: period_end,
      allocated_time: (period_days * 0.5 * 60).to_i
    )
    create(
      :resource_allocation,
      :allocated,
      entity: planner,
      principal: second_user,
      start_date: period_start,
      end_date: period_end,
      allocated_time: (period_days * 1.2 * 60).to_i
    )
  end

  it "calculates capacity, allocation and participation by member", :aggregate_failures do
    expect(dashboard[:summary]).to include(
      allocation: 85.0,
      active_members: 2,
      total_members: 2
    )
    expect(dashboard[:rows].first).to include(
      user: second_user,
      allocation: 120.0
    )
    expect(dashboard[:rows].last).to include(
      user: first_user,
      allocation: 50.0
    )
    expect(dashboard[:rows].sum { |row| row[:participation] }).to be_within(0.1).of(100)
  end

  it "identifies overload and available capacity", :aggregate_failures do
    expect(dashboard[:insights][:overloaded].pluck(:user)).to contain_exactly(second_user)
    expect(dashboard[:insights][:available]).to be_empty
  end

  context "with a pending allocation" do
    before do
      create(
        :resource_allocation,
        :requested,
        entity: planner,
        principal: first_user,
        start_date: period_start,
        end_date: period_end,
        allocated_time: period_days * 60
      )
    end

    it "reports the request without adding it to allocated capacity", :aggregate_failures do
      expect(dashboard[:summary][:allocation]).to eq(85.0)
      expect(dashboard[:insights][:requested]).to eq(1)
    end
  end

  context "with an unsupported period" do
    subject(:dashboard) do
      described_class.new(project:, current_user: viewer, period: 9).call
    end

    it "uses the default period" do
      expect(dashboard[:period]).to eq(3)
    end
  end
end
