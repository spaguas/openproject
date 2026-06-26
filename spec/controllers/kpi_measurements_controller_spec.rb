# frozen_string_literal: true

require "rails_helper"

RSpec.describe KpiMeasurementsController do
  shared_let(:project) { create(:project, enabled_module_names: %w[kpis]) }
  shared_let(:user) do
    create(:user, member_with_permissions: { project => %i[view_kpis manage_kpis edit_project] })
  end
  shared_let(:kpi) { create(:kpi, project:) }

  shared_current_user { user }

  describe "GET #edit" do
    it "renders the edit form" do
      measurement = create(:kpi_measurement, kpi:, author: user, value: 40, measured_at: Date.yesterday)

      get :edit,
          params: {
            project_id: project.id,
            kpi_id: kpi.id,
            id: measurement.id
          }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST #create" do
    it "records the value, measurement time, insertion time, and responsible user" do
      measured_at = Date.new(2026, 6, 18)

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
        note: "Monthly result"
      )
      expect(measurement.measured_at.to_date).to eq(measured_at)
      expect(measurement.created_at).to be_present
      expect(kpi.reload.current_value).to eq(72.5)
      expect(response).to redirect_to(project_kpi_path(project, kpi))
    end

    context "without project management permission" do
      let(:user) do
        create(:user, member_with_permissions: { project => %i[view_kpis manage_kpis] })
      end

      it "does not record the measurement" do
        expect do
          post :create,
               params: {
                 project_id: project.id,
                 kpi_id: kpi.id,
                 kpi_measurement: {
                   value: 72.5,
                   measured_at: Date.new(2026, 6, 18),
                   note: "Monthly result"
                 }
               }
        end.not_to change(KpiMeasurement, :count)

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "with a future measurement date" do
      it "does not record the measurement" do
        expect do
          post :create,
               params: {
                 project_id: project.id,
                 kpi_id: kpi.id,
                 kpi_measurement: {
                   value: 72.5,
                   measured_at: Date.tomorrow,
                   note: "Monthly result"
                 }
               }
        end.not_to change(KpiMeasurement, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "PATCH #update" do
    it "updates the measurement and refreshes the current KPI value" do
      measurement = create(:kpi_measurement, kpi:, author: user, value: 40, measured_at: 2.days.ago)

      patch :update,
            params: {
              project_id: project.id,
              kpi_id: kpi.id,
              id: measurement.id,
              kpi_measurement: {
                value: 88.5,
                measured_at: Date.yesterday,
                note: "Updated result"
              }
            }

      expect(measurement.reload).to have_attributes(
        value: 88.5,
        note: "Updated result"
      )
      expect(measurement.measured_at.to_date).to eq(Date.yesterday)
      expect(kpi.reload.current_value).to eq(88.5)
      expect(response).to redirect_to(project_kpi_path(project, kpi))
    end

    it "does not update the measurement to a future measurement date" do
      measurement = create(:kpi_measurement, kpi:, author: user, value: 40, measured_at: 2.days.ago)

      patch :update,
            params: {
              project_id: project.id,
              kpi_id: kpi.id,
              id: measurement.id,
              kpi_measurement: {
                value: 88.5,
                measured_at: Date.tomorrow,
                note: "Updated result"
              }
            }

      expect(measurement.reload).to have_attributes(
        value: 40,
        note: nil
      )
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE #destroy" do
    it "removes the measurement and refreshes the current KPI value" do
      create(:kpi_measurement, kpi:, author: user, value: 40, measured_at: 2.days.ago)
      measurement = create(:kpi_measurement, kpi:, author: user, value: 88.5, measured_at: 1.day.ago)

      expect do
        delete :destroy,
               params: {
                 project_id: project.id,
                 kpi_id: kpi.id,
                 id: measurement.id
               }
      end.to change(KpiMeasurement, :count).by(-1)

      expect(kpi.reload.current_value).to eq(40)
      expect(response).to redirect_to(project_kpi_path(project, kpi))
    end
  end
end
