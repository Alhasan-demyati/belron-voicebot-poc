"use client";
import {
  BarChart,
  Bar,
  LineChart,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  Legend,
  ResponsiveContainer,
  CartesianGrid,
} from "recharts";
import { useMemo } from "react";

const UC_COLORS: Record<number, string> = {
  1: "#2563eb",
  2: "#10b981",
  3: "#f59e0b",
  4: "#a855f7",
};

export function CesCharts({
  weekly,
  distribution,
}: {
  weekly: any[];
  distribution: any[];
}) {
  const weeklyChart = useMemo(() => {
    // pivot week × use_case into a chart-ready shape
    const byWeek = new Map<string, any>();
    for (const r of weekly) {
      const key = r.week;
      if (!byWeek.has(key)) byWeek.set(key, { week: key });
      byWeek.get(key)[`uc${r.use_case}`] = parseFloat(r.avg_ces);
    }
    return Array.from(byWeek.values()).sort((a, b) => a.week.localeCompare(b.week));
  }, [weekly]);

  const distChart = useMemo(() => {
    // bins 1..10, total across all UCs
    const bins = Array.from({ length: 10 }, (_, i) => ({ score: i + 1, count: 0 }));
    for (const r of distribution) {
      bins[r.ces_score - 1].count += r.count;
    }
    return bins;
  }, [distribution]);

  return (
    <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
      <div>
        <h3 className="mb-2 text-sm text-neutral-500">Verteilung CES 1–10</h3>
        <ResponsiveContainer width="100%" height={260}>
          <BarChart data={distChart}>
            <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
            <XAxis dataKey="score" tick={{ fontSize: 11 }} />
            <YAxis tick={{ fontSize: 11 }} />
            <Tooltip />
            <Bar dataKey="count" fill="#2563eb" radius={[4, 4, 0, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </div>

      <div>
        <h3 className="mb-2 text-sm text-neutral-500">Ø CES pro Woche, je UC</h3>
        <ResponsiveContainer width="100%" height={260}>
          <LineChart data={weeklyChart}>
            <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
            <XAxis dataKey="week" tick={{ fontSize: 10 }} />
            <YAxis domain={[0, 10]} tick={{ fontSize: 11 }} />
            <Tooltip />
            <Legend />
            {[1, 2, 3, 4].map((uc) => (
              <Line
                key={uc}
                dataKey={`uc${uc}`}
                stroke={UC_COLORS[uc]}
                strokeWidth={2}
                dot={{ r: 3 }}
                connectNulls
                name={`UC${uc}`}
              />
            ))}
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
