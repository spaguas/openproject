# frozen_string_literal: true

module ContractManagement
  class NotificationService
    def initialize(subject:, kind:, today: Date.current)
      @subject = subject
      @contract = subject.public_contract
      @kind = kind
      @today = today
    end

    def call
      return if ContractNotification.exists?(subject: @subject, kind: @kind)

      recipients = @contract.responsibilities.notifiable.active_on(@today).includes(:user).map(&:user).uniq
      return if recipients.empty?

      recipients.each do |recipient|
        ContractManagementMailer.contract_event(recipient, @contract, @subject, kind: @kind).deliver_later
      end
      ContractNotification.create!(public_contract: @contract, subject: @subject, kind: @kind, sent_on: @today)
    end
  end
end
