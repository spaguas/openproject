# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

module Reminders
  class ScheduleReminderJob < ApplicationJob
    queue_with_priority :notification

    def self.schedule(reminder)
      set(wait_until: reminder.remind_at).perform_later(reminder)
    end

    def perform(reminder)
      return if reminder.schedule_type_one_time? && reminder.unread_notifications?

      unless reminder.visible?(reminder.creator)
        reminder.update_column(:completed_at, Time.current)
        return
      end

      create_notification_service = create_notification_from_reminder(reminder)

      create_notification_service.on_success do |service_result|
        process_created_notification(reminder, service_result.result)
      end

      create_notification_service.on_failure do |service_result|
        Rails.logger.error do
          "Failed to create notification for reminder #{reminder.id}: #{service_result.message}"
        end
      end
    end

    private

    def process_created_notification(reminder, notification)
      ReminderNotification.create!(reminder:, notification:)
      dispatch_immediate_email_notification(notification)
      schedule_next_deadline_notification(reminder)
    end

    def create_notification_from_reminder(reminder)
      Notifications::CreateService
        .new(user: reminder.creator)
        .call(
          recipient_id: reminder.creator_id,
          resource: reminder.remindable,
          reason: :reminder
        )
    end

    def dispatch_immediate_email_notification(notification)
      recipient = notification.recipient
      send_email =
        if notification.reminder.schedule_type_deadline?
          notification.reminder.delivery_channel_system_and_email?
        else
          recipient.pref.immediate_reminders[:personal_reminder]
        end

      return unless send_email

      Mails::Reminders::NotificationDeliveryJob.perform_later(notification)
    end

    def schedule_next_deadline_notification(reminder)
      return unless reminder.schedule_type_deadline?

      next_occurrence = reminder.next_deadline_occurrence(after: reminder.remind_at + 1.second)

      if next_occurrence
        reminder.update_columns(remind_at: next_occurrence, job_id: nil)
        job = self.class.schedule(reminder)
        reminder.update_columns(job_id: job.job_id)
      else
        reminder.update_columns(completed_at: Time.current, job_id: nil)
      end
    end
  end
end
