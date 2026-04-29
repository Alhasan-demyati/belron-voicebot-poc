import type { Metadata } from "next";
import "./globals.css";
import { Sidebar } from "@/components/Sidebar";
import { LanguageProvider } from "@/lib/i18n/LanguageProvider";

export const metadata: Metadata = {
  title: "Belron — Remona DE Voicebot Dashboard",
  description: "Belron / Carglass Germany Voicebot POC — operations dashboard",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="de" suppressHydrationWarning>
      <body className="bg-neutral-50 text-neutral-900 dark:bg-neutral-950 dark:text-neutral-100" suppressHydrationWarning>
        <LanguageProvider initial="de">
          <div className="h-1 w-full bg-gradient-to-r from-belron-yellow via-belron-yellow to-belron-red" />
          <div className="flex min-h-[calc(100vh-0.25rem)]">
            <Sidebar />
            <main className="flex-1 overflow-x-auto">{children}</main>
          </div>
        </LanguageProvider>
      </body>
    </html>
  );
}
