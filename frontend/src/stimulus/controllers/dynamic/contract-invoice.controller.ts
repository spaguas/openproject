import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['grossAmount', 'taxPercentage', 'netAmount'];

  declare readonly grossAmountTarget:HTMLInputElement;
  declare readonly taxPercentageTarget:HTMLInputElement;
  declare readonly netAmountTarget:HTMLInputElement;

  connect():void {
    this.calculate();
  }

  calculate():void {
    const grossAmount = this.numberValue(this.grossAmountTarget.value);
    const taxPercentage = this.numberValue(this.taxPercentageTarget.value);

    if (grossAmount === null || taxPercentage === null) {
      this.netAmountTarget.value = '';
      return;
    }

    const netAmount = grossAmount * (1 - taxPercentage / 100);
    this.netAmountTarget.value = netAmount.toFixed(2);
  }

  private numberValue(value:string):number|null {
    if (value.trim() === '') {
      return null;
    }

    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
}
