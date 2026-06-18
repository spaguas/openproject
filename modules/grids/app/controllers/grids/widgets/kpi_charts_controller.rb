# frozen_string_literal: true

class Grids::Widgets::KpiChartsController < Grids::WidgetController
  def show
    kpis = Kpi
      .associated_with_project(@project)
      .includes(:kpi_category)
      .ordered

    render json: {
      kpis: kpis.map { |kpi| serialize_kpi(kpi) }
    }
  end

  private

  def serialize_kpi(kpi)
    {
      id: kpi.id,
      name: kpi.name,
      category: kpi.category_name,
      currentValue: kpi.current_value.to_f,
      targetValue: kpi.target_value.to_f,
      progress: kpi.progress_percentage,
      unit: kpi.unit,
      status: kpi.status,
      href: project_kpi_path(@project, kpi)
    }
  end
end
