import { Controller } from '@hotwired/stimulus';

const ECHARTS_URL = '/vendor/echarts/echarts.min.js';

interface EChartsInstance {
  setOption(option:Record<string, unknown>):void;
  on(eventName:string, handler:(params:unknown) => void):void;
  resize():void;
  dispose():void;
}

interface EChartsNamespace {
  init(element:HTMLElement):EChartsInstance;
}

type WindowWithECharts = Window & {
  echarts?:EChartsNamespace;
};

interface ProjectInsightGraphNode {
  id:string;
  name:string;
  category:number;
  symbolSize:number;
  value:number;
  itemStyle?:Record<string, string>;
  detail:{
    type:string;
    status:string;
    date?:string;
    url:string;
  };
}

interface ProjectInsightGraphLink {
  source:string;
  target:string;
  name:string;
}

interface ProjectInsightGraphConfig {
  labels:{
    empty:string;
    type:string;
    status:string;
    date:string;
  };
  categories:{ name:string }[];
  nodes:ProjectInsightGraphNode[];
  links:ProjectInsightGraphLink[];
}

interface ProjectInsightCalendarItem {
  name:string;
  kind:string;
  status:string;
  status_label:string;
  url:string;
}

interface ProjectInsightCalendarEntry {
  date:string;
  value:number;
  status:string;
  status_label:string;
  color:string;
  count:number;
  items:ProjectInsightCalendarItem[];
}

interface ProjectInsightCalendarConfig {
  year:number;
  labels:{
    empty:string;
    items:string;
    status:string;
  };
  entries:ProjectInsightCalendarEntry[];
}

export default class ProjectInsightsController extends Controller {
  static targets = ['graph', 'calendar'];
  static values = {
    graphConfig: Object,
    calendarConfig: Object,
  };

  declare readonly graphTarget:HTMLElement;
  declare readonly calendarTarget:HTMLElement;
  declare readonly hasGraphTarget:boolean;
  declare readonly hasCalendarTarget:boolean;
  declare readonly hasGraphConfigValue:boolean;
  declare readonly hasCalendarConfigValue:boolean;
  declare readonly graphConfigValue:ProjectInsightGraphConfig;
  declare readonly calendarConfigValue:ProjectInsightCalendarConfig;

  private graphChart:EChartsInstance|null = null;
  private calendarChart:EChartsInstance|null = null;
  private graphResizeObserver:ResizeObserver|null = null;
  private calendarResizeObserver:ResizeObserver|null = null;

  connect() {
    if (this.hasGraphTarget && this.hasGraphConfigValue) {
      void this.renderGraph();
    }

    if (this.hasCalendarTarget && this.hasCalendarConfigValue) {
      void this.renderCalendar();
    }
  }

  disconnect() {
    this.graphResizeObserver?.disconnect();
    this.calendarResizeObserver?.disconnect();
    this.graphChart?.dispose();
    this.calendarChart?.dispose();
    this.graphChart = null;
    this.calendarChart = null;
  }

  private async renderGraph() {
    if (this.graphConfigValue.nodes.length === 0) {
      this.graphTarget.textContent = this.graphConfigValue.labels.empty;
      return;
    }

    const echarts = await this.loadECharts();
    this.graphChart = echarts.init(this.graphTarget);
    this.graphChart.setOption(this.graphOption());
    this.graphChart.on('click', (params:unknown) => {
      const node = (params as { dataType?:string; data?:ProjectInsightGraphNode }).data;
      if ((params as { dataType?:string }).dataType === 'node' && node?.detail?.url) {
        window.location.href = node.detail.url;
      }
    });

    this.graphResizeObserver = new ResizeObserver(() => this.graphChart?.resize());
    this.graphResizeObserver.observe(this.graphTarget);
  }

  private graphOption():Record<string, unknown> {
    const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    return {
      animation: !reducedMotion,
      color: ['#8250df', '#1a7f37', '#0969da'],
      tooltip: {
        trigger: 'item',
        formatter: (params:unknown) => this.graphTooltip(params),
      },
      legend: {
        bottom: 0,
        data: this.graphConfigValue.categories.map((category) => category.name),
      },
      series: [
        {
          type: 'graph',
          layout: 'force',
          roam: true,
          draggable: true,
          categories: this.graphConfigValue.categories,
          data: this.graphConfigValue.nodes,
          links: this.graphConfigValue.links,
          force: {
            edgeLength: [70, 150],
            repulsion: 230,
            gravity: 0.08,
          },
          label: {
            show: true,
            formatter: '{b}',
            position: 'right',
            hideOverlap: true,
            color: '#24292f',
            fontSize: 12,
          },
          labelLayout: {
            hideOverlap: true,
          },
          lineStyle: {
            color: '#8c959f',
            curveness: 0.12,
            opacity: 0.72,
          },
          emphasis: {
            focus: 'adjacency',
          },
        },
      ],
    };
  }

