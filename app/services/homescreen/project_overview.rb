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
        overdue: overdue_work_packages.size,
        due_soon: due_soon_work_packages.size,
        unassigned: unassigned_work_packages.size,
        completion: completion_percentage
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

      projects.filter_map do |project|
        items = grouped[project.id] || []
        next if items.empty?

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
      end.sort_by { |row| [-row[:overdue], -row[:open], row[:project].name.downcase] }.first(10)
    end

    def recent_work_packages
      work_packages
        .sort_by(&:updated_at)
        .reverse
        .first(8)
    end

    private

    def visible_work_packages
      project_ids = projects.map(&:id)
      return [] if project_ids.empty?

      WorkPackage
        .visible(user)
        .where(project_id: project_ids)
        .includes(:project, :status, :type, :assigned_to)
        .to_a
    end

    def projects_by_id
      @projects_by_id ||= projects.index_by(&:id)
    end

    def areas
      @areas ||= projects.map { |project| area_for(project) }.uniq
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

    def completion_percentage
      percentage(closed_work_packages.size, work_packages.size)
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
  end
end
