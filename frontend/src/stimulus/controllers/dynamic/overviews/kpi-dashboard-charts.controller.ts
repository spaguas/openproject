import { Controller } from '@hotwired/stimulus';
import type { Chart as ChartInstance, ChartConfiguration } from 'chart.js';

interface KpiChartDataset {
  label?:string;
  data:(number|null)[];
  backgroundColor?:string|string[];
  borderColor?:string;
}

interface KpiChartConfig {
  type:'doughnut'|'line';
  labels:string[];
  datasets:KpiChartDataset[];
}

export default class KpiDashboardChartsController extends Controller {
  static targets = ['chart'];

  declare readonly chartTargets:HTMLCanvasElement[];

  private readonly charts:ChartInstance[] = [];

  connect() {
    void this.renderCharts();
  }

  private async renderCharts() {
    const { Chart, registerables } = await import('chart.js');
    Chart.register(...registerables);

    this.chartTargets.forEach((canvas) => {
      const config = JSON.parse(canvas.dataset.chartConfig ?? '{}') as KpiChartConfig;
      if (!config.datasets.some((dataset) => dataset.data.some((value) => value !== null && value > 0))) {
        return;
      }

      this.charts.push(new Chart(canvas, this.chartConfiguration(config) as ChartConfiguration));
    });
  }

  disconnect() {
    this.charts.forEach((chart) => chart.destroy());
  }

  private chartConfiguration(config:KpiChartConfig) {
    const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    return {
      type: config.type,
      data: {
        labels: config.labels,
        datasets: config.datasets.map((dataset) => ({
          ...dataset,
          borderWidth: config.type === 'line' ? 2 : 0,
          pointRadius: config.type === 'line' ? 3 : undefined,
          tension: config.type === 'line' ? 0.25 : undefined,
          spanGaps: false,
        })),
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: reducedMotion ? false : { duration: 250 },
        plugins: {
          legend: {
            position: config.type === 'doughnut' ? 'right' : 'bottom',
            labels: {
              boxWidth: 10,
              usePointStyle: true,
            },
          },
          tooltip: {
            callbacks: {
              label: (item:{ dataset:{ label?:string }; formattedValue:string }) => {
                const label = item.dataset.label ? `${item.dataset.label}: ` : '';
                return `${label}${item.formattedValue}${config.type === 'line' ? '%' : ''}`;
              },
            },
          },
        },
        scales: config.type === 'line'
          ? {
            x: {
              grid: { display: false },
            },
            y: {
              beginAtZero: true,
              max: 100,
              ticks: {
                callback: (value:string|number) => `${value}%`,
              },
            },
          }
          : undefined,
      },
    };
  }
}
