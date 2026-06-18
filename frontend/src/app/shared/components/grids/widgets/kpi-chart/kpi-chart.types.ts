export type KpiChartMetric = 'progress'|'current'|'target';
export type KpiChartType = 'horizontal_bar'|'vertical_bar';

export interface KpiChartItem {
  id:number;
  name:string;
  category:string|null;
  currentValue:number;
  targetValue:number;
  progress:number;
  unit:string|null;
  status:string;
  href:string;
}

export interface KpiChartResponse {
  kpis:KpiChartItem[];
}
