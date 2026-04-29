"use client";
import { useState, useEffect, useCallback } from "react";
import { useConversation } from "@elevenlabs/react";
import { Phone, PhoneOff, Mic, MicOff, X, Loader2 } from "lucide-react";
import { useLanguage } from "@/lib/i18n/LanguageProvider";

const AGENT_ID =
  process.env.NEXT_PUBLIC_ELEVENLABS_AGENT_ID ??
  "agent_4901kq4pqxr4e1jrn1bhq8xqbmrz";

type Turn = { role: "user" | "agent"; text: string; ts: number };

export function CallButton() {
  const { t } = useLanguage();
  const [open, setOpen] = useState(false);
  const [turns, setTurns] = useState<Turn[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [muted, setMuted] = useState(false);

  const conversation = useConversation({
    micMuted: muted,
    onConnect: () => setError(null),
    onDisconnect: () => {
      // keep modal open after disconnect so the user can review the transcript
    },
    onMessage: (m: any) => {
      // Library shapes vary across versions; handle the common cases
      const role: "user" | "agent" =
        m?.source === "user" || m?.role === "user" ? "user" : "agent";
      const text: string = m?.message ?? m?.text ?? m?.content ?? "";
      if (text) setTurns((t) => [...t, { role, text, ts: Date.now() }]);
    },
    onError: (e: any) => {
      console.error("ElevenLabs conversation error:", e);
      setError(typeof e === "string" ? e : e?.message ?? t("call.error"));
    },
  });

  // Normalize status — the SDK may emit values beyond the documented 3
  // (e.g. "reconnecting", "failed", "error"). Bucket everything into the
  // 3 states we render so we never crash on a missing label key.
  const rawStatus = (conversation as any).status as string | undefined;
  const status: "disconnected" | "connecting" | "connected" =
    rawStatus === "connected"
      ? "connected"
      : rawStatus === "connecting" || rawStatus === "reconnecting"
      ? "connecting"
      : "disconnected";
  const isSpeaking = !!(conversation as any).isSpeaking;

  const startCall = useCallback(async () => {
    setError(null);
    setTurns([]);
    setMuted(false);
    try {
      // Request mic permission first (required by browsers)
      await navigator.mediaDevices.getUserMedia({ audio: true });
      await conversation.startSession({
        agentId: AGENT_ID,
        connectionType: "webrtc",
      });
    } catch (e: any) {
      setError(e?.message ?? t("call.micError"));
    }
  }, [conversation, t]);

  const endCall = useCallback(async () => {
    try {
      await conversation.endSession();
    } catch (e) {
      console.error(e);
    }
  }, [conversation]);

  // Close button only ends the call if active
  const handleClose = useCallback(async () => {
    if (status === "connected" || status === "connecting") {
      await endCall();
    }
    setOpen(false);
    // small delay so the disconnect callback can finish
    setTimeout(() => setTurns([]), 200);
  }, [status, endCall]);

  return (
    <>
      <button
        onClick={() => setOpen(true)}
        className="flex w-full items-center justify-center gap-2 rounded-lg bg-belron-red px-4 py-2.5 text-sm font-medium text-white shadow-sm transition hover:bg-belron-red-dark"
      >
        <Phone className="h-4 w-4" />
        {t("call.button")}
      </button>

      {open && (
        <CallModal
          status={status}
          isSpeaking={isSpeaking}
          turns={turns}
          error={error}
          muted={muted}
          onToggleMute={() => setMuted((m) => !m)}
          onStart={startCall}
          onEnd={endCall}
          onClose={handleClose}
        />
      )}
    </>
  );
}

function CallModal({
  status,
  isSpeaking,
  turns,
  error,
  muted,
  onToggleMute,
  onStart,
  onEnd,
  onClose,
}: {
  status: "disconnected" | "connecting" | "connected";
  isSpeaking: boolean;
  turns: Turn[];
  error: string | null;
  muted: boolean;
  onToggleMute: () => void;
  onStart: () => void;
  onEnd: () => void;
  onClose: () => void;
}) {
  const { t } = useLanguage();
  // ESC closes
  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [onClose]);

  // Auto-scroll transcript
  useEffect(() => {
    const el = document.getElementById("call-transcript-scroll");
    if (el) el.scrollTop = el.scrollHeight;
  }, [turns]);

  const statusLabel: Record<typeof status, { text: string; color: string }> = {
    disconnected: { text: t("call.ready"), color: "text-neutral-500" },
    connecting: { text: t("call.connecting"), color: "text-amber-600" },
    connected: {
      text: muted
        ? t("call.muted")
        : isSpeaking
        ? t("call.speaking")
        : t("call.listening"),
      color: muted
        ? "text-neutral-500"
        : isSpeaking
        ? "text-blue-600"
        : "text-emerald-600",
    },
  };

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4 backdrop-blur-sm"
      onClick={onClose}
    >
      <div
        onClick={(e) => e.stopPropagation()}
        className="flex h-[600px] max-h-[90vh] w-full max-w-md flex-col overflow-hidden rounded-2xl bg-white shadow-2xl dark:bg-neutral-900"
      >
        {/* Header */}
        <div className="flex items-center justify-between border-b border-neutral-200 px-5 py-4 dark:border-neutral-800">
          <div>
            <div className="text-sm font-semibold">Remona DE</div>
            <div className={`text-xs ${statusLabel[status].color}`}>
              {statusLabel[status].text}
            </div>
          </div>
          <button
            onClick={onClose}
            className="rounded-full p-1 text-neutral-500 hover:bg-neutral-100 dark:hover:bg-neutral-800"
            aria-label={t("call.close")}
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* Status / orb */}
        <div className="flex flex-1 flex-col items-center justify-center bg-gradient-to-b from-belron-yellow/5 to-transparent px-6 py-6">
          <div
            className={`flex h-32 w-32 items-center justify-center rounded-full transition-all duration-300 ${
              status === "connected"
                ? muted
                  ? "bg-neutral-300/30 ring-4 ring-neutral-300/50"
                  : isSpeaking
                  ? "bg-blue-500/20 ring-4 ring-blue-500/40"
                  : "bg-emerald-500/20 ring-4 ring-emerald-500/40 animate-pulse"
                : status === "connecting"
                ? "bg-amber-500/20 ring-4 ring-amber-500/40 animate-pulse"
                : "bg-belron-red/10 ring-4 ring-belron-red/30"
            }`}
          >
            {status === "connecting" ? (
              <Loader2 className="h-12 w-12 animate-spin text-amber-600" />
            ) : status === "connected" ? (
              muted ? (
                <MicOff className="h-12 w-12 text-neutral-500" />
              ) : (
                <Mic className="h-12 w-12 text-emerald-600" />
              )
            ) : (
              <Phone className="h-12 w-12 text-belron-red" />
            )}
          </div>

          {/* Transcript */}
          {turns.length > 0 && (
            <div
              id="call-transcript-scroll"
              className="mt-5 max-h-44 w-full space-y-2 overflow-y-auto rounded-lg bg-neutral-50 p-3 text-sm dark:bg-neutral-800"
            >
              {turns.map((t, i) => (
                <div
                  key={i}
                  className={`flex ${t.role === "user" ? "justify-start" : "justify-end"}`}
                >
                  <div
                    className={`max-w-[85%] rounded-lg px-3 py-1.5 text-xs ${
                      t.role === "user"
                        ? "bg-white shadow-sm dark:bg-neutral-700"
                        : "bg-blue-100 dark:bg-blue-900/40"
                    }`}
                  >
                    {t.text}
                  </div>
                </div>
              ))}
            </div>
          )}

          {error && (
            <div className="mt-4 w-full rounded-md bg-red-50 px-3 py-2 text-xs text-red-700 dark:bg-red-900/20 dark:text-red-300">
              {error}
            </div>
          )}

          {status === "disconnected" && turns.length === 0 && (
            <p className="mt-5 text-center text-xs text-neutral-500">
              {t("call.intro")}
            </p>
          )}
        </div>

        {/* Action buttons */}
        <div className="border-t border-neutral-200 p-4 dark:border-neutral-800">
          {status === "disconnected" ? (
            <button
              onClick={onStart}
              className="flex w-full items-center justify-center gap-2 rounded-lg bg-belron-red px-4 py-3 font-medium text-white shadow-sm transition hover:bg-belron-red-dark"
            >
              <Phone className="h-5 w-5" />
              {t("call.start")}
            </button>
          ) : (
            <div className="flex gap-2">
              <button
                onClick={onToggleMute}
                disabled={status === "connecting"}
                aria-pressed={muted}
                title={muted ? t("call.unmute") : t("call.mute")}
                className={`flex flex-1 items-center justify-center gap-2 rounded-lg px-4 py-3 font-medium shadow-sm transition disabled:opacity-50 ${
                  muted
                    ? "bg-amber-500 text-white hover:bg-amber-600"
                    : "border border-neutral-300 bg-white text-neutral-700 hover:bg-neutral-100 dark:border-neutral-700 dark:bg-neutral-900 dark:text-neutral-200 dark:hover:bg-neutral-800"
                }`}
              >
                {muted ? <MicOff className="h-5 w-5" /> : <Mic className="h-5 w-5" />}
                {muted ? t("call.unmute") : t("call.mute")}
              </button>
              <button
                onClick={onEnd}
                disabled={status === "connecting"}
                className="flex flex-1 items-center justify-center gap-2 rounded-lg bg-neutral-900 px-4 py-3 font-medium text-white shadow-sm transition hover:bg-neutral-800 disabled:opacity-50 dark:bg-white dark:text-neutral-900 dark:hover:bg-neutral-100"
              >
                <PhoneOff className="h-5 w-5" />
                {t("call.end")}
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
