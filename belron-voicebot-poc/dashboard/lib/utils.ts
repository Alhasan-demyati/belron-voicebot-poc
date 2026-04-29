import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatDateTime(input: string | Date | null | undefined) {
  if (!input) return "—";
  const d = typeof input === "string" ? new Date(input) : input;
  return d.toLocaleString("de-DE", {
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export function formatDuration(seconds: number | null | undefined) {
  if (seconds == null) return "—";
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}:${s.toString().padStart(2, "0")}`;
}

export function pct(numerator: number, denominator: number, digits = 1) {
  if (!denominator) return "—";
  return `${((numerator / denominator) * 100).toFixed(digits)}%`;
}
