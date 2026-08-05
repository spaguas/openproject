# frozen_string_literal: true

module OpenProject::ContractManagement
  class Hooks < OpenProject::Hook::ViewListener
    render_on :homescreen_after_links, partial: "hooks/contract_management/homescreen_summary"
  end
end
