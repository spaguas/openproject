# frozen_string_literal: true

require "rails_helper"

RSpec.describe KpisController do
  shared_let(:project) { create(:project, enabled_module_names: %w[kpis]) }
  shared_let(:user) do
    create(:user, member_with_permissions: { project => %i[view_kpis manage_kpis] })
  end

  shared_current_user { user }

  describe "POST #create" do
    it "creates the KPI and its initial measurement in one operation" do
      expect do
        post :create,
             params: {
               project_id: project.id,
               kpi: {
                 name: "Service availability",
                 current_value: 98.5,
                 target_value: 99.9,
                 direction: "increase",
                 measurement_frequency: "monthly",
                 status: "on_track"
               }
             }
      end.to change(Kpi, :count).by(1).and change(KpiMeasurement, :count).by(1)

      kpi = Kpi.order(:id).last
      expect(kpi.measurement_frequency).to eq("monthly")
      expect(kpi.latest_measurement).to have_attributes(value: 98.5, author: user)
      expect(response).to redirect_to(project_kpi_path(project, kpi))
    end
  end

  describe "PATCH #update" do
    it "does not allow the cached current value to be edited directly" do
      kpi = create(:kpi, project:, current_value: 40)
      create(:kpi_measurement, kpi:, author: user, value: 40)

      patch :update,
            params: {
              project_id: project.id,
              id: kpi.id,
              kpi: {
                name: kpi.name,
                current_value: 90,
                target_value: kpi.target_value,
                direction: kpi.direction,
                measurement_frequency: kpi.measurement_frequency,
                status: kpi.status
              }
            }

      expect(kpi.reload.current_value).to eq(40)
    end
  end
end
