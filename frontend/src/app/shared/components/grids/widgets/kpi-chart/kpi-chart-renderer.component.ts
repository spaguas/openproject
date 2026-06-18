import { ChangeDetectionStrategy, Component, computed, input } from '@angular/core';
import { ChartConfiguration, ChartData, TooltipItem } from 'chart.js';
import { BaseChartDirective, provideCharts, withDefaultRegisterables } from 'ng2-charts';
import { KpiChartItem, KpiChartMetric, KpiChartType } from './kpi-chart.types';

const STATUS_COLORS:Record<string, string> = {
  not_started: '#818b98',
  on_track: '#1a7f37',
  at_risk: '#bf8700',
  off_track: '#cf222e',
  achieved: '#0969da',
  paused: '#8250df',
};

@Component({
  selector: 'op-kpi-chart-renderer',
  template: `
    <canvas
      baseChart
      type="bar"
      [data]="chartData()"
      [options]="chartOptions()"
      [attr.aria-label]="accessibleDescription()"
      role="img">
    </canvas>
  `,
  imports: [BaseChartDirective],
  providers: [provideCharts(withDefaultRegisterables())],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class KpiChartRendererComponent {
  readonly kpis = input.required<KpiChartItem[]>();
  readonly metric = input.required<KpiChartMetric>();
  readonly chartType = input.required<KpiChartType>();
  readonly datasetLabel = input.required<string>();

  readonly chartData = computed<ChartData<'bar'>>(() => ({
    labels: this.kpis().map((kpi) => kpi.name),
    datasets: [{
      label: this.datasetLabel(),
      data: this.kpis().map((kpi) => this.metricValue(kpi)),
      backgroundColor: this.kpis().map((kpi) => STATUS_COLORS[kpi.status] || STATUS_COLORS.not_started),
      borderWidth: 0,
      borderRadius: 3,
    }],
  }));

  readonly chartOptions = computed<ChartConfiguration<'bar'>['options']>(() => ({
    responsive: true,
    maintainAspectRatio: false,
    indexAxis: this.chartType() === 'horizontal_bar' ? 'y' : 'x',
    animation: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? false : { duration: 250 },
    scales: {
      x: {
        beginAtZero: true,
        max: this.metric() === 'progress' && this.chartType() === 'horizontal_bar' ? 100 : undefined,
        ticks: {
          callback: this.metric() === 'progress' ? (value) => `${value}%` : undefined,
        },
      },
      y: {
        beginAtZero: true,
        max: this.metric() === 'progress' && this.chartType() === 'vertical_bar' ? 100 : undefined,
        ticks: {
          autoSkip: false,
          callback: this.metric() === 'progress' && this.chartType() === 'vertical_bar'
            ? (value) => `${value}%`
            : undefined,
        },
      },
    },
    plugins: {
      legend: {
        display: false,
      },
      tooltip: {
        callbacks: {
          label: (item) => this.tooltipLabel(item),
        },
      },
    },
  }));

  readonly accessibleDescription = computed(() =>
    this.kpis()
      .map((kpi) => `${kpi.name}: ${this.formattedValue(kpi)}`)
      .join('; '));

  private metricValue(kpi:KpiChartItem):number {
    if (this.metric() === 'current') {
      return kpi.currentValue;
    }
    if (this.metric() === 'target') {
      return kpi.targetValue;
    }
    return kpi.progress;
  }

  private tooltipLabel(item:TooltipItem<'bar'>):string {
    return this.formattedValue(this.kpis()[item.dataIndex]);
  }

  private formattedValue(kpi:KpiChartItem):string {
    const value = this.metricValue(kpi);

    if (this.metric() === 'progress') {
      return `${value}%`;
    }

    return kpi.unit ? `${value} ${kpi.unit}` : value.toString();
  }
}
