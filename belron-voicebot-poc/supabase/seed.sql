-- seed.sql
-- German mock data for the Carglass Germany Voicebot POC.
-- Run AFTER all migrations. Idempotent-ish (uses ON CONFLICT where natural keys exist;
-- truncates telemetry on re-seed for a clean slate).

begin;

-- ─────────────────────────────────────────────────────────────────────────────
-- Wipe telemetry & dependent tables for repeatable seeding
-- ─────────────────────────────────────────────────────────────────────────────
truncate table
    public.customer_feedback,
    public.outcomes,
    public.handovers,
    public.tool_calls,
    public.conversation_turns,
    public.conversations,
    public.calls,
    public.consent_events,
    public.safety_events,
    public.integration_health,
    public.appointment_history,
    public.appointments,
    public.vehicles,
    public.customers,
    public.slot_overrides,
    public.slot_templates,
    public.branch_holidays,
    public.branch_hours,
    public.branches,
    public.services,
    public.agent_quality_feedback,
    public.prompt_experiments,
    public.agent_versions
restart identity cascade;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5 services
-- ─────────────────────────────────────────────────────────────────────────────
insert into public.services (code, name_de, name_en, default_duration_minutes, requires_calibration) values
    ('CG-FA',  'Frontscheibe ersetzen',    'Windshield replacement', 150, true),
    ('CG-FR',  'Frontscheibe reparieren',  'Windshield repair',       60, false),
    ('CG-SS',  'Seitenscheibe ersetzen',   'Side window replacement', 90, false),
    ('CG-HS',  'Heckscheibe ersetzen',     'Rear window replacement', 90, false),
    ('CG-CAL', 'Kalibrierung',             'ADAS calibration',        60, true);

-- ─────────────────────────────────────────────────────────────────────────────
-- 20 branches across major DE cities
-- ─────────────────────────────────────────────────────────────────────────────
insert into public.branches (code, name, address_line1, postal_code, city, lat, lng, phone, services) values
    ('B-BER-01', 'Berlin Mitte',           'Friedrichstraße 100',     '10117', 'Berlin',     52.520008, 13.404954, '+493012345001', array['CG-FA','CG-FR','CG-SS','CG-HS','CG-CAL']),
    ('B-BER-02', 'Berlin Charlottenburg',  'Kantstraße 45',           '10625', 'Berlin',     52.506863, 13.317570, '+493012345002', array['CG-FA','CG-FR','CG-SS','CG-CAL']),
    ('B-HAM-01', 'Hamburg Altona',         'Große Bergstraße 20',     '22767', 'Hamburg',    53.550556, 9.935833,  '+494012345001', array['CG-FA','CG-FR','CG-SS','CG-HS','CG-CAL']),
    ('B-HAM-02', 'Hamburg Wandsbek',       'Wandsbeker Marktstr 10',  '22041', 'Hamburg',    53.580000, 10.080000, '+494012345002', array['CG-FA','CG-FR','CG-SS','CG-CAL']),
    ('B-MUC-01', 'München Schwabing',      'Leopoldstraße 75',        '80802', 'München',    48.158889, 11.583056, '+498912345001', array['CG-FA','CG-FR','CG-SS','CG-HS','CG-CAL']),
    ('B-MUC-02', 'München Pasing',         'Bäckerstraße 2',          '81241', 'München',    48.143333, 11.461667, '+498912345002', array['CG-FA','CG-FR','CG-SS','CG-CAL']),
    ('B-KOE-01', 'Köln Innenstadt',        'Hohe Straße 50',          '50667', 'Köln',       50.937500, 6.960278,  '+492212345001', array['CG-FA','CG-FR','CG-SS','CG-HS','CG-CAL']),
    ('B-KOE-02', 'Köln Ehrenfeld',         'Venloer Straße 200',      '50823', 'Köln',       50.951667, 6.918333,  '+492212345002', array['CG-FA','CG-FR','CG-SS','CG-CAL']),
    ('B-FFM-01', 'Frankfurt Innenstadt',   'Zeil 80',                 '60313', 'Frankfurt',  50.114444, 8.683056,  '+496912345001', array['CG-FA','CG-FR','CG-SS','CG-HS','CG-CAL']),
    ('B-FFM-02', 'Frankfurt Bornheim',     'Berger Straße 150',       '60385', 'Frankfurt',  50.130556, 8.706944,  '+496912345002', array['CG-FA','CG-FR','CG-SS','CG-CAL']),
    ('B-STU-01', 'Stuttgart Vaihingen',    'Schwabstraße 40',         '70197', 'Stuttgart',  48.766667, 9.150000,  '+497112345001', array['CG-FA','CG-FR','CG-SS','CG-HS','CG-CAL']),
    ('B-DUS-01', 'Düsseldorf Bilk',        'Bilker Allee 200',        '40217', 'Düsseldorf', 51.213889, 6.776111,  '+492112345001', array['CG-FA','CG-FR','CG-SS','CG-HS','CG-CAL']),
    ('B-LEJ-01', 'Leipzig Süd',            'Karl-Liebknecht-Str 100', '04275', 'Leipzig',    51.323889, 12.378056, '+493412345001', array['CG-FA','CG-FR','CG-SS','CG-CAL']),
    ('B-DTM-01', 'Dortmund Hörde',         'Hermannstraße 25',        '44263', 'Dortmund',   51.490000, 7.500000,  '+492312345001', array['CG-FA','CG-FR','CG-SS','CG-CAL']),
    ('B-ESS-01', 'Essen Holsterhausen',    'Gemarkenstraße 60',       '45147', 'Essen',      51.450000, 6.997500,  '+492012345001', array['CG-FA','CG-FR','CG-SS','CG-CAL']),
    ('B-HBR-01', 'Bremen Findorff',        'Hemmstraße 80',           '28215', 'Bremen',     53.090000, 8.795000,  '+494212345001', array['CG-FA','CG-FR','CG-SS','CG-CAL']),
    ('B-HAJ-01', 'Hannover Mitte',         'Georgstraße 30',          '30159', 'Hannover',   52.376111, 9.730556,  '+495112345001', array['CG-FA','CG-FR','CG-SS','CG-HS','CG-CAL']),
    ('B-NUE-01', 'Nürnberg Süd',           'Allersberger Straße 100', '90461', 'Nürnberg',   49.430000, 11.080000, '+499112345001', array['CG-FA','CG-FR','CG-SS','CG-CAL']),
    ('B-DRS-01', 'Dresden Neustadt',       'Hauptstraße 20',          '01097', 'Dresden',    51.061111, 13.738889, '+493512345001', array['CG-FA','CG-FR','CG-SS','CG-CAL']),
    ('B-BON-01', 'Bonn Bad Godesberg',     'Koblenzer Straße 50',     '53177', 'Bonn',       50.683333, 7.150000,  '+492212345003', array['CG-FA','CG-FR','CG-SS','CG-CAL']);

