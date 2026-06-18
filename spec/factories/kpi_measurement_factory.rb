# frozen_string_literal: true

FactoryBot.define do
  factory :kpi_measurement do
    kpi
    author factory: :user
    value { 50 }
    measured_at { Time.current }
  end
end
