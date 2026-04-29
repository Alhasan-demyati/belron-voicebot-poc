import { cn } from "@/lib/utils";
import { TranslationKey } from "@/lib/i18n/dictionary";
import { T } from "@/lib/i18n/LanguageProvider";

export function Card({
  children,
  className,
}: {
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "rounded-2xl border border-neutral-200 bg-white p-5 shadow-sm dark:border-neutral-800 dark:bg-neutral-900",
        className
      )}
    >
      {children}
    </div>
  );
}

export function CardHeader({ children }: { children: React.ReactNode }) {
  return <div className="mb-3 flex items-center justify-between">{children}</div>;
}

export function CardTitle({ children }: { children: React.ReactNode }) {
  return <h3 className="text-sm font-medium text-neutral-500">{children}</h3>;
}

export function KpiCard({
  label,
  labelKey,
  value,
  sub,
  subKey,
  subText,
  target,
  status,
}: {
  label?: string;
  labelKey?: TranslationKey;
  value: string;
  sub?: string;
  subKey?: TranslationKey;
  subText?: string;
  target?: string;
  status?: "good" | "warn" | "bad" | "neutral";
}) {
  const colorMap: Record<string, string> = {
    good: "text-emerald-600",
    warn: "text-amber-600",
    bad: "text-red-600",
    neutral: "text-neutral-700 dark:text-neutral-300",
  };
  const color = colorMap[status ?? "neutral"];
  return (
    <Card>
      <div className="text-xs uppercase tracking-wide text-neutral-500">
        {labelKey ? <T k={labelKey} /> : label}
      </div>
      <div className={cn("mt-2 text-3xl font-semibold", color)}>{value}</div>
      {(sub || subKey || subText) && (
        <div className="mt-1 text-sm text-neutral-500">
          {subText && !subKey && subText}
          {subText && subKey && (
            <>
              {subText} <T k={subKey} />
            </>
          )}
          {!subText && subKey && <T k={subKey} />}
          {!subText && !subKey && sub}
        </div>
      )}
      {target && (
        <div className="mt-2 text-xs text-neutral-400">
          <T k="kpi.target" />: {target}
        </div>
      )}
    </Card>
  );
}