-- ─────────────────────────────────────────────────────────────────────────────
-- branch_hours: Mon-Fri 08:00-18:00, Sat 09:00-13:00, Sun closed
-- ─────────────────────────────────────────────────────────────────────────────
insert into public.branch_hours (branch_id, day_of_week, opens_at, closes_at, is_closed)
select b.id, dow,
       case when dow = 5 then time '09:00' when dow = 6 then null else time '08:00' end,
       case when dow = 5 then time '13:00' when dow = 6 then null else time '18:00' end,
       (dow = 6)
from public.branches b
cross join generate_series(0, 6) as dow;

-- ─────────────────────────────────────────────────────────────────────────────
-- branch_holidays: 2026-05-01 (Tag der Arbeit) and 2026-10-03 (Tag der Deutschen Einheit)
-- ─────────────────────────────────────────────────────────────────────────────
insert into public.branch_holidays (branch_id, date, reason)
select b.id, d, r
from public.branches b
cross join (values
    (date '2026-05-01', 'Tag der Arbeit'),
    (date '2026-10-03', 'Tag der Deutschen Einheit')
) as h(d, r);

-- ─────────────────────────────────────────────────────────────────────────────
-- slot_templates: Mon-Fri 08:00-18:00 (3 bays), Sat 09:00-13:00 (2 bays); per service
-- (single all-day window keeps the math simple for the POC; n8n discretizes into
--  service-duration-sized slots at query time)
-- ─────────────────────────────────────────────────────────────────────────────
insert into public.slot_templates (branch_id, service_id, day_of_week, start_time, end_time, bays)
select b.id, s.id, dow,
       case when dow = 5 then time '09:00' else time '08:00' end,
       case when dow = 5 then time '13:00' else time '18:00' end,
       case when dow = 5 then 2 else 3 end
