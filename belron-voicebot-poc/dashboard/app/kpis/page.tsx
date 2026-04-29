import { Suspense } from "react";
import { Card } from "@/components/Card";
import { PageHeader } from "@/components/PageHeader";
import { RefreshButton } from "@/components/RefreshButton";
import { ChartSkeleton, TableSkeleton } from "@/components/Skeleton";
import { T } from "@/lib/i18n/LanguageProvider";
import { TranslationKey } from "@/lib/i18n/dictionary";
import {
  fetchAutomationByUseCase,
  fetchCesAvgWeekly,
  fetchCesDistribution,
  fetchAhtDistribution,
  fetchHandoverQuality,
  fetchAbandonmentFunnel,
  fetchIntegrationReliability,
} from "@/lib/kpis";
import { CesCharts } from "./CesCharts";
import { AutomationChart } from "./AutomationChart";
import { ReliabilityChart } from "./ReliabilityChart";

export const revalidate = 60;

async function AutomationCard() {
  const data = await fetchAutomationByUseCase();
  return (
    <Card>
      <h2 className="mb-3 text-lg font-semibold"><T k="kpis.section.automation" /></h2>
      <AutomationChart data={data} />
    </Card>
  );
}

async function CesCard() {
  const [weekly, distribution] = await Promise.all([fetchCesAvgWeekly(), fetchCesDistribution()]);
  return (
    <Card>
      <h2 className="mb-3 text-lg font-semibold"><T k="kpis.section.ces" /></h2>
      <CesCharts weekly={weekly} distribution={distribution} />
    </Card>
  );
}

async function AhtCard() {
  const aht = await fetchAhtDistribution();
  return (
    <Card>
      <h2 className="mb-3 text-lg font-semibold"><T k="kpis.section.aht" /></h2>
      <table className="w-full text-sm">
        <thead className="text-left text-xs uppercase tracking-wide text-neutral-500">
          <tr>
            <th className="py-2"><T k="common.uc" /></th>
            <th className="py-2"><T k="kpis.col.samples" /></th>
            <th className="py-2"><T k="kpis.col.avg" /></th>
            <th className="py-2">p50</th>
            <th className="py-2">p90</th>
            <th className="py-2">p99</th>
          </tr>
        </thead>
        <tbody>
          {aht.length === 0 && (
            <tr><td colSpan={6} className="py-3 text-center text-neutral-500 text-xs"><T k="common.noData" /></td></tr>
          )}
          {aht.map((r: any) => (
            <tr key={r.use_case} className="border-t border-neutral-100 dark:border-neutral-800">
              <td className="py-2">UC{r.use_case}</td>
              <td>{r.samples}</td>
              <td>{r.avg_seconds}</td>
              <td>{r.p50_seconds}</td>
              <td>{r.p90_seconds}</td>
              <td>{r.p99_seconds}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </Card>
  );
}

async function HandoverCard() {
  const handover = await fetchHandoverQuality();
  return (
    <Card>
      <h2 className="mb-3 text-lg font-semibold"><T k="kpis.section.handoverQuality" /></h2>
      <table className="w-full text-sm">
        <thead className="text-left text-xs uppercase tracking-wide text-neutral-500">
          <tr>
            <th className="py-2"><T k="common.reason" /></th>
            <th className="py-2"><T k="kpis.col.total" /></th>
            <th className="py-2"><T k="common.qualified" /></th>
            <th className="py-2"><T k="kpis.col.qualifiedPct" /></th>
          </tr>
        </thead>
        <tbody>
          {handover.length === 0 && (
            <tr><td colSpan={4} className="py-3 text-center text-neutral-500 text-xs"><T k="common.noData" /></td></tr>
          )}
          {handover.map((r: any) => (
            <tr key={r.reason_code} className="border-t border-neutral-100 dark:border-neutral-800">
              <td className="py-2">{r.reason_code}</td>
              <td>{r.total}</td>
              <td>{r.qualified}</td>
              <td>{r.qualified_pct}%</td>
            </tr>
          ))}
        </tbody>
      </table>
    </Card>
  );
}

async function AbandonmentCard() {
  const abandonment = await fetchAbandonmentFunnel();
  return (
    <Card>
      <h2 className="mb-3 text-lg font-semibold"><T k="kpis.section.abandonment" /></h2>
      <table className="w-full text-sm">
        <thead className="text-left text-xs uppercase tracking-wide text-neutral-500">
          <tr>
            <th className="py-2"><T k="kpis.col.stage" /></th>
            <th className="py-2"><T k="common.uc" /></th>
            <th className="py-2"><T k="kpis.col.count" /></th>
          </tr>
        </thead>
        <tbody>
          {abandonment.length === 0 && (
            <tr><td colSpan={3} className="py-3 text-center text-neutral-500 text-xs"><T k="common.noData" /></td></tr>
          )}
          {abandonment.map((r: any, i: number) => (
            <tr key={i} className="border-t border-neutral-100 dark:border-neutral-800">
              <td className="py-2">{r.stage}</td>
              <td>{r.use_case ?? "—"}</td>
              <td>{r.count}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </Card>
  );
}

async function ReliabilityCard() {
  const reliability = await fetchIntegrationReliability();
  return (
    <Card>
      <h2 className="mb-3 text-lg font-semibold"><T k="kpis.section.reliability" /></h2>
      <ReliabilityChart data={reliability as any[]} />
    </Card>
  );
}

function ChartCardFallback({ titleKey, height = 260 }: { titleKey: TranslationKey; height?: number }) {
  return (
    <Card>
      <h2 className="mb-3 text-lg font-semibold"><T k={titleKey} /></h2>
      <ChartSkeleton height={height} />
    </Card>
  );
}

function TableCardFallback({ titleKey }: { titleKey: TranslationKey }) {
  return (
    <Card>
      <h2 className="mb-3 text-lg font-semibold"><T k={titleKey} /></h2>
      <TableSkeleton rows={4} cols={4} />
    </Card>
  );
}

export default function KpisPage() {
  return (
    <div className="space-y-6 p-6">
      <PageHeader titleKey="kpis.title" subtitleKey="kpis.subtitle" right={<RefreshButton />} />

      <Suspense fallback={<ChartCardFallback titleKey="kpis.section.automation" height={300} />}>
        <AutomationCard />
      </Suspense>

      <Suspense fallback={<ChartCardFallback titleKey="kpis.section.ces" height={260} />}>
        <CesCard />
      </Suspense>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Suspense fallback={<TableCardFallback titleKey="kpis.section.aht" />}>
          <AhtCard />
        </Suspense>
        <Suspense fallback={<TableCardFallback titleKey="kpis.section.handoverQuality" />}>
          <HandoverCard />
        </Suspense>
        <Suspense fallback={<TableCardFallback titleKey="kpis.section.abandonment" />}>
          <AbandonmentCard />
        </Suspense>
        <Suspense fallback={<ChartCardFallback titleKey="kpis.section.reliability" />}>
          <ReliabilityCard />
        </Suspense>
      </div>
    </div>
  );
}
