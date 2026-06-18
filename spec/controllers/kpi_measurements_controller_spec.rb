# frozen_string_literal: true

require "rails_helper"

RSpec.describe KpiMeasurementsController do
  shared_let(:project) { create(:project, enabled_module_names: %w[kpis]) }
  shared_let(:user) do
    create(:user, member_with_permissions: { project => %i[view_kpis manage_kpis] })
  end
  shared_let(:kpi) { create(:kpi, project:) }

  shared_current_user { user }

  describe "POST #create" do
    it "records the value, measurement time, insertion time, and responsible user" do
      measured_at = Time.zone.local(2026, 6, 18, 9, 30)

      expect do
        post :create,
             params: {
               project_id: project.id,
               kpi_id: kpi.id,
               kpi_measurement: {
                 value: 72.5,
                 measured_at:,
                 note: "Monthly result"
               }
             }
      end.to change(KpiMeasurement, :count).by(1)

      measurement = KpiMeasurement.order(:id).last
      expect(measurement).to have_attributes(
        kpi:,
        author: user,
        value: 72.5,
        measured_at:,
        note: "Monthly result"
      )
      expect(measurement.created_at).to be_present
      expect(kpi.reload.current_value).to eq(72.5)
      expect(response).to redirect_to(project_kpi_path(project, kpi))
    end
  end
end
