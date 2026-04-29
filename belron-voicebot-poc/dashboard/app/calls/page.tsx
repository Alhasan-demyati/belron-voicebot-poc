import Link from "next/link";
import { Card } from "@/components/Card";
import { PageHeader } from "@/components/PageHeader";
import { RefreshButton } from "@/components/RefreshButton";
import { T } from "@/lib/i18n/LanguageProvider";
import { TranslationKey } from "@/lib/i18n/dictionary";
import { formatDateTime, formatDuration } from "@/lib/utils";
import { fetchCallsListLive } from "@/lib/queries";

export const dynamic = "force-dynamic";

const STATUS_COLORS: Record<string, string> = {
  in_progress: "bg-blue-100 text-blue-700",
  completed_automated: "bg-emerald-100 text-emerald-700",
  completed_with_handover: "bg-amber-100 text-amber-700",
  abandoned: "bg-red-100 text-red-700",
};

export default async function CallsPage({
  searchParams,
}: {
  searchParams: Promise<{ uc?: string; status?: string; ces?: string }>;
}) {
  const sp = await searchParams;
  const rows: any[] = await fetchCallsListLive(sp);

  return (
    <div className="space-y-6 p-6">
      <PageHeader
        titleKey="calls.title"
        subtitleKey="calls.subtitle"
        right={<RefreshButton />}
      />

      <Card className="!p-3">
        <div className="flex flex-wrap gap-2 text-xs">
          <FilterChip labelKey="calls.filter.all" href="/calls" active={!sp.status && !sp.uc && !sp.ces} />
          <FilterChip labelKey="calls.filter.live" href="/calls?status=in_progress" active={sp.status === "in_progress"} />
          <FilterChip labelKey="calls.filter.automated" href="/calls?status=completed_automated" active={sp.status === "completed_automated"} />
          <FilterChip labelKey="calls.filter.handover" href="/calls?status=completed_with_handover" active={sp.status === "completed_with_handover"} />
          <FilterChip labelKey="calls.filter.abandoned" href="/calls?status=abandoned" active={sp.status === "abandoned"} />
          <span className="ml-2 mr-1 text-neutral-300">|</span>
          <FilterChipRaw label="UC1" href="/calls?uc=1" active={sp.uc === "1"} />
          <FilterChipRaw label="UC2" href="/calls?uc=2" active={sp.uc === "2"} />
          <FilterChipRaw label="UC3" href="/calls?uc=3" active={sp.uc === "3"} />
          <FilterChipRaw label="UC4" href="/calls?uc=4" active={sp.uc === "4"} />
          <FilterChipRaw label="UC5" href="/calls?uc=5" active={sp.uc === "5"} />
          <span className="ml-2 mr-1 text-neutral-300">|</span>
          <FilterChipRaw label="CES 1–3" href="/calls?ces=1-3" active={sp.ces === "1-3"} />
          <FilterChipRaw label="CES 4–6" href="/calls?ces=4-6" active={sp.ces === "4-6"} />
          <FilterChipRaw label="CES 7–8" href="/calls?ces=7-8" active={sp.ces === "7-8"} />
          <FilterChipRaw label="CES 9–10" href="/calls?ces=9-10" active={sp.ces === "9-10"} />
        </div>
      </Card>

      <Card className="!p-0">
        <table className="w-full text-sm">
          <thead className="border-b border-neutral-200 text-left text-xs uppercase tracking-wide text-neutral-500 dark:border-neutral-800">
            <tr>
              <th className="px-4 py-3"><T k="common.time" /></th>
              <th className="px-4 py-3"><T k="common.status" /></th>
              <th className="px-4 py-3"><T k="common.uc" /></th>
              <th className="px-4 py-3"><T k="common.customer" /></th>
              <th className="px-4 py-3"><T k="common.phone" /></th>
              <th className="px-4 py-3"><T k="common.duration" /></th>
              <th className="px-4 py-3"><T k="calls.col.activity" /></th>
              <th className="px-4 py-3"><T k="calls.col.action" /></th>
              <th className="px-4 py-3">CES</th>
            </tr>
          </thead>
          <tbody>
            {rows.length === 0 && (
              <tr>
                <td colSpan={9} className="px-4 py-8 text-center text-neutral-500">
                  <T k="calls.empty" />
                </td>
              </tr>
            )}
            {rows.map((c: any) => {
              const cust = c.call?.customer;
              const ces = c.ces;
              const enrich = c.enrich;
              const customerName = cust
                ? `${cust.first_name ?? ""} ${cust.last_name ?? ""}`.trim() || enrich?.derivedName || "—"
                : (enrich?.derivedName ?? "—");
              const phone = c.call?.phone_e164_spoken ?? enrich?.derivedPhone ?? "—";
              const uc = c.primary_use_case ?? enrich?.derivedUC ?? null;
              const action = enrich?.action;
              return (
                <tr key={c.id} className="border-b border-neutral-100 hover:bg-neutral-50 dark:border-neutral-800 dark:hover:bg-neutral-900">
                  <td className="px-4 py-3">
                    <Link href={`/calls/${c.id}`} prefetch className="text-blue-600 hover:underline">
                      {formatDateTime(c.started_at)}
                    </Link>
                  </td>
                  <td className="px-4 py-3">
                    <span className={`rounded-full px-2 py-1 text-xs ${STATUS_COLORS[c.status] ?? "bg-neutral-100 text-neutral-600"}`}>
                      {c.status}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-xs">
                    {uc != null ? (
                      <span className="rounded bg-neutral-100 px-2 py-0.5 dark:bg-neutral-800">
                        UC{uc}{c.primary_use_case == null && enrich?.derivedUC != null && <span className="ml-0.5 text-neutral-400">*</span>}
                      </span>
                    ) : "—"}
                  </td>
                  <td className="px-4 py-3">
                    {customerName === "—" ? <span className="text-neutral-400">—</span> : customerName}
                  </td>
                  <td className="px-4 py-3 font-mono text-xs">{phone}</td>
                  <td className="px-4 py-3">{formatDuration(c.call?.duration_seconds)}</td>
                  <td className="px-4 py-3 text-xs text-neutral-500">
                    {c.turnCount > 0 || (enrich?.toolCount ?? 0) > 0 ? (
                      <>
                        {c.turnCount > 0 && <span>{c.turnCount} <T k="callDetail.entries" /></span>}
                        {(enrich?.toolCount ?? 0) > 0 && c.turnCount > 0 && <span> · </span>}
                        {(enrich?.toolCount ?? 0) > 0 && <span>{enrich.toolCount} <T k="callDetail.toolCalls" /></span>}
                      </>
                    ) : (
                      <span className="text-neutral-400">—</span>
                    )}
                  </td>
                  <td className="px-4 py-3 text-xs">
                    {action?.kind === "booked" ? (
                      <span className="rounded bg-emerald-100 px-2 py-0.5 font-mono text-emerald-700">
                        ✓ booked {action.ref}
                      </span>
                    ) : action?.kind === "rescheduled" ? (
                      <span className="rounded bg-blue-100 px-2 py-0.5 font-mono text-blue-700">
                        ↻ rescheduled{action.ref ? ` ${action.ref}` : ""}
                      </span>
                    ) : action?.kind === "cancelled" ? (
                      <span className="rounded bg-red-100 px-2 py-0.5 text-red-700">✗ cancelled</span>
                    ) : action?.kind === "handover" ? (
                      <span className="rounded bg-amber-100 px-2 py-0.5 text-amber-700">
                        → handover{action.reason ? ` (${action.reason})` : ""}
                      </span>
                    ) : action?.kind === "question" ? (
                      <span className="rounded bg-neutral-100 px-2 py-0.5 text-neutral-700 dark:bg-neutral-800 dark:text-neutral-300">
                        ? question
                      </span>
                    ) : c.booking?.ok === false ? (
                      <span className="rounded bg-red-100 px-2 py-0.5 text-red-700">✗ booking failed</span>
                    ) : (
                      <span className="text-neutral-400">—</span>
                    )}
                  </td>
                  <td className="px-4 py-3">
                    {ces?.collected && ces.score != null
                      ? <span className={`font-semibold ${ces.score >= 7 ? "text-emerald-600" : ces.score >= 4 ? "text-amber-600" : "text-red-600"}`}>{ces.score}</span>
                      : <span className="text-xs text-neutral-400">—</span>}
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

function chipClass(active: boolean) {
  return `rounded-full px-3 py-1 ${
    active
      ? "bg-belron-red text-white"
      : "border border-neutral-200 text-neutral-600 hover:bg-neutral-100 dark:border-neutral-700 dark:hover:bg-neutral-800"
  }`;
}

function FilterChip({ labelKey, href, active }: { labelKey: TranslationKey; href: string; active: boolean }) {
  return (
    <Link href={href} prefetch className={chipClass(active)}>
      <T k={labelKey} />
    </Link>
  );
}

function FilterChipRaw({ label, href, active }: { label: string; href: string; active: boolean }) {
  return (
    <Link href={href} prefetch className={chipClass(active)}>
      {label}
    </Link>
  );
}
