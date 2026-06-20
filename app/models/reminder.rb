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

class Reminder < ApplicationRecord
  DEADLINE_DAYS = [0, 1, 3, 7, 14, 30].freeze
  RECURRENCE_INTERVALS = {
    "once" => nil,
    "daily" => 1.day,
    "every_three_days" => 3.days,
    "weekly" => 1.week
  }.freeze

  belongs_to :remindable, polymorphic: true
  belongs_to :creator, class_name: "User"

  has_many :reminder_notifications, dependent: :destroy
  has_many :notifications, through: :reminder_notifications

  enum :schedule_type, {
    one_time: "one_time",
    deadline: "deadline"
  }, prefix: true

  enum :recurrence, {
    once: "once",
    daily: "daily",
    every_three_days: "every_three_days",
    weekly: "weekly"
  }, prefix: true

  enum :delivery_channel, {
    system_only: "system_only",
    system_and_email: "system_and_email"
  }, prefix: true

  # Currently, reminders are personal, meaning
  # they are only visible to the user who created them
  # and who still has access to the remindable.
  def self.visible(user)
    where(creator: user)
      .where(remindable_type: WorkPackage.name, remindable_id: WorkPackage.visible(user).select(:id))
  end

  def self.upcoming_and_visible_to(user)
    active = visible(user).where(completed_at: nil)

    active.where(schedule_type: "deadline")
      .or(
        active
          .where(schedule_type: "one_time")
          .where.not(id: ReminderNotification.select(:reminder_id))
      )
  end

  def visible?(user = User.current)
    creator == user && remindable.visible?(user)
  end

  def unread_notifications?
    unread_notifications.exists?
  end

  def unread_notifications
    notifications.where(read_ian: [false, nil])
  end

  def completed?
    completed_at.present?
  end

  def scheduled?
    job_id.present? && !completed?
  end

  def next_deadline_occurrence(after: Time.current)
    return unless schedule_type_deadline? && remindable&.due_date

    first_occurrence = first_deadline_occurrence
    return first_occurrence if first_occurrence >= after
    return if recurrence_once?

    recurring_deadline_occurrence(first_occurrence, after:)
  end

  def first_deadline_occurrence
    deadline_time(remindable.due_date - days_before.days)
  end

  def recurring_deadline_occurrence(first_occurrence, after:)
    interval = RECURRENCE_INTERVALS.fetch(recurrence)
    occurrence = first_occurrence
    occurrence += interval while occurrence < after
    occurrence if occurrence <= deadline_time(remindable.due_date)
  end

  def deadline_time(date)
    creator.time_zone.local(date.year, date.month, date.day, 9)
  end
end
