-- Meli Nails · Fix de nombres por reserva
-- Evita que actualizar clients.full_name cambie el nombre mostrado
-- en las reservas anteriores del mismo número de WhatsApp.
-- Esta migración ya fue aplicada en el proyecto Supabase de producción.

begin;

alter table public.bookings
  add column if not exists client_name text;

-- Backfill de reservas anteriores con el nombre actualmente asociado al cliente.
update public.bookings b
set client_name = c.full_name
from public.clients c
where c.id = b.client_id
  and (b.client_name is null or b.client_name = '');

comment on column public.bookings.client_name is
  'Nombre del cliente capturado al crear esta reserva; no cambia si se actualiza la ficha del cliente.';

-- La función v3 ahora escribe client_name junto al client_id en cada reserva.
-- La función completa se instala desde Supabase y se conserva en el historial
-- de migraciones del proyecto.

commit;
