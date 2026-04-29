import Link from "next/link";
import { ArrowDown, ArrowUp, ArrowUpDown } from "lucide-react";
import { createCachedClient } from "@/lib/supabase/server";
import { Card } from "@/components/Card";
import { PageHeader } from "@/components/PageHeader";
import { T } from "@/lib/i18n/LanguageProvider";
import { TranslationKey } from "@/lib/i18n/dictionary";
import { formatDateTime } from "@/lib/utils";

export const dynamic = "force-dynamic";

const STATUS_COLORS: Record<string, string> = {
  scheduled: "bg-blue-100 text-blue-700",
  checked_in: "bg-indigo-100 text-indigo-700",
  in_progress: "bg-amber-100 text-amber-700",
  ready_for_pickup: "bg-emerald-100 text-emerald-700",
  completed: "bg-neutral-100 text-neutral-700",
  cancelled: "bg-red-100 text-red-700",
  no_show: "bg-red-200 text-red-800",
};

const DAMAGE_COLORS: Record<string, string> = {
  small: "bg-emerald-100 text-emerald-700",
  medium: "bg-amber-100 text-amber-700",
  large: "bg-red-100 text-red-700",
};

const GLASS_LABELS: Record<string, { de: string; en: string }> = {
  windshield: { de: "Frontscheibe", en: "Windshield" },
  side: { de: "Seitenscheibe", en: "Side" },
  rear: { de: "Heckscheibe", en: "Rear" },
  panoramic: { de: "Panorama", en: "Panoramic" },
};

type SortKey =
  | "booking_reference"
  | "status"
  | "customer"
  | "branch"
  | "service"
  | "scheduled_start"
  | "eta_ready_at"
  | "insurance_provider"
  | "created_at";

const DB_SORTABLE: Record<string, string> = {
  booking_reference: "booking_reference",
  status: "status",
  scheduled_start: "scheduled_start",
  eta_ready_at: "eta_ready_at",
  insurance_provider: "insurance_provider",
  created_at: "created_at",
};

