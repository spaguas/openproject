# frozen_string_literal: true

require "spec_helper"

RSpec.describe Okr::ObjectivesController do
  it "routes project OKR objectives" do
    expect(get("/projects/demo/okrs")).to route_to(
      controller: "okr/objectives",
      action: "index",
      project_id: "demo"
    )
  end

  it "routes nested KPI progress creation" do
    expect(post("/projects/demo/okrs/1/kpis/2/progress_entries")).to route_to(
      controller: "okr/progress_entries",
      action: "create",
      project_id: "demo",
      okr_objective_id: "1",
      kpi_id: "2"
    )
  end
end
