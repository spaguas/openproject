# frozen_string_literal: true

FactoryBot.define do
  factory :public_contract do
    association :project
    sequence(:number) { |number| "CT-#{number}" }
    sei_process_number { "006.000001/2026-01" }
    start_date { Date.new(2026, 1, 1) }
    end_date { Date.new(2026, 12, 31) }
    duration_months { 12 }
    description { "Public service contract" }
    amount { 100_000 }
    deadline_notification_days { 30 }
  end
end