export default async function AppointmentsPage({
  searchParams,
}: {
  searchParams: Promise<{ sort?: string; dir?: string }>;
}) {
  const sp = await searchParams;
  const sortKey: SortKey = (sp.sort as SortKey) || "created_at";
  const sortDir: "asc" | "desc" = sp.dir === "asc" ? "asc" : "desc";

  const sb = await createCachedClient();
  let q = sb
    .from("appointments")
    .select(`
      id, booking_reference, status, scheduled_start, scheduled_end, eta_ready_at, insurance_provider, created_via, created_at,
      damage_size, damage_notes,
      customer:customers(first_name, last_name, phone_e164),
      vehicle:vehicles(make, model, year, license_plate, glass_type),
      branch:branches(name, city),
      service:services(name_de),
      history:appointment_history(previous_start, new_start, created_at, reason)
    `)
    .limit(80);

  // Server-side sort for direct columns; for joined columns we sort client-side below.
  const dbCol = DB_SORTABLE[sortKey];
  if (dbCol) {
    q = q.order(dbCol, { ascending: sortDir === "asc", nullsFirst: false });
  } else {
    q = q.order("created_at", { ascending: false });
  }
  const { data } = await q;
  let rows: any[] = data ?? [];

  if (!dbCol) {
    const cmp = (a: string, b: string) =>
      sortDir === "asc" ? a.localeCompare(b, "de") : b.localeCompare(a, "de");
    if (sortKey === "customer") {
      rows = [...rows].sort((a, b) =>
        cmp(
          `${a.customer?.last_name ?? ""} ${a.customer?.first_name ?? ""}`.trim(),
          `${b.customer?.last_name ?? ""} ${b.customer?.first_name ?? ""}`.trim(),
        ),
      );
    } else if (sortKey === "branch") {
      rows = [...rows].sort((a, b) => cmp(a.branch?.name ?? "", b.branch?.name ?? ""));
    } else if (sortKey === "service") {
      rows = [...rows].sort((a, b) => cmp(a.service?.name_de ?? "", b.service?.name_de ?? ""));
    }
  }

  return (
    <div className="space-y-6 p-6">
      <PageHeader titleKey="appointments.title" subtitleKey="appointments.subtitle" />
      <Card className="!p-0">
        <table className="w-full text-sm">
          <thead className="border-b border-neutral-200 text-left text-xs uppercase tracking-wide text-neutral-500 dark:border-neutral-800">
            <tr>
              <SortTh col="created_at" labelKey="appointments.col.bookedAt" current={sortKey} dir={sortDir} />
              <SortTh col="booking_reference" labelKey="appointments.col.reference" current={sortKey} dir={sortDir} />
              <SortTh col="status" labelKey="common.status" current={sortKey} dir={sortDir} />
              <SortTh col="customer" labelKey="common.customer" current={sortKey} dir={sortDir} />
              <th className="px-4 py-3"><T k="appointments.col.vehicle" /></th>
              <SortTh col="branch" labelKey="common.branch" current={sortKey} dir={sortDir} />
              <SortTh col="service" labelKey="appointments.col.service" current={sortKey} dir={sortDir} />
              <th className="px-4 py-3"><T k="appointments.col.damage" /></th>
              <SortTh col="scheduled_start" labelKey="appointments.col.start" current={sortKey} dir={sortDir} />
              <SortTh col="eta_ready_at" labelKey="appointments.col.eta" current={sortKey} dir={sortDir} />
              <SortTh col="insurance_provider" labelKey="appointments.col.insurance" current={sortKey} dir={sortDir} />
            </tr>
          </thead>
          <tbody>
            {rows.map((a: any) => (
              <tr key={a.id} className="border-b border-neutral-100 hover:bg-neutral-50 dark:border-neutral-800 dark:hover:bg-neutral-900">
                <td className="px-4 py-3 text-xs text-neutral-600 dark:text-neutral-400">{formatDateTime(a.created_at)}</td>
                <td className="px-4 py-3 font-mono text-xs">{a.booking_reference}</td>
                <td className="px-4 py-3">
                  <span className={`rounded-full px-2 py-0.5 text-xs ${STATUS_COLORS[a.status] ?? "bg-neutral-100"}`}>
                    {a.status}
                  </span>
                </td>
                <td className="px-4 py-3">
                  {a.customer ? `${a.customer.first_name ?? ""} ${a.customer.last_name ?? ""}`.trim() || "—" : "—"}
                </td>
                <td className="px-4 py-3 text-xs">
                  {a.vehicle && (a.vehicle.make || a.vehicle.model || a.vehicle.year) ? (
                    <>
                      <div>{[a.vehicle.make, a.vehicle.model].filter(Boolean).join(" ") || "—"}</div>
                      {a.vehicle.year && <div className="text-neutral-500">{a.vehicle.year}</div>}
                    </>
                  ) : (
                    <span className="text-neutral-400">—</span>
                  )}
                </td>
                <td className="px-4 py-3">{a.branch?.name ?? "—"}</td>
                <td className="px-4 py-3 text-xs">{a.service?.name_de ?? "—"}</td>
                <td className="px-4 py-3 text-xs">
                  {a.damage_size ? (
                    <span className={`rounded-full px-2 py-0.5 ${DAMAGE_COLORS[a.damage_size] ?? "bg-neutral-100"}`}>
                      {a.damage_size}
                    </span>
                  ) : (
                    "—"
                  )}
                  {a.vehicle?.glass_type && (
                    <div className="mt-1 text-neutral-500">
                      {GLASS_LABELS[a.vehicle.glass_type]?.de ?? a.vehicle.glass_type}
                    </div>
                  )}
                </td>
                <td className="px-4 py-3">
                  {formatDateTime(a.scheduled_start)}
                  {(() => {
                    const reschedules = (a.history ?? [])
                      .filter((h: any) => h.previous_start)
                      .sort(
                        (x: any, y: any) =>
                          new Date(y.created_at).getTime() - new Date(x.created_at).getTime(),
                      );
                    const latest = reschedules[0];
                    if (!latest) return null;
                    return (
                      <div className="mt-1 text-xs text-neutral-500">
                        <T k="appointments.rescheduledFrom" />{" "}
                        <span className="line-through">{formatDateTime(latest.previous_start)}</span>
                        {reschedules.length > 1 && (
                          <span className="ml-1 text-neutral-400">
                            (+{reschedules.length - 1})
                          </span>
                        )}
                      </div>
                    );
                  })()}
                </td>
                <td className="px-4 py-3">{formatDateTime(a.eta_ready_at)}</td>
                <td className="px-4 py-3 text-xs text-neutral-500">{a.insurance_provider ?? "—"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
    </div>
  );
}

function SortTh({
  col,
  labelKey,
  current,
  dir,
}: {
  col: SortKey;
  labelKey: TranslationKey;
  current: SortKey;
  dir: "asc" | "desc";
}) {
  const isActive = current === col;
  // Click toggles direction when active; defaults to desc otherwise.
  const nextDir = isActive ? (dir === "asc" ? "desc" : "asc") : "desc";
  const href = `/appointments?sort=${col}&dir=${nextDir}`;
  const Icon = !isActive ? ArrowUpDown : dir === "asc" ? ArrowUp : ArrowDown;

  return (
    <th className="px-4 py-3">
      <Link
        href={href}
        prefetch={false}
        className={`inline-flex items-center gap-1.5 transition ${
          isActive
            ? "text-belron-red"
            : "text-neutral-500 hover:text-neutral-800 dark:hover:text-neutral-200"
        }`}
      >
        <T k={labelKey} />
        <Icon className={`h-3 w-3 ${isActive ? "" : "opacity-40"}`} />
      </Link>
    </th>
  );
}
