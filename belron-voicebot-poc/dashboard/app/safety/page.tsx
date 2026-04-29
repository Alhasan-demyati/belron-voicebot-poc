import Link from "next/link";
import { Card } from "@/components/Card";
import { PageHeader } from "@/components/PageHeader";
import { RefreshButton } from "@/components/RefreshButton";
import { T } from "@/lib/i18n/LanguageProvider";
import { formatDateTime } from "@/lib/utils";
import { fetchSafetyEventsLive } from "@/lib/queries";

export const dynamic = "force-dynamic";

const SEVERITY_COLORS: Record<string, string> = {
  info: "bg-neutral-100 text-neutral-700",
  warning: "bg-amber-100 text-amber-700",
  error: "bg-red-100 text-red-700",
  critical: "bg-red-300 text-red-900",
};

export default async function SafetyPage() {
  const data = await fetchSafetyEventsLive();

  return (
    <div className="space-y-6 p-6">
      <PageHeader
        titleKey="safety.title"
        subtitleKey="safety.subtitle"
        right={<RefreshButton />}
      />

      <Card className="!p-0">
        <table className="w-full text-sm">
          <thead className="border-b border-neutral-200 text-left text-xs uppercase tracking-wide text-neutral-500 dark:border-neutral-800">
            <tr>
              <th className="px-4 py-3"><T k="common.time" /></th>
              <th className="px-4 py-3"><T k="common.type" /></th>
              <th className="px-4 py-3"><T k="common.severity" /></th>
              <th className="px-4 py-3"><T k="common.detector" /></th>
              <th className="px-4 py-3"><T k="common.action" /></th>
              <th className="px-4 py-3"><T k="common.acknowledged" /></th>
              <th className="px-4 py-3"><T k="common.details" /></th>
            </tr>
          </thead>
          <tbody>
            {data.length === 0 && (
              <tr>
                <td colSpan={7} className="px-4 py-8 text-center text-neutral-500">
                  <T k="safety.empty" />
                </td>
              </tr>
            )}
            {data.map((e: any) => (
              <tr key={e.id} className="border-b border-neutral-100 dark:border-neutral-800">
                <td className="px-4 py-3">
                  {e.conversation_id ? (
                    <Link href={`/calls/${e.conversation_id}`} className="text-blue-600 hover:underline">
                      {formatDateTime(e.created_at)}
                    </Link>
                  ) : (
                    formatDateTime(e.created_at)
                  )}
                </td>
                <td className="px-4 py-3">{e.event_type}</td>
                <td className="px-4 py-3">
                  <span className={`rounded-full px-2 py-0.5 text-xs ${SEVERITY_COLORS[e.severity] ?? "bg-neutral-100"}`}>
                    {e.severity}
                  </span>
                </td>
                <td className="px-4 py-3 text-xs text-neutral-500">{e.detector}</td>
                <td className="px-4 py-3 text-xs">{e.action_taken ?? "—"}</td>
                <td className="px-4 py-3">
                  {e.acknowledged_at ? (
                    <span className="text-xs text-emerald-700">{formatDateTime(e.acknowledged_at)}</span>
                  ) : (
                    <span className="rounded-full bg-amber-100 px-2 py-0.5 text-xs text-amber-700"><T k="common.open" /></span>
                  )}
                </td>
                <td className="px-4 py-3 max-w-xs truncate text-xs text-neutral-500">
                  {JSON.stringify(e.details)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
    </div>
  );
}
