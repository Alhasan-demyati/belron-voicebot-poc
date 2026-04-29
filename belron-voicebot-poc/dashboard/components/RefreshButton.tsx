"use client";
import { useRouter } from "next/navigation";
import { useState, useTransition } from "react";
import { RefreshCw } from "lucide-react";
import { useLanguage } from "@/lib/i18n/LanguageProvider";

export function RefreshButton() {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [spinning, setSpinning] = useState(false);
  const { t } = useLanguage();

  const handleClick = () => {
    setSpinning(true);
    startTransition(() => {
      router.refresh();
      setTimeout(() => setSpinning(false), 600);
    });
  };

  return (
    <button
      onClick={handleClick}
      disabled={pending}
      className="flex items-center gap-2 rounded-full border border-neutral-200 bg-white px-3 py-1.5 text-xs text-neutral-700 shadow-sm transition hover:bg-neutral-50 disabled:opacity-50 dark:border-neutral-700 dark:bg-neutral-900 dark:text-neutral-300 dark:hover:bg-neutral-800"
      title={t("common.refreshTitle")}
    >
      <RefreshCw className={`h-3.5 w-3.5 ${spinning ? "animate-spin" : ""}`} />
      {t("common.refresh")}
    </button>
  );
}
