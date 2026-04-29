import Link from "next/link";
import { Card } from "@/components/Card";
import { PageHeader } from "@/components/PageHeader";
import { RefreshButton } from "@/components/RefreshButton";
import { T } from "@/lib/i18n/LanguageProvider";
import { formatDateTime } from "@/lib/utils";
import { fetchHandoversLive } from "@/lib/queries";

export const dynamic = "force-dynamic";

export default async function HandoversPage() {
  const data = await fetchHandoversLive();

  return (
    <div className="space-y-6 p-6">
      <PageHeader
        titleKey="handovers.title"
        subtitleKey="handovers.subtitle"
        right={<RefreshButton />}
      />

      <Card className="!p-0">
        <table className="w-full text-sm">
          <thead className="border-b border-neutral-200 text-left text-xs uppercase tracking-wide text-neutral-500 dark:border-neutral-800">
            <tr>
              <th className="px-4 py-3"><T k="common.time" /></th>
              <th className="px-4 py-3"><T k="common.customer" /></th>
              <th className="px-4 py-3"><T k="common.reason" /></th>
              <th className="px-4 py-3"><T k="common.qualified" /></th>
              <th className="px-4 py-3"><T k="common.queue" /></th>
              <th className="px-4 py-3"><T k="common.summary" /></th>
            </tr>
          </thead>
          <tbody>
            {data.length === 0 && (
              <tr>
                <td colSpan={6} className="px-4 py-8 text-center text-neutral-500">
                  <T k="handovers.empty" />
                </td>
              </tr>
            )}
            {data.map((h: any) => {
              const cust = h.conversation?.call?.customer;
              return (
                <tr key={h.id} className="border-b border-neutral-100 hover:bg-neutral-50 dark:border-neutral-800 dark:hover:bg-neutral-900">
                  <td className="px-4 py-3">
                    <Link href={`/calls/${h.conversation_id}`} className="text-blue-600 hover:underline">
                      {formatDateTime(h.created_at)}
                    </Link>
                  </td>
                  <td className="px-4 py-3">
                    {cust ? `${cust.first_name ?? ""} ${cust.last_name ?? ""}` : "—"}
                  </td>
                  <td className="px-4 py-3">
                    <span className={`rounded-full px-2 py-0.5 text-xs ${
                      h.reason_code === "consent_declined" ? "bg-red-100 text-red-700" :
                      h.reason_code === "safety" ? "bg-red-200 text-red-800" :
                      h.reason_code === "location_change" ? "bg-amber-100 text-amber-700" :
                      "bg-neutral-100"
                    }`}>{h.reason_code}</span>
                  </td>
                  <td className="px-4 py-3">
                    {h.qualified ? (
                      <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-700"><T k="common.yesShort" /></span>
                    ) : (
                      <span className="rounded-full bg-amber-100 px-2 py-0.5 text-xs text-amber-700"><T k="common.noShort" /></span>
                    )}
                  </td>
                  <td className="px-4 py-3 text-xs">
                    {h.transferred_to?.startsWith("elevenlabs_agent:") ? (
                      <span className="rounded bg-indigo-100 px-2 py-0.5 font-mono text-indigo-700">
                        → {h.transferred_to.replace("elevenlabs_agent:", "")}
                      </span>
                    ) : (
                      h.transferred_to ?? "—"
                    )}
                  </td>
                  <td className="px-4 py-3 max-w-md truncate">{h.summary_for_agent}</td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </Card>
    </div>
  );
}
