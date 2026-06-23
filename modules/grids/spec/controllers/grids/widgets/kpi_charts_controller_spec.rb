# frozen_string_literal: true

require "rails_helper"

RSpec.describe Grids::Widgets::KpiChartsController do
  shared_let(:project) { create(:project, enabled_module_names: %w[kpis]) }
  shared_let(:user) { create(:user, member_with_permissions: { project => %i[view_kpis edit_project] }) }
  shared_let(:kpi) do
    create(
      :kpi,
      project:,
      name: "Delivery rate",
      current_value: 75,
      target_value: 100,
      unit: "%",
      status: "on_track"
    )
  end

  current_user { user }

  describe "GET #show" do
    before do
      kpi
      get :show, params: { project_id: project.identifier }, format: :json
    end

    it "returns the project KPI metrics", :aggregate_failures do
      expect(response).to be_successful

      item = response.parsed_body.fetch("kpis").sole
      expect(item).to include(
        "id" => kpi.id,
        "name" => "Delivery rate",
        "currentValue" => 75.0,
        "targetValue" => 100.0,
        "progress" => 75,
        "unit" => "%",
        "status" => "on_track"
      )
    end
  end
end
