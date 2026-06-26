# frozen_string_literal: true

module Homescreen
  class ProjectOverview
    SOON_DAYS = 14

    attr_reader :user, :projects, :work_packages

    def initialize(user:)
      @user = user
      @projects = Project.visible(user).active.order(:lft, :name).to_a
      @work_packages = visible_work_packages
    end

    def visible?
      projects.any?
    end

    def summary
      {
        projects: projects.size,
        areas: areas.size,
        work_packages: work_packages.size,
        open: open_work_packages.size,
        closed: closed_work_packages.size,
        overdue: overdue_project_rows.size,
        due_soon: due_soon_project_rows.size,
        unassigned: unassigned_work_packages.size,
        completion: project_completion_percentage
      }
    end

    def status_distribution
      distribution_for(:status)
    end

    def type_distribution
      distribution_for(:type).first(6)
    end

    def area_distribution
      work_packages
        .group_by { |work_package| area_for(projects_by_id.fetch(work_package.project_id)) }
        .map { |area, items| overview_entry(area.name, items.size, project_path_id: area.id) }
        .sort_by { |entry| [-entry[:count], entry[:label].downcase] }
    end

    def project_rows
      grouped = work_packages.group_by(&:project_id)
      rows = projects.filter_map { |project| project_row(project, grouped[project.id] || []) }

      rows.sort_by { |row| [-row[:overdue], -row[:open], row[:project].name.downcase] }.first(10)
    end

    def recent_work_packages
      work_packages
        .sort_by(&:updated_at)
        .last(8)
        .reverse
    end

    def project_responsibility_rows
      grouped = Hash.new { |hash, key| hash[key] = [] }

      projects.each { |project| group_project_by_responsible(grouped, project) }
      rows = grouped.map { |responsible, responsible_projects| responsibility_row(responsible, responsible_projects) }

      rows.sort_by { |row| [-row[:count], row[:label].downcase] }
    end

    def area_project_status_rows
      grouped = projects.group_by { |project| area_for(project) }
      rows = grouped.map { |area, area_projects| area_project_status_row(area, area_projects) }

      rows.sort_by { |row| [-row[:total], row[:area].name.downcase] }
    end

    def area_work_package_status_rows
      grouped = work_packages.group_by { |work_package| area_for(projects_by_id.fetch(work_package.project_id)) }
      rows = grouped.map { |area, area_work_packages| area_work_package_status_row(area, area_work_packages) }

      rows.sort_by { |row| [-row[:total], row[:area].name.downcase] }
    end

    def completed_project_rows
      rows = projects
        .select(&:finished?)
        .map do |project|
          {
            project:,
            area: area_for(project),
            status: project_status_label(project)
          }
        end

      rows.sort_by { |row| row[:project].name.downcase }
    end

    def overdue_project_rows
      rows = overdue_work_packages.group_by(&:project_id).map do |project_id, items|
        project_deadline_row(project_id, items, overdue: true)
      end

      rows.sort_by { |row| [-row[:days], row[:project].name.downcase] }
    end

    def due_soon_project_rows
      rows = due_soon_work_packages.group_by(&:project_id).map do |project_id, items|
        project_deadline_row(project_id, items, overdue: false)
      end

      rows.sort_by { |row| [row[:days], row[:project].name.downcase] }
    end

    def project_graph_data
      {
        nodes: project_graph_nodes,
        links: project_graph_links
      }
    end

    def project_calendar_heatmap_data
      {
        year: Date.current.year,
        entries: project_calendar_entries
      }
    end

    private

    def visible_work_packages
      project_ids = projects.map(&:id)
      return [] if project_ids.empty?

      WorkPackage
        .visible(user)
        .where(project_id: project_ids)
        .includes(:project, :status, :type, :assigned_to, :responsible)
        .to_a
    end

    def project_calendar_entries
      work_packages_by_project = work_packages.group_by(&:project_id)

      projects.filter_map do |project|
        items = work_packages_by_project[project.id] || []
        due_dates = items.filter_map(&:due_date).select { |date| date.year == Date.current.year }
        next if due_dates.empty?

        calendar_entry_for(project, items, due_dates.min)
      end
    end

    def calendar_entry_for(project, work_packages_for_project, date)
      status = calendar_status_for(project, work_packages_for_project)

      {
        date: date.iso8601,
        project: project.name,
        status:,
        status_label: I18n.t("homescreen.project_calendar.statuses.#{status}"),
        url: Rails.application.routes.url_helpers.project_path(project)
      }
    end

    def calendar_status_for(project, work_packages_for_project)
      return :completed if calendar_project_completed?(project, work_packages_for_project)
      return :overdue if work_packages_for_project.any? { |work_package| overdue?(work_package) }

      :on_track
    end

    def calendar_project_completed?(project, work_packages_for_project)
      project.finished? ||
        (work_packages_for_project.any? && work_packages_for_project.all? { |work_package| work_package.status.is_closed? })
    end

    def project_graph_nodes
      grouped_work_packages = work_packages.group_by(&:project_id)

      projects.map do |project|
        project_work_packages = grouped_work_packages[project.id] || []
        open_count = project_work_packages.count { |work_package| !work_package.status.is_closed? }
        closed_count = project_work_packages.size - open_count

        {
          id: project.id,
          name: project.name,
          workspace_type: project.workspace_type,
          workspace_label: project.workspace_label,
          status: project_status_label(project),
          area: area_for(project).name,
          parent_id: project.parent_id,
          work_packages: project_work_packages.size,
          open_work_packages: open_count,
          closed_work_packages: closed_count,
          completion: percentage(closed_count, project_work_packages.size)
        }
      end
    end

    def project_graph_links
      (project_hierarchy_links + shared_kpi_links)
        .uniq { |link| [link[:source], link[:target], link[:kind]] }
    end

    def project_hierarchy_links
      projects.filter_map do |project|
        next if project.parent_id.blank? || !projects_by_id.key?(project.parent_id)

        {
          source: project.parent_id,
          target: project.id,
          kind: "hierarchy",
          label: I18n.t("homescreen.project_graph.relations.hierarchy")
        }
      end
    end

    def shared_kpi_links
      kpis_with_visible_projects.flat_map do |kpi|
        visible_kpi_project_ids(kpi).combination(2).map do |source_id, target_id|
          {
            source: source_id,
            target: target_id,
            kind: "kpi",
            label: I18n.t("homescreen.project_graph.relations.kpi", name: kpi.name)
          }
        end
      end
    end

    def kpis_with_visible_projects
      project_ids = projects.select { |project| user.allowed_in_project?(:view_kpis, project) }.map(&:id)
      return Kpi.none if project_ids.empty?

      Kpi
        .left_outer_joins(:projects)
        .where(project_id: project_ids)
        .or(Kpi.left_outer_joins(:projects).where(projects: { id: project_ids }))
        .includes(:project, :projects)
        .distinct
    end

    def visible_kpi_project_ids(kpi)
      ([kpi.project_id] + kpi.projects.map(&:id))
        .select { |project_id| projects_by_id.key?(project_id) }
        .uniq
        .sort
    end

    def projects_by_id
      @projects_by_id ||= projects.index_by(&:id)
    end

    def areas
      @areas ||= projects.map { |project| area_for(project) }.uniq
    end

    def members_by_project
      @members_by_project ||= Member
        .where(project_id: projects.map(&:id))
        .includes(:principal, :roles)
        .to_a
        .group_by(&:project_id)
    end

    def project_responsibles(project)
      (members_by_project[project.id] || [])
        .filter_map { |member| member.principal if member.roles.any? { it.permissions.include?(:edit_project) } }
        .uniq
        .sort_by { it.name.downcase }
    end

    def project_row(project, items)
      return if items.empty?

      open = items.count { |work_package| !work_package.status.is_closed? }
      closed = items.size - open
      overdue = items.count { |work_package| overdue?(work_package) }

      {
        project:,
        area: area_for(project),
        total: items.size,
        open:,
        closed:,
        overdue:,
        completion: percentage(closed, items.size)
      }
    end

    def group_project_by_responsible(grouped, project)
      responsibles = project_responsibles(project)
      responsibles = [nil] if responsibles.empty?
      responsibles.each { |responsible| grouped[responsible] << project }
    end

    def responsibility_row(responsible, responsible_projects)
      {
        responsible:,
        label: responsible&.name || I18n.t("homescreen.project_overview.details.unassigned"),
        projects: responsible_projects.sort_by { it.name.downcase },
        count: responsible_projects.size
      }
    end

    def area_project_status_row(area, area_projects)
      {
        area:,
        total: area_projects.size,
        statuses: distribution_hash(area_projects) { project_status_label(it) }
      }
    end

    def area_work_package_status_row(area, area_work_packages)
      {
        area:,
        total: area_work_packages.size,
        statuses: distribution_hash(area_work_packages) { it.status.name }
      }
    end

    def project_deadline_row(project_id, items, overdue:)
      due_date = items.filter_map(&:due_date).min
      project = projects_by_id.fetch(project_id)

      {
        project:,
        area: area_for(project),
        due_date:,
        days: overdue ? (Date.current - due_date).to_i : (due_date - Date.current).to_i,
        work_packages: items.size
      }
    end

    def area_for(project)
      current = project

      while current.parent_id.present? && projects_by_id[current.parent_id].present?
        current = projects_by_id[current.parent_id]
      end

      current
    end

    def open_work_packages
      @open_work_packages ||= work_packages.reject { |work_package| work_package.status.is_closed? }
    end

    def closed_work_packages
      @closed_work_packages ||= work_packages.select { |work_package| work_package.status.is_closed? }
    end

    def overdue_work_packages
      @overdue_work_packages ||= open_work_packages.select { |work_package| overdue?(work_package) }
    end

    def due_soon_work_packages
      @due_soon_work_packages ||= open_work_packages.select do |work_package|
        work_package.due_date.present? &&
          work_package.due_date >= Date.current &&
          work_package.due_date <= SOON_DAYS.days.from_now.to_date
      end
    end

    def unassigned_work_packages
      @unassigned_work_packages ||= open_work_packages.select { |work_package| work_package.assigned_to_id.blank? }
    end

    def overdue?(work_package)
      work_package.due_date.present? && work_package.due_date < Date.current && !work_package.status.is_closed?
    end

    def project_completion_percentage
      percentage(completed_project_rows.size, projects.size)
    end

    def percentage(part, total)
      return 0 if total.zero?

      ((part.to_f / total) * 100).round
    end

    def distribution_for(attribute)
      work_packages
        .group_by(&attribute)
        .map { |record, items| overview_entry(record.name, items.size) }
        .sort_by { |entry| [-entry[:count], entry[:label].downcase] }
    end

    def overview_entry(label, count, project_path_id: nil)
      {
        label:,
        count:,
        percentage: percentage(count, work_packages.size),
        project_path_id:
      }
    end

    def distribution_hash(records)
      records
        .group_by { yield(it) }
        .transform_values(&:size)
        .sort_by { |label, count| [-count, label.downcase] }
        .to_h
    end

    def project_status_label(project)
      return I18n.t("homescreen.project_overview.details.status_not_set") if project.status_code.blank?

      I18n.t("activerecord.attributes.project.status_codes.#{project.status_code}")
    end
  end
end
