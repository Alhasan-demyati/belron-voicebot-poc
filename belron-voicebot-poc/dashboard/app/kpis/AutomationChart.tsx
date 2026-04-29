"use client";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  Legend,
  ResponsiveContainer,
  CartesianGrid,
  ReferenceLine,
} from "recharts";

export function AutomationChart({ data }: { data: any[] }) {
  const chart = data.map((r) => ({
    label: `UC${r.use_case}`,
    actual: r.automation_rate_pct ?? 0,
    target: r.target_pct ?? 0,
  }));

  return (
    <ResponsiveContainer width="100%" height={300}>
      <BarChart data={chart}>
        <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
        <XAxis dataKey="label" tick={{ fontSize: 11 }} />
        <YAxis domain={[0, 100]} tick={{ fontSize: 11 }} unit="%" />
        <Tooltip />
        <Legend />
        <ReferenceLine y={50} stroke="#94a3b8" strokeDasharray="3 3" />
        <Bar dataKey="target" fill="#cbd5e1" name="Ziel %" radius={[4, 4, 0, 0]} />
        <Bar dataKey="actual" fill="#2563eb" name="Ist %" radius={[4, 4, 0, 0]} />
      </BarChart>
    </ResponsiveContainer>
  );
}