  private graphTooltip(params:unknown):string {
    const item = params as { dataType?:string; data?:ProjectInsightGraphNode|ProjectInsightGraphLink };

    if (item.dataType === 'edge') {
      return this.escapeHtml((item.data as ProjectInsightGraphLink).name);
    }

    const node = item.data as ProjectInsightGraphNode | undefined;
    if (!node) {
      return '';
    }

    const rows = [
      `<strong>${this.escapeHtml(node.name)}</strong>`,
      `${this.escapeHtml(this.graphConfigValue.labels.type)}: ${this.escapeHtml(node.detail.type)}`,
      `${this.escapeHtml(this.graphConfigValue.labels.status)}: ${this.escapeHtml(node.detail.status)}`,
    ];

    if (node.detail.date) {
      const label = this.escapeHtml(this.graphConfigValue.labels.date);
      const date = this.escapeHtml(this.formattedDate(node.detail.date));
      rows.push(
        `${label}: ${date}`
      );
    }

    return rows.join('<br>');
  }

  private async renderCalendar() {
    if (this.calendarConfigValue.entries.length === 0) {
      this.calendarTarget.textContent = this.calendarConfigValue.labels.empty;
      return;
    }

    const echarts = await this.loadECharts();
    this.calendarChart = echarts.init(this.calendarTarget);
    this.calendarChart.setOption(this.calendarOption());
    this.calendarChart.on('click', (params:unknown) => {
      const entry = (params as { data?:{ entry?:ProjectInsightCalendarEntry } }).data?.entry;
      const firstItem = entry?.items[0];
      if (firstItem?.url) {
        window.location.href = firstItem.url;
      }
    });

    this.calendarResizeObserver = new ResizeObserver(() => this.calendarChart?.resize());
    this.calendarResizeObserver.observe(this.calendarTarget);
  }

  private calendarOption():Record<string, unknown> {
    const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    return {
      animation: !reducedMotion,
      tooltip: {
        trigger: 'item',
        formatter: (params:unknown) => this.calendarTooltip(params),
      },
      calendar: {
        top: 46,
        left: 44,
        right: 24,
        bottom: 24,
        range: String(this.calendarConfigValue.year),
        cellSize: ['auto', 18],
        itemStyle: {
          borderColor: '#d0d7de',
          borderWidth: 1,
        },
        splitLine: {
          show: true,
          lineStyle: {
            color: '#d0d7de',
            width: 1,
          },
        },
        yearLabel: {
          show: false,
        },
        dayLabel: {
          firstDay: 1,
        },
      },
      series: [
        {
          type: 'heatmap',
          coordinateSystem: 'calendar',
          data: this.calendarData(),
          emphasis: {
            itemStyle: {
              borderColor: '#24292f',
              borderWidth: 1.5,
            },
          },
        },
      ],
    };
  }

  private calendarData():Record<string, unknown>[] {
    return this.calendarConfigValue.entries.map((entry) => ({
      value: [entry.date, entry.value],
      itemStyle: {
        color: entry.color,
      },
      entry,
    }));
  }

  private calendarTooltip(params:unknown):string {
    const entry = (params as { data?:{ entry?:ProjectInsightCalendarEntry } }).data?.entry;

    if (!entry) {
      return this.escapeHtml(this.calendarConfigValue.labels.empty);
    }

    const items = entry.items
      .slice(0, 8)
      .map((item) => `${this.escapeHtml(item.name)} (${this.escapeHtml(item.status_label)})`);
    const remaining = entry.items.length - items.length;

    if (remaining > 0) {
      items.push(`+${remaining}`);
    }

    return [
      `<strong>${this.escapeHtml(this.formattedDate(entry.date))}</strong>`,
      `${this.escapeHtml(this.calendarConfigValue.labels.status)}: ${this.escapeHtml(entry.status_label)}`,
      `${this.escapeHtml(this.calendarConfigValue.labels.items)}: ${entry.count}`,
      items.join('<br>'),
    ].filter(Boolean).join('<br>');
  }

  private formattedDate(value:string):string {
    const date = new Date(`${value}T00:00:00`);

    return new Intl.DateTimeFormat(document.documentElement.lang || undefined, {
      dateStyle: 'medium',
    }).format(date);
  }

  private escapeHtml(value:string):string {
    const element = document.createElement('div');
    element.textContent = value;
    return element.innerHTML;
  }

  private async loadECharts():Promise<EChartsNamespace> {
    const echartsWindow = window as WindowWithECharts;

    if (echartsWindow.echarts) {
      return echartsWindow.echarts;
    }

    await new Promise<void>((resolve, reject) => {
      const existingScript = document.querySelector<HTMLScriptElement>(`script[src="${ECHARTS_URL}"]`);

      if (existingScript) {
        existingScript.addEventListener('load', () => resolve(), { once: true });
        existingScript.addEventListener(
          'error',
          () => reject(new Error('Unable to load Apache ECharts')),
          { once: true }
        );
        return;
      }

      const script = document.createElement('script');
      script.src = ECHARTS_URL;
      script.async = true;
      script.onload = () => resolve();
      script.onerror = () => reject(new Error('Unable to load Apache ECharts'));
      document.head.appendChild(script);
    });

    if (!echartsWindow.echarts) {
      throw new Error('Apache ECharts did not initialize');
    }

    return echartsWindow.echarts;
  }
}
