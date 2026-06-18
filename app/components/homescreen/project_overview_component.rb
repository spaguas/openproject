# frozen_string_literal: true

module Homescreen
  class ProjectOverviewComponent < ApplicationComponent
    include IconsHelper
    include Redmine::I18n

    DETAIL_KEYS = %i[projects areas work_packages completion overdue due_soon].freeze
    STATUS_COLORS = [
      "#0969da",
      "#1a7f37",
      "#bf8700",
      "#cf222e",
      "#8250df",
      "#57606a",
      "#0a7ea4",
      "#9a6700"
    ].freeze

    attr_reader :overview

    def initialize(overview:)
      super

      @overview = overview
    end

    delegate :summary, to: :overview

    def render?
      overview.visible?
    end

    def dialog_id(key)
      "homescreen-project-overview-#{key}-dialog"
    end

    def chart_config(key)
      raise ArgumentError, "Unknown project overview detail: #{key}" unless DETAIL_KEYS.include?(key)

      send("#{key}_chart_config")
    end

    def detail_title(key)
      t("homescreen.project_overview.details.#{key}.title")
    end

    def detail_description(key)
      t("homescreen.project_overview.details.#{key}.description", days: Homescreen::ProjectOverview::SOON_DAYS)
    end

    private

    def projects_chart_config
      rows = overview.project_responsibility_rows

      horizontal_bar_config(
        rows.pluck(:label),
        rows.pluck(:count),
        t("homescreen.project_overview.details.projects.dataset")
      )
    end

    def areas_chart_config
      stacked_percentage_config(overview.area_project_status_rows)
    end

    def work_packages_chart_config
      stacked_percentage_config(overview.area_work_package_status_rows)
    end

    def completion_chart_config
      completed = overview.completed_project_rows.size

      {
        type: "doughnut",
        labels: [
          t("homescreen.project_overview.details.completion.completed"),
          t("homescreen.project_overview.details.completion.remaining")
        ],
        datasets: [
          {
            data: [completed, overview.projects.size - completed],
            backgroundColor: ["#1a7f37", "#d0d7de"]
          }
        ],
        suffix: t("homescreen.project_overview.details.projects_suffix")
      }
    end

    def overdue_chart_config
      rows = overview.overdue_project_rows

      horizontal_bar_config(
        rows.map { it[:project].name },
        rows.pluck(:days),
        t("homescreen.project_overview.details.overdue.dataset"),
        color: "#cf222e",
        suffix: t("homescreen.project_overview.details.days_suffix")
      )
    end

    def due_soon_chart_config
      rows = overview.due_soon_project_rows

      horizontal_bar_config(
        rows.map { it[:project].name },
        rows.pluck(:days),
        t("homescreen.project_overview.details.due_soon.dataset"),
        color: "#bf8700",
        suffix: t("homescreen.project_overview.details.days_suffix")
      )
    end

    def horizontal_bar_config(labels, data, dataset_label, color: "#0969da", suffix: nil)
      {
        type: "bar",
        indexAxis: "y",
        labels:,
        datasets: [
          {
            label: dataset_label,
            data:,
            backgroundColor: color
          }
        ],
        suffix:
      }
    end

    def stacked_percentage_config(rows)
      {
        type: "bar",
        indexAxis: "y",
        stacked: true,
        percentage: true,
        labels: rows.map { it[:area].name },
        datasets: stacked_datasets(rows)
      }
    end

    def stacked_datasets(rows)
      statuses_for(rows).each_with_index.map do |status, index|
        {
          label: status,
          data: rows.map { |row| percentage(row[:statuses].fetch(status, 0), row[:total]) },
          rawData: rows.map { |row| row[:statuses].fetch(status, 0) },
          backgroundColor: STATUS_COLORS[index % STATUS_COLORS.size]
        }
      end
    end

    def statuses_for(rows)
      totals = Hash.new(0)
      rows.each { |row| row[:statuses].each { |status, count| totals[status] += count } }

      totals.sort_by { |label, count| [-count, label.downcase] }.map(&:first)
    end

    def percentage(part, total)
      return 0 if total.zero?

      ((part.to_f / total) * 100).round(1)
    end
  end
end
