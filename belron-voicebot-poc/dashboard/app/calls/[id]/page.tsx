import { createCachedClient } from "@/lib/supabase/server";
import { Card } from "@/components/Card";
import { RefreshButton } from "@/components/RefreshButton";
import { T } from "@/lib/i18n/LanguageProvider";
import { TranslationKey } from "@/lib/i18n/dictionary";
import { formatDateTime, formatDuration } from "@/lib/utils";

export const dynamic = "force-dynamic";

const DAMAGE_COLORS: Record<string, string> = {
  small: "bg-emerald-100 text-emerald-700",
  medium: "bg-amber-100 text-amber-700",
  large: "bg-red-100 text-red-700",
};

const GLASS_LABELS: Record<string, string> = {
  windshield: "Frontscheibe",
  side: "Seitenscheibe",
  rear: "Heckscheibe",
  panoramic: "Panorama",
};

export default async function CallDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  const sb = await createCachedClient();

  const [{ data: conv }, { data: turns }, { data: tools }, { data: feedback }, { data: handover }] = await Promise.all([
    sb
      .from("conversations")
      .select(`
        id, status, primary_use_case, goal_achieved, started_at, ended_at, language, final_intent,
        call:calls!inner(id, external_call_id, phone_e164_spoken, duration_seconds, recording_url, customer:customers(first_name, last_name, phone_e164)),
        agent_version:agent_versions(version, voice_id, notes)
      `)
      .eq("id", id)
      .single(),
    sb
      .from("conversation_turns")
      .select("*")
      .eq("conversation_id", id)
      .order("turn_index", { ascending: true }),
    sb
      .from("tool_calls")
      .select("*")
      .eq("conversation_id", id)
      .order("created_at", { ascending: true }),
    sb
      .from("customer_feedback")
      .select("*")
      .eq("conversation_id", id)
      .maybeSingle(),
    sb
      .from("handovers")
      .select("*")
      .eq("conversation_id", id)
      .maybeSingle(),
  ]);

  if (!conv) {
    return <div className="p-6"><T k="callDetail.notFound" /></div>;
  }

  const callId = (conv as any).call?.id;
  const { data: consent } = callId
    ? await sb
        .from("consent_events")
        .select("*")
        .eq("call_id", callId)
        .eq("consent_type", "recording")
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle()
    : { data: null };

  const cust = (conv as any).call?.customer;

  // Derive booking from tool_calls
  const bookCalls = (tools ?? []).filter((t: any) => t.tool_name === "book_appointment");
  const lastBook = bookCalls[bookCalls.length - 1];
  const lastBookOk =
    lastBook?.status === "success" &&
    !!lastBook?.response_payload?.ok &&
    !!lastBook?.response_payload?.data?.booking_reference;
  const bookData = lastBook?.response_payload?.data ?? null;

  return (
    <div className="space-y-6 p-6">
      <header className="flex items-start justify-between gap-3">
        <div>
          <div className="text-xs text-neutral-500"><T k="callDetail.conversation" /> · {(conv as any).call?.external_call_id}</div>
          <h1 className="text-2xl font-semibold">
            {cust ? `${cust.first_name ?? ""} ${cust.last_name ?? ""}` : <T k="callDetail.unknownCaller" />}
          </h1>
          <div className="mt-1 text-sm text-neutral-500">
            {formatDateTime((conv as any).started_at)} · <T k="common.duration" /> {formatDuration((conv as any).call?.duration_seconds)} ·{" "}
            UC {(conv as any).primary_use_case ?? "—"} · <T k="common.status" /> {(conv as any).status}
          </div>
        </div>
        <RefreshButton />
      </header>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
        <div className="space-y-6 lg:col-span-2">
          <Card>
            <div className="mb-3 flex items-center justify-between">
              <h2 className="text-lg font-semibold"><T k="callDetail.transcript" /></h2>
              <span className="text-xs text-neutral-500">
                {turns?.length ?? 0} <T k="callDetail.entries" /> ·{" "}
                {tools?.length ?? 0} <T k="callDetail.toolCalls" />
              </span>
            </div>
            <Transcript turns={turns ?? []} tools={tools ?? []} />
          </Card>
        </div>

        <div className="space-y-6">
          <Card>
            <h2 className="mb-3 text-lg font-semibold"><T k="callDetail.outcome" /></h2>
            <dl className="space-y-2 text-sm">
              <Row labelKey="common.status" value={(conv as any).status} />
              <Row labelKey="callDetail.useCase" value={(conv as any).primary_use_case ?? "—"} />
              <Row labelKey="callDetail.goalReached" value={(conv as any).goal_achieved == null ? "—" : <T k={(conv as any).goal_achieved ? "common.yes" : "common.no"} />} />
              <Row labelKey="common.language" value={(conv as any).language} />
              <Row labelKey="callDetail.finalIntent" value={(conv as any).final_intent ?? "—"} />
              <Row labelKey="callDetail.agentVersion" value={(conv as any).agent_version?.version ?? "—"} />
              <Row labelKey="callDetail.phoneSpoken" value={(conv as any).call?.phone_e164_spoken ?? "—"} />
            </dl>
          </Card>

          <Card>
            <h2 className="mb-3 text-lg font-semibold"><T k="callDetail.consent" /></h2>
            {consent ? (
              <div className="space-y-2 text-sm">
                <div className="flex items-center justify-between">
                  <span className="text-neutral-500"><T k="callDetail.consentRecording" /></span>
                  <span className={`rounded-full px-2 py-0.5 text-xs ${
                    consent.granted ? "bg-emerald-100 text-emerald-700" : "bg-red-100 text-red-700"
                  }`}>
                    <T k={consent.granted ? "callDetail.consentGranted" : "callDetail.consentDeclined"} />
                  </span>
                </div>
                {consent.response_text && (
                  <div className="rounded-md bg-neutral-100 p-2 text-xs italic dark:bg-neutral-800">
                    „{consent.response_text}"
                  </div>
                )}
              </div>
            ) : (
              <div className="text-sm text-neutral-500"><T k="callDetail.consentNotCaptured" /></div>
            )}
          </Card>

          <Card>
            <h2 className="mb-3 text-lg font-semibold"><T k="callDetail.booking" /></h2>
            {!lastBook && (
              <div className="text-sm text-neutral-500"><T k="callDetail.bookingNone" /></div>
            )}
            {lastBook && !lastBookOk && (
              <div className="rounded-md bg-red-50 p-3 text-sm text-red-900 dark:bg-red-900/30 dark:text-red-200">
                <div className="font-medium"><T k="callDetail.bookingFailed" /></div>
                {lastBook.response_payload?.error_code && (
                  <div className="mt-1 font-mono text-xs">{String(lastBook.response_payload.error_code)}</div>
                )}
                {lastBook.response_payload?.message_for_agent && (
                  <div className="mt-1 text-xs">{String(lastBook.response_payload.message_for_agent)}</div>
                )}
              </div>
            )}
            {lastBook && lastBookOk && bookData && (
              <dl className="space-y-2 text-sm">
                <Row labelKey="callDetail.bookingRef" value={
                  <span className="rounded bg-emerald-100 px-2 py-0.5 font-mono text-xs text-emerald-700">
                    {bookData.booking_reference}
                  </span>
                } />
                <Row labelKey="callDetail.bookingStart" value={formatDateTime(bookData.scheduled_start)} />
                <Row labelKey="callDetail.bookingService" value={bookData.service_name ?? "—"} />
                <Row labelKey="callDetail.bookingBranch" value={
                  bookData.branch
                    ? `${bookData.branch.name}${bookData.branch.city ? ` · ${bookData.branch.city}` : ""}`
                    : "—"
                } />
                <Row labelKey="callDetail.bookingGlass" value={
                  bookData.glass_type ? (GLASS_LABELS[bookData.glass_type] ?? bookData.glass_type) : "—"
                } />
                <Row labelKey="callDetail.bookingDamage" value={
                  bookData.damage_size ? (
                    <span className={`rounded-full px-2 py-0.5 text-xs ${DAMAGE_COLORS[bookData.damage_size] ?? "bg-neutral-100"}`}>
                      {bookData.damage_size}
                    </span>
                  ) : "—"
                } />
                <BookingVehicleRow request={lastBook.request_payload} />
                <BookingInsuranceRow request={lastBook.request_payload} />
                {bookData.customer_was_created && (
                  <div className="mt-2 rounded-md bg-blue-50 px-2 py-1 text-xs text-blue-700 dark:bg-blue-900/30 dark:text-blue-200">
                    <T k="callDetail.bookingNewCustomer" />
                  </div>
                )}
              </dl>
            )}
          </Card>

          <Card>
            <h2 className="mb-3 text-lg font-semibold"><T k="callDetail.cesRating" /></h2>
            {feedback ? (
              feedback.ces_collected ? (
                <div>
                  <div className={`text-5xl font-semibold ${
                    feedback.ces_score! >= 7 ? "text-emerald-600" :
                    feedback.ces_score! >= 4 ? "text-amber-600" : "text-red-600"
                  }`}>
                    {feedback.ces_score} <span className="text-base text-neutral-400">/ 10</span>
                  </div>
                  <div className="mt-2 text-sm text-neutral-500">{feedback.ces_question}</div>
                  {feedback.comment_text && (
                    <div className="mt-2 rounded-md bg-neutral-100 p-3 text-sm dark:bg-neutral-800">
                      „{feedback.comment_text}"
                    </div>
                  )}
                </div>
              ) : (
                <div className="rounded-md bg-amber-50 p-3 text-sm text-amber-900 dark:bg-amber-900/30 dark:text-amber-200">
                  <T k="callDetail.cesNotCaptured" />
                </div>
              )
            ) : (
              <div className="text-sm text-neutral-500"><T k="callDetail.noFeedback" /></div>
            )}
          </Card>

          {handover && (
            <Card>
              <h2 className="mb-3 text-lg font-semibold"><T k="callDetail.handover" /></h2>
              <dl className="space-y-2 text-sm">
                <Row labelKey="common.reason" value={
                  <span className={`rounded-full px-2 py-0.5 text-xs ${
                    handover.reason_code === "consent_declined" ? "bg-red-100 text-red-700" : "bg-neutral-100"
                  }`}>
                    {handover.reason_code}
                  </span>
                } />
                <Row labelKey="common.qualified" value={<T k={handover.qualified ? "common.yes" : "common.no"} />} />
                <Row labelKey="callDetail.handoverTo" value={
                  handover.transferred_to?.startsWith("elevenlabs_agent:")
                    ? <span className="font-mono text-xs">→ {handover.transferred_to.replace("elevenlabs_agent:", "")}</span>
                    : (handover.transferred_to ?? "—")
                } />
              </dl>
              <div className="mt-3 rounded-md bg-neutral-100 p-3 text-sm dark:bg-neutral-800">
                <div className="text-xs uppercase tracking-wide text-neutral-500"><T k="callDetail.summaryForAgent" /></div>
                <div className="mt-1 whitespace-pre-wrap">{handover.summary_for_agent}</div>
              </div>
            </Card>
          )}

          {(conv as any).call?.recording_url && (
            <Card>
              <h2 className="mb-3 text-lg font-semibold"><T k="callDetail.recording" /></h2>
              <audio controls className="w-full" src={(conv as any).call.recording_url} />
            </Card>
          )}
        </div>
      </div>
    </div>
  );
}