from public.branches b
cross join public.services s
cross join generate_series(0, 5) as dow;  -- skip Sunday (6)

-- ─────────────────────────────────────────────────────────────────────────────
-- 50 customers with German names and valid +49 phones
-- ─────────────────────────────────────────────────────────────────────────────
insert into public.customers (
    phone_e164, email, first_name, last_name, postal_code, language,
    consent_recording, consent_data_processing, consent_marketing
) values
    ('+491701234001', 'lukas.mueller@example.de',     'Lukas',    'Müller',     '10117', 'de', true,  true,  false),
    ('+491701234002', 'anna.schmidt@example.de',      'Anna',     'Schmidt',    '20354', 'de', true,  true,  true),
    ('+491701234003', 'jonas.fischer@example.de',     'Jonas',    'Fischer',    '80331', 'de', true,  true,  false),
    ('+491701234004', 'lena.weber@example.de',        'Lena',     'Weber',      '50667', 'de', true,  true,  false),
    ('+491701234005', 'finn.meyer@example.de',        'Finn',     'Meyer',      '60311', 'de', false, true,  false),
    ('+491701234006', 'mia.wagner@example.de',        'Mia',      'Wagner',     '70173', 'de', true,  true,  true),
    ('+491701234007', 'paul.becker@example.de',       'Paul',     'Becker',     '40212', 'de', true,  true,  false),
    ('+491701234008', 'emma.schulz@example.de',       'Emma',     'Schulz',     '04109', 'de', true,  true,  false),
    ('+491701234009', 'noah.hoffmann@example.de',     'Noah',     'Hoffmann',   '44135', 'de', false, true,  false),
    ('+491701234010', 'lina.schaefer@example.de',     'Lina',     'Schäfer',    '45127', 'de', true,  true,  false),
    ('+491701234011', 'leon.koch@example.de',         'Leon',     'Koch',       '28195', 'de', true,  true,  true),
    ('+491701234012', 'hannah.bauer@example.de',      'Hannah',   'Bauer',      '30159', 'de', true,  true,  false),
    ('+491701234013', 'elias.richter@example.de',     'Elias',    'Richter',    '90402', 'de', true,  true,  false),
    ('+491701234014', 'sophie.klein@example.de',      'Sophie',   'Klein',      '01067', 'de', true,  true,  false),
    ('+491701234015', 'maximilian.wolf@example.de',   'Maximilian','Wolf',      '53111', 'de', true,  true,  true),
    ('+491701234016', 'marie.neumann@example.de',     'Marie',    'Neumann',    '10117', 'de', true,  true,  false),
    ('+491701234017', 'felix.schwarz@example.de',     'Felix',    'Schwarz',    '20354', 'de', false, true,  false),
    ('+491701234018', 'lea.zimmermann@example.de',    'Lea',      'Zimmermann', '80331', 'de', true,  true,  false),
    ('+491701234019', 'julian.braun@example.de',      'Julian',   'Braun',      '50667', 'de', true,  true,  true),
    ('+491701234020', 'laura.krueger@example.de',     'Laura',    'Krüger',     '60311', 'de', true,  true,  false),
    ('+491701234021', 'benjamin.hofmann@example.de',  'Benjamin', 'Hofmann',    '70173', 'de', true,  true,  false),
    ('+491701234022', 'klara.hartmann@example.de',    'Klara',    'Hartmann',   '40212', 'de', true,  true,  false),
    ('+491701234023', 'tim.lange@example.de',         'Tim',      'Lange',      '04109', 'de', false, true,  false),
    ('+491701234024', 'amelie.schmitt@example.de',    'Amelie',   'Schmitt',    '44135', 'de', true,  true,  true),
    ('+491701234025', 'david.werner@example.de',      'David',    'Werner',     '45127', 'de', true,  true,  false),
    ('+491701234026', 'helena.krause@example.de',     'Helena',   'Krause',     '28195', 'de', true,  true,  false),
    ('+491701234027', 'simon.lehmann@example.de',     'Simon',    'Lehmann',    '30159', 'de', true,  true,  false),
    ('+491701234028', 'pia.schulze@example.de',       'Pia',      'Schulze',    '90402', 'de', true,  true,  true),
    ('+491701234029', 'erik.maier@example.de',        'Erik',     'Maier',      '01067', 'de', true,  true,  false),
    ('+491701234030', 'fiona.koehler@example.de',     'Fiona',    'Köhler',     '53111', 'de', false, true,  false),
    ('+491701234031', 'oskar.herrmann@example.de',    'Oskar',    'Herrmann',   '22767', 'de', true,  true,  false),
    ('+491701234032', 'ida.koenig@example.de',        'Ida',      'König',      '10625', 'de', true,  true,  false),
    ('+491701234033', 'theo.walter@example.de',       'Theo',     'Walter',     '80802', 'de', true,  true,  true),
    ('+491701234034', 'mila.mayer@example.de',        'Mila',     'Mayer',      '50823', 'de', true,  true,  false),
    ('+491701234035', 'liam.huber@example.de',        'Liam',     'Huber',      '60385', 'de', true,  true,  false),
    ('+491701234036', 'frieda.kaiser@example.de',     'Frieda',   'Kaiser',     '70197', 'de', true,  true,  false),
    ('+491701234037', 'henry.fuchs@example.de',       'Henry',    'Fuchs',      '40217', 'de', false, true,  false),
    ('+491701234038', 'matilda.peters@example.de',    'Matilda',  'Peters',     '04275', 'de', true,  true,  true),
    ('+491701234039', 'anton.lang@example.de',        'Anton',    'Lang',       '44263', 'de', true,  true,  false),
    ('+491701234040', 'rosa.scholz@example.de',       'Rosa',     'Scholz',     '45147', 'de', true,  true,  false),
    ('+491701234041', 'milo.jung@example.de',         'Milo',     'Jung',       '28215', 'de', true,  true,  false),
    ('+491701234042', 'nora.hahn@example.de',         'Nora',     'Hahn',       '30159', 'de', true,  true,  false),
    ('+491701234043', 'samuel.vogel@example.de',      'Samuel',   'Vogel',      '90461', 'de', true,  true,  true),
    ('+491701234044', 'alma.friedrich@example.de',    'Alma',     'Friedrich',  '01097', 'de', true,  true,  false),
    ('+491701234045', 'aaron.keller@example.de',      'Aaron',    'Keller',     '53177', 'de', false, true,  false),
    ('+491701234046', 'isabella.guenther@example.de', 'Isabella', 'Günther',    '22041', 'de', true,  true,  false),
    ('+491701234047', 'oscar.berg@example.de',        'Oscar',    'Berg',       '81241', 'de', true,  true,  false),
    ('+491701234048', 'mathilda.frank@example.de',    'Mathilda', 'Frank',      '50823', 'de', true,  true,  true),
    ('+491701234049', 'levi.berger@example.de',       'Levi',     'Berger',     '60385', 'de', true,  true,  false),
    ('+491701234050', 'emilia.winkler@example.de',    'Emilia',   'Winkler',    '70197', 'de', true,  true,  false);

