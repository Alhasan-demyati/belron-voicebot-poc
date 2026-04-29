"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from "react";
import { Lang, TranslationKey, translate } from "./dictionary";

const STORAGE_KEY = "belron-dashboard-lang";

type Ctx = {
  lang: Lang;
  setLang: (l: Lang) => void;
  t: (key: TranslationKey) => string;
};

const LanguageContext = createContext<Ctx | null>(null);

export function LanguageProvider({
  children,
  initial = "de",
}: {
  children: React.ReactNode;
  initial?: Lang;
}) {
  const [lang, setLangState] = useState<Lang>(initial);

  useEffect(() => {
    try {
      const stored = window.localStorage.getItem(STORAGE_KEY) as Lang | null;
      if (stored === "de" || stored === "en") {
        setLangState(stored);
        document.documentElement.lang = stored;
      }
    } catch {
      // ignore
    }
  }, []);

  const setLang = useCallback((l: Lang) => {
    setLangState(l);
    try {
      window.localStorage.setItem(STORAGE_KEY, l);
      document.documentElement.lang = l;
    } catch {
      // ignore
    }
  }, []);

  const t = useCallback((key: TranslationKey) => translate(lang, key), [lang]);

  const value = useMemo(() => ({ lang, setLang, t }), [lang, setLang, t]);

  return <LanguageContext.Provider value={value}>{children}</LanguageContext.Provider>;
}

export function useLanguage(): Ctx {
  const ctx = useContext(LanguageContext);
  if (!ctx) {
    throw new Error("useLanguage must be used within LanguageProvider");
  }
  return ctx;
}

export function T({ k }: { k: TranslationKey }) {
  const { t } = useLanguage();
  return <>{t(k)}</>;
}
