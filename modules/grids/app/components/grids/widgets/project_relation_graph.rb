# frozen_string_literal: true

module Grids
  module Widgets
    class ProjectRelationGraph < Grids::WidgetComponent
      include Rails.application.routes.url_helpers

      TASK_LIMIT = 120
      private_constant :TASK_LIMIT

      param :project

      def title
        I18n.t("overviews.project_insights.graph.title")
      end

      def config_json
        ERB::Util.json_escape(config.to_json)
      end

      private

      def config
        {
          labels:,
          categories:,
          nodes:,
          links:
        }
      end

      def labels
        {
          empty: I18n.t("overviews.project_insights.graph.empty"),
          type: I18n.t("overviews.project_insights.type"),
          status: I18n.t("overviews.project_insights.status"),
          date: I18n.t("overviews.project_insights.date")
        }
      end

      def categories
        [
          { name: Project.model_name.human },
          { name: I18n.t(:label_subproject_plural) },
          { name: WorkPackage.model_name.human }
        ]
      end

      def nodes
        [project_node] + child_project_nodes + work_package_nodes
      end

      def links
        child_project_links + work_package_links
      end

      def project_node
        {
          id: project_node_id(project),
          name: project.name,
          category: 0,
          symbolSize: 58,
          value: visible_work_packages.size,
          detail: {
            type: project.workspace_label,
            status: project_status_label(project),
            url: project_path(project)
          }
        }
      end

      def child_project_nodes
        child_projects.map do |child|
          {
            id: project_node_id(child),
            name: child.name,
            category: 1,
            symbolSize: 42,
            value: work_packages_by_project[child.id]&.size || 0,
            detail: {
              type: child.workspace_label,
              status: project_status_label(child),
              url: project_path(child)
            }
          }
        end
      end

      def work_package_nodes
        visible_work_packages.first(TASK_LIMIT).map do |work_package|
          {
            id: work_package_node_id(work_package),
            name: "##{work_package.id} #{work_package.subject}",
            category: 2,
            symbolSize: work_package.overdue? ? 30 : 24,
            value: work_package.overdue? ? 2 : 1,
            itemStyle: {
              color: work_package.overdue? ? "#bf8700" : "#0969da"
            },
            detail: {
              type: work_package.type.name,
              status: work_package.status.name,
              date: work_package.due_date&.iso8601,
              url: work_package_path(work_package)
            }
          }
        end
      end

      def child_project_links
        child_projects.map do |child|
          {
            source: project_node_id(project),
            target: project_node_id(child),
            name: I18n.t("overviews.project_insights.graph.relations.child_project")
          }
        end
      end

      def work_package_links
        visible_work_packages.first(TASK_LIMIT).map do |work_package|
          {
            source: project_node_id(projects_by_id.fetch(work_package.project_id)),
            target: work_package_node_id(work_package),
            name: I18n.t("overviews.project_insights.graph.relations.task")
          }
        end
      end

      def child_projects
        @child_projects ||= project.children.visible(current_user).active.order(:lft, :name).to_a
      end

      def projects_by_id
        @projects_by_id ||= ([project] + child_projects).index_by(&:id)
      end

      def visible_work_packages
        @visible_work_packages ||= WorkPackage
          .visible(current_user)
          .where(project_id: projects_by_id.keys)
          .includes(:project, :status, :type)
          .order(Arel.sql("due_date ASC NULLS LAST"), :id)
          .to_a
      end

      def work_packages_by_project
        @work_packages_by_project ||= visible_work_packages.group_by(&:project_id)
      end

      def project_status_label(target_project)
        return I18n.t("overviews.project_insights.status_not_set") if target_project.status_code.blank?

        I18n.t("activerecord.attributes.project.status_codes.#{target_project.status_code}")
      end

      def project_node_id(target_project)
        "project-#{target_project.id}"
      end

      def work_package_node_id(work_package)
        "work-package-#{work_package.id}"
      end
    end
  end
end
