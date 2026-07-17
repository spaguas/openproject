# frozen_string_literal: true

module Overviews
  class GlobalKpiDashboardComponent < ApplicationComponent
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

    def kpis
      dashboard[:kpis]
    end

    def chart_config(key)
      ERB::Util.json_escape(dashboard.fetch(key).to_json)
    end

    def overdue_days(kpi)
      ((Time.current - kpi.next_measurement_at) / 1.day).floor
    end

    def status_tone(status)
      case status
      when "achieved", "on_track" then "success"
      when "at_risk" then "warning"
      when "off_track" then "danger"
      else "neutral"
      end
    end
  end
end
