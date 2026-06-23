# frozen_string_literal: true

module Overviews
  class KpiDashboardComponent < ApplicationComponent
    include ApplicationHelper
    include Redmine::I18n

    attr_reader :project, :dashboard

    def initialize(project:, dashboard:)
      super()

      @project = project
      @dashboard = dashboard
    end

    private

    def summary
      dashboard[:summary]
    end

    def kpis
      dashboard[:kpis]
    end

    def can_manage_kpis?
      User.current.allowed_in_project?(:manage_kpis, project) &&
        User.current.allowed_in_project?(:edit_project, project)
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
