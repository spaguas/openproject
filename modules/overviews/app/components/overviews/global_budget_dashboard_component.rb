# frozen_string_literal: true

module Overviews
  class GlobalBudgetDashboardComponent < ApplicationComponent
    include ApplicationHelper
    include Redmine::I18n

    attr_reader :dashboard, :form_url

    def initialize(dashboard:, form_url:)
      super()
      @dashboard = dashboard
      @form_url = form_url
    end

    private

    def summary
      dashboard[:summary]
    end

    def insights
      dashboard[:insights]
    end

    def budgets
      dashboard[:budgets]
    end

    def money(value, precision: 0)
      number_to_currency(
        value,
        unit: Setting.costs_currency,
        format: Setting.costs_currency_format,
        negative_format: "-#{Setting.costs_currency_format}",
        precision:
      )
    end

    def percentage(value)
      number_to_percentage(value, precision: 1)
    end

    def months(value)
      return t("overviews.budget.insights.runway.no_projection") if value.blank?

      t("overviews.budget.insights.runway.months", count: value)
    end

    def chart_config(key)
      ERB::Util.json_escape(dashboard.fetch(key).to_json)
    end

    def trend_has_data?
      dashboard[:trend_chart][:datasets].any? { |dataset| dataset[:data].any?(&:positive?) }
    end

    def ratio_tone(ratio)
      return "danger" if ratio > 100
      return "warning" if ratio >= 80

      "success"
    end

    def project_summary(project_rows)
      project_rows.first(3).map do |row|
        "#{row[:project].name} (#{money(row[:spent])})"
      end.join(", ")
    end
  end
end
