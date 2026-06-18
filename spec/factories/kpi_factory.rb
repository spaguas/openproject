# frozen_string_literal: true

FactoryBot.define do
  factory :kpi do
    project
    sequence(:name) { |number| "KPI #{number}" }
    current_value { 25 }
    target_value { 100 }
    direction { "increase" }
    status { "on_track" }
  end
end
