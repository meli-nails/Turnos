-- Meli Nails · Servicios múltiples O diseño independiente
-- Proyecto: vfkalbukfiyprugqepcy
-- Compatible con reservas históricas y con la función anterior v2.
-- La web debe usar las RPC *_v2 de disponibilidad y create_booking_request_v3.

begin;

-- 1) Cada diseño pasa a tener precio completo y duración propia.
--    Se conserva extra_price por compatibilidad con datos/versiones históricas.
alter table public.designs
  add column if not exists price numeric(12,2) not null default 0,
  add column if not exists duration_min integer not null default 60;

-- Los importes cargados en extra_price son los importes que ya mostraba
-- el catálogo vigente para los diseños publicados. Se copian como precio
-- completo inicial; desde admin se pueden corregir precio y duración.
update public.designs
set price = extra_price
where price = 0 and extra_price > 0;

do $constraints$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.designs'::regclass
      and conname = 'designs_price_nonnegative'
  ) then
    alter table public.designs
      add constraint designs_price_nonnegative check (price >= 0);
  end if;

  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.designs'::regclass
      and conname = 'designs_duration_range'
  ) then
    alter table public.designs
      add constraint designs_duration_range check (duration_min between 15 and 480);
  end if;
end
$constraints$;

comment on column public.designs.price is
  'Precio completo del diseño cuando se reserva sin servicios.';
comment on column public.designs.duration_min is
  'Duración estimada del diseño independiente, en minutos.';

-- 2) Snapshot de hasta dos servicios por reserva.
--    service_id y service_name se mantienen para compatibilidad con paneles
--    o integraciones anteriores: service_id conserva el primer servicio.
alter table public.bookings
  add column if not exists service_ids uuid[] not null default '{}'::uuid[],
  add column if not exists service_names text[] not null default '{}'::text[];

update public.bookings
set service_ids = array[service_id],
    service_names = array[service_name]
where service_id is not null
  and cardinality(service_ids) = 0;

update public.bookings
set service_names = array[service_name]
where service_id is null
  and design_id is null
  and service_name is not null
  and service_name <> 'Diseño independiente'
  and cardinality(service_names) = 0;

do $constraints$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.bookings'::regclass
      and conname = 'bookings_service_ids_max_two'
  ) then
    alter table public.bookings
      add constraint bookings_service_ids_max_two
      check (cardinality(service_ids) <= 2);
  end if;
end
$constraints$;

comment on column public.bookings.service_ids is
  'IDs snapshot de uno o dos servicios elegidos; vacío cuando se reserva un diseño.';
comment on column public.bookings.service_names is
  'Nombres snapshot de los servicios elegidos para mostrar reservas aunque cambie el catálogo.';

-- 3) Disponibilidad: acepta uno/dos servicios o un diseño independiente.
create or replace function public.get_available_slots_v2(
  p_service_ids uuid[],
  p_design_id uuid,
  p_date date
)
returns table(starts_at timestamptz, local_time text)
language plpgsql
stable
security definer
set search_path to ''
as $function$
declare
  s public.business_settings%rowtype;
  wh public.working_hours%rowtype;
  v_ids uuid[] := coalesce(p_service_ids, '{}'::uuid[]);
  v_duration integer;
  v_count integer;
  v_today date;
  v_design_price numeric(12,2);
begin
  if p_date is null then return; end if;
  if cardinality(v_ids) > 2 then return; end if;
  if cardinality(v_ids) <> (
    select count(distinct selected.service_id)::integer
    from unnest(v_ids) as selected(service_id)
  ) then return; end if;
  if cardinality(v_ids) > 0 and p_design_id is not null then return; end if;
  if cardinality(v_ids) = 0 and p_design_id is null then return; end if;

  select * into s
  from public.business_settings bs
  where bs.id = 1;
  if not found then return; end if;

  if cardinality(v_ids) > 0 then
    select count(*)::integer, coalesce(sum(sv.duration_min), 0)::integer
      into v_count, v_duration
    from unnest(v_ids) as selected(service_id)
    join public.services sv
      on sv.id = selected.service_id
     and sv.is_active
     and not sv.is_sample;

    if v_count <> cardinality(v_ids) or v_duration < 5 or v_duration > 600 then return; end if;
  else
    select d.duration_min, d.price
      into v_duration, v_design_price
    from public.designs d
    where d.id = p_design_id
      and d.is_available
      and not d.is_sample;

    if not found or coalesce(v_design_price, 0) <= 0
       or v_duration is null or v_duration < 15 or v_duration > 480 then
      return;
    end if;
  end if;

  v_today := (now() at time zone s.timezone)::date;
  if p_date < v_today or p_date > v_today + s.max_advance_days then return; end if;

  select * into wh
  from public.working_hours w
  where w.weekday = extract(dow from p_date)::integer;
  if not found or not wh.is_open then return; end if;

  return query
  select c.st, to_char(c.local_ts, 'HH24:MI')
  from (
    select g.local_ts,
           (g.local_ts at time zone s.timezone) as st,
           (g.local_ts at time zone s.timezone)
             + make_interval(mins => v_duration) as en
    from generate_series(
      p_date + wh.open_time,
      p_date + wh.close_time - make_interval(mins => v_duration),
      make_interval(mins => s.slot_interval_min)
    ) as g(local_ts)
  ) c
  where c.st >= now() + make_interval(hours => s.min_notice_hours)
    and (
      wh.break_start is null or wh.break_end is null
      or c.local_ts::time >= wh.break_end
      or (c.local_ts + make_interval(mins => v_duration))::time <= wh.break_start
    )
    and not exists (
      select 1 from public.bookings b
      where b.status in ('pending', 'confirmed', 'completed')
        and b.starts_at < c.en
        and b.ends_at > c.st
    )
    and not exists (
      select 1 from public.time_blocks tb
      where tb.starts_at < c.en
        and tb.ends_at > c.st
    )
  order by c.st;