function Row({ labelKey, value }: { labelKey: TranslationKey; value: React.ReactNode }) {
  return (
    <div className="flex items-start justify-between gap-3">
      <dt className="text-neutral-500"><T k={labelKey} /></dt>
      <dd className="text-right font-medium">{value}</dd>
    </div>
  );
}

function BookingVehicleRow({ request }: { request: any }) {
  const make = request?.vehicle_make;
  const model = request?.vehicle_model;
  const year = request?.vehicle_year;
  const value = [make, model, year].filter(Boolean).join(" ") || "—";
  return <Row labelKey="callDetail.bookingVehicle" value={value} />;
}

function BookingInsuranceRow({ request }: { request: any }) {
  const ins = request?.insurance_provider;
  return <Row labelKey="callDetail.bookingInsurance" value={ins || "—"} />;
}

function Transcript({ turns, tools }: { turns: any[]; tools: any[] }) {
  const items = [
    ...turns.map((t) => ({ kind: "turn" as const, data: t, ts: t.created_at })),
    ...tools.map((t) => ({ kind: "tool" as const, data: t, ts: t.created_at })),
  ].sort((a, b) => new Date(a.ts).getTime() - new Date(b.ts).getTime());

  if (items.length === 0) {
    return (
      <div className="rounded-md bg-neutral-100 p-4 text-sm text-neutral-500 dark:bg-neutral-800">
        <T k="callDetail.emptyTranscript" />
      </div>
    );
  }

  return (
    <div className="space-y-3">
      {items.map((item, i) => {
        if (item.kind === "turn") {
          const t = item.data;
          const isUser = t.role === "user";
          return (
            <div key={`turn-${t.id ?? i}`} className={`flex ${isUser ? "justify-start" : "justify-end"}`}>
              <div className={`max-w-[80%] rounded-2xl px-4 py-3 text-sm ${
                isUser ? "bg-neutral-100 dark:bg-neutral-800" : "bg-blue-50 dark:bg-blue-900/30"
              }`}>
                <div className="mb-1 text-[10px] uppercase tracking-wide text-neutral-500">
                  {t.role} · #{t.turn_index}
                </div>
                <div className="whitespace-pre-wrap">{t.text ?? <em><T k="callDetail.empty2" /></em>}</div>
              </div>
            </div>
          );
        }
        const tc = item.data;
        const ok = tc.status === "success";
        return (
          <details
            key={`tool-${tc.id ?? i}`}
            className={`group mx-auto max-w-[90%] rounded-md border text-xs ${
              ok
                ? "border-emerald-200 bg-emerald-50 dark:border-emerald-900 dark:bg-emerald-900/30"
                : "border-red-200 bg-red-50 dark:border-red-900 dark:bg-red-900/30"
            }`}
          >
            <summary className="flex cursor-pointer items-center justify-between gap-2 px-3 py-2 select-none">
              <div className="flex items-center gap-2">
                <span className="font-mono">⚙</span>
                <span className="font-medium">{tc.tool_name}</span>
                <span className="text-neutral-500">· {tc.status}</span>
                {tc.latency_ms != null && <span className="text-neutral-500">· {tc.latency_ms} ms</span>}
              </div>
              <span className="text-neutral-400 group-open:hidden"><T k="callDetail.toolExpand" /></span>
              <span className="hidden text-neutral-400 group-open:inline"><T k="callDetail.toolCollapse" /></span>
            </summary>
            <div className="space-y-2 border-t border-current/10 px-3 py-2">
              {tc.request_payload != null && (
                <div>
                  <div className="mb-1 text-[10px] uppercase tracking-wide text-neutral-500"><T k="callDetail.toolRequest" /></div>
                  <pre className="overflow-x-auto rounded bg-white/60 p-2 text-[11px] leading-snug dark:bg-black/30">{safeStringify(tc.request_payload)}</pre>
                </div>
              )}
              {tc.response_payload != null && (
                <div>
                  <div className="mb-1 text-[10px] uppercase tracking-wide text-neutral-500"><T k="callDetail.toolResponse" /></div>
                  <pre className="overflow-x-auto rounded bg-white/60 p-2 text-[11px] leading-snug dark:bg-black/30">{safeStringify(tc.response_payload)}</pre>
                </div>
              )}
              {tc.error_message && (
                <div>
                  <div className="mb-1 text-[10px] uppercase tracking-wide text-red-600">Error</div>
                  <pre className="overflow-x-auto rounded bg-white/60 p-2 text-[11px] leading-snug dark:bg-black/30">{tc.error_message}</pre>
                </div>
              )}
            </div>
          </details>
        );
      })}
    </div>
  );
}

function safeStringify(v: any): string {
  try {
    return JSON.stringify(v, null, 2);
  } catch {
    return String(v);
  }
}
