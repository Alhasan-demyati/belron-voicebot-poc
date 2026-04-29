"use client";
import Image from "next/image";
import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  LayoutDashboard,
  Phone,
  BarChart3,
  MapPin,
  Calendar,
  GitBranch,
  ArrowRightLeft,
  ShieldAlert,
  Settings,
} from "lucide-react";
import { cn } from "@/lib/utils";
import { useLanguage } from "@/lib/i18n/LanguageProvider";
import { TranslationKey } from "@/lib/i18n/dictionary";
import { LanguageToggle } from "./LanguageToggle";
import { CallButton } from "./CallButton";

const NAV: { href: string; key: TranslationKey; icon: any }[] = [
  { href: "/", key: "nav.overview", icon: LayoutDashboard },
  { href: "/calls", key: "nav.calls", icon: Phone },
  { href: "/kpis", key: "nav.kpis", icon: BarChart3 },
  { href: "/branches", key: "nav.branches", icon: MapPin },
  { href: "/appointments", key: "nav.appointments", icon: Calendar },
  { href: "/agent-versions", key: "nav.agentVersions", icon: GitBranch },
  { href: "/handovers", key: "nav.handovers", icon: ArrowRightLeft },
  { href: "/safety", key: "nav.safety", icon: ShieldAlert },
  { href: "/settings", key: "nav.settings", icon: Settings },
];

export function Sidebar() {
  const pathname = usePathname();
  const { t } = useLanguage();
  return (
    <aside className="flex w-60 flex-col border-r border-neutral-200 bg-white dark:border-neutral-800 dark:bg-neutral-950">
      <div className="border-b border-neutral-200 px-5 py-5 dark:border-neutral-800">
        <Image
          src="/belron-logo.png"
          alt="Belron"
          width={1280}
          height={530}
          priority
          className="h-12 w-auto"
        />
        <div className="mt-3 text-sm font-semibold text-belron-red">Carla DE</div>
        <div className="text-xs text-neutral-500">{t("app.subtitle")}</div>
      </div>
      <nav className="mt-2 flex-1 px-2">
        {NAV.map(({ href, key, icon: Icon }) => {
          const active = pathname === href || (href !== "/" && pathname.startsWith(href));
          return (
            <Link
              key={href}
              href={href}
              prefetch
              className={cn(
                "group relative flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition-colors",
                active
                  ? "bg-belron-red/10 font-medium text-belron-red dark:bg-belron-red/20"
                  : "text-neutral-600 hover:bg-belron-yellow/20 hover:text-belron-ink dark:text-neutral-400 dark:hover:bg-neutral-900 dark:hover:text-white"
              )}
            >
              {active && (
                <span className="absolute left-0 top-1.5 bottom-1.5 w-1 rounded-r-full bg-belron-red" />
              )}
              <Icon className="h-4 w-4" />
              {t(key)}
            </Link>
          );
        })}
      </nav>
      <div className="border-t border-neutral-200 p-3 dark:border-neutral-800">
        <CallButton />
      </div>
      <LanguageToggle />
    </aside>
  );
}
