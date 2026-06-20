# frozen_string_literal: true

class WorkPackages::Reminder::DeadlineSettings < ApplicationForm
  form do |reminder_form|
    reminder_form.select_list(
      name: :days_before,
      label: I18n.t("work_package.reminders.deadline.days_before"),
      input_width: :medium
    ) do |list|
      Reminder::DEADLINE_DAYS.each do |days|
        list.option(
          label: I18n.t("work_package.reminders.deadline.day_options", count: days),
          value: days,
          selected: model.days_before == days
        )
      end
    end

    reminder_form.select_list(
      name: :recurrence,
      label: I18n.t("work_package.reminders.deadline.recurrence"),
      input_width: :medium
    ) do |list|
      Reminder.recurrences.each_key do |value|
        list.option(
          label: I18n.t("work_package.reminders.deadline.recurrences.#{value}"),
          value:,
          selected: model.recurrence == value
        )
      end
    end

    reminder_form.radio_button_group(
      name: :delivery_channel,
      label: I18n.t("work_package.reminders.deadline.delivery_channel")
    ) do |group|
      Reminder.delivery_channels.each_key do |value|
        group.radio_button(
          value:,
          checked: model.delivery_channel == value,
          label: I18n.t("work_package.reminders.deadline.delivery_channels.#{value}.label"),
          caption: I18n.t("work_package.reminders.deadline.delivery_channels.#{value}.caption")
        )
      end
    end
  end
end