end
$function$;

create or replace function public.get_available_days_v2(
  p_service_ids uuid[],
  p_design_id uuid,
  p_from date,
  p_to date
)
returns table(day date)
language sql
stable
security definer
set search_path to ''
as $function$
  select d.day_value::date
  from generate_series(p_from, least(p_to, p_from + 62), interval '1 day') as d(day_value)
  where exists (
    select 1
    from public.get_available_slots_v2(p_service_ids, p_design_id, d.day_value::date)
  );
$function$;

-- 4) Reserva: cálculo y validación definitivos en PostgreSQL.
create or replace function public.create_booking_request_v3(
  p_service_ids uuid[],
  p_design_id uuid,
  p_starts_at timestamptz,
  p_name text,
  p_phone text,
  p_notes text,
  p_extras jsonb,
  p_location text
)
returns text
language plpgsql
security definer
set search_path to ''
as $function$
declare
  s public.business_settings%rowtype;
  v_design public.designs%rowtype;
  v_ids uuid[] := coalesce(p_service_ids, '{}'::uuid[]);
  v_service_names text[] := '{}'::text[];
  v_service_name text;
  v_primary_service uuid;
  v_service_count integer := 0;
  v_base_price numeric(12,2) := 0;
  v_duration integer := 0;
  v_name text := btrim(coalesce(p_name, ''));
  v_phone text := regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
  v_notes text := btrim(coalesce(p_notes, ''));
  v_location text := coalesce(p_location, 'En el espacio de Meli');
  v_input_extras jsonb := coalesce(p_extras, '[]'::jsonb);
  v_saved_extras jsonb := '[]'::jsonb;
  v_extra_id text;
  v_extra_name text;
  v_extra_price numeric(12,2);
  v_seen_extras text[] := array[]::text[];
  v_extra_total numeric(12,2) := 0;
  v_date date;
  v_client uuid;
  v_price numeric(12,2);
  v_deposit numeric(12,2);
  v_code text;
