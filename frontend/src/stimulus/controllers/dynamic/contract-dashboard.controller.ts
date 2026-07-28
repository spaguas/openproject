import { ActionEvent, Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['dialog', 'dialogTitle', 'dialogContent', 'template'];

  declare readonly dialogTarget:HTMLDialogElement;
  declare readonly dialogTitleTarget:HTMLElement;
  declare readonly dialogContentTarget:HTMLElement;
  declare readonly templateTargets:HTMLTemplateElement[];

  open(event:ActionEvent):void {
    const key = String(event.params.key);
    const title = String(event.params.title);
    const template = this.templateTargets.find((candidate) => candidate.dataset.detailKey === key);

    if (!template) {
      return;
    }

    this.dialogTitleTarget.textContent = title;
    this.dialogContentTarget.replaceChildren(template.content.cloneNode(true));
    this.dialogTarget.showModal();
  }

  close(event?:Event):void {
    event?.preventDefault();
    this.dialogTarget.close();
  }

  closeFromBackdrop(event:MouseEvent):void {
    if (event.target === this.dialogTarget) {
      this.close(event);
    }
  }
}
