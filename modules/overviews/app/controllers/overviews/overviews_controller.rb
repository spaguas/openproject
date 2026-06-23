# frozen_string_literal: true

# -- copyright
# OpenProject is an open source project management software.
# Copyright (C) the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
# ++

module ::Overviews
  class OverviewsController < ::Grids::BaseInProjectController
    before_action :jump_to_project_menu_item, only: [:show] # rubocop:disable Rails/LexicallyScopedActionFilter
    before_action :ensure_budget_dashboard_permissions, only: :budget
    before_action :ensure_kpi_dashboard_permissions, only: :kpis

    menu_item :overview

    def project_custom_fields_sidebar
      render :project_custom_fields_sidebar, layout: false
    end

    def project_life_cycle_sidebar
      render :project_life_cycle_sidebar, layout: false
    end

    def kpis
      @kpi_dashboard = Overviews::KpiDashboard.new(
        project: @project,
        period: params[:period]
      ).call
    end

    def budget
      @budget_dashboard = Overviews::BudgetDashboard.new(
        project: @project,
        current_user:,
        period: params[:period]
      ).call
    end

    def team_allocation
      @team_allocation_dashboard = Overviews::TeamAllocationDashboard.new(
        project: @project,
        current_user:,
        period: params[:period]
      ).call
    end

    def jump_to_project_menu_item
      # try to redirect to the requested menu item
      redirect_to_project_menu_item(@project, params[:jump]) if params[:jump]
    end

    private

    def ensure_budget_dashboard_permissions
      allowed = Overviews::BudgetDashboard::REQUIRED_PERMISSIONS.all? do |permission|
        current_user.allowed_in_project?(permission, @project)
      end

      render_403 unless allowed
    end

    def ensure_kpi_dashboard_permissions
      allowed = current_user.allowed_in_project?(:view_kpis, @project) &&
        current_user.allowed_in_project?(:edit_project, @project)

      render_403 unless allowed
    end
  end
end
