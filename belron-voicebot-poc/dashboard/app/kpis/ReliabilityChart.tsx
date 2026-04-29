"use client";
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  Legend,
  ResponsiveContainer,
  CartesianGrid,
  ReferenceLine,
} from "recharts";
import { useMemo } from "react";

export function ReliabilityChart({ data }: { data: any[] }) {
  const chart = useMemo(() => {
    const byDay = new Map<string, any>();
    for (const r of data) {
      const key = r.day;
      if (!byDay.has(key)) byDay.set(key, { day: key });
      byDay.get(key)[r.integration] = parseFloat(r.success_rate_pct);
    }
    return Array.from(byDay.values()).sort((a, b) => a.day.localeCompare(b.day));
  }, [data]);

  const integrations = Array.from(
    new Set(data.map((r) => r.integration))
  );

  const colors: Record<string, string> = {
    crm: "#2563eb",
    booking: "#10b981",
    elevenlabs: "#f59e0b",
    n8n: "#a855f7",
    telephony: "#ef4444",
    other: "#6b7280",
  };

  return (
    <ResponsiveContainer width="100%" height={260}>
      <LineChart data={chart}>
        <CartesianGrid strokeDasharray="3 3" stroke="#e5e7eb" />
        <XAxis dataKey="day" tick={{ fontSize: 10 }} />
        <YAxis domain={[90, 100]} tick={{ fontSize: 11 }} unit="%" />
        <Tooltip />
        <Legend />
        <ReferenceLine y={99} stroke="#10b981" strokeDasharray="4 4" label={{ value: "Ziel 99%", fontSize: 10, fill: "#10b981" }} />
        {integrations.map((i) => (
          <Line
            key={i}
            dataKey={i}
            stroke={colors[i] ?? "#6b7280"}
            strokeWidth={2}
            dot={{ r: 2 }}
            connectNulls
            name={i}
          />
        ))}
      </LineChart>
    </ResponsiveContainer>
  );
}
