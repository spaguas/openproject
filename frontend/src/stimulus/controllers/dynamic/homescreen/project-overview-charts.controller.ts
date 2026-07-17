import { Controller } from '@hotwired/stimulus';
import type { Chart as ChartInstance, ChartConfiguration, TooltipItem } from 'chart.js';

const ECHARTS_URL = '/vendor/echarts/echarts.min.js';
const LEAFLET_URL = '/vendor/leaflet/leaflet.js';
const LEAFLET_CSS_URL = '/vendor/leaflet/leaflet.css';

interface EChartsInstance {
  setOption(option:Record<string, unknown>):void;
  on(eventName:string, handler:(params:unknown) => void):void;
  resize():void;
  dispose():void;
}

interface EChartsNamespace {
  init(element:HTMLElement):EChartsInstance;
}

interface LeafletLatLngBounds {
  isValid():boolean;
}

interface LeafletLayer {
  addTo(target:LeafletMap|LeafletLayer):LeafletLayer;
  bindPopup(content:string):LeafletLayer;
}

interface LeafletMap {
  setView(center:[number, number], zoom:number):LeafletMap;
  fitBounds(bounds:LeafletLatLngBounds, options?:Record<string, unknown>):LeafletMap;
  invalidateSize(options?:Record<string, unknown>):LeafletMap;
  remove():void;
}

interface LeafletNamespace {
  map(element:HTMLElement, options?:Record<string, unknown>):LeafletMap;
  tileLayer(url:string, options?:Record<string, unknown>):LeafletLayer;
  circleMarker(latLng:[number, number], options?:Record<string, unknown>):LeafletLayer;
  layerGroup(layers?:LeafletLayer[]):LeafletLayer;
  latLngBounds(latLngs:[number, number][]):LeafletLatLngBounds;
  control:{
    layers(
      baseLayers?:Record<string, LeafletLayer>,
      overlays?:Record<string, LeafletLayer>,
      options?:Record<string, unknown>
    ):LeafletLayer;
  };
}

declare global {
  interface Window {
    echarts?:EChartsNamespace;
    L?:LeafletNamespace;
  }
}

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

interface ProjectGraphLabels {
  empty:string;
  area:string;
  type:string;
  status:string;
  work_packages:string;
  open_work_packages:string;
  completion:string;
  open_project:string;
}

interface ProjectGraphCategory {
  name:string;
}

interface ProjectGraphDetail {
  name:string;
  workspace_label:string;
  status:string;
  area:string;
  work_packages:number;
  open_work_packages:number;
  completion:number;
  url:string;
}

interface ProjectGraphNode {
  id:string;
  name:string;
  category:number;
  value:number;
  symbolSize:number;
  detail:ProjectGraphDetail;
}

interface ProjectGraphLink {
  source:string;
  target:string;
  name:string;
  lineStyle:{
    color:string;
    type:'solid'|'dashed';
    width:number;
  };
}

interface ProjectGraphConfig {
  labels:ProjectGraphLabels;
  categories:ProjectGraphCategory[];
  nodes:ProjectGraphNode[];
  links:ProjectGraphLink[];
}

interface EChartsClickParams {
  dataType?:string;
  data?:ProjectGraphNode;
}

interface ProjectCalendarLegendItem {
  status:string;
  label:string;
  color:string;
  value:number;
}

interface ProjectCalendarProject {
  name:string;
  status:string;
  status_label:string;
  url:string;
}

interface ProjectCalendarEntry {
  date:string;
  value:number;
  status:string;
  status_label:string;
  color:string;
  count:number;
  projects:ProjectCalendarProject[];
}

interface ProjectCalendarLabels {
  empty:string;
  projects:string;
  status:string;
}

interface ProjectCalendarConfig {
  year:number;
  labels:ProjectCalendarLabels;
  legend:ProjectCalendarLegendItem[];
  entries:ProjectCalendarEntry[];
}

interface ProjectMapLabels {
  project_layer:string;
  work_package_layer:string;
  project:string;
  work_package:string;
  type:string;
  responsible:string;
  phase:string;
  progress:string;
  priority:string;
  status:string;
  georeferenced:string;
  fallback_location:string;
  georeferenced_yes:string;
  open:string;
}

interface ProjectMapLegendItem {
  label:string;
  color:string;
}

