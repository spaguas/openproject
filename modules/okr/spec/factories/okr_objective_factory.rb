# frozen_string_literal: true

FactoryBot.define do
  factory :okr_objective, class: "OkrObjective" do
    project
    sequence(:title) { |n| "Objective #{n}" }
    description { "Improve the project outcome." }
    start_date { Date.new(2026, 1, 1) }
    target_date { Date.new(2026, 3, 31) }
  end
end
