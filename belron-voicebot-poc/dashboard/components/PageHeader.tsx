"use client";

import { TranslationKey } from "@/lib/i18n/dictionary";
import { useLanguage } from "@/lib/i18n/LanguageProvider";

export function PageHeader({
  titleKey,
  subtitleKey,
  right,
}: {
  titleKey: TranslationKey;
  subtitleKey?: TranslationKey;
  right?: React.ReactNode;
}) {
  const { t } = useLanguage();
  return (
    <header className="flex items-end justify-between border-b-2 border-belron-yellow pb-4">
      <div>
        <h1 className="text-2xl font-semibold text-belron-ink dark:text-white">
          {t(titleKey)}
        </h1>
        {subtitleKey && (
          <p className="text-sm text-neutral-500">{t(subtitleKey)}</p>
        )}
      </div>
      {right}
    </header>
  );
}
