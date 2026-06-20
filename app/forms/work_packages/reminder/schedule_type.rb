# frozen_string_literal: true

class WorkPackages::Reminder::ScheduleType < ApplicationForm
  form do |reminder_form|
    reminder_form.radio_button_group(
      name: :schedule_type,
      label: I18n.t("work_package.reminders.schedule_type.label")
    ) do |group|
      %w[one_time deadline].each do |value|
        group.radio_button(
          value:,
          checked: model.schedule_type == value,
          label: I18n.t("work_package.reminders.schedule_type.#{value}.label"),
          caption: I18n.t("work_package.reminders.schedule_type.#{value}.caption"),
          data: {
            target_name: "reminder-schedule-type",
            "show-when-value-selected-target": "cause"
          }
        )
      end
    end
  end
end
