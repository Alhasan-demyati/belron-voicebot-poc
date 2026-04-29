"use client";

import { Languages } from "lucide-react";
import { LANGUAGES } from "@/lib/i18n/dictionary";
import { useLanguage } from "@/lib/i18n/LanguageProvider";
import { cn } from "@/lib/utils";

export function LanguageToggle() {
  const { lang, setLang, t } = useLanguage();
  return (
    <div className="border-t border-neutral-200 px-3 py-3 dark:border-neutral-800">
      <div className="flex items-center gap-2 px-2 pb-2 text-xs uppercase tracking-wide text-neutral-500">
        <Languages className="h-3 w-3" />
        {t("lang.label")}
      </div>
      <div className="flex gap-1 rounded-lg bg-neutral-100 p-1 dark:bg-neutral-900">
        {LANGUAGES.map((l) => (
          <button
            key={l.code}
            type="button"
            onClick={() => setLang(l.code)}
            className={cn(
              "flex-1 rounded-md px-2 py-1.5 text-xs font-medium transition-colors",
              lang === l.code
                ? "bg-belron-red text-white shadow-sm"
                : "text-neutral-600 hover:bg-belron-yellow/30 hover:text-belron-ink dark:text-neutral-400"
            )}
          >
            {l.flag}
          </button>
        ))}
      </div>
    </div>
  );
}
