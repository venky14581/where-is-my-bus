import { useEffect, useRef } from 'react';
import { BarController, BarElement, CategoryScale, Chart, Legend, LinearScale, Tooltip } from 'chart.js';

Chart.register(BarController, BarElement, CategoryScale, LinearScale, Tooltip, Legend);

export interface BarSeries {
  label: string;
  values: number[];
  colour: string;
}

/** A bar chart; [stacked] stacks the series in each bar. */
export function BarChart({ labels, series, stacked = false, yTitle, label }: {
  labels: string[];
  series: BarSeries[];
  stacked?: boolean;
  yTitle: string;
  /** For screen readers: what the chart shows. The tables next to it hold the numbers. */
  label: string;
}) {
  const canvas = useRef<HTMLCanvasElement>(null);
  useEffect(() => {
    if (!canvas.current) return;
    const text = getComputedStyle(document.documentElement).getPropertyValue('--muted').trim() || '#6b5c60';
    const grid = getComputedStyle(document.documentElement).getPropertyValue('--border').trim() || '#e4d9db';
    const chart = new Chart(canvas.current, {
      type: 'bar',
      data: {
        labels,
        datasets: series.map((s) => ({ label: s.label, data: s.values, backgroundColor: s.colour, borderRadius: 4, maxBarThickness: 48 })),
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: false,
        plugins: { legend: { display: series.length > 1, labels: { color: text } } },
        scales: {
          x: { stacked, ticks: { color: text }, grid: { display: false } },
          y: { stacked, beginAtZero: true, ticks: { color: text }, grid: { color: grid }, title: { display: true, text: yTitle, color: text } },
        },
      },
    });
    return () => chart.destroy();
  }, [labels, series, stacked, yTitle]);
  return (
    <div className="chart-frame">
      <canvas ref={canvas} role="img" aria-label={label} />
    </div>
  );
}
