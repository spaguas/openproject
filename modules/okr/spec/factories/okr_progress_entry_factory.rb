# frozen_string_literal: true

FactoryBot.define do
  factory :okr_progress_entry, class: "OkrProgressEntry" do
    kpi factory: :okr_kpi
    author factory: :user
    value { 35 }
    recorded_on { Date.new(2026, 1, 12) }
    note { "Weekly checkpoint." }
  end
end
