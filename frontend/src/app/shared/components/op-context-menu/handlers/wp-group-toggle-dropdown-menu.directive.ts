//-- copyright
// OpenProject is an open source project management software.
// Copyright (C) the OpenProject GmbH
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License version 3.
//
// OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
// Copyright (C) 2006-2013 Jean-Philippe Lang
// Copyright (C) 2010-2013 the ChiliProject Team
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// as published by the Free Software Foundation; either version 2
// of the License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program; if not, write to the Free Software
// Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
//
// See COPYRIGHT and LICENSE files for more details.
//++

import { Directive, inject } from '@angular/core';
import { OpContextMenuTrigger } from 'core-app/shared/components/op-context-menu/handlers/op-context-menu-trigger.directive';
import { I18nService } from 'core-app/core/i18n/i18n.service';
import { WorkPackageViewCollapsedGroupsService } from 'core-app/features/work-packages/routing/wp-view-base/view-services/wp-view-collapsed-groups.service';
import { IsolatedQuerySpace } from 'core-app/features/work-packages/directives/query-space/isolated-query-space';
import { States } from 'core-app/core/states/states.service';
import { WorkPackageViewHierarchiesService } from 'core-app/features/work-packages/routing/wp-view-base/view-services/wp-view-hierarchy.service';

@Directive({
  selector: '[wpGroupToggleDropdown]',
  standalone: false,
})
export class WorkPackageGroupToggleDropdownMenuDirective extends OpContextMenuTrigger {
  readonly I18n = inject(I18nService);
  readonly wpViewCollapsedGroups = inject(WorkPackageViewCollapsedGroupsService);
  readonly querySpace = inject(IsolatedQuerySpace);
  readonly states = inject(States);
  readonly wpTableHierarchies = inject(WorkPackageViewHierarchiesService);

  protected open(evt:Event) {
    this.buildItems();
    this.opContextMenu.show(this, evt);
  }

  public get locals() {
    return {
      items: this.items,
      contextMenuId: 'wp-group-fold-context-menu',
    };
  }

  private buildItems() {
    const hierarchyParentIds = this.visibleHierarchyParentIds();

    this.items = [];

    if (this.wpViewCollapsedGroups.currentGroupedBy) {
      this.items.push({
        disabled: this.wpViewCollapsedGroups.allGroupsAreCollapsed,
        linkText: this.I18n.t('js.button_collapse_all'),
        icon: 'icon-minus2',
        onClick: () => {
          this.wpViewCollapsedGroups.setAllGroupsCollapseStateTo(true);

          return true;
        },
      });

      this.items.push({
        disabled: this.wpViewCollapsedGroups.allGroupsAreExpanded,
        linkText: this.I18n.t('js.button_expand_all'),
        icon: 'icon-plus',
        onClick: () => {
          this.wpViewCollapsedGroups.setAllGroupsCollapseStateTo(false);

          return true;
        },
      });
    }

    if (this.wpTableHierarchies.isEnabled && hierarchyParentIds.length > 0) {
      this.items.push({
        disabled: hierarchyParentIds.every((id) => this.wpTableHierarchies.collapsed(id)),
        linkText: this.I18n.t('js.work_packages.hierarchy.collapse_all'),
        icon: 'icon-minus2',
        onClick: () => {
          this.wpTableHierarchies.setAll(hierarchyParentIds, true);

          return true;
        },
      });

      this.items.push({
        disabled: hierarchyParentIds.every((id) => !this.wpTableHierarchies.collapsed(id)),
        linkText: this.I18n.t('js.work_packages.hierarchy.expand_all'),
        icon: 'icon-plus',
        onClick: () => {
          this.wpTableHierarchies.setAll(hierarchyParentIds, false);

          return true;
        },
      });
    }
  }

  private visibleHierarchyParentIds():string[] {
    const parentIds = new Set<string>();
    const renderedIds = this.querySpace.renderedWorkPackageIds.value || [];

    renderedIds.forEach((id) => {
      const workPackage = this.states.workPackages.get(id).value;

      workPackage?.getAncestors().forEach((ancestor) => {
        parentIds.add(ancestor.id!);
      });
    });

    return Array.from(parentIds);
  }
}
