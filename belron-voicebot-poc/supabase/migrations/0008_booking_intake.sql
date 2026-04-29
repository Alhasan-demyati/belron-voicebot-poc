-- 0008_booking_intake.sql
-- Adds damage intake fields captured during the new-booking voice flow (UC5).
-- Allows vehicle rows without a license plate (callers are not asked for one
-- in the new-booking flow).

-- ─────────────────────────────────────────────────────────────────────────────
-- damage_size enum + columns on appointments
-- ─────────────────────────────────────────────────────────────────────────────
do $$
begin
    if not exists (select 1 from pg_type where typname = 'damage_size') then
        create type damage_size as enum ('small', 'medium', 'large');
    end if;
end$$;

alter table public.appointments
    add column if not exists damage_size  damage_size,
    add column if not exists damage_notes text;

-- ─────────────────────────────────────────────────────────────────────────────
-- Vehicles: license_plate is no longer required (booking flow may skip it).
-- The trigram index on upper(license_plate) tolerates nulls.
-- ─────────────────────────────────────────────────────────────────────────────
alter table public.vehicles
    alter column license_plate drop not null;
