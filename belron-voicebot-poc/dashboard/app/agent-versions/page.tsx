import { createCachedClient } from "@/lib/supabase/server";
import { Card } from "@/components/Card";
import { PageHeader } from "@/components/PageHeader";
import { T } from "@/lib/i18n/LanguageProvider";
import { formatDateTime } from "@/lib/utils";

export const revalidate = 300;

export default async function AgentVersionsPage() {
  const sb = await createCachedClient();
  const { data: versions } = await sb
    .from("agent_versions")
    .select("*")
    .order("deployed_at", { ascending: false });

  // Per-version performance: group outcomes by agent_version_id
  const { data: perf } = await sb
    .from("conversations")
    .select("agent_version_id, status, outcomes(automated, abandoned, handover, aht_seconds), customer_feedback(ces_score, ces_collected)");

  const byVersion = new Map<string, any>();
  (perf ?? []).forEach((c: any) => {
    const k = c.agent_version_id ?? "unknown";
    if (!byVersion.has(k)) {
      byVersion.set(k, {
        total: 0, automated: 0, abandoned: 0, handover: 0,
        ces_sum: 0, ces_count: 0, aht_sum: 0, aht_count: 0,
      });
    }
    const v = byVersion.get(k);
    v.total++;
    const o = Array.isArray(c.outcomes) ? c.outcomes[0] : c.outcomes;
    if (o?.automated) v.automated++;
    if (o?.abandoned) v.abandoned++;
    if (o?.handover) v.handover++;
    if (o?.aht_seconds) { v.aht_sum += o.aht_seconds; v.aht_count++; }
    const f = Array.isArray(c.customer_feedback) ? c.customer_feedback[0] : c.customer_feedback;
    if (f?.ces_collected && f?.ces_score) { v.ces_sum += f.ces_score; v.ces_count++; }
  });

  return (
    <div className="space-y-6 p-6">
      <PageHeader titleKey="agentVersions.title" subtitleKey="agentVersions.subtitle" />
      <Card className="!p-0">
        <table className="w-full text-sm">
          <thead className="border-b border-neutral-200 text-left text-xs uppercase tracking-wide text-neutral-500 dark:border-neutral-800">
            <tr>
              <th className="px-4 py-3"><T k="agentVersions.col.version" /></th>
              <th className="px-4 py-3"><T k="agentVersions.col.active" /></th>
              <th className="px-4 py-3"><T k="agentVersions.col.model" /></th>
              <th className="px-4 py-3"><T k="agentVersions.col.temp" /></th>
              <th className="px-4 py-3"><T k="agentVersions.col.voice" /></th>
              <th className="px-4 py-3"><T k="agentVersions.col.deployed" /></th>
              <th className="px-4 py-3"><T k="agentVersions.col.calls" /></th>
              <th className="px-4 py-3"><T k="agentVersions.col.auto" /></th>
              <th className="px-4 py-3"><T k="agentVersions.col.handover" /></th>
              <th className="px-4 py-3"><T k="agentVersions.col.ces" /></th>
              <th className="px-4 py-3"><T k="agentVersions.col.aht" /></th>
            </tr>
          </thead>
          <tbody>
            {(versions ?? []).map((v: any) => {
              const stats = byVersion.get(v.id) ?? { total: 0 };
              return (
                <tr key={v.id} className="border-b border-neutral-100 dark:border-neutral-800">
                  <td className="px-4 py-3 font-mono">{v.version}</td>
                  <td className="px-4 py-3">
                    {v.is_active ? (
                      <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-700"><T k="common.active" /></span>
                    ) : (
                      <span className="rounded-full bg-neutral-100 px-2 py-0.5 text-xs text-neutral-500"><T k="common.archived" /></span>
                    )}
                  </td>
                  <td className="px-4 py-3">{v.model}</td>
                  <td className="px-4 py-3">{v.temperature}</td>
                  <td className="px-4 py-3 font-mono text-xs">{v.voice_id ?? "—"}</td>
                  <td className="px-4 py-3 text-xs">{formatDateTime(v.deployed_at)}</td>
                  <td className="px-4 py-3">{stats.total}</td>
                  <td className="px-4 py-3">
                    {stats.total ? `${((stats.automated / stats.total) * 100).toFixed(0)}%` : "—"}
                  </td>
                  <td className="px-4 py-3">
                    {stats.total ? `${((stats.handover / stats.total) * 100).toFixed(0)}%` : "—"}
                  </td>
                  <td className="px-4 py-3">
                    {stats.ces_count ? (stats.ces_sum / stats.ces_count).toFixed(2) : "—"}
                  </td>
                  <td className="px-4 py-3">
                    {stats.aht_count ? `${Math.round(stats.aht_sum / stats.aht_count)}s` : "—"}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </Card>
    </div>
  );
}
