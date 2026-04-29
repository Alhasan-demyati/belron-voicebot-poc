import { unstable_cache } from "next/cache";
import { createCachedClient } from "@/lib/supabase/server";

const POC_TARGETS: Record<number, number> = { 1: 70, 2: 80, 3: 40, 4: 50 };
const ABANDONMENT_BENCHMARK = 8.7; // current Carla figure from POC briefing
const RELIABILITY_TARGET = 99.0;

export type OverviewKpis = {
  liveCalls: number;
  totalCalls: number;
  overallAutomationPct: number | null;
  overallAbandonmentPct: number | null;
  qualifiedHandoverPct: number | null;
  avgCesOverall: number | null;
  cesCapturePct: number | null;
  integrationReliability7dPct: number | null;
  abandonmentBenchmark: number;
  reliabilityTarget: number;
};

async function fetchOverviewKpisRaw(): Promise<OverviewKpis> {
  const sb = await createCachedClient();
  const { data, error } = await sb.from("kpi_overview").select("*").limit(1).single();

  if (error || !data) {
    return {
      liveCalls: 0,
      totalCalls: 0,
      overallAutomationPct: null,
      overallAbandonmentPct: null,
      qualifiedHandoverPct: null,
      avgCesOverall: null,
      cesCapturePct: null,
      integrationReliability7dPct: null,
      abandonmentBenchmark: ABANDONMENT_BENCHMARK,
      reliabilityTarget: RELIABILITY_TARGET,
    };
  }

  return {
    liveCalls: data.live_calls ?? 0,
    totalCalls: data.total_calls_with_outcome ?? 0,
    overallAutomationPct: data.overall_automation_pct,
    overallAbandonmentPct: data.overall_abandonment_pct,
    qualifiedHandoverPct: data.qualified_handover_pct,
    avgCesOverall: data.avg_ces_overall,
    cesCapturePct: data.ces_capture_pct,
    integrationReliability7dPct: data.integration_reliability_7d_pct,
    abandonmentBenchmark: ABANDONMENT_BENCHMARK,
    reliabilityTarget: RELIABILITY_TARGET,
  };
}

export const fetchOverviewKpis = unstable_cache(
  fetchOverviewKpisRaw,
  ["kpi-overview"],
  { revalidate: 30, tags: ["kpis"] }
);

export type AutomationByUseCaseRow = {
  use_case: number;
  total_calls: number;
  automated_calls: number;
  automation_rate_pct: number | null;
  handover_calls: number;
  abandoned_calls: number;
  target_pct: number;
};

async function fetchAutomationByUseCaseRaw(): Promise<AutomationByUseCaseRow[]> {
  const sb = await createCachedClient();
  const { data } = await sb.from("kpi_automation_by_usecase").select("*");
  if (!data) return [];
  return data.map((r: any) => ({
    use_case: r.use_case,
    total_calls: r.total_calls,
    automated_calls: r.automated_calls,
    automation_rate_pct: r.automation_rate_pct,
    handover_calls: r.handover_calls,
    abandoned_calls: r.abandoned_calls,
    target_pct: POC_TARGETS[r.use_case] ?? 0,
  }));
}

export const fetchAutomationByUseCase = unstable_cache(
  fetchAutomationByUseCaseRaw,
  ["kpi-automation-by-usecase"],
  { revalidate: 30, tags: ["kpis"] }
);

export const fetchCesDistribution = unstable_cache(
  async () => {
    const sb = await createCachedClient();
    const { data } = await sb.from("kpi_ces_distribution").select("*");
    return data ?? [];
  },
  ["kpi-ces-distribution"],
  { revalidate: 60, tags: ["kpis"] }
);

export const fetchCesAvgWeekly = unstable_cache(
  async () => {
    const sb = await createCachedClient();
    const { data } = await sb
      .from("kpi_ces_avg_by_usecase")
      .select("*")
      .order("week", { ascending: true });
    return data ?? [];
  },
  ["kpi-ces-avg-weekly"],
  { revalidate: 60, tags: ["kpis"] }
);

export const fetchAhtDistribution = unstable_cache(
  async () => {
    const sb = await createCachedClient();
    const { data } = await sb.from("kpi_aht_distribution").select("*");
    return data ?? [];
  },
  ["kpi-aht-distribution"],
  { revalidate: 60, tags: ["kpis"] }
);

export const fetchHandoverQuality = unstable_cache(
  async () => {
    const sb = await createCachedClient();
    const { data } = await sb.from("kpi_handover_quality").select("*");
    return data ?? [];
  },
  ["kpi-handover-quality"],
  { revalidate: 60, tags: ["kpis"] }
);

export const fetchAbandonmentFunnel = unstable_cache(
  async () => {
    const sb = await createCachedClient();
    const { data } = await sb.from("kpi_abandonment_funnel").select("*");
    return data ?? [];
  },
  ["kpi-abandonment-funnel"],
  { revalidate: 60, tags: ["kpis"] }
);

export const fetchIntegrationReliability = unstable_cache(
  async (days = 14) => {
    const sb = await createCachedClient();
    const { data } = await sb
      .from("kpi_integration_reliability")
      .select("*")
      .order("day", { ascending: false })
      .limit(days * 4);
    return (data ?? []).reverse();
  },
  ["kpi-integration-reliability"],
  { revalidate: 60, tags: ["kpis"] }
);

export const POC_TARGETS_PUBLIC = POC_TARGETS;
