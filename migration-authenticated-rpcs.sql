-- Aplicada en Supabase el 2026-11-25.
-- Permite que el sitio público siga consultando la agenda aunque haya una sesión Auth activa en el mismo navegador.
-- No elimina las validaciones internas ni cambia las políticas RLS de las tablas.

revoke all on function public.get_available_days(uuid, date, date) from public;
grant execute on function public.get_available_days(uuid, date, date) to anon, authenticated;

revoke all on function public.get_available_slots(uuid, date) from public;
grant execute on function public.get_available_slots(uuid, date) to anon, authenticated;

revoke all on function public.get_public_business_settings() from public;
grant execute on function public.get_public_business_settings() to anon, authenticated;

revoke all on function public.create_booking_request_v2(uuid, uuid, timestamptz, text, text, text, jsonb, text) from public;
grant execute on function public.create_booking_request_v2(uuid, uuid, timestamptz, text, text, text, jsonb, text) to anon, authenticated;
