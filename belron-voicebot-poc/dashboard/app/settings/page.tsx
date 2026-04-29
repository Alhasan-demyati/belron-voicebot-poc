import { Card } from "@/components/Card";
import { PageHeader } from "@/components/PageHeader";
import { T } from "@/lib/i18n/LanguageProvider";

export default function SettingsPage() {
  return (
    <div className="space-y-6 p-6">
      <PageHeader titleKey="settings.title" subtitleKey="settings.subtitle" />
      <Card>
        <h2 className="mb-3 text-lg font-semibold"><T k="settings.connections" /></h2>
        <dl className="space-y-2 text-sm">
          <Row label="Supabase URL" value={maskUrl(process.env.NEXT_PUBLIC_SUPABASE_URL)} />
          <Row label="Anon Key" value={mask(process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY)} />
        </dl>
      </Card>

      <Card>
        <h2 className="mb-3 text-lg font-semibold"><T k="settings.dataFlow" /></h2>
        <ol className="list-decimal space-y-2 pl-4 text-sm">
          <li><T k="settings.flow.1" /></li>
          <li><T k="settings.flow.2" /></li>
          <li><T k="settings.flow.3" /></li>
          <li><T k="settings.flow.4" /></li>
          <li><T k="settings.flow.5" /></li>
          <li><T k="settings.flow.6" /></li>
        </ol>
      </Card>

      <Card>
        <h2 className="mb-3 text-lg font-semibold"><T k="settings.helpfulLinks" /></h2>
        <ul className="space-y-1 text-sm">
          <li><a className="text-blue-600 hover:underline" href="https://elevenlabs.io/app/conversational-ai" target="_blank">ElevenLabs Conversational AI</a></li>
          <li><a className="text-blue-600 hover:underline" href="https://supabase.com/dashboard" target="_blank">Supabase Dashboard</a></li>
        </ul>
      </Card>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex justify-between">
      <dt className="text-neutral-500">{label}</dt>
      <dd className="font-mono text-xs">{value}</dd>
    </div>
  );
}

function mask(s?: string) {
  if (!s) return "—";
  if (s.length < 12) return "•".repeat(s.length);
  return s.slice(0, 6) + "…" + s.slice(-4);
}

function maskUrl(s?: string) {
  if (!s) return "—";
  return s;
}
