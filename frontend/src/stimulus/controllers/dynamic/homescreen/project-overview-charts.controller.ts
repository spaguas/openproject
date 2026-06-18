import { Controller } from '@hotwired/stimulus';
import type { Chart as ChartInstance, ChartConfiguration, TooltipItem } from 'chart.js';

interface DashboardDataset {
  label?:string;
  data:number[];
  rawData?:number[];
  backgroundColor:string|string[];
}

interface DashboardChartConfig {
  type:'bar'|'doughnut';
  indexAxis?:'x'|'y';
  stacked?:boolean;
  percentage?:boolean;
  suffix?:string;
  labels:string[];
  datasets:DashboardDataset[];
}

export default class ProjectOverviewChartsController extends Controller {
  private readonly charts = new Map<string, ChartInstance>();

  async render({ params: { key } }:{ params:{ key:string } }) {
    await this.nextFrame();

    const canvas = this.chartCanvas(key);
    if (!canvas) {
      return;
    }

    const config = JSON.parse(canvas.dataset.chartConfig ?? '{}') as DashboardChartConfig;
    const container = canvas.closest<HTMLElement>('.homescreen-project-overview--chart-container');
    const hasData = config.datasets.some((dataset) => dataset.data.some((value) => value > 0));

    if (container) {
      container.hidden = !hasData;
    }
    if (!hasData) {
      return;
    }

    const { Chart, registerables } = await import('chart.js');
    Chart.register(...registerables);

    this.charts.get(key)?.destroy();
    this.charts.set(
      key,
      new Chart(
        canvas,
        this.chartConfiguration(config) as ChartConfiguration
      )
    );
  }

  disconnect() {
    this.charts.forEach((chart) => chart.destroy());
    this.charts.clear();
  }

  private chartCanvas(key:string):HTMLCanvasElement|null {
    return Array
      .from(this.element.querySelectorAll<HTMLCanvasElement>('canvas[data-chart-key]'))
      .find((canvas) => canvas.dataset.chartKey === key) ?? null;
  }

  private chartConfiguration(config:DashboardChartConfig) {
    return {
      type: config.type,
      data: {
        labels: config.labels,
        datasets: config.datasets,
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        indexAxis: config.indexAxis,
        animation: window.matchMedia('(prefers-reduced-motion: reduce)').matches
          ? false
          : { duration: 250 },
        plugins: {
          legend: {
            display: config.type === 'doughnut' || config.datasets.length > 1,
            position: 'bottom',
          },
          tooltip: {
            callbacks: {
              label: (item:TooltipItem<'bar'|'doughnut'>) => this.tooltipLabel(item, config),
            },
          },
        },
        scales: config.type === 'bar'
          ? {
            x: {
              beginAtZero: true,
              stacked: config.stacked,
              max: config.percentage ? 100 : undefined,
              ticks: {
                callback: config.percentage
                  ? (value:string|number) => `${value}%`
                  : undefined,
              },
            },
            y: {
              stacked: config.stacked,
              ticks: {
                autoSkip: false,
              },
            },
          }
          : undefined,
      },
    };
  }

  private tooltipLabel(item:TooltipItem<'bar'|'doughnut'>, config:DashboardChartConfig):string {
    const dataset = config.datasets[item.datasetIndex];
    const label = dataset.label ? `${dataset.label}: ` : '';

    if (config.percentage) {
      const count = dataset.rawData?.[item.dataIndex] ?? 0;
      const percentage = typeof item.raw === 'number' ? item.raw : 0;
      return `${label}${count} (${percentage}%)`;
    }

    const value = typeof item.raw === 'number' ? item.raw : 0;
    return `${label}${value}${config.suffix ? ` ${config.suffix}` : ''}`;
  }

  private nextFrame():Promise<void> {
    return new Promise((resolve) => {
      requestAnimationFrame(() => requestAnimationFrame(() => resolve()));
    });
  }
}
