import { ActionEvent, Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['tab', 'panel', 'badge'];

  declare readonly tabTargets:HTMLButtonElement[];
  declare readonly panelTargets:HTMLElement[];
  declare readonly badgeTargets:HTMLElement[];
  private revealingInvalid = false;

  connect():void {
    const panelWithMarkedField = this.panelTargets.find((panel) =>
      panel.querySelector('.form--field.-error, .field_with_errors, [aria-invalid="true"]'),
    );
    const invalidBadge = this.badgeTargets.find((badge) => Number(badge.dataset.serverErrorCount ?? 0) > 0);
    const invalidPanel = panelWithMarkedField ?? this.panelTargets.find((panel) =>
      panel.dataset.contractFormTabsPanel === invalidBadge?.dataset.contractFormTabsBadge,
    );
    const requestedSection = window.location.hash.replace(/^#/, '');
    const requestedPanel = this.panelTargets.find((panel) => panel.dataset.contractFormTabsPanel === requestedSection);
    this.activate(
      invalidPanel?.dataset.contractFormTabsPanel
      ?? requestedPanel?.dataset.contractFormTabsPanel
      ?? this.tabTargets[0]?.dataset.contractFormTabsTab,
    );
    this.refresh();
  }

  select(event:ActionEvent):void {
    this.activate(String(event.params.tab));
  }

  navigate(event:KeyboardEvent):void {
    const currentIndex = this.tabTargets.indexOf(event.currentTarget as HTMLButtonElement);
    let nextIndex:number|undefined;

    if (event.key === 'ArrowRight') nextIndex = (currentIndex + 1) % this.tabTargets.length;
    if (event.key === 'ArrowLeft') nextIndex = (currentIndex - 1 + this.tabTargets.length) % this.tabTargets.length;
    if (event.key === 'Home') nextIndex = 0;
    if (event.key === 'End') nextIndex = this.tabTargets.length - 1;
    if (nextIndex === undefined) return;

    event.preventDefault();
    const tab = this.tabTargets[nextIndex];
    this.activate(tab.dataset.contractFormTabsTab);
    tab.focus();
  }

  revealInvalid(event:Event):void {
    if (this.revealingInvalid) return;

    const panel = (event.target as HTMLElement).closest<HTMLElement>('[data-contract-form-tabs-panel]');
    if (!panel) return;

    this.revealingInvalid = true;
    this.activate(panel.dataset.contractFormTabsPanel);
    this.refresh();
    requestAnimationFrame(() => { this.revealingInvalid = false; });
  }

  refresh():void {
    this.panelTargets.forEach((panel) => {
      const controls = Array.from(panel.querySelectorAll<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement>(
        'input:not([type="hidden"]), select, textarea',
      )).filter((control) => !control.disabled);
      const pendingFields = new Set<HTMLElement>();

      controls.filter((control) => !control.validity.valid)
        .forEach((control) => pendingFields.add(control.closest<HTMLElement>('.form--field') ?? control));
      panel.querySelectorAll<HTMLElement>('.form--field.-error, .field_with_errors, [aria-invalid="true"]')
        .forEach((element) => pendingFields.add(element.closest<HTMLElement>('.form--field') ?? element));

      this.updateBadge(panel.dataset.contractFormTabsPanel, pendingFields.size);
    });
  }

  private activate(name:string|undefined):void {
    if (!name) return;

    this.tabTargets.forEach((tab) => {
      const selected = tab.dataset.contractFormTabsTab === name;
      tab.setAttribute('aria-selected', String(selected));
      tab.tabIndex = selected ? 0 : -1;
    });
    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.contractFormTabsPanel !== name;
    });
  }

  private updateBadge(section:string|undefined, count:number):void {
    const badge = this.badgeTargets.find((candidate) => candidate.dataset.contractFormTabsBadge === section);
    if (!badge) return;

    count = Math.max(count, Number(badge.dataset.serverErrorCount ?? 0));
    badge.hidden = count === 0;
    const countTarget = badge.querySelector<HTMLElement>('[data-badge-count]');
    if (countTarget) countTarget.textContent = String(count);
    const template = count === 1
      ? this.element.getAttribute('data-contract-form-tabs-alert-one')
      : this.element.getAttribute('data-contract-form-tabs-alert-other');
    const label = template?.replace('__COUNT__', String(count)) ?? String(count);
    const labelTarget = badge.querySelector<HTMLElement>('[data-badge-label]');
    if (labelTarget) labelTarget.textContent = label;
  }
}