-- ─────────────────────────────────────────────────────────────────────────────
-- 80 vehicles linked to customers (most have 1, some have 2)
-- ─────────────────────────────────────────────────────────────────────────────
insert into public.vehicles (customer_id, license_plate, make, model, year, glass_type)
select c.id,
       'B-' || upper(substring(md5(c.id::text || s::text), 1, 2)) || ' ' || (1000 + (s * 17 + 100) % 9000)::text,
       (array['VW','BMW','Mercedes','Audi','Opel','Ford','Skoda','Renault','Peugeot','Hyundai'])[1 + (abs(hashtext(c.id::text || s::text)) % 10)],
       (array['Golf','Polo','3er','5er','C-Klasse','A4','A6','Astra','Focus','Octavia','Megane','308','i30'])[1 + (abs(hashtext(c.id::text || s::text || 'm')) % 13)],
       2017 + (abs(hashtext(c.id::text || s::text || 'y')) % 8),
       (array['windshield','side','rear','panoramic'])[1 + (abs(hashtext(c.id::text || s::text || 'g')) % 4)]
from public.customers c
cross join generate_series(1, 2) as s
where s = 1 or (abs(hashtext(c.id::text)) % 100) < 60   -- ~60% of customers have a 2nd car → ~80 total
order by c.id, s;

