-- No se necesita indexar service_ids para el flujo de consultas actual.
drop index if exists public.bookings_service_ids_gin_idx;
