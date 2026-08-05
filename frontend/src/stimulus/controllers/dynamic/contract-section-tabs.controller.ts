import { ActionEvent, Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['tab', 'panel'];

  declare readonly tabTargets:HTMLButtonElement[];
  declare readonly panelTargets:HTMLElement[];

  connect():void {
    const requestedSection = window.location.hash.replace(/^#/, '');
    const initialSection = this.panelTargets.some((panel) => panel.dataset.contractSectionTabsPanel === requestedSection)
      ? requestedSection
      : this.tabTargets[0]?.dataset.contractSectionTabsTab;
    this.activate(initialSection);
  }

  select(event:ActionEvent):void {
    const section = String(event.params.tab);
    this.activate(section);
    window.history.replaceState(null, '', `#${section}`);
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
    this.activate(tab.dataset.contractSectionTabsTab);
    window.history.replaceState(null, '', `#${tab.dataset.contractSectionTabsTab}`);
    tab.focus();
  }

  private activate(section:string|undefined):void {
    if (!section) return;

    this.tabTargets.forEach((tab) => {
      const selected = tab.dataset.contractSectionTabsTab === section;
      tab.setAttribute('aria-selected', String(selected));
      tab.tabIndex = selected ? 0 : -1;
    });
    this.panelTargets.forEach((panel) => {
      panel.hidden = panel.dataset.contractSectionTabsPanel !== section;
    });
  }
}
