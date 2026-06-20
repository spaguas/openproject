import { Controller } from '@hotwired/stimulus';
import type { Chart as ChartInstance, ChartConfiguration } from 'chart.js';

interface BudgetChartDataset {
  label:string;
  data:number[];
  backgroundColor:string;
  stack?:string;
}

interface BudgetChartConfig {
  type:'bar';
  labels:string[];
  datasets:BudgetChartDataset[];
}

export default class BudgetDashboardChartsController extends Controller {
  static targets = ['chart'];

  declare readonly chartTargets:HTMLCanvasElement[];

  private readonly charts:ChartInstance[] = [];

  connect() {
    void this.renderCharts();
  }

  disconnect() {
    this.charts.forEach((chart) => chart.destroy());
  }

  private async renderCharts() {
    const { Chart, registerables } = await import('chart.js');
    Chart.register(...registerables);

    this.chartTargets.forEach((canvas) => {
      const config = JSON.parse(canvas.dataset.chartConfig ?? '{}') as BudgetChartConfig;
      this.charts.push(new Chart(canvas, this.configuration(config) as ChartConfiguration));
    });
  }

  private configuration(config:BudgetChartConfig) {
    const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const isComparison = config.datasets.every((dataset) => dataset.stack === undefined);
    const currency = new Intl.NumberFormat(document.documentElement.lang || 'pt-BR', {
      style: 'currency',
      currency: this.currencyCode(),
      maximumFractionDigits: 0,
    });

    return {
      type: 'bar',
      data: {
        labels: config.labels,
        datasets: config.datasets,
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        indexAxis: isComparison ? 'y' : 'x',
        animation: reducedMotion ? false : { duration: 250 },
        plugins: {
          legend: {
            position: 'bottom',
            labels: { boxWidth: 10, usePointStyle: true },
          },
          tooltip: {
            callbacks: {
              label: (item:{ dataset:{ label?:string }; raw:unknown }) =>
                `${item.dataset.label}: ${currency.format(Number(item.raw))}`,
            },
          },
        },
        scales: {
          x: {
            type: isComparison ? 'linear' : 'category',
            beginAtZero: isComparison,
            stacked: !isComparison,
            grid: { display: isComparison },
            ticks: isComparison ? {
              callback: (value:string|number) => this.compactCurrency(Number(value)),
            } : undefined,
          },
          y: {
            type: isComparison ? 'category' : 'linear',
            beginAtZero: !isComparison,
            stacked: !isComparison,
            grid: { display: false },
            ticks: isComparison
              ? {
                callback: (value:string|number) => config.labels[Number(value)] ?? String(value),
              }
              : {
                callback: (value:string|number) => this.compactCurrency(Number(value)),
              },
          },
        },
      },
    };
  }

  private compactCurrency(value:number) {
    return new Intl.NumberFormat(document.documentElement.lang || 'pt-BR', {
      notation: 'compact',
      maximumFractionDigits: 1,
    }).format(value);
  }

  private currencyCode() {
    return document.documentElement.lang === 'pt-BR' ? 'BRL' : 'EUR';
  }
}
