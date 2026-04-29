import { cn } from "@/lib/utils";

export function Skeleton({ className, style }: { className?: string; style?: React.CSSProperties }) {
  return (
    <div
      style={style}
      className={cn(
        "animate-pulse rounded-md bg-neutral-200/70 dark:bg-neutral-800/70",
        className
      )}
    />
  );
}

export function CardSkeleton({ className }: { className?: string }) {
  return (
    <div
      className={cn(
        "rounded-2xl border border-neutral-200 bg-white p-5 shadow-sm dark:border-neutral-800 dark:bg-neutral-900",
        className
      )}
    >
      <Skeleton className="h-3 w-24" />
      <Skeleton className="mt-3 h-8 w-32" />
      <Skeleton className="mt-2 h-3 w-40" />
    </div>
  );
}

export function TableSkeleton({ rows = 8, cols = 6 }: { rows?: number; cols?: number }) {
  return (
    <div className="rounded-2xl border border-neutral-200 bg-white p-0 shadow-sm dark:border-neutral-800 dark:bg-neutral-900">
      <div className="border-b border-neutral-100 px-4 py-3 dark:border-neutral-800">
        <div className="grid gap-4" style={{ gridTemplateColumns: `repeat(${cols}, 1fr)` }}>
          {Array.from({ length: cols }).map((_, i) => (
            <Skeleton key={i} className="h-3 w-20" />
          ))}
        </div>
      </div>
      {Array.from({ length: rows }).map((_, r) => (
        <div key={r} className="border-b border-neutral-100 px-4 py-4 last:border-0 dark:border-neutral-800">
          <div className="grid gap-4" style={{ gridTemplateColumns: `repeat(${cols}, 1fr)` }}>
            {Array.from({ length: cols }).map((_, c) => (
              <Skeleton key={c} className="h-4" />
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}

export function PageHeaderSkeleton() {
  return (
    <div className="border-b-2 border-belron-yellow pb-4">
      <Skeleton className="h-7 w-40" />
      <Skeleton className="mt-2 h-4 w-72" />
    </div>
  );
}

export function ChartSkeleton({ height = 260 }: { height?: number }) {
  return <Skeleton className="w-full" style={{ height }} />;
}
