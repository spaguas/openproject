# frozen_string_literal: true

module Grids
  module Widgets
    class ProjectScheduleCalendar < Grids::WidgetComponent
      include Rails.application.routes.url_helpers

      param :project

      STATUS_CONFIG = {
        on_track: { value: 1, color: "#0969da" },
        overdue: { value: 2, color: "#bf8700" }
      }.freeze
      STATUS_PRIORITY = %i[overdue on_track].freeze
      private_constant :STATUS_CONFIG, :STATUS_PRIORITY

      def title
        I18n.t("overviews.project_insights.calendar.title")
      end

      def config_json
        ERB::Util.json_escape(config.to_json)
      end

      def legend
        STATUS_CONFIG.map do |status, config|
          {
            label: I18n.t("overviews.project_insights.statuses.#{status}"),
            color: config[:color]
          }
        end
      end

      private

      def config
        {
          year: Date.current.year,
          labels:,
          entries: calendar_entries
        }
      end

      def labels
        {
          empty: I18n.t("overviews.project_insights.calendar.empty"),
          items: I18n.t("overviews.project_insights.calendar.items"),
          status: I18n.t("overviews.project_insights.status")
        }
      end

      def calendar_entries
        raw_calendar_entries
          .group_by { |entry| entry[:date] }
          .map { |date, entries| day_entry(date, entries) }
          .sort_by { |entry| entry[:date] }
      end

      def raw_calendar_entries
        project_entries + work_package_entries
      end

      def project_entries
        child_projects.filter_map do |child|
          date = project_due_date(child)
          next if date.blank? || date.year != Date.current.year

          status = project_overdue?(child, date) ? :overdue : :on_track
          {
            date: date.iso8601,
            name: child.name,
            kind: child.workspace_label,
            status:,
            status_label: I18n.t("overviews.project_insights.statuses.#{status}"),
            url: project_path(child)
          }
        end
      end

      def work_package_entries
        visible_work_packages.filter_map do |work_package|
          date = work_package.due_date || work_package.start_date
          next if date.blank? || date.year != Date.current.year

          status = work_package.overdue? ? :overdue : :on_track
          {
            date: date.iso8601,
            name: "##{work_package.id} #{work_package.subject}",
            kind: WorkPackage.model_name.human,
            status:,
            status_label: I18n.t("overviews.project_insights.statuses.#{status}"),
            url: work_package_path(work_package)
          }
        end
      end

      def day_entry(date, entries)
        status = dominant_status(entries)
        config = STATUS_CONFIG.fetch(status)

        {
          date:,
          value: config[:value],
          status: status.to_s,
          status_label: I18n.t("overviews.project_insights.statuses.#{status}"),
          color: config[:color],
          count: entries.size,
          items: entries.sort_by { |entry| [entry[:status].to_s, entry[:name].downcase] }
        }
      end

      def dominant_status(entries)
        statuses = entries.map { |entry| entry[:status] }

        STATUS_PRIORITY.find { |status| statuses.include?(status) } || :on_track
      end

      def child_projects
        @child_projects ||= project.children.visible(current_user).active.order(:lft, :name).to_a
      end

      def project_ids
        @project_ids ||= [project.id] + child_projects.map(&:id)
      end

      def visible_work_packages
        @visible_work_packages ||= WorkPackage
          .visible(current_user)
          .where(project_id: project_ids)
          .includes(:status, :type)
          .order(Arel.sql("due_date ASC NULLS LAST"), :id)
          .to_a
      end

      def work_packages_by_project
        @work_packages_by_project ||= visible_work_packages.group_by(&:project_id)
      end

      def project_due_date(child)
        overdue_due_dates = child_work_packages(child).select(&:overdue?).filter_map(&:due_date)
        return overdue_due_dates.min if overdue_due_dates.any?

        child.available_phases.filter_map(&:finish_date).max ||
          child_work_packages(child).filter_map(&:due_date).max
      end

      def project_overdue?(child, date)
        return false if child.finished?

        child_work_packages(child).any?(&:overdue?) || date < Date.current
      end

      def child_work_packages(child)
        work_packages_by_project[child.id] || []
      end
    end
  end
end
