-- Meli Nails: evita que solicitudes antiguas bloqueen nuevas reservas.
-- Mantiene el límite de 3 solicitudes pendientes, pero solo cuenta turnos futuros.
DO $$
DECLARE
  v_definition text;
  v_old text := 'and b.status = ''pending''';
  v_new text := 'and b.status = ''pending'' and b.starts_at > now()';
BEGIN
  SELECT pg_get_functiondef(
    'public.create_booking_request_v2(uuid,uuid,timestamptz,text,text,text,jsonb,text)'::regprocedure
  ) INTO v_definition;

  IF position(v_old IN v_definition) = 0 THEN
    RAISE EXCEPTION 'No se encontró la condición esperada; no se modificó la función.';
  END IF;

  EXECUTE replace(v_definition, v_old, v_new);
END $$;
