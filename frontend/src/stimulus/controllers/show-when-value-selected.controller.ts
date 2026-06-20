import { toggleElement, toggleElementByVisibility } from 'core-app/shared/helpers/dom-helpers';
import { ApplicationController } from 'stimulus-use';

export default class OpShowWhenValueSelectedController extends ApplicationController {
  static targets = ['cause', 'effect'];

  declare readonly effectTargets:HTMLInputElement[];

  private boundListener = this.toggleDisabled.bind(this);

  causeTargetConnected(target:HTMLElement) {
    target.addEventListener('change', this.boundListener);
  }

  causeTargetDisconnected(target:HTMLElement) {
    target.removeEventListener('change', this.boundListener);
  }

  private toggleDisabled(evt:Event):void {
    const input = evt.target as HTMLInputElement;
    const targetName = input.dataset.targetName;

    this
      .effectTargets
      .filter((el) => targetName === el.dataset.targetName)
      .forEach((el) => {
        const disabled = this.willDisable(el, input.value);
        el.disabled = disabled;
        this.toggleDescendantFields(el, disabled);

        if (el.dataset.setVisibility === 'true') {
          toggleElementByVisibility(el, !disabled);
        } else {
          toggleElement(el, !disabled);
        }
    });
  }

  private willDisable(el:HTMLElement, value:string):boolean {
    if (el.dataset.notValue) {
      return el.dataset.notValue === value;
    }

    return !(el.dataset.value === value);
  }

  private toggleDescendantFields(el:HTMLElement, disabled:boolean):void {
    if (el.dataset.disableDescendants !== 'true') {
      return;
    }

    el
      .querySelectorAll<HTMLInputElement | HTMLSelectElement | HTMLTextAreaElement | HTMLButtonElement>(
        'input, select, textarea, button',
      )
      .forEach((field) => {
        field.disabled = disabled;
      });
  }
}
