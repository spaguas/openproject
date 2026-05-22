# frozen_string_literal: true

FactoryBot.define do
  factory :okr_kpi, class: "OkrKpi" do
    objective factory: :okr_objective
    sequence(:name) { |n| "KPI #{n}" }
    description { "Measure progress toward the objective." }
    update_frequency { "weekly" }
    unit { "%" }
    baseline_value { 20 }
    current_value { 20 }
    target_value { 80 }
    target_direction { "increase" }
  end
end