interface ProjectMapItem {
  id:number;
  kind:'project'|'work_package';
  title:string;
  project?:string;
  latitude:number;
  longitude:number;
  georeferenced:boolean;
  responsible:string;
  phase:string;
  progress:number;
  priority:string;
  status:string;
  status_key:'on_track'|'overdue'|'completed';
  url:string;
}

interface ProjectMapConfig {
  center:[number, number];
  labels:ProjectMapLabels;
  legend:Record<ProjectMapItem['status_key'], ProjectMapLegendItem>;
  projects:ProjectMapItem[];
  work_packages:ProjectMapItem[];
}

export default class ProjectOverviewChartsController extends Controller {
  static targets = ['graph', 'detail', 'calendar', 'map'];
  static values = {
    graphConfig: Object,
    calendarConfig: Object,
    mapConfig: Object,
  };

  declare readonly graphTarget:HTMLElement;
  declare readonly detailTarget:HTMLElement;
  declare readonly calendarTarget:HTMLElement;
  declare readonly mapTarget:HTMLElement;
  declare readonly hasGraphTarget:boolean;
  declare readonly hasDetailTarget:boolean;
  declare readonly hasCalendarTarget:boolean;
  declare readonly hasMapTarget:boolean;
  declare readonly hasGraphConfigValue:boolean;
  declare readonly hasCalendarConfigValue:boolean;
  declare readonly hasMapConfigValue:boolean;
  declare readonly graphConfigValue:ProjectGraphConfig;
  declare readonly calendarConfigValue:ProjectCalendarConfig;
  declare readonly mapConfigValue:ProjectMapConfig;

  private readonly charts = new Map<string, ChartInstance>();
  private graphChart:EChartsInstance|null = null;
  private graphResizeObserver:ResizeObserver|null = null;
  private calendarChart:EChartsInstance|null = null;
  private calendarResizeObserver:ResizeObserver|null = null;
  private projectMap:LeafletMap|null = null;
  private projectMapBounds:LeafletLatLngBounds|null = null;
  private projectMapResizeObserver:ResizeObserver|null = null;
  private projectMapResizeFrame:number|null = null;
  private projectMapInitialBoundsApplied = false;

  connect() {
    if (this.hasGraphTarget && this.hasGraphConfigValue) {
      void this.renderProjectGraph();
    }

    if (this.hasCalendarTarget && this.hasCalendarConfigValue) {
      void this.renderProjectCalendar();
    }

    if (this.hasMapTarget && this.hasMapConfigValue) {
      void this.renderProjectMap();
    }
  }

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
    this.graphResizeObserver?.disconnect();
    this.graphChart?.dispose();
    this.graphChart = null;
    this.calendarResizeObserver?.disconnect();
    this.calendarChart?.dispose();
    this.calendarChart = null;
    this.projectMapResizeObserver?.disconnect();
    this.projectMapResizeObserver = null;
    if (this.projectMapResizeFrame !== null) {
      cancelAnimationFrame(this.projectMapResizeFrame);
      this.projectMapResizeFrame = null;
    }
    this.projectMap?.remove();
    this.projectMap = null;
    this.projectMapBounds = null;
    this.projectMapInitialBoundsApplied = false;
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

  private async renderProjectGraph() {
    if (this.graphConfigValue.nodes.length === 0) {
      this.renderEmptyProjectDetail();
      return;
    }

    const echarts = await this.loadECharts();
    this.graphChart = echarts.init(this.graphTarget);
    this.graphChart.setOption(this.projectGraphOption());
    this.graphChart.on('click', (params:unknown) => {
      const clickParams = params as EChartsClickParams;

      if (clickParams.dataType === 'node' && clickParams.data) {
        this.renderProjectDetail(clickParams.data.detail);
      }
    });

    this.graphResizeObserver = new ResizeObserver(() => this.graphChart?.resize());
    this.graphResizeObserver.observe(this.graphTarget);
    this.renderProjectDetail(this.graphConfigValue.nodes[0].detail);
  }

  private async renderProjectCalendar() {
    const echarts = await this.loadECharts();
    this.calendarChart = echarts.init(this.calendarTarget);
    this.calendarChart.setOption(this.projectCalendarOption());

    this.calendarResizeObserver = new ResizeObserver(() => this.calendarChart?.resize());
    this.calendarResizeObserver.observe(this.calendarTarget);
  }

