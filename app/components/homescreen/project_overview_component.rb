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
    CALENDAR_STATUS_CONFIG = {
      on_track: { value: 1, color: "#0969da" },
      overdue: { value: 2, color: "#bf8700" },
      completed: { value: 3, color: "#1a7f37" }
    }.freeze
    CALENDAR_STATUS_PRIORITY = %i[overdue on_track completed].freeze

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

    def project_graph_config
      graph_data = overview.project_graph_data

      {
        labels: project_graph_labels,
        categories: project_graph_categories,
        nodes: graph_data[:nodes].map { |node| project_graph_node(node) },
        links: graph_data[:links].map { |link| project_graph_link(link) }
      }
    end

    def project_graph_config_json
      ERB::Util.json_escape(project_graph_config.to_json)
    end

    def project_calendar_config
      return @project_calendar_config if defined?(@project_calendar_config)

      calendar_data = overview.project_calendar_heatmap_data

      @project_calendar_config = {
        year: calendar_data[:year],
        labels: project_calendar_labels,
        legend: calendar_legend,
        entries: calendar_entries(calendar_data[:entries])
      }
    end

    def project_calendar_config_json
      ERB::Util.json_escape(project_calendar_config.to_json)
    end

    def project_map_config
      map_data = overview.project_map_data

      {
        center: map_data[:center],
        labels: project_map_labels,
        legend: project_map_legend,
        projects: map_data[:projects],
        work_packages: map_data[:work_packages]
      }
    end

    def project_map_config_json
      ERB::Util.json_escape(project_map_config.to_json)
    end

    private

    def project_map_labels
      {
        project_layer: t("homescreen.project_map.layers.projects"),
        work_package_layer: t("homescreen.project_map.layers.work_packages"),
        project: Project.model_name.human,
        work_package: WorkPackage.model_name.human,
        type: t("homescreen.project_map.tooltip.type"),
        responsible: t("homescreen.project_map.tooltip.responsible"),
        phase: t("homescreen.project_map.tooltip.phase"),
        progress: t("homescreen.project_map.tooltip.progress"),
        priority: t("homescreen.project_map.tooltip.priority"),
        status: t("homescreen.project_map.tooltip.status"),
        georeferenced: t("homescreen.project_map.tooltip.georeferenced"),
        fallback_location: t("homescreen.project_map.tooltip.fallback_location"),
        georeferenced_yes: t("homescreen.project_map.tooltip.georeferenced_yes"),
        open: t("homescreen.project_map.tooltip.open")
      }
    end

    def project_map_legend
      {
        on_track: { label: t("homescreen.project_map.statuses.on_track"), color: "#0969da" },
        overdue: { label: t("homescreen.project_map.statuses.overdue"), color: "#bf8700" },
        completed: { label: t("homescreen.project_map.statuses.completed"), color: "#1a7f37" }
      }
    end

    def project_graph_labels
      {
        empty: t("homescreen.project_graph.details.empty"),
        area: t("homescreen.project_graph.details.area"),
        type: t("homescreen.project_graph.details.type"),
        status: t("homescreen.project_graph.details.status"),
        work_packages: t("homescreen.project_graph.details.work_packages"),
        open_work_packages: t("homescreen.project_graph.details.open_work_packages"),
        completion: t("homescreen.project_graph.details.completion"),
        open_project: t("homescreen.project_graph.details.open_project")
      }
    end

    def project_graph_categories
      %w[portfolio program project].map do |workspace_type|
        {
          name: t("homescreen.project_graph.categories.#{workspace_type}")
        }
      end
    end

    def project_graph_node(node)
      category = %w[portfolio program project].index(node[:workspace_type]) || 2
      size = 34 + [node[:work_packages], 24].min

      {
        id: node[:id].to_s,
        name: node[:name],
        category:,
        value: node[:work_packages],
        symbolSize: size,
        detail: node.merge(
          url: helpers.project_path(node[:id])
        )
      }
    end

    def project_graph_link(link)
      {
        source: link[:source].to_s,
        target: link[:target].to_s,
        name: link[:label],
        lineStyle: {
          color: link[:kind] == "kpi" ? "#bf8700" : "#0969da",
          type: link[:kind] == "kpi" ? "dashed" : "solid",
          width: link[:kind] == "kpi" ? 1.5 : 2
        }
      }
    end

    def project_calendar_labels
      {
        empty: t("homescreen.project_calendar.empty"),
        projects: t("homescreen.project_calendar.projects"),
        status: t("homescreen.project_calendar.status")
      }
    end

    def calendar_legend
      CALENDAR_STATUS_CONFIG.map do |status, config|
        {
          status: status.to_s,
          label: t("homescreen.project_calendar.statuses.#{status}"),
          color: config[:color],
          value: config[:value]
        }
      end
    end

    def calendar_entries(entries)
      entries
        .group_by { |entry| entry[:date] }
        .map { |date, day_entries| calendar_day_entry(date, day_entries) }
        .sort_by { |entry| entry[:date] }
    end

    def calendar_day_entry(date, entries)
      status = dominant_calendar_status(entries)
      config = CALENDAR_STATUS_CONFIG.fetch(status)

      {
        date:,
        value: config[:value],
        status: status.to_s,
        status_label: t("homescreen.project_calendar.statuses.#{status}"),
        color: config[:color],
        count: entries.size,
        projects: entries
          .sort_by { |entry| [entry[:status].to_s, entry[:project].downcase] }
          .map do |entry|
            {
              name: entry[:project],
              status: entry[:status].to_s,
              status_label: entry[:status_label],
              url: entry[:url]
            }
          end
      }
    end

    def dominant_calendar_status(entries)
      statuses = entries.map { |entry| entry[:status].to_sym }

      CALENDAR_STATUS_PRIORITY.find { |status| statuses.include?(status) } || :on_track
    end

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
