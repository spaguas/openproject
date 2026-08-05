# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Contract operational tabs", :js, :selenium do
  let(:admin) { create(:admin) }
  let(:project) { create(:project, enabled_module_names: %w[contract_management]) }
  let!(:contract) { create(:public_contract, project:) }

  before do
    login_as(admin)
  end

  it "groups contract records into icon tabs and preserves the selected anchor" do
    visit project_contract_management_contract_path(project, contract)

    expect(page).to have_css(".contract-record-tabs__tab", count: 7)
    expect(page).to have_css('[data-contract-section-tabs-tab="measurements"][aria-selected="true"]')
    expect(page).to have_css(".contract-record-tabs__tab .contract-record-tabs__icon", count: 7)

    find('[data-contract-section-tabs-tab="invoices"]').click

    expect(page).to have_css('[data-contract-section-tabs-tab="invoices"][aria-selected="true"]')
    expect(page).to have_css('[data-contract-section-tabs-panel="invoices"]:not([hidden])')
    expect(page.current_url).to end_with("#invoices")
  end
end