-- ─────────────────────────────────────────────────────────────────────────────
-- Agent versions (3 versions, v0.3 active)
-- ─────────────────────────────────────────────────────────────────────────────
insert into public.agent_versions (version, system_prompt, model, temperature, voice_id, notes, deployed_at, is_active) values
    ('0.1.0',  'Baseline-Prompt v0.1 — siehe elevenlabs/system_prompt_de.md',                 'gpt-4o-mini',  0.30, 'ELEVEN-DE-FEMALE-V1', 'Initial baseline.',                       now() - interval '30 days', false),
    ('0.2.0',  'Refined-Prompt v0.2 — verbesserte Identifikation und CES-Fluss',              'gpt-4o',       0.30, 'ELEVEN-DE-FEMALE-V1', 'Improved identification and CES flow.',   now() - interval '14 days', false),
    ('0.3.0',  'Production-Prompt v0.3 — vollständiger Prompt mit allen 4 Use Cases',         'gpt-4o',       0.30, 'ELEVEN-DE-FEMALE-V2', 'Current active production prompt.',       now() - interval '2 days',  true);

-- ─────────────────────────────────────────────────────────────────────────────
-- 150 appointments: spread −30d…+30d, varied statuses, varied branches/services
-- ─────────────────────────────────────────────────────────────────────────────
with picks as (
    select
        gs as n,
        (now() - interval '30 days' + (gs * interval '8 hours'))::timestamptz as base_start
    from generate_series(0, 149) as gs
),
joined as (
    select
        p.n,
        p.base_start,
        (select id from public.customers order by id offset (p.n % 50) limit 1) as customer_id,
        (select id from public.branches  order by id offset (p.n % 20) limit 1) as branch_id,
        (select id from public.services  order by id offset (p.n %  5) limit 1) as service_id,
        (select default_duration_minutes from public.services order by id offset (p.n % 5) limit 1) as duration_min
    from picks p
)
insert into public.appointments (
    booking_reference, customer_id, vehicle_id, branch_id, service_id,
    scheduled_start, scheduled_end, status, eta_ready_at,
    insurance_provider, insurance_excess_eur, created_via
)
select
    'CG-' || upper(substring(md5(j.n::text || j.base_start::text), 1, 5)),
    j.customer_id,
    (select id from public.vehicles v where v.customer_id = j.customer_id order by v.id limit 1),
    j.branch_id,
    j.service_id,
    j.base_start,
    j.base_start + (j.duration_min || ' minutes')::interval,
    case
        when j.base_start < now() - interval '7 days' then
            (array['completed','completed','completed','no_show','cancelled'])[1 + (j.n % 5)]::appointment_status
        when j.base_start < now() - interval '1 day' then
            (array['completed','ready_for_pickup','no_show'])[1 + (j.n % 3)]::appointment_status
        when j.base_start < now() then
            (array['in_progress','ready_for_pickup','checked_in'])[1 + (j.n % 3)]::appointment_status
        else
            (array['scheduled','scheduled','scheduled','cancelled'])[1 + (j.n % 4)]::appointment_status
    end,
    case when j.n % 7 = 0 then j.base_start + (j.duration_min + 15) * interval '1 minute' else null end,
    (array['HUK Coburg','Allianz','AXA','DEVK','LVM','R+V','Selbstzahler'])[1 + (j.n % 7)],
    case (j.n % 7)
        when 6 then null  -- Selbstzahler → no excess
        else (array[0, 150, 300]::numeric[])[1 + (j.n % 3)]
    end,
    (array['web','phone','bot','agent'])[1 + (j.n % 4)]
from joined j;

