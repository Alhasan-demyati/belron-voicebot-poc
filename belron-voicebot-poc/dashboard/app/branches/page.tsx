import { createCachedClient } from "@/lib/supabase/server";
import { Card } from "@/components/Card";
import { PageHeader } from "@/components/PageHeader";
import { T } from "@/lib/i18n/LanguageProvider";

export const revalidate = 300;

export default async function BranchesPage() {
  const sb = await createCachedClient();
  const { data } = await sb
    .from("branches")
    .select("*")
    .order("city", { ascending: true });

  return (
    <div className="space-y-6 p-6">
      <PageHeader titleKey="branches.title" subtitleKey="branches.subtitle" />
      <Card className="!p-0">
        <table className="w-full text-sm">
          <thead className="border-b border-neutral-200 text-left text-xs uppercase tracking-wide text-neutral-500 dark:border-neutral-800">
            <tr>
              <th className="px-4 py-3"><T k="common.code" /></th>
              <th className="px-4 py-3"><T k="common.name" /></th>
              <th className="px-4 py-3"><T k="common.city" /></th>
              <th className="px-4 py-3"><T k="common.postalCode" /></th>
              <th className="px-4 py-3"><T k="common.phone" /></th>
              <th className="px-4 py-3"><T k="common.services" /></th>
              <th className="px-4 py-3"><T k="common.status" /></th>
            </tr>
          </thead>
          <tbody>
            {(data ?? []).map((b: any) => (
              <tr key={b.id} className="border-b border-neutral-100 hover:bg-neutral-50 dark:border-neutral-800 dark:hover:bg-neutral-900">
                <td className="px-4 py-3 font-mono text-xs">{b.code}</td>
                <td className="px-4 py-3 font-medium">{b.name}</td>
                <td className="px-4 py-3">{b.city}</td>
                <td className="px-4 py-3">{b.postal_code}</td>
                <td className="px-4 py-3 font-mono text-xs">{b.phone}</td>
                <td className="px-4 py-3 text-xs text-neutral-500">{b.services?.join(", ")}</td>
                <td className="px-4 py-3">
                  {b.active ? (
                    <span className="rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-700"><T k="common.active" /></span>
                  ) : (
                    <span className="rounded-full bg-neutral-100 px-2 py-0.5 text-xs text-neutral-500"><T k="common.inactive" /></span>
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </Card>
    </div>
  );
}
