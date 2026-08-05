import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['mode', 'total', 'fiscalYear', 'month', 'period', 'startMonth', 'endMonth'];

  declare readonly modeTargets:HTMLInputElement[];
  declare readonly totalTarget:HTMLInputElement;
  declare readonly fiscalYearTarget:HTMLInputElement;
  declare readonly monthTargets:HTMLInputElement[];
  declare readonly periodTarget:HTMLElement;
  declare readonly startMonthTarget:HTMLSelectElement;
  declare readonly endMonthTarget:HTMLSelectElement;
  connect() {
    this.applyMode();
  }

  changeMode() {
    this.applyMode();
  }

  recalculate() {
    if (this.automatic) {
      this.distributeAutomatically();
    }
  }

  sumMonths() {
    if (!this.automatic) {
      const total = this.monthTargets.reduce((sum, input) => sum + this.numberValue(input.value), 0);
      this.totalTarget.value = total.toFixed(2);
    }
  }

  private applyMode() {
    this.totalTarget.readOnly = !this.automatic;
    this.monthTargets.forEach((input) => {
      input.readOnly = this.automatic;
    });
    this.periodTarget.hidden = !this.automatic;
    this.startMonthTarget.disabled = !this.automatic;
    this.endMonthTarget.disabled = !this.automatic;

    if (this.automatic) {
      this.distributeAutomatically();
    } else {
      this.sumMonths();
    }
  }

  private distributeAutomatically() {
    const total = this.numberValue(this.totalTarget.value);
    const months = this.applicableMonths();

    this.monthTargets.forEach((input) => {
      input.value = '0.00';
    });
    if (total <= 0 || months.length === 0) return;

    const totalInCents = Math.round(total * 100);
    const baseInCents = Math.floor(totalInCents / months.length);
    let remainder = totalInCents - (baseInCents * months.length);

    months.forEach((month) => {
      const input = this.monthTargets.find((candidate) => Number(candidate.dataset.month) === month);
      if (!input) return;

      const cents = baseInCents + (remainder > 0 ? 1 : 0);
      remainder = Math.max(remainder - 1, 0);
      input.value = (cents / 100).toFixed(2);
    });
  }

  private applicableMonths():number[] {
    const year = Number(this.fiscalYearTarget.value);
    if (!year) return [];

    const first = Number(this.startMonthTarget.value);
    const last = Number(this.endMonthTarget.value);
    if (first > last) return [];

    return Array.from({ length: last - first + 1 }, (_, index) => first + index);
  }

  private get automatic():boolean {
    return this.modeTargets.find((input) => input.checked)?.value === 'automatic';
  }

  private numberValue(value:string):number {
    const parsed = Number(value.replace(',', '.'));
    return Number.isFinite(parsed) ? parsed : 0;
  }
}
