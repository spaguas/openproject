# frozen_string_literal: true

require "rails_helper"

RSpec.describe Overviews::GlobalTeamAllocationDashboard do
  let(:viewer) { build_stubbed(:user) }
  let(:project_a) { build_stubbed(:project) }
  let(:project_b) { build_stubbed(:project) }
  let(:member) { build_stubbed(:user, firstname: "Team", lastname: "Member") }
  let(:project_scope) { instance_double(ActiveRecord::Relation) }

  subject(:dashboard) do
    described_class.new(current_user: viewer, period: 3).call
  end

  before do
    allow(Project).to receive(:visible).with(viewer).and_return(project_scope)
    allow(project_scope).to receive(:active).and_return(project_scope)
    allow(project_scope).to receive(:order).with(:lft, :name).and_return([project_a, project_b])

    allow(Overviews::TeamAllocationDashboard).to receive(:new)
      .with(project: project_a, current_user: viewer, period: 3)
      .and_return(instance_double(Overviews::TeamAllocationDashboard, call: project_dashboard(40)))
    allow(Overviews::TeamAllocationDashboard).to receive(:new)
      .with(project: project_b, current_user: viewer, period: 3)
      .and_return(instance_double(Overviews::TeamAllocationDashboard, call: project_dashboard(60)))
  end

  it "consolidates a member across all visible projects without duplicating capacity", :aggregate_failures do
    expect(dashboard[:rows].size).to eq(1)
    expect(dashboard[:rows].first).to include(
      user: member,
      allocated_hours: 100,
      capacity_hours: 100,
      allocation: 100,
      participation: 100
    )
    expect(dashboard[:summary]).to include(
      allocation: 100,
      active_members: 1,
      total_members: 1
    )
  end

  def project_dashboard(hours)
    {
      rows: [
        {
          user: member,
          roles: "Developer",
          allocated_hours: hours,
          logged_hours: hours / 2,
          capacity_hours: 100,
          allocation: hours,
          estimated_cost: hours * 100,
          participation: 100
        }
      ],
      insights: { requested: 0 },
      time_visible: true,
      costs_visible: true
    }
  end
end
