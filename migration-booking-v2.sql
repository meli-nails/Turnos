-- Aplicada en el proyecto vfkalbukfiyprugqepcy el 2026-11-25.
-- Agrega modalidad/extras y una RPC pública que calcula precios en servidor.
alter table public.bookings
  add column if not exists location text not null default 'En el espacio de Meli',
  add column if not exists extras jsonb not null default '[]'::jsonb,
  add column if not exists extra_total numeric(12,2) not null default 0;

do $$ begin
  if not exists (select 1 from pg_constraint where conrelid='public.bookings'::regclass and conname='bookings_extras_is_array') then
    alter table public.bookings add constraint bookings_extras_is_array check (jsonb_typeof(extras)='array');
  end if;
  if not exists (select 1 from pg_constraint where conrelid='public.bookings'::regclass and conname='bookings_extra_total_nonnegative') then
    alter table public.bookings add constraint bookings_extra_total_nonnegative check (extra_total>=0);
  end if;
  if not exists (select 1 from pg_constraint where conrelid='public.bookings'::regclass and conname='bookings_location_allowed') then
    alter table public.bookings add constraint bookings_location_allowed check (location in ('En el espacio de Meli','A domicilio'));
  end if;
end $$;

create or replace function public.create_booking_request_v2(
  p_service_id uuid,p_design_id uuid,p_starts_at timestamptz,p_name text,p_phone text,
  p_notes text,p_extras jsonb,p_location text
) returns text language plpgsql security definer set search_path to '' as $function$
declare
  s public.business_settings%rowtype; v_service public.services%rowtype; v_design public.designs%rowtype;
  v_name text:=btrim(coalesce(p_name,'')); v_phone text:=regexp_replace(coalesce(p_phone,''),'[^0-9]','','g');
  v_notes text:=btrim(coalesce(p_notes,'')); v_location text:=coalesce(p_location,'En el espacio de Meli');
  v_input_extras jsonb:=coalesce(p_extras,'[]'::jsonb); v_saved_extras jsonb:='[]'::jsonb;
  v_extra_id text; v_extra_name text; v_extra_price numeric(12,2); v_seen_extras text[]:=array[]::text[];
  v_extra_total numeric(12,2):=0; v_date date; v_client uuid; v_price numeric(12,2); v_deposit numeric(12,2); v_code text;
begin
  if char_length(v_name)<2 or char_length(v_name)>80 then raise exception 'INVALID_NAME'; end if;
  if char_length(v_phone)<8 or char_length(v_phone)>15 then raise exception 'INVALID_PHONE'; end if;
  if char_length(v_notes)>500 then raise exception 'INVALID_NOTES'; end if;
  if p_starts_at is null then raise exception 'SLOT_UNAVAILABLE'; end if;
  if v_location not in ('En el espacio de Meli','A domicilio') then raise exception 'INVALID_LOCATION'; end if;
  if jsonb_typeof(v_input_extras)<>'array' or jsonb_array_length(v_input_extras)>5 then raise exception 'INVALID_EXTRAS'; end if;
  for v_extra_id in select jsonb_array_elements_text(v_input_extras) loop
    if v_extra_id=any(v_seen_extras) then continue; end if;
    case v_extra_id
      when 'strass' then v_extra_name:='Strass';v_extra_price:=500;
      when 'dijes' then v_extra_name:='Dijes';v_extra_price:=500;
      when 'ojos-gato' then v_extra_name:='Ojos de gato';v_extra_price:=1000;
      when 'efectos' then v_extra_name:='Efectos';v_extra_price:=1000;
      when 'francesitas' then v_extra_name:='Francesitas (todas las uñas)';v_extra_price:=1000;
      else raise exception 'INVALID_EXTRA';
    end case;
    v_seen_extras:=array_append(v_seen_extras,v_extra_id);v_extra_total:=v_extra_total+v_extra_price;
    v_saved_extras:=v_saved_extras||jsonb_build_array(jsonb_build_object('id',v_extra_id,'name',v_extra_name,'price',v_extra_price));
  end loop;
  select * into s from public.business_settings bs where bs.id=1;
  if not found then raise exception 'BUSINESS_NOT_CONFIGURED'; end if;
  select * into v_service from public.services sv where sv.id=p_service_id and sv.is_active and not sv.is_sample;
  if not found then raise exception 'SERVICE_UNAVAILABLE'; end if;
  if p_design_id is not null then
    select * into v_design from public.designs d where d.id=p_design_id and d.is_available and not d.is_sample;
    if not found then raise exception 'DESIGN_UNAVAILABLE'; end if;
  end if;
  if (select count(*) from public.bookings b where b.source='web' and b.created_at>now()-interval '10 minutes')>=15 then raise exception 'RATE_LIMITED'; end if;
  if (select count(*) from public.bookings b join public.clients c on c.id=b.client_id where c.phone=v_phone and b.status='pending')>=3 then raise exception 'TOO_MANY_PENDING'; end if;
  v_date:=(p_starts_at at time zone s.timezone)::date;
  if not exists(select 1 from public.get_available_slots(p_service_id,v_date) g where g.starts_at=p_starts_at) then raise exception 'SLOT_UNAVAILABLE'; end if;
  insert into public.clients(full_name,phone) values(v_name,v_phone)
    on conflict(phone) do update set full_name=excluded.full_name returning id into v_client;
  v_price:=v_service.price+coalesce(v_design.extra_price,0)+v_extra_total;
  v_deposit:=round(v_price*s.deposit_percent/100.0);
  begin
    insert into public.bookings(client_id,service_id,design_id,service_name,design_name,starts_at,duration_min,ends_at,status,price,deposit_amount,client_notes,source,location,extras,extra_total)
    values(v_client,v_service.id,v_design.id,v_service.name,v_design.name,p_starts_at,v_service.duration_min,p_starts_at+make_interval(mins=>v_service.duration_min),'pending',v_price,v_deposit,v_notes,'web',v_location,v_saved_extras,v_extra_total)
    returning public_code into v_code;
  exception when exclusion_violation then raise exception 'SLOT_UNAVAILABLE'; end;
  return v_code;
end $function$;
revoke all on function public.create_booking_request_v2(uuid,uuid,timestamptz,text,text,text,jsonb,text) from public,anon,authenticated;
grant execute on function public.create_booking_request_v2(uuid,uuid,timestamptz,text,text,text,jsonb,text) to anon;
