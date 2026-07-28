# frozen_string_literal: true

class ContractManagementMailer < ApplicationMailer
  def deadline(recipient, contract, deadline_type:, deadline_on:, invoice: nil)
    @recipient = recipient
    @contract = contract
    @deadline_type = deadline_type
    @deadline_on = deadline_on
    @invoice = invoice
    @contract_url = project_contract_management_contract_url(contract.project, contract)

    send_localized_mail(recipient) do
      I18n.t(
        "contract_management.mailer.subject.#{deadline_type}",
        contract: contract.number,
        invoice: invoice&.number,
        date: I18n.l(deadline_on)
      )
    end
  end
end
