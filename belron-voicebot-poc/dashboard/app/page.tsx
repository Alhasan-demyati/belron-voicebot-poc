import { Card, KpiCard } from "@/components/Card";
import { PageHeader } from "@/components/PageHeader";
import { RefreshButton } from "@/components/RefreshButton";
import { T } from "@/lib/i18n/LanguageProvider";
import { TranslationKey } from "@/lib/i18n/dictionary";
import { fetchKpiOverviewLive, fetchAutomationByUseCaseLive } from "@/lib/queries";

export const dynamic = "force-dynamic";

const ABANDONMENT_BENCHMARK = 8.7;
const RELIABILITY_TARGET = 99.0;
const POC_TARGETS: Record<number, number> = { 1: 70, 2: 80, 3: 40, 4: 50, 5: 60 };
const UC_KEYS: Record<number, TranslationKey> = {
  1: "uc.1", 2: "uc.2", 3: "uc.3", 4: "uc.4", 5: "uc.5",
};

function automationStatus(actual: number | null, target: number) {
  if (actual == null) return "neutral" as const;
  if (actual >= target) return "good" as const;
  if (actual >= target * 0.8) return "warn" as const;
  return "bad" as const;
}

export default async function OverviewPage() {
  const [o, byUC] = await Promise.all([
    fetchKpiOverviewLive(),
    fetchAutomationByUseCaseLive(),
  ]);

  return (
    <div className="space-y-6 p-6">
      <PageHeader
        titleKey="overview.title"
        subtitleKey="overview.subtitle"
        right={<RefreshButton />}
      />

      <section className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-4">
        <KpiCard
          labelKey="kpi.automationTotal"
          value={o?.overall_automation_pct != null ? `${o.overall_automation_pct}%` : "—"}
          subText={`${o?.total_calls_with_outcome ?? 0}`}
          subKey="kpi.calls"
          status={o?.overall_automation_pct != null
            ? o.overall_automation_pct >= 60 ? "good"
              : o.overall_automation_pct >= 40 ? "warn" : "bad"
            : "neutral"}
        />
        <KpiCard
          labelKey="kpi.abandonment"
          value={o?.overall_abandonment_pct != null ? `${o.overall_abandonment_pct}%` : "—"}
          subKey="kpi.benchmark"
          subText={`: ${ABANDONMENT_BENCHMARK}%`}
          status={o?.overall_abandonment_pct != null
            ? o.overall_abandonment_pct < ABANDONMENT_BENCHMARK ? "good" : "warn"
            : "neutral"}
        />
        <KpiCard
          labelKey="kpi.qualifiedHandover"
          value={o?.qualified_handover_pct != null ? `${o.qualified_handover_pct}%` : "—"}
          subKey="kpi.qualifiedHandoverSub"
          status={o?.qualified_handover_pct != null && o.qualified_handover_pct >= 80 ? "good" : "warn"}
        />
        <KpiCard
          labelKey="kpi.reliability7d"
          value={o?.integration_reliability_7d_pct != null ? `${o.integration_reliability_7d_pct}%` : "—"}
          target={`${RELIABILITY_TARGET}%`}
          status={o?.integration_reliability_7d_pct != null
            ? o.integration_reliability_7d_pct >= RELIABILITY_TARGET ? "good" : "bad"
            : "neutral"}
        />
        <KpiCard
          labelKey="kpi.cesAvg"
          value={o?.avg_ces_overall != null ? Number(o.avg_ces_overall).toFixed(2) : "—"}
          subKey="kpi.cesAvgSub"
          status={o?.avg_ces_overall != null
            ? o.avg_ces_overall >= 8 ? "good"
              : o.avg_ces_overall >= 6 ? "warn" : "bad"
            : "neutral"}
        />
        <KpiCard
          labelKey="kpi.cesCapture"
          value={o?.ces_capture_pct != null ? `${o.ces_capture_pct}%` : "—"}
          subKey="kpi.cesCaptureSub"
          status={o?.ces_capture_pct != null && o.ces_capture_pct >= 70 ? "good" : "warn"}
        />
      </section>

      <section>
        <h2 className="mb-3 text-lg font-semibold">
          <T k="overview.byUseCase" />
        </h2>
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2 xl:grid-cols-5">
          {[1, 2, 3, 4, 5].map((uc) => {
            const row = byUC.find((r: any) => r.use_case === uc);
            const target = POC_TARGETS[uc];
            const actual = row?.automation_rate_pct ?? null;
            const status = automationStatus(actual, target);
            return (
              <Card key={uc}>
                <div className="text-xs uppercase tracking-wide text-neutral-500">
                  <T k={UC_KEYS[uc]} />
                </div>
                <div className="mt-2 flex items-end gap-2">
                  <div className={`text-3xl font-semibold ${
                    actual == null ? "text-neutral-400" :
                    status === "good" ? "text-emerald-600" :
                    status === "warn" ? "text-amber-600" : "text-red-600"
                  }`}>
                    {actual != null ? `${actual}%` : "—"}
                  </div>
                  <div className="pb-1 text-sm text-neutral-500">
                    / <T k="kpi.target" /> {target}%
                  </div>
                </div>
                <div className="mt-3 h-2 w-full overflow-hidden rounded-full bg-neutral-100 dark:bg-neutral-800">
                  <div
                    className={`h-full ${
                      actual != null && actual >= target ? "bg-emerald-500" :
                      actual != null && actual >= target * 0.8 ? "bg-amber-500" : "bg-red-500"
                    }`}
                    style={{ width: `${Math.min(100, actual ?? 0)}%` }}
                  />
                </div>
                <div className="mt-3 grid grid-cols-3 gap-2 text-xs text-neutral-500">
                  <div><T k="kpi.total" />: <span className="text-neutral-900 dark:text-neutral-100">{row?.total_calls ?? 0}</span></div>
                  <div><T k="kpi.auto" />: <span className="text-neutral-900 dark:text-neutral-100">{row?.automated_calls ?? 0}</span></div>
                  <div><T k="kpi.handover" />: <span className="text-neutral-900 dark:text-neutral-100">{row?.handover_calls ?? 0}</span></div>
                </div>
              </Card>
            );
          })}
        </div>
      </section>
    </div>
  );
}
