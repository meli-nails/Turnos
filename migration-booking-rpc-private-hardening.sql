-- Meli Nails · Endpoints públicos invoker + implementación privada
-- Ejecutar después de migration-booking-options-v3.sql.

begin;

create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to anon, authenticated;

alter function public.get_available_slots_v2(uuid[], uuid, date) set schema private;
alter function public.get_available_days_v2(uuid[], uuid, date, date) set schema private;
alter function public.create_booking_request_v3(uuid[], uuid, timestamptz, text, text, text, jsonb, text) set schema private;

grant execute on function private.get_available_slots_v2(uuid[], uuid, date) to anon, authenticated;
grant execute on function private.get_available_days_v2(uuid[], uuid, date, date) to anon, authenticated;
grant execute on function private.create_booking_request_v3(uuid[], uuid, timestamptz, text, text, text, jsonb, text) to anon, authenticated;

create or replace function public.get_available_slots_v2(
  p_service_ids uuid[], p_design_id uuid, p_date date
) returns table(starts_at timestamptz, local_time text)
language sql stable security invoker set search_path to ''
as $function$
  select * from private.get_available_slots_v2(p_service_ids, p_design_id, p_date);
$function$;

create or replace function public.get_available_days_v2(
  p_service_ids uuid[], p_design_id uuid, p_from date, p_to date
) returns table(day date)
language sql stable security invoker set search_path to ''
as $function$
  select * from private.get_available_days_v2(p_service_ids, p_design_id, p_from, p_to);
$function$;

create or replace function public.create_booking_request_v3(
  p_service_ids uuid[], p_design_id uuid, p_starts_at timestamptz,
  p_name text, p_phone text, p_notes text, p_extras jsonb, p_location text
) returns text
language sql security invoker set search_path to ''
as $function$
  select private.create_booking_request_v3(
    p_service_ids, p_design_id, p_starts_at, p_name, p_phone, p_notes, p_extras, p_location
  );
$function$;

revoke all on function public.get_available_slots_v2(uuid[], uuid, date) from public, anon, authenticated;
revoke all on function public.get_available_days_v2(uuid[], uuid, date, date) from public, anon, authenticated;
revoke all on function public.create_booking_request_v3(uuid[], uuid, timestamptz, text, text, text, jsonb, text) from public, anon, authenticated;

grant execute on function public.get_available_slots_v2(uuid[], uuid, date) to anon, authenticated;
grant execute on function public.get_available_days_v2(uuid[], uuid, date, date) to anon, authenticated;
grant execute on function public.create_booking_request_v3(uuid[], uuid, timestamptz, text, text, text, jsonb, text) to anon, authenticated;

commit;