-- ─────────────────────────────────────────────────────────────────────────────
-- Synthetic telemetry so dashboard charts are populated on day one.
-- We mock 60 historical conversations across all 4 use cases with realistic
-- distributions of automated/handover/abandoned and CES scores 1–10.
-- ─────────────────────────────────────────────────────────────────────────────
with seed_calls as (
    insert into public.calls (
        external_call_id, phone_e164_spoken, started_at, ended_at, duration_seconds,
        customer_id, language_detected, consent_recorded
    )
    select
        'mock_' || gs::text,
        c.phone_e164,
        now() - (gs || ' hours')::interval,
        now() - (gs || ' hours')::interval + ((60 + (gs * 7) % 240) || ' seconds')::interval,
        60 + (gs * 7) % 240,
        c.id,
        'de',
        true
    from generate_series(1, 60) as gs
    join lateral (
        select id, phone_e164 from public.customers order by id offset (gs % 50) limit 1
    ) c on true
    returning id, external_call_id, started_at, ended_at, customer_id, duration_seconds
),
seed_convs as (
    insert into public.conversations (
        call_id, agent_version_id, language, status,
        primary_use_case, goal_achieved, started_at, ended_at
    )
    select
        sc.id,
        (select id from public.agent_versions where is_active limit 1),
        'de',
        case (cast(substring(sc.external_call_id from 6) as int) % 10)
            when 0 then 'abandoned'::conversation_status
            when 1 then 'completed_with_handover'::conversation_status
            else 'completed_automated'::conversation_status
        end,
        1 + (cast(substring(sc.external_call_id from 6) as int) % 4),
        case (cast(substring(sc.external_call_id from 6) as int) % 10)
            when 0 then false
            when 1 then false
            else true
        end,
        sc.started_at,
        sc.ended_at
    from seed_calls sc
    returning id, status, primary_use_case, started_at, ended_at, call_id
)
insert into public.outcomes (
    conversation_id, use_case, automated, abandoned, abandonment_stage,
    handover, handover_qualified, aht_seconds, time_to_first_response_ms,
    tool_calls_count, tool_call_failures, customer_goal_completed
)
select
    cv.id,
    cv.primary_use_case,
    (cv.status = 'completed_automated'),
    (cv.status = 'abandoned'),
    case when cv.status = 'abandoned' then (array['identification','search','confirmation','intent_detection'])[1 + (extract(epoch from cv.started_at)::bigint % 4)] else null end,
    (cv.status = 'completed_with_handover'),
    case when cv.status = 'completed_with_handover' then (extract(epoch from cv.started_at)::bigint % 5 < 4) else null end,
    extract(epoch from (cv.ended_at - cv.started_at))::int,
    300 + (extract(epoch from cv.started_at)::bigint % 800)::int,
    1 + (extract(epoch from cv.started_at)::bigint % 6)::int,
    case when extract(epoch from cv.started_at)::bigint % 20 = 0 then 1 else 0 end,
    (cv.status in ('completed_automated','completed_with_handover'))
from seed_convs cv;

-- Customer feedback rows: ~85% capture rate, scores skewed positive
insert into public.customer_feedback (conversation_id, ces_score, ces_collected, ces_question, source)
select
    o.conversation_id,
    case when (extract(epoch from o.recomputed_at)::bigint % 100) < 85
         then ((extract(epoch from o.recomputed_at)::bigint % 6) + 5)::smallint   -- 5..10 mostly
         else null
    end,
    ((extract(epoch from o.recomputed_at)::bigint % 100) < 85),
    'Auf einer Skala von 1 bis 10, wie würden Sie unser Gespräch heute bewerten?',
    'in_call'
from public.outcomes o;

-- A few low scores for distribution variety
update public.customer_feedback
set ces_score = ((random() * 4)::int + 1)::smallint
where ces_collected
  and id in (select id from public.customer_feedback where ces_collected order by random() limit 6);

-- Handover rows for the conversations marked completed_with_handover
insert into public.handovers (conversation_id, reason_code, summary_for_agent, qualified, transferred_to)
select
    o.conversation_id,
    (array['location_change','out_of_scope','customer_request','low_confidence','repeated_failure'])[1 + (extract(epoch from o.recomputed_at)::bigint % 5)],
    'Kunde wünscht persönliche Beratung. Bisheriger Gesprächsverlauf siehe Transkript.',
    coalesce(o.handover_qualified, true),
    'queue:carla-de-overflow'
from public.outcomes o
where o.handover;

-- Integration health: mostly success, ~0.5% failure
insert into public.integration_health (integration, endpoint, status_code, latency_ms, success, conversation_id, created_at)
select
    (array['crm','booking','elevenlabs','n8n'])[1 + (gs % 4)],
    '/webhook/' || (array['get-customer-by-phone','get-appointment','check-availability','reschedule-appointment'])[1 + (gs % 4)],
    case when gs % 200 = 0 then 500 else 200 end,
    80 + (gs % 400),
    (gs % 200 != 0),
    null,
    now() - (gs || ' minutes')::interval
from generate_series(1, 600) as gs;

-- Safety events: a few mock acknowledgement examples
insert into public.safety_events (conversation_id, event_type, detector, severity, action_taken, details, created_at)
select
    o.conversation_id,
    (array['out_of_scope','tool_failure','hallucination_suspect'])[1 + (extract(epoch from o.recomputed_at)::bigint % 3)],
    'rule',
    'warning',
    'warned',
    jsonb_build_object('note','Mock-Ereignis aus Seed-Daten'),
    o.recomputed_at
from public.outcomes o
order by random()
limit 8;

commit;
