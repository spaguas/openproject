import { ChangeDetectionStrategy, ChangeDetectorRef, Component, OnInit, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { AbstractWidgetComponent } from 'core-app/shared/components/grids/widgets/abstract-widget.component';
import { CurrentProjectService } from 'core-app/core/current-project/current-project.service';
import { PathHelperService } from 'core-app/core/path-helper/path-helper.service';
import { GridAreaService } from 'core-app/shared/components/grids/grid/area.service';
import {
  KpiChartItem,
  KpiChartMetric,
  KpiChartResponse,
  KpiChartType,
} from './kpi-chart.types';

@Component({
  selector: 'op-kpi-chart-widget',
  templateUrl: './kpi-chart.component.html',
  styleUrls: ['./kpi-chart.component.sass'],
  changeDetection: ChangeDetectionStrategy.OnPush,
  standalone: false,
})
export class WidgetKpiChartComponent extends AbstractWidgetComponent implements OnInit {
  private readonly http = inject(HttpClient);
  private readonly currentProject = inject(CurrentProjectService);
  private readonly pathHelper = inject(PathHelperService);
  private readonly layout = inject(GridAreaService);
  private readonly cdr = inject(ChangeDetectorRef);

  kpis:KpiChartItem[] = [];
  loading = true;
  loadFailed = false;

  readonly metricOptions:KpiChartMetric[] = ['progress', 'current', 'target'];
  readonly chartTypeOptions:KpiChartType[] = ['horizontal_bar', 'vertical_bar'];

  readonly text = {
    configuration: this.i18n.t('js.grid.widgets.kpi_chart.configuration'),
    displayedKpis: this.i18n.t('js.grid.widgets.kpi_chart.displayed_kpis'),
    metric: this.i18n.t('js.grid.widgets.kpi_chart.metric'),
    chartType: this.i18n.t('js.grid.widgets.kpi_chart.chart_type'),
    loading: this.i18n.t('js.grid.widgets.kpi_chart.loading'),
    noResults: this.i18n.t('js.grid.widgets.kpi_chart.no_results'),
    loadFailed: this.i18n.t('js.grid.widgets.kpi_chart.load_failed'),
  };

  ngOnInit():void {
    const projectIdentifier = this.currentProject.identifier;
    if (!projectIdentifier) {
      this.loading = false;
      this.loadFailed = true;
      return;
    }

    this.http
      .get<KpiChartResponse>(this.pathHelper.projectKpiChartWidgetPath(projectIdentifier))
      .pipe(this.untilDestroyed())
      .subscribe({
        next: ({ kpis }) => {
          this.kpis = kpis;
          this.loading = false;
          this.cdr.detectChanges();
        },
        error: () => {
          this.loading = false;
          this.loadFailed = true;
          this.cdr.detectChanges();
        },
      });
  }

  get canConfigure():boolean {
    return this.layout.isEditable;
  }

  get metric():KpiChartMetric {
    return (this.resource.options.metric as KpiChartMetric) || 'progress';
  }

  get chartType():KpiChartType {
    return (this.resource.options.chartType as KpiChartType) || 'horizontal_bar';
  }

  get selectedKpiIds():number[] {
    const configured = (this.resource.options.kpiIds as number[] || []).map(Number);
    return configured.length > 0 ? configured : this.kpis.map((kpi) => kpi.id);
  }

  get selectedKpis():KpiChartItem[] {
    const selected = new Set(this.selectedKpiIds);
    return this.kpis.filter((kpi) => selected.has(kpi.id));
  }

  get datasetLabel():string {
    return this.i18n.t(`js.grid.widgets.kpi_chart.metrics.${this.metric}`);
  }

  isSelected(kpiId:number):boolean {
    return this.selectedKpiIds.includes(kpiId);
  }

  updateMetric(metric:KpiChartMetric):void {
    this.persistOptions({ metric });
  }

  updateChartType(chartType:KpiChartType):void {
    this.persistOptions({ chartType });
  }

  toggleKpi(kpiId:number, selected:boolean):void {
    const selectedIds = new Set(this.selectedKpiIds);
    if (selected) {
      selectedIds.add(kpiId);
    } else {
      selectedIds.delete(kpiId);
    }

    if (selectedIds.size === 0) {
      return;
    }

    this.persistOptions({ kpiIds: Array.from(selectedIds) });
  }

  formattedValue(kpi:KpiChartItem):string {
    if (this.metric === 'progress') {
      return `${kpi.progress}%`;
    }

    const value = this.metric === 'current' ? kpi.currentValue : kpi.targetValue;
    return kpi.unit ? `${value} ${kpi.unit}` : value.toString();
  }

  metricLabel(metric:KpiChartMetric):string {
    return this.i18n.t(`js.grid.widgets.kpi_chart.metrics.${metric}`);
  }

  chartTypeLabel(chartType:KpiChartType):string {
    return this.i18n.t(`js.grid.widgets.kpi_chart.chart_types.${chartType}`);
  }

  private persistOptions(options:Record<string, unknown>):void {
    this.resource.options = { ...this.resource.options, ...options };
    this.resourceChanged.emit(this.setChangesetOptions(options));
    this.cdr.detectChanges();
  }
}