begin
  if char_length(v_name) < 2 or char_length(v_name) > 80 then
    raise exception 'INVALID_NAME';
  end if;
  if char_length(v_phone) < 8 or char_length(v_phone) > 15 then
    raise exception 'INVALID_PHONE';
  end if;
  if char_length(v_notes) > 500 then
    raise exception 'INVALID_NOTES';
  end if;
  if p_starts_at is null then raise exception 'SLOT_UNAVAILABLE'; end if;
  if v_location not in ('En el espacio de Meli', 'A domicilio') then
    raise exception 'INVALID_LOCATION';
  end if;
  if jsonb_typeof(v_input_extras) is distinct from 'array'
     or jsonb_array_length(v_input_extras) > 5 then
    raise exception 'INVALID_EXTRAS';
  end if;

  -- Debe recibirse exactamente una modalidad: servicios o diseño.
  if cardinality(v_ids) = 0 and p_design_id is null then
    raise exception 'OPTION_REQUIRED';
  end if;
  if cardinality(v_ids) > 2 then raise exception 'TOO_MANY_SERVICES'; end if;
  if cardinality(v_ids) > 0 and p_design_id is not null then
    raise exception 'EXCLUSIVE_SELECTION';
  end if;
  if cardinality(v_ids) <> (
    select count(distinct selected.service_id)::integer
    from unnest(v_ids) as selected(service_id)
  ) then
    raise exception 'DUPLICATE_SERVICE';
  end if;

  if cardinality(v_ids) > 0 then
    select count(*)::integer,
           coalesce(sum(sv.price), 0)::numeric(12,2),
           coalesce(array_agg(sv.name order by selected.ordinality), '{}'::text[]),
           coalesce(sum(sv.duration_min), 0)::integer
      into v_service_count, v_base_price, v_service_names, v_duration
    from unnest(v_ids) with ordinality as selected(service_id, ordinality)
    join public.services sv
      on sv.id = selected.service_id
     and sv.is_active
     and not sv.is_sample;

    if v_service_count <> cardinality(v_ids) then
      raise exception 'SERVICE_UNAVAILABLE';
    end if;
    v_primary_service := v_ids[1];
    v_service_name := array_to_string(v_service_names, ' + ');
  else
    select * into v_design
    from public.designs d
    where d.id = p_design_id
      and d.is_available
      and not d.is_sample;
    if not found then raise exception 'DESIGN_UNAVAILABLE'; end if;
    if coalesce(v_design.price, 0) <= 0 then raise exception 'DESIGN_PRICE_NOT_SET'; end if;
    if v_design.duration_min < 15 or v_design.duration_min > 480 then
      raise exception 'DESIGN_DURATION_INVALID';
    end if;
    v_base_price := v_design.price;
    v_duration := v_design.duration_min;
    v_service_name := 'Diseño independiente';
  end if;
  if v_duration < 5 or v_duration > 600 then
    raise exception 'DURATION_INVALID';
  end if;

  -- Lista blanca de extras y precios fijados en el servidor.
  for v_extra_id in
    select jsonb_array_elements_text(v_input_extras)
  loop
    if v_extra_id = any(v_seen_extras) then continue; end if;
    case v_extra_id
      when 'strass' then
        v_extra_name := 'Strass'; v_extra_price := 500;
      when 'dijes' then
        v_extra_name := 'Dijes'; v_extra_price := 500;
      when 'ojos-gato' then
        v_extra_name := 'Ojos de gato'; v_extra_price := 1000;
      when 'efectos' then
        v_extra_name := 'Efectos'; v_extra_price := 1000;
      when 'francesitas' then
        v_extra_name := 'Francesitas (todas las uñas)'; v_extra_price := 1000;
      else
        raise exception 'INVALID_EXTRA';
    end case;
    v_seen_extras := array_append(v_seen_extras, v_extra_id);
    v_extra_total := v_extra_total + v_extra_price;
    v_saved_extras := v_saved_extras || jsonb_build_array(
      jsonb_build_object('id', v_extra_id, 'name', v_extra_name, 'price', v_extra_price)
    );
  end loop;

  select * into s
  from public.business_settings bs
  where bs.id = 1;
  if not found then raise exception 'BUSINESS_NOT_CONFIGURED'; end if;

  if (
    select count(*) from public.bookings b
    where b.source = 'web'
      and b.created_at > now() - interval '10 minutes'
  ) >= 15 then
    raise exception 'RATE_LIMITED';
  end if;

  if (
    select count(*)
    from public.bookings b
    join public.clients c on c.id = b.client_id
    where c.phone = v_phone
      and b.status = 'pending'
      and b.starts_at > now()
  ) >= 3 then
    raise exception 'TOO_MANY_PENDING';
  end if;

  v_date := (p_starts_at at time zone s.timezone)::date;
  if not exists (
    select 1
    from public.get_available_slots_v2(v_ids, p_design_id, v_date) g
    where g.starts_at = p_starts_at
  ) then
    raise exception 'SLOT_UNAVAILABLE';
  end if;

  insert into public.clients(full_name, phone)
  values (v_name, v_phone)
  on conflict (phone)
  do update set full_name = excluded.full_name
  returning id into v_client;

  v_price := v_base_price + v_extra_total;
  v_deposit := round(v_price * s.deposit_percent / 100.0);

  begin
    insert into public.bookings(
      client_id, service_id, design_id, service_name, design_name,
      service_ids, service_names, starts_at, duration_min, ends_at,
      status, price, deposit_amount, client_notes, source, location,
      extras, extra_total
    ) values (
      v_client, v_primary_service, v_design.id, v_service_name, v_design.name,
      v_ids, v_service_names, p_starts_at, v_duration,
      p_starts_at + make_interval(mins => v_duration),
      'pending', v_price, v_deposit, v_notes, 'web', v_location,
      v_saved_extras, v_extra_total
    )
    returning public_code into v_code;
  exception
    when exclusion_violation then raise exception 'SLOT_UNAVAILABLE';
  end;

  return v_code;
end
$function$;

-- 5) Permisos: endpoints públicos intencionales para reservar y consultar slots.
revoke all on function public.get_available_slots_v2(uuid[], uuid, date)
  from public, anon, authenticated;
revoke all on function public.get_available_days_v2(uuid[], uuid, date, date)
  from public, anon, authenticated;
revoke all on function public.create_booking_request_v3(uuid[], uuid, timestamptz, text, text, text, jsonb, text)
  from public, anon, authenticated;

grant execute on function public.get_available_slots_v2(uuid[], uuid, date)
  to anon, authenticated;
grant execute on function public.get_available_days_v2(uuid[], uuid, date, date)
  to anon, authenticated;
grant execute on function public.create_booking_request_v3(uuid[], uuid, timestamptz, text, text, text, jsonb, text)
  to anon, authenticated;

commit;
