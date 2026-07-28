# frozen_string_literal: true

module ContractManagement
  class DeadlineNotificationJob < ApplicationJob
    queue_as :mailers

    def perform(today: Date.current)
      ContractInvoice.where(status: "pending", due_on: ...today).update_all(status: "overdue", updated_at: Time.current)

      PublicContract.includes(responsibilities: :user, invoices: []).find_each do |contract|
        next unless contract.project.module_enabled?(:contract_management)

        notify_contract_deadline(contract, today)
        notify_invoice_deadlines(contract, today)
      end
    end

    private

    def notify_contract_deadline(contract, today)
      deadline_on = contract.effective_end_date
      return unless deadline_in_window?(deadline_on, today, contract.deadline_notification_days)

      notify_once(contract:, deadline_type: "contract", deadline_on:, today:)
    end

    def notify_invoice_deadlines(contract, today)
      contract.invoices.each do |invoice|
        next unless invoice.status == "pending"
        next unless deadline_in_window?(invoice.due_on, today, contract.deadline_notification_days)

        notify_once(contract:, invoice:, deadline_type: "invoice", deadline_on: invoice.due_on, today:)
      end
    end

    def deadline_in_window?(deadline, today, notification_days)
      deadline.between?(today, today + notification_days.days)
    end

    def notify_once(contract:, deadline_type:, deadline_on:, today:, invoice: nil)
      attributes = {
        public_contract: contract,
        invoice:,
        deadline_type:,
        deadline_on:,
        sent_on: today
      }
      return if ContractDeadlineNotification.exists?(attributes.except(:sent_on))

      recipients = contract
        .responsibilities
        .select { |responsibility| responsibility.notify? && active?(responsibility, today) }
        .map(&:user)
        .uniq
      return if recipients.empty?

      recipients.each do |recipient|
        ContractManagementMailer.deadline(recipient, contract, deadline_type:, deadline_on:, invoice:).deliver_later
      end
      ContractDeadlineNotification.create!(attributes)
    end

    def active?(responsibility, today)
      responsibility.starts_on <= today && (responsibility.ends_on.nil? || responsibility.ends_on >= today)
    end
  end
end
