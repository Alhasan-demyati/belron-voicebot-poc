"use server";
/**
 * Server actions called from client components for live re-fetching.
 * These bypass the unstable_cache layer in lib/kpis.ts so we always get fresh data.
 */
import { createClient } from "@supabase/supabase-js";

function sb() {
  const key =
    process.env.SUPABASE_SERVICE_ROLE_KEY ||
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!;
  return createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export async function fetchKpiOverviewLive() {
  const { data } = await sb().from("kpi_overview").select("*").limit(1).single();
  return data ?? null;
}

export async function fetchAutomationByUseCaseLive() {
  const { data } = await sb().from("kpi_automation_by_usecase").select("*");
  return data ?? [];
}

export async function fetchCallsListLive(opts: { uc?: string; status?: string; ces?: string }) {
  const { uc, status } = opts;
  let q = sb()
    .from("conversations")
    .select(`
      id, status, primary_use_case, started_at, ended_at, goal_achieved,
      call:calls!inner(id, external_call_id, phone_e164_spoken, duration_seconds, customer:customers(first_name, last_name))
    `)
    .order("started_at", { ascending: false })
    .limit(80);
  if (status) q = q.eq("status", status);
  if (uc) q = q.eq("primary_use_case", parseInt(uc));
  const { data: convs } = await q;

  const ces = new Map<string, { score: number | null; collected: boolean }>();
  if (convs?.length) {
    const { data: cesRows } = await sb()
      .from("customer_feedback")
      .select("conversation_id, ces_score, ces_collected")
      .in("conversation_id", convs.map((c: any) => c.id));
    cesRows?.forEach((r: any) => ces.set(r.conversation_id, { score: r.ces_score, collected: r.ces_collected }));
  }

  let filtered = convs ?? [];
  if (opts.ces) {
    filtered = filtered.filter((c: any) => {
      const x = ces.get(c.id);
      if (!x?.collected || x.score == null) return false;
      const s = x.score;
      switch (opts.ces) {
        case "1-3": return s >= 1 && s <= 3;
        case "4-6": return s >= 4 && s <= 6;
        case "7-8": return s >= 7 && s <= 8;
        case "9-10": return s >= 9 && s <= 10;
        default: return true;
      }
    });
  }

  // Pull all tool_calls + turn counts for these conversations in two queries
  const bookings = new Map<string, { ref: string | null; ok: boolean }>();
  const enrichments = new Map<string, {
    derivedPhone: string | null;
    derivedName: string | null;
    derivedUC: number | null;
    action: { kind: "booked" | "rescheduled" | "cancelled" | "handover" | "question" | null; ref: string | null; reason: string | null };
    toolCount: number;
  }>();
  const turnCounts = new Map<string, number>();
  if (filtered.length) {
    const ids = filtered.map((c: any) => c.id);
    const [{ data: toolRows }, { data: turnRows }] = await Promise.all([
      sb()
        .from("tool_calls")
        .select("conversation_id, tool_name, status, request_payload, response_payload, created_at")
        .in("conversation_id", ids)
        .order("created_at", { ascending: true }),
      sb()
        .from("conversation_turns")
        .select("conversation_id")
        .in("conversation_id", ids),
    ]);

    turnRows?.forEach((r: any) => {
      turnCounts.set(r.conversation_id, (turnCounts.get(r.conversation_id) ?? 0) + 1);
    });

    // Group tool_calls by conversation
    const byConv = new Map<string, any[]>();
    toolRows?.forEach((r: any) => {
      const arr = byConv.get(r.conversation_id) ?? [];
      arr.push(r);
      byConv.set(r.conversation_id, arr);
    });

    for (const cid of ids) {
      const calls = byConv.get(cid) ?? [];
      // booking
      const lastBook = [...calls].reverse().find((r) => r.tool_name === "book_appointment");
      if (lastBook) {
        const ok =
          lastBook.status === "success" &&
          !!lastBook.response_payload?.ok &&
          !!lastBook.response_payload?.data?.booking_reference;
        bookings.set(cid, { ref: lastBook.response_payload?.data?.booking_reference ?? null, ok });
      }
      // derived phone (from get_customer_by_phone request OR book_appointment request)
      const phoneCall = calls.find((r) => r.tool_name === "get_customer_by_phone");
      const phoneFromBook = calls.find((r) => r.tool_name === "book_appointment")?.request_payload?.spoken_phone;
      const derivedPhone =
        phoneCall?.response_payload?.data?.customer?.phone_e164 ??
        phoneCall?.request_payload?.spoken_phone ??
        phoneFromBook ?? null;
      // derived name
      const derivedName =
        phoneCall?.response_payload?.data?.customer
          ? `${phoneCall.response_payload.data.customer.first_name ?? ""} ${phoneCall.response_payload.data.customer.last_name ?? ""}`.trim() || null
          : (calls.find((r) => r.tool_name === "book_appointment")?.request_payload?.name ?? null);
      // derived UC from tool patterns
      let derivedUC: number | null = null;
      if (calls.some((r) => r.tool_name === "book_appointment")) derivedUC = 5;
      else if (calls.some((r) => r.tool_name === "reschedule_appointment" || r.tool_name === "cancel_appointment")) derivedUC = 3;
      else if (calls.some((r) => r.tool_name === "get_appointment")) derivedUC = 2;
      else if (calls.some((r) => ["prepare_handover", "transfer_to_agent"].includes(r.tool_name))) derivedUC = 4;
      // primary action
      let action: any = { kind: null, ref: null, reason: null };
      const reschedOk = [...calls].reverse().find((r) => r.tool_name === "reschedule_appointment" && r.status === "success" && r.response_payload?.ok);
      const cancelOk = [...calls].reverse().find((r) => r.tool_name === "cancel_appointment" && r.status === "success" && r.response_payload?.ok);
      const handover = [...calls].reverse().find((r) => r.tool_name === "prepare_handover" && r.status === "success");
      if (lastBook && bookings.get(cid)?.ok) action = { kind: "booked", ref: bookings.get(cid)!.ref, reason: null };
      else if (reschedOk) action = { kind: "rescheduled", ref: reschedOk.response_payload?.data?.appointment?.booking_reference ?? null, reason: null };
      else if (cancelOk) action = { kind: "cancelled", ref: null, reason: null };
      else if (handover) action = { kind: "handover", ref: null, reason: handover.request_payload?.reason_code ?? null };
      else if (calls.length > 0) action = { kind: "question", ref: null, reason: null };

      enrichments.set(cid, {
        derivedPhone,
        derivedName,
        derivedUC,
        action,
        toolCount: calls.length,
      });
    }
  }

  return filtered.map((c: any) => ({
    ...c,
    ces: ces.get(c.id) ?? null,
    booking: bookings.get(c.id) ?? null,
    enrich: enrichments.get(c.id) ?? null,
    turnCount: turnCounts.get(c.id) ?? 0,
  }));
}

export async function fetchHandoversLive() {
  const { data } = await sb()
    .from("handovers")
    .select(`*, conversation:conversations(id, started_at, call:calls(customer:customers(first_name, last_name)))`)
    .order("created_at", { ascending: false })
    .limit(80);
  return data ?? [];
}

export async function fetchSafetyEventsLive() {
  const { data } = await sb()
    .from("safety_events")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(80);
  return data ?? [];
}

export async function fetchCallTurnsAndTools(conversationId: string) {
  const [{ data: turns }, { data: tools }] = await Promise.all([
    sb().from("conversation_turns").select("*").eq("conversation_id", conversationId).order("turn_index"),
    sb().from("tool_calls").select("*").eq("conversation_id", conversationId).order("created_at"),
  ]);
  return { turns: turns ?? [], tools: tools ?? [] };
}

export async function fetchOutcomeAndFeedback(conversationId: string) {
  const [{ data: outcome }, { data: feedback }] = await Promise.all([
    sb().from("outcomes").select("*").eq("conversation_id", conversationId).maybeSingle(),
    sb().from("customer_feedback").select("*").eq("conversation_id", conversationId).maybeSingle(),
  ]);
  return { outcome: outcome ?? null, feedback: feedback ?? null };
}
