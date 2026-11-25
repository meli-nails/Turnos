MELI NAILS · INTEGRACIÓN CON SUPABASE EXISTENTE
================================================

ARCHIVOS
- index.html: web pública integrada con catálogo, agenda y solicitudes.
- admin.html: panel de administración con Supabase Auth.
- supabase-config.js: URL y clave publishable del proyecto conectado.
- supabase-schema.sql: NO ejecutar en el proyecto actual; es un esquema antiguo de referencia.
- migration-booking-v2.sql: migración aplicada para modalidad y extras.
- migration-authenticated-rpcs.sql: migración aplicada para que las RPC públicas también funcionen con una sesión Auth activa.

PROYECTO CONECTADO
- Project ref: vfkalbukfiyprugqepcy
- URL: https://vfkalbukfiyprugqepcy.supabase.co
- Auth: inicio de sesión por email y contraseña; el usuario debe existir en public.admins.
- Catálogo: public.services y public.designs.
- Reservas: public.bookings y public.clients.
- Disponibilidad: RPC get_available_days (marca únicamente días con al menos un horario libre) y get_available_slots (horas exactas libres).
- Las RPC públicas de catálogo/agenda/solicitud están autorizadas para anon y authenticated; las tablas administrativas siguen protegidas por RLS y public.admins.
- Imágenes: Storage bucket público media (JPG/PNG/WebP hasta 5 MB), con políticas de escritura para usuarios autenticados que pertenezcan a public.admins.
- Crear solicitud: RPC create_booking_request_v2.

SEGURIDAD
Se incluye únicamente la clave publishable pública. No agregar service_role ni secret keys al frontend.
RLS y la membresía admins siguen siendo la autoridad de acceso.

PUBLICACIÓN
Subí index.html, admin.html y supabase-config.js en la misma carpeta/origen. Abrí admin.html e iniciá sesión con el usuario ya autorizado en public.admins.

NOTAS
- Los diseños de muestra (is_sample=true) no aparecen en el catálogo público hasta que se publiquen desde el panel.
- Al editar/publicar un registro de muestra desde el panel, se marca is_sample=false.
- La reserva requiere servicio; diseño es opcional y suma su extra_price.
- Los importes de servicio, diseño y extras se calculan en PostgreSQL.
- La solicitud se registra antes de abrir WhatsApp; si falla el guardado, no se envía un mensaje que aparente una reserva registrada.
- En el calendario público solo se pueden seleccionar días con horarios libres para el servicio elegido; las reservas pendientes, confirmadas y completadas bloquean el horario.
- La carga de diseños permite arrastrar/seleccionar una imagen, ver una vista previa y subir JPG/PNG/WebP de hasta 5 MB a Storage → media. El administrador debe estar autenticado y autorizado en public.admins.
- Desde Turnos, el administrador puede confirmar o rechazar una solicitud y contactar a la clienta por WhatsApp con un mensaje preparado. La apertura de WhatsApp requiere la acción final del administrador.
- Desde Turnos también puede bloquear o liberar horarios manuales en public.time_blocks para compromisos coordinados fuera de la web.
- La disponibilidad se consulta en tiempo real según working_hours, time_blocks, min_notice y reservas existentes.
