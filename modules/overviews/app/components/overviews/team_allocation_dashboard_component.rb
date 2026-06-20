# frozen_string_literal: true

module Overviews
  class TeamAllocationDashboardComponent < ApplicationComponent
    include ApplicationHelper
    include Redmine::I18n

    attr_reader :project, :dashboard, :form_url, :context

    def initialize(dashboard:, form_url:, project: nil, context: :project)
      super()
      @project = project
      @dashboard = dashboard
      @form_url = form_url
      @context = context
    end

    private

    def rows
      dashboard[:rows]
    end

    def summary
      dashboard[:summary]
    end

    def percentage(value)
      number_to_percentage(value, precision: 1)
    end

    def hours(value)
      "#{number_with_precision(value, precision: 1, strip_insignificant_zeros: true)}h"
    end

    def money(value)
      return t("overviews.team_allocation.restricted") if value.nil?

      number_to_currency(
        value,
        unit: Setting.costs_currency,
        format: Setting.costs_currency_format,
        negative_format: "-#{Setting.costs_currency_format}",
        precision: 0
      )
    end

    def allocation_tone(value)
      return "danger" if value > Overviews::TeamAllocationDashboard::CAPACITY_OVERLOAD
      return "warning" if value >= Overviews::TeamAllocationDashboard::CAPACITY_WARNING
      return "available" if value < Overviews::TeamAllocationDashboard::LOW_ALLOCATION

      "healthy"
    end

    def chart_width(value)
      [(value / dashboard[:chart_max].to_f) * 100, 100].min.round(2)
    end

    def capacity_marker
      (100.0 / dashboard[:chart_max] * 100).round(2)
    end

    def period_options
      dashboard[:period_options].map do |months|
        [t("overviews.team_allocation.months", count: months), months]
      end
    end

    def summary_note(key)
      case key
      when :allocation
        t(
          "overviews.team_allocation.metric_notes.allocation",
          allocated: hours(summary[:planned_hours]),
          capacity: hours(summary[:capacity_hours])
        )
      when :active_members
        active_members_note
      else
        t("overviews.team_allocation.metric_notes.#{key}")
      end
    end

    def description
      key = context == :global ? :global_description : :description
      t("overviews.team_allocation.#{key}")
    end

    def active_members_note
      key = context == :global ? :global_active_members : :active_members
      t("overviews.team_allocation.metric_notes.#{key}", total: summary[:total_members])
    end

    def member_allocation_summary(member_rows)
      member_rows.first(3).map do |row|
        "#{row[:user].name} (#{percentage(row[:allocation])})"
      end.join(", ")
    end
  end
end
