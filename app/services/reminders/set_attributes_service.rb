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
  class SetAttributesService < ::BaseServices::SetAttributes
    def perform
      remind_at_params = params.extract!(:remind_at_date, :remind_at_time)

      build_remind_at(params, remind_at_params) unless params.key?(:remind_at)

      contract_call = super

      if contract_call.failure?
        prepare_errors_from_result(remind_at_params, contract_call)
      end

      contract_call
    end

    private

    def build_remind_at(params, remind_at_params)
      if deadline_schedule?(params)
        build_deadline_remind_at(params)
      else
        build_remind_at_from_params(params, remind_at_params)
      end
    end

    def deadline_schedule?(params)
      params.fetch(:schedule_type, model.schedule_type) == "deadline"
    end

    def build_deadline_remind_at(params)
      remindable = params[:remindable] || model.remindable
      days_before = params[:days_before].to_i

      params[:remind_at] =
        if remindable&.due_date
          first_occurrence = deadline_time(remindable.due_date - days_before.days)
          next_deadline_occurrence(
            first_occurrence:,
            due_date: remindable.due_date,
            recurrence: params.fetch(:recurrence, model.recurrence)
          )
        end
    end

    def next_deadline_occurrence(first_occurrence:, due_date:, recurrence:)
      return first_occurrence if first_occurrence >= Time.current
      return first_occurrence if recurrence == "once"

      interval = Reminder::RECURRENCE_INTERVALS[recurrence]
      return first_occurrence unless interval

      occurrence = first_occurrence
      occurrence += interval while occurrence < Time.current

      occurrence <= deadline_time(due_date) ? occurrence : first_occurrence
    end

    def deadline_time(date)
      user.time_zone.local(date.year, date.month, date.day, 9)
    end

    def build_remind_at_from_params(params, remind_at_params)
      return params if remind_at_params.empty?

      date = remind_at_params[:remind_at_date]
      time = remind_at_params[:remind_at_time]
      params[:remind_at] = date.present? && time.present? ? User.current.time_zone.parse("#{date} #{time}") : nil
    end

    # At the form level, we split the date and time into two form fields.
    # In order to be a bit more informative of which field is causing
    # the remind_at attribute to be in the past/invalid, we need to
    # remap the error attribute to the appropriate field.
    def prepare_errors_from_result(remind_at_params, contract_call)
      return contract_call unless contract_call.errors.include?(:remind_at)
      return prepare_deadline_errors(contract_call) if contract_call.result.schedule_type_deadline?

      case contract_call.errors.find { |error| error.attribute == :remind_at }.type
      when :blank
        handle_blank_error(remind_at_params, contract_call)
      when :datetime_must_be_in_future
        handle_future_error(contract_call)
      end

      contract_call.errors.delete(:remind_at)
    end

    def prepare_deadline_errors(contract_call)
      if contract_call.errors.added?(:remind_at, :datetime_must_be_in_future)
        contract_call.errors.add(:days_before, :deadline_alert_must_be_in_future)
      end

      contract_call.errors.delete(:remind_at)
      contract_call
    end

    def handle_blank_error(remind_at_params, contract_call)
      %i[remind_at_date remind_at_time].each do |attribute|
        contract_call.errors.add(attribute, :blank) if remind_at_params[attribute].blank?
      end
    end

    def handle_future_error(contract_call)
      reminder = contract_call.result

      {
        remind_at_date: (reminder.remind_at.to_date < today_in_user_time_zone),
        remind_at_time: (reminder.remind_at < now_in_user_time_zone)
      }.each do |attribute, in_the_past|
        contract_call.errors.add(attribute, :datetime_must_be_in_future) if in_the_past
      end
    end

    def today_in_user_time_zone
      @today_in_user_time_zone ||= now_in_user_time_zone.to_date
    end

    def now_in_user_time_zone
      @now_in_user_time_zone ||= Time.current.in_time_zone(User.current.time_zone)
    end
  end
end