  private async renderProjectMap() {
    const leaflet = await this.loadLeaflet();
    const map = leaflet.map(this.mapTarget, {
      scrollWheelZoom: false,
    }).setView(this.mapConfigValue.center, 11);

    leaflet.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '&copy; OpenStreetMap contributors',
      maxZoom: 19,
    }).addTo(map);

    const projectMarkers = this.mapConfigValue.projects.map((item) => this.mapMarker(leaflet, item, 9));
    const workPackageMarkers = this.mapConfigValue.work_packages.map((item) => this.mapMarker(leaflet, item, 5));
    const projectLayer = leaflet.layerGroup(projectMarkers).addTo(map);
    const workPackageLayer = leaflet.layerGroup(workPackageMarkers).addTo(map);
    const bounds = leaflet.latLngBounds(
      [...this.mapConfigValue.projects, ...this.mapConfigValue.work_packages]
        .map((item) => [item.latitude, item.longitude] as [number, number])
    );

    leaflet.control.layers(
      undefined,
      {
        [this.mapConfigValue.labels.project_layer]: projectLayer,
        [this.mapConfigValue.labels.work_package_layer]: workPackageLayer,
      },
      { collapsed: false }
    ).addTo(map);

    this.projectMap = map;
    this.projectMapBounds = bounds;
    this.projectMapInitialBoundsApplied = false;
    this.observeProjectMapSize();
    this.refreshProjectMapSize();
  }

  private observeProjectMapSize() {
    this.projectMapResizeObserver?.disconnect();
    this.projectMapResizeObserver = new ResizeObserver(() => this.refreshProjectMapSize());
    this.projectMapResizeObserver.observe(this.mapTarget);
  }

  private refreshProjectMapSize() {
    if (!this.projectMap) {
      return;
    }

    if (this.projectMapResizeFrame !== null) {
      cancelAnimationFrame(this.projectMapResizeFrame);
    }

    this.projectMapResizeFrame = requestAnimationFrame(() => {
      this.projectMapResizeFrame = requestAnimationFrame(() => {
        this.projectMapResizeFrame = null;

        if (!this.projectMap || this.mapTarget.offsetWidth === 0 || this.mapTarget.offsetHeight === 0) {
          return;
        }

        this.projectMap.invalidateSize({ pan: false, debounceMoveend: true });

        if (!this.projectMapInitialBoundsApplied && this.projectMapBounds?.isValid()) {
          this.projectMap.fitBounds(this.projectMapBounds, { padding: [28, 28], maxZoom: 14 });
          this.projectMapInitialBoundsApplied = true;
        }
      });
    });
  }

  private mapMarker(leaflet:LeafletNamespace, item:ProjectMapItem, radius:number):LeafletLayer {
    const color = this.mapConfigValue.legend[item.status_key]?.color ?? '#57606a';
    return leaflet
      .circleMarker([item.latitude, item.longitude], {
        radius,
        color,
        weight: item.georeferenced ? 2 : 1,
        fillColor: color,
        fillOpacity: item.kind === 'project' ? 0.78 : 0.52,
        opacity: item.georeferenced ? 1 : 0.55,
      })
      .bindPopup(this.mapPopup(item));
  }

  private mapPopup(item:ProjectMapItem):string {
    const title = item.kind === 'work_package' && item.project
      ? `${item.project}: ${item.title}`
      : item.title;
    const typeLabel = item.kind === 'project'
      ? this.mapConfigValue.labels.project
      : this.mapConfigValue.labels.work_package;

    return `
      <div class="homescreen-project-overview--map-popup">
        <h4>${this.escapeHtml(title)}</h4>
        <dl>
          <dt>${this.escapeHtml(this.mapConfigValue.labels.type)}</dt>
          <dd>${this.escapeHtml(typeLabel)}</dd>
          <dt>${this.escapeHtml(this.mapConfigValue.labels.responsible)}</dt>
          <dd>${this.escapeHtml(item.responsible)}</dd>
          <dt>${this.escapeHtml(this.mapConfigValue.labels.phase)}</dt>
          <dd>${this.escapeHtml(item.phase)}</dd>
          <dt>${this.escapeHtml(this.mapConfigValue.labels.progress)}</dt>
          <dd>${item.progress}%</dd>
          <dt>${this.escapeHtml(this.mapConfigValue.labels.priority)}</dt>
          <dd>${this.escapeHtml(item.priority)}</dd>
          <dt>${this.escapeHtml(this.mapConfigValue.labels.status)}</dt>
          <dd>${this.escapeHtml(item.status)}</dd>
          <dt>${this.escapeHtml(this.mapConfigValue.labels.georeferenced)}</dt>
          <dd>${this.escapeHtml(item.georeferenced ? this.mapConfigValue.labels.georeferenced_yes : this.mapConfigValue.labels.fallback_location)}</dd>
        </dl>
        <a href="${this.escapeHtml(item.url)}">${this.escapeHtml(this.mapConfigValue.labels.open)}</a>
      </div>
    `;
  }

  private projectCalendarOption():Record<string, unknown> {
    const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    return {
      animation: !reducedMotion,
      tooltip: {
        trigger: 'item',
        formatter: (params:unknown) => this.projectCalendarTooltip(params),
      },
      calendar: {
        top: 54,
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
          data: this.projectCalendarData(),
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

  private projectCalendarData():Record<string, unknown>[] {
    if (this.calendarConfigValue.entries.length === 0) {
      return [];
    }

    return this.calendarConfigValue.entries.map((entry) => ({
      value: [entry.date, entry.value],
      itemStyle: {
        color: entry.color,
      },
      entry,
    }));
  }

  private projectCalendarTooltip(params:unknown):string {
    const item = params as { data?:{ entry?:ProjectCalendarEntry } };
    const entry = item.data?.entry;

    if (!entry) {
      return this.escapeHtml(this.calendarConfigValue.labels.empty);
    }

    const projects = entry.projects
      .slice(0, 8)
      .map((project) => `${this.escapeHtml(project.name)} (${this.escapeHtml(project.status_label)})`);
    const remaining = entry.projects.length - projects.length;

    if (remaining > 0) {
      projects.push(`+${remaining}`);
    }

    return [
      `<strong>${this.escapeHtml(this.formattedDate(entry.date))}</strong>`,
      `${this.escapeHtml(this.calendarConfigValue.labels.status)}: ${this.escapeHtml(entry.status_label)}`,
      `${this.escapeHtml(this.calendarConfigValue.labels.projects)}: ${entry.count}`,
      projects.join('<br>'),
    ].filter(Boolean).join('<br>');
  }

  private formattedDate(value:string):string {
    const date = new Date(`${value}T00:00:00`);

    return new Intl.DateTimeFormat(document.documentElement.lang || undefined, {
      dateStyle: 'medium',
    }).format(date);
  }

  private projectGraphOption():Record<string, unknown> {
    const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    return {
      animation: !reducedMotion,
      color: ['#8250df', '#0969da', '#1a7f37'],
      tooltip: {
        trigger: 'item',
        formatter: (params:unknown) => this.projectGraphTooltip(params),
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
            edgeLength: [80, 170],
            repulsion: 260,
            gravity: 0.08,
          },
          label: {
            show: true,
            position: 'right',
            formatter: '{b}',
            hideOverlap: true,
            color: '#24292f',
            fontSize: 12,
          },
          labelLayout: {
            hideOverlap: true,
          },
          edgeLabel: {
            show: false,
          },
          lineStyle: {
            curveness: 0.12,
            opacity: 0.72,
          },
          emphasis: {
            focus: 'adjacency',
            lineStyle: {
              width: 3,
              opacity: 1,
            },
          },
        },
      ],
    };
  }

  private projectGraphTooltip(params:unknown):string {
    const item = params as { dataType?:string; data?:ProjectGraphNode|ProjectGraphLink };

    if (item.dataType === 'edge') {
      return this.escapeHtml((item.data as ProjectGraphLink).name);
    }

    const detail = (item.data as ProjectGraphNode | undefined)?.detail;
    if (!detail) {
      return '';
    }

    return [
      `<strong>${this.escapeHtml(detail.name)}</strong>`,
      `${this.escapeHtml(this.graphConfigValue.labels.type)}: ${this.escapeHtml(detail.workspace_label)}`,
      `${this.escapeHtml(this.graphConfigValue.labels.status)}: ${this.escapeHtml(detail.status)}`,
      `${this.escapeHtml(this.graphConfigValue.labels.work_packages)}: ${detail.work_packages}`,
    ].join('<br>');
  }

  private renderProjectDetail(detail:ProjectGraphDetail) {
    if (!this.hasDetailTarget) {
      return;
    }

    this.detailTarget.replaceChildren(
      this.elementFor('h4', detail.name),
      this.definitionList(detail),
      this.projectLink(detail)
    );
  }

  private renderEmptyProjectDetail() {
    if (!this.hasDetailTarget) {
      return;
    }

    this.detailTarget.replaceChildren(
      this.elementFor('p', this.graphConfigValue.labels.empty, 'homescreen-project-overview--graph-empty')
    );
  }

  private definitionList(detail:ProjectGraphDetail):HTMLDListElement {
    const dl = document.createElement('dl');
    [
      [this.graphConfigValue.labels.type, detail.workspace_label],
      [this.graphConfigValue.labels.area, detail.area],
      [this.graphConfigValue.labels.status, detail.status],
      [this.graphConfigValue.labels.work_packages, String(detail.work_packages)],
      [this.graphConfigValue.labels.open_work_packages, String(detail.open_work_packages)],
      [this.graphConfigValue.labels.completion, `${detail.completion}%`],
    ].forEach(([label, value]) => {
      dl.append(
        this.elementFor('dt', label),
        this.elementFor('dd', value)
      );
    });

    return dl;
  }

  private projectLink(detail:ProjectGraphDetail):HTMLAnchorElement {
    const link = document.createElement('a');
    link.href = detail.url;
    link.className = 'button -highlight';
    link.textContent = this.graphConfigValue.labels.open_project;
    return link;
  }

  private elementFor<K extends keyof HTMLElementTagNameMap>(
    tagName:K,
    text:string,
    className?:string
  ):HTMLElementTagNameMap[K] {
    const element = document.createElement(tagName);
    element.textContent = text;
    if (className) {
      element.className = className;
    }

    return element;
  }

  private escapeHtml(value:string):string {
    const element = document.createElement('div');
    element.textContent = value;
    return element.innerHTML;
  }

  private async loadECharts():Promise<EChartsNamespace> {
    if (window.echarts) {
      return window.echarts;
    }

    await new Promise<void>((resolve, reject) => {
      const existingScript = document.querySelector<HTMLScriptElement>(`script[src="${ECHARTS_URL}"]`);

      if (existingScript) {
        existingScript.addEventListener('load', () => resolve(), { once: true });
        existingScript.addEventListener('error', () => reject(new Error('Unable to load Apache ECharts')), { once: true });
        return;
      }

      const script = document.createElement('script');
      script.src = ECHARTS_URL;
      script.async = true;
      script.onload = () => resolve();
      script.onerror = () => reject(new Error('Unable to load Apache ECharts'));
      document.head.appendChild(script);
    });

    if (!window.echarts) {
      throw new Error('Apache ECharts did not initialize');
    }

    return window.echarts;
  }

  private async loadLeaflet():Promise<LeafletNamespace> {
    this.loadStylesheet(LEAFLET_CSS_URL);

    if (window.L) {
      return window.L;
    }

    await new Promise<void>((resolve, reject) => {
      const existingScript = document.querySelector<HTMLScriptElement>(`script[src="${LEAFLET_URL}"]`);

      if (existingScript) {
        existingScript.addEventListener('load', () => resolve(), { once: true });
        existingScript.addEventListener('error', () => reject(new Error('Unable to load Leaflet')), { once: true });
        return;
      }

      const script = document.createElement('script');
      script.src = LEAFLET_URL;
      script.async = true;
      script.onload = () => resolve();
      script.onerror = () => reject(new Error('Unable to load Leaflet'));
      document.head.appendChild(script);
    });

    if (!window.L) {
      throw new Error('Leaflet did not initialize');
    }

    return window.L;
  }

  private loadStylesheet(href:string):void {
    if (document.querySelector(`link[href="${href}"]`)) {
      return;
    }

    const link = document.createElement('link');
    link.rel = 'stylesheet';
    link.href = href;
    document.head.appendChild(link);
  }
}
