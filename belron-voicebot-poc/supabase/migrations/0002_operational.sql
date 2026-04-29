-- 0002_operational.sql
-- Operational data: customers, vehicles, appointments
-- Powers UC2 (status check) and UC3 (rescheduling).

-- ─────────────────────────────────────────────────────────────────────────────
-- customers
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.customers (
    id                         uuid primary key default gen_random_uuid(),
    tenant_id                  text not null default 'DE',
    phone_e164                 text,            -- E.164 format, e.g. +49301234567
    email                      text,
    first_name                 text,
    last_name                  text,
    postal_code                text,
    language                   text not null default 'de',
    consent_recording          boolean not null default false,
    consent_data_processing    boolean not null default false,
    consent_marketing          boolean not null default false,
    created_at                 timestamptz not null default now(),
    updated_at                 timestamptz not null default now()
);

create index if not exists idx_customers_phone_e164 on public.customers (phone_e164);
create index if not exists idx_customers_email on public.customers (email);
create index if not exists idx_customers_name_postal
    on public.customers using gin ((first_name || ' ' || last_name || ' ' || coalesce(postal_code, '')) gin_trgm_ops);

-- ─────────────────────────────────────────────────────────────────────────────
-- vehicles
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.vehicles (
    id              uuid primary key default gen_random_uuid(),
    customer_id     uuid not null references public.customers(id) on delete cascade,
    license_plate   text not null,
    make            text,
    model           text,
    year            smallint,
    vin             text,
    glass_type      text check (glass_type in ('windshield','side','rear','panoramic') or glass_type is null),
    notes           text,
    created_at      timestamptz not null default now(),
    updated_at      timestamptz not null default now()
);

create index if not exists idx_vehicles_license_plate on public.vehicles (upper(license_plate));
create index if not exists idx_vehicles_customer on public.vehicles (customer_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- appointments
-- ─────────────────────────────────────────────────────────────────────────────
do $$
begin
    if not exists (select 1 from pg_type where typname = 'appointment_status') then
        create type appointment_status as enum (
            'scheduled',
            'checked_in',
            'in_progress',
            'ready_for_pickup',
            'completed',
            'cancelled',
            'no_show'
        );
    end if;
end$$;

create table if not exists public.appointments (
    id                  uuid primary key default gen_random_uuid(),
    booking_reference   text not null unique,            -- short human-readable code, e.g. CG-7K9F2
    customer_id         uuid not null references public.customers(id) on delete restrict,
    vehicle_id          uuid references public.vehicles(id) on delete set null,
    branch_id           uuid not null references public.branches(id) on delete restrict,
    service_id          uuid not null references public.services(id) on delete restrict,
    scheduled_start     timestamptz not null,
    scheduled_end       timestamptz not null,
    status              appointment_status not null default 'scheduled',
    eta_ready_at        timestamptz,
    insurance_provider  text,
    insurance_excess_eur numeric(8,2),
    notes               text,
    created_via         text not null default 'web' check (created_via in ('web','phone','bot','agent')),
    created_at          timestamptz not null default now(),
    updated_at          timestamptz not null default now(),
    check (scheduled_end > scheduled_start)
);

create index if not exists idx_appointments_customer on public.appointments (customer_id);
create index if not exists idx_appointments_branch on public.appointments (branch_id);
create index if not exists idx_appointments_scheduled_start on public.appointments (scheduled_start);
create index if not exists idx_appointments_status on public.appointments (status);

-- ─────────────────────────────────────────────────────────────────────────────
-- appointment_history (audit trail; one row per status / time change)
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists public.appointment_history (
    id                  uuid primary key default gen_random_uuid(),
    appointment_id      uuid not null references public.appointments(id) on delete cascade,
    previous_status     appointment_status,
    new_status          appointment_status,
    previous_start      timestamptz,
    new_start           timestamptz,
    changed_by          text not null check (changed_by in ('bot','agent','customer','system')),
    conversation_id     uuid,                            -- soft FK; conversations table created later
    reason              text,
    created_at          timestamptz not null default now()
);

create index if not exists idx_appointment_history_appt on public.appointment_history (appointment_id);
create index if not exists idx_appointment_history_conv on public.appointment_history (conversation_id);
