# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Contract portfolio dashboard", :js, :selenium do
  let(:admin) { create(:admin) }
  let(:project) { create(:project, enabled_module_names: %w[contract_management]) }
  let!(:active_contract) do
    create(:public_contract, project:, number: "ACTIVE-2026", end_date: 6.months.from_now.to_date)
  end
  let!(:expired_contract) do
    create(:public_contract, project:, number: "EXPIRED-2025", end_date: 1.month.ago.to_date)
  end

  before do
    login_as(admin)
  end

  it "shows coordinated insights and opens status details" do
    visit contract_management_portfolio_path

    expect(page).to have_css(".contract-dashboard__kpi", count: 4)
    expect(page).to have_text(active_contract.number)
    expect(page).to have_text(expired_contract.number)

    find('[data-contract-dashboard-key-param="status-expired"]').click

    expect(page).to have_css("dialog.contract-dashboard__dialog[open]")
    within("dialog.contract-dashboard__dialog") do
      expect(page).to have_text(expired_contract.number)
      expect(page).to have_no_text(active_contract.number)
    end
  end

  it "filters the whole dashboard by contract status" do
    visit contract_management_portfolio_path

    select I18n.t("contract_management.portfolio.statuses.active"), from: "status"
    click_button I18n.t("contract_management.portfolio.filters.apply")

    expect(page).to have_text(active_contract.number)
    expect(page).to have_no_text(expired_contract.number)
  end
end
